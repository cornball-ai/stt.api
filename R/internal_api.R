#' Build the segments data.frame from a parsed API response
#'
#' Shared by the timestamped formats. verbose_json segments carry
#' start/end/text; diarized_json segments add a \code{speaker} label. The
#' speaker column is added only when the response actually has it, so
#' \code{is.null(x$segments$speaker)} gives a straight answer either way.
#'
#' @param segs The \code{segments} element of the parsed response, or NULL.
#' @return A data.frame with numeric start/end, or NULL.
#' @keywords internal
.parse_api_segments <- function(segs) {
    if (is.null(segs) || length(segs) == 0) {
        return(NULL)
    }
    # Decided once, for all rows: a per-row conditional would build frames with
    # different columns, and rbind would then fail.
    has_speaker <- any(vapply(segs, function(s) !is.null(s$speaker),
                              logical(1)))

    # A segment is usable only if it carries all three caption fields as
    # scalars. Anything else is dropped on its own -- building the row
    # straight from s$start/s$end/s$text would make one malformed segment
    # collapse the whole response to nothing, since data.frame() with a NULL
    # column is a legal 0-column frame and rbind then fails on the width
    # mismatch. That failure is invisible and intermittent: the model decides
    # how to segment, so the same audio can parse one call and vanish the next.
    rows <- lapply(segs, function(s) {
        if (is.null(s$start) || length(s$start) != 1L ||
            is.null(s$end) || length(s$end) != 1L ||
            is.null(s$text) || length(s$text) != 1L) {
            return(NULL)
        }
        row <- data.frame(
                          start = s$start,
                          end = s$end,
                          text = as.character(s$text),
                          stringsAsFactors = FALSE
        )
        if (has_speaker) {
            row$speaker <- as.character(s$speaker %||% NA)
        }
        row
    })
    rows <- Filter(Negate(is.null), rows)
    if (length(rows) == 0) {
        return(NULL)
    }

    out <- tryCatch(do.call(rbind, rows), error = function(e) NULL)
    if (is.null(out) || nrow(out) == 0) {
        return(NULL)
    }
    # Normalize to numeric seconds
    .normalize_segments(out)
}

# Internal: Transcribe via OpenAI-compatible API
.via_api <- function(file, model = NULL, language = NULL,
                     response_format = "json", prompt = NULL,
                     chunking_strategy = NULL) {
    base_url <- .get_api_base(required = TRUE)
    api_key <- .get_api_key()
    timeout <- .get_timeout()

    # Build endpoint URL

    url <- paste0(base_url, "/v1/audio/transcriptions")

    # Prepare multipart form data
    form_data <- list(file = curl::form_file(file))

    if (!is.null(model)) {
        form_data$model <- model
    }

    if (!is.null(language)) {
        form_data$language <- language
    }

    if (!is.null(prompt)) {
        form_data$prompt <- prompt
    }

    form_data$response_format <- response_format

    # Request word-level timestamps for verbose_json, so result$words is
    # populated like the in-process whisper backend. OpenAI treats word and
    # segment as separate granularities, and requesting word alone can suppress
    # segments -- so ask for BOTH (two array-style fields). whisper::serve
    # honors either.
    if (identical(response_format, "verbose_json")) {
        gran <- list("segment", "word")
        names(gran) <- c("timestamp_granularities[]", "timestamp_granularities[]")
        form_data <- c(form_data, gran)
    }

    # diarized_json (gpt-4o-transcribe-diarize) rejects
    # timestamp_granularities[] -- it carries its own segment timing -- and
    # rejects audio over 30s unless chunking_strategy is set. stt() resolves
    # the default, so that what the call_record reports is what went out.
    if (!is.null(chunking_strategy)) {
        form_data$chunking_strategy <- chunking_strategy
    }

    # Build headers (curl expects "Name: Value" format)
    headers <- "Accept: application/json"
    if (!is.null(api_key) && nchar(api_key) > 0) {
        headers <- c(headers, paste0("Authorization: Bearer ", api_key))
    }

    # Create curl handle
    h <- curl::new_handle()
    curl::handle_setopt(h, timeout = timeout, httpheader = headers)
    curl::handle_setform(h, .list = form_data)

    # Make request
    response <- tryCatch(
                         curl::curl_fetch_memory(url, handle = h),
                         error = function(e) {
        stop(
             "API request failed: ", conditionMessage(e), "\n",
             "URL: ", url,
             call. = FALSE
        )
    }
    )

    # Check HTTP status
    if (response$status_code >= 400) {
        body <- rawToChar(response$content)
        error_msg <- tryCatch(
                              {
            parsed <- jsonlite::fromJSON(body, simplifyVector = FALSE)
            if (!is.null(parsed$error$message)) {
                parsed$error$message
            } else {
                body
            }
        },
                              error = function(e) body
        )
        stop(
             "API error (HTTP ", response$status_code, "): ", error_msg,
             call. = FALSE
        )
    }

    # Parse response
    body <- rawToChar(response$content)

    if (response_format == "text") {
        return(list(
                    text = body,
                    segments = NULL,
                    language = language,
                    backend = "api",
                    raw = body
            ))
    }

    # Parse JSON response
    parsed <- tryCatch(
                       jsonlite::fromJSON(body, simplifyVector = FALSE),
                       error = function(e) {
        stop("Failed to parse API response as JSON: ", conditionMessage(e),
             call. = FALSE)
    }
    )

    segments <- .parse_api_segments(parsed$segments)

    # Extract word-level timestamps if available (verbose_json + word
    # granularity), mirroring the native whisper backend's result$words.
    words <- NULL
    if (!is.null(parsed$words) && length(parsed$words) > 0) {
        words <- tryCatch(
                          do.call(rbind, lapply(parsed$words, function(w) {
            data.frame(word = w$word, start = w$start, end = w$end,
                       stringsAsFactors = FALSE)
        })),
                          error = function(e) NULL
        )
    }

    out <- list(
         text = parsed$text %||% "",
         segments = segments,
         language = parsed$language %||% language,
         backend = "api",
         raw = parsed
    )
    if (!is.null(words)) {
        out$words <- words
    }
    out
}


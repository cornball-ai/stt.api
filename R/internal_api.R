#' MIME type for an audio file, from its extension
#'
#' Covers every container OpenAI accepts as transcription input, since a
#' speaker reference may be in any of them. Deriving this from the extension
#' rather than sniffing the file keeps the dependency list where it is; an
#' unknown extension is an error rather than a guess, since a wrong MIME type
#' fails server-side with a far less obvious message.
#'
#' @param path File path.
#' @return A MIME type string.
#' @keywords internal
.audio_mime <- function(path) {
    ext <- tolower(sub(".*\\.", "", basename(path)))
    mime <- switch(ext,
                   mp3 = "audio/mpeg",
                   mpeg = "audio/mpeg",
                   mpga = "audio/mpeg",
                   wav = "audio/wav",
                   m4a = "audio/mp4",
                   mp4 = "audio/mp4",
                   flac = "audio/flac",
                   ogg = "audio/ogg",
                   oga = "audio/ogg",
                   webm = "audio/webm",
                   NULL)
    if (is.null(mime)) {
        stop("Cannot determine an audio MIME type for '", basename(path),
             "'. Use one of: flac, m4a, mp3, mp4, mpeg, mpga, ogg, wav, webm.",
             call. = FALSE)
    }
    mime
}

#' Encode an audio file as a data URI
#'
#' The speaker-reference fields take the clip inline as
#' \code{data:<mime>;base64,<...>} rather than as a file part, so the bytes
#' are read and encoded here. jsonlite is already an import, so this adds no
#' dependency despite having nothing to do with JSON.
#'
#' @param path Path to an audio file.
#' @return A data URI string.
#' @keywords internal
.audio_data_uri <- function(path) {
    if (!file.exists(path)) {
        stop("Speaker reference file not found: ", path, call. = FALSE)
    }
    raw <- readBin(path, "raw", n = file.size(path))
    # jsonlite::base64_enc() emits MIME-style base64, hard-wrapped at 72
    # columns. A data URI must be one unbroken run, and the embedded newlines
    # get the whole field rejected server-side with "Known speaker references
    # must be base64-encoded audio data", which does not point at whitespace.
    b64 <- gsub("[\r\n]", "", jsonlite::base64_enc(raw))
    paste0("data:", .audio_mime(path), ";base64,", b64)
}

#' Validate the known_speakers argument
#'
#' @param x A named character vector of audio file paths, or NULL.
#' @return \code{x}, invisibly, or an error.
#' @keywords internal
.validate_known_speakers <- function(x) {
    if (is.null(x) || length(x) == 0) {
        return(invisible(NULL))
    }
    if (!is.character(x)) {
        stop("known_speakers must be a character vector of audio file paths.",
             call. = FALSE)
    }
    nms <- names(x)
    if (is.null(nms) || any(is.na(nms)) || !all(nzchar(nms))) {
        stop("known_speakers must be named; the names become the speaker ",
             "labels in the result (e.g. c(agent = 'agent.wav')).",
             call. = FALSE)
    }
    if (anyDuplicated(nms)) {
        stop("known_speakers names must be unique; duplicated: ",
             paste(unique(nms[duplicated(nms)]), collapse = ", "),
             call. = FALSE)
    }
    # OpenAI's cap. Checked here so the failure names the limit rather than
    # arriving as a generic 400.
    if (length(x) > 4L) {
        stop("At most 4 known speakers are supported; got ", length(x), ".",
             call. = FALSE)
    }
    missing <- x[!file.exists(x)]
    if (length(missing) > 0) {
        stop("Speaker reference file(s) not found: ",
             paste(missing, collapse = ", "), call. = FALSE)
    }
    invisible(x)
}

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
                     chunking_strategy = NULL, known_speakers = NULL) {
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

    # Named speakers: the names go out as one repeated field and the encoded
    # reference clips as another, paired by position -- same array-style
    # convention as timestamp_granularities[] above. Segments then come back
    # labelled with these names instead of the provider's generic ones.
    if (length(known_speakers) > 0) {
        nms <- as.list(names(known_speakers))
        names(nms) <- rep("known_speaker_names[]", length(nms))
        refs <- lapply(unname(known_speakers), .audio_data_uri)
        names(refs) <- rep("known_speaker_references[]", length(refs))
        form_data <- c(form_data, nms, refs)
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


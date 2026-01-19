# Internal: Transcribe via OpenAI-compatible API
.via_api <- function(
  file,
  model = NULL,
  language = NULL,
  response_format = "json",
  prompt = NULL
) {

  base_url <- .get_api_base(required = TRUE)
  api_key <- .get_api_key()
  timeout <- .get_timeout()

  # Build endpoint URL

  url <- paste0(base_url, "/v1/audio/transcriptions")

  # Prepare multipart form data
  form_data <- list(
    file = curl::form_file(file)
  )

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

  # Build headers (curl expects "Name: Value" format)
  headers <- "Accept: application/json"
  if (!is.null(api_key) && nchar(api_key) > 0) {
    headers <- c(headers, paste0("Authorization: Bearer ", api_key))
  }

  # Create curl handle
  h <- curl::new_handle()
  curl::handle_setopt(h,
    timeout = timeout,
    httpheader = headers
  )
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

  # Extract segments if available (verbose_json format)
  segments <- NULL
  if (!is.null(parsed$segments) && length(parsed$segments) > 0) {
    segments <- tryCatch(
      {
        do.call(rbind, lapply(parsed$segments, function(s) {
              data.frame(
                start = s$start,
                end = s$end,
                text = s$text,
                stringsAsFactors = FALSE
              )
            }))
      },
      error = function(e) NULL
    )
    # Normalize to numeric seconds
    segments <- .normalize_segments(segments)
  }

  list(
    text = parsed$text %||% "",
    segments = segments,
    language = parsed$language %||% language,
    backend = "api",
    raw = parsed
  )
}


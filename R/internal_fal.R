# Internal fal.api backend for transcription

#' Transcribe via fal.api
#' @keywords internal
.via_fal <- function(
  file,
  model = NULL,
  language = NULL
) {

  if (!requireNamespace("fal.api", quietly = TRUE)) {
    stop("fal.api package is required for fal backend", call. = FALSE)
  }

  # Default to fal-ai/whisper

  model <- model %||% "fal-ai/whisper"

  # Upload file to fal.ai storage
  audio_url <- fal.api::.fal_upload_file(file)

  # Build request params
  params <- list(audio_url = audio_url)
  if (!is.null(language)) {
    params$language <- language
  }

  # Run transcription
  result <- fal.api::fal_generate(
    model = model,
    audio_url = audio_url,
    language = language,
    .timeout = getOption("stt.timeout", 120)
  )

  # Normalize response to stt.api format
  text <- result$text %||% ""

  # Build segments if available
  segments <- NULL
  if (!is.null(result$chunks)) {
    segments <- data.frame(
      start = sapply(result$chunks, function(x) x$timestamp[[1]] %||% NA_real_),
      end = sapply(result$chunks, function(x) x$timestamp[[2]] %||% NA_real_),
      text = sapply(result$chunks, function(x) x$text %||% ""),
      stringsAsFactors = FALSE
    )
    segments <- .normalize_segments(segments)
  }

  list(
    text = text,
    segments = segments,
    language = language,
    backend = "fal",
    raw = result
  )
}


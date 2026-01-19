# Internal helper to get API base URL
.get_api_base <- function(required = FALSE) {
  base <- getOption("stt.api_base")
  if (required && is.null(base)) {
    stop(
      "API base URL not set.\n",
      "Use set_stt_base() to configure the endpoint.",
      call. = FALSE
    )
  }
  base
}

# Internal helper to get API key
.get_api_key <- function() {
  getOption("stt.api_key")
}

# Internal helper to get timeout
.get_timeout <- function() {

  getOption("stt.timeout", default = 60)
}

# Check if audio.whisper is available
.has_audio_whisper <- function() {

  requireNamespace("audio.whisper", quietly = TRUE)
}

#' Convert time string to numeric seconds
#' @param time_str Time string in "HH:MM:SS.mmm" or "MM:SS.mmm" format
#' @return Numeric seconds
#' @keywords internal
.time_to_seconds <- function(time_str) {
  if (is.numeric(time_str)) return(time_str)
  if (is.na(time_str) || is.null(time_str)) return(NA_real_)

  parts <- strsplit(as.character(time_str), ":") [[1]]
  if (length(parts) == 3) {
    as.numeric(parts[1]) * 3600 + as.numeric(parts[2]) * 60 + as.numeric(parts[3])
  } else if (length(parts) == 2) {
    as.numeric(parts[1]) * 60 + as.numeric(parts[2])
  } else {
    as.numeric(parts[1])
  }
}

#' Normalize segments to use numeric seconds
#' @param segments Data frame with from/to or start/end columns
#' @return Data frame with numeric start/end columns
#' @keywords internal
.normalize_segments <- function(segments) {
  if (is.null(segments) || nrow(segments) == 0) return(segments)

  # Standardize column names to start/end
  if ("from" %in% names(segments) && !"start" %in% names(segments)) {
    segments$start <- segments$from
  }
  if ("to" %in% names(segments) && !"end" %in% names(segments)) {
    segments$end <- segments$to
  }

  # Convert to numeric seconds if needed
  if ("start" %in% names(segments) && !is.numeric(segments$start)) {
    segments$start <- sapply(segments$start, .time_to_seconds)
  }
  if ("end" %in% names(segments) && !is.numeric(segments$end)) {
    segments$end <- sapply(segments$end, .time_to_seconds)
  }

  segments
}

# Choose backend based on availability and user preference
.choose_backend <- function(backend = c("auto", "api", "whisper", "audio.whisper")) {
  backend <- match.arg(backend)

  if (backend == "api") {
    # Explicit API request - verify it's configured
    if (is.null(.get_api_base())) {
      stop(
        "Backend 'api' requested but no API base URL is set.\n",
        "Use set_stt_base() to configure the endpoint.",
        call. = FALSE
      )
    }
    return("api")
  }

  if (backend == "whisper") {
    # Explicit native whisper request - verify it's available
    if (!.has_whisper()) {
      stop(
        "Backend 'whisper' requested but package is not installed.\n",
        "Install with: remotes::install_github('cornball-ai/whisper')",
        call. = FALSE
      )
    }
    return("whisper")
  }

  if (backend == "audio.whisper") {
    # Explicit audio.whisper request - verify it's available
    if (!.has_audio_whisper()) {
      stop(
        "Backend 'audio.whisper' requested but package is not installed.\n",
        "Install with: install.packages('audio.whisper', repos = 'https://bnosac.github.io/drat')",
        call. = FALSE
      )
    }
    return("audio.whisper")
  }

  # Auto mode: try backends in priority order
  if (!is.null(.get_api_base())) {
    return("api")
  }

  if (.has_whisper()) {
    return("whisper")
  }

  if (.has_audio_whisper()) {
    return("audio.whisper")
  }

  stop(
    "No transcription backend available.\n",
    "Either:\n",
    "  - Set an API endpoint with set_stt_base(), or\n",
    "  - Install whisper: remotes::install_github('cornball-ai/whisper'), or\n",
    "  - Install audio.whisper: install.packages('audio.whisper', repos = 'https://bnosac.github.io/drat')",
    call. = FALSE
  )
}


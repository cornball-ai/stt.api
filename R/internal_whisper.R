# Native whisper package backend

# Module-level whisper model cache
.native_whisper_cache <- new.env(parent = emptyenv())

# Check if native whisper package is available
.has_whisper <- function() {
  requireNamespace("whisper", quietly = TRUE)
}

#' Get or create cached native whisper model
#' @param model Model name (e.g., "tiny", "base", "small", "medium", "large-v3")
#' @param device Device to use ("auto", "cpu", "cuda")
#' @return Loaded whisper model object
#' @keywords internal
.get_native_whisper_model <- function(
  model,
  device = "auto"
) {
  cache_key <- paste(model, device, sep = "_")
  if (is.null(.native_whisper_cache[[cache_key]])) {
    message("Loading native whisper model: ", model, "...")
    .native_whisper_cache[[cache_key]] <- tryCatch(
      whisper::load_whisper_model(model, device = device),
      error = function(e) {
        stop(
          "Failed to load whisper model '", model, "': ", conditionMessage(e),
          call. = FALSE
        )
      }
    )
    message("Native whisper model loaded and cached.")
  }
  .native_whisper_cache[[cache_key]]
}

#' Clear native whisper model cache
#'
#' Removes cached native whisper models from memory. Call this to free GPU/RAM
#' after batch processing is complete.
#'
#' @export
clear_native_whisper_cache <- function() {
  models <- ls(.native_whisper_cache)
  if (length(models) > 0) {
    rm(list = models, envir = .native_whisper_cache)
    gc()
    message("Cleared ", length(models), " cached native whisper model(s).")
  } else {
    message("Native whisper cache is empty.")
  }
  invisible(NULL)
}

#' Internal: Transcribe via native whisper package
#'
#' Uses the cornball-ai/whisper native R torch implementation.
#'
#' @param file Character. Path to the audio file to transcribe.
#' @param model Character or NULL. Whisper model name (e.g., "tiny", "base",
#'   "small", "medium", "large-v3").
#' @param language Character or NULL. Language code for transcription.
#' @return List with transcription results in normalized format.
#' @keywords internal
.via_whisper <- function(
  file,
  model = NULL,
  language = NULL
) {

  if (!.has_whisper()) {
    stop(
      "whisper package is not installed.\n",
      "Install with: remotes::install_github('cornball-ai/whisper')",
      call. = FALSE
    )
  }

  # Default model if not specified
  if (is.null(model)) {
    model <- "tiny"
  }

  # Default language
  if (is.null(language)) {
    language <- "en"
  }

  # Run transcription using whisper::transcribe directly
  # (it handles model loading/caching internally)
  result <- tryCatch(
    whisper::transcribe(
      file = file,
      model = model,
      language = language,
      verbose = FALSE
    ),
    error = function(e) {
      stop(
        "Transcription failed: ", conditionMessage(e),
        call. = FALSE
      )
    }
  )

  # Build segments data frame if available
  segments <- NULL
  if (!is.null(result$segments) && nrow(result$segments) > 0) {
    segments <- result$segments
    # Normalize column names (whisper returns start/end already)
    segments <- .normalize_segments(segments)
  }

  list(
    text = result$text,
    segments = segments,
    language = result$language %||% language,
    backend = "whisper",
    raw = result
  )
}

# Null coalescing operator if not available
`%||%` <- function(
  x,
  y
) if (is.null(x)) y else x


# Module-level whisper model cache
.whisper_cache <- new.env(parent = emptyenv())

#' Get or create cached whisper model
#' @param model Model name (e.g., "tiny", "base", "small", "medium", "large-v3")
#' @return Loaded whisper model object
#' @keywords internal
.get_whisper_model <- function(model) {
  if (is.null(.whisper_cache[[model]])) {
    message("Loading whisper model: ", model, "...")
    .whisper_cache[[model]] <- tryCatch(
      audio.whisper::whisper(model),
      error = function(e) {
        stop(
          "Failed to load whisper model '", model, "': ", conditionMessage(e),
          call. = FALSE
        )
      }
    )
    message("Whisper model loaded and cached.")
  }
  .whisper_cache[[model]]
}

#' Clear whisper model cache
#'
#' Removes cached whisper models from memory. Call this to free GPU/RAM
#' after batch processing is complete.
#'
#' @export
clear_whisper_cache <- function() {
  models <- ls(.whisper_cache)
  if (length(models) > 0) {
    rm(list = models, envir = .whisper_cache)
    gc() # Force garbage collection
    message("Cleared ", length(models), " cached whisper model(s).")
  } else {
    message("Whisper cache is empty.")
  }
  invisible(NULL)
}

#' Internal: Transcribe via audio.whisper package
#'
#' @param file Character. Path to the audio file to transcribe.
#' @param model Character or NULL. Whisper model name (e.g., "tiny", "base", "small").
#' @param language Character or NULL. Language code for transcription.
#' @return List with transcription results.
#' @keywords internal
#' @importFrom stats predict
#' @importFrom utils capture.output
.via_audio_whisper <- function(
  file,
  model = NULL,
  language = NULL
) {

  if (!.has_audio_whisper()) {
    stop(
      "audio.whisper package is not installed.\n",
      "Install with: install.packages('audio.whisper', repos = 'https://bnosac.github.io/drat')",
      call. = FALSE
    )
  }

  # Default model if not specified
  if (is.null(model)) {
    model <- "tiny"
  }

  # Get cached model (loads only once per model type)
  whisper_model <- .get_whisper_model(model)

  # Build predict arguments
  predict_args <- list(
    object = whisper_model,
    newdata = file
  )

  if (!is.null(language)) {
    predict_args$language <- language
  }

  # Run transcription (suppress verbose whisper output)
  result <- tryCatch({
      invisible(capture.output(
          res <- do.call(predict, predict_args),
          type = "output"
        ))
      res
    }, error = function(e) {
      stop(
        "Transcription failed: ", conditionMessage(e),
        call. = FALSE
      )
    }
  )

  # Build segments data frame if available
  segments <- NULL
  if (!is.null(result$data) && nrow(result$data) > 0) {
    segments <- result$data
    # Normalize to numeric seconds with start/end column names
    segments <- .normalize_segments(segments)
  }

  # Combine all text segments
  text <- ""
  if (!is.null(result$data$text)) {
    text <- paste(result$data$text, collapse = " ")
  }

  list(
    text = text,
    segments = segments,
    language = language,
    backend = "audio.whisper",
    raw = result
  )
}


# gpu.ctl integration for stt.api
#
# Optionally acquires GPU resources before API calls when gpu.ctl is available.
# Enable with: options(stt.gpuctl = TRUE)

# Service configuration for Whisper STT
.stt_gpu_service <- list(
  name = "whisper",
  port = 8200,
  vram = 6,
  container = "whisper",
  health = "/health"
)

#' Check if gpu.ctl integration is enabled
#' @noRd
.gpuctl_enabled <- function() {
  isTRUE(getOption("stt.gpuctl", FALSE)) &&
  requireNamespace("gpu.ctl", quietly = TRUE)
}

#' Register stt.api service with gpu.ctl
#' @noRd
.gpuctl_register_service <- function() {
  if (!.gpuctl_enabled()) return(invisible(FALSE))

  tryCatch({
      # Only register if not already registered
      existing <- gpu.ctl::gpu_services()
      if (!.stt_gpu_service$name %in% existing$name) {
        gpu.ctl::gpu_register(
          name = .stt_gpu_service$name,
          port = .stt_gpu_service$port,
          vram = .stt_gpu_service$vram,
          container = .stt_gpu_service$container,
          health_endpoint = .stt_gpu_service$health
        )
      }
    }, error = function(e) {
      # Silently ignore registration errors
    })
  invisible(TRUE)
}

#' Acquire GPU for whisper if gpu.ctl is enabled
#'
#' @return Invisible TRUE if acquired, FALSE if not using gpu.ctl
#' @noRd
.gpuctl_acquire <- function() {
  if (!.gpuctl_enabled()) return(invisible(FALSE))

  .gpuctl_register_service()

  tryCatch({
      gpu.ctl::gpu_acquire(.stt_gpu_service$name)
      invisible(TRUE)
    }, error = function(e) {
      warning("gpu.ctl: ", e$message, call. = FALSE)
      invisible(FALSE)
    })
}


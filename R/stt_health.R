#' Check STT Backend Health
#'
#' Checks whether a transcription backend is available and working.
#'
#' @return A list with components:
#' \describe{
#'   \item{ok}{Logical. TRUE if a backend is available.}
#'   \item{backend}{Character. The available backend ("api" or "whisper"),
#'     or NULL if none available.}
#'   \item{message}{Character. Status message with details.}
#' }
#'
#' @examples
#' \dontrun{
#' h <- stt_health()
#' if (h$ok) {
#'   message("STT ready via ", h$backend)
#' }
#' }
#'
#' @export
stt_health <- function() {
    # Check whisper package first
    if (.has_whisper()) {
        return(list(
                    ok = TRUE,
                    backend = "whisper",
                    message = "whisper package is available"
            ))
    }

    # Check API backend
    api_base <- .get_api_base()
    if (!is.null(api_base)) {
        return(.check_api_health(api_base))
    }

    # No backend available
    list(
         ok = FALSE,
         backend = NULL,
         message = "No backend available. Install whisper or set stt.api_base."
    )
}

# Internal: Check API endpoint health
.check_api_health <- function(base_url) {
    # Try common health endpoints (including /v1/models which OpenAI supports)
    endpoints <- c("/v1/models", "/health", "/v1/health", "/")
    api_key <- .get_api_key()

    # Build headers (curl expects "Name: Value" format)
    headers <- "Accept: application/json"
    if (!is.null(api_key) && nchar(api_key) > 0) {
        headers <- c(headers, paste0("Authorization: Bearer ", api_key))
    }

    for (endpoint in endpoints) {
        url <- paste0(base_url, endpoint)

        h <- curl::new_handle()
        curl::handle_setopt(h,
                            timeout = 5,
                            httpheader = headers,
                            nobody = FALSE
        )

        response <- tryCatch(
                             curl::curl_fetch_memory(url, handle = h),
                             error = function(e) NULL
        )

        if (!is.null(response) && response$status_code < 400) {
            return(list(
                        ok = TRUE,
                        backend = "api",
                        message = paste0("API endpoint responding at ", base_url)
                ))
        }
    }

    # API not responding
    list(
         ok = FALSE,
         backend = "api",
         message = paste0("API endpoint not responding at ", base_url)
    )
}


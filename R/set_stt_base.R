#' Set the API Base URL
#'
#' Sets the base URL for OpenAI-compatible STT endpoints.
#'
#' @param url Character string. The base URL (e.g., "http://localhost:4123"
#'   or "https://api.openai.com").
#'
#' @return Invisibly returns the previous value.
#'
#' @examples
#' \dontrun{
#' set_stt_base("http://localhost:4123")
#' set_stt_base("https://api.openai.com")
#' }
#'
#' @export
set_stt_base <- function(url) {
  if (!is.null(url) && !is.character(url)) {
    stop("url must be a character string or NULL", call. = FALSE)
  }
  if (!is.null(url) && length(url) != 1) {
    stop("url must be a single string", call. = FALSE)
  }

  # Remove trailing slash if present
  if (!is.null(url)) {
    url <- sub("/$", "", url)
  }

  old <- getOption("stt.api_base")
  options(stt.api_base = url)
  invisible(old)
}


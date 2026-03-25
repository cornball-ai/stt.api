#' Set the API Key
#'
#' Sets the API key for hosted STT services (e.g., OpenAI).
#' Local servers typically ignore this.
#'
#' @param key Character string. The API key.
#'
#' @return Invisibly returns the previous value.
#'
#' @examples
#' set_stt_key("test-key-123")
#' getOption("stt.api_key")
#'
#' @export
set_stt_key <- function(key) {
    if (!is.null(key) && !is.character(key)) {
        stop("key must be a character string or NULL", call. = FALSE)
    }
    if (!is.null(key) && length(key) != 1) {
        stop("key must be a single string", call. = FALSE)
    }

    old <- getOption("stt.api_key")
    options(stt.api_key = key)
    invisible(old)
}


#' Speech to Text
#'
#' Convert an audio file to text using a local whisper backend or
#' an OpenAI-compatible API.
#'
#' @param file Path to the audio file to convert.
#' @param model Model name to use for transcription. For API backends, this
#'   is passed directly (e.g., "whisper-1"). For whisper, this is
#'   the model size (e.g., "tiny", "base", "small", "medium", "large").
#'   If NULL, uses the backend's default.
#' @param language Language code (e.g., "en", "es", "fr"). Optional hint
#'   to improve transcription accuracy.
#' @param response_format Response format for API backend. One of "text",
#'   "json", or "verbose_json". Ignored for whisper backend.
#' @param backend Which backend to use: "auto" (default), "whisper",
#'   or "openai". Auto mode tries whisper first, then openai API
#'   (if configured).
#' @param prompt Optional text to guide the transcription. For API backend,
#'   this is passed as initial_prompt to help with spelling of names,
#'   acronyms, or domain-specific terms. Ignored for whisper backend.
#'
#' @return A list with components:
#' \describe{
#'   \item{text}{The transcribed text as a single string.}
#'   \item{segments}{A data.frame of segments with timing info, or NULL.}
#'   \item{language}{The detected or specified language code.}
#'   \item{backend}{Which backend was used ("api" or "whisper").}
#'   \item{raw}{The raw response from the backend.}
#' }
#' The result also carries a \code{"call_record"} attribute (cornball_sidecar
#' v1, as in xtx.api/tts.api): the resolved request, elapsed seconds, and a
#' timestamp -- provenance that rides with the transcription when callers
#' serialize it.
#'
#' @examples
#' \dontrun{
#' # Using OpenAI API
#' set_stt_base("https://api.openai.com")
#' set_stt_key(Sys.getenv("OPENAI_API_KEY"))
#' result <- stt("speech.wav", model = "whisper-1")
#' result$text
#'
#' # Using local server
#' set_stt_base("http://localhost:4123")
#' result <- stt("speech.wav")
#' }
#'
#' @export
stt <- function(file, model = NULL, language = NULL,
                response_format = c("json", "text", "verbose_json"),
                backend = c("auto", "whisper", "openai"), prompt = NULL) {
    # Validate file
    if (!file.exists(file)) {
        stop("File not found: ", file, call. = FALSE)
    }

    response_format <- match.arg(response_format)
    backend <- match.arg(backend)

    # Resolve backend
    resolved_backend <- .choose_backend(backend)

    # Dispatch to appropriate backend
    started <- Sys.time()
    res <- if (resolved_backend == "openai") {
        .via_api(
                 file = file,
                 model = model,
                 language = language,
                 response_format = response_format,
                 prompt = prompt
        )
    } else {
        .via_whisper(file = file, model = model, language = language)
    }
    # stt produces an R object, not a media file, so the call record rides as
    # an attribute (cornball_sidecar v1, as in xtx.api/tts.api); callers that
    # serialize the result keep its provenance with it.
    attr(res, "call_record") <- list(
        cornball_sidecar = 1L, package = "stt.api",
        version = as.character(utils::packageVersion("stt.api")),
        fn = "stt",
        request = Filter(Negate(is.null),
                         list(file = file, model = model,
                              language = language,
                              response_format = response_format,
                              backend = resolved_backend, prompt = prompt)),
        elapsed = round(as.numeric(difftime(Sys.time(), started,
            units = "secs")), 2),
        created = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"))
    res
}


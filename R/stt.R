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
#' @param backend Which engine to use: "auto" (default), "whisper",
#'   or "openai". Auto mode tries whisper first, then the openai API
#'   (if configured). See \code{source} for *where* the engine runs.
#' @param source Where the engine runs: "auto" (default), "api" for an HTTP
#'   service (OpenAI, or a self-hosted whisper server; see
#'   \code{\link{set_stt_base}}), or "package" for the in-process whisper R
#'   package. "auto" runs whisper in-process and openai via the API, matching
#'   the previous behavior. Use \code{backend = "whisper", source = "api"} to
#'   reach a whisper \code{serve()} endpoint.
#' @param prompt Optional text to guide the transcription. For API backend,
#'   this is passed as initial_prompt to help with spelling of names,
#'   acronyms, or domain-specific terms. Ignored for whisper backend.
#'
#' @return A list with components:
#' \describe{
#'   \item{text}{The transcribed text as a single string.}
#'   \item{segments}{A data.frame of segments with timing info, or NULL.}
#'   \item{words}{A data.frame of word-level timestamps (word, start, end),
#'     present only when the API returns word granularity (verbose_json);
#'     otherwise absent.}
#'   \item{language}{The detected or specified language code.}
#'   \item{backend}{The legacy execution route ("api" or "whisper"). This
#'     reports *where* the engine ran, not the engine itself; the resolved
#'     \code{backend}/\code{source} pair lives in the \code{"call_record"}
#'     attribute.}
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
#' # Using a self-hosted whisper serve() endpoint
#' set_stt_base("http://troy-g5:7809")
#' result <- stt("speech.wav", backend = "whisper", source = "api")
#'
#' # In-process whisper package
#' result <- stt("speech.wav", backend = "whisper", source = "package")
#' }
#'
#' @export
stt <- function(file, model = NULL, language = NULL,
                response_format = c("json", "text", "verbose_json"),
                backend = c("auto", "whisper", "openai"),
                source = c("auto", "api", "package"), prompt = NULL) {
    # Validate file
    if (!file.exists(file)) {
        stop("File not found: ", file, call. = FALSE)
    }

    response_format <- match.arg(response_format)
    backend <- match.arg(backend)
    source <- match.arg(source)

    # Resolve the engine and where it runs (in-process package vs HTTP API)
    route <- .resolve_route(backend, source)

    # Dispatch to appropriate route
    started <- Sys.time()
    res <- if (route$route == "api") {
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
                              backend = route$backend, source = route$route,
                              prompt = prompt)),
        elapsed = round(as.numeric(difftime(Sys.time(), started,
            units = "secs")), 2),
        created = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"))
    res
}


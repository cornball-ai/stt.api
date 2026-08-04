#' Speech to Text
#'
#' Convert an audio file to text using a local whisper backend or
#' an OpenAI-compatible API.
#'
#' @param file Path to the audio file to convert.
#' @param model Model name to use for transcription. For API backends, this
#'   is passed directly (e.g., "whisper-1"). For whisper, this is
#'   the model size (e.g., "tiny", "base", "small", "medium", "large").
#'   If NULL, uses the backend's default. Which model you pick decides what
#'   timing you can get back from OpenAI: "whisper-1" is the only one that
#'   returns word-level timings (with \code{response_format = "verbose_json"}),
#'   "gpt-4o-transcribe-diarize" returns speaker-labelled segments (with
#'   \code{response_format = "diarized_json"}), and the plain
#'   "gpt-4o-transcribe"/"gpt-4o-mini-transcribe" models accept only
#'   \code{response_format = "json"}, so they return no timing at all and the
#'   result is a plain list with no \code{data} component. A self-hosted
#'   \code{whisper::serve()} endpoint has no such restriction.
#' @param language Language code (e.g., "en", "es", "fr"). Optional hint
#'   to improve transcription accuracy.
#' @param response_format Response format for API backend. One of "text",
#'   "json", "verbose_json", or "diarized_json". Ignored for whisper backend,
#'   except that "diarized_json" is an error there (see \code{model}).
#'   "diarized_json" is OpenAI's diarizing format: segments gain a
#'   \code{speaker} column, and word timings are not available with it.
#' @param backend Which engine to use: "auto" (default), "whisper",
#'   or "openai". Auto mode tries whisper first, then the openai API
#'   (if configured), except for \code{response_format = "diarized_json"},
#'   which only OpenAI serves and so resolves straight to "openai". See
#'   \code{source} for *where* the engine runs.
#' @param source Where the engine runs: "auto" (default), "api" for an HTTP
#'   service (OpenAI, or a self-hosted whisper server; see
#'   \code{\link{set_stt_base}}), or "package" for the in-process whisper R
#'   package. "auto" runs whisper in-process and openai via the API, matching
#'   the previous behavior. Use \code{backend = "whisper", source = "api"} to
#'   reach a whisper \code{serve()} endpoint.
#' @param prompt Optional text to guide the transcription. For API backend,
#'   this is passed as initial_prompt to help with spelling of names,
#'   acronyms, or domain-specific terms. Ignored for whisper backend.
#' @param chunking_strategy Optional chunking strategy passed to the API,
#'   e.g. "auto". Defaults to "auto" for
#'   \code{response_format = "diarized_json"}, which OpenAI rejects for audio
#'   longer than 30 seconds when the parameter is unset. NULL otherwise.
#'
#' @return A list with components:
#' \describe{
#'   \item{text}{The transcribed text as a single string.}
#'   \item{segments}{A data.frame of segments with timing info, or NULL. For
#'     \code{response_format = "diarized_json"} it carries an extra
#'     \code{speaker} column; that column is absent, not NA, for every other
#'     format.}
#'   \item{words}{A data.frame of word-level timestamps (word, start, end),
#'     present only when the API returns word granularity (verbose_json,
#'     and on OpenAI only from "whisper-1"; see \code{model}); otherwise
#'     absent.}
#'   \item{language}{The detected or specified language code.}
#'   \item{backend}{The legacy execution route ("api" or "whisper"). This
#'     reports *where* the engine ran, not the engine itself; the resolved
#'     \code{backend}/\code{source} pair lives in the \code{"call_record"}
#'     attribute.}
#'   \item{raw}{The raw response from the backend.}
#' }
#' When the result has usable segments (\code{start}/\code{end}/\code{text}
#' columns), it additionally carries the shape subtitle tooling expects: a
#' \code{data} data.frame with \code{from}/\code{to} timestamp strings
#' ("HH:MM:SS.mmm") and \code{text}, and class
#' \code{c("stt_result", "whisper_transcription")}, so it feeds
#' \code{subtitles::whisper_to_srt()} and \code{subtitles::whisper_to_ass()}
#' directly. Note the API route returns segments only with
#' \code{response_format = "verbose_json"}. Results without usable segments
#' are plain lists, as before.
#'
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
#' # Speaker-labelled segments
#' result <- stt("meeting.wav", model = "gpt-4o-transcribe-diarize",
#'               response_format = "diarized_json")
#' result$segments[, c("start", "end", "speaker", "text")]
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
                response_format = c("json", "text", "verbose_json",
                                    "diarized_json"),
                backend = c("auto", "whisper", "openai"),
                source = c("auto", "api", "package"), prompt = NULL,
                chunking_strategy = NULL) {
    # Validate file
    if (!file.exists(file)) {
        stop("File not found: ", file, call. = FALSE)
    }

    response_format <- match.arg(response_format)
    backend <- match.arg(backend)
    source <- match.arg(source)

    # Only OpenAI diarizes, so asking for diarized_json already names the
    # backend. Let the axis whose job is to pick, pick -- otherwise the
    # default call resolves to in-process whisper and dies on the check below.
    if (response_format == "diarized_json" && backend == "auto") {
        backend <- "openai"
    }

    # Resolved here, not in .via_api(), so the call_record below reports the
    # value actually sent. OpenAI rejects diarized_json on audio longer than
    # 30s when chunking_strategy is unset.
    if (response_format == "diarized_json" && is.null(chunking_strategy)) {
        chunking_strategy <- "auto"
    }

    # Resolve the engine and where it runs (in-process package vs HTTP API)
    route <- .resolve_route(backend, source)

    # response_format is advisory for whisper -- the R object is the same
    # whichever you ask for -- so it is ignored there. diarized_json is the
    # exception: it asks for speaker labels no whisper build produces, so
    # silently ignoring it would hand back a result missing the one thing the
    # caller wanted. An explicit backend = "whisper" therefore fails here.
    if (response_format == "diarized_json" && route$backend != "openai") {
        stop("response_format = 'diarized_json' requires backend = 'openai' ",
             "(only OpenAI's models diarize); resolved backend was '",
             route$backend, "'.", call. = FALSE)
    }

    # Dispatch to appropriate route
    started <- Sys.time()
    res <- if (route$route == "api") {
        .via_api(
                 file = file,
                 model = model,
                 language = language,
                 response_format = response_format,
                 prompt = prompt,
                 chunking_strategy = chunking_strategy
        )
    } else {
        .via_whisper(file = file, model = model, language = language)
    }
    # Both routes land here with the same normalized shape, so this is where
    # the subtitle-tool shape goes on: the result feeds
    # subtitles::whisper_to_srt()/whisper_to_ass() directly whether it came
    # from the HTTP API or the in-process whisper package.
    res <- .attach_subtitle_shape(res)

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
                              prompt = prompt,
                              chunking_strategy = chunking_strategy)),
        elapsed = round(as.numeric(difftime(Sys.time(), started,
            units = "secs")), 2),
        created = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"))
    res
}


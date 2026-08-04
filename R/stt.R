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
#'   "json", "verbose_json", or "diarized_json". Ignored for whisper
#'   backend, except that a diarizing request is an error there, whether it
#'   is diarizing by format or by model (see \code{model}). "diarized_json"
#'   is OpenAI's diarizing format: segments gain a \code{speaker} column,
#'   and word timings are not available with it.
#' @param backend Which engine to use: "auto" (default), "whisper",
#'   or "openai". Auto mode tries whisper first, then the openai API
#'   (if configured), except for a diarizing request, which only OpenAI
#'   serves and so resolves straight to "openai". That covers
#'   \code{response_format = "diarized_json"} and also a \code{model} whose
#'   name marks it as diarizing, since those models answer plain "json" and
#'   "text" as well. See \code{source} for *where* the engine runs.
#' @param source Where the engine runs: "auto" (default), "api" for an HTTP
#'   service (OpenAI, or a self-hosted whisper server; see
#'   \code{\link{set_stt_base}}), or "package" for the in-process whisper R
#'   package. "auto" runs whisper in-process and openai via the API, matching
#'   the previous behavior. Use \code{backend = "whisper", source = "api"} to
#'   reach a whisper \code{serve()} endpoint.
#' @param prompt Optional text to guide the transcription. For API backend,
#'   this is passed as initial_prompt to help with spelling of names,
#'   acronyms, or domain-specific terms. Ignored for whisper backend, and an
#'   error for a diarizing model: OpenAI refuses a prompt for those
#'   whichever \code{response_format} is requested, so this is rejected on
#'   the model as well as on \code{diarized_json}.
#' @param chunking_strategy Optional chunking strategy passed to the API,
#'   e.g. "auto". Defaults to "auto" for any request to a diarizing model
#'   (\code{response_format = "diarized_json"}, or a \code{model} whose name
#'   says so), because OpenAI refuses those for audio longer than 30 seconds
#'   when it is unset. The threshold is the audio duration, not the response
#'   format. Defaulted regardless of length, since the duration is not known
#'   without decoding the file. NULL for non-diarizing requests.
#' @param known_speakers Optional named character vector of audio files, at
#'   most four, giving a short reference clip per speaker. The \emph{names}
#'   are offered to the provider as labels: segments it matches to a
#'   reference come back named, so
#'   \code{known_speakers = c(agent = "agent.wav", caller = "caller.wav")}
#'   can yield \code{segments$speaker} values of "agent" and "caller".
#'   Matching is best-effort and partial results are normal -- speakers it
#'   cannot match keep a generic label, so expect a mix, and check what came
#'   back rather than assuming. Nor does supplying references re-cut the
#'   segmentation: speakers the model has already merged into one cluster
#'   (several people on one radio downlink, say) are not thereby separated.
#'   Each clip should contain only that speaker and run roughly 2 to 10
#'   seconds; the files are read and sent inline, so keep them short.
#'   Requires \code{response_format = "diarized_json"} and is an error
#'   otherwise.
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
#' \code{response_format = "verbose_json"} or \code{"diarized_json"}.
#' Results without usable segments are plain lists, as before.
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
#' # ...with your own labels instead of generic ones
#' audio <- system.file("audio", package = "stt.api")
#' result <- stt(file.path(audio, "EagleHasLanded.mp3"),
#'               model = "gpt-4o-transcribe-diarize",
#'               response_format = "diarized_json",
#'               known_speakers = c(
#'                   Armstrong = file.path(audio, "ref_armstrong.mp3"),
#'                   Houston   = file.path(audio, "ref_houston.mp3")))
#' unique(result$segments$speaker)
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
                chunking_strategy = NULL, known_speakers = NULL) {
    # Validate file
    if (!file.exists(file)) {
        stop("File not found: ", file, call. = FALSE)
    }

    response_format <- match.arg(response_format)
    backend <- match.arg(backend)
    source <- match.arg(source)

    # Argument validation before route resolution: whether known_speakers is
    # well formed does not depend on which endpoint is configured, and a
    # malformed call should say so rather than complain about a missing base
    # URL first.
    #
    # Named speakers only mean anything to the diarizing format; silently
    # ignoring them elsewhere would return generic labels with no hint why.
    if (length(known_speakers) > 0 && response_format != "diarized_json") {
        stop("known_speakers requires response_format = 'diarized_json'; ",
             "got '", response_format, "'.", call. = FALSE)
    }
    .validate_known_speakers(known_speakers)

    # The next two rules key on the model, not the response format: OpenAI
    # applies them to "diarization models" whichever format is requested, so
    # gating on diarized_json alone leaves the plain-json case to fail after
    # the upload instead of before it.
    diarizing <- .is_diarizing(model, response_format)

    # HTTP 400: "Prompt is not supported for diarization models".
    if (!is.null(prompt) && diarizing) {
        stop("prompt is not supported for diarizing models; OpenAI rejects ",
             "the combination whichever response_format is used.",
             call. = FALSE)
    }

    # Only OpenAI diarizes, so a diarizing request already names the backend.
    # Let the axis whose job is to pick, pick. Keyed on `diarizing` and not
    # on the format: a diarizing model asked for plain json is still an
    # OpenAI request, and leaving it on "auto" sent an OpenAI model name to
    # in-process whisper on any machine that had whisper installed.
    if (diarizing && backend == "auto") {
        backend <- "openai"
    }

    # response_format is advisory for whisper -- the R object is the same
    # whichever you ask for -- so it is ignored there. A diarizing request is
    # the exception: it asks for speaker labels no whisper build produces, so
    # silently ignoring it would hand back a result missing the one thing the
    # caller wanted. An explicit backend = "whisper" therefore fails here.
    #
    # Checked against `backend`, before .resolve_route(), and not against the
    # resolved route afterwards. Route resolution also decides availability,
    # so on a machine without whisper installed it raises "package is not
    # installed" first -- turning an incompatible-argument error into an
    # environment-dependent one. Which argument combinations are legal cannot
    # depend on what happens to be installed.
    if (diarizing && backend != "openai") {
        stop("a diarizing request requires backend = 'openai' ",
             "(only OpenAI's models diarize); got backend = '", backend, "'.",
             call. = FALSE)
    }

    # HTTP 400: "chunking_strategy is required for diarization models", above
    # 30s of audio. Measured, not assumed: with the parameter unset a 15s clip
    # succeeds in both json and diarized_json, and a 44s clip is refused in
    # both. So the threshold is the duration and the format does not enter
    # into it. Defaulted for every diarizing request because the duration is
    # not known here without decoding the audio, and resolved here rather
    # than in .via_api() so the call_record reports the value actually sent.
    if (diarizing && is.null(chunking_strategy)) {
        chunking_strategy <- "auto"
    }

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
                 prompt = prompt,
                 chunking_strategy = chunking_strategy,
                 known_speakers = known_speakers
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
                              chunking_strategy = chunking_strategy,
                              # Paths, not the encoded clips: the record is
                              # provenance, and the base64 would dwarf it.
                              known_speakers = known_speakers)),
        elapsed = round(as.numeric(difftime(Sys.time(), started,
            units = "secs")), 2),
        created = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"))
    res
}


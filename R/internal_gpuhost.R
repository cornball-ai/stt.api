# The fleet's GPU host as a place whisper runs: stt.api's third source.
#
# gpu.host is the client to a gpu.ctl host, or to the router in front of
# several: one base, one token, POST /infer with the audio in the
# request. This file is the model-shaped half, which is the half the
# client refuses to know: which catalog entry, what goes in the input,
# and how the host's value becomes stt()'s result. Audio travels base64
# in the request body, since the worker is in a container on another
# machine and a path names nothing it can read. The reply is the host's
# JSON value: text, segments and word timings, always, because the
# entry exists for callers that cut captions from them.

.has_gpu_host <- function() {
    requireNamespace("gpu.host", quietly = TRUE)
}

# Configured means a base resolves and the token file exists; whether
# the host answers is the preflight's question, asked when a request is
# made rather than every time a route is resolved.
.gpu_host_configured <- function() {
    .has_gpu_host() && gpu.host::gpu_host_configured()
}

# Which catalog entry serves whisper on this host. A property of the
# endpoint, not of stt.api: the fleet's voice row declares whisper-small
# and its image row whisper-large-v3, and a name fixed here would make
# stt() usable against exactly one of them and refuse the other with an
# unknown-entry 400 that reads as a broken service. In order: the
# caller's model, options(stt.gpuhost_entry), then the first whisper
# entry the host's /health lists.
.gpuhost_entry <- function(model = NULL) {
    if (!is.null(model)) {
        return(model)
    }
    opt <- getOption("stt.gpuhost_entry")
    if (is.character(opt) && length(opt) == 1L && !is.na(opt) && nzchar(opt)) {
        return(opt)
    }
    entries <- as.character(gpu.host::gpu_host_health()$entries)
    hit <- entries[startsWith(entries, "whisper")]
    if (!length(hit)) {
        stop("the GPU host serves no whisper entry (it lists: ",
             paste(entries, collapse = ", "), "); name one with model = ",
             "or options(stt.gpuhost_entry = )", call. = FALSE)
    }
    hit[[1L]]
}

#' Internal: Transcribe on the fleet's GPU host
#'
#' One \code{/infer} request through gpu.host. The entry's input is the
#' audio alone: the host's whisper entries take no language, so
#' \code{language} is not sent and the result reports what the host
#' detected. Segments and word timings come back always.
#'
#' @param file Path to the audio file.
#' @param model The catalog entry name, or NULL for the host's whisper
#'   entry (see \code{.gpuhost_entry}).
#' @param language Kept for the result's \code{language} when the host
#'   reports none; not sent.
#' @param diarize Label speakers locally with n3d from the host's word
#'   timings.
#' @return The normalized result list.
#' @keywords internal
.via_gpuhost <- function(file, model = NULL, language = NULL,
                         diarize = FALSE) {
    if (!.has_gpu_host()) {
        stop("source = 'gpuhost' needs the gpu.host package.\n",
             "Install with: remotes::install_github('cornball-ai/gpu.host')",
             call. = FALSE)
    }
    entry <- .gpuhost_entry(model)
    bytes <- readBin(file, "raw", n = file.size(file))
    input <- list(audio_b64 = jsonlite::base64_enc(bytes))
    reply <- gpu.host::gpu_host_infer(entry, input, timeout = .get_timeout())
    v <- gpu.host::gpu_host_value(reply)

    segments <- NULL
    if (is.data.frame(v$segments) && nrow(v$segments) > 0) {
        segments <- .normalize_segments(v$segments)
    }
    out <- list(
                text = v$text %||% "",
                segments = segments,
                language = v$language %||% language,
                backend = "gpuhost",
                raw = v
    )
    if (is.data.frame(v$words) && nrow(v$words) > 0) {
        out$words <- v$words
    }
    if (diarize) {
        out <- .label_locally(file, out)
    }
    out
}

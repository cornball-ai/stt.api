# source = "gpuhost": whisper on the fleet's GPU host through gpu.host.
#
# Everything here runs against gpu.host's request hook, so no host and no
# network: the assertions are about what stt() sends and what it makes of
# the host's value. The route tests fake .has_whisper so they do not
# depend on what this machine has installed.

if (!requireNamespace("gpu.host", quietly = TRUE)) {
    exit_file("gpu.host not installed")
}

# ---- isolate from any real gpu.host configuration on this machine ----
cfg_dir <- tempfile("stt-gpuhost-")
old_cfg <- Sys.getenv("R_USER_CONFIG_DIR", unset = NA)
Sys.setenv(R_USER_CONFIG_DIR = cfg_dir)
old_env <- Sys.getenv(c("GPU_HOST_BASE", "GPU_HOST_TOKEN"), unset = NA)
Sys.unsetenv(c("GPU_HOST_BASE", "GPU_HOST_TOKEN"))
old_opts <- options(gpu.host.base = NULL, gpu.host.token = NULL,
                    gpu.host.http = NULL, stt.gpuhost_entry = NULL,
                    stt.api_base = NULL, stt.timeout = 60)

ns <- asNamespace("stt.api")
with_fake <- function(name, value, expr) {
    orig <- get(name, ns)
    unlockBinding(name, ns)
    assign(name, value, envir = ns)
    on.exit({
        assign(name, orig, envir = ns)
        lockBinding(name, ns)
    }, add = TRUE)
    force(expr)
}
without_whisper <- function(expr) with_fake(".has_whisper", function() FALSE, expr)

# ---- not configured: the route refuses and says how to configure ----
expect_false(stt.api:::.gpu_host_configured())
expect_error(stt.api:::.resolve_route("whisper", "gpuhost"), "gpu_host_config")
expect_error(stt.api:::.resolve_route("auto", "gpuhost"), "gpu_host_config")
expect_error(stt.api:::.resolve_route("openai", "gpuhost"), "backend = 'whisper'")

# ---- configured: base and a token file ----
tok <- tempfile("token-")
writeBin(as.raw(1:32), tok)
options(gpu.host.base = "http://gpu:7878", gpu.host.token = tok)
expect_true(stt.api:::.gpu_host_configured())
expect_equal(stt.api:::.resolve_route("whisper", "gpuhost"),
             list(backend = "whisper", route = "gpuhost"))
expect_equal(stt.api:::.resolve_route("auto", "gpuhost"),
             list(backend = "whisper", route = "gpuhost"))
expect_error(stt.api:::.resolve_route("openai", "gpuhost"), "backend = 'whisper'")

# auto/auto: the in-process package first (unchanged), then the GPU host,
# then the API
r <- without_whisper(stt.api:::.resolve_route("auto", "auto"))
expect_equal(r, list(backend = "whisper", route = "gpuhost"))
options(stt.api_base = "http://api:1")
r <- without_whisper(stt.api:::.resolve_route("auto", "auto"))
expect_equal(r$route, "gpuhost")
options(gpu.host.base = NULL)
r <- without_whisper(stt.api:::.resolve_route("auto", "auto"))
expect_equal(r, list(backend = "openai", route = "api"))
options(stt.api_base = NULL)
expect_error(without_whisper(stt.api:::.resolve_route("auto", "auto")),
             "gpu_host_config")
options(gpu.host.base = "http://gpu:7878")
# an explicit api source is never the GPU host: it still needs a base
expect_error(without_whisper(stt.api:::.resolve_route("whisper", "api")),
             "set_stt_base")
# the whisper engine with the source left open: the package when it is
# installed, else a configured GPU host, else the package's refusal
r <- without_whisper(stt.api:::.resolve_route("whisper", "auto"))
expect_equal(r, list(backend = "whisper", route = "gpuhost"))
options(gpu.host.base = NULL)
expect_error(without_whisper(stt.api:::.resolve_route("whisper", "auto")),
             "not installed")
options(gpu.host.base = "http://gpu:7878")

# ---- the request on the wire, and the result from the value ----
sent <- NULL
answer <- NULL
envelope <- function(x, status = 200L) {
    list(status = status,
         headers = list("content-type" = "application/json"),
         body = charToRaw(as.character(jsonlite::toJSON(x, auto_unbox = TRUE,
                                                        null = "null"))))
}
value <- list(
    text = "the eagle has landed", language = "en",
    segments = data.frame(start = c(0, 1.5), end = c(1.5, 3),
                          text = c("the eagle", "has landed"),
                          stringsAsFactors = FALSE),
    words = data.frame(word = c("the", "eagle", "has", "landed"),
                       start = c(0, 0.5, 1.5, 2.2), end = c(0.5, 1.4, 2.1, 3),
                       stringsAsFactors = FALSE))
health <- list(status = "ok", protocol = "gpu-host/1",
               entries = c("chatterbox-turbo", "whisper-small"), checks = "x")
calls <- list()
options(gpu.host.http = function(method, url, headers, body, timeout) {
    calls[[length(calls) + 1L]] <<- url
    if (grepl("/health$", url)) {
        return(envelope(list(ok = TRUE, value = health)))
    }
    sent <<- list(method = method, url = url, headers = headers, body = body,
                  timeout = timeout)
    answer
})
answer <- envelope(list(ok = TRUE, value = value))

audio <- tempfile(fileext = ".wav")
bytes <- as.raw(c(0x52, 0x49, 0x46, 0x46, 1:200))
writeBin(bytes, audio)

res <- stt(audio, model = "whisper-small", language = "en",
           response_format = "verbose_json", backend = "whisper",
           source = "gpuhost")
expect_equal(sent$method, "POST")
expect_equal(sent$url, "http://gpu:7878/infer")
expect_equal(sent$timeout, 60)
expect_true(startsWith(unname(sent$headers[["Authorization"]]), "Bearer "))
req <- jsonlite::fromJSON(sent$body)
expect_equal(req$v, "gpu-host/1")
expect_equal(req$entry, "whisper-small")
# the audio travels in the request, and nothing else: the entry takes no
# language, so none is sent
expect_equal(names(req$input), "audio_b64")
expect_equal(req$input$audio_b64, jsonlite::base64_enc(bytes))
expect_equal(req$key, gpu.host::gpu_host_key("whisper-small",
                                             list(audio_b64 = jsonlite::base64_enc(bytes))))
# with a model given, no health probe was needed
expect_equal(length(calls), 1L)

expect_equal(res$text, "the eagle has landed")
expect_equal(res$backend, "gpuhost")
expect_equal(res$language, "en")
expect_true(is.data.frame(res$segments))
expect_equal(res$segments$start, c(0, 1.5))
expect_equal(res$segments$text, c("the eagle", "has landed"))
expect_null(res$segments$speaker)
expect_equal(nrow(res$words), 4L)
expect_equal(res$words$word, c("the", "eagle", "has", "landed"))
# the subtitle shape and the provenance, as on every route
expect_true(inherits(res, "stt_result"))
expect_equal(res$data$text, c("the eagle", "has landed"))
cr <- attr(res, "call_record")
expect_equal(cr$request$source, "gpuhost")
expect_equal(cr$request$backend, "whisper")
expect_equal(cr$request$model, "whisper-small")

# the timeout is stt.timeout
options(stt.timeout = 300)
stt(audio, model = "whisper-small", backend = "whisper", source = "gpuhost")
expect_equal(sent$timeout, 300)
options(stt.timeout = 60)

# a value with no segments or words is a plain list, text only
answer <- envelope(list(ok = TRUE, value = list(text = "hm")))
res <- stt(audio, model = "whisper-small", backend = "whisper", source = "gpuhost")
expect_equal(res$text, "hm")
expect_null(res$segments)
expect_null(res$words)
expect_false(inherits(res, "stt_result"))
answer <- envelope(list(ok = TRUE, value = value))

# ---- which entry: model, then the option, then the host's listing ----
options(stt.gpuhost_entry = "whisper-large-v3")
stt(audio, backend = "whisper", source = "gpuhost")
expect_equal(jsonlite::fromJSON(sent$body)$entry, "whisper-large-v3")
options(stt.gpuhost_entry = NULL)
calls <- list()
stt(audio, backend = "whisper", source = "gpuhost")
expect_equal(calls[[1L]], "http://gpu:7878/health")
expect_equal(jsonlite::fromJSON(sent$body)$entry, "whisper-small")
health$entries <- "chatterbox-turbo"
expect_error(stt(audio, backend = "whisper", source = "gpuhost"), "no whisper entry")
health$entries <- c("chatterbox-turbo", "whisper-small")

# ---- the host's refusals surface as they are ----
answer <- list(status = 409L, headers = list("content-type" = "application/json"),
               body = charToRaw('{"ok":false,"error":"same key, different content"}'))
e <- tryCatch(stt(audio, model = "whisper-small", backend = "whisper",
                  source = "gpuhost"), error = function(e) e)
expect_true(inherits(e, "gpu_host_error"))
expect_equal(e$status, 409L)
answer <- envelope(list(ok = FALSE, error = "audio_b64 is not base64"))
expect_error(stt(audio, model = "whisper-small", backend = "whisper",
                 source = "gpuhost"), "audio_b64 is not base64")
answer <- envelope(list(ok = TRUE, value = value))

# ---- speaker labels: the host's words, labelled here ----
# n3d and its weights are stood in for; what matters is that the labeller
# runs on this route and gets the host's word timings
labelled <- NULL
label_stub <- function(file, res) {
    labelled <<- res
    res$segments$speaker <- c("A", "B")
    res$words$speaker <- c("A", "A", "B", "B")
    res
}
res <- with_fake(".has_n3d", function() TRUE,
                 with_fake(".label_locally", label_stub,
                           stt(audio, model = "whisper-small",
                               response_format = "diarized_json",
                               backend = "whisper", source = "gpuhost")))
expect_equal(labelled$words$word, c("the", "eagle", "has", "landed"))
expect_equal(labelled$backend, "gpuhost")
expect_equal(res$segments$speaker, c("A", "B"))
expect_equal(res$words$speaker, c("A", "A", "B", "B"))
# backend "auto" with the GPU host as the source goes local, not to OpenAI
res <- with_fake(".has_n3d", function() TRUE,
                 with_fake(".label_locally", label_stub,
                           stt(audio, model = "whisper-small",
                               response_format = "diarized_json",
                               source = "gpuhost")))
expect_equal(attr(res, "call_record")$request$backend, "whisper")
# ...and so does "auto"/"auto" when no whisper package is installed
res <- without_whisper(with_fake(".has_n3d", function() TRUE,
                                 with_fake(".label_locally", label_stub,
                                           stt(audio, model = "whisper-small",
                                               response_format = "diarized_json"))))
expect_equal(attr(res, "call_record")$request$source, "gpuhost")
# without n3d the request is refused, as on the other local routes
expect_error(with_fake(".has_n3d", function() FALSE,
                       stt(audio, model = "whisper-small",
                           response_format = "diarized_json",
                           backend = "whisper", source = "gpuhost")),
             "n3d")

# ---- stt_health() reports the host, after the package, before the API ----
h <- without_whisper(stt_health())
expect_true(h$ok)
expect_equal(h$backend, "gpuhost")
expect_true(grepl("whisper-small", h$message))
health$entries <- "chatterbox-turbo"
options(stt.api_base = NULL)
h <- without_whisper(stt_health())
expect_false(h$ok)
health$entries <- c("chatterbox-turbo", "whisper-small")

# ---- restore ----
options(old_opts)
for (nm in names(old_env)) {
    if (is.na(old_env[[nm]])) Sys.unsetenv(nm) else do.call(Sys.setenv, as.list(old_env[nm]))
}
if (is.na(old_cfg)) Sys.unsetenv("R_USER_CONFIG_DIR") else Sys.setenv(R_USER_CONFIG_DIR = old_cfg)
unlink(c(audio, tok, cfg_dir), recursive = TRUE)

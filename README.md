# stt.api

[![CRAN status](https://www.r-pkg.org/badges/version/stt.api)](https://CRAN.R-project.org/package=stt.api)

**`stt.api`** is a minimal, backend-agnostic R client for **OpenAI-compatible speech-to-text (STT) APIs**, with optional local fallbacks.

It lets you transcribe audio in R **without caring which backend actually performs the transcription**.

---

## What stt.api is (and is not)

### ✅ What it *is*

* A unified interface for speech-to-text in R
* A way to switch easily between:

  * `{whisper}` (native R torch, local GPU/CPU, in-process)
  * a self-hosted `whisper::serve()` endpoint over HTTP (`source = "api"`)
  * OpenAI `/v1/audio/transcriptions` (cloud or local servers)
* Designed for scripting, Shiny apps, containers, and reproducible pipelines

### ❌ What it is *not*

* Not a Whisper reimplementation
* Not a model manager
* Not a GPU / CUDA helper
* Not an audio preprocessing toolkit
* Not a replacement for `{whisper}`

---

## Installation

```r
install.packages("stt.api")
```

Required dependencies are minimal:

* `curl`
* `jsonlite`

Optional backends:

* `{whisper}` (recommended, on CRAN)

Development version:

```r
remotes::install_github("cornball-ai/stt.api")
```

---

## Quick start

```r
install.packages(c("whisper", "stt.api"))

library(stt.api)

res <- stt("speech.wav")
res$text
```

That's it. With `{whisper}` installed, `stt()` transcribes locally on GPU or CPU with no configuration needed.

---

## Other backends

stt.api also supports OpenAI-compatible APIs for cloud or container-based transcription:

```r
set_stt_base("http://localhost:4123")
# Optional, for hosted services like OpenAI
set_stt_key(Sys.getenv("OPENAI_API_KEY"))

res <- stt("speech.wav", backend = "openai")
```

This works with OpenAI, Whisper containers, LM Studio, OpenWebUI, AnythingLLM, or any server implementing `/v1/audio/transcriptions`.

### Where the engine runs: the `source` axis

`source` selects *where* a backend runs, separately from `backend` (*which*
engine): `"auto"` (default), `"api"` (HTTP), or `"package"` (in-process).
`"auto"` keeps the previous behavior — whisper in-process, openai via the API —
so existing calls are unchanged. To reach a self-hosted `whisper::serve()`
endpoint instead of running whisper in-process:

```r
set_stt_base("http://troy-g5:7809")          # the whisper::serve() endpoint
res <- stt("speech.wav", backend = "whisper", source = "api")
```

---

## Automatic backend selection

When you call `stt()` without specifying a backend, it picks the first available:

1. `{whisper}` (native R torch, if installed)
2. OpenAI-compatible API (if `stt.api_base` is set)
3. Error with guidance

---

## Normalized output

Regardless of backend, `stt()` always returns the same structure:

```r
list(
  text     = "Transcribed text",
  segments = NULL | data.frame(...),
  words    = data.frame(word, start, end),  # only with word-level timing
  language = "en",
  backend  = "api" | "whisper",             # legacy execution route
  raw      = <raw backend response>
)
```

`words` is present only when the API returns word granularity (`verbose_json`);
otherwise it's absent. `backend` reports *where* the engine ran (the legacy
execution route), not the engine itself: the resolved `backend`/`source` pair
lives in the `"call_record"` attribute.

This makes it easy to switch backends without changing downstream code.

---

## Health checks

```r
stt_health()
```

Returns:

```r
list(
  ok = TRUE,
  backend = "api",
  message = "OK"
)
```

Useful for Shiny apps and deployment checks.

---

## Backend selection

Explicit backend choice:

```r
stt("speech.wav", backend = "openai")
stt("speech.wav", backend = "whisper")
```

Automatic selection (default):

```r
stt("speech.wav")
```

---

## Supported endpoints

`stt.api` targets the **OpenAI-compatible STT spec**:

```
POST /v1/audio/transcriptions
```

This is intentionally chosen because it is:

* Widely adopted
* Simple
* Supported by many local and hosted services
* Easy to proxy and containerize

---

## Configuration options

```r
options(
  stt.api_base = NULL,
  stt.api_key  = NULL,
  stt.timeout  = 60
)
```

Setters:

```r
set_stt_base()
set_stt_key()
```

---

## Error handling philosophy

* No silent failures
* Clear messages when a backend is unavailable
* Actionable instructions when configuration is missing

Example:

```
Error in stt():
No transcription backend available.
Install whisper or set stt.api_base.
```

---

## Relationship to tts.api

`stt.api` is designed to pair cleanly with **`tts.api`**:

| Task          | Package  |
| ------------- | -------- |
| Speech → Text | `stt.api` |
| Text → Speech | `tts.api` |

Both share:

* Minimal dependencies
* OpenAI-compatible API focus
* Backend-agnostic design
* Optional Docker support

---

## Why this package exists

Installing and maintaining local Whisper backends can be difficult:

* CUDA / cuBLAS issues
* Compiler toolchains
* Platform differences

`stt.api` lets you **decouple your R code from those concerns**.

Your transcription code stays the same whether the backend is:

* Local
* Containerized
* Cloud-hosted
* GPU-accelerated
* CPU-only

---

## License

MIT

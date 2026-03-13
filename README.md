# stt.api

**`stt.api`** is a minimal, backend-agnostic R client for **OpenAI-compatible speech-to-text (STT) APIs**, with optional local fallbacks.

It lets you transcribe audio in R **without caring which backend actually performs the transcription**.

---

## What stt.api is (and is not)

### ✅ What it *is*

* A thin R wrapper around **OpenAI-style STT endpoints**
* A way to switch easily between:

  * OpenAI `/v1/audio/transcriptions`
  * Local OpenAI-compatible servers (LM Studio, OpenWebUI, AnythingLLM, Whisper containers)
  * Native `{whisper}` (R torch, local GPU) *if available*
  * Local `{audio.whisper}` *if available*
* Designed for scripting, Shiny apps, containers, and reproducible pipelines

### ❌ What it is *not*

* Not a Whisper reimplementation
* Not a model manager
* Not a GPU / CUDA helper
* Not an audio preprocessing toolkit
* Not a replacement for `{whisper}` or `{audio.whisper}`

---

## Installation

```r
# From CRAN (once available)
install.packages("stt.api")

# Development version
remotes::install_github("cornball-ai/stt.api")
```

Required dependencies are minimal:

* `curl`
* `jsonlite`

Optional backends:

* `{whisper}` (native R torch transcription)
* `{audio.whisper}` (local transcription via whisper.cpp)
* `{processx}` (Docker helpers)

---

## Quick start

### 1. Use an OpenAI-compatible API (local or cloud)

```r
library(stt.api)

set_stt_base("http://localhost:4123")
# Optional, for hosted services like OpenAI
set_stt_key(Sys.getenv("OPENAI_API_KEY"))

res <- stt("speech.wav")
res$text
```

This works with:

* OpenAI
* Chatterbox / Whisper containers
* LM Studio
* OpenWebUI
* AnythingLLM
* Any server implementing `/v1/audio/transcriptions`

---

### 2. Use native `{whisper}` (if installed)

```r
res <- stt("speech.wav", backend = "whisper")
res$text
```

Uses the R torch implementation. Runs locally on GPU or CPU.

---

### 3. Use local `{audio.whisper}` (if installed)

```r
res <- stt("speech.wav", backend = "audio.whisper")
res$text
```

If a backend is not installed and you request it explicitly, `stt.api` will error with clear instructions.

---

### 4. Automatic backend selection (default)

```r
res <- stt("speech.wav")
```

Backend priority:

1. `{whisper}` (native R torch, if installed)
2. `{audio.whisper}` (if installed)
3. OpenAI-compatible API (if `stt.api_base` is set)
4. Error with guidance

---

## Normalized output

Regardless of backend, `stt()` always returns the same structure:

```r
list(
  text     = "Transcribed text",
  segments = NULL | data.frame(...),
  language = "en",
  backend  = "api" | "whisper" | "audio.whisper",
  raw      = <raw backend response>
)
```

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
stt("speech.wav", backend = "audio.whisper")
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

## Docker (optional)

If you run Whisper or OpenAI-compatible STT in Docker, `stt.api` can optionally integrate via `{processx}`.

Example use cases:

* Starting a local Whisper container
* Checking container health
* Inspecting logs

Docker helpers are **explicit and opt-in**.
`stt.api` never starts containers automatically.

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
Install whisper, install audio.whisper, or set stt.api_base.
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

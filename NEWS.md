# stt.api 0.2.1.3

* The API backend now requests and parses word-level timestamps: with
  `response_format = "verbose_json"` it sends `timestamp_granularities[]` for
  both `segment` and `word` (requesting word alone can suppress segments on
  OpenAI) and returns `result$words` (word/start/end), matching the native
  whisper backend. Works against OpenAI and a self-hosted `whisper::serve()`.

# stt.api 0.2.1.2

* `stt()` gains a `source` axis ("auto", "api", "package"), mirroring
  `tts.api`'s split of *which* engine from *where* it runs. The default
  ("auto") reproduces the previous behavior (whisper in-process, openai via
  the API), so existing calls are unchanged. `backend = "whisper", source =
  "api"` now reaches a self-hosted whisper `serve()` endpoint (set the URL
  with `set_stt_base()`), instead of having to borrow `backend = "openai"`.

# stt.api 0.2.0

* Remove audio.whisper backend
* Remove gpu.ctl integration
* Remove processx dependency (never implemented)
* Backends are now: whisper (native R torch) and OpenAI-compatible API

# stt.api 0.1.0

* Initial release
* Support for OpenAI-compatible speech-to-text APIs
* Local server support (LM Studio, OpenWebUI, Whisper containers)
* Optional whisper package integration for local transcription
* Segment-level timestamps with word-level timing when available

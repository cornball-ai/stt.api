# stt.api 0.3.0.1

* `stt()` results now carry the shape subtitle tooling expects, so they feed
  `subtitles::whisper_to_srt()` and `subtitles::whisper_to_ass()` directly on
  either route:

  ```r
  x <- stt.api::stt("video.mp4")
  subtitles::whisper_to_srt(x, "video.srt")
  ```

  A result with segments gains a `data` frame of `from`/`to` timestamp strings
  and `text`, and class `c("stt_result", "whisper_transcription")`. Additive:
  `text`, `segments`, `words`, `raw` and the `call_record` attribute are
  unchanged, and results without usable segments are returned as before.

# stt.api 0.3.0

* `stt()` gains a `source` axis ("auto", "api", "package"), mirroring
  `tts.api`'s split of *which* engine from *where* it runs. The default
  ("auto") reproduces the previous behavior (whisper in-process, openai via
  the API), so existing calls are unchanged. `backend = "whisper",
  source = "api"` reaches a self-hosted whisper `serve()` endpoint (set the
  URL with `set_stt_base()`).
* The API backend now requests and parses word-level timestamps: with
  `response_format = "verbose_json"` it sends `timestamp_granularities[]` for
  both `segment` and `word` and returns `result$words` (word/start/end),
  matching the native whisper backend. Works against OpenAI and a self-hosted
  `whisper::serve()`.
* `stt()` results now carry a `"call_record"` attribute (cornball_sidecar v1,
  matching `tts.api`/`xtx.api`): the resolved request, the backend/source
  actually used, elapsed seconds, and a timestamp. Callers that serialize the
  result keep its provenance with it.

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

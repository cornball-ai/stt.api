# stt.api 0.3.1

* New `response_format = "diarized_json"`: speaker-labelled transcription
  through OpenAI's `gpt-4o-transcribe-diarize`.

  ```r
  x <- stt("meeting.wav", model = "gpt-4o-transcribe-diarize",
           response_format = "diarized_json")
  x$segments[, c("start", "end", "speaker", "text")]
  ```

  `segments` gains a `speaker` column carrying whatever labels the provider
  returns, passed through as character without interpretation. The column is
  absent, not NA, for every other format, so `is.null(x$segments$speaker)`
  answers cleanly. Word timings are not
  available with this format, which is OpenAI's restriction rather than
  ours. The result carries the usual `data` frame and class, so diarized
  output captions like any other.

  Two conveniences come with it. `backend = "auto"` resolves straight to
  `"openai"` for this format, since nothing else serves it; an explicit
  `backend = "whisper"` is an error rather than a silently undiarized
  result. And the new `chunking_strategy` argument defaults to `"auto"`
  here, which OpenAI requires for audio longer than 30 seconds.

* `stt()`'s `model` documentation now spells out which model buys which
  timing from OpenAI: `whisper-1` for word-level (with `verbose_json`),
  `gpt-4o-transcribe-diarize` for speaker-labelled segments (with
  `diarized_json`), and plain `gpt-4o-transcribe`/`gpt-4o-mini-transcribe`
  for no timing at all, since they accept only `response_format = "json"`.
  Self-hosted `whisper::serve()` endpoints are unaffected.

* Segment parsing no longer discards a whole response over one bad segment.
  A segment missing `start`, `end` or `text` is dropped on its own; before,
  it collapsed every segment to `NULL`, because `data.frame(start = NULL,
  ...)` is a legal 0-column frame and `rbind` then failed on the width
  mismatch. The failure was intermittent rather than reproducible: the model
  chooses its own segmentation, so the same audio parsed on one call and
  came back empty on the next.

* A 44-second public domain clip ships at
  `system.file("audio", "twospeaker.mp3", package = "stt.api")` for trying
  diarization on: the Apollo 11 landing, LM crew and Houston. See
  `inst/audio/README` for provenance and for why the clip is shaped the way
  it is.

* `stt()` results now carry the shape subtitle tooling expects, so they feed
  `subtitles::whisper_to_srt()` and `subtitles::whisper_to_ass()` directly on
  either route:

  ```r
  x <- stt.api::stt("video.mp4", response_format = "verbose_json")
  subtitles::whisper_to_srt(x, "video.srt")
  ```

  (`verbose_json` matters on the API route, which returns segments only at
  that granularity; the in-process route always returns segments.)

  A result with segments gains a `data` frame of `from`/`to` timestamp strings
  and `text`, and class `c("stt_result", "whisper_transcription")`. Additive:
  `text`, `segments`, `words`, `raw` and the `call_record` attribute are
  unchanged, and results without usable segments are returned as before.

* The copyright holder is now recorded as `cornball.ai`, the registered
  entity, in both `DESCRIPTION` and `LICENSE`.

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

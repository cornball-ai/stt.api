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

  Three things follow from the model rather than the response format, since
  a diarizing model also answers plain `json` and `text`. A request counts
  as diarizing when the format is `diarized_json` or the model name says so,
  and then:

  - `backend = "auto"` resolves straight to `"openai"`, since nothing else
    serves these models. An explicit `backend = "whisper"` is an error
    rather than a silently undiarized result.
  - The new `chunking_strategy` argument defaults to `"auto"`. OpenAI
    refuses a diarizing request over 30 seconds of audio when it is unset,
    in any format. It is defaulted regardless of length, since the duration
    is not known without decoding the file.
  - `prompt` is refused up front. OpenAI answers that combination with HTTP
    400, "Prompt is not supported for diarization models", so the check
    saves an upload rather than adding a restriction of ours.

* New `known_speakers` argument offers your own labels for the segments in
  place of the provider's generic ones. Pass a named vector of short
  reference clips, at most four, and matched segments come back under those
  names:

  ```r
  audio <- system.file("audio", package = "stt.api")
  x <- stt(file.path(audio, "EagleHasLanded.mp3"),
           model = "gpt-4o-transcribe-diarize",
           response_format = "diarized_json",
           known_speakers = c(
               Armstrong = file.path(audio, "ref_armstrong.mp3"),
               Houston   = file.path(audio, "ref_houston.mp3")))
  unique(x$segments$speaker)
  #> [1] "Houston"   "Armstrong"
  ```

  Matching is best-effort. Speakers the model cannot match to a reference
  keep a generic label, so a mixture is normal and worth checking for rather
  than assuming. References also do not re-cut the segmentation: people the
  model has already merged into one cluster, such as several voices sharing
  a radio downlink, are not separated by naming them.

  Each clip should hold one speaker and run roughly 2 to 10 seconds. The
  files are read and sent inline, so the `call_record` keeps the paths
  rather than the encoded audio. Requires `diarized_json`, and says so
  rather than quietly ignoring the argument. No new dependency: jsonlite
  was already an import and does the base64.

* `stt()`'s `model` documentation now spells out which model buys which
  timing from OpenAI: `whisper-1` for word-level (with `verbose_json`),
  `gpt-4o-transcribe-diarize` for speaker-labelled segments (with
  `diarized_json`), and plain `gpt-4o-transcribe`/`gpt-4o-mini-transcribe`
  for no timing at all, since they accept only `response_format = "json"`.
  Self-hosted `whisper::serve()` endpoints are unaffected.

* New `label_speakers()` folds the speaker labels into the caption text, so
  they survive the trip to a subtitle file:

  ```r
  x <- stt("meeting.wav", model = "gpt-4o-transcribe-diarize",
           response_format = "diarized_json")
  subtitles::whisper_to_srt(label_speakers(x), "meeting.srt")
  #> HOUSTON: We copy you down, Eagle.
  #> ARMSTRONG: Tranquility Base here. The Eagle has landed.
  ```

  Diarization puts `speaker` on `segments`, but subtitle tools read `data`,
  which is `from`/`to`/`text` — so the labels were dropped on the way to a
  caption file and everyone wiring the two together wrote the same paste0.
  Only `data$text` changes; `segments` keeps its own text and labels, and
  the class and `call_record` ride through, so the result still feeds
  `whisper_to_srt()` and `whisper_to_ass()` directly. `sep`, `prefix` and
  `suffix` control the styling. Segments whose speaker came back unmatched
  are left alone rather than labelled `NA`.

* Segment parsing no longer discards a whole response over one bad segment.
  A segment missing `start`, `end` or `text` is dropped on its own; before,
  it collapsed every segment to `NULL`, because `data.frame(start = NULL,
  ...)` is a legal 0-column frame and `rbind` then failed on the width
  mismatch. The failure was intermittent rather than reproducible: the model
  chooses its own segmentation, so the same audio parsed on one call and
  came back empty on the next.

* Public domain audio ships in `inst/audio` for trying diarization on: a
  44-second clip of the Apollo 11 landing
  (`system.file("audio", "EagleHasLanded.mp3", package = "stt.api")`), plus
  two short per-speaker clips for `known_speakers`. See `inst/audio/README`
  for provenance and for why the main clip is shaped the way it is.

* `stt()` results now carry the shape subtitle tooling expects, so they feed
  `subtitles::whisper_to_srt()` and `subtitles::whisper_to_ass()` directly on
  either route:

  ```r
  x <- stt.api::stt("video.mp4", response_format = "verbose_json")
  subtitles::whisper_to_srt(x, "video.srt")
  ```

  (The response format matters on the API route, which returns segments only
  for `verbose_json` and `diarized_json`; the in-process route always returns
  segments.)

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

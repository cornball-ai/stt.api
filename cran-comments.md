## R CMD check results

0 errors | 0 warnings | 0 notes

## Test environments

* local Ubuntu 24.04, R 4.6.1
* GitHub Actions: ubuntu-latest, macos-latest
* local Windows, R 4.6.0
* local Windows, R-devel (4.7.0 pre-release)

## Changes since last CRAN release (0.3.0)

- `stt()` results now carry the shape subtitle tooling expects, so they feed
  `subtitles::whisper_to_srt()` and `whisper_to_ass()` directly. A result with
  usable segments gains a `data` frame of `from`/`to` timestamp strings and
  `text`, and class `c("stt_result", "whisper_transcription")`. The change is
  additive: `text`, `segments`, `words`, `raw` and the `call_record` attribute
  are unchanged, and results without usable segments are returned exactly as
  before. No new dependency: the coupling is a data shape, so the tests assert
  the contract directly rather than importing `subtitles`.

- New `response_format = "diarized_json"`, giving speaker-labelled
  transcription through OpenAI's diarizing model. Segments gain a `speaker`
  column for that format only; a new `chunking_strategy` argument defaults to
  "auto" there, which the API requires for audio over 30 seconds. Verified
  against the live endpoint on the bundled 44-second clip.

- `stt()`'s `model` documentation now records which model yields which
  timing from OpenAI: "whisper-1" for word-level, "gpt-4o-transcribe-diarize"
  for speaker-labelled segments, and the plain gpt-4o transcription models
  for none, since they accept `response_format = "json"` alone.

- New `known_speakers` argument for that format: a named vector of short
  per-speaker reference clips, whose names replace the provider's generic
  speaker labels in the result. No new dependency; jsonlite was already
  imported and provides the base64 encoding.

- Segment parsing no longer discards an entire response over one malformed
  segment; the bad segment alone is dropped.

- Public domain audio is bundled in `inst/audio` for exercising diarization
  (Apollo 11 landing, a work of the US Government; provenance in
  `inst/audio/README`): a 44-second clip plus two short per-speaker
  reference clips, around 220 KB in total. The tests that use them are gated
  on both `at_home()` and a configured API key, so they never run during
  checks.

- The copyright holder is recorded as `cornball.ai`, the registered entity,
  in both `DESCRIPTION` and `LICENSE`. It previously read "Cornball AI",
  which is not the legal name.

## Reverse dependencies

None.

## Notes

The optional `whisper` backend is in Suggests and is only exercised when
`whisper` is installed; all such code is guarded with `requireNamespace()`.

## R CMD check results

0 errors | 0 warnings | 0 notes

## Test environments

* local Ubuntu 24.04, R 4.6.0
* GitHub Actions: ubuntu-latest, macos-latest
* local Windows, R 4.6.0
* local Windows, R-devel (4.7.0 pre-release)

## Changes since last CRAN release (0.2.1)

- `stt()` gains a `source` axis ("auto", "api", "package") to choose where a
  backend runs (in-process vs HTTP), defaulting to the previous behavior.
- The API backend requests and parses word-level timestamps for
  `verbose_json` (`result$words`), matching the native whisper backend.
- `stt()` results now carry a `"call_record"` attribute (resolved request,
  backend/source used, elapsed seconds, timestamp) for provenance.

## Reverse dependencies

None.

## Notes

The optional `whisper` backend is in Suggests and is only exercised when
`whisper` is installed; all such code is guarded with `requireNamespace()`.

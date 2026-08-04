# stt.api

Speech-to-text API client for R.

## Exports

| Function | Purpose |
|----------|---------|
| `stt(file, model, language, backend)` | Transcribe audio to text |
| `set_stt_base(url)` | Set API endpoint |
| `set_stt_key(key)` | Set API key |
| `clear_native_whisper_cache()` | Free GPU/RAM from native backend |

## Backends

| Backend | Description | Segments |
|---------|-------------|----------|
| `whisper` | Native R torch whisper | **No** (text only) |
| `openai` | OpenAI Whisper API | Yes |
| `auto` | Try backends in order | Depends |

### Backend Selection

```r
# OpenAI API (recommended for segments)
set_stt_base("https://api.openai.com")
set_stt_key(Sys.getenv("OPENAI_API_KEY"))
stt("audio.wav", backend = "openai", response_format = "verbose_json")

# Native whisper (fast, but no segment timing)
stt("audio.wav", backend = "whisper", model = "large-v3")
```

## Options

```r
options(stt.api_base = "https://api.openai.com")  # API endpoint
options(stt.api_key = "sk-...")                    # API key
options(stt.timeout = 120)                         # Request timeout (seconds)
```

## Timing by route

Every route returns segments now. What differs is what you have to ask for.

| Route | Segments | Word timings |
|---|---|---|
| whisper in-process | always | always (`word_timestamps = TRUE` is passed for you) |
| whisper `serve()` over HTTP | always | `response_format = "verbose_json"` |
| OpenAI, `whisper-1` | `verbose_json` | `verbose_json` |
| OpenAI, `gpt-4o-transcribe-diarize` | `diarized_json`, plus a `speaker` column | never; OpenAI does not offer them alongside diarization |
| OpenAI, `gpt-4o-transcribe` and relatives | never | never; they accept `json` only |

Anything with usable segments also carries `$data` and class
`c("stt_result", "whisper_transcription")`, so it feeds
`subtitles::whisper_to_srt()` and `whisper_to_ass()` directly. Karaoke
(`whisper_to_ass(karaoke = TRUE)`) needs the word timings, so pick a route
from the right-hand column.

(This section previously said the native whisper backend returned no
segments at all, and pointed at OpenAI as the workaround. That stopped
being true with whisper 0.4.1 and stt.api 0.3.0.)

## Before submitting to CRAN

Run this against the real working tree, every time:

```bash
bash tools/check_tarball.sh
```

`R CMD build` packages the working **directory**, not the git tree, and it
does not skip arbitrary dot-directories -- only a fixed known set. So any
untracked scratch left in the package root ships. This has already happened
twice in sibling packages: a `git worktree add` left a full second copy of
whisper inside whisper, and a temporary clone of an unrelated package in
the subtitles root contributed 179 of 213 tarball entries.

CI runs the same validator, but **CI cannot catch this class** -- it checks
out a clean tree, so untracked local files do not exist there. The local run
is the only thing that sees them.

Also run win-builder before submitting, on both release and devel:

```r
tinypkgr::check_win_devel()
```

A local `R CMD check` is not a substitute. whisper 0.5.0 was clean on four
environments and still came back from win-builder with `Status: 1 ERROR`,
from a test that guarded on `requireNamespace("torch")` instead of
`torch::torch_is_installed()`.

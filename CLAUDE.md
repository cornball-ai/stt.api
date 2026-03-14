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
| `audio.whisper` | audio.whisper R package | Yes |
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
options(stt.gpuctl = TRUE)                         # Enable GPU management
```

## Known Issues

### Native whisper backend returns no segments

The native `whisper` R package (cornball-ai/whisper) currently returns only text, not word/segment timing. This means `result$segments` is NULL.

**Workaround**: Use `backend = "openai"` with `response_format = "verbose_json"` to get segment timing.

**TODO**: Add segment timing to native whisper package. The underlying torch model supports this - need to extract token timestamps during decoding and convert to segment boundaries.

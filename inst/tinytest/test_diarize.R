# Tests for diarized_json support: segment parsing (R/internal_api.R) and
# the routing rules stt() applies to it (R/stt.R).
#
# Everything here runs offline against fabricated responses, EXCEPT the block
# at the bottom, which makes a real billed OpenAI request. That block is gated
# on at_home() and on OPENAI_API_KEY being set, so it never runs under
# R CMD check and never runs without a key.

# The shape OpenAI returns for response_format = "diarized_json", as
# jsonlite::fromJSON(simplifyVector = FALSE) delivers it.
diarized <- list(
    list(type = "transcript.text.segment", id = "seg_0", start = 0.3,
         end = 4.25, speaker = "A", text = "Ask not what your country"),
    list(type = "transcript.text.segment", id = "seg_1", start = 5,
         end = 7.3, speaker = "B", text = "can do for you"))

# The same, from verbose_json: no speaker anywhere.
plain <- list(
    list(id = 0L, start = 0.3, end = 4.25, text = "Ask not what your country"),
    list(id = 1L, start = 5, end = 7.3, text = "can do for you"))

# ---- diarized segments gain a speaker column ----

d <- stt.api:::.parse_api_segments(diarized)

expect_true(is.data.frame(d))
expect_equal(names(d), c("start", "end", "text", "speaker"))
expect_equal(nrow(d), 2L)
expect_equal(d$speaker, c("A", "B"))
expect_equal(d$start, c(0.3, 5))
expect_equal(d$end, c(4.25, 7.3))
expect_true(is.numeric(d$start))
expect_true(is.numeric(d$end))

# ---- undiarized segments have no speaker column at all ----
# Absent, not a column of NA: callers branch on is.null(segments$speaker).

p <- stt.api:::.parse_api_segments(plain)

expect_equal(names(p), c("start", "end", "text"))
expect_null(p$speaker)
expect_equal(nrow(p), 2L)

# ---- a response missing speaker on some segments keeps every segment ----
# The column decision is made once for the whole response. Made per row, the
# frames would differ in width and rbind would drop the lot.

mixed <- diarized
mixed[[2]]$speaker <- NULL
m <- stt.api:::.parse_api_segments(mixed)

expect_equal(nrow(m), 2L)
expect_true("speaker" %in% names(m))
expect_equal(m$speaker, c("A", NA_character_))
expect_equal(m$text, c("Ask not what your country", "can do for you"))

# ---- degenerate inputs ----

expect_null(stt.api:::.parse_api_segments(NULL))
expect_null(stt.api:::.parse_api_segments(list()))

# A malformed segment list yields NULL rather than an error. Note
# data.frame(start = NULL, end = NULL, text = NULL) is a legal 0-column
# frame, not an error, so the tryCatch alone would let it through.
expect_null(stt.api:::.parse_api_segments(list(list(nonsense = TRUE))))
expect_null(stt.api:::.parse_api_segments(
    list(list(start = 0, end = 1))))  # no text

# ---- one bad segment must not discard the good ones ----
# Regression: the model chooses its own segmentation, so a response can carry
# a segment missing start/end/text. Building rows unguarded made that single
# segment collapse the entire response to NULL -- intermittently, since the
# same audio segments differently call to call.

partial <- list(
    diarized[[1]],
    list(type = "transcript.text.segment", id = "seg_x", speaker = "B"),
    diarized[[2]])
pr <- stt.api:::.parse_api_segments(partial)

expect_equal(nrow(pr), 2L)
expect_equal(pr$speaker, c("A", "B"))
expect_equal(pr$start, c(0.3, 5))

# Same for a segment whose fields are present but not scalars.
vec <- list(diarized[[1]],
            list(start = c(1, 2), end = c(3, 4), text = "two", speaker = "B"))
expect_equal(nrow(stt.api:::.parse_api_segments(vec)), 1L)

# ---- the subtitle shape rides on diarized output too ----
# speaker is extra; from/to/text still come off start/end/text.

res <- stt.api:::.attach_subtitle_shape(
    list(text = "Ask not what your country can do for you", segments = d,
         language = "en", backend = "api", raw = list()))

expect_equal(class(res), c("stt_result", "whisper_transcription"))
expect_equal(res$data$from, c("00:00:00.300", "00:00:05.000"))
expect_equal(res$data$to, c("00:00:04.250", "00:00:07.300"))
expect_equal(names(res$data), c("from", "to", "text"))
# The speaker labels stay on $segments; $data is the caption contract only.
expect_equal(res$segments$speaker, c("A", "B"))

# ---- stt() routing rules for diarized_json ----

# Any existing file does: stt() checks file.exists() and then fails on
# routing, well before anything reads a byte of audio.
f <- system.file("DESCRIPTION", package = "stt.api")
expect_true(file.exists(f))

old <- options(stt.api_base = NULL, stt.api_key = NULL)

# Explicitly asking for whisper while asking for speaker labels is an error,
# not a silently undiarized result.
expect_error(
    stt(f, response_format = "diarized_json", backend = "whisper"),
    "requires backend = 'openai'")

# backend = "auto" resolves to openai rather than to in-process whisper, so
# with no base URL set the failure is the missing endpoint, not the backend.
expect_error(
    stt(f, response_format = "diarized_json"),
    "no API base URL is set")

# The format is a real choice, not a typo caught by match.arg.
expect_true("diarized_json" %in% eval(formals(stt)$response_format))

options(old)

# ---- live: real two-speaker audio through OpenAI ----
# Never during R CMD check, and only when a key is actually configured: this
# spends money and needs the network. The bundled clip is 44s of the Apollo
# 11 landing (public domain; see inst/audio/README) -- the LM crew, then
# Houston. It runs past 30s, which is where OpenAI starts requiring
# chunking_strategy for this format.

key <- Sys.getenv("OPENAI_API_KEY")
clip <- system.file("audio", "twospeaker.mp3", package = "stt.api")

if (at_home() && nzchar(key) && nzchar(clip)) {
    old_live <- options(stt.api_base = "https://api.openai.com",
                        stt.api_key = key, stt.timeout = 300)

    # Restored before any assertion runs. Left until after the expectations,
    # a network error or a failed expectation would skip the restore and leak
    # a live base URL and API key into every test file sourced after this one.
    live <- tryCatch(stt(clip, model = "gpt-4o-transcribe-diarize",
                         response_format = "diarized_json"),
                     error = function(e) e)
    options(old_live)

    # A transport failure is one clear red assertion, not a torn-off file.
    expect_false(inherits(live, "error"))
}

if (at_home() && nzchar(key) && nzchar(clip) && !inherits(live, "error")) {
    # The whole point of the format: more than one speaker came back.
    expect_true("speaker" %in% names(live$segments))
    expect_true(length(unique(live$segments$speaker)) >= 2L)
    expect_true(all(nzchar(live$segments$speaker)))

    # Timing is real and ordered, and covers past the 30s chunking boundary,
    # which is the evidence that chunking_strategy went out and was accepted.
    expect_true(is.numeric(live$segments$start))
    expect_true(all(diff(live$segments$start) >= 0))
    expect_true(max(live$segments$end) > 30)

    # Diarized output still captions.
    expect_true(inherits(live, "whisper_transcription"))
    expect_equal(nrow(live$data), nrow(live$segments))

    # OpenAI does not offer word timings alongside diarization.
    expect_null(live$words)

    # The record reports the chunking strategy actually sent.
    expect_equal(attr(live, "call_record")$request$chunking_strategy, "auto")
}

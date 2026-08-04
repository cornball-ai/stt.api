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

# ...and that error must not depend on whisper being installed. Route
# resolution also decides availability, so checking the resolved route
# instead of the argument raised "package is not installed" first on any
# machine without whisper -- green locally, red on CI. Stubbing the
# availability probe pins the ordering.
local({
    orig <- stt.api:::.has_whisper
    assignInNamespace(".has_whisper", function() FALSE, ns = "stt.api")
    on.exit(assignInNamespace(".has_whisper", orig, ns = "stt.api"),
            add = TRUE)
    expect_error(
        stt(f, response_format = "diarized_json", backend = "whisper"),
        "requires backend = 'openai'")
})

# backend = "auto" resolves to openai rather than to in-process whisper, so
# with no base URL set the failure is the missing endpoint, not the backend.
expect_error(
    stt(f, response_format = "diarized_json"),
    "no API base URL is set")

# Same for a diarizing model asked for plain json, which carries no
# diarized_json anywhere. Keyed on the format instead of the model, this
# stayed on "auto" and .resolve_route() picked whisper/package wherever
# whisper happened to be installed -- dispatching an OpenAI model name to
# the in-process engine. Stubbing availability both ways pins the routing
# regardless of what the test machine has.
for (installed in c(TRUE, FALSE)) {
    local({
        orig <- stt.api:::.has_whisper
        assignInNamespace(".has_whisper", function() installed,
                          ns = "stt.api")
        on.exit(assignInNamespace(".has_whisper", orig, ns = "stt.api"),
                add = TRUE)
        expect_error(
            stt(f, model = "gpt-4o-transcribe-diarize",
                response_format = "json"),
            "no API base URL is set", info = paste("whisper:", installed))
    })
}

# The format is a real choice, not a typo caught by match.arg.
expect_true("diarized_json" %in% eval(formals(stt)$response_format))

options(old)

# ---- known_speakers: encoding and validation, all offline ----

audio <- system.file("audio", package = "stt.api")
ref_a <- file.path(audio, "ref_armstrong.mp3")
ref_h <- file.path(audio, "ref_houston.mp3")

expect_true(file.exists(ref_a))
expect_true(file.exists(ref_h))

# MIME comes off the extension; an unknown container is an error rather than
# a guess, because a wrong type fails server-side with a worse message.
expect_equal(stt.api:::.audio_mime("a.mp3"), "audio/mpeg")
expect_equal(stt.api:::.audio_mime("a.WAV"), "audio/wav")
expect_equal(stt.api:::.audio_mime("a.m4a"), "audio/mp4")
expect_equal(stt.api:::.audio_mime("/tmp/x/a.flac"), "audio/flac")
expect_error(stt.api:::.audio_mime("a.aiff"), "Cannot determine an audio MIME")
expect_error(stt.api:::.audio_mime("noextension"), "Cannot determine an audio MIME")

# Every container OpenAI accepts as transcription input is accepted here,
# since a reference clip may be in any of them. mpeg and mpga are easy to
# miss because no common encoder writes those extensions by default.
for (e in c("flac", "m4a", "mp3", "mp4", "mpeg", "mpga", "ogg", "wav",
            "webm")) {
    expect_true(is.character(stt.api:::.audio_mime(paste0("a.", e))),
                info = e)
}
expect_equal(stt.api:::.audio_mime("a.mpga"), "audio/mpeg")
expect_equal(stt.api:::.audio_mime("a.mpeg"), "audio/mpeg")

# The reference clip goes inline as a data URI, not as a file part.
uri <- stt.api:::.audio_data_uri(ref_a)
expect_true(is.character(uri))
expect_equal(length(uri), 1L)
expect_true(startsWith(uri, "data:audio/mpeg;base64,"))

# Round-trips to the original bytes: the payload is the file, not a summary.
b64 <- sub("^data:audio/mpeg;base64,", "", uri)
expect_equal(jsonlite::base64_dec(b64),
             readBin(ref_a, "raw", n = file.size(ref_a)))

# One unbroken run, no whitespace. jsonlite::base64_enc() hard-wraps at 72
# columns by default, and those newlines get the field rejected server-side
# with a message that says nothing about whitespace.
expect_false(grepl("[[:space:]]", uri))

expect_error(stt.api:::.audio_data_uri(file.path(audio, "nope.mp3")),
             "Speaker reference file not found")

# ---- known_speakers validation ----

expect_null(stt.api:::.validate_known_speakers(NULL))
expect_null(stt.api:::.validate_known_speakers(character(0)))
expect_silent(stt.api:::.validate_known_speakers(c(A = ref_a, B = ref_h)))

expect_error(stt.api:::.validate_known_speakers(c(ref_a, ref_h)),
             "must be named")
expect_error(stt.api:::.validate_known_speakers(setNames(ref_a, "")),
             "must be named")
expect_error(stt.api:::.validate_known_speakers(c(A = ref_a, A = ref_h)),
             "must be unique")
expect_error(stt.api:::.validate_known_speakers(list(A = ref_a)),
             "character vector")

# OpenAI caps this at four; the error names the limit rather than arriving
# as a generic 400.
five <- setNames(rep(ref_a, 5), LETTERS[1:5])
expect_error(stt.api:::.validate_known_speakers(five), "At most 4")

expect_error(stt.api:::.validate_known_speakers(c(A = "/nonexistent/x.mp3")),
             "not found")

# Named speakers are meaningless outside the diarizing format, and silently
# ignoring them would return generic labels with no hint why.
expect_error(
    stt(f, response_format = "verbose_json", backend = "openai",
        known_speakers = c(A = ref_a)),
    "requires response_format = 'diarized_json'")

# ---- diarizing-model detection ----
# Two OpenAI rules key on the model rather than the response format, both
# confirmed live with response_format = "json":
#   HTTP 400: chunking_strategy is required for diarization models
#   HTTP 400: Prompt is not supported for diarization models
# So the predicate has to see the model, not just the format.

isd <- stt.api:::.is_diarizing

expect_true(isd("gpt-4o-transcribe-diarize", "json"))
expect_true(isd("gpt-4o-transcribe-diarize", "text"))
expect_true(isd("GPT-4O-TRANSCRIBE-DIARIZE", "json"))
expect_true(isd(NULL, "diarized_json"))       # format alone implies it
expect_true(isd("whisper-1", "diarized_json"))

expect_false(isd("whisper-1", "json"))
expect_false(isd("gpt-4o-transcribe", "verbose_json"))
expect_false(isd(NULL, "json"))
expect_false(isd(NA_character_, "json"))
expect_false(isd(c("a", "b"), "json"))
expect_false(isd(character(0), "json"))

# ---- prompt is incompatible with diarizing models ----
# Caught locally so the combination fails before the audio is uploaded.

expect_error(
    stt(f, response_format = "diarized_json", prompt = "Tranquility Base"),
    "prompt is not supported")

# The case the format-only guard missed: the diarizing model also serves
# plain json, and refuses prompt there too.
expect_error(
    stt(f, model = "gpt-4o-transcribe-diarize", response_format = "json",
        backend = "openai", prompt = "Tranquility Base"),
    "prompt is not supported")

# Both at once still reports the prompt problem rather than dying somewhere
# less obvious.
expect_error(
    stt(f, response_format = "diarized_json", prompt = "x",
        known_speakers = c(A = ref_a)),
    "prompt is not supported")

# The restriction is the model's, not the format's: prompt stays legal on a
# non-diarizing model, so this must get past argument checking to the
# missing endpoint instead. Naming the model is the point of the test --
# omitting it would encode the format boundary that was wrong.
expect_error(
    stt(f, model = "whisper-1", response_format = "verbose_json",
        backend = "openai", prompt = "Tranquility Base"),
    "no API base URL is set")

# ---- live: real two-speaker audio through OpenAI ----
# Never during R CMD check, and only when a key is actually configured: this
# spends money and needs the network. The bundled clip is 44s of the Apollo
# 11 landing (public domain; see inst/audio/README) -- the LM crew, then
# Houston. It runs past 30s, which is where OpenAI starts requiring
# chunking_strategy for this format.

key <- Sys.getenv("OPENAI_API_KEY")
clip <- system.file("audio", "EagleHasLanded.mp3", package = "stt.api")

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

# ---- live: known_speakers replaces the generic labels ----

if (at_home() && nzchar(key) && nzchar(clip)) {
    speakers <- c(Armstrong = ref_a, Houston = ref_h)

    old_named <- options(stt.api_base = "https://api.openai.com",
                         stt.api_key = key, stt.timeout = 300)
    named <- tryCatch(stt(clip, model = "gpt-4o-transcribe-diarize",
                          response_format = "diarized_json",
                          known_speakers = speakers),
                      error = function(e) e)
    options(old_named)

    expect_false(inherits(named, "error"))
}

if (at_home() && nzchar(key) && nzchar(clip) && !inherits(named, "error")) {
    got <- unique(named$segments$speaker)

    # The contract under test is that our names went out and were used, not
    # that every speaker gets matched. Matching is best-effort: unmatched
    # speakers keep a generic label, so requiring every label to be one of
    # ours would go red on a partial match, which is documented behaviour
    # rather than a defect.
    expect_true(length(got) > 0)
    expect_true(any(got %in% names(speakers)))

    # Paths, not the encoded clips, in the provenance record.
    expect_equal(attr(named, "call_record")$request$known_speakers, speakers)
}

# ---- live: the diarizing model on plain json ----
# Regression for a boundary that was drawn on the response format when the
# rule is the model's. This call carries no diarized_json anywhere, so a
# chunking default keyed on the format never fires; the bundled clip is 44s,
# and OpenAI refuses a diarizing request over 30s with an unset
# chunking_strategy ("chunking_strategy is required for diarization
# models"). If it succeeds, the default reached the wire.
#
# backend is left at "auto" deliberately. Naming "openai" would mask the
# routing half of the same bug, where a diarizing model on plain json stayed
# on "auto" and resolved to in-process whisper.

if (at_home() && nzchar(key) && nzchar(clip)) {
    old_pj <- options(stt.api_base = "https://api.openai.com",
                      stt.api_key = key, stt.timeout = 300)
    plainjson <- tryCatch(stt(clip, model = "gpt-4o-transcribe-diarize",
                              response_format = "json"),
                          error = function(e) e)
    options(old_pj)

    expect_false(inherits(plainjson, "error"))
}

if (at_home() && nzchar(key) && nzchar(clip) &&
    !inherits(plainjson, "error")) {
    expect_true(nchar(plainjson$text) > 0)
    expect_equal(attr(plainjson, "call_record")$request$chunking_strategy,
                 "auto")
    # Routed to OpenAI from backend = "auto", not to in-process whisper.
    expect_equal(attr(plainjson, "call_record")$request$backend, "openai")
    expect_equal(attr(plainjson, "call_record")$request$source, "api")
}

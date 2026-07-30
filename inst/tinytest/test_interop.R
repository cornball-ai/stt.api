# Tests for the subtitle-tool interop shape (R/internal_interop.R).
# Pure data reshaping: no network, no model, no whisper install needed.

# ---- .format_hms ----

expect_equal(stt.api:::.format_hms(0), "00:00:00.000")
expect_equal(stt.api:::.format_hms(7.4), "00:00:07.400")
expect_equal(stt.api:::.format_hms(61.25), "00:01:01.250")
expect_equal(stt.api:::.format_hms(3661.5), "01:01:01.500")

# Rounds to whole milliseconds before splitting, so a value just under a
# boundary carries instead of printing a 60th second.
expect_equal(stt.api:::.format_hms(59.9996), "00:01:00.000")
expect_equal(stt.api:::.format_hms(3599.9999), "01:00:00.000")

# sprintf()'s %d rejects non-finite doubles, so the guard catches infinities
# and not just missings.
expect_equal(stt.api:::.format_hms(-1), "00:00:00.000")
expect_equal(stt.api:::.format_hms(NA_real_), "00:00:00.000")
expect_equal(stt.api:::.format_hms(NaN), "00:00:00.000")
expect_equal(stt.api:::.format_hms(Inf), "00:00:00.000")
expect_equal(stt.api:::.format_hms(-Inf), "00:00:00.000")

# ---- .attach_subtitle_shape ----
# The shape both .via_api() and .via_whisper() return.

mk <- function(backend = "api") {
    list(text = "one two",
         segments = data.frame(start = c(0, 2.5), end = c(2.5, 5),
                               text = c("one", "two"),
                               stringsAsFactors = FALSE),
         language = "en", backend = backend, raw = list(dummy = TRUE))
}

out <- stt.api:::.attach_subtitle_shape(mk())

expect_equal(class(out), c("stt_result", "whisper_transcription"))
expect_true(inherits(out, "whisper_transcription"))

expect_true(is.data.frame(out$data))
expect_equal(names(out$data), c("from", "to", "text"))
expect_equal(out$data$from, c("00:00:00.000", "00:00:02.500"))
expect_equal(out$data$to, c("00:00:02.500", "00:00:05.000"))
expect_equal(out$data$text, c("one", "two"))

# Purely additive: nothing that was there before moved or changed.
expect_equal(out$text, "one two")
expect_equal(out$language, "en")
expect_equal(out$backend, "api")
expect_equal(out$segments, mk()$segments)
expect_equal(out$raw, list(dummy = TRUE))

# Both routes get the same treatment.
expect_equal(class(stt.api:::.attach_subtitle_shape(mk("whisper"))),
             c("stt_result", "whisper_transcription"))

# Word timings ride through untouched for karaoke.
res_w <- mk()
res_w$words <- data.frame(word = c("one", "two"), start = c(0, 2.5),
                          end = c(0.5, 3), stringsAsFactors = FALSE)
expect_equal(stt.api:::.attach_subtitle_shape(res_w)$words, res_w$words)

# ---- nothing to caption: returned unchanged and unclassed ----

bare <- list(text = "one two", language = "en", backend = "api")
expect_identical(stt.api:::.attach_subtitle_shape(bare), bare)
expect_false(inherits(stt.api:::.attach_subtitle_shape(bare),
                      "whisper_transcription"))

empty <- mk()
empty$segments <- data.frame(start = numeric(0), end = numeric(0),
                             text = character(0))
expect_identical(stt.api:::.attach_subtitle_shape(empty), empty)

# A segments frame missing the columns we'd read is left alone rather than
# producing a malformed $data.
odd <- mk()
odd$segments <- data.frame(a = 1, b = 2)
expect_identical(stt.api:::.attach_subtitle_shape(odd), odd)

# ---- the contract subtitles:: checks ----
# subtitles::whisper_to_srt()/whisper_to_ass() do exactly two things with the
# object: stopifnot(inherits(x, "whisper_transcription")), then read $data's
# from/to/text. Asserting the contract directly keeps stt.api from depending
# on a subtitle package -- the coupling is a data shape, not a package edge.

expect_true(inherits(out, "whisper_transcription"))
expect_true(all(c("from", "to", "text") %in% names(out$data)))
expect_true(is.character(out$data$from))
expect_true(is.character(out$data$to))
expect_equal(nrow(out$data), nrow(out$segments))
expect_true(all(grepl("^\\d{2}:\\d{2}:\\d{2}\\.\\d{3}$",
                      c(out$data$from, out$data$to))))

# ---- the call_record attribute survives the reshaping ----
# .attach_subtitle_shape() runs before the attribute is set in stt(), but
# assigning $data and the class must not disturb an attribute either way.

tagged <- mk()
attr(tagged, "call_record") <- list(cornball_sidecar = 1L, fn = "stt")
expect_equal(attr(stt.api:::.attach_subtitle_shape(tagged), "call_record"),
             list(cornball_sidecar = 1L, fn = "stt"))

# Tests for label_speakers(). No network, no API key.

mk <- function(speaker = c("HOUSTON", "ARMSTRONG")) {
    segs <- data.frame(
        start = c(0, 2.5), end = c(2.5, 5),
        text = c("We copy you down, Eagle.", "The Eagle has landed."),
        stringsAsFactors = FALSE)
    segs$speaker <- speaker
    structure(
        list(text = "We copy you down, Eagle. The Eagle has landed.",
             segments = segs,
             data = data.frame(
                 from = c("00:00:00.000", "00:00:02.500"),
                 to = c("00:00:02.500", "00:00:05.000"),
                 text = segs$text, stringsAsFactors = FALSE),
             language = "en", backend = "api"),
        class = c("stt_result", "whisper_transcription"))
}

# ---- the default fold ----

out <- label_speakers(mk())

expect_equal(out$data$text,
             c("HOUSTON: We copy you down, Eagle.",
               "ARMSTRONG: The Eagle has landed."))

# Only data$text moves. segments keeps its own text and the labels, so the
# raw transcription is still available unmangled.
expect_equal(out$segments$text, mk()$segments$text)
expect_equal(out$segments$speaker, c("HOUSTON", "ARMSTRONG"))
expect_equal(out$data$from, mk()$data$from)
expect_equal(out$data$to, mk()$data$to)
expect_equal(out$text, mk()$text)

# The subtitle contract survives, which is the whole point.
expect_equal(class(out), c("stt_result", "whisper_transcription"))
expect_true(inherits(out, "whisper_transcription"))
expect_equal(names(out$data), c("from", "to", "text"))

# ---- separators and brackets ----

expect_equal(label_speakers(mk(), sep = " - ")$data$text[1],
             "HOUSTON - We copy you down, Eagle.")
expect_equal(
    label_speakers(mk(), prefix = "[", suffix = "]", sep = " ")$data$text[1],
    "[HOUSTON] We copy you down, Eagle.")
expect_equal(label_speakers(mk(), sep = "\n")$data$text[1],
             "HOUSTON\nWe copy you down, Eagle.")

# ---- a segment with no speaker is left unlabelled ----
# This is a response that omitted the field for a segment, or an object
# assembled by hand. It is NOT what a partial known_speakers match looks
# like: a speaker the provider cannot match to a reference keeps a generic
# label, and gets labelled with it. Either way "NA: " on screen would be
# worse than no label.

no_speaker_row <- label_speakers(mk(c("HOUSTON", NA)))
expect_equal(no_speaker_row$data$text,
             c("HOUSTON: We copy you down, Eagle.",
               "The Eagle has landed."))

# A generic label is a label: it gets used, not skipped. This is the shape a
# real unmatched speaker arrives in.
generic <- label_speakers(mk(c("HOUSTON", "B")))
expect_equal(generic$data$text,
             c("HOUSTON: We copy you down, Eagle.",
               "B: The Eagle has landed."))

empty <- label_speakers(mk(c("", "ARMSTRONG")))
expect_equal(empty$data$text,
             c("We copy you down, Eagle.",
               "ARMSTRONG: The Eagle has landed."))

# ---- leading whitespace from the provider is trimmed ----
# Diarized segment text arrives with a leading space, which would otherwise
# render as "HOUSTON:  text".

spaced <- mk()
spaced$data$text <- paste0(" ", spaced$data$text)
expect_equal(label_speakers(spaced)$data$text[1],
             "HOUSTON: We copy you down, Eagle.")

# ---- the call_record rides through ----

tagged <- mk()
attr(tagged, "call_record") <- list(cornball_sidecar = 1L, fn = "stt")
expect_equal(attr(label_speakers(tagged), "call_record"),
             list(cornball_sidecar = 1L, fn = "stt"))

# ---- refusals ----

no_speaker <- mk()
no_speaker$segments$speaker <- NULL
expect_error(label_speakers(no_speaker), "No speaker labels")

no_data <- mk()
no_data$data <- NULL
expect_error(label_speakers(no_data), "No captionable segments")

empty_data <- mk()
empty_data$data <- empty_data$data[0, ]
expect_error(label_speakers(empty_data), "No captionable segments")

# A row-count mismatch means the object was edited by hand. Recycling the
# labels would caption the wrong lines with the wrong names, which is worse
# than refusing.
mismatch <- mk()
mismatch$data <- mismatch$data[1, ]
expect_error(label_speakers(mismatch), "disagree on row count")

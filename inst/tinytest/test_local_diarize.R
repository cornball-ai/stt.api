# ---- word-to-speaker assignment, offline ----

assign <- stt.api:::.assign_speakers
group <- stt.api:::.group_words

# 3 s at 10 ms frames: speaker 1 talks for the first second, speaker 2 from
# 1.5 s on, overlapping neither; 1.0-1.5 s is silence.
probs <- matrix(0, 300, 8)
probs[1:100, 1] <- 0.9
probs[151:300, 2] <- 0.8

words <- data.frame(
    word = c("Hello", "there.", "Hi", "back."),
    start = c(0.0, 0.5, 1.6, 2.2),
    end = c(0.4, 0.9, 2.0, 2.8),
    stringsAsFactors = FALSE)
spk <- assign(words$start, words$end, probs)
expect_equal(spk, c("A", "A", "B", "B"))

# the larger activity mass wins when a word straddles a change:
# 0.5 s of A at 0.9 against 0.1 s of B at 0.8, then the reverse
expect_equal(assign(0.5, 1.6, probs), "A")
expect_equal(assign(0.95, 1.9, probs), "B")

# a word in silence takes its neighbour's speaker instead of NA
expect_equal(assign(c(0.2, 1.1, 1.6), c(0.4, 1.4, 1.9), probs),
             c("A", "A", "B"))
expect_equal(assign(c(1.1, 1.6), c(1.4, 1.9), probs), c("B", "B"))
# no speech anywhere: NA, not a guess
expect_true(all(is.na(assign(c(0, 1), c(0.5, 1.5), probs * 0))))

# spans past the end of the audio clamp to the last frame
expect_equal(assign(2.9, 3.4, probs), "B")

words$speaker <- spk
segs <- group(words)
expect_equal(segs$text, c("Hello there.", "Hi back."))
expect_equal(segs$start, c(0, 1.6))
expect_equal(segs$end, c(0.9, 2.8))
expect_equal(segs$speaker, c("A", "B"))

# ---- live: whisper + n3d on real audio ----
# At home only, and only with both packages and their weights cached: this
# never downloads.
if (at_home() && requireNamespace("whisper", quietly = TRUE) &&
    requireNamespace("n3d", quietly = TRUE) && n3d::n3d_exists() &&
    whisper::model_exists("tiny")) {
    clip <- system.file("audio", "EagleHasLanded.mp3", package = "stt.api")
    res <- stt.api::stt(clip, model = "tiny",
                        response_format = "diarized_json",
                        backend = "whisper")
    expect_true(nrow(res$segments) > 1)
    expect_true(all(c("start", "end", "text", "speaker") %in%
                    names(res$segments)))
    expect_true(all(res$segments$speaker %in% LETTERS[1:8]))
    # words keep their timings and gain the speaker
    expect_true("speaker" %in% names(res$words))
    # still captions, and the labels fold in
    expect_true(inherits(res, "whisper_transcription"))
    expect_equal(nrow(res$data), nrow(res$segments))
    expect_true(grepl("^[A-H]: ",
                      stt.api::label_speakers(res)$data$text[1]))
    expect_equal(attr(res, "call_record")$request$backend, "whisper")
    expect_null(attr(res, "call_record")$request$chunking_strategy)
}

# ---- diarize(): speaker-only ----

f <- system.file("DESCRIPTION", package = "stt.api")
expect_error(stt.api::diarize("no-such-file.wav"), "File not found")
local({
    orig <- stt.api:::.has_n3d
    assignInNamespace(".has_n3d", function() FALSE, ns = "stt.api")
    on.exit(assignInNamespace(".has_n3d", orig, ns = "stt.api"), add = TRUE)
    expect_error(stt.api::diarize(f), "needs the n3d package")
})

if (at_home() && requireNamespace("n3d", quietly = TRUE) &&
    n3d::n3d_exists()) {
    clip <- system.file("audio", "EagleHasLanded.mp3", package = "stt.api")
    d <- stt.api::diarize(clip)
    expect_equal(names(d), c("start", "end", "speaker"))
    expect_true(nrow(d) > 1)
    expect_true(all(d$speaker %in% LETTERS[1:8]))
    # first arrival is A
    expect_equal(d$speaker[which.min(d$start)], "A")
    expect_equal(attr(d, "call_record")$fn, "diarize")
}

#' Check if the n3d package is available
#' @return TRUE if n3d is installed.
#' @keywords internal
.has_n3d <- function() {
    requireNamespace("n3d", quietly = TRUE)
}

#' Speaker-labelled segments from whisper words and n3d probabilities
#'
#' Local diarization pairs in-process whisper with n3d (Nemotron 3
#' Diarization). n3d gives per-speaker activity every 10 ms; each whisper
#' word takes the speaker with the most activity over its span, and
#' consecutive words of one speaker become one segment. Speakers are
#' labelled "A", "B", ... in order of first arrival, as OpenAI labels its
#' diarized segments.
#'
#' @param file Path to the audio file.
#' @param words whisper's word table (word, start, end), or NULL.
#' @param segments whisper's segment table (start, end, text), or NULL; used
#'   when there are no word timings.
#' @return A list of \code{segments} (start, end, text, speaker), the
#'   \code{words} with a speaker column (or NULL), and the n3d
#'   \code{diarization} segments.
#' @keywords internal
.n3d_speaker_segments <- function(file, words, segments) {
    diar <- n3d::diarize(file, probs = TRUE)
    probs <- diar$probs

    if (!is.null(words) && nrow(words) > 0) {
        words$speaker <- .assign_speakers(words$start, words$end, probs)
        segs <- .group_words(words)
    } else if (!is.null(segments) && nrow(segments) > 0) {
        segs <- segments[, c("start", "end", "text")]
        segs$speaker <- .assign_speakers(segs$start, segs$end, probs)
        words <- NULL
    } else {
        segs <- NULL
        words <- NULL
    }
    list(segments = segs, words = words, diarization = diar$segments)
}

#' Label a transcription's segments with n3d
#'
#' The one step both local routes share: in-process whisper and a
#' whisper serve() endpoint each hand back segments and (when asked) word
#' timings, and n3d labels them from the audio the same way. The
#' unlabelled result is kept whole under \code{raw$whisper}, beside the
#' n3d segments.
#'
#' @param file Path to the audio file.
#' @param res A normalized result: \code{segments}, optional \code{words},
#'   \code{raw}.
#' @return \code{res} with a \code{speaker} column on \code{segments} (and
#'   on \code{words}, when present), or an error naming the step.
#' @keywords internal
.label_locally <- function(file, res) {
    diar <- tryCatch(
        .n3d_speaker_segments(file, res$words, res$segments),
        error = function(e) {
            stop("Diarization failed: ", conditionMessage(e), call. = FALSE)
        })
    res$segments <- diar$segments
    if (!is.null(diar$words)) {
        res$words <- diar$words
    }
    res$raw <- list(whisper = res$raw, diarization = diar$diarization)
    res
}

# Speaker label with the most activity over each [start, end] span. Spans
# with no detected speech take the nearest labelled neighbour's speaker.
.assign_speakers <- function(start, end, probs, frame_duration = 0.01) {
    n_frames <- nrow(probs)
    labels <- LETTERS[seq_len(ncol(probs))]
    csum <- rbind(0, apply(probs, 2L, cumsum))
    first <- pmin(n_frames, pmax(1L, floor(start / frame_duration) + 1L))
    last <- pmin(n_frames, pmax(first, ceiling(end / frame_duration)))
    mass <- csum[last + 1L,, drop = FALSE] - csum[first,, drop = FALSE]
    speaker <- labels[max.col(mass, ties.method = "first")]
    speaker[apply(mass, 1L, max) < 1e-3] <- NA_character_
    .fill_nearest(speaker)
}

# Carry the previous label forward, then the next one backward.
.fill_nearest <- function(x) {
    if (all(is.na(x))) {
        return(x)
    }
    for (i in seq_along(x)[-1L]) {
        if (is.na(x[i])) x[i] <- x[i - 1L]
    }
    for (i in rev(seq_along(x))[-1L]) {
        if (is.na(x[i])) x[i] <- x[i + 1L]
    }
    x
}

# One segment per run of consecutive words with the same speaker.
.group_words <- function(words) {
    runs <- rle(ifelse(is.na(words$speaker), "", words$speaker))
    ends <- cumsum(runs$lengths)
    starts <- ends - runs$lengths + 1L
    text <- vapply(seq_along(starts), function(i) {
        paste(trimws(words$word[starts[i]:ends[i]]), collapse = " ")
    }, character(1))
    data.frame(start = words$start[starts], end = words$end[ends],
               text = text, speaker = words$speaker[starts],
               stringsAsFactors = FALSE)
}

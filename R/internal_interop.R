# Interop with subtitle tooling.
#
# subtitles::whisper_to_srt() and whisper_to_ass() take an audio.whisper-shaped
# object: class "whisper_transcription", carrying a $data frame of from/to
# timestamp strings and text. stt() returns numeric segments, so attaching that
# shape at its single return point lets a transcription feed those writers
# directly, on either route.

# Render numeric seconds as "HH:MM:SS.mmm".
#
# Rounds to whole milliseconds first, so a value just under a minute boundary
# carries into the minutes field rather than printing a 60th second. Negative
# and non-finite input clamps to zero: sprintf()'s integer conversions reject
# non-finite doubles outright, so the guard has to catch infinities and not
# just missings.
.format_hms <- function(t) {
    ms <- round(as.numeric(t) * 1000)
    ms[!is.finite(ms) | ms < 0] <- 0
    sprintf("%02d:%02d:%06.3f", ms %/% 3600000, (ms %% 3600000) %/% 60000,
            (ms %% 60000) / 1000)
}

# Attach the subtitle-tool shape to an stt() result.
#
# Both routes converge on the same normalized shape (.via_api and .via_whisper
# each return text/segments/language/backend/raw with segments run through
# .normalize_segments, so start/end are numeric seconds), which is why this can
# live at one place and cover both.
#
# Purely additive: text, segments, words, raw and the call_record attribute are
# left untouched, so existing callers are unaffected. Results without segments
# are returned unchanged and unclassed -- there is nothing to build a subtitle
# file from, and claiming the class without $data would fail inside the
# subtitle writers.
#
# The class vector leads with "stt_result" so this package's own S3 methods get
# first dispatch. audio.whisper also defines methods on "whisper_transcription";
# leading with our own class keeps those a fallback rather than letting them
# capture our objects when both packages are attached.
.attach_subtitle_shape <- function(res) {
    segs <- res$segments
    if (is.null(segs) || nrow(segs) == 0) {
        return(res)
    }
    if (!all(c("start", "end", "text") %in% names(segs))) {
        return(res)
    }

    res$data <- data.frame(
        from = .format_hms(segs$start),
        to = .format_hms(segs$end),
        text = segs$text,
        stringsAsFactors = FALSE)
    class(res) <- c("stt_result", "whisper_transcription")
    res
}

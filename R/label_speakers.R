#' Fold Speaker Labels Into Caption Text
#'
#' Diarized results carry speaker labels on \code{segments}, but subtitle
#' tools read \code{data}, which is \code{from}/\code{to}/\code{text} only.
#' The labels are therefore dropped on the way to a caption file. This folds
#' them into the caption text so they survive:
#'
#' \preformatted{
#' HOUSTON: We copy you down, Eagle.
#' ARMSTRONG: Tranquility Base here. The Eagle has landed.
#' }
#'
#' Only \code{data$text} changes. \code{segments} keeps its own untouched
#' \code{text} and \code{speaker} columns, so the labels are still available
#' separately, and the class and \code{"call_record"} attribute are
#' preserved -- the result still feeds
#' \code{subtitles::whisper_to_srt()} and \code{whisper_to_ass()} directly.
#'
#' @param x A result from \code{\link{stt}} with speaker labels, i.e. one
#'   produced with \code{response_format = "diarized_json"}.
#' @param sep String placed between the label and the line. Defaults to
#'   \code{": "}.
#' @param prefix String placed before the label, for styles like
#'   \code{prefix = "["}. Empty by default.
#' @param suffix String placed after the label, for styles like
#'   \code{suffix = "]"}. Empty by default.
#'
#' @return \code{x} with \code{data$text} relabelled. Segments whose speaker
#'   is missing are left alone rather than labelled \code{NA}, which happens
#'   when a provider matches only some speakers to the references given in
#'   \code{known_speakers}.
#'
#' @section Karaoke:
#' Pass \code{karaoke = FALSE} to
#' \code{subtitles::whisper_to_ass()} for a diarized result. That argument
#' defaults to \code{TRUE} and needs word-level timings, which OpenAI does
#' not return alongside diarization -- so the default errors on any diarized
#' result, labelled or not. \code{whisper_to_srt()} is unaffected.
#'
#' @examples
#' # The shape stt() returns for a diarized request.
#' x <- structure(
#'   list(
#'     segments = data.frame(
#'       start = c(0, 2.5), end = c(2.5, 5),
#'       text = c("We copy you down, Eagle.", "The Eagle has landed."),
#'       speaker = c("HOUSTON", "ARMSTRONG"),
#'       stringsAsFactors = FALSE),
#'     data = data.frame(
#'       from = c("00:00:00.000", "00:00:02.500"),
#'       to = c("00:00:02.500", "00:00:05.000"),
#'       text = c("We copy you down, Eagle.", "The Eagle has landed."),
#'       stringsAsFactors = FALSE)),
#'   class = c("stt_result", "whisper_transcription"))
#'
#' label_speakers(x)$data$text
#' label_speakers(x, prefix = "[", suffix = "]", sep = " ")$data$text
#'
#' \dontrun{
#' # Into a caption file. karaoke = FALSE is required for diarized results.
#' subtitles::whisper_to_srt(label_speakers(x), "meeting.srt")
#' subtitles::whisper_to_ass(label_speakers(x), "meeting.ass",
#'                           karaoke = FALSE)
#' }
#'
#' @seealso \code{\link{stt}} for \code{known_speakers}, which sets the
#'   labels this uses.
#' @export
label_speakers <- function(x, sep = ": ", prefix = "", suffix = "") {
    if (!is.data.frame(x$data) || nrow(x$data) == 0) {
        stop("No captionable segments in this result. Speaker labels need ",
             "response_format = 'diarized_json'.", call. = FALSE)
    }
    if (!is.data.frame(x$segments) || is.null(x$segments$speaker)) {
        stop("No speaker labels in this result. Request them with ",
             "response_format = 'diarized_json'.", call. = FALSE)
    }
    # data is built from segments row for row, so a mismatch means the object
    # was assembled by hand or edited. Refuse rather than recycle: silently
    # pairing the wrong label with the wrong line is worse than no labels.
    if (nrow(x$segments) != nrow(x$data)) {
        stop("segments and data disagree on row count (", nrow(x$segments),
             " vs ", nrow(x$data), "); cannot match labels to lines.",
             call. = FALSE)
    }

    who <- as.character(x$segments$speaker)
    label <- paste0(prefix, who, suffix, sep)

    # An unmatched speaker comes back missing rather than named. Prefixing
    # those with "NA: " would put the word NA on screen.
    have <- !is.na(who) & nzchar(who)
    x$data$text[have] <- paste0(label[have], trimws(x$data$text[have]))
    x
}

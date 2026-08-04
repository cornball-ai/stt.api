% tinyrox says don't edit this manually, but it can't stop you!
\name{label_speakers}
\alias{label_speakers}
\title{Fold Speaker Labels Into Caption Text}
\usage{
label_speakers(x, sep = ": ", prefix = "", suffix = "")
}
\arguments{
\item{x}{A result from \code{\link{stt}} with speaker labels, i.e. one
produced with \code{response_format = "diarized_json"}.}

\item{sep}{String placed between the label and the line. Defaults to
\code{": "}.}

\item{prefix}{String placed before the label, for styles like
\code{prefix = "["}. Empty by default.}

\item{suffix}{String placed after the label, for styles like
\code{suffix = "]"}. Empty by default.}
}
\value{
\code{x} with \code{data$text} relabelled. Segments whose speaker
  is missing are left alone rather than labelled \code{NA}. Note this is
  not what a partial \code{known_speakers} match looks like: a speaker
  the provider cannot match to a reference keeps a generic label, so
  those segments are labelled with it. A missing speaker means the
  response omitted the field for that segment.
}
\description{
Diarized results carry speaker labels on \code{segments}, but subtitle
tools read \code{data}, which is \code{from}/\code{to}/\code{text} only.
The labels are therefore dropped on the way to a caption file. This folds
them into the caption text so they survive:
}
\details{
\preformatted{
HOUSTON: We copy you down, Eagle.
ARMSTRONG: Tranquility Base here. The Eagle has landed.
}

Only \code{data$text} changes. \code{segments} keeps its own untouched
\code{text} and \code{speaker} columns, so the labels are still available
separately, and the class and \code{"call_record"} attribute are
preserved -- the result still feeds
\code{subtitles::whisper_to_srt()} and \code{whisper_to_ass()} directly.

}
\section{Karaoke}{
Pass \code{karaoke = FALSE} to
\code{subtitles::whisper_to_ass()} for a diarized result. That argument
defaults to \code{TRUE} and needs word-level timings, which OpenAI does
not return alongside diarization -- so the default errors on any diarized
result, labelled or not. \code{whisper_to_srt()} is unaffected.

}
\examples{
# The shape stt() returns for a diarized request.
x <- structure(
  list(
    segments = data.frame(
      start = c(0, 2.5), end = c(2.5, 5),
      text = c("We copy you down, Eagle.", "The Eagle has landed."),
      speaker = c("HOUSTON", "ARMSTRONG"),
      stringsAsFactors = FALSE),
    data = data.frame(
      from = c("00:00:00.000", "00:00:02.500"),
      to = c("00:00:02.500", "00:00:05.000"),
      text = c("We copy you down, Eagle.", "The Eagle has landed."),
      stringsAsFactors = FALSE)),
  class = c("stt_result", "whisper_transcription"))

label_speakers(x)$data$text
label_speakers(x, prefix = "[", suffix = "]", sep = " ")$data$text

\dontrun{
# Into a caption file. karaoke = FALSE is required for diarized results.
subtitles::whisper_to_srt(label_speakers(x), "meeting.srt")
subtitles::whisper_to_ass(label_speakers(x), "meeting.ass",
                          karaoke = FALSE)
}

}
\seealso{
\code{\link{stt}} for \code{known_speakers}, which sets the
  labels this uses.
}

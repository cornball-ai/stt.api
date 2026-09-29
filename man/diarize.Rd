% tinyrox says don't edit this manually, but it can't stop you!
\name{diarize}
\alias{diarize}
\title{Speaker Diarization}
\usage{
diarize(file, threshold = 0.5)
}
\arguments{
\item{file}{Path to the audio file.}

\item{threshold}{Speaker activity probability above which a 10 ms frame
counts as speech.}
}
\value{
A data.frame with columns \code{start} and \code{end} (seconds)
  and \code{speaker}, labelled "A", "B", ... in order of first arrival as
  in \code{\link{stt}}'s diarized segments. Overlapping speech gives
  overlapping rows. It carries a \code{"call_record"} attribute like
  \code{\link{stt}}'s result.
}
\description{
Who spoke when, without a transcript. Runs in-process with the
\pkg{n3d} package (NVIDIA Nemotron 3 Diarization, up to 8 speakers),
which needs its weights fetched once with \code{n3d::download_n3d()}.
For speaker-labelled text, use \code{\link{stt}} with
\code{response_format = "diarized_json"}.
}
\examples{
\donttest{
if (requireNamespace("n3d", quietly = TRUE) && n3d::n3d_exists()) {
  clip <- system.file("audio", "EagleHasLanded.mp3", package = "stt.api")
  diarize(clip)
}
}

}

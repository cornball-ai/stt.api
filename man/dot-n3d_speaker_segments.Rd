% tinyrox says don't edit this manually, but it can't stop you!
\name{.n3d_speaker_segments}
\alias{.n3d_speaker_segments}
\title{Speaker-labelled segments from whisper words and n3d probabilities}
\usage{
.n3d_speaker_segments(file, words, segments)
}
\arguments{
\item{file}{Path to the audio file.}

\item{words}{whisper's word table (word, start, end), or NULL.}

\item{segments}{whisper's segment table (start, end, text), or NULL; used
when there are no word timings.}
}
\value{
A list of \code{segments} (start, end, text, speaker), the
  \code{words} with a speaker column (or NULL), and the n3d
  \code{diarization} segments.
}
\description{
Local diarization pairs in-process whisper with n3d (Nemotron 3
Diarization). n3d gives per-speaker activity every 10 ms; each whisper
word takes the speaker with the most activity over its span, and
consecutive words of one speaker become one segment. Speakers are
labelled "A", "B", ... in order of first arrival, as OpenAI labels its
diarized segments.
}
\keyword{internal}

% tinyrox says don't edit this manually, but it can't stop you!
\name{.label_locally}
\alias{.label_locally}
\title{Label a transcription's segments with n3d}
\usage{
.label_locally(file, res)
}
\arguments{
\item{file}{Path to the audio file.}

\item{res}{A normalized result: \code{segments}, optional \code{words},
\code{raw}.}
}
\value{
\code{res} with a \code{speaker} column on \code{segments} (and
  on \code{words}, when present), or an error naming the step.
}
\description{
The one step both local routes share: in-process whisper and a
whisper serve() endpoint each hand back segments and (when asked) word
timings, and n3d labels them from the audio the same way. The
unlabelled result is kept whole under \code{raw$whisper}, beside the
n3d segments.
}
\keyword{internal}

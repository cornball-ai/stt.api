% tinyrox says don't edit this manually, but it can't stop you!
\name{stt_health}
\alias{stt_health}
\title{Check STT Backend Health}
\usage{
stt_health()
}
\value{
A list with components:
\describe{
  \item{ok}{Logical. TRUE if a backend is available.}
  \item{backend}{Character. The available backend ("api", "audio.whisper"),
    or NULL if none available.}
  \item{message}{Character. Status message with details.}
}
}
\description{
Checks whether a transcription backend is available and working.
}
\examples{
\dontrun{
h <- stt_health()
if (h$ok) {
  message("STT ready via ", h$backend)
}
}

}

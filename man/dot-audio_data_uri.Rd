% tinyrox says don't edit this manually, but it can't stop you!
\name{.audio_data_uri}
\alias{.audio_data_uri}
\title{Encode an audio file as a data URI}
\usage{
.audio_data_uri(path)
}
\arguments{
\item{path}{Path to an audio file.}
}
\value{
A data URI string.
}
\description{
The speaker-reference fields take the clip inline as
\code{data:<mime>;base64,<...>} rather than as a file part, so the bytes
are read and encoded here. jsonlite is already an import, so this adds no
dependency despite having nothing to do with JSON.
}
\keyword{internal}

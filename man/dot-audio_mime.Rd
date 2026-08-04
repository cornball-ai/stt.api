% tinyrox says don't edit this manually, but it can't stop you!
\name{.audio_mime}
\alias{.audio_mime}
\title{MIME type for an audio file, from its extension}
\usage{
.audio_mime(path)
}
\arguments{
\item{path}{File path.}
}
\value{
A MIME type string.
}
\description{
Covers every container OpenAI accepts as transcription input, since a
speaker reference may be in any of them. Deriving this from the extension
rather than sniffing the file keeps the dependency list where it is; an
unknown extension is an error rather than a guess, since a wrong MIME type
fails server-side with a far less obvious message.
}
\keyword{internal}

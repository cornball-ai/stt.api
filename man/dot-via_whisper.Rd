% tinyrox says don't edit this manually, but it can't stop you!
\name{.via_whisper}
\alias{.via_whisper}
\title{Internal: Transcribe via native whisper package}
\usage{
.via_whisper(file, model = NULL, language = NULL, diarize = FALSE)
}
\arguments{
\item{file}{Character. Path to the audio file to transcribe.}

\item{model}{Character or NULL. Whisper model name (e.g., "tiny", "base",
"small", "medium", "large-v3").}

\item{language}{Character or NULL. Language code for transcription.}

\item{diarize}{Logical. Label speakers with the n3d package; segments and
words gain a \code{speaker} column.}
}
\value{
List with transcription results in normalized format.
}
\description{
Uses the cornball-ai/whisper native R torch implementation.
}
\keyword{internal}

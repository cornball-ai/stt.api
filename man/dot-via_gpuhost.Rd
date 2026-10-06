% tinyrox says don't edit this manually, but it can't stop you!
\name{.via_gpuhost}
\alias{.via_gpuhost}
\title{Internal: Transcribe on the fleet's GPU host}
\usage{
.via_gpuhost(file, model = NULL, language = NULL, diarize = FALSE)
}
\arguments{
\item{file}{Path to the audio file.}

\item{model}{The catalog entry name, or NULL for the host's whisper
entry (see \code{.gpuhost_entry}).}

\item{language}{Kept for the result's \code{language} when the host
reports none; not sent.}

\item{diarize}{Label speakers locally with n3d from the host's word
timings.}
}
\value{
The normalized result list.
}
\description{
One \code{/infer} request through gpu.host. The entry's input is the
audio alone: the host's whisper entries take no language, so
\code{language} is not sent and the result reports what the host
detected. Segments and word timings come back always.
}
\keyword{internal}

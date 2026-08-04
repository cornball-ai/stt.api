% tinyrox says don't edit this manually, but it can't stop you!
\name{.is_diarizing}
\alias{.is_diarizing}
\title{Is this request headed for a diarizing model?}
\usage{
.is_diarizing(model, response_format)
}
\arguments{
\item{model}{Model name, or NULL.}

\item{response_format}{The resolved response format.}
}
\value{
TRUE or FALSE.
}
\description{
Several of OpenAI's rules key on the model rather than the response
format, since a diarizing model also answers plain \code{json} and
\code{text}. It refuses \code{prompt} for "diarization models" whichever
format is asked for, requires \code{chunking_strategy} for them above 30
seconds of audio in any format, and only OpenAI serves them at all, so a
diarizing request also fixes the backend. Verified against the live
endpoint with \code{response_format = "json"}:
}
\details{
HTTP 400: Prompt is not supported for diarization models
HTTP 400: chunking_strategy is required for diarization models

\code{diarized_json} implies a diarizing model, since nothing else
produces it. Beyond that the only signal available before the request is
the model name, so this matches on it. That is a heuristic: a self-hosted
model whose name happens to contain "diarize" is treated as diarizing.
The alternative is uploading the audio to be told the same thing.

}
\keyword{internal}

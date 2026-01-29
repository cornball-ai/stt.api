% tinyrox says don't edit this manually, but it can't stop you!
\name{.get_native_whisper_model}
\alias{.get_native_whisper_model}
\title{Get or create cached native whisper model}
\usage{
.get_native_whisper_model(model, device = "auto")
}
\arguments{
\item{model}{Model name (e.g., "tiny", "base", "small", "medium", "large-v3")}

\item{device}{Device to use ("auto", "cpu", "cuda")}
}
\value{
Loaded whisper model object
}
\description{
Get or create cached native whisper model
}
\keyword{internal}

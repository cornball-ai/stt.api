% tinyrox says don't edit this manually, but it can't stop you!
\name{set_stt_key}
\alias{set_stt_key}
\title{Set the API Key}
\usage{
set_stt_key(key)
}
\arguments{
\item{key}{Character string. The API key.}
}
\value{
Invisibly returns the previous value.
}
\description{
Sets the API key for hosted STT services (e.g., OpenAI).
Local servers typically ignore this.
}
\examples{
\dontrun{
set_stt_key(Sys.getenv("OPENAI_API_KEY"))
}

}

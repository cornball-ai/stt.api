% tinyrox says don't edit this manually, but it can't stop you!
\name{set_stt_base}
\alias{set_stt_base}
\title{Set the API Base URL}
\usage{
set_stt_base(url)
}
\arguments{
\item{url}{Character string. The base URL (e.g., "http://localhost:4123"
or "https://api.openai.com").}
}
\value{
Invisibly returns the previous value.
}
\description{
Sets the base URL for OpenAI-compatible STT endpoints.
}
\examples{
\dontrun{
set_stt_base("http://localhost:4123")
set_stt_base("https://api.openai.com")
}

}

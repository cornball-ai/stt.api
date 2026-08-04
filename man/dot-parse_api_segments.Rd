% tinyrox says don't edit this manually, but it can't stop you!
\name{.parse_api_segments}
\alias{.parse_api_segments}
\title{Build the segments data.frame from a parsed API response}
\usage{
.parse_api_segments(segs)
}
\arguments{
\item{segs}{The \code{segments} element of the parsed response, or NULL.}
}
\value{
A data.frame with numeric start/end, or NULL.
}
\description{
Shared by the timestamped formats. verbose_json segments carry
start/end/text; diarized_json segments add a \code{speaker} label. The
speaker column is added only when the response actually has it, so
\code{is.null(x$segments$speaker)} gives a straight answer either way.
}
\keyword{internal}

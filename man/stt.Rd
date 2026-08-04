% tinyrox says don't edit this manually, but it can't stop you!
\name{stt}
\alias{stt}
\title{Speech to Text}
\usage{
stt(file, model = NULL, language = NULL,
    response_format = c("json", "text", "verbose_json", "diarized_json"),
    backend = c("auto", "whisper", "openai"),
    source = c("auto", "api", "package"), prompt = NULL,
    chunking_strategy = NULL, known_speakers = NULL)
}
\arguments{
\item{file}{Path to the audio file to convert.}

\item{model}{Model name to use for transcription. For API backends, this
is passed directly (e.g., "whisper-1"). For whisper, this is
the model size (e.g., "tiny", "base", "small", "medium", "large").
If NULL, uses the backend's default. Which model you pick decides what
timing you can get back from OpenAI: "whisper-1" is the only one that
returns word-level timings (with \code{response_format = "verbose_json"}),
"gpt-4o-transcribe-diarize" returns speaker-labelled segments (with
\code{response_format = "diarized_json"}), and the plain
"gpt-4o-transcribe"/"gpt-4o-mini-transcribe" models accept only
\code{response_format = "json"}, so they return no timing at all and the
result is a plain list with no \code{data} component. A self-hosted
\code{whisper::serve()} endpoint has no such restriction.}

\item{language}{Language code (e.g., "en", "es", "fr"). Optional hint
to improve transcription accuracy.}

\item{response_format}{Response format for API backend. One of "text",
"json", "verbose_json", or "diarized_json". Ignored for whisper backend,
except that "diarized_json" is an error there (see \code{model}).
"diarized_json" is OpenAI's diarizing format: segments gain a
\code{speaker} column, and word timings are not available with it.}

\item{backend}{Which engine to use: "auto" (default), "whisper",
or "openai". Auto mode tries whisper first, then the openai API
(if configured), except for \code{response_format = "diarized_json"},
which only OpenAI serves and so resolves straight to "openai". See
\code{source} for *where* the engine runs.}

\item{source}{Where the engine runs: "auto" (default), "api" for an HTTP
service (OpenAI, or a self-hosted whisper server; see
\code{\link{set_stt_base}}), or "package" for the in-process whisper R
package. "auto" runs whisper in-process and openai via the API, matching
the previous behavior. Use \code{backend = "whisper", source = "api"} to
reach a whisper \code{serve()} endpoint.}

\item{prompt}{Optional text to guide the transcription. For API backend,
this is passed as initial_prompt to help with spelling of names,
acronyms, or domain-specific terms. Ignored for whisper backend.}

\item{chunking_strategy}{Optional chunking strategy passed to the API,
e.g. "auto". Defaults to "auto" for
\code{response_format = "diarized_json"}, which OpenAI rejects for audio
longer than 30 seconds when the parameter is unset. NULL otherwise.}

\item{known_speakers}{Optional named character vector of audio files, at
most four, giving a short reference clip per speaker. The \emph{names}
are offered to the provider as labels: segments it matches to a
reference come back named, so
\code{known_speakers = c(agent = "agent.wav", caller = "caller.wav")}
can yield \code{segments$speaker} values of "agent" and "caller".
Matching is best-effort and partial results are normal -- speakers it
cannot match keep a generic label, so expect a mix, and check what came
back rather than assuming. Nor does supplying references re-cut the
segmentation: speakers the model has already merged into one cluster
(several people on one radio downlink, say) are not thereby separated.
Each clip should contain only that speaker and run roughly 2 to 10
seconds; the files are read and sent inline, so keep them short.
Requires \code{response_format = "diarized_json"} and is an error
otherwise.}
}
\value{
A list with components:
\describe{
  \item{text}{The transcribed text as a single string.}
  \item{segments}{A data.frame of segments with timing info, or NULL. For
    \code{response_format = "diarized_json"} it carries an extra
    \code{speaker} column; that column is absent, not NA, for every other
    format.}
  \item{words}{A data.frame of word-level timestamps (word, start, end),
    present only when the API returns word granularity (verbose_json,
    and on OpenAI only from "whisper-1"; see \code{model}); otherwise
    absent.}
  \item{language}{The detected or specified language code.}
  \item{backend}{The legacy execution route ("api" or "whisper"). This
    reports *where* the engine ran, not the engine itself; the resolved
    \code{backend}/\code{source} pair lives in the \code{"call_record"}
    attribute.}
  \item{raw}{The raw response from the backend.}
}
When the result has usable segments (\code{start}/\code{end}/\code{text}
columns), it additionally carries the shape subtitle tooling expects: a
\code{data} data.frame with \code{from}/\code{to} timestamp strings
("HH:MM:SS.mmm") and \code{text}, and class
\code{c("stt_result", "whisper_transcription")}, so it feeds
\code{subtitles::whisper_to_srt()} and \code{subtitles::whisper_to_ass()}
directly. Note the API route returns segments only with
\code{response_format = "verbose_json"} or \code{"diarized_json"}.
Results without usable segments are plain lists, as before.

The result also carries a \code{"call_record"} attribute (cornball_sidecar
v1, as in xtx.api/tts.api): the resolved request, elapsed seconds, and a
timestamp -- provenance that rides with the transcription when callers
serialize it.
}
\description{
Convert an audio file to text using a local whisper backend or
an OpenAI-compatible API.
}
\examples{
\dontrun{
# Using OpenAI API
set_stt_base("https://api.openai.com")
set_stt_key(Sys.getenv("OPENAI_API_KEY"))
result <- stt("speech.wav", model = "whisper-1")
result$text

# Speaker-labelled segments
result <- stt("meeting.wav", model = "gpt-4o-transcribe-diarize",
              response_format = "diarized_json")
result$segments[, c("start", "end", "speaker", "text")]

# ...with your own labels instead of generic ones
audio <- system.file("audio", package = "stt.api")
result <- stt(file.path(audio, "EagleHasLanded.mp3"),
              model = "gpt-4o-transcribe-diarize",
              response_format = "diarized_json",
              known_speakers = c(
                  Armstrong = file.path(audio, "ref_armstrong.mp3"),
                  Houston   = file.path(audio, "ref_houston.mp3")))
unique(result$segments$speaker)

# Using a self-hosted whisper serve() endpoint
set_stt_base("http://troy-g5:7809")
result <- stt("speech.wav", backend = "whisper", source = "api")

# In-process whisper package
result <- stt("speech.wav", backend = "whisper", source = "package")
}

}

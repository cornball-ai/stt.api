% tinyrox says don't edit this manually, but it can't stop you!
\name{clear_native_whisper_cache}
\alias{clear_native_whisper_cache}
\title{Clear native whisper model cache}
\usage{
clear_native_whisper_cache()
}
\value{
No return value, called for side effects (frees memory by removing
  cached models and triggers garbage collection).
}
\description{
Removes cached native whisper models from memory. Call this to free GPU/RAM
after batch processing is complete.
}
\examples{
clear_native_whisper_cache()

}

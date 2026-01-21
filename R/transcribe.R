#' Transcribe Audio
#'
#' Transcribe an audio file to text using an OpenAI-compatible API or
#' local audio.whisper backend.
#'
#' @param file Path to the audio file to transcribe.
#' @param model Model name to use for transcription. For API backends, this
#'   is passed directly (e.g., "whisper-1"). For audio.whisper, this is
#'   the model size (e.g., "tiny", "base", "small", "medium", "large").
#'   If NULL, uses the backend's default.
#' @param language Language code (e.g., "en", "es", "fr"). Optional hint
#'   to improve transcription accuracy.
#' @param response_format Response format for API backend. One of "text",
#'   "json", or "verbose_json". Ignored for audio.whisper backend.
#' @param backend Which backend to use: "auto" (default), "whisper",
#'   "audio.whisper", "openai", or "fal". Auto mode tries native whisper first,
#'   then audio.whisper, then openai API (if configured), then fal.api.
#'
#' @return A list with components:
#' \describe{
#'   \item{text}{The transcribed text as a single string.}
#'   \item{segments}{A data.frame of segments with timing info, or NULL.}
#'   \item{language}{The detected or specified language code.}
#'   \item{backend}{Which backend was used ("api" or "audio.whisper").}
#'   \item{raw}{The raw response from the backend.}
#' }
#'
#' @examples
#' \dontrun{
#' # Using OpenAI API
#' set_stt_base("https://api.openai.com")
#' set_stt_key(Sys.getenv("OPENAI_API_KEY"))
#' result <- transcribe("speech.wav", model = "whisper-1")
#' result$text
#'
#' # Using local server
#' set_stt_base("http://localhost:4123")
#' result <- transcribe("speech.wav")
#'
#' # Using audio.whisper directly
#' result <- transcribe("speech.wav", backend = "audio.whisper")
#' }
#'
#' @param prompt Optional text to guide the transcription. For API backend,
#'   this is passed as initial_prompt to help with spelling of names,
#'   acronyms, or domain-specific terms. Ignored for audio.whisper backend
#'   (not supported by underlying library).
#'
#' @export
transcribe <- function(
  file,
  model = NULL,
  language = NULL,
  response_format = c("json", "text", "verbose_json"),
  backend = c("auto", "whisper", "audio.whisper", "openai", "fal"),
  prompt = NULL
) {

  # Validate file
  if (!file.exists(file)) {
    stop("File not found: ", file, call. = FALSE)
  }

  response_format <- match.arg(response_format)
  backend <- match.arg(backend)

  # Resolve backend
  resolved_backend <- .choose_backend(backend)

  # Acquire GPU for local whisper API (not for openai.com)
  if (resolved_backend == "openai" &&
    !grepl("openai\\.com", getOption("stt.api_base", ""))) {
    .gpuctl_acquire()
  }

  # Dispatch to appropriate backend
  if (resolved_backend == "openai") {
    .via_api(
      file = file,
      model = model,
      language = language,
      response_format = response_format,
      prompt = prompt
    )
  } else if (resolved_backend == "whisper") {
    .via_whisper(
      file = file,
      model = model,
      language = language
    )
  } else if (resolved_backend == "fal") {
    .via_fal(
      file = file,
      model = model,
      language = language
    )
  } else {
    # audio.whisper backend
    .via_audio_whisper(
      file = file,
      model = model,
      language = language
    )
  }
}


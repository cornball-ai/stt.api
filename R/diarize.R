#' Speaker Diarization
#'
#' Who spoke when, without a transcript. Runs in-process with the
#' \pkg{n3d} package (NVIDIA Nemotron 3 Diarization, up to 8 speakers),
#' which needs its weights fetched once with \code{n3d::download_n3d()}.
#' For speaker-labelled text, use \code{\link{stt}} with
#' \code{response_format = "diarized_json"}.
#'
#' @param file Path to the audio file.
#' @param threshold Speaker activity probability above which a 10 ms frame
#'   counts as speech.
#'
#' @return A data.frame with columns \code{start} and \code{end} (seconds)
#'   and \code{speaker}, labelled "A", "B", ... in order of first arrival as
#'   in \code{\link{stt}}'s diarized segments. Overlapping speech gives
#'   overlapping rows. It carries a \code{"call_record"} attribute like
#'   \code{\link{stt}}'s result.
#'
#' @examples
#' \donttest{
#' if (requireNamespace("n3d", quietly = TRUE) && n3d::n3d_exists()) {
#'   clip <- system.file("audio", "EagleHasLanded.mp3", package = "stt.api")
#'   diarize(clip)
#' }
#' }
#'
#' @export
diarize <- function(file, threshold = 0.5) {
    if (!file.exists(file)) {
        stop("File not found: ", file, call. = FALSE)
    }
    if (!.has_n3d()) {
        stop("diarize() needs the n3d package.\n",
             "Install with: remotes::install_github('cornball-ai/n3d')",
             call. = FALSE)
    }
    started <- Sys.time()
    segs <- n3d::diarize(file, threshold = threshold)
    segs$speaker <- LETTERS[segs$speaker]
    attr(segs, "call_record") <- list(
        cornball_sidecar = 1L, package = "stt.api",
        version = as.character(utils::packageVersion("stt.api")),
        fn = "diarize",
        request = list(file = file, threshold = threshold, backend = "n3d",
                       source = "package"),
        elapsed = round(as.numeric(difftime(Sys.time(), started,
            units = "secs")), 2),
        created = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"))
    segs
}

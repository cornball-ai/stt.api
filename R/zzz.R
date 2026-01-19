.onLoad <- function(
  libname,
  pkgname
) {

  op <- options()
  op_stt <- list(
    stt.api_base = NULL,
    stt.api_key = NULL,
    stt.timeout = 60,
    stt.backend = "auto"
  )

  toset <- !(names(op_stt) %in% names(op))
  if (any(toset)) {
    options(op_stt[toset])
  }

  invisible()
}


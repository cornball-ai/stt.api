# Internal helper to get API base URL
.get_api_base <- function(required = FALSE) {
    base <- getOption("stt.api_base")
    if (required && is.null(base)) {
        stop(
             "API base URL not set.\n",
             "Use set_stt_base() to configure the endpoint.",
             call. = FALSE
        )
    }
    base
}

# Internal helper to get API key
.get_api_key <- function() {
    getOption("stt.api_key")
}

# Internal helper to get timeout
.get_timeout <- function() {
    getOption("stt.timeout", default = 60)
}

#' Convert time string to numeric seconds
#' @param time_str Time string in "HH:MM:SS.mmm" or "MM:SS.mmm" format
#' @return Numeric seconds
#' @keywords internal
.time_to_seconds <- function(time_str) {
    if (is.numeric(time_str)) {
        return(time_str)
    }
    if (is.na(time_str) || is.null(time_str)) {
        return(NA_real_)
    }

    parts <- strsplit(as.character(time_str), ":")[[1]]
    if (length(parts) == 3) {
        as.numeric(parts[1]) * 3600 + as.numeric(parts[2]) * 60 + as.numeric(parts[3])
    } else if (length(parts) == 2) {
        as.numeric(parts[1]) * 60 + as.numeric(parts[2])
    } else {
        as.numeric(parts[1])
    }
}

#' Normalize segments to use numeric seconds
#' @param segments Data frame with from/to or start/end columns
#' @return Data frame with numeric start/end columns
#' @keywords internal
.normalize_segments <- function(segments) {
    if (is.null(segments) || nrow(segments) == 0) {
        return(segments)
    }

    # Standardize column names to start/end
    if ("from" %in% names(segments) && !"start" %in% names(segments)) {
        segments$start <- segments$from
    }
    if ("to" %in% names(segments) && !"end" %in% names(segments)) {
        segments$end <- segments$to
    }

    # Convert to numeric seconds if needed
    if ("start" %in% names(segments) && !is.numeric(segments$start)) {
        segments$start <- sapply(segments$start, .time_to_seconds)
    }
    if ("end" %in% names(segments) && !is.numeric(segments$end)) {
        segments$end <- sapply(segments$end, .time_to_seconds)
    }

    segments
}

# Resolve the (backend, source) pair to a concrete route.
#
# Two axes, mirroring tts.api: `backend` is the engine ("whisper" or "openai",
# "auto" picks), `source` is where it runs ("package" in-process, "api" over
# HTTP, "auto" picks). Returns list(backend = , route = ) where route is one of
# "package" or "api". source = "auto" reproduces the previous behavior (whisper
# in-process, openai via API), so existing calls are unchanged.
.resolve_route <- function(backend = c("auto", "whisper", "openai"),
                           source = c("auto", "api", "package")) {
    backend <- match.arg(backend)
    source <- match.arg(source)

    if (backend == "openai") {
        if (source == "package") {
            stop("source = 'package' is only available for backend = ",
                 "'whisper'; openai runs via the API (source = 'api').",
                 call. = FALSE)
        }
        route <- "api"
    } else if (backend == "whisper") {
        # auto / package -> in-process; api -> a whisper serve() endpoint
        route <- if (source == "api") "api" else "package"
    } else {
        # backend == "auto": pick engine from source and availability
        if (source == "package") {
            backend <- "whisper"
            route <- "package"
        } else if (source == "api") {
            backend <- if (!is.null(.get_api_base())) "openai" else "whisper"
            route <- "api"
        } else {
            # source == "auto": whisper in-process first, then API
            if (.has_whisper()) {
                backend <- "whisper"
                route <- "package"
            } else if (!is.null(.get_api_base())) {
                backend <- "openai"
                route <- "api"
            } else {
                stop(
                     "No transcription backend available.\n",
                     "Either:\n",
                     "  - Install whisper: install.packages('whisper'), or\n",
                     "  - Set an API endpoint with set_stt_base()",
                     call. = FALSE
                )
            }
        }
    }

    # Availability checks for the resolved route
    if (route == "package" && !.has_whisper()) {
        stop(
             "Backend 'whisper' requested but package is not installed.\n",
             "Install with: install.packages('whisper')",
             call. = FALSE
        )
    }
    if (route == "api" && is.null(.get_api_base())) {
        stop(
             "API route requested but no API base URL is set.\n",
             "Use set_stt_base() to configure the endpoint.",
             call. = FALSE
        )
    }

    list(backend = backend, route = route)
}


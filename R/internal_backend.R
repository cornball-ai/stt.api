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
# HTTP, "gpuhost" on the fleet's GPU host, "auto" picks). Returns
# list(backend = , route = ) where route is one of "package", "api" or
# "gpuhost". source = "auto" keeps the earlier order (whisper in-process,
# then openai via API) and slots the GPU host between them: a configured
# host is a deliberate setup, so it outranks a hosted API, and the
# in-process package still comes first so existing calls are unchanged.
.resolve_route <- function(backend = c("auto", "whisper", "openai"),
                           source = c("auto", "api", "package", "gpuhost")) {
    backend <- match.arg(backend)
    source <- match.arg(source)

    if (backend == "openai") {
        if (source %in% c("package", "gpuhost")) {
            stop("source = '", source, "' is only available for backend = ",
                 "'whisper'; openai runs via the API (source = 'api').",
                 call. = FALSE)
        }
        route <- "api"
    } else if (backend == "whisper") {
        # package -> in-process; api -> a whisper serve() endpoint;
        # gpuhost -> the fleet's GPU host; auto -> in-process when the
        # package is installed, else a configured GPU host, else the
        # package's own "not installed" refusal below
        route <- switch(source,
                        api = "api",
                        gpuhost = "gpuhost",
                        package = "package",
                        if (!.has_whisper() && .gpu_host_configured()) {
                            "gpuhost"
                        } else {
                            "package"
                        })
    } else {
        # backend == "auto": pick engine from source and availability
        if (source == "package") {
            backend <- "whisper"
            route <- "package"
        } else if (source == "gpuhost") {
            backend <- "whisper"
            route <- "gpuhost"
        } else if (source == "api") {
            backend <- if (!is.null(.get_api_base())) "openai" else "whisper"
            route <- "api"
        } else {
            # source == "auto": whisper in-process, then the GPU host, then
            # the API
            if (.has_whisper()) {
                backend <- "whisper"
                route <- "package"
            } else if (.gpu_host_configured()) {
                backend <- "whisper"
                route <- "gpuhost"
            } else if (!is.null(.get_api_base())) {
                backend <- "openai"
                route <- "api"
            } else {
                stop(
                     "No transcription backend available.\n",
                     "Either:\n",
                     "  - Install whisper: install.packages('whisper'),\n",
                     "  - Configure the fleet's GPU host with ",
                     "gpu.host::gpu_host_config(), or\n",
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
    if (route == "gpuhost") {
        if (!.has_gpu_host()) {
            stop("source = 'gpuhost' needs the gpu.host package.\n",
                 "Install with: remotes::install_github('cornball-ai/gpu.host')",
                 call. = FALSE)
        }
        if (!gpu.host::gpu_host_configured()) {
            stop("source = 'gpuhost' requested but no GPU host is configured.\n",
                 "Use gpu.host::gpu_host_config(base = , token = ), or set ",
                 "options(gpu.host.base = ) and options(gpu.host.token = ).",
                 call. = FALSE)
        }
    }

    list(backend = backend, route = route)
}


# Test internal helper functions

# --- .time_to_seconds() ---

# Numeric passthrough
expect_equal(stt.api:::.time_to_seconds(123.5), 123.5)
expect_equal(stt.api:::.time_to_seconds(0), 0)

# HH:MM:SS format
expect_equal(stt.api:::.time_to_seconds("01:30:45"), 5445)  # 1*3600 + 30*60 + 45
expect_equal(stt.api:::.time_to_seconds("00:00:00"), 0)
expect_equal(stt.api:::.time_to_seconds("02:00:00"), 7200)

# MM:SS format
expect_equal(stt.api:::.time_to_seconds("01:30"), 90)
expect_equal(stt.api:::.time_to_seconds("00:45"), 45)

# Seconds only
expect_equal(stt.api:::.time_to_seconds("45"), 45)

# NA/NULL handling
expect_true(is.na(stt.api:::.time_to_seconds(NA)))
expect_true(is.na(stt.api:::.time_to_seconds(NULL)))

# --- .normalize_segments() ---

# NULL/empty handling
expect_null(stt.api:::.normalize_segments(NULL))
expect_equal(nrow(stt.api:::.normalize_segments(data.frame())), 0)

# from/to -> start/end conversion
df_from_to <- data.frame(text = "hello", from = 0, to = 1.5)
result <- stt.api:::.normalize_segments(df_from_to)
expect_true("start" %in% names(result))
expect_true("end" %in% names(result))
expect_equal(result$start, 0)
expect_equal(result$end, 1.5)

# String time conversion
df_strings <- data.frame(text = "hello", start = "00:01:30", end = "00:02:00")
result <- stt.api:::.normalize_segments(df_strings)
expect_equal(result$start, 90)
expect_equal(result$end, 120)

# Already numeric - no change
df_numeric <- data.frame(text = "hello", start = 10.5, end = 15.0)
result <- stt.api:::.normalize_segments(df_numeric)
expect_equal(result$start, 10.5)
expect_equal(result$end, 15.0)

# --- .resolve_route() (source axis, mirrors tts.api) ---
# Use a temporary api base for the "api" routes; clear whisper option deps by
# operating only on routes that don't require the whisper package to be loaded.
old_base <- getOption("stt.api_base")
on.exit(options(stt.api_base = old_base), add = TRUE)

# openai always routes to the API (base required)
options(stt.api_base = "http://localhost:9999")
r <- stt.api:::.resolve_route("openai", "auto")
expect_equal(r$route, "api")
expect_equal(r$backend, "openai")

# openai + package is an error (no in-process engine for openai)
expect_error(stt.api:::.resolve_route("openai", "package"))

# whisper + api routes to the API (the serve() endpoint), base required
r <- stt.api:::.resolve_route("whisper", "api")
expect_equal(r$route, "api")
expect_equal(r$backend, "whisper")

# auto + api with a base set -> openai over the API
r <- stt.api:::.resolve_route("auto", "api")
expect_equal(r$route, "api")

# api route with no base set is an error
options(stt.api_base = NULL)
expect_error(stt.api:::.resolve_route("whisper", "api"))

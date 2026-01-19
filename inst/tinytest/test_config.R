# Test configuration functions

# --- Setup: save and restore options ---
old_opts <- options(stt.api_base = NULL, stt.api_key = NULL)
on.exit(options(old_opts), add = TRUE)

# --- set_stt_base() ---

# Returns previous value invisibly (NULL initially)
expect_null(set_stt_base("http://localhost:4123"))

# Sets the option
expect_equal(getOption("stt.api_base"), "http://localhost:4123")

# Returns previous value when called again
expect_equal(set_stt_base("https://api.openai.com"), "http://localhost:4123")
expect_equal(getOption("stt.api_base"), "https://api.openai.com")

# --- set_stt_key() ---

# Reset first
options(stt.api_key = NULL)

# Returns previous value (NULL initially)
expect_null(set_stt_key("sk-test-key"))

# Sets the option
expect_equal(getOption("stt.api_key"), "sk-test-key")

# Returns previous value when called again
expect_equal(set_stt_key("sk-new-key"), "sk-test-key")

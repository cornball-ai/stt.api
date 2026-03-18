# stt.api 0.2.0

* Remove audio.whisper backend
* Remove gpu.ctl integration
* Remove processx dependency (never implemented)
* Backends are now: whisper (native R torch) and OpenAI-compatible API

# stt.api 0.1.0

* Initial release
* Support for OpenAI-compatible speech-to-text APIs
* Local server support (LM Studio, OpenWebUI, Whisper containers)
* Optional whisper package integration for local transcription
* Segment-level timestamps with word-level timing when available

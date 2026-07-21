class_name Narrator
extends RefCounted
## Thin wrapper over the OS text-to-speech voice (same approach as Ant Explorer's
## intro fallback). Baked WAV narration can be added later; for the preview we
## speak live and pace the tour with a word-count estimate.

## Speak a line. Returns an estimated duration in seconds so a caller can pace a
## sequence without needing utterance callbacks.
static func speak(text: String) -> float:
	if text.strip_edges().is_empty():
		return 0.0
	if DisplayServer.tts_get_voices().size() > 0:
		DisplayServer.tts_stop()
		# volume is 0–100 (int). Passing 1.0 was ~1% — barely audible next to video.
		DisplayServer.tts_speak(text, "", 100, 1.0, 0.95)
	return estimate_seconds(text)

static func stop() -> void:
	if DisplayServer.tts_get_voices().size() > 0:
		DisplayServer.tts_stop()

## ~2.6 words/sec spoken, with a floor and a little trailing pause.
static func estimate_seconds(text: String) -> float:
	var words := text.split(" ", false).size()
	return maxf(1.6, float(words) / 2.6 + 0.7)

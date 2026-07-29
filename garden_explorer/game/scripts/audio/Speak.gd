class_name Speak
extends RefCounted
## Thin wrapper so UI scripts call Narrator without class_name cache issues.

const NarratorScript := preload("res://scripts/audio/Narrator.gd")

static func line(text: String, tap_cancellable: bool = false, lock_movement: bool = true) -> float:
	return NarratorScript.speak(text, tap_cancellable, lock_movement)

static func soft(text: String) -> float:
	## Tip VO that must not freeze walking (empty-bed water, etc.).
	return NarratorScript.speak(text, false, false)

static func stop() -> void:
	NarratorScript.stop()

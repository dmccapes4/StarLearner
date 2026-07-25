class_name Speak
extends RefCounted
## Thin wrapper so UI scripts call Narrator without class_name cache issues.

const NarratorScript := preload("res://scripts/audio/Narrator.gd")

static func line(text: String) -> float:
	return NarratorScript.speak(text)

static func stop() -> void:
	NarratorScript.stop()

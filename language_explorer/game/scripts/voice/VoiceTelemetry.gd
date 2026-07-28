class_name VoiceTelemetry
extends RefCounted
## Structured voice-flow logs for adb logcat (`adb logcat | grep VoiceTel`).

const TAG := "VoiceTel"

static func log(event: String, fields: Dictionary = {}) -> void:
	var parts: PackedStringArray = [TAG, event]
	var keys := fields.keys()
	keys.sort()
	for k in keys:
		parts.append("%s=%s" % [str(k), str(fields[k])])
	print(" ".join(parts))

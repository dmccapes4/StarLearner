class_name VoiceNextStore
extends RefCounted
## Persistent enrolled "next" clip — survives sessions; optional re-record tile.

const PATH := "user://voice/next_enroll.wav"
const SEEN_KEY := "voice_next_enrolled"

static func has_saved() -> bool:
	return Save.was_seen(SEEN_KEY) and FileAccess.file_exists(PATH)

static func save_from(source_path: String) -> bool:
	if source_path.is_empty() or not FileAccess.file_exists(source_path):
		return false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://voice"))
	var dst := ProjectSettings.globalize_path(PATH)
	var err := DirAccess.copy_absolute(ProjectSettings.globalize_path(source_path), dst)
	if err != OK:
		push_warning("VoiceNextStore: copy failed %s → %s (%s)" % [source_path, PATH, err])
		return false
	Save.mark_seen(SEEN_KEY)
	return true

static func saved_path() -> String:
	if FileAccess.file_exists(PATH):
		return PATH
	return ""

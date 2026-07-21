class_name RoleVO
extends Node
## First adoption per role per session: pre-baked Piper wav (raw-load OK).

const VO_PATH := "res://data/role_vo.json"
const VO_DIR := "res://assets/audio/vo/roles"
const ENTER_CUE := "res://assets/audio/kenney_ui/Audio/switch3.ogg"
const ALT_CUE := "res://assets/audio/kenney_ui/Audio/rollover3.ogg"
const _VoStream := preload("res://scripts/content/VoStream.gd")

signal role_announced(role_key: String, line1: String, line2: String, line3: String)

var narrator: Node = null  ## optional Narrator queue; direct player fallback
var _lines: Dictionary = {}
var _visited: Dictionary = {}
var _cue_player: AudioStreamPlayer
var _vo_player: AudioStreamPlayer

func _init() -> void:
	_load_lines()

func _ready() -> void:
	if _lines.is_empty():
		_load_lines()
	_cue_player = AudioStreamPlayer.new()
	_cue_player.volume_db = -12.0
	add_child(_cue_player)
	var cue := ENTER_CUE if ResourceLoader.exists(ENTER_CUE) else ALT_CUE
	if ResourceLoader.exists(cue):
		_cue_player.stream = load(cue)
	_vo_player = AudioStreamPlayer.new()
	_vo_player.volume_db = 0.0
	add_child(_vo_player)
	Events.role_changed.connect(_on_role_changed)

func _on_role_changed(role: int) -> void:
	if role != AntEnums.Role.NONE:
		try_announce(role)

func _load_lines() -> void:
	_lines.clear()
	if not FileAccess.file_exists(VO_PATH):
		push_warning("RoleVO: missing %s" % VO_PATH)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(VO_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var roles: Dictionary = (parsed as Dictionary).get("roles", {})
	for key in roles:
		_lines[str(key)] = roles[key]

func reset_session() -> void:
	_visited.clear()

func has_visited(role: int) -> bool:
	var key := AntEnums.role_name(role)
	return key.is_empty() or _visited.has(key)

func try_announce(role: int) -> bool:
	var key := AntEnums.role_name(role)
	if key.is_empty() or _visited.has(key):
		return false
	if not _lines.has(key):
		_visited[key] = true
		return false
	_visited[key] = true
	var entry: Dictionary = _lines[key]
	_speak(key, str(entry.get("line1", "")), str(entry.get("line2", "")), str(entry.get("line3", "")))
	return true

func _speak(role_key: String, line1: String, line2: String, line3: String) -> void:
	if _vo_player and _vo_player.playing:
		_vo_player.stop()
	var full := "%s %s %s" % [line1, line2, line3]
	print("Role VO [%s]: %s" % [role_key, full])
	role_announced.emit(role_key, line1, line2, line3)
	var wav_path: String = _VoStream.resolve_vo(VO_DIR, role_key)
	var stream: AudioStream = _VoStream.load_path(wav_path) if not wav_path.is_empty() else null
	if stream != null:
		if narrator != null and narrator.has_method("speak"):
			narrator.speak(stream, "role:%s" % role_key)
		elif _vo_player:
			_vo_player.stream = stream
			_vo_player.play()
		return
	if _cue_player and _cue_player.stream:
		_cue_player.volume_db = -4.0
		_cue_player.play()
	if DisplayServer.tts_get_voices().size() > 0:
		DisplayServer.tts_stop()
		DisplayServer.tts_speak(full, "", 1.0, 1.0, 0.9)

func lines_for(role: int) -> PackedStringArray:
	var key := AntEnums.role_name(role)
	if not _lines.has(key):
		return PackedStringArray()
	var e: Dictionary = _lines[key]
	return PackedStringArray([
		str(e.get("line1", "")),
		str(e.get("line2", "")),
		str(e.get("line3", "")),
	])

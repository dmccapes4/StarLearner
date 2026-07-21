class_name ChamberVO
extends Node
## First visit per session: play pre-baked Piper VO wav (raw-load OK).
## Soft enter cue only when no wav file exists.

const VO_PATH := "res://data/chamber_vo.json"
const VO_DIR := "res://assets/audio/vo"
const ENTER_CUE := "res://assets/audio/kenney_ui/Audio/switch3.ogg"
const ALT_CUE := "res://assets/audio/kenney_ui/Audio/rollover3.ogg"
const _VoStream := preload("res://scripts/content/VoStream.gd")

signal chamber_announced(zone: String, line1: String, line2: String)

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

func _load_lines() -> void:
	_lines.clear()
	if not FileAccess.file_exists(VO_PATH):
		push_warning("ChamberVO: missing %s" % VO_PATH)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(VO_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var chambers: Dictionary = (parsed as Dictionary).get("chambers", {})
	for zone in chambers:
		_lines[str(zone)] = chambers[zone]

func reset_session() -> void:
	_visited.clear()

func has_visited(zone: String) -> bool:
	return _visited.has(zone)

func try_announce(zone: String) -> bool:
	if zone.is_empty() or _visited.has(zone):
		return false
	if not _lines.has(zone):
		_visited[zone] = true
		return false
	_visited[zone] = true
	var entry: Dictionary = _lines[zone]
	_speak(zone, str(entry.get("line1", "")), str(entry.get("line2", "")))
	return true

func _speak(zone: String, line1: String, line2: String) -> void:
	if _vo_player and _vo_player.playing:
		_vo_player.stop()
	var full := "%s %s" % [line1, line2]
	print("VO [%s]: %s" % [zone, full])
	chamber_announced.emit(zone, line1, line2)
	var wav_path: String = _VoStream.resolve_vo(VO_DIR, zone)
	var stream: AudioStream = _VoStream.load_path(wav_path) if not wav_path.is_empty() else null
	if stream != null:
		if narrator != null and narrator.has_method("speak"):
			narrator.speak(stream, "chamber:%s" % zone)
		elif _vo_player:
			_vo_player.stream = stream
			_vo_player.play()
		return
	# No wav: soft cue + OS TTS fallback.
	if _cue_player and _cue_player.stream:
		_cue_player.volume_db = -4.0
		_cue_player.play()
	if DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		DisplayServer.tts_stop()
		DisplayServer.tts_speak(full, "", 1.0, 1.0, 0.9)

func lines_for(zone: String) -> PackedStringArray:
	if not _lines.has(zone):
		return PackedStringArray()
	var e: Dictionary = _lines[zone]
	return PackedStringArray([str(e.get("line1", "")), str(e.get("line2", ""))])

class_name GateSfx
extends RefCounted
## Quick wood gate creak / latch for pen gate open & close.

const OPEN_PATH := "res://assets/audio/sfx/gate_open.ogg"
const CLOSE_PATH := "res://assets/audio/sfx/gate_close.ogg"

static var _player: AudioStreamPlayer

static func play_open() -> void:
	_play(OPEN_PATH)

static func play_close() -> void:
	_play(CLOSE_PATH)

static func _play(path: String) -> void:
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is AudioStream:
			stream = res
	if stream == null:
		var abs := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(abs):
			stream = AudioStreamOggVorbis.load_from_file(abs)
	if stream == null:
		return
	var p := _ensure_player()
	p.stream = stream
	p.volume_db = -4.0
	p.play()

static func _ensure_player() -> AudioStreamPlayer:
	if _player != null and is_instance_valid(_player):
		return _player
	var tree := Engine.get_main_loop() as SceneTree
	_player = AudioStreamPlayer.new()
	_player.name = "GateSfxPlayer"
	_player.bus = "Master"
	tree.root.add_child(_player)
	return _player

class_name AnimalSfx
extends RefCounted
## Plays recorded animal sounds (not TTS).

const SFX_DIR := "res://assets/audio/animals/"

static var _player: AudioStreamPlayer

static func play(animal_id: String) -> void:
	var kind := _kind(animal_id)
	var path := SFX_DIR + kind + ".ogg"
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is AudioStream:
			stream = res
	if stream == null:
		## Fallback via raw file (may lack .import).
		var abs := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(abs):
			stream = _load_ogg(abs)
	if stream == null:
		return
	var p := _ensure_player()
	p.stream = stream
	p.volume_db = -2.0
	p.play()

static func _kind(animal_id: String) -> String:
	var id := animal_id.to_lower()
	if id.begins_with("chicken"):
		return "chicken"
	if id.begins_with("cow"):
		return "cow"
	if id.begins_with("pig"):
		return "pig"
	if id.begins_with("dog"):
		return "dog"
	if id.begins_with("rabbit"):
		return "rabbit"
	return "chicken"

static func _ensure_player() -> AudioStreamPlayer:
	if _player != null and is_instance_valid(_player):
		return _player
	var tree := Engine.get_main_loop() as SceneTree
	_player = AudioStreamPlayer.new()
	_player.name = "AnimalSfxPlayer"
	_player.bus = "Master"
	tree.root.add_child(_player)
	return _player

static func _load_ogg(abs_path: String) -> AudioStream:
	## Godot 4 can load OggVorbis via ResourceLoader when imported; for raw files
	## prefer AudioStreamOggVorbis.load_from_file when available.
	return AudioStreamOggVorbis.load_from_file(abs_path)

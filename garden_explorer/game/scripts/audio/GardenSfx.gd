class_name GardenSfx
extends RefCounted
## Short plant / water / uproot / harvest cues (Stardew-ish soft farm SFX).

const DIR := "res://assets/audio/sfx"
static var _player: AudioStreamPlayer = null

static func plant() -> void:
	_play("plant_seed.wav", -4.0)

static func water() -> void:
	_play("water_pour.wav", -6.0)

static func uproot() -> void:
	_play("uproot.wav", -5.0)

static func harvest() -> void:
	_play("harvest.wav", -8.0)

static func _play(file: String, db: float) -> void:
	var path := "%s/%s" % [DIR, file]
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		stream = load(path)
	elif FileAccess.file_exists(path):
		## Headless / unimported wav.
		var f := FileAccess.open(path, FileAccess.READ)
		if f:
			var bytes := f.get_buffer(f.get_length())
			var wav := AudioStreamWAV.new()
			## Skip 44-byte header for our generated PCM16 mono 22050 files.
			if bytes.size() > 44:
				wav.data = bytes.slice(44)
				wav.format = AudioStreamWAV.FORMAT_16_BITS
				wav.mix_rate = 22050
				wav.stereo = false
				stream = wav
	if stream == null:
		return
	var p := _ensure()
	if p == null:
		return
	p.stop()
	p.stream = stream
	p.volume_db = db
	p.play()

static func _ensure() -> AudioStreamPlayer:
	if _player != null and is_instance_valid(_player):
		return _player
	var loop := Engine.get_main_loop()
	if loop == null or not (loop is SceneTree):
		return null
	_player = AudioStreamPlayer.new()
	_player.name = "GardenSfx"
	_player.bus = "Master"
	(loop as SceneTree).root.add_child(_player)
	return _player

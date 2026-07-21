class_name VoStream
extends RefCounted
## Load baked VO audio (same approach as Ant Explorer). Works even before Godot
## imports the WAV (gen tools write raw PCM files ResourceLoader ignores until
## --import runs).

static func load_path(path: String) -> AudioStream:
	if path.is_empty():
		return null
	if ResourceLoader.exists(path):
		var res: Resource = load(path)
		if res is AudioStream:
			return res as AudioStream
	if not FileAccess.file_exists(path):
		return null
	if path.ends_with(".wav"):
		return _load_wav_file(path)
	return null

static func _load_wav_file(path: String) -> AudioStreamWAV:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_warning("VoStream: cannot open %s" % path)
		return null
	var bytes: PackedByteArray = f.get_buffer(f.get_length())
	f.close()
	if bytes.size() < 44:
		return null
	# Minimal RIFF/WAVE PCM parser.
	if bytes.slice(0, 4).get_string_from_ascii() != "RIFF":
		return null
	if bytes.slice(8, 12).get_string_from_ascii() != "WAVE":
		return null
	var offset := 12
	var channels := 1
	var sample_rate := 22050
	var bits_per_sample := 16
	var data := PackedByteArray()
	while offset + 8 <= bytes.size():
		var chunk_id := bytes.slice(offset, offset + 4).get_string_from_ascii()
		var chunk_size := _u32(bytes, offset + 4)
		var chunk_data_start := offset + 8
		var chunk_end := chunk_data_start + chunk_size
		if chunk_end > bytes.size():
			break
		if chunk_id == "fmt ":
			var audio_format := _u16(bytes, chunk_data_start)
			channels = _u16(bytes, chunk_data_start + 2)
			sample_rate = _u32(bytes, chunk_data_start + 4)
			bits_per_sample = _u16(bytes, chunk_data_start + 14)
			if audio_format != 1:
				push_warning("VoStream: unsupported WAV format %d in %s" % [audio_format, path])
				return null
		elif chunk_id == "data":
			data = bytes.slice(chunk_data_start, chunk_end)
			break
		offset = chunk_end
		if chunk_size % 2 == 1:
			offset += 1
	if data.is_empty():
		return null
	var stream := AudioStreamWAV.new()
	stream.mix_rate = sample_rate
	stream.stereo = channels > 1
	match bits_per_sample:
		8:
			stream.format = AudioStreamWAV.FORMAT_8_BITS
		16:
			stream.format = AudioStreamWAV.FORMAT_16_BITS
		_:
			push_warning("VoStream: unsupported bit depth %d in %s" % [bits_per_sample, path])
			return null
	stream.data = data
	return stream

static func _u16(b: PackedByteArray, i: int) -> int:
	return int(b[i]) | (int(b[i + 1]) << 8)

static func _u32(b: PackedByteArray, i: int) -> int:
	return int(b[i]) | (int(b[i + 1]) << 8) | (int(b[i + 2]) << 16) | (int(b[i + 3]) << 24)

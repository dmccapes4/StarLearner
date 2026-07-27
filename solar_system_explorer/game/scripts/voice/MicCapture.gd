extends Node
## Record microphone audio to a WAV under user://voice/.
## Requires project setting audio/driver/enable_input=true and (on Android)
## RECORD_AUDIO permission. Ported from Language Explorer — capture only;
## matching stays offline in VoiceCommands.
##
## Flight listen keeps the mic player running and takes windows via
## take_pcm_window() (toggle AudioEffectRecord only). Full start()/cancel()
## still rebuild the stream for enroll and pause/blur.

signal recording_finished(path: String)
signal recording_failed(reason: String)

const BUS_NAME := "MicRecord"
const VOICE_DIR := "user://voice"
## Default silence floor for live listen. Enroll uses a lower floor — "slower"
## and "stop" often peak well under 800 on this handset.
const SILENCE_PEAK := 400
const ENROLL_MIN_PEAK := 120
const NORM_TARGET := 10000

var _bus_idx: int = -1
var _effect: AudioEffectRecord
var _recording: bool = false
var _mic_player: AudioStreamPlayer
var _built: bool = false

func ensure_ready() -> bool:
	if _built:
		return _mic_player != null
	_built = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(VOICE_DIR))
	_bus_idx = AudioServer.get_bus_index(BUS_NAME)
	if _bus_idx < 0:
		AudioServer.add_bus()
		_bus_idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(_bus_idx, BUS_NAME)
		AudioServer.set_bus_send(_bus_idx, "Master")
		AudioServer.set_bus_mute(_bus_idx, true)
	_mic_player = AudioStreamPlayer.new()
	_mic_player.bus = BUS_NAME
	add_child(_mic_player)
	_rebuild_record_effect()
	return _effect != null

func _rebuild_record_effect() -> void:
	if _bus_idx < 0:
		return
	for i in range(AudioServer.get_bus_effect_count(_bus_idx) - 1, -1, -1):
		var fx := AudioServer.get_bus_effect(_bus_idx, i)
		if fx is AudioEffectRecord:
			AudioServer.remove_bus_effect(_bus_idx, i)
	_effect = AudioEffectRecord.new()
	AudioServer.add_bus_effect(_bus_idx, _effect)

func is_recording() -> bool:
	return _recording

## Snapshot for flight telemetry — want_hot means Solar intends to hold the mic.
func status() -> Dictionary:
	var player_on := _mic_player != null and _mic_player.playing
	var effect_on := false
	if _effect != null:
		effect_on = _effect.is_recording_active()
	return {
		"rec": _recording,
		"player": player_on,
		"effect": effect_on,
		"hot": _recording and player_on,
	}

func start() -> bool:
	if not ensure_ready():
		recording_failed.emit("mic_unavailable")
		print("PGTEL EV mic start ok=0 reason=unavailable")
		return false
	if _recording:
		cancel()
	_rebuild_record_effect()
	if _mic_player.playing:
		_mic_player.stop()
	_mic_player.stream = AudioStreamMicrophone.new()
	_mic_player.play()
	_effect.set_recording_active(true)
	_recording = true
	var st := status()
	print("PGTEL EV mic start ok=1 player=%d effect=%d" % [
		1 if st["player"] else 0, 1 if st["effect"] else 0])
	return true

## One listen window without stopping AudioStreamMicrophone.
## Rebuilds the Record effect after each take so Android cannot hand back
## the previous clip (that was causing endless "voice stale" loops).
## Always returns peak/n/reason so flight telemetry can see cold captures.
func take_pcm_window(min_peak: int = SILENCE_PEAK) -> Dictionary:
	var out := {
		"ok": false, "peak": 0, "stereo": false, "data": PackedByteArray(),
		"n": 0, "reason": "idle", "player": false, "effect": false,
	}
	var st := status()
	out["player"] = st["player"]
	out["effect"] = st["effect"]
	if not _recording or _effect == null:
		out["reason"] = "not_recording"
		_tel_win(out, min_peak)
		return out
	if not st["player"]:
		out["reason"] = "player_dead"
		_tel_win(out, min_peak)
		return out
	_effect.set_recording_active(false)
	var stream: AudioStreamWAV = _effect.get_recording()
	_rebuild_record_effect()
	_effect.set_recording_active(true)
	if stream == null or stream.data.is_empty():
		out["reason"] = "empty"
		recording_failed.emit("empty")
		_tel_win(out, min_peak)
		return out
	var peak := _peak_16(stream)
	out["peak"] = peak
	out["n"] = stream.data.size()
	out["stereo"] = stream.stereo
	if peak < min_peak:
		out["reason"] = "silent"
		recording_failed.emit("silent")
		_tel_win(out, min_peak)
		return out
	out["ok"] = true
	out["reason"] = "hot"
	out["data"] = stream.data.duplicate()
	_tel_win(out, min_peak)
	return out

func _tel_win(out: Dictionary, min_peak: int) -> void:
	print("PGTEL EV mic win peak=%d min=%d n=%d ok=%d reason=%s player=%d effect=%d" % [
		int(out.get("peak", 0)), min_peak, int(out.get("n", 0)),
		1 if out.get("ok", false) else 0, str(out.get("reason", "?")),
		1 if out.get("player", false) else 0,
		1 if out.get("effect", false) else 0,
	])

## In-memory capture that also stops the session (enroll / one-shot).
func stop_to_pcm(min_peak: int = SILENCE_PEAK) -> Dictionary:
	var empty := {"ok": false, "peak": 0, "stereo": false, "data": PackedByteArray(),
		"n": 0, "reason": "idle"}
	if not _recording:
		empty["reason"] = "not_recording"
		return empty
	_effect.set_recording_active(false)
	_recording = false
	if _mic_player.playing:
		_mic_player.stop()
	var stream: AudioStreamWAV = _effect.get_recording()
	_rebuild_record_effect()
	if stream == null or stream.data.is_empty():
		recording_failed.emit("empty")
		empty["reason"] = "empty"
		print("PGTEL EV mic peak=0 min=%d file=pcm:0 reason=empty" % min_peak)
		return empty
	var peak := _peak_16(stream)
	print("PGTEL EV mic peak=%d min=%d file=pcm:%d" % [peak, min_peak, stream.data.size()])
	if peak < min_peak:
		recording_failed.emit("silent")
		empty["peak"] = peak
		empty["n"] = stream.data.size()
		empty["reason"] = "silent"
		return empty
	return {
		"ok": true,
		"peak": peak,
		"stereo": stream.stereo,
		"data": stream.data.duplicate(),
		"n": stream.data.size(),
		"reason": "hot",
	}

## min_peak: reject below this 16-bit amplitude. normalize: boost quiet speech.
func stop_to_file(filename: String = "clip.wav", min_peak: int = SILENCE_PEAK,
		normalize: bool = false) -> String:
	if not _recording:
		return ""
	_effect.set_recording_active(false)
	_recording = false
	if _mic_player.playing:
		_mic_player.stop()
	var stream: AudioStreamWAV = _effect.get_recording()
	_rebuild_record_effect()
	if stream == null:
		recording_failed.emit("empty")
		return ""
	var peak := _peak_16(stream)
	print("PGTEL EV mic peak=%d min=%d file=%s" % [peak, min_peak, filename])
	if peak < min_peak:
		push_warning("MicCapture: silent clip (peak %d < %d)" % [peak, min_peak])
		recording_failed.emit("silent")
		return ""
	if normalize and peak > 0 and peak < NORM_TARGET:
		_boost_stream(stream, float(NORM_TARGET) / float(peak))
	var path := "%s/%s" % [VOICE_DIR, filename]
	var abs_path := ProjectSettings.globalize_path(path)
	var err := stream.save_to_wav(abs_path)
	if err != OK:
		recording_failed.emit("save_failed")
		return ""
	recording_finished.emit(path)
	return path

func cancel() -> void:
	if not _recording and (_mic_player == null or not _mic_player.playing):
		return
	print("PGTEL EV mic cancel was_rec=%d player=%d" % [
		1 if _recording else 0,
		1 if (_mic_player != null and _mic_player.playing) else 0])
	if _effect != null:
		_effect.set_recording_active(false)
	_recording = false
	if _mic_player != null and _mic_player.playing:
		_mic_player.stop()
	_rebuild_record_effect()

static func _peak_16(stream: AudioStreamWAV) -> int:
	var data: PackedByteArray = stream.data
	if data.is_empty():
		return 0
	var peak := 0
	var i := 0
	var n := data.size()
	var step := 4 if stream.stereo else 2
	while i + 1 < n:
		var s := int(data[i]) | (int(data[i + 1]) << 8)
		if s >= 32768:
			s -= 65536
		var a := absi(s)
		if a > peak:
			peak = a
		i += step
	return peak

static func _boost_stream(stream: AudioStreamWAV, gain: float) -> void:
	gain = clampf(gain, 1.0, 12.0)
	var data: PackedByteArray = stream.data
	var out := PackedByteArray()
	out.resize(data.size())
	var i := 0
	while i + 1 < data.size():
		var s := int(data[i]) | (int(data[i + 1]) << 8)
		if s >= 32768:
			s -= 65536
		var v := int(clampf(float(s) * gain, -32768.0, 32767.0))
		if v < 0:
			v += 65536
		out[i] = v & 0xff
		out[i + 1] = (v >> 8) & 0xff
		i += 2
	stream.data = out

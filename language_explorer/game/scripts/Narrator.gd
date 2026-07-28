class_name Narrator
extends RefCounted
## Narration with baked ElevenLabs clips (tools/gen_language_vo.py later), falling
## back to OS TTS only when a clip is missing.
##
## Android TTS crash gate (Godot 4.3): never call tts_get_voices(); stay silent
## until WARMUP_MS has elapsed before using DisplayServer.tts_speak.

const VO_DIR := "res://audio/vo"
const WARMUP_MS := 3500

const _VoStream := preload("res://scripts/VoStream.gd")
const _NarratorVoice := preload("res://scripts/NarratorVoice.gd")

static var _voice: Node = null
## While narration plays, chrome taps are ignored (see Main input gate).
static var _busy_until_ms: int = 0

static func blocks_input() -> bool:
	return Time.get_ticks_msec() < _busy_until_ms

static func _lock_input(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(maxi(0, int(ceil(seconds * 1000.0))))
	if until > _busy_until_ms:
		_busy_until_ms = until

static func warmup_remaining_ms() -> int:
	return maxi(0, WARMUP_MS - int(Time.get_ticks_msec()))

static func _tts_available() -> bool:
	return DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH) \
		and Time.get_ticks_msec() >= WARMUP_MS

static func split_sentences(text: String) -> PackedStringArray:
	var out := PackedStringArray()
	var cur := ""
	for ch in text.strip_edges():
		cur += ch
		if ch == "." or ch == "!" or ch == "?":
			var s := normalize_line(cur)
			if not s.is_empty():
				out.append(s)
			cur = ""
	var tail := normalize_line(cur)
	if not tail.is_empty():
		out.append(tail)
	return out

static func normalize_line(text: String) -> String:
	var parts := text.strip_edges().split(" ", false)
	return " ".join(parts)

static func vo_key(sentence: String) -> String:
	return normalize_line(sentence).md5_text()

static func vo_path(sentence: String) -> String:
	return "%s/%s.wav" % [VO_DIR, vo_key(sentence)]

static func is_playing() -> bool:
	if _voice != null and is_instance_valid(_voice) and _voice.has_method("is_active"):
		return bool(_voice.call("is_active"))
	return false

static func await_playback(tree: SceneTree) -> void:
	if tree == null:
		return
	while is_playing() or blocks_input():
		await tree.process_frame

static func speak(text: String) -> float:
	if text.strip_edges().is_empty():
		return 0.0
	var sentences := split_sentences(text)
	var streams: Array = []
	var baked_s := 0.0
	for s in sentences:
		var stream: AudioStream = _VoStream.load_path(vo_path(s))
		if stream == null:
			streams = []
			break
		streams.append(stream)
		baked_s += stream.get_length()
	if not streams.is_empty():
		stop()
		var voice: Node = _ensure_voice()
		var dur := baked_s + 0.15 * float(streams.size()) + 0.5
		if voice != null:
			voice.play_queue(streams)
		_lock_input(dur)
		return dur
	var est := estimate_seconds(text)
	stop()
	if _tts_available():
		DisplayServer.tts_speak(text, "", 100, 1.0, 0.95)
	_lock_input(est)
	return est

static func stop() -> void:
	if _voice != null and is_instance_valid(_voice):
		_voice.stop_all()
	if _tts_available():
		DisplayServer.tts_stop()
	_busy_until_ms = 0

static func _ensure_voice() -> Node:
	if _voice != null and is_instance_valid(_voice):
		return _voice
	var loop := Engine.get_main_loop()
	if loop == null or not (loop is SceneTree):
		return null
	_voice = _NarratorVoice.new()
	_voice.name = "NarratorVoice"
	(loop as SceneTree).root.add_child(_voice)
	return _voice

static func estimate_seconds(text: String) -> float:
	var words := text.split(" ", false).size()
	return maxf(1.6, float(words) / 2.6 + 0.7)

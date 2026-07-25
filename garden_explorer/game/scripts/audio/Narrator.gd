class_name Narrator
extends RefCounted
## Narration with a warm baked ElevenLabs voice (tools/gen_math_vo.py), falling
## back to the OS text-to-speech engine only for sentences with no baked clip.
##
## Baked clips are per *sentence*, keyed by md5 of the normalized text
## (audio/vo/<md5>.wav). Dynamic lines ("That is 12 eggs every day.") still hit
## the cache because scenes draw their numbers from MathProblemGen.VO_SEED_POOL
## and tools/dump_vo_lines.gd enumerates every sentence ahead of time.

const VO_DIR := "res://audio/vo"

## Preloaded (not class_name lookups) so headless runs see fresh classes
## before the editor rescans the global class cache.
const _VoStream := preload("res://scripts/audio/VoStream.gd")
const _NarratorVoice := preload("res://scripts/audio/NarratorVoice.gd")

## While narration plays, player walk input is ignored (see Player).
static var _busy_until_ms: int = 0

static func blocks_movement() -> bool:
	return Time.get_ticks_msec() < _busy_until_ms

static func _lock_movement(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(maxi(0, int(ceil(seconds * 1000.0))))
	if until > _busy_until_ms:
		_busy_until_ms = until

## The Android OS TTS engine binds *asynchronously* a second or two after launch.
## Touching TTS before it's bound crashes the whole process (Godot 4.3):
##   • tts_get_voices() returns a null array → native step() aborts on
##     GetArrayLength(null) (SIGABRT) — so we never call it, and
##   • tts_speak() before binding throws in GodotTTS.updateTTS() → hard crash.
## There is no safe readiness probe, so we stay silent until a warmup window has
## elapsed since engine start, by which point the engine is reliably bound.
## (Only relevant for the TTS fallback — baked clips play immediately.)
const WARMUP_MS := 3500

static var _voice: Node = null

static func warmup_remaining_ms() -> int:
	return maxi(0, WARMUP_MS - int(Time.get_ticks_msec()))

## Whether it is safe to talk to the OS TTS engine right now.
static func _tts_available() -> bool:
	return DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH) \
		and Time.get_ticks_msec() >= WARMUP_MS

## Split a narration line into sentences (baked clips are per sentence).
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

## Collapse whitespace so runtime text and the dump tool hash identically.
static func normalize_line(text: String) -> String:
	var parts := text.strip_edges().split(" ", false)
	return " ".join(parts)

static func vo_key(sentence: String) -> String:
	return normalize_line(sentence).md5_text()

static func vo_path(sentence: String) -> String:
	return "%s/%s.wav" % [VO_DIR, vo_key(sentence)]

## Speak a line. Returns an estimated duration in seconds so a caller can pace a
## sequence without needing utterance callbacks.
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
		_lock_movement(dur)
		return dur
	# Fallback: live OS TTS (only when a sentence has no baked clip).
	var est := estimate_seconds(text)
	if _tts_available():
		DisplayServer.tts_stop()
		# volume is 0–100 (int). Passing 1.0 was ~1% — barely audible.
		DisplayServer.tts_speak(text, "", 100, 1.0, 0.95)
	_lock_movement(est)
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
	# Add immediately (not deferred) so the first speak in the launch intro
	# can play — call_deferred left the player null for the opening line.
	(loop as SceneTree).root.add_child(_voice)
	return _voice

## ~2.6 words/sec spoken, with a floor and a little trailing pause.
static func estimate_seconds(text: String) -> float:
	var words := text.split(" ", false).size()
	return maxf(1.6, float(words) / 2.6 + 0.7)

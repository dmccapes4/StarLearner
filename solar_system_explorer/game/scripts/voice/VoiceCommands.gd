class_name VoiceCommands
extends Control
## Offline voice speed control for Free Flight.
## Enroll once (faster / slower / stop), then keep the mic ON in flight and
## match spoken words to those saved clips (energy envelopes — no Wi-Fi).

signal enroll_finished()
signal command(which: String)

const MicCaptureS := preload("res://scripts/voice/MicCapture.gd")

const WORDS: PackedStringArray = ["faster", "slower", "stop"]
const ENROLL_SECS := 2.4
const LISTEN_SECS := 1.0
const LISTEN_GAP_S := 0.55
const CMD_COOLDOWN_S := 3.2
const VO_HANGOVER_S := 0.55
const MATCH_MIN := 0.62
## Reject only when two words are nearly tied — was 0.05 and blocked real speech.
const AMBIG_MARGIN := 0.03
const ENERGY_MIN := 0.004
const ENROLL_ENERGY_MIN := 0.0012
const ENVELOPE_BINS := 24
const VOICE_DIR := "user://voice"
const LISTEN_MIN_PEAK := 500
## Remember buffer fingerprints so a stuck Android clip cannot rematch later
## as a different command (the delayed "faster" after saying stop).
const FP_TTL_MS := 10000

const LINE_INTRO := "Want to change speed while you fly? Tap the mic and say faster, then slower, then stop. Your words stay on this phone — no Wi-Fi needed."
const LINE_SAY := {
	"faster": "Tap the mic and say faster!",
	"slower": "Now tap and say slower — nice and clear!",
	"stop": "And tap and say stop!",
}
const LINE_GOT := "Got it!"
const LINE_SKIP := "That's okay — you can still tilt to steer. Let's fly!"
const LINE_LISTEN_ON := "Mic is on — say faster, slower, or stop anytime!"

var _mic: Node
var _mic_btn: Button
var _red_dot: Control
var _word_lbl: Label
var _skip_btn: Button
var _listen_badge: PanelContainer
var _listen_lbl: Label
var _busy: bool = false
var _gen: int = 0
var _enroll_i: int = 0
var _listening: bool = false
var _cmd_cd: float = 0.0
var _templates: Dictionary = {}
var _last_peak: int = -1
var _last_bytes: int = -1
var _last_win_peak: int = -1
var _last_win_reason: String = "off"
var _cold_streak: int = 0
var _seen_fp: Dictionary = {}   ## fingerprint → ticks_msec
var _last_hit_peak: int = -1
var _last_hit_ms: int = 0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_mic = MicCaptureS.new()
	add_child(_mic)
	_build_ui()

func mic_available() -> bool:
	return _mic != null and bool(_mic.call("ensure_ready"))

static func templates_ready() -> bool:
	for w in WORDS:
		if not FileAccess.file_exists("%s/%s.wav" % [VOICE_DIR, w]):
			return false
	return true

static func clear_templates() -> void:
	for w in WORDS:
		var p := "%s/%s.wav" % [VOICE_DIR, w]
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	var listen := "%s/_listen.wav" % VOICE_DIR
	if FileAccess.file_exists(listen):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(listen))

func load_templates() -> bool:
	_templates.clear()
	for w in WORDS:
		var env := envelope_from_wav("%s/%s.wav" % [VOICE_DIR, w], ENERGY_MIN)
		if env.is_empty():
			_templates.clear()
			return false
		_templates[w] = env
	return true

func begin_enroll() -> void:
	_gen += 1
	_busy = false
	_enroll_i = 0
	_listening = false
	_listen_badge.visible = false
	while _enroll_i < WORDS.size():
		var p := "%s/%s.wav" % [VOICE_DIR, WORDS[_enroll_i]]
		if not FileAccess.file_exists(p):
			break
		if envelope_from_wav(p, ENROLL_ENERGY_MIN).is_empty():
			break
		_enroll_i += 1
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_mic_btn.visible = true
	_skip_btn.visible = true
	_word_lbl.visible = true
	_set_recording(false)
	if _enroll_i >= WORDS.size():
		_finish_enroll()
		return
	if _enroll_i == 0:
		_word_lbl.text = "Say:  FASTER"
		Narrator.speak(LINE_INTRO)
	else:
		_prompt_current()

func cancel() -> void:
	_gen += 1
	_busy = false
	_listening = false
	if _mic != null:
		_mic.cancel()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_recording(false)
	_listen_badge.visible = false

func enable_flight_mic() -> void:
	start_listening()

func start_listening() -> void:
	if not load_templates():
		_listening = false
		_listen_badge.visible = false
		_tel("voice listen fail reason=no_templates")
		return
	_gen += 1
	var gen := _gen
	_listening = true
	_cmd_cd = 0.4
	_busy = false
	_last_peak = -1
	_last_bytes = -1
	_last_win_peak = -1
	_last_win_reason = "starting"
	_cold_streak = 0
	_seen_fp.clear()
	_last_hit_peak = -1
	_last_hit_ms = 0
	# Keep this Control visible so the MIC ON badge shows — enroll used to
	# set visible=false on the whole node, which hid any flight UI too.
	visible = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mic_btn.visible = false
	_skip_btn.visible = false
	_word_lbl.visible = false
	_listen_badge.visible = true
	_set_listen_badge(true)
	_tel("voice listen start")
	_listen_loop(gen)

func stop_listening() -> void:
	_gen += 1
	_busy = false
	_listening = false
	_last_win_reason = "off"
	if _mic != null:
		_mic.cancel()
	_listen_badge.visible = false
	_set_listen_badge(false)
	_tel("voice listen stop")

## Compact status for PlaygroundScene's periodic PGTEL line.
func tel_snapshot() -> String:
	if not _listening:
		return "mic=off"
	var st: Dictionary = {}
	if _mic != null:
		st = _mic.call("status") as Dictionary
	var hot := bool(st.get("hot", false)) and _last_win_reason == "hot"
	var tag := "hot" if hot else "cold"
	if Narrator.is_playing():
		tag = "vo"
	elif _cmd_cd > 0.0:
		tag = "cd"
	return "mic=%s peak=%d reason=%s player=%d rec=%d cd=%.1f" % [
		tag, _last_win_peak, _last_win_reason,
		1 if st.get("player", false) else 0,
		1 if st.get("rec", false) else 0,
		_cmd_cd,
	]

func _prompt_current() -> void:
	if _enroll_i >= WORDS.size():
		_finish_enroll()
		return
	var w: String = WORDS[_enroll_i]
	_word_lbl.text = "Say:  %s" % w.to_upper()
	Narrator.speak(str(LINE_SAY[w]))

func _on_mic_pressed() -> void:
	if _busy or _enroll_i >= WORDS.size():
		return
	_record_word(WORDS[_enroll_i])

func _on_skip() -> void:
	_gen += 1
	if _mic != null:
		_mic.cancel()
	_set_recording(false)
	for w in WORDS:
		var p := "%s/%s.wav" % [VOICE_DIR, w]
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	Narrator.speak(LINE_SKIP)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	enroll_finished.emit()

func _record_word(which: String) -> void:
	_gen += 1
	var gen := _gen
	_busy = true
	_set_recording(true)
	Narrator.stop()
	if not _mic.start():
		_busy = false
		_set_recording(false)
		Narrator.speak("Hmm, I couldn't hear the mic. Try again, or skip.")
		return
	await _wait(gen, 0.25)
	if gen != _gen:
		return
	_mic.cancel()
	if not _mic.start():
		_busy = false
		_set_recording(false)
		Narrator.speak("Hmm, I couldn't hear the mic. Try again, or skip.")
		return
	await _wait(gen, ENROLL_SECS)
	if gen != _gen:
		return
	var path: Variant = _mic.call("stop_to_file", "%s.wav" % which, 120, true)
	_set_recording(false)
	_busy = false
	var path_s := ""
	if typeof(path) == TYPE_STRING:
		path_s = path
	if path_s.is_empty() or envelope_from_wav(path_s, ENROLL_ENERGY_MIN).is_empty():
		Narrator.speak("Hmm, that was too quiet. Tap and say it again a little louder!")
		return
	_enroll_i += 1
	var d := Narrator.speak(LINE_GOT)
	await _wait(gen, maxf(0.55, d))
	if gen != _gen:
		return
	_prompt_current()

func _finish_enroll() -> void:
	_gen += 1
	# Stay visible=false until start_listening arms the badge.
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_recording(false)
	_mic_btn.visible = false
	_skip_btn.visible = false
	_word_lbl.visible = false
	load_templates()
	enroll_finished.emit()

func _listen_loop(gen: int) -> void:
	while _listening and gen == _gen:
		if _cmd_cd > 0.0:
			await _wait(gen, 0.1)
			_cmd_cd = maxf(0.0, _cmd_cd - 0.1)
			continue
		# Don't hear narrator VO (or its echo) — that was re-firing "faster"
		# right after "stop" and made speed changes last ~1 second.
		if Narrator.is_playing():
			_last_win_reason = "vo"
			_set_listen_badge(false)
			if _mic.is_recording():
				_mic.cancel()
			await _wait(gen, 0.15)
			_cmd_cd = VO_HANGOVER_S
			continue
		_set_listen_badge(true)
		# Keep the mic player up across windows — only slice Record effects.
		if not _mic.is_recording():
			if not _mic.start():
				_last_win_reason = "start_fail"
				_cold_streak += 1
				_tel("voice cold streak=%d reason=start_fail" % _cold_streak)
				_set_listen_badge(false)
				await _wait(gen, 1.0)
				continue
			_tel("voice mic hot")
		await _wait(gen, LISTEN_SECS)
		if gen != _gen or not _listening:
			_mic.cancel()
			return
		if Narrator.is_playing():
			_last_win_reason = "vo"
			_mic.cancel()
			_cmd_cd = VO_HANGOVER_S
			continue
		var clip: Variant = _mic.call("take_pcm_window", LISTEN_MIN_PEAK)
		await get_tree().process_frame
		if gen != _gen or not _listening:
			return
		if typeof(clip) != TYPE_DICTIONARY:
			_last_win_reason = "bad_clip"
			_cold_streak += 1
			await _wait(gen, LISTEN_GAP_S)
			continue
		_last_win_peak = int(clip.get("peak", 0))
		_last_win_reason = str(clip.get("reason", "?"))
		if not bool(clip.get("ok", false)):
			_cold_streak += 1
			_tel("voice cold streak=%d reason=%s peak=%d player=%d" % [
				_cold_streak, _last_win_reason, _last_win_peak,
				1 if clip.get("player", false) else 0])
			# Dead player / empty stream → remount; brief silence is normal.
			if _last_win_reason in ["player_dead", "empty", "not_recording"] \
					or _cold_streak >= 3:
				_mic.cancel()
				_cold_streak = 0
			await _wait(gen, LISTEN_GAP_S)
			continue
		_cold_streak = 0
		var peak: int = _last_win_peak
		var data: PackedByteArray = clip.get("data", PackedByteArray())
		var fp := _pcm_fingerprint(data)
		# Stuck Android buffer: same content (or same peak right after a hit)
		# must never rematch as a different / delayed command.
		if _fp_seen_recently(fp) or _ghost_peak(peak):
			_last_win_reason = "echo"
			_tel("voice echo peak=%d n=%d fp=%d — drop" % [peak, data.size(), fp])
			_mic.cancel()
			_last_peak = -1
			_last_bytes = -1
			await _wait(gen, 0.25)
			continue
		if peak == _last_peak and data.size() == _last_bytes:
			_last_win_reason = "stale"
			_fp_mark(fp)
			_tel("voice stale peak=%d n=%d — remount mic" % [peak, data.size()])
			_mic.cancel()
			_last_peak = -1
			_last_bytes = -1
			await _wait(gen, 0.2)
			continue
		_last_peak = peak
		_last_bytes = data.size()
		_fp_mark(fp)
		var scored := _match_pcm_scored(data, bool(clip.get("stereo", false)))
		var hit: String = str(scored.get("hit", ""))
		if hit.is_empty():
			_tel("voice miss peak=%d best=%s s=%.2f second=%.2f" % [
				peak, str(scored.get("best", "")),
				float(scored.get("best_s", 0.0)),
				float(scored.get("second", 0.0))])
		else:
			_tel("voice hit=%s peak=%d s=%.2f second=%.2f" % [
				hit, peak, float(scored.get("best_s", 0.0)),
				float(scored.get("second", 0.0))])
			_last_hit_peak = peak
			_last_hit_ms = Time.get_ticks_msec()
			command.emit(hit)
			_cmd_cd = CMD_COOLDOWN_S + VO_HANGOVER_S
			# Drop the winning buffer so it cannot re-fire mid-cooldown.
			_mic.cancel()
			_last_peak = -1
			_last_bytes = -1
		await _wait(gen, LISTEN_GAP_S)

func _pcm_fingerprint(data: PackedByteArray) -> int:
	if data.is_empty():
		return 0
	var h: int = data.size()
	var step: int = maxi(2, int(data.size() / 48))
	var i := 0
	while i + 1 < data.size():
		var s: int = int(data[i]) | (int(data[i + 1]) << 8)
		h = ((h << 5) - h) ^ s
		i += step
	return h

func _fp_mark(fp: int) -> void:
	var now := Time.get_ticks_msec()
	_seen_fp[fp] = now
	# Prune old entries so the dict stays small.
	var drop: Array = []
	for k in _seen_fp:
		if now - int(_seen_fp[k]) > FP_TTL_MS:
			drop.append(k)
	for k in drop:
		_seen_fp.erase(k)

func _fp_seen_recently(fp: int) -> bool:
	if not _seen_fp.has(fp):
		return false
	return Time.get_ticks_msec() - int(_seen_fp[fp]) < FP_TTL_MS

func _ghost_peak(peak: int) -> bool:
	## Same peak as a recent hit → almost always the stuck Android buffer
	## coming back with a slightly different byte count.
	if _last_hit_peak < 0 or peak != _last_hit_peak:
		return false
	return Time.get_ticks_msec() - _last_hit_ms < FP_TTL_MS

func match_pcm(data: PackedByteArray, stereo: bool) -> String:
	return str(_match_pcm_scored(data, stereo).get("hit", ""))

func _match_pcm_scored(data: PackedByteArray, stereo: bool) -> Dictionary:
	var live := envelope_from_pcm16(data, stereo, ENERGY_MIN)
	var out := {"hit": "", "best": "", "best_s": 0.0, "second": 0.0}
	if live.is_empty():
		out["best"] = "empty_env"
		return out
	var best := ""
	var best_s := 0.0
	var second := 0.0
	for w in _templates:
		var s := envelope_score(live, _templates[w])
		if s > best_s:
			second = best_s
			best_s = s
			best = w
		elif s > second:
			second = s
	out["best"] = best
	out["best_s"] = best_s
	out["second"] = second
	if best_s < MATCH_MIN:
		return out
	if best_s - second < AMBIG_MARGIN and second >= MATCH_MIN * 0.9:
		_tel("voice ambig best=%s s=%.2f second=%.2f" % [best, best_s, second])
		return out
	out["hit"] = best
	return out

func match_clip(path: String) -> String:
	var live := envelope_from_wav(path, ENERGY_MIN)
	if live.is_empty():
		return ""
	var best := ""
	var best_s := MATCH_MIN
	var second := 0.0
	for w in _templates:
		var s := envelope_score(live, _templates[w])
		if s > best_s:
			second = best_s
			best_s = s
			best = w
		elif s > second:
			second = s
	if not best.is_empty() and best_s - second < AMBIG_MARGIN and second >= MATCH_MIN * 0.9:
		return ""
	return best

static func envelope_from_pcm16(data: PackedByteArray, stereo: bool,
		energy_min: float = ENERGY_MIN) -> PackedFloat32Array:
	if data.is_empty():
		return PackedFloat32Array()
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.stereo = stereo
	stream.data = data
	var samples := _samples_from_stream(stream)
	return _envelope_from_samples(samples, energy_min)

static func envelope_from_wav(path: String, energy_min: float = ENERGY_MIN) -> PackedFloat32Array:
	return _envelope_from_samples(_pcm_mono_f32(path), energy_min)

static func _envelope_from_samples(samples: PackedFloat32Array,
		energy_min: float) -> PackedFloat32Array:
	if samples.is_empty():
		return PackedFloat32Array()
	var n: int = samples.size()
	var peak := 0.0
	var sum_sq := 0.0
	for i in n:
		var a: float = absf(samples[i])
		peak = maxf(peak, a)
		sum_sq += samples[i] * samples[i]
	var rms: float = sqrt(sum_sq / float(maxi(n, 1)))
	if peak < energy_min and rms < energy_min * 0.45:
		return PackedFloat32Array()
	var out := PackedFloat32Array()
	out.resize(ENVELOPE_BINS)
	var bin_n: int = maxi(1, int(ceil(float(n) / float(ENVELOPE_BINS))))
	var max_e := 0.0
	for b in ENVELOPE_BINS:
		var sum := 0.0
		var c := 0
		var start: int = b * bin_n
		var stop: int = mini(n, start + bin_n)
		for i in range(start, stop):
			var v: float = samples[i]
			sum += v * v
			c += 1
		var e: float = sqrt(sum / float(maxi(c, 1)))
		out[b] = e
		max_e = maxf(max_e, e)
	if max_e < energy_min * 0.5:
		return PackedFloat32Array()
	for b in ENVELOPE_BINS:
		out[b] = out[b] / max_e
	return out

static func envelope_score(a: PackedFloat32Array, b: PackedFloat32Array) -> float:
	if a.size() != b.size() or a.is_empty():
		return 0.0
	var dot := 0.0
	var na := 0.0
	var nb := 0.0
	for i in a.size():
		dot += a[i] * b[i]
		na += a[i] * a[i]
		nb += b[i] * b[i]
	if na < 1.0e-8 or nb < 1.0e-8:
		return 0.0
	return clampf(dot / sqrt(na * nb), 0.0, 1.0)

static func _pcm_mono_f32(path: String) -> PackedFloat32Array:
	var abs_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(abs_path):
		return _decode_wav_file(abs_path)
	if FileAccess.file_exists(path):
		return _decode_wav_file(ProjectSettings.globalize_path(path))
	return PackedFloat32Array()

static func _samples_from_stream(stream: AudioStreamWAV) -> PackedFloat32Array:
	var data: PackedByteArray = stream.data
	if data.is_empty():
		return PackedFloat32Array()
	var out := PackedFloat32Array()
	match stream.format:
		AudioStreamWAV.FORMAT_8_BITS:
			out.resize(data.size())
			for i in data.size():
				out[i] = (float(data[i]) - 128.0) / 128.0
		AudioStreamWAV.FORMAT_16_BITS:
			var n: int = data.size() / 2
			out.resize(n)
			for i in n:
				var lo: int = data[i * 2]
				var hi: int = data[i * 2 + 1]
				var s: int = lo | (hi << 8)
				if s >= 32768:
					s -= 65536
				out[i] = float(s) / 32768.0
		_:
			return PackedFloat32Array()
	if stream.stereo and out.size() >= 2:
		var mono := PackedFloat32Array()
		mono.resize(out.size() / 2)
		for i in mono.size():
			mono[i] = 0.5 * (out[i * 2] + out[i * 2 + 1])
		return mono
	return out

static func _decode_wav_file(abs_path: String) -> PackedFloat32Array:
	var f := FileAccess.open(abs_path, FileAccess.READ)
	if f == null:
		return PackedFloat32Array()
	var bytes: PackedByteArray = f.get_buffer(f.get_length())
	if bytes.size() < 44:
		return PackedFloat32Array()
	var i := 12
	var data_off := -1
	var data_size := 0
	var bits := 16
	var chans := 1
	while i + 8 <= bytes.size():
		var tag := String.chr(bytes[i]) + String.chr(bytes[i + 1]) \
			+ String.chr(bytes[i + 2]) + String.chr(bytes[i + 3])
		var sz: int = bytes[i + 4] | (bytes[i + 5] << 8) \
			| (bytes[i + 6] << 16) | (bytes[i + 7] << 24)
		if tag == "fmt " and i + 24 <= bytes.size():
			chans = bytes[i + 10] | (bytes[i + 11] << 8)
			bits = bytes[i + 22] | (bytes[i + 23] << 8)
		elif tag == "data":
			data_off = i + 8
			data_size = sz
			break
		i += 8 + sz + (sz & 1)
	if data_off < 0 or data_off + data_size > bytes.size():
		return PackedFloat32Array()
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS if bits == 8 \
		else AudioStreamWAV.FORMAT_16_BITS
	stream.stereo = chans > 1
	stream.data = bytes.slice(data_off, data_off + data_size)
	return _samples_from_stream(stream)

func _build_ui() -> void:
	_word_lbl = Label.new()
	_word_lbl.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_word_lbl.offset_top = 70
	_word_lbl.offset_bottom = 120
	_word_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_word_lbl.add_theme_font_size_override("font_size", 36)
	_word_lbl.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
	_word_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_word_lbl)

	var wrap := Control.new()
	wrap.position = Vector2(530, 180)
	wrap.size = Vector2(220, 220)
	add_child(wrap)

	_mic_btn = Button.new()
	_mic_btn.custom_minimum_size = Vector2(220, 220)
	_mic_btn.size = Vector2(220, 220)
	_mic_btn.focus_mode = Control.FOCUS_NONE
	_mic_btn.text = "MIC"
	_mic_btn.add_theme_font_size_override("font_size", 48)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.18, 0.32, 0.48, 0.96)
	sb.set_corner_radius_all(110)
	sb.set_border_width_all(3)
	sb.border_color = Color(1, 1, 1, 0.55)
	_mic_btn.add_theme_stylebox_override("normal", sb)
	var hover := sb.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.24, 0.40, 0.58, 0.98)
	_mic_btn.add_theme_stylebox_override("hover", hover)
	_mic_btn.pressed.connect(_on_mic_pressed)
	wrap.add_child(_mic_btn)

	var rsb := StyleBoxFlat.new()
	rsb.bg_color = Color(0.92, 0.18, 0.18, 0.95)
	rsb.set_corner_radius_all(28)
	_red_dot = Panel.new()
	_red_dot.size = Vector2(56, 56)
	_red_dot.position = Vector2(82, 82)
	_red_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_red_dot.visible = false
	(_red_dot as Panel).add_theme_stylebox_override("panel", rsb)
	wrap.add_child(_red_dot)

	_skip_btn = Button.new()
	_skip_btn.text = "Skip for now"
	_skip_btn.position = Vector2(490, 430)
	_skip_btn.size = Vector2(300, 56)
	_skip_btn.focus_mode = Control.FOCUS_NONE
	_skip_btn.add_theme_font_size_override("font_size", 22)
	var ksb := StyleBoxFlat.new()
	ksb.bg_color = Color(0.2, 0.22, 0.28, 0.9)
	ksb.set_corner_radius_all(14)
	_skip_btn.add_theme_stylebox_override("normal", ksb)
	_skip_btn.pressed.connect(_on_skip)
	add_child(_skip_btn)

	# Always-visible flight badge — bottom-right of the 1280×600 layout.
	_listen_badge = PanelContainer.new()
	_listen_badge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_listen_badge.offset_left = -230
	_listen_badge.offset_top = -92
	_listen_badge.offset_right = -20
	_listen_badge.offset_bottom = -20
	_listen_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_listen_badge.visible = false
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color(0.08, 0.18, 0.12, 0.92)
	bsb.set_corner_radius_all(18)
	bsb.set_border_width_all(3)
	bsb.border_color = Color(0.35, 0.95, 0.55, 0.95)
	_listen_badge.add_theme_stylebox_override("panel", bsb)
	add_child(_listen_badge)

	_listen_lbl = Label.new()
	_listen_lbl.text = "MIC ON"
	_listen_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_listen_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_listen_lbl.add_theme_font_size_override("font_size", 28)
	_listen_lbl.add_theme_color_override("font_color", Color(0.55, 1.0, 0.7))
	_listen_lbl.custom_minimum_size = Vector2(200, 60)
	_listen_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_listen_badge.add_child(_listen_lbl)

func _set_recording(on: bool) -> void:
	if _red_dot != null:
		_red_dot.visible = on

func _set_listen_badge(on: bool) -> void:
	if _listen_lbl == null:
		return
	if on:
		_listen_lbl.text = "MIC ON"
		_listen_lbl.add_theme_color_override("font_color", Color(0.55, 1.0, 0.7))
	else:
		_listen_lbl.text = "MIC…"
		_listen_lbl.add_theme_color_override("font_color", Color(0.75, 0.8, 0.55))

func _tel(msg: String) -> void:
	print("PGTEL EV ", msg)

func _wait(gen: int, secs: float) -> bool:
	var t := 0.0
	while t < secs:
		await get_tree().process_frame
		if gen != _gen:
			return false
		t += get_process_delta_time()
	return gen == _gen

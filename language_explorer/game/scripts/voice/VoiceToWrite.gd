class_name VoiceToWrite
extends Control
const ChromeIcons := preload("res://scripts/ChromeIcons.gd")
const HubClientS := preload("res://scripts/voice/HubClient.gd")
## Narrated Voice flow: one mic tile + red recording circle.
## Uses MicOwner (process-wide hold). Clips toggle record only — mic stays ours.

signal finished()

enum Phase {
	OFFLINE,
	INTRO,
	WAIT_NEXT,
	REC_NEXT,
	WAIT_BACK,
	REC_BACK,
	WAIT_PHRASE,
	REC_PHRASE,
	PROCESSING,
	PRACTICE,
}

const MIC_SIZE := Vector2(160, 160)
const RED_SIZE := 48.0
const DESK_SIZE := Vector2(760, 400)
const DESK_PATH := "res://images/ui/voice_desk.png"
const ENROLL_SECS := 2.2
const PHRASE_SECS := 10.0
const PHRASE_MIN_SECS := 1.4
const MIC_SETTLE_SECS := 0.2
## After stopping VO, wait so speaker "Tap…" echo decays before capture.
const ECHO_SETTLE_SECS := 0.65

var _built := false
var _phase: int = Phase.OFFLINE
var _gen: int = 0
var _busy: bool = false
var _lang: String = "en"
var _online: bool = false
var _phrase_started_ms: int = 0

var _mic: Node
var _sentence: String = ""
var _letters: Array = []  # letter chars
var _words: Array = []  # {text, first, last, from, to}
var _index: int = 0
var _hl_mode: String = "letter"  # letter | word
var _listen_looping: bool = false
var _desk_pulse_on: bool = false

var _sentence_rtl: RichTextLabel
var _big_letter: Label
var _mic_btn: Button
var _red_dot: Control
var _mic_wrap: Control
var _desk_wrap: Control
var _desk_frame: Panel
var _desk_sb: StyleBoxFlat

func start() -> void:
	_build()
	_lang = Save.get_lang()
	_gen += 1
	var gen := _gen
	_listen_looping = false
	_busy = false
	_sentence = ""
	_letters.clear()
	_words.clear()
	_index = 0
	_hl_mode = "letter"
	_show_practice_text(false)
	_set_recording(false)
	_show_desk(true, false)
	_mic_btn.visible = false
	_center_mic()
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP

	_online = await HubClientS.online_probe(get_tree())
	if gen != _gen:
		return
	if not _online:
		_phase = Phase.OFFLINE
		Narrator.speak(LangVo.line("voice_needs_wifi", _lang))
		return

	if _mic != null:
		_mic.hold()
	await _wait(gen, 0.35)
	if gen != _gen:
		return

	_phase = Phase.INTRO
	var intro_key := "voice_intro"
	if not Save.was_seen("tut_voice_v2"):
		intro_key = "voice_intro_first"
		Save.mark_seen("tut_voice_v2")
		Save.mark_seen("tut_voice")
	var d := Narrator.speak(LangVo.line(intro_key, _lang))
	if not await _wait(gen, maxf(2.5, d)):
		return
	_begin_wait_next()

func stop() -> void:
	_gen += 1
	_busy = false
	_listen_looping = false
	_desk_pulse_on = false
	Narrator.stop()
	if _mic != null:
		_mic.cancel()
		_mic.clear_session_files()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _build() -> void:
	if _built:
		return
	_built = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_mic = MicOwner.capture()
	if _mic == null:
		push_error("VoiceToWrite: MicOwner has no capture")

	_desk_wrap = Control.new()
	_desk_wrap.size = DESK_SIZE
	_desk_wrap.position = Vector2(
		(1280.0 - DESK_SIZE.x) * 0.5,
		(600.0 - DESK_SIZE.y) * 0.5
	)
	_desk_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_desk_wrap.visible = false
	add_child(_desk_wrap)

	_desk_sb = StyleBoxFlat.new()
	_desk_sb.bg_color = Color(0.08, 0.09, 0.14, 1)
	_desk_sb.set_corner_radius_all(28)
	_desk_sb.set_border_width_all(6)
	_desk_sb.border_color = LangTheme.GOLD
	_desk_sb.shadow_color = Color(LangTheme.GOLD, 0.35)
	_desk_sb.shadow_size = 10
	_desk_frame = Panel.new()
	_desk_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_desk_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_desk_frame.add_theme_stylebox_override("panel", _desk_sb)
	_desk_wrap.add_child(_desk_frame)

	var desk_tex := TextureRect.new()
	desk_tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	desk_tex.offset_left = 14
	desk_tex.offset_top = 14
	desk_tex.offset_right = -14
	desk_tex.offset_bottom = -14
	desk_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	desk_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	desk_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(DESK_PATH):
		desk_tex.texture = load(DESK_PATH)
	_desk_wrap.add_child(desk_tex)

	_sentence_rtl = RichTextLabel.new()
	_sentence_rtl.bbcode_enabled = true
	_sentence_rtl.fit_content = true
	_sentence_rtl.scroll_active = false
	_sentence_rtl.position = Vector2(80, 55)
	_sentence_rtl.size = Vector2(1120, 70)
	_sentence_rtl.add_theme_font_size_override("normal_font_size", 32)
	_sentence_rtl.add_theme_font_size_override("bold_font_size", 36)
	_sentence_rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sentence_rtl.visible = false
	add_child(_sentence_rtl)

	_big_letter = Label.new()
	_big_letter.add_theme_font_size_override("font_size", 180)
	_big_letter.add_theme_color_override("font_color", LangTheme.GOLD)
	_big_letter.position = Vector2(440, 130)
	_big_letter.size = Vector2(400, 220)
	_big_letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_big_letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_big_letter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_big_letter.visible = false
	add_child(_big_letter)

	_mic_wrap = Control.new()
	_mic_wrap.size = MIC_SIZE
	_mic_wrap.position = Vector2(
		(1280.0 - MIC_SIZE.x) * 0.5,
		(600.0 - MIC_SIZE.y) * 0.5
	)
	add_child(_mic_wrap)

	_mic_btn = Button.new()
	_mic_btn.custom_minimum_size = MIC_SIZE
	_mic_btn.size = MIC_SIZE
	_mic_btn.position = Vector2.ZERO
	_mic_btn.focus_mode = Control.FOCUS_NONE
	LangTheme.style_mode_tile(_mic_btn, LangTheme.MODES["voice"]["color"], false)
	ChromeIcons.apply_button(_mic_btn, "home_voice", 90)
	_mic_btn.pressed.connect(_on_mic_pressed)
	_mic_wrap.add_child(_mic_btn)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.92, 0.18, 0.18, 0.95)
	sb.set_corner_radius_all(int(RED_SIZE))
	_red_dot = Panel.new()
	_red_dot.size = Vector2(RED_SIZE, RED_SIZE)
	_red_dot.position = (MIC_SIZE - Vector2(RED_SIZE, RED_SIZE)) * 0.5
	_red_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_red_dot.visible = false
	(_red_dot as Panel).add_theme_stylebox_override("panel", sb)
	_mic_wrap.add_child(_red_dot)

func _process(_delta: float) -> void:
	if not _desk_pulse_on or _desk_sb == null:
		return
	var t := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 380.0)
	var width := int(round(4.0 + 10.0 * t))  # 4 → 14
	_desk_sb.set_border_width_all(width)
	_desk_sb.shadow_size = int(round(6.0 + 10.0 * t))
	_desk_sb.shadow_color = Color(LangTheme.GOLD, 0.25 + 0.35 * t)
	if _desk_frame != null:
		_desk_frame.add_theme_stylebox_override("panel", _desk_sb)

func _center_mic() -> void:
	if _mic_wrap == null:
		return
	_mic_wrap.position = Vector2(
		(1280.0 - MIC_SIZE.x) * 0.5,
		(600.0 - MIC_SIZE.y) * 0.5
	)

func _set_recording(on: bool) -> void:
	if _red_dot != null:
		_red_dot.visible = on

## Desk tile: intro (static) or processing (gold thickness pulse). Hidden while mic is up.
func _show_desk(on: bool, pulse: bool = false) -> void:
	_desk_pulse_on = on and pulse
	if _desk_wrap != null:
		_desk_wrap.visible = on
		if on:
			_desk_wrap.position = Vector2(
				(1280.0 - DESK_SIZE.x) * 0.5,
				(600.0 - DESK_SIZE.y) * 0.5
			)
	if _desk_sb != null:
		_desk_sb.set_border_width_all(6)
		_desk_sb.border_color = LangTheme.GOLD
		_desk_sb.shadow_size = 10 if pulse else 6
		_desk_sb.shadow_color = Color(LangTheme.GOLD, 0.35 if pulse else 0.2)
		if _desk_frame != null:
			_desk_frame.add_theme_stylebox_override("panel", _desk_sb)

func _show_practice_text(on: bool) -> void:
	_sentence_rtl.visible = on
	_big_letter.visible = on
	if on:
		_show_desk(false, false)
		if _mic_btn != null:
			_mic_btn.visible = false

func _arm_mic_tap() -> void:
	Narrator.stop()

func _prep_capture(gen: int) -> bool:
	## Stop VO, mute path via MicCapture.start, wait out speaker echo.
	_arm_mic_tap()
	return await _wait(gen, ECHO_SETTLE_SECS)

func _begin_wait_next() -> void:
	_phase = Phase.WAIT_NEXT
	_show_desk(false, false)
	_center_mic()
	_mic_btn.visible = true
	_set_recording(false)
	_sentence_rtl.visible = false
	_big_letter.visible = false
	Narrator.speak(LangVo.line("voice_tap_say_next", _lang))

func _begin_wait_back() -> void:
	_phase = Phase.WAIT_BACK
	_show_desk(false, false)
	_center_mic()
	_mic_btn.visible = true
	_set_recording(false)
	Narrator.speak(LangVo.line("voice_tap_say_back", _lang))

func _begin_wait_phrase() -> void:
	_phase = Phase.WAIT_PHRASE
	_show_desk(false, false)
	_center_mic()
	_mic_btn.visible = true
	_set_recording(false)
	_sentence_rtl.visible = false
	_big_letter.visible = false
	Narrator.speak(LangVo.line("voice_tap_say_idea", _lang))

func _on_mic_pressed() -> void:
	if _phase == Phase.REC_PHRASE:
		var elapsed := (Time.get_ticks_msec() - _phrase_started_ms) / 1000.0
		if elapsed < PHRASE_MIN_SECS:
			return
		_record_phrase_stop()
		return
	if _busy:
		return
	match _phase:
		Phase.WAIT_NEXT:
			_record_enroll("next")
		Phase.WAIT_BACK:
			_record_enroll("back")
		Phase.WAIT_PHRASE:
			_record_phrase_start()
		_:
			pass

func _record_enroll(which: String) -> void:
	_gen += 1
	var gen := _gen
	_busy = true
	_phase = Phase.REC_NEXT if which == "next" else Phase.REC_BACK
	# Red circle after echo settle so she speaks into a quiet room.
	_set_recording(false)
	if not await _prep_capture(gen):
		return
	_set_recording(true)
	if not _mic.start():
		push_warning("VoiceToWrite: mic start failed for enroll %s" % which)
		_busy = false
		_set_recording(false)
		_phase = Phase.WAIT_NEXT if which == "next" else Phase.WAIT_BACK
		Narrator.speak(LangVo.line("voice_try_again", _lang))
		return
	await _wait(gen, MIC_SETTLE_SECS + ENROLL_SECS)
	if gen != _gen:
		return
	var path: String = _mic.stop_to_file("%s.wav" % which)
	_set_recording(false)
	if path.is_empty():
		push_warning("VoiceToWrite: empty/silent enroll wav for %s" % which)
		_busy = false
		Narrator.speak(LangVo.line("voice_mic_busy", _lang))
		await _wait(gen, 2.2)
		if gen != _gen:
			return
		if which == "next":
			_begin_wait_next()
		else:
			_begin_wait_back()
		return
	var resp: Dictionary = await HubClientS.command(get_tree(), path)
	if gen != _gen:
		return
	var cmd := str(resp.get("command", "none"))
	print("VoiceToWrite enroll %s → %s text=%s" % [which, cmd, str(resp.get("text", ""))])
	if cmd != which:
		push_warning("VoiceToWrite: enroll expected %s got %s (%s)" % [which, cmd, str(resp.get("text", ""))])
		_busy = false
		if which == "next":
			_begin_wait_next()
		else:
			_begin_wait_back()
		return
	var d := Narrator.speak(LangVo.line("voice_got_it", _lang))
	await _wait(gen, maxf(0.7, d))
	_busy = false
	if which == "next":
		_begin_wait_back()
	else:
		_begin_wait_phrase()

func _record_phrase_start() -> void:
	_gen += 1
	var gen := _gen
	_busy = true
	_phase = Phase.REC_PHRASE
	_set_recording(false)
	if not await _prep_capture(gen):
		return
	_set_recording(true)
	_phrase_started_ms = Time.get_ticks_msec()
	if not _mic.start():
		push_warning("VoiceToWrite: mic start failed for phrase")
		_busy = false
		_set_recording(false)
		_phase = Phase.WAIT_PHRASE
		Narrator.speak(LangVo.line("voice_try_again", _lang))
		return
	await _wait(gen, MIC_SETTLE_SECS)
	if gen != _gen:
		return
	_phrase_started_ms = Time.get_ticks_msec()
	await _wait(gen, PHRASE_SECS)
	if gen != _gen:
		return
	if _phase == Phase.REC_PHRASE:
		await _finish_phrase(gen)

func _record_phrase_stop() -> void:
	if _phase != Phase.REC_PHRASE:
		return
	_gen += 1
	var gen := _gen
	await _finish_phrase(gen)

func _finish_phrase(gen: int) -> void:
	_phase = Phase.PROCESSING
	_mic_btn.visible = false
	_set_recording(false)
	_show_desk(true, true)
	var path: String = _mic.stop_to_file("phrase.wav")
	if path.is_empty():
		push_warning("VoiceToWrite: empty phrase wav")
		_busy = false
		_begin_wait_phrase()
		Narrator.speak(LangVo.line("voice_try_again", _lang))
		return
	Narrator.speak(LangVo.line("voice_thinking", _lang))
	# Desk tile + pulsing gold outline while ASR + llama run.
	var resp: Dictionary = await HubClientS.voice_write(get_tree(), path, _lang)
	if gen != _gen:
		return
	print(
		"VoiceToWrite phrase ok=%s raw=%s text=%s letters=%d err=%s"
		% [
			str(resp.get("ok", false)),
			str(resp.get("raw", "")),
			str(resp.get("text", "")),
			(resp.get("letters", []) as Array).size(),
			str(resp.get("error", "")),
		]
	)
	if not bool(resp.get("ok", false)) or str(resp.get("text", "")).strip_edges().is_empty():
		_busy = false
		_begin_wait_phrase()
		Narrator.speak(LangVo.line("voice_try_again", _lang))
		return
	_sentence = str(resp.get("text", "")).strip_edges()
	_parse_sentence_words()
	if _letters.is_empty():
		_busy = false
		_begin_wait_phrase()
		Narrator.speak(LangVo.line("voice_try_again", _lang))
		return
	_index = 0
	_hl_mode = "letter"
	_phase = Phase.PRACTICE
	_busy = false
	_show_desk(false, false)
	_show_practice_text(true)
	_refresh_letter_view()
	Save.record_activity_started("voice_write")
	await _begin_current_word(gen)
	_start_listen_loop()

func _parse_sentence_words() -> void:
	_letters.clear()
	_words.clear()
	var i := 0
	var s := _sentence
	while i < s.length():
		var ch := s.substr(i, 1)
		if not _is_alpha(ch):
			i += 1
			continue
		var from := i
		var first := _letters.size()
		var word := ""
		while i < s.length():
			ch = s.substr(i, 1)
			if not _is_alpha(ch):
				break
			word += ch
			_letters.append(ch)
			i += 1
		_words.append({
			"text": word,
			"first": first,
			"last": _letters.size() - 1,
			"from": from,
			"to": i,
		})

func _is_alpha(ch: String) -> bool:
	return LangLetters.is_letter(ch)

func _word_at(letter_i: int) -> Dictionary:
	for w in _words:
		if letter_i >= int(w["first"]) and letter_i <= int(w["last"]):
			return w
	return {}

func _start_listen_loop() -> void:
	if _listen_looping:
		return
	_listen_looping = true
	_listen_loop()

func _listen_loop() -> void:
	var gen := _gen
	while _listen_looping and gen == _gen and _phase == Phase.PRACTICE and visible:
		if Narrator.blocks_input() or _busy:
			await get_tree().create_timer(0.25).timeout
			continue
		if not _mic.start():
			await get_tree().create_timer(0.8).timeout
			continue
		await get_tree().create_timer(1.35).timeout
		if gen != _gen or not _listen_looping:
			_mic.cancel()
			break
		var path: String = _mic.stop_to_file("listen_%d.wav" % Time.get_ticks_msec())
		if path.is_empty():
			continue
		var resp: Dictionary = await HubClientS.command(get_tree(), path)
		if gen != _gen or not _listen_looping:
			break
		var cmd := str(resp.get("command", "none"))
		if cmd != "none":
			print("VoiceToWrite listen → %s (%s)" % [cmd, str(resp.get("text", ""))])
		if cmd == "next":
			await _go_next()
		elif cmd == "back":
			await _go_back()
		await get_tree().create_timer(0.35).timeout

func _go_next() -> void:
	if _phase != Phase.PRACTICE or _letters.is_empty() or _busy:
		return
	_busy = true
	Narrator.stop()
	var gen := _gen
	var w := _word_at(_index)
	if w.is_empty():
		_busy = false
		return
	# Completing the last letter of a word → celebrate the whole word first.
	if _index >= int(w["last"]):
		await _celebrate_word(gen, w)
		if gen != _gen:
			return
		if _index >= _letters.size() - 1:
			var d := Narrator.speak(LangVo.line("you_got_it", _lang))
			await _wait(gen, maxf(0.9, d))
			_busy = false
			Save.record_activity_finished("voice_write")
			_listen_looping = false
			_show_practice_text(false)
			_begin_wait_phrase()
			return
		_index = int(w["last"]) + 1
		await _begin_current_word(gen)
		_busy = false
		return
	_index += 1
	_hl_mode = "letter"
	_refresh_letter_view()
	await _speak_current_letter(gen)
	_busy = false

func _go_back() -> void:
	if _phase != Phase.PRACTICE or _letters.is_empty() or _busy:
		return
	_busy = true
	Narrator.stop()
	var gen := _gen
	_index = maxi(0, _index - 1)
	var w := _word_at(_index)
	# Landing on the first letter of a word → re-intro that word.
	if not w.is_empty() and _index == int(w["first"]):
		await _begin_current_word(gen)
	else:
		_hl_mode = "letter"
		_refresh_letter_view()
		await _speak_current_letter(gen)
	_busy = false

func _begin_current_word(gen: int) -> void:
	var w := _word_at(_index)
	if w.is_empty():
		return
	_index = int(w["first"])
	_hl_mode = "word"
	_refresh_letter_view()
	var d0 := Narrator.speak(str(w["text"]))
	await _wait(gen, maxf(0.7, d0))
	if gen != _gen:
		return
	var d1 := Narrator.speak(LangVo.line("voice_first_letter", _lang))
	await _wait(gen, maxf(0.55, d1))
	if gen != _gen:
		return
	_hl_mode = "letter"
	_refresh_letter_view()
	await _speak_current_letter(gen)

func _celebrate_word(gen: int, w: Dictionary) -> void:
	_hl_mode = "word"
	_refresh_letter_view()
	var d := Narrator.speak(str(w["text"]))
	await _wait(gen, maxf(0.7, d))

func _speak_current_letter(gen: int) -> void:
	if _index < 0 or _index >= _letters.size():
		return
	_hl_mode = "letter"
	_refresh_letter_view()
	var ch := str(_letters[_index])
	var name := LangLetters.letter_name(ch, _lang)
	if LangLetters.is_letter(ch):
		if ch == ch.to_upper() and ch.to_lower() != ch:
			name = LangVo.line("voice_upper_letter", _lang).replace("{letter}", name)
		elif ch == ch.to_lower() and ch.to_upper() != ch:
			name = LangVo.line("voice_lower_letter", _lang).replace("{letter}", LangLetters.letter_name(ch.to_upper(), _lang))
	var d := Narrator.speak(name)
	await _wait(gen, maxf(0.55, d))

func _refresh_letter_view() -> void:
	_refresh_sentence_hl()
	if _letters.is_empty():
		_big_letter.text = ""
		return
	_index = clampi(_index, 0, _letters.size() - 1)
	if _hl_mode == "word":
		var w := _word_at(_index)
		_big_letter.text = str(w.get("text", _letters[_index]))
		_big_letter.add_theme_font_size_override("font_size", 96 if str(w.get("text", "")).length() > 1 else 180)
	else:
		_big_letter.text = str(_letters[_index])
		_big_letter.add_theme_font_size_override("font_size", 180)

func _refresh_sentence_hl() -> void:
	if _sentence_rtl == null:
		return
	var gold := _color_hex(LangTheme.GOLD)
	var dim := _color_hex(LangTheme.TEXT_DIM)
	var text := _sentence
	var from := 0
	var to := 0
	if _hl_mode == "word":
		var w := _word_at(_index)
		if not w.is_empty():
			from = int(w["from"])
			to = int(w["to"])
	else:
		from = _letter_sentence_index(_index)
		to = from + 1 if from >= 0 else 0
		if from < 0:
			from = 0
			to = 0
	from = clampi(from, 0, text.length())
	to = clampi(to, from, text.length())
	var left := _bb_escape(text.substr(0, from))
	var mid := _bb_escape(text.substr(from, to - from))
	var right := _bb_escape(text.substr(to))
	_sentence_rtl.text = "[center][color=%s]%s[/color][b][color=%s]%s[/color][/b][color=%s]%s[/color][/center]" % [
		dim, left, gold, mid, dim, right
	]

func _letter_sentence_index(letter_i: int) -> int:
	if letter_i < 0 or letter_i >= _letters.size():
		return -1
	var count := 0
	for i in _sentence.length():
		var ch := _sentence.substr(i, 1)
		if not _is_alpha(ch):
			continue
		if count == letter_i:
			return i
		count += 1
	return -1

func _bb_escape(s: String) -> String:
	return s.replace("[", "[lb]").replace("]", "[rb]")

func _color_hex(c: Color) -> String:
	return "#%02x%02x%02x" % [int(round(c.r * 255.0)), int(round(c.g * 255.0)), int(round(c.b * 255.0))]

func _wait(gen: int, secs: float) -> bool:
	await get_tree().create_timer(secs).timeout
	return gen == _gen and is_inside_tree() and visible

static func vo_lines() -> Array:
	var keys := [
		"voice_needs_wifi", "voice_intro", "voice_intro_first", "voice_tap_say_next", "voice_tap_say_back",
		"voice_tap_say_idea", "voice_thinking", "voice_try_again", "voice_mic_busy", "voice_got_it",
		"voice_say_next_back", "voice_first_letter",
	]
	var out: Array = []
	for k in keys:
		out.append(LangVo.line(k, "en"))
		out.append(LangVo.line(k, "es"))
	out.append(LangVo.line("voice_upper_letter", "en").replace("{letter}", "A"))
	out.append(LangVo.line("voice_lower_letter", "en").replace("{letter}", "T"))
	out.append(LangVo.line("voice_upper_letter", "es").replace("{letter}", "A"))
	out.append(LangVo.line("voice_lower_letter", "es").replace("{letter}", "T"))
	return out

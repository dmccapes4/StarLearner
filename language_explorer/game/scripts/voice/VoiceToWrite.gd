class_name VoiceToWrite
extends Control
const ChromeIcons := preload("res://scripts/ChromeIcons.gd")
const HubClientS := preload("res://scripts/voice/HubClient.gd")
const LetterWheelS := preload("res://scripts/voice/LetterWheel.gd")
const LangFontsS := preload("res://scripts/LangFonts.gd")
const VoiceArrowButtonS := preload("res://scripts/voice/VoiceArrowButton.gd")
const VoiceNextStoreS := preload("res://scripts/voice/VoiceNextStore.gd")
const VoiceTelemetryS := preload("res://scripts/voice/VoiceTelemetry.gd")
## Narrated Voice flow: one mic tile + red recording circle.
## Uses MicOwner (process-wide hold). Clips toggle record only — mic stays ours.

signal finished()

enum Phase {
	OFFLINE,
	INTRO,
	WAIT_NEXT,
	REC_NEXT,
	WAIT_PHRASE,
	REC_PHRASE,
	PROCESSING,
	PRACTICE,
}

const VIEW_W := 1280.0
const VIEW_H := 600.0
const SENTENCE_NORMAL := 44
const SENTENCE_BOLD := 52
const ARROW_SIZE := Vector2(64, 168)
const ARROW_GAP := 28.0

const MIC_SIZE := Vector2(160, 160)
const RERECORD_SIZE := Vector2(100, 100)
const TILE_GAP := 20.0
const RED_SIZE := 48.0
const DESK_SIZE := Vector2(760, 400)
const DESK_PATH := "res://images/ui/voice_desk.png"
const ENROLL_SECS := 2.2
const PHRASE_SECS := 10.0
const PHRASE_MIN_SECS := 1.4
const MIC_SETTLE_SECS := 0.2
## After stopping VO, wait so speaker "Tap…" echo decays before capture.
const ECHO_SETTLE_SECS := 0.65
## Kid writes the letter on paper after hearing it — mic stays off.
const WRITE_PAUSE_SECS := 2.0
const MIC_WARMUP_SECS := 0.35
const LISTEN_SECS := 1.5
const LISTEN_MIN_PEAK := 280

var _intro_skip_pressed: bool = false

var _built := false
var _phase: int = Phase.OFFLINE
var _gen: int = 0
var _busy: bool = false
var _narrating: bool = false
var _nav_in_progress: bool = false
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
var _listen_epoch: int = 0
var _write_pause_pending: bool = false
var _mic_weak_streak: int = 0
var _desk_pulse_on: bool = false
var _listen_dot: Panel

var _sentence_rtl: RichTextLabel
var _wheel: Control
var _prev_btn: Button
var _next_btn: Button
var _mic_btn: Button
var _rerecord_btn: Button
var _mic_wrap: Control
var _rerecord_wrap: Control
var _red_dot: Control
var _rerecord_red_dot: Control
var _enroll_from_rerecord: bool = false
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
	_narrating = false
	_nav_in_progress = false
	_intro_skip_pressed = false
	_sentence = ""
	_letters.clear()
	_words.clear()
	_index = 0
	_hl_mode = "letter"
	_show_practice_text(false)
	_set_recording(false, "")
	_show_desk(true, false)
	_show_mic_tiles(false)
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
	if not await _wait_intro_or_skip(gen, maxf(1.0, d)):
		return
	if not Save.was_seen("tut_voice_listen_dot"):
		_set_listen_indicator(true)
		if not await _speak_line(LangVo.line("voice_listen_dot", _lang), gen):
			return
		_set_listen_indicator(false)
		Save.mark_seen("tut_voice_listen_dot")
	if VoiceNextStoreS.has_saved():
		_begin_wait_phrase(true)
	else:
		_begin_wait_next()

func stop() -> void:
	_gen += 1
	_busy = false
	_narrating = false
	_nav_in_progress = false
	_listen_looping = false
	_listen_epoch += 1
	_write_pause_pending = false
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
	_sentence_rtl.position = Vector2(40, 36)
	_sentence_rtl.size = Vector2(VIEW_W - 80.0, 104)
	LangFontsS.apply_richtext(_sentence_rtl, SENTENCE_NORMAL, SENTENCE_BOLD)
	_sentence_rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sentence_rtl.visible = false
	add_child(_sentence_rtl)

	_wheel = LetterWheelS.new()
	_wheel.visible = false
	add_child(_wheel)

	_prev_btn = VoiceArrowButtonS.new()
	_prev_btn.direction = VoiceArrowButtonS.Dir.LEFT
	_prev_btn.custom_minimum_size = ARROW_SIZE
	_prev_btn.size = ARROW_SIZE
	_prev_btn.focus_mode = Control.FOCUS_NONE
	_prev_btn.visible = false
	_prev_btn.pressed.connect(_on_prev_pressed)
	add_child(_prev_btn)

	_next_btn = VoiceArrowButtonS.new()
	_next_btn.direction = VoiceArrowButtonS.Dir.RIGHT
	_next_btn.custom_minimum_size = ARROW_SIZE
	_next_btn.size = ARROW_SIZE
	_next_btn.focus_mode = Control.FOCUS_NONE
	_next_btn.visible = false
	_next_btn.pressed.connect(_on_next_pressed)
	add_child(_next_btn)
	_layout_practice_ui()

	_mic_wrap = Control.new()
	_mic_wrap.size = MIC_SIZE
	add_child(_mic_wrap)

	_rerecord_wrap = Control.new()
	_rerecord_wrap.size = RERECORD_SIZE
	_rerecord_wrap.visible = false
	add_child(_rerecord_wrap)

	_rerecord_btn = Button.new()
	_rerecord_btn.custom_minimum_size = RERECORD_SIZE
	_rerecord_btn.size = RERECORD_SIZE
	_rerecord_btn.focus_mode = Control.FOCUS_NONE
	LangTheme.style_mode_tile(_rerecord_btn, LangTheme.PANEL, false, false)
	ChromeIcons.apply_button(_rerecord_btn, "rerecord_next", 72)
	_rerecord_btn.pressed.connect(_on_rerecord_pressed)
	_rerecord_wrap.add_child(_rerecord_btn)

	var r_sb := StyleBoxFlat.new()
	r_sb.bg_color = Color(0.92, 0.18, 0.18, 0.95)
	r_sb.set_corner_radius_all(int(RED_SIZE * 0.85))
	_rerecord_red_dot = Panel.new()
	_rerecord_red_dot.size = Vector2(RED_SIZE * 0.85, RED_SIZE * 0.85)
	_rerecord_red_dot.position = (RERECORD_SIZE - _rerecord_red_dot.size) * 0.5
	_rerecord_red_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rerecord_red_dot.visible = false
	(_rerecord_red_dot as Panel).add_theme_stylebox_override("panel", r_sb)
	_rerecord_wrap.add_child(_rerecord_red_dot)

	_mic_btn = Button.new()
	_mic_btn.custom_minimum_size = MIC_SIZE
	_mic_btn.size = MIC_SIZE
	_mic_btn.position = Vector2.ZERO
	_mic_btn.focus_mode = Control.FOCUS_NONE
	LangTheme.style_mode_tile(_mic_btn, LangTheme.MODES["voice"]["color"], false, false)
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

	var listen_sb := StyleBoxFlat.new()
	listen_sb.bg_color = Color(0.92, 0.18, 0.18, 0.95)
	listen_sb.set_corner_radius_all(int(RED_SIZE))
	listen_sb.set_border_width_all(3)
	listen_sb.border_color = Color(1.0, 0.85, 0.85, 0.9)
	_listen_dot = Panel.new()
	_listen_dot.size = Vector2(RED_SIZE, RED_SIZE)
	_listen_dot.position = Vector2(VIEW_W - RED_SIZE - 24.0, 20.0)
	_listen_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_listen_dot.visible = false
	_listen_dot.add_theme_stylebox_override("panel", listen_sb)
	add_child(_listen_dot)
	_layout_mic_tiles(false)

func _gui_input(event: InputEvent) -> void:
	if _phase != Phase.INTRO:
		return
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		_intro_skip_pressed = true
		accept_event()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_intro_skip_pressed = true
			accept_event()

func _wait_intro_or_skip(gen: int, _min_secs: float) -> bool:
	while gen == _gen and is_inside_tree() and visible:
		if _intro_skip_pressed:
			_intro_skip_pressed = false
			Narrator.stop()
			return true
		if not Narrator.is_playing() and not Narrator.blocks_input():
			return true
		await get_tree().create_timer(0.05).timeout
	return false

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

func _layout_mic_tiles(show_rerecord: bool) -> void:
	var y := (VIEW_H - MIC_SIZE.y) * 0.5
	if show_rerecord:
		var row_w := RERECORD_SIZE.x + TILE_GAP + MIC_SIZE.x
		var x := (VIEW_W - row_w) * 0.5
		_rerecord_wrap.position = Vector2(x, y + (MIC_SIZE.y - RERECORD_SIZE.y) * 0.5)
		_mic_wrap.position = Vector2(x + RERECORD_SIZE.x + TILE_GAP, y)
	else:
		_mic_wrap.position = Vector2((VIEW_W - MIC_SIZE.x) * 0.5, y)

func _set_tile_gold(on: bool) -> void:
	LangTheme.style_mode_tile(_mic_btn, LangTheme.MODES["voice"]["color"], false, on)
	LangTheme.style_mode_tile(_rerecord_btn, LangTheme.PANEL, false, on)

func _show_mic_tiles(on: bool, show_rerecord: bool = false, gold: bool = false) -> void:
	if _mic_wrap != null:
		_mic_wrap.visible = on
	if _rerecord_wrap != null:
		_rerecord_wrap.visible = on and show_rerecord
	if on:
		_layout_mic_tiles(show_rerecord)
		_set_tile_gold(gold)
	else:
		_set_recording(false, "")

func _center_mic() -> void:
	_layout_mic_tiles(_rerecord_wrap != null and _rerecord_wrap.visible)

func _set_recording(on: bool, source: String = "mic") -> void:
	if _red_dot != null:
		_red_dot.visible = on and source == "mic"
	if _rerecord_red_dot != null:
		_rerecord_red_dot.visible = on and source == "rerecord"

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

func _layout_practice_ui() -> void:
	if _wheel == null or _prev_btn == null or _next_btn == null:
		return
	var wheel_w := LetterWheelS.SLOT_WIDTH * 5.0
	var row_w := ARROW_SIZE.x + ARROW_GAP + wheel_w + ARROW_GAP + ARROW_SIZE.x
	var row_x := (VIEW_W - row_w) * 0.5
	var row_y := (VIEW_H - ARROW_SIZE.y) * 0.5 + 24.0
	var wheel_y := row_y + (ARROW_SIZE.y - LetterWheelS.SLOT_HEIGHT) * 0.5
	_prev_btn.position = Vector2(row_x, row_y)
	_wheel.position = Vector2(row_x + ARROW_SIZE.x + ARROW_GAP, wheel_y)
	_next_btn.position = Vector2(row_x + ARROW_SIZE.x + ARROW_GAP + wheel_w + ARROW_GAP, row_y)

func _show_practice_text(on: bool) -> void:
	_sentence_rtl.visible = on
	if _wheel != null:
		_wheel.visible = on
	if _prev_btn != null:
		_prev_btn.visible = on
	if _next_btn != null:
		_next_btn.visible = on
	if on:
		_layout_practice_ui()
		_show_desk(false, false)
		if _mic_btn != null:
			_mic_wrap.visible = false
		if _rerecord_wrap != null:
			_rerecord_wrap.visible = false
		_update_arrow_state()

func _arm_mic_tap() -> void:
	Narrator.stop()

func _prep_capture(gen: int) -> bool:
	## Stop VO, mute path via MicCapture.start, wait out speaker echo.
	_arm_mic_tap()
	return await _wait(gen, ECHO_SETTLE_SECS)

func _begin_wait_next() -> void:
	_phase = Phase.WAIT_NEXT
	_busy = false
	_listen_looping = false
	_listen_epoch += 1
	if _mic != null:
		_mic.cancel()
	_set_listen_indicator(false)
	_show_desk(false, false)
	_show_mic_tiles(true, false, false)
	_sentence_rtl.visible = false
	if _wheel != null:
		_wheel.visible = false
	Narrator.speak(LangVo.line("voice_tap_say_next", _lang))

func _begin_wait_phrase(first_entry: bool = false) -> void:
	_phase = Phase.WAIT_PHRASE
	_busy = false
	_nav_in_progress = false
	_listen_looping = false
	_listen_epoch += 1
	if _mic != null:
		_mic.cancel()
	_set_listen_indicator(false)
	_show_desk(false, false)
	var show_rerecord := first_entry and VoiceNextStoreS.has_saved()
	_show_mic_tiles(true, show_rerecord, show_rerecord)
	_sentence_rtl.visible = false
	if _wheel != null:
		_wheel.visible = false
	var line_key := "voice_rerecord_or_phrase" if show_rerecord else "voice_tap_say_idea"
	Narrator.speak(LangVo.line(line_key, _lang))

func _on_rerecord_pressed() -> void:
	if _busy or not _rerecord_wrap.visible:
		return
	_enroll_from_rerecord = true
	_record_enroll()

func _set_listen_indicator(on: bool) -> void:
	if _listen_dot != null:
		_listen_dot.visible = on and _phase == Phase.PRACTICE

func _schedule_write_pause() -> void:
	_write_pause_pending = true
	_set_listen_indicator(false)

func _cancel_listen_capture() -> void:
	_listen_epoch += 1
	if _mic != null and _mic.is_recording():
		VoiceTelemetryS.log("listen_cancel", {"reason": "arrow_or_nav", "epoch": _listen_epoch})
		_mic.cancel()
	_set_listen_indicator(false)

func _on_prev_pressed() -> void:
	if _phase != Phase.PRACTICE or _nav_in_progress:
		return
	_cancel_listen_capture()
	if _narrating:
		_gen += 1
		_narrating = false
	Narrator.stop()
	await Narrator.await_playback(get_tree())
	await _go_back()
	if _phase == Phase.PRACTICE and not _listen_looping:
		_start_listen_loop()

func _on_next_pressed() -> void:
	if _phase != Phase.PRACTICE or _nav_in_progress:
		return
	_cancel_listen_capture()
	if _narrating:
		_gen += 1
		_narrating = false
	Narrator.stop()
	await Narrator.await_playback(get_tree())
	await _go_next()
	if _phase == Phase.PRACTICE and not _listen_looping:
		_start_listen_loop()

func _update_arrow_state() -> void:
	if _prev_btn != null:
		_prev_btn.disabled = _index <= 0 or _nav_in_progress
		_prev_btn.queue_redraw()
	if _next_btn != null:
		_next_btn.disabled = _nav_in_progress
		_next_btn.queue_redraw()

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
			_record_enroll()
		Phase.WAIT_PHRASE:
			_record_phrase_start()
		_:
			pass

func _record_enroll() -> void:
	_gen += 1
	var gen := _gen
	_busy = true
	_phase = Phase.REC_NEXT
	var rec_source := "rerecord" if _enroll_from_rerecord else "mic"
	_set_recording(false, "")
	if not await _prep_capture(gen):
		return
	_set_recording(true, rec_source)
	VoiceTelemetryS.log("enroll_start", {"source": rec_source, "secs": ENROLL_SECS})
	if not _mic.start():
		push_warning("VoiceToWrite: mic start failed for enroll next")
		_busy = false
		var retry_rerecord := _enroll_from_rerecord
		_enroll_from_rerecord = false
		_set_recording(false, "")
		if retry_rerecord:
			_begin_wait_phrase(true)
		else:
			_phase = Phase.WAIT_NEXT
			_begin_wait_next()
		Narrator.speak(LangVo.line("voice_try_again", _lang))
		return
	await _wait(gen, MIC_SETTLE_SECS + ENROLL_SECS)
	if gen != _gen:
		return
	var path: String = _mic.stop_to_file("next.wav")
	_set_recording(false, "")
	if path.is_empty():
		VoiceTelemetryS.log("enroll_fail", {
			"reason": _mic.last_stop_reason(),
			"peak": _mic.last_peak(),
			"min_peak": MicCapture.SILENCE_PEAK,
		})
		push_warning("VoiceToWrite: empty/silent enroll wav for next")
		_busy = false
		var retry_rerecord := _enroll_from_rerecord
		_enroll_from_rerecord = false
		Narrator.speak(LangVo.line("voice_mic_busy", _lang))
		await _wait(gen, 2.2)
		if gen != _gen:
			return
		if retry_rerecord:
			_begin_wait_phrase(true)
		else:
			_begin_wait_next()
		return
	var t0 := Time.get_ticks_msec()
	var resp: Dictionary = await HubClientS.command(get_tree(), path)
	var asr_ms := Time.get_ticks_msec() - t0
	if gen != _gen:
		return
	var cmd := str(resp.get("command", "none"))
	VoiceTelemetryS.log("enroll_asr", {
		"cmd": cmd,
		"text": str(resp.get("text", "")),
		"peak": _mic.last_peak(),
		"asr_ms": asr_ms,
		"err": str(resp.get("error", "")),
	})
	if cmd != "next":
		push_warning("VoiceToWrite: enroll expected next got %s (%s)" % [cmd, str(resp.get("text", ""))])
		_busy = false
		var retry_rerecord := _enroll_from_rerecord
		_enroll_from_rerecord = false
		if retry_rerecord:
			_begin_wait_phrase(true)
		else:
			_begin_wait_next()
		return
	VoiceNextStoreS.save_from(path)
	var from_rerecord := _enroll_from_rerecord
	_enroll_from_rerecord = false
	var d := Narrator.speak(LangVo.line("voice_got_it", _lang))
	await _wait(gen, maxf(0.7, d))
	_busy = false
	if from_rerecord:
		_begin_wait_phrase(true)
	else:
		_begin_wait_phrase(false)

func _record_phrase_start() -> void:
	_gen += 1
	var gen := _gen
	_busy = true
	_phase = Phase.REC_PHRASE
	_set_recording(false, "")
	if not await _prep_capture(gen):
		return
	_set_recording(true, "mic")
	_phrase_started_ms = Time.get_ticks_msec()
	if not _mic.start():
		push_warning("VoiceToWrite: mic start failed for phrase")
		_busy = false
		_set_recording(false, "")
		_phase = Phase.WAIT_PHRASE
		_begin_wait_phrase(false)
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
	_show_mic_tiles(false)
	_set_recording(false, "")
	_show_desk(true, true)
	var path: String = _mic.stop_to_file("phrase.wav")
	if path.is_empty():
		push_warning("VoiceToWrite: empty phrase wav")
		_busy = false
		_begin_wait_phrase(false)
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
		_begin_wait_phrase(false)
		Narrator.speak(LangVo.line("voice_try_again", _lang))
		return
	_sentence = str(resp.get("text", "")).strip_edges()
	_parse_sentence_words()
	if _letters.is_empty():
		_busy = false
		_begin_wait_phrase(false)
		Narrator.speak(LangVo.line("voice_try_again", _lang))
		return
	_index = 0
	_hl_mode = "letter"
	_phase = Phase.PRACTICE
	_busy = false
	_narrating = true
	_show_desk(false, false)
	_show_practice_text(true)
	Save.record_activity_started("voice_write")
	await _begin_current_word(gen)
	_narrating = false
	if gen != _gen:
		return
	_update_arrow_state()
	await _speak_line(LangVo.line("voice_say_next", _lang), gen)
	_schedule_write_pause()
	_start_listen_loop()

func _speak_line(text: String, gen: int) -> bool:
	if gen != _gen or text.strip_edges().is_empty():
		return false
	Narrator.speak(text)
	await Narrator.await_playback(get_tree())
	return gen == _gen and is_inside_tree() and visible

func _speak_letter_at(letter_i: int, gen: int, animate_wheel: bool = false, wheel_dir: int = 0) -> bool:
	if gen != _gen or letter_i < 0 or letter_i >= _letters.size():
		return false
	_index = letter_i
	_hl_mode = "letter"
	await _refresh_letter_view(animate_wheel, wheel_dir)
	if gen != _gen:
		return false
	var ch := str(_letters[letter_i])
	var name := LangLetters.letter_name(ch, _lang)
	Narrator.speak(name)
	await Narrator.await_playback(get_tree())
	return gen == _gen and is_inside_tree() and visible

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
	_mic_weak_streak = 0
	VoiceTelemetryS.log("listen_loop_start", {
		"window_secs": LISTEN_SECS,
		"min_peak": LISTEN_MIN_PEAK,
		"letter_i": _index,
		"word": str(_word_at(_index).get("text", "")),
	})
	_listen_loop()

func _listen_loop() -> void:
	var gen := _gen
	while _listen_looping and gen == _gen and _phase == Phase.PRACTICE and visible:
		if Narrator.blocks_input() or Narrator.is_playing() or _nav_in_progress or _narrating:
			_set_listen_indicator(false)
			await get_tree().create_timer(0.2).timeout
			continue
		if _write_pause_pending:
			_set_listen_indicator(false)
			VoiceTelemetryS.log("write_pause", {"secs": WRITE_PAUSE_SECS, "letter_i": _index})
			if not await _wait(gen, WRITE_PAUSE_SECS):
				break
			_write_pause_pending = false
		var epoch := _listen_epoch
		if not await _wait(gen, ECHO_SETTLE_SECS):
			break
		if epoch != _listen_epoch:
			continue
		_set_listen_indicator(true)
		if not _mic.start():
			VoiceTelemetryS.log("mic_start_fail", {"held": _mic.is_held()})
			_set_listen_indicator(false)
			if await _maybe_recover_mic(gen):
				continue
			await get_tree().create_timer(0.8).timeout
			continue
		if not await _wait(gen, MIC_WARMUP_SECS):
			_mic.cancel()
			break
		if epoch != _listen_epoch or gen != _gen or not _listen_looping:
			_mic.cancel()
			continue
		if not await _wait(gen, LISTEN_SECS):
			_mic.cancel()
			break
		if epoch != _listen_epoch or gen != _gen or not _listen_looping:
			_mic.cancel()
			continue
		_set_listen_indicator(false)
		var path: String = _mic.stop_to_file("listen_%d.wav" % Time.get_ticks_msec(), LISTEN_MIN_PEAK)
		if path.is_empty():
			VoiceTelemetryS.log("listen_skip", {
				"reason": _mic.last_stop_reason(),
				"peak": _mic.last_peak(),
				"min_peak": LISTEN_MIN_PEAK,
				"letter_i": _index,
				"epoch": epoch,
			})
			if await _note_weak_mic(gen, _mic.last_peak(), LISTEN_MIN_PEAK):
				continue
			continue
		var t0 := Time.get_ticks_msec()
		var resp: Dictionary = await HubClientS.command(get_tree(), path)
		if epoch != _listen_epoch or gen != _gen or not _listen_looping:
			break
		var asr_ms := Time.get_ticks_msec() - t0
		var cmd := str(resp.get("command", "none"))
		VoiceTelemetryS.log("listen_asr", {
			"cmd": cmd,
			"text": str(resp.get("text", "")),
			"peak": _mic.last_peak(),
			"min_peak": LISTEN_MIN_PEAK,
			"asr_ms": asr_ms,
			"err": str(resp.get("error", "")),
			"letter_i": _index,
		})
		if cmd == "next":
			_mic_weak_streak = 0
			_listen_epoch += 1
			await _go_next()
			continue
		if await _note_weak_mic(gen, _mic.last_peak(), 500):
			continue

func _note_weak_mic(gen: int, peak: int, threshold: int) -> bool:
	if peak >= threshold:
		_mic_weak_streak = 0
		return false
	_mic_weak_streak += 1
	if _mic_weak_streak < 2:
		return false
	VoiceTelemetryS.log("mic_weak_streak", {"streak": _mic_weak_streak, "peak": peak})
	_mic_weak_streak = 0
	return await _maybe_recover_mic(gen)

func _maybe_recover_mic(gen: int) -> bool:
	if gen != _gen or _mic == null:
		return false
	var ok: bool = await _mic.recover_hold()
	return ok and gen == _gen

func _go_next() -> void:
	if _phase != Phase.PRACTICE or _letters.is_empty() or _nav_in_progress:
		return
	_nav_in_progress = true
	_update_arrow_state()
	Narrator.stop()
	await Narrator.await_playback(get_tree())
	var gen := _gen
	var w := _word_at(_index)
	if w.is_empty():
		_nav_in_progress = false
		_update_arrow_state()
		return
	# Completing the last letter of a word → celebrate the whole word first.
	if _index >= int(w["last"]):
		await _celebrate_word(gen, w)
		if gen != _gen:
			_nav_in_progress = false
			return
		if _index >= _letters.size() - 1:
			if not await _speak_line(_sentence, gen):
				_nav_in_progress = false
				return
			if not await _speak_line(LangVo.line("you_got_it", _lang), gen):
				_nav_in_progress = false
				return
			_nav_in_progress = false
			_busy = false
			_update_arrow_state()
			Save.record_activity_finished("voice_write")
			_listen_looping = false
			_show_practice_text(false)
			_begin_wait_phrase(false)
			return
		if not await _begin_current_word(gen, int(w["last"]) + 1):
			_nav_in_progress = false
			return
		_schedule_write_pause()
		_nav_in_progress = false
		_update_arrow_state()
		return
	var next_i := _index + 1
	if not await _speak_letter_at(next_i, gen, true, 1):
		_nav_in_progress = false
		_update_arrow_state()
		return
	_schedule_write_pause()
	_nav_in_progress = false
	_update_arrow_state()

func _go_back() -> void:
	if _phase != Phase.PRACTICE or _letters.is_empty() or _nav_in_progress:
		return
	if _index <= 0:
		return
	_nav_in_progress = true
	_update_arrow_state()
	Narrator.stop()
	await Narrator.await_playback(get_tree())
	var gen := _gen
	var prev_i := _index - 1
	var w := _word_at(prev_i)
	# Landing on the first letter of a word → re-intro that word.
	if not w.is_empty() and prev_i == int(w["first"]):
		if not await _begin_current_word(gen, prev_i):
			_nav_in_progress = false
			_update_arrow_state()
			return
	else:
		if not await _speak_letter_at(prev_i, gen, true, -1):
			_nav_in_progress = false
			_update_arrow_state()
			return
	_schedule_write_pause()
	_nav_in_progress = false
	_update_arrow_state()

func _begin_current_word(gen: int, letter_i: int = -1) -> bool:
	if letter_i >= 0:
		_index = letter_i
	var w := _word_at(_index)
	if w.is_empty():
		return false
	_index = int(w["first"])
	_hl_mode = "word"
	await _refresh_letter_view()
	if gen != _gen:
		return false
	if not await _speak_line(str(w["text"]), gen):
		return false
	if not await _speak_line(LangVo.line("voice_first_letter", _lang), gen):
		return false
	if not await _speak_letter_at(int(w["first"]), gen):
		return false
	return gen == _gen and is_inside_tree() and visible

func _celebrate_word(gen: int, w: Dictionary) -> void:
	_index = int(w["last"])
	_hl_mode = "word"
	await _refresh_letter_view()
	if gen != _gen:
		return
	await _speak_line(str(w["text"]), gen)

func _speak_current_letter(gen: int) -> void:
	await _speak_letter_at(_index, gen)

func _refresh_letter_view(animate_wheel: bool = false, wheel_dir: int = 0) -> void:
	_refresh_sentence_hl()
	if _letters.is_empty():
		if _wheel != null:
			_wheel.set_context([], 0)
		return
	_index = clampi(_index, 0, _letters.size() - 1)
	if _wheel != null:
		await _wheel.set_context(_letters, _index, animate_wheel, wheel_dir)
	_update_arrow_state()

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
		"voice_needs_wifi", "voice_intro", "voice_intro_first", "voice_listen_dot", "voice_tap_say_next",
		"voice_tap_say_idea", "voice_rerecord_or_phrase", "voice_thinking", "voice_try_again",
		"voice_mic_busy", "voice_got_it", "voice_say_next", "voice_first_letter",
	]
	var out: Array = []
	for k in keys:
		out.append(LangVo.line(k, "en"))
		out.append(LangVo.line(k, "es"))
	return out

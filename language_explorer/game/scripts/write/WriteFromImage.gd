class_name WriteFromImage
extends Control
const ChromeIcons := preload("res://scripts/ChromeIcons.gd")
## Write → Images: pick a word image, then alphabet tiles or sketch outlines.
## Image tap = next-letter hint (reveal after 3 wrongs or 3 image taps).

signal finished()

const LetterSlotsS := preload("res://scripts/write/LetterSlots.gd")
const AlphabetBoardS := preload("res://scripts/write/AlphabetBoard.gd")
const TraceCanvasS := preload("res://scripts/write/TraceCanvas.gd")
const WriteSessionS := preload("res://scripts/write/WriteSession.gd")
const ClearButtonS := preload("res://scripts/ClearButton.gd")

enum Phase { PICK, PRACTICE }

var _built := false
var _phase: int = Phase.PICK
var _gen: int = 0
var _busy: bool = false
var _session: WriteSession
var _word: Dictionary = {}
var _lang: String = "en"

var _title: Label
var _hint: Label
var _pick_row: HBoxContainer
var _cue: TextureButton
var _slots: LetterSlots
var _board: AlphabetBoard
var _trace: TraceCanvas
var _next_btn: ClearButton
var _practice: Control

func start() -> void:
	_build()
	_lang = Save.get_lang()
	_phase = Phase.PICK
	_show_picker()
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	Narrator.speak(LangVo.line("write_images_blurb", _lang))

func stop() -> void:
	_gen += 1
	_busy = false
	Narrator.stop()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _build() -> void:
	if _built:
		return
	_built = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_title = Label.new()
	_title.text = ""
	_title.visible = false
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title)

	var header := TextureRect.new()
	header.texture = ChromeIcons.texture("images")
	header.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	header.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.position = Vector2(40, 8)
	header.size = Vector2(72, 72)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(header)

	_hint = Label.new()
	_hint.visible = false
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)

	_pick_row = HBoxContainer.new()
	_pick_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_pick_row.add_theme_constant_override("separation", 28)
	_pick_row.position = Vector2(40, 160)
	_pick_row.size = Vector2(1200, 280)
	add_child(_pick_row)

	_practice = Control.new()
	_practice.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_practice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_practice.visible = false
	add_child(_practice)

	_cue = TextureButton.new()
	_cue.ignore_texture_size = true
	_cue.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_cue.custom_minimum_size = Vector2(120, 120)
	_cue.size = Vector2(120, 120)
	_cue.position = Vector2(580, 48)
	_cue.focus_mode = Control.FOCUS_NONE
	_cue.pressed.connect(_on_image_tap)
	_practice.add_child(_cue)

	_slots = LetterSlotsS.new()
	_slots.position = Vector2(340, 175)
	_slots.size = Vector2(600, 70)
	_practice.add_child(_slots)

	_board = AlphabetBoardS.new()
	_board.position = Vector2(320, 250)
	_board.size = Vector2(640, 300)
	_board.letter_pressed.connect(_on_letter)
	_practice.add_child(_board)

	_trace = TraceCanvasS.new()
	_trace.position = Vector2(140, 250)
	_trace.size = Vector2(1000, 220)
	_trace.letter_traced.connect(_on_traced)
	_trace.ask_replay.connect(_on_image_tap)
	_practice.add_child(_trace)

	_next_btn = ClearButtonS.new()
	_next_btn.position = Vector2(580, 500)
	_next_btn.size = Vector2(120, 72)
	_next_btn.visible = false
	_next_btn.set_context(ClearButton.Context.NEXT_WORD, _lang)
	_next_btn.context_pressed.connect(func(_c: int) -> void:
		Narrator.speak(LangVo.line("next_word", _lang))
		_show_picker()
	)
	_practice.add_child(_next_btn)

func _show_picker() -> void:
	_phase = Phase.PICK
	_practice.visible = false
	_pick_row.visible = true
	_next_btn.visible = false
	for c in _pick_row.get_children():
		c.queue_free()
	_hint.text = ""
	var words: Array = LangData.words_for_lang(_lang)
	if words.is_empty():
		words = LangData.words()
	for w in words:
		_pick_row.add_child(_make_pick_tile(w))

func _make_pick_tile(w: Dictionary) -> Control:
	var wrap := VBoxContainer.new()
	wrap.custom_minimum_size = Vector2(140, 200)
	wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	var btn := TextureButton.new()
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn.custom_minimum_size = Vector2(120, 120)
	btn.size = Vector2(120, 120)
	btn.texture_normal = WordArt.texture_for(w)
	btn.focus_mode = Control.FOCUS_NONE
	var wid := str(w.get("id", ""))
	btn.pressed.connect(func() -> void: _begin_word(wid))
	wrap.add_child(btn)
	var lbl := Label.new()
	lbl.text = str(w.get("word", ""))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", LangTheme.TEXT)
	wrap.add_child(lbl)
	return wrap

func _begin_word(word_id: String) -> void:
	_word = {}
	for w in LangData.words():
		if str(w.get("id", "")) == word_id:
			_word = w
			break
	if _word.is_empty():
		return
	_phase = Phase.PRACTICE
	_pick_row.visible = false
	_practice.visible = true
	_next_btn.visible = false
	_lang = str(_word.get("lang", Save.get_lang()))
	_session = WriteSessionS.new()
	_session.start(_word)
	_session.letter_advanced.connect(_on_advanced)
	_session.word_finished.connect(_on_word_finished)
	_session.reveal_requested.connect(_on_reveal)
	_session.board_should_reset.connect(_reset_board)

	_cue.texture_normal = WordArt.texture_for(_word)
	_slots.setup(_session.letters)
	_slots.set_filled(0)

	var use_sketch := Save.get_letter_input() == "sketch"
	_board.visible = not use_sketch
	_trace.visible = use_sketch
	if use_sketch:
		_trace.setup(_session.letters)
		_hint.text = LangVo.line("trace_hint", _lang)
	else:
		_board.setup(_lang, _session.expected_is_upper(), false)
		_board.reset_attempt(_session.expected_is_upper(), true)
		_hint.text = LangVo.line("tap_image_letter", _lang)
	_intro()

func _intro() -> void:
	_gen += 1
	var gen := _gen
	_busy = true
	var spoken := str(_word.get("narration_word", _word.get("word", "")))
	var d := Narrator.speak(spoken)
	if not await _wait(gen, maxf(1.0, d)):
		return
	var tip := LangVo.line("tap_image_letter", _lang)
	d = Narrator.speak(tip)
	await _wait(gen, maxf(1.2, d))
	_busy = false

func _on_image_tap() -> void:
	if _phase != Phase.PRACTICE or _busy or _session == null or _session.done:
		return
	_gen += 1
	var gen := _gen
	_busy = true
	var ch := _session.register_hint()
	var name := LangLetters.letter_name(ch, _lang)
	var d := Narrator.speak(name)
	await _wait(gen, maxf(0.7, d))
	_busy = false

func _on_letter(glyph: String) -> void:
	if _phase != Phase.PRACTICE or _busy or _session == null or _session.done:
		return
	var result := _session.try_letter(glyph)
	match result:
		WriteSession.Result.CORRECT:
			if not _session.done:
				_on_correct_feedback()
		WriteSession.Result.WRONG:
			_on_wrong_feedback(glyph)

func _on_traced(_idx: int, letter: String) -> void:
	if _phase != Phase.PRACTICE or _busy or _session == null or _session.done:
		return
	_gen += 1
	var gen := _gen
	_busy = true
	var name := LangLetters.letter_name(letter, _lang)
	var d := Narrator.speak(name)
	if not await _wait(gen, maxf(0.55, d)):
		return
	_session.complete_letter_from_sketch()
	_slots.set_filled(_session.filled_count())
	if not _session.done:
		_trace.set_index(_session.index)
	_busy = false

func _on_correct_feedback() -> void:
	_gen += 1
	var gen := _gen
	_busy = true
	_slots.set_filled(_session.filled_count())
	var d := Narrator.speak(LangVo.line("correct", _lang))
	await _wait(gen, maxf(0.7, d))
	_busy = false

func _on_wrong_feedback(glyph: String) -> void:
	_gen += 1
	var gen := _gen
	_busy = true
	var key := LangLetters.normalize_key(glyph)
	if key != _session.expected_key():
		_board.mark_wrong(key)
	var d := Narrator.speak(LangVo.line("almost2", _lang))
	if not await _wait(gen, maxf(1.0, d)):
		return
	var ch := _session.expected_letter()
	d = Narrator.speak(LangLetters.letter_name(ch, _lang))
	await _wait(gen, maxf(0.7, d))
	_busy = false

func _on_reveal() -> void:
	if _board.visible:
		_board.apply_reveal(_session.expected_key())

func _reset_board() -> void:
	if _board.visible:
		_board.reset_attempt(_session.expected_is_upper(), true)
	_slots.set_filled(_session.filled_count())

func _on_advanced(_i: int) -> void:
	_slots.set_filled(_session.filled_count())

func _on_word_finished() -> void:
	_slots.set_filled(_session.letters.size())
	if _trace.visible:
		_trace.mark_complete()
	Save.record_activity_finished("write_" + str(_word.get("id", "")))
	_finish_beat()

func _finish_beat() -> void:
	_gen += 1
	var gen := _gen
	_busy = true
	# Spell letter-by-letter gold feel via spoken names, then full word.
	for ch in _session.letters:
		if gen != _gen:
			return
		var d := Narrator.speak(LangLetters.letter_name(str(ch), _lang))
		if not await _wait(gen, maxf(0.5, d - 0.1)):
			return
	var spoken := str(_word.get("narration_word", _word.get("word", "")))
	var d2 := Narrator.speak(spoken)
	await _wait(gen, maxf(1.0, d2))
	_busy = false
	_next_btn.set_context(ClearButton.Context.NEXT_SENTENCE, _lang)
	_next_btn.set_context(ClearButton.Context.NEXT_WORD, _lang)
	_next_btn.visible = true
	_hint.text = ""

func _wait(gen: int, secs: float) -> bool:
	await get_tree().create_timer(secs).timeout
	return gen == _gen and is_inside_tree() and visible

static func vo_lines() -> Array:
	var out: Array = []
	out.append(LangVo.line("write_images_blurb", "en"))
	out.append(LangVo.line("write_images_blurb", "es"))
	out.append(LangVo.line("tap_image_letter", "en"))
	out.append(LangVo.line("tap_image_letter", "es"))
	out.append(LangVo.line("trace_hint", "en"))
	out.append(LangVo.line("trace_hint", "es"))
	out.append(LangVo.line("next_word", "en"))
	out.append(LangVo.line("next_word", "es"))
	out.append(LangVo.line("almost2", "en"))
	out.append(LangVo.line("almost2", "es"))
	for w in LangData.words():
		out.append(str(w.get("narration_word", w.get("word", ""))))
		out.append(str(w.get("word", "")))
		var lang := str(w.get("lang", "en"))
		for ch in WriteSession.letters_for_word(w):
			out.append(LangLetters.letter_name(str(ch), lang))
	return out

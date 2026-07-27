class_name WriteFromImage
extends Control
const ChromeIcons := preload("res://scripts/ChromeIcons.gd")
## Unified Write: picture + letter-by-letter narration + alphabet board.
## Image tap replays spell-then-word. Next-word tile always available.

signal finished()

const LetterSlotsS := preload("res://scripts/write/LetterSlots.gd")
const AlphabetBoardS := preload("res://scripts/write/AlphabetBoard.gd")
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
var _word_ids: Array = []
var _word_cursor: int = 0

var _title: Label
var _hint: Label
var _pick_scroll: ScrollContainer
var _pick_row: Control
var _cue: TextureButton
var _slots: LetterSlots
var _board: AlphabetBoard
var _next_btn: ClearButton
var _practice: Control

func start() -> void:
	_build()
	_lang = Save.get_lang()
	_phase = Phase.PICK
	_show_picker()
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	Narrator.speak(LangVo.line("write_blurb", _lang))

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
	_title.visible = false
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title)

	var header := TextureRect.new()
	header.texture = ChromeIcons.texture("write")
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

	_pick_scroll = ScrollContainer.new()
	_pick_scroll.position = Vector2(40, 100)
	_pick_scroll.size = Vector2(1200, 360)
	_pick_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_pick_scroll)

	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)
	_pick_scroll.add_child(grid)
	_pick_row = grid

	_practice = Control.new()
	_practice.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_practice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_practice.visible = false
	add_child(_practice)

	_cue = TextureButton.new()
	_cue.ignore_texture_size = true
	_cue.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_cue.custom_minimum_size = Vector2(140, 140)
	_cue.size = Vector2(140, 140)
	_cue.position = Vector2(570, 36)
	_cue.focus_mode = Control.FOCUS_NONE
	_cue.pressed.connect(_on_image_tap)
	_practice.add_child(_cue)

	_slots = LetterSlotsS.new()
	_slots.position = Vector2(340, 185)
	_slots.size = Vector2(600, 70)
	_practice.add_child(_slots)

	_board = AlphabetBoardS.new()
	_board.position = Vector2(320, 260)
	_board.size = Vector2(640, 280)
	_board.letter_pressed.connect(_on_letter)
	_practice.add_child(_board)

	_next_btn = ClearButtonS.new()
	_next_btn.position = Vector2(1080, 480)
	_next_btn.size = Vector2(120, 72)
	_next_btn.visible = false
	_next_btn.set_context(ClearButton.Context.NEXT_WORD, _lang)
	_next_btn.context_pressed.connect(func(_c: int) -> void: _goto_next_word())
	_practice.add_child(_next_btn)

func _show_picker() -> void:
	_phase = Phase.PICK
	_practice.visible = false
	_pick_scroll.visible = true
	_next_btn.visible = false
	for c in _pick_row.get_children():
		c.queue_free()
	_word_ids.clear()
	var words: Array = LangData.words_for_lang(_lang)
	if words.is_empty():
		words = LangData.words()
	for w in words:
		_word_ids.append(str(w.get("id", "")))
		_pick_row.add_child(_make_pick_tile(w))

func _make_pick_tile(w: Dictionary) -> Control:
	var wrap := VBoxContainer.new()
	wrap.custom_minimum_size = Vector2(120, 180)
	wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	var btn := TextureButton.new()
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn.custom_minimum_size = Vector2(100, 100)
	btn.size = Vector2(100, 100)
	btn.texture_normal = WordArt.texture_for(w)
	btn.focus_mode = Control.FOCUS_NONE
	var wid := str(w.get("id", ""))
	btn.pressed.connect(func() -> void: _begin_word(wid))
	wrap.add_child(btn)
	return wrap

func _begin_word(word_id: String) -> void:
	_word = {}
	for w in LangData.words():
		if str(w.get("id", "")) == word_id:
			_word = w
			break
	if _word.is_empty():
		return
	for i in _word_ids.size():
		if str(_word_ids[i]) == word_id:
			_word_cursor = i
			break
	_phase = Phase.PRACTICE
	_pick_scroll.visible = false
	_practice.visible = true
	_next_btn.set_context(ClearButton.Context.NEXT_WORD, _lang)
	_next_btn.visible = true
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
	_board.visible = true
	_board.setup(_lang, _session.expected_is_upper(), false)
	_board.reset_attempt(_session.expected_is_upper(), true)
	_intro()

func _intro() -> void:
	_gen += 1
	var gen := _gen
	_busy = true
	await _spell_then_word(gen)
	_busy = false

func _spell_then_word(gen: int) -> void:
	if _session == null:
		return
	for ch in _session.letters:
		if gen != _gen:
			return
		var d := Narrator.speak(LangLetters.letter_name(str(ch), _lang))
		if not await _wait(gen, maxf(0.5, d - 0.1)):
			return
	var spoken := str(_word.get("narration_word", _word.get("word", "")))
	var d2 := Narrator.speak(spoken)
	await _wait(gen, maxf(0.9, d2))

func _on_image_tap() -> void:
	if _phase != Phase.PRACTICE or _session == null:
		return
	# Anytime: replay letter-by-letter then word.
	_gen += 1
	var gen := _gen
	_busy = true
	Narrator.stop()
	await _spell_then_word(gen)
	if gen != _gen:
		return
	_busy = false

func _goto_next_word() -> void:
	_gen += 1
	Narrator.stop()
	_busy = false
	var d := Narrator.speak(LangVo.line("next_word", _lang))
	# Soft wait without blocking the picker forever.
	await get_tree().create_timer(maxf(0.4, d - 0.2)).timeout
	if _word_ids.is_empty():
		_show_picker()
		return
	_word_cursor = (_word_cursor + 1) % _word_ids.size()
	_begin_word(str(_word_ids[_word_cursor]))

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

func _on_correct_feedback() -> void:
	_gen += 1
	var gen := _gen
	_busy = true
	_slots.set_filled(_session.filled_count())
	var d := Narrator.speak(LangVo.line("correct", _lang))
	await _wait(gen, maxf(0.55, d))
	_busy = false

func _on_wrong_feedback(glyph: String) -> void:
	_gen += 1
	var gen := _gen
	_busy = true
	var key := LangLetters.normalize_key(glyph)
	if key != _session.expected_key():
		_board.mark_wrong(key)
	var d := Narrator.speak(LangVo.line("almost2", _lang))
	if not await _wait(gen, maxf(0.9, d)):
		return
	var ch := _session.expected_letter()
	d = Narrator.speak(LangLetters.letter_name(ch, _lang))
	await _wait(gen, maxf(0.6, d))
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
	Save.record_activity_finished("write_" + str(_word.get("id", "")))
	_finish_beat()

func _finish_beat() -> void:
	_gen += 1
	var gen := _gen
	_busy = true
	var d0 := Narrator.speak(LangVo.line("great", _lang))
	if not await _wait(gen, maxf(0.8, d0)):
		return
	# Celebration: letter-by-letter again (gold feel via spoken names + full word).
	for ch in _session.letters:
		if gen != _gen:
			return
		var d := Narrator.speak(LangLetters.letter_name(str(ch), _lang))
		if not await _wait(gen, maxf(0.45, d - 0.1)):
			return
	var spoken := str(_word.get("narration_word", _word.get("word", "")))
	var d2 := Narrator.speak(spoken)
	await _wait(gen, maxf(0.9, d2))
	_busy = false
	_next_btn.visible = true

func _wait(gen: int, secs: float) -> bool:
	await get_tree().create_timer(secs).timeout
	return gen == _gen and is_inside_tree() and visible

static func vo_lines() -> Array:
	var out: Array = []
	out.append(LangVo.line("write_blurb", "en"))
	out.append(LangVo.line("write_blurb", "es"))
	out.append(LangVo.line("next_word", "en"))
	out.append(LangVo.line("next_word", "es"))
	out.append(LangVo.line("almost2", "en"))
	out.append(LangVo.line("almost2", "es"))
	out.append(LangVo.line("great", "en"))
	out.append(LangVo.line("great", "es"))
	out.append(LangVo.line("you_got_it", "en"))
	out.append(LangVo.line("you_got_it", "es"))
	for w in LangData.words():
		out.append(str(w.get("narration_word", w.get("word", ""))))
		out.append(str(w.get("word", "")))
		var lang := str(w.get("lang", "en"))
		for ch in WriteSession.letters_for_word(w):
			out.append(LangLetters.letter_name(str(ch), lang))
	return out

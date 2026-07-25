class_name WordLabel
extends Control
## One word as a row of letter Labels with the shared literacy grammar:
##   normal | target_red (larger) | spelling_gold (bold + larger) | done_green
##
## spell(lang) narrates letter-by-letter (gold/bold), then the full word.

signal spell_finished()
signal letter_spoken(index: int, letter: String)

enum State { NORMAL, TARGET_RED, SPELLING_GOLD, DONE_GREEN }

const BASE_SIZE := 42
const TARGET_SIZE := 54
const SPELL_SIZE := 56

var word: String = ""
var state: int = State.NORMAL
var _letters: Array = []  # Label
var _gen: int = 0
var _busy: bool = false
var _built_row: HBoxContainer
var _font_size: int = BASE_SIZE

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	if _built_row == null:
		_ensure_row()

func setup(text: String, font_size: int = BASE_SIZE) -> void:
	word = text
	_font_size = font_size
	_ensure_row()
	_rebuild_letters()
	apply_state(State.NORMAL)

func get_word() -> String:
	return word

func is_busy() -> bool:
	return _busy

func apply_state(s: int) -> void:
	state = s
	for i in _letters.size():
		_style_letter(i, s)

func stop() -> void:
	_gen += 1
	_busy = false
	Narrator.stop()

## Spell letter-by-letter (gold/bold/larger while each letter is spoken), then
## speak the full word. Restores TARGET_RED or DONE_GREEN afterward if set.
func spell(lang: String = "en", finish_state: int = State.NORMAL) -> void:
	_gen += 1
	var gen := _gen
	_busy = true
	var chars := LangLetters.spell_letters(word)
	if chars.is_empty():
		_busy = false
		spell_finished.emit()
		return
	for i in chars.size():
		if gen != _gen:
			return
		_highlight_spelling(i)
		var name := LangLetters.letter_name(chars[i], lang)
		var d := Narrator.speak(name)
		letter_spoken.emit(i, chars[i])
		if not await _wait(gen, maxf(0.55, d - 0.15)):
			return
	if gen != _gen:
		return
	# Full word, slightly emphasized.
	apply_state(State.SPELLING_GOLD)
	var d2 := Narrator.speak(word)
	if not await _wait(gen, maxf(0.9, d2 - 0.1)):
		return
	apply_state(finish_state)
	_busy = false
	spell_finished.emit()

## Speak only the full word (no letter pass), with a brief gold flash.
func speak_word(lang: String = "en") -> void:
	_gen += 1
	var gen := _gen
	_busy = true
	apply_state(State.SPELLING_GOLD)
	var d := Narrator.speak(word)
	if not await _wait(gen, maxf(0.9, d - 0.1)):
		return
	if state == State.SPELLING_GOLD:
		apply_state(State.NORMAL)
	_busy = false

func _ensure_row() -> void:
	if _built_row != null:
		return
	_built_row = HBoxContainer.new()
	_built_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_built_row.add_theme_constant_override("separation", 2)
	_built_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_built_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_built_row)

func _rebuild_letters() -> void:
	for c in _built_row.get_children():
		c.queue_free()
	_letters.clear()
	# Show the raw word characters (including punctuation) but only letters
	# participate in spelling highlights by index into spell_letters().
	for i in word.length():
		var ch := word.substr(i, 1)
		var lbl := Label.new()
		lbl.text = ch
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		lbl.add_theme_constant_override("outline_size", 5)
		_built_row.add_child(lbl)
		_letters.append(lbl)
	custom_minimum_size = Vector2(maxi(80, word.length() * int(_font_size * 0.7)), _font_size + 16)

func _highlight_spelling(spell_index: int) -> void:
	var seen := 0
	for i in _letters.size():
		var ch := word.substr(i, 1)
		if LangLetters.is_letter(ch):
			if seen == spell_index:
				_style_letter_at(i, State.SPELLING_GOLD)
			else:
				_style_letter_at(i, State.NORMAL)
			seen += 1
		else:
			_style_letter_at(i, State.NORMAL)

func _style_letter(spell_index: int, s: int) -> void:
	# Apply uniform state to all letters (used by apply_state).
	for i in _letters.size():
		_style_letter_at(i, s)

func _style_letter_at(display_index: int, s: int) -> void:
	if display_index < 0 or display_index >= _letters.size():
		return
	var lbl: Label = _letters[display_index]
	var color := LangTheme.TEXT
	var size := _font_size
	var bold_extra := 0
	match s:
		State.TARGET_RED:
			color = LangTheme.RED
			size = int(float(_font_size) * 1.28)
		State.SPELLING_GOLD:
			color = LangTheme.GOLD
			size = int(float(_font_size) * 1.33)
			bold_extra = 2
		State.DONE_GREEN:
			color = LangTheme.GREEN
			size = _font_size
		_:
			color = LangTheme.TEXT
			size = _font_size
	lbl.add_theme_font_size_override("font_size", size + bold_extra)
	lbl.add_theme_color_override("font_color", color)

func _wait(gen: int, secs: float) -> bool:
	await get_tree().create_timer(secs).timeout
	return gen == _gen and is_inside_tree()

## Lines exercised by the Apple / Manzana demos (for VO bake).
static func vo_lines() -> Array:
	var out: Array = []
	for ch in LangLetters.spell_letters("Apple"):
		out.append(LangLetters.letter_name(ch, "en"))
	out.append("Apple")
	for ch in LangLetters.spell_letters("Manzana"):
		out.append(LangLetters.letter_name(ch, "es"))
	out.append("Manzana")
	return out

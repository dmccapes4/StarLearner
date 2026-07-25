class_name SpellDemo
extends Control
const ChromeIcons := preload("res://scripts/ChromeIcons.gd")
## Phase 2 acceptance demo: spell Apple (EN) and Manzana (ES) with WordLabel,
## plus a ClearButton that re-runs read-all. Chrome is icon-primary.

signal finished()

var _built := false
var _word: WordLabel
var _clear: ClearButton
var _btn_apple: Button
var _btn_manzana: Button
var _gen: int = 0

func start() -> void:
	_build()
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	Narrator.speak(LangVo.line("demo_apple", "en"))

func stop() -> void:
	_gen += 1
	if _word != null:
		_word.stop()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _build() -> void:
	if _built:
		return
	_built = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var header := TextureRect.new()
	header.texture = ChromeIcons.texture("spell_demo")
	header.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	header.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.position = Vector2(576, 40)
	header.size = Vector2(128, 88)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(header)

	_word = WordLabel.new()
	_word.position = Vector2(340, 160)
	_word.size = Vector2(600, 80)
	_word.setup("Apple", 52)
	add_child(_word)

	_btn_apple = Button.new()
	_btn_apple.custom_minimum_size = Vector2(120, 100)
	_btn_apple.size = Vector2(120, 100)
	_btn_apple.position = Vector2(440, 300)
	_btn_apple.focus_mode = Control.FOCUS_NONE
	LangTheme.style_primary(_btn_apple)
	ChromeIcons.apply_button(_btn_apple, "apple_en", 72)
	_btn_apple.pressed.connect(func() -> void: _run_spell("Apple", "en"))
	add_child(_btn_apple)

	_btn_manzana = Button.new()
	_btn_manzana.custom_minimum_size = Vector2(120, 100)
	_btn_manzana.size = Vector2(120, 100)
	_btn_manzana.position = Vector2(720, 300)
	_btn_manzana.focus_mode = Control.FOCUS_NONE
	LangTheme.style_primary(_btn_manzana)
	ChromeIcons.apply_button(_btn_manzana, "apple_es", 72)
	_btn_manzana.pressed.connect(func() -> void: _run_spell("Manzana", "es"))
	add_child(_btn_manzana)

	_clear = ClearButton.new()
	_clear.position = Vector2(580, 430)
	_clear.size = Vector2(120, 72)
	_clear.set_context(ClearButton.Context.READ_ALL, "en")
	_clear.context_pressed.connect(_on_clear)
	add_child(_clear)

func _run_spell(text: String, lang: String) -> void:
	if Narrator.blocks_input():
		return
	_gen += 1
	var gen := _gen
	_word.stop()
	_word.setup(text, 52)
	_word.apply_state(WordLabel.State.TARGET_RED)
	_clear.set_context(ClearButton.Context.READ_ALL, lang)
	var intro := LangVo.line("demo_apple", "en") if lang == "en" else LangVo.line("demo_manzana", "es")
	var d := Narrator.speak(intro)
	await get_tree().create_timer(maxf(1.2, d)).timeout
	if gen != _gen:
		return
	await _word.spell(lang, WordLabel.State.DONE_GREEN)

func _on_clear(ctx: int) -> void:
	if ctx != ClearButton.Context.READ_ALL:
		return
	if Narrator.blocks_input():
		return
	if _word.word.is_empty():
		return
	var lang := "es" if _word.word.to_lower().find("manzana") >= 0 else "en"
	_word.spell(lang, WordLabel.State.DONE_GREEN)

static func vo_lines() -> Array:
	return [
		LangVo.line("demo_apple", "en"),
		LangVo.line("demo_manzana", "es"),
	]

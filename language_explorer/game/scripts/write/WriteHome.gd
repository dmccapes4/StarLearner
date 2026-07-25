class_name WriteHome
extends Control
const ChromeIcons := preload("res://scripts/ChromeIcons.gd")
## Write mode home: Images / Narration icon tiles + letter-input icon picker.

signal finished()
signal choose_images()
signal choose_narration()

var _built := false
var _btn_images: Button
var _btn_narration: Button
var _btn_alphabet: Button
var _btn_sketch: Button

func start() -> void:
	_build()
	refresh_input_chrome()
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	Narrator.speak(LangVo.line("write_blurb", Save.get_lang()))

func stop() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _build() -> void:
	if _built:
		return
	_built = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var header := TextureRect.new()
	header.texture = ChromeIcons.texture("write")
	header.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	header.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.position = Vector2(576, 36)
	header.size = Vector2(128, 88)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(header)

	_btn_images = _make_mode_btn("images", LangTheme.BLUE, Vector2(300, 150))
	_btn_images.pressed.connect(func() -> void: choose_images.emit())
	add_child(_btn_images)

	_btn_narration = _make_mode_btn("narration", LangTheme.GOLD, Vector2(700, 150))
	_btn_narration.pressed.connect(func() -> void: choose_narration.emit())
	add_child(_btn_narration)

	_btn_alphabet = Button.new()
	_btn_alphabet.custom_minimum_size = Vector2(140, 100)
	_btn_alphabet.size = Vector2(140, 100)
	_btn_alphabet.position = Vector2(460, 420)
	_btn_alphabet.focus_mode = Control.FOCUS_NONE
	_btn_alphabet.pressed.connect(func() -> void:
		Save.set_letter_input("alphabet")
		refresh_input_chrome()
		Narrator.speak(LangVo.line("alphabet_tiles", Save.get_lang()))
	)
	add_child(_btn_alphabet)

	_btn_sketch = Button.new()
	_btn_sketch.custom_minimum_size = Vector2(140, 100)
	_btn_sketch.size = Vector2(140, 100)
	_btn_sketch.position = Vector2(680, 420)
	_btn_sketch.focus_mode = Control.FOCUS_NONE
	_btn_sketch.pressed.connect(func() -> void:
		Save.set_letter_input("sketch")
		refresh_input_chrome()
		Narrator.speak(LangVo.line("sketch_letters", Save.get_lang()))
	)
	add_child(_btn_sketch)

func refresh_input_chrome() -> void:
	var mode := Save.get_letter_input()
	if mode == "sketch":
		LangTheme.style_primary(_btn_sketch)
		LangTheme.style_secondary(_btn_alphabet)
	else:
		LangTheme.style_primary(_btn_alphabet)
		LangTheme.style_secondary(_btn_sketch)
	ChromeIcons.apply_button(_btn_alphabet, "alphabet", 72)
	ChromeIcons.apply_button(_btn_sketch, "sketch", 72)

func _make_mode_btn(icon_id: String, color: Color, pos: Vector2) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(280, 200)
	b.size = Vector2(280, 200)
	b.position = pos
	b.focus_mode = Control.FOCUS_NONE
	LangTheme.style_mode_tile(b, color, false)
	ChromeIcons.apply_button(b, icon_id, 120)
	return b

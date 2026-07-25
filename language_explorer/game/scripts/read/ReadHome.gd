class_name ReadHome
extends Control
const ChromeIcons := preload("res://scripts/ChromeIcons.gd")
## Read mode home: Sentences and Books as icon tiles (pre-reader chrome).

signal finished()
signal choose_sentences()
signal choose_books()

var _built := false
var _btn_sentences: Button
var _btn_books: Button

func start() -> void:
	_build()
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	Narrator.speak(LangVo.line("read_blurb", Save.get_lang()))

func stop() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _build() -> void:
	if _built:
		return
	_built = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var header := TextureRect.new()
	header.texture = ChromeIcons.texture("read")
	header.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	header.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.position = Vector2(576, 48)
	header.size = Vector2(128, 88)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(header)

	_btn_sentences = _make_mode_btn("sentences", LangTheme.BLUE, Vector2(300, 200))
	_btn_sentences.pressed.connect(func() -> void: choose_sentences.emit())
	add_child(_btn_sentences)

	_btn_books = _make_mode_btn("books", LangTheme.GREEN, Vector2(700, 200))
	_btn_books.pressed.connect(func() -> void: choose_books.emit())
	add_child(_btn_books)

func _make_mode_btn(icon_id: String, color: Color, pos: Vector2) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(280, 200)
	b.size = Vector2(280, 200)
	b.position = pos
	b.focus_mode = Control.FOCUS_NONE
	LangTheme.style_mode_tile(b, color, false)
	ChromeIcons.apply_button(b, icon_id, 120)
	return b

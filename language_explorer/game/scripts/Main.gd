extends Node
const ChromeIcons := preload("res://scripts/ChromeIcons.gd")
## Language Explorer — home: Read + Write + Voice.

const SpellDemoS := preload("res://scripts/SpellDemo.gd")
const BookShelfS := preload("res://scripts/read/BookShelf.gd")
const BookReaderS := preload("res://scripts/read/BookReader.gd")
const WriteFromImageS := preload("res://scripts/write/WriteFromImage.gd")
const VoiceToWriteS := preload("res://scripts/voice/VoiceToWrite.gd")
const TutorialPlayerS := preload("res://scripts/ui/TutorialPlayer.gd")
const HamburgerPanelS := preload("res://scripts/ui/HamburgerPanel.gd")

const INTRO_STEPS := [
	{"say": "Welcome to Language Explorer!", "hl": ""},
	{"say": "This tile is Read — open a book and follow along.", "hl": "read"},
	{"say": "This tile is Write — spell words from pictures.", "hl": "write"},
	{"say": "This tile is Voice — say an idea, then write it with your pencil.", "hl": "voice"},
	{"say": "And this menu has tutorials and language.", "hl": "menu"},
	{"say": "Tap a tile to begin!", "hl": ""},
]

var _ui: Control
var _header: Label
var _home: Control
var _read_tile: Button
var _write_tile: Button
var _voice_tile: Button
var _menu_btn: Button
var _menu
var _back: Button
var _gate: ColorRect
var _spell_demo: SpellDemo
var _book_shelf: BookShelf
var _book_reader: BookReader
var _write_practice: WriteFromImage
var _voice_practice
var _tutorial: TutorialPlayer

var _intro_running: bool = false
var _intro_gen: int = 0
var _depth: String = "home"  # home|demo|books|reader|write|voice

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = LangTheme.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_ui = Control.new()
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ui)

	_build_header()
	_build_home_tiles()
	_build_back_button()
	_build_menu()
	_build_input_gate()

	_spell_demo = SpellDemoS.new()
	_spell_demo.visible = false
	_spell_demo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_spell_demo)

	_book_shelf = BookShelfS.new()
	_book_shelf.visible = false
	_book_shelf.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_book_shelf)

	_book_reader = BookReaderS.new()
	_book_reader.visible = false
	_book_reader.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_book_reader)

	_write_practice = WriteFromImageS.new()
	_write_practice.visible = false
	_write_practice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_write_practice)

	_voice_practice = VoiceToWriteS.new()
	_voice_practice.visible = false
	_voice_practice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_voice_practice)

	_tutorial = TutorialPlayerS.new()
	_tutorial.visible = false
	_tutorial.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_tutorial)

	_book_shelf.open_book.connect(_enter_reader)

	_show_home_chrome()
	call_deferred("_begin_intro")

func _build_header() -> void:
	_header = Label.new()
	_header.text = ""
	_header.visible = false
	_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_header)

func _build_home_tiles() -> void:
	_home = Control.new()
	_home.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_home.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_home)

	# Three tiles across 1280 — slightly smaller than the two-tile layout.
	_read_tile = _make_home_tile("home_read", LangTheme.MODES["read"]["color"], Vector2(100, 160))
	_read_tile.pressed.connect(func() -> void: _on_home_tile("read"))
	_home.add_child(_read_tile)

	_write_tile = _make_home_tile("home_write", LangTheme.MODES["write"]["color"], Vector2(500, 160))
	_write_tile.pressed.connect(func() -> void: _on_home_tile("write"))
	_home.add_child(_write_tile)

	_voice_tile = _make_home_tile("home_voice", LangTheme.MODES["voice"]["color"], Vector2(900, 160))
	_voice_tile.pressed.connect(func() -> void: _on_home_tile("voice"))
	_home.add_child(_voice_tile)

func _make_home_tile(icon_id: String, color: Color, pos: Vector2) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(250, 240)
	b.size = Vector2(250, 240)
	b.position = pos
	b.focus_mode = Control.FOCUS_NONE
	LangTheme.style_mode_tile(b, color, false)
	ChromeIcons.apply_button(b, icon_id, 130)
	return b

func _build_back_button() -> void:
	_back = Button.new()
	_back.custom_minimum_size = Vector2(72, 64)
	_back.size = Vector2(72, 64)
	_back.position = Vector2(20, 12)
	_back.focus_mode = Control.FOCUS_NONE
	LangTheme.style_primary(_back)
	ChromeIcons.apply_button(_back, "back", 44)
	_back.visible = false
	_back.pressed.connect(_on_back)
	_ui.add_child(_back)

func _build_menu() -> void:
	_menu_btn = Button.new()
	_menu_btn.custom_minimum_size = Vector2(64, 64)
	_menu_btn.size = Vector2(64, 64)
	_menu_btn.position = Vector2(20, 12)
	_menu_btn.focus_mode = Control.FOCUS_NONE
	LangTheme.style_secondary(_menu_btn)
	ChromeIcons.apply_button(_menu_btn, "menu", 40)
	_menu_btn.pressed.connect(_open_menu)
	_ui.add_child(_menu_btn)

	_menu = HamburgerPanelS.new()
	_menu.visible = false
	_menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu.action.connect(_on_menu_item)
	_ui.add_child(_menu)

func _build_input_gate() -> void:
	_gate = ColorRect.new()
	_gate.color = Color(0.02, 0.03, 0.06, 0.10)
	_gate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_gate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gate.visible = false
	_ui.add_child(_gate)

func _process(_delta: float) -> void:
	var busy := Narrator.blocks_input()
	if _gate == null:
		return
	_gate.visible = busy
	_gate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if busy:
		_ui.move_child(_gate, -1)
		if _back != null and _back.visible:
			_ui.move_child(_back, -1)

func _open_menu() -> void:
	if _intro_running:
		return
	if Narrator.blocks_input():
		return
	_menu.open_panel()
	_ui.move_child(_menu, -1)

func _on_menu_item(id: int) -> void:
	match id:
		0:
			_enter_tutorial("tut_read")
		2:
			_enter_tutorial("tut_books")
		3:
			_enter_tutorial("tut_write")
		4:
			_enter_tutorial("tut_alphabet")
		6:
			_enter_tutorial("tut_voice")
		10:
			Save.set_lang("en")
			Narrator.speak(LangVo.line("english", "en"))
		11:
			Save.set_lang("es")
			Narrator.speak(LangVo.line("spanish", "es"))
		25:
			_enter_spell_demo()
		30:
			Narrator.speak(LangVo.line("credits", Save.get_lang()))

func _enter_tutorial(tutorial_id: String) -> void:
	_tutorial.start(tutorial_id, Save.get_lang())
	_ui.move_child(_tutorial, -1)

func _maybe_tutorial(tutorial_id: String) -> void:
	if Save.was_seen(tutorial_id):
		return
	_enter_tutorial(tutorial_id)

static func intro_lines() -> Array:
	var out: Array = []
	for step in INTRO_STEPS:
		out.append(str(step["say"]))
	return out

func _begin_intro() -> void:
	if _intro_running:
		return
	if Save.is_intro_done():
		_set_intro_highlight("")
		return
	await get_tree().process_frame
	_run_intro()

func _run_intro() -> void:
	_intro_running = true
	_intro_gen += 1
	var gen := _intro_gen
	for step in INTRO_STEPS:
		if gen != _intro_gen:
			return
		_set_intro_highlight(str(step["hl"]))
		var d := Narrator.speak(str(step["say"]))
		if not await _wait_intro(gen, maxf(2.0, d)):
			return
	_set_intro_highlight("")
	_intro_running = false
	Save.set_intro_done(true)

func _set_intro_highlight(hl: String) -> void:
	LangTheme.style_mode_tile(_read_tile, LangTheme.MODES["read"]["color"], false, hl == "read")
	LangTheme.style_mode_tile(_write_tile, LangTheme.MODES["write"]["color"], false, hl == "write")
	LangTheme.style_mode_tile(_voice_tile, LangTheme.MODES["voice"]["color"], false, hl == "voice")
	ChromeIcons.apply_button(_read_tile, "home_read", 130)
	ChromeIcons.apply_button(_write_tile, "home_write", 130)
	ChromeIcons.apply_button(_voice_tile, "home_voice", 130)
	if hl == "menu":
		var sb := StyleBoxFlat.new()
		sb.bg_color = LangTheme.PANEL
		sb.set_corner_radius_all(18)
		sb.set_border_width_all(4)
		sb.border_color = LangTheme.GOLD
		sb.shadow_color = Color(LangTheme.GOLD, 0.45)
		sb.shadow_size = 8
		for state in ["normal", "hover", "focus", "pressed"]:
			_menu_btn.add_theme_stylebox_override(state, sb)
		ChromeIcons.apply_button(_menu_btn, "menu", 40)
	else:
		LangTheme.style_secondary(_menu_btn)
		ChromeIcons.apply_button(_menu_btn, "menu", 40)

func _skip_intro() -> void:
	if not _intro_running:
		return
	_intro_gen += 1
	Narrator.stop()
	_set_intro_highlight("")
	_intro_running = false
	Save.set_intro_done(true)

func _wait_intro(gen: int, secs: float) -> bool:
	await get_tree().create_timer(secs).timeout
	return gen == _intro_gen and is_inside_tree()

func _on_home_tile(mode: String) -> void:
	if Narrator.blocks_input() and not _intro_running:
		return
	if _intro_running:
		_skip_intro()
	match mode:
		"read":
			_enter_books()
		"write":
			_enter_write()
		"voice":
			_enter_voice()

func _stop_all_modes() -> void:
	_spell_demo.stop()
	_book_shelf.stop()
	_book_reader.stop()
	_write_practice.stop()
	_voice_practice.stop()
	if _tutorial.visible:
		_tutorial.stop(true)
	else:
		_tutorial.stop()

func _enter_write() -> void:
	Save.record_activity_started("write")
	_depth = "write"
	_home.visible = false
	_header.visible = false
	_menu_btn.visible = false
	_back.visible = true
	_stop_all_modes()
	_write_practice.start()
	_ui.move_child(_write_practice, -1)
	_ui.move_child(_back, -1)
	call_deferred("_maybe_tutorial", "tut_write")
	call_deferred("_maybe_tutorial", "tut_alphabet")

func _enter_voice() -> void:
	Save.record_activity_started("voice")
	_depth = "voice"
	_home.visible = false
	_header.visible = false
	_menu_btn.visible = false
	_back.visible = true
	_stop_all_modes()
	_voice_practice.start()
	_ui.move_child(_voice_practice, -1)
	_ui.move_child(_back, -1)
	# First-run tutorial is narrated inside VoiceToWrite (zoo example), not the text overlay.

func _enter_spell_demo() -> void:
	if _intro_running:
		_skip_intro()
	Save.record_activity_started("spell_demo")
	_depth = "demo"
	_home.visible = false
	_header.visible = false
	_menu_btn.visible = false
	_back.visible = true
	_stop_all_modes()
	_spell_demo.start()
	_ui.move_child(_spell_demo, -1)
	_ui.move_child(_back, -1)

func _enter_books() -> void:
	Save.record_activity_started("books")
	_depth = "books"
	_home.visible = false
	_header.visible = false
	_menu_btn.visible = false
	_back.visible = true
	_stop_all_modes()
	_book_shelf.start()
	_ui.move_child(_book_shelf, -1)
	_ui.move_child(_back, -1)
	call_deferred("_maybe_tutorial", "tut_read")
	call_deferred("_maybe_tutorial", "tut_books")

func _enter_reader(book_id: String) -> void:
	Save.record_activity_started("reader")
	_depth = "reader"
	_home.visible = false
	_header.visible = false
	_menu_btn.visible = false
	_back.visible = true
	_stop_all_modes()
	_book_reader.start(book_id)
	_ui.move_child(_book_reader, -1)
	_ui.move_child(_back, -1)

func _on_back() -> void:
	Narrator.stop()
	match _depth:
		"reader":
			_book_reader.stop()
			_enter_books()
		"books", "write", "voice", "demo":
			_show_home()
		_:
			_show_home()

func _show_home() -> void:
	_depth = "home"
	_stop_all_modes()
	_show_home_chrome()

func _show_home_chrome() -> void:
	_back.visible = false
	_header.visible = true
	_menu_btn.visible = true
	_home.visible = true
	_ui.move_child(_home, -1)
	_ui.move_child(_menu_btn, -1)
	_ui.move_child(_header, -1)
	_set_intro_highlight("")

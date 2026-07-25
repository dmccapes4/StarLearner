extends Node
const ChromeIcons := preload("res://scripts/ChromeIcons.gd")
## Language Explorer — flow controller (Phase 1 shell).
##
##   Home: two large tiles (Read / Write) + ☰ tutorials / language / letter input
##   Nested screens always get ◀ Back (top-left).
##   First launch plays a short narrated tour once (Save.intro_done).

const ReadHomeS := preload("res://scripts/read/ReadHome.gd")
const WriteHomeS := preload("res://scripts/write/WriteHome.gd")
const SpellDemoS := preload("res://scripts/SpellDemo.gd")
const SentenceMatchS := preload("res://scripts/read/SentenceMatch.gd")
const BookShelfS := preload("res://scripts/read/BookShelf.gd")
const BookReaderS := preload("res://scripts/read/BookReader.gd")
const WriteFromImageS := preload("res://scripts/write/WriteFromImage.gd")
const WriteFromNarrationS := preload("res://scripts/write/WriteFromNarration.gd")
const TutorialPlayerS := preload("res://scripts/ui/TutorialPlayer.gd")
const HamburgerPanelS := preload("res://scripts/ui/HamburgerPanel.gd")

const INTRO_STEPS := [
	{"say": "Welcome to Language Explorer!", "hl": ""},
	{"say": "This tile is Read — sentences and books.", "hl": "read"},
	{"say": "This tile is Write — practice letters and words.", "hl": "write"},
	{"say": "And this menu has tutorials and language.", "hl": "menu"},
	{"say": "Tap a tile to begin!", "hl": ""},
]

var _ui: Control
var _header: Label
var _home: Control
var _read_tile: Button
var _write_tile: Button
var _menu_btn: Button
var _menu
var _back: Button
var _gate: ColorRect
var _read_home: ReadHome
var _write_home: WriteHome
var _spell_demo: SpellDemo
var _sentence_match: SentenceMatch
var _book_shelf: BookShelf
var _book_reader: BookReader
var _write_images: WriteFromImage
var _write_narration: WriteFromNarration
var _tutorial: TutorialPlayer

var _intro_running: bool = false
var _intro_gen: int = 0
var _depth: String = "home"  # home|read|write|demo|sentences|books|reader|write_images|write_narration

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

	_read_home = ReadHomeS.new()
	_read_home.visible = false
	_read_home.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_read_home)

	_write_home = WriteHomeS.new()
	_write_home.visible = false
	_write_home.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_write_home)

	_spell_demo = SpellDemoS.new()
	_spell_demo.visible = false
	_spell_demo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_spell_demo)

	_sentence_match = SentenceMatchS.new()
	_sentence_match.visible = false
	_sentence_match.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_sentence_match)

	_book_shelf = BookShelfS.new()
	_book_shelf.visible = false
	_book_shelf.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_book_shelf)

	_book_reader = BookReaderS.new()
	_book_reader.visible = false
	_book_reader.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_book_reader)

	_write_images = WriteFromImageS.new()
	_write_images.visible = false
	_write_images.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_write_images)

	_write_narration = WriteFromNarrationS.new()
	_write_narration.visible = false
	_write_narration.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_write_narration)

	_tutorial = TutorialPlayerS.new()
	_tutorial.visible = false
	_tutorial.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_tutorial)

	_read_home.choose_sentences.connect(_enter_sentences)
	_read_home.choose_books.connect(_enter_books)
	_book_shelf.open_book.connect(_enter_reader)
	_write_home.choose_images.connect(_enter_write_images)
	_write_home.choose_narration.connect(_enter_write_narration)

	_show_home_chrome()
	call_deferred("_begin_intro")

func _build_header() -> void:
	_header = Label.new()
	_header.text = ""  # Brand is spoken on intro; avoid word gate for pre-readers.
	_header.visible = false
	_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_header)

func _build_home_tiles() -> void:
	_home = Control.new()
	_home.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_home.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_home)

	_read_tile = _make_home_tile("read", LangTheme.MODES["read"]["color"], Vector2(280, 160))
	_read_tile.pressed.connect(func() -> void: _on_home_tile("read"))
	_home.add_child(_read_tile)

	_write_tile = _make_home_tile("write", LangTheme.MODES["write"]["color"], Vector2(720, 160))
	_write_tile.pressed.connect(func() -> void: _on_home_tile("write"))
	_home.add_child(_write_tile)

func _make_home_tile(icon_id: String, color: Color, pos: Vector2) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(280, 240)
	b.size = Vector2(280, 240)
	b.position = pos
	b.focus_mode = Control.FOCUS_NONE
	LangTheme.style_mode_tile(b, color, false)
	ChromeIcons.apply_button(b, icon_id, 140)
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
	# Barely perceptible occlusion while VO locks input.
	_gate.color = Color(0.02, 0.03, 0.06, 0.14)
	_gate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_gate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gate.visible = false
	_ui.add_child(_gate)

func _process(_delta: float) -> void:
	var busy := Narrator.blocks_input()
	if _gate == null:
		return
	_gate.visible = busy
	_gate.mouse_filter = Control.MOUSE_FILTER_STOP if busy else Control.MOUSE_FILTER_IGNORE
	if busy:
		_ui.move_child(_gate, -1)

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
		1:
			_enter_tutorial("tut_sentences")
		2:
			_enter_tutorial("tut_books")
		3:
			_enter_tutorial("tut_write")
		4:
			_enter_tutorial("tut_alphabet")
		5:
			_enter_tutorial("tut_sketch")
		10:
			Save.set_lang("en")
			Narrator.speak(LangVo.line("english", "en"))
		11:
			Save.set_lang("es")
			Narrator.speak(LangVo.line("spanish", "es"))
		20:
			Save.set_letter_input("alphabet")
			if _write_home.visible:
				_write_home.refresh_input_chrome()
			Narrator.speak(LangVo.line("alphabet_tiles", Save.get_lang()))
		21:
			Save.set_letter_input("sketch")
			if _write_home.visible:
				_write_home.refresh_input_chrome()
			Narrator.speak(LangVo.line("sketch_letters", Save.get_lang()))
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

# ---- intro -------------------------------------------------------------------

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
	ChromeIcons.apply_button(_read_tile, "read", 140)
	ChromeIcons.apply_button(_write_tile, "write", 140)
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

# ---- navigation --------------------------------------------------------------

func _on_home_tile(mode: String) -> void:
	if Narrator.blocks_input() and not _intro_running:
		return
	if _intro_running:
		_skip_intro()
	match mode:
		"read":
			_enter_read()
		"write":
			_enter_write()

func _stop_all_modes() -> void:
	_read_home.stop()
	_write_home.stop()
	_spell_demo.stop()
	_sentence_match.stop()
	_book_shelf.stop()
	_book_reader.stop()
	_write_images.stop()
	_write_narration.stop()
	# Leaving mid-tutorial counts as seen so first-entry doesn't re-trap the player.
	if _tutorial.visible:
		_tutorial.stop(true)
	else:
		_tutorial.stop()

func _enter_read() -> void:
	Save.record_activity_started("read_home")
	_depth = "read"
	_home.visible = false
	_header.visible = false
	_menu_btn.visible = false
	_back.visible = true
	_stop_all_modes()
	_read_home.start()
	_ui.move_child(_read_home, -1)
	_ui.move_child(_back, -1)
	call_deferred("_maybe_tutorial", "tut_read")

func _enter_write() -> void:
	Save.record_activity_started("write_home")
	_depth = "write"
	_home.visible = false
	_header.visible = false
	_menu_btn.visible = false
	_back.visible = true
	_stop_all_modes()
	_write_home.start()
	_ui.move_child(_write_home, -1)
	_ui.move_child(_back, -1)
	call_deferred("_maybe_tutorial", "tut_write")

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

func _enter_sentences() -> void:
	Save.record_activity_started("sentences")
	_depth = "sentences"
	_home.visible = false
	_header.visible = false
	_menu_btn.visible = false
	_back.visible = true
	_stop_all_modes()
	_sentence_match.start(Save.get_lang())
	_ui.move_child(_sentence_match, -1)
	_ui.move_child(_back, -1)
	call_deferred("_maybe_tutorial", "tut_sentences")

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

func _enter_write_images() -> void:
	Save.record_activity_started("write_images")
	_depth = "write_images"
	_home.visible = false
	_header.visible = false
	_menu_btn.visible = false
	_back.visible = true
	_stop_all_modes()
	_write_images.start()
	_ui.move_child(_write_images, -1)
	_ui.move_child(_back, -1)
	call_deferred("_maybe_letter_input_tutorial")

func _enter_write_narration() -> void:
	Save.record_activity_started("write_narration")
	_depth = "write_narration"
	_home.visible = false
	_header.visible = false
	_menu_btn.visible = false
	_back.visible = true
	_stop_all_modes()
	_write_narration.start()
	_ui.move_child(_write_narration, -1)
	_ui.move_child(_back, -1)
	call_deferred("_maybe_letter_input_tutorial")

func _maybe_letter_input_tutorial() -> void:
	if Save.get_letter_input() == "sketch":
		_maybe_tutorial("tut_sketch")
	else:
		_maybe_tutorial("tut_alphabet")

func _on_back() -> void:
	Narrator.stop()
	match _depth:
		"reader":
			_book_reader.stop()
			_enter_books()
		"books":
			_book_shelf.stop()
			_enter_read()
		"sentences":
			_sentence_match.stop()
			_enter_read()
		"write_images":
			_write_images.stop()
			_enter_write()
		"write_narration":
			_write_narration.stop()
			_enter_write()
		"demo":
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

extends Node
## Math Explorer — flow controller.
##
##   Header + a card per tab; tabs across the bottom:
##     + − × ÷  operations → block tutorial ("Watch") + endless block Practice
##     chickens / trains / coins  games → Play (interactive) + Watch where useful
##   ☰ (top-left) opens the Math Concepts Library: block tutorials on top, then
##   the games, then concept videos (two trains) and what's coming.
##
##   First time an activity is opened, its tutorial plays first (tracked in
##   user://seen.cfg), so she is never dropped into a game cold.

const MathTabBar := preload("res://scripts/TabBar.gd")
const AdditionTutorial := preload("res://scripts/AdditionTutorial.gd")
const BlockTutorial := preload("res://scripts/BlockTutorial.gd")
const TrainsScene := preload("res://scripts/TrainsScene.gd")
const EggsScene := preload("res://scripts/EggsScene.gd")
const EggsDragScene := preload("res://scripts/EggsDragScene.gd")
const PracticeScene := preload("res://scripts/PracticeScene.gd")
const CoinsScene := preload("res://scripts/CoinsScene.gd")

const SEEN_PATH := "user://seen.cfg"

## Card copy for the game tabs.
const GAME_CARDS := {
	"eggs": {"title": "Chickens & Eggs", "blurb": "Help the hens fill their nests,\nthen pack the cartons!",
		"play": "Play  \u25B6", "watch": "Watch how it works  \u25B6"},
	"trains": {"title": "Two Trains", "blurb": "The blue train is faster \u2014\nhow far ahead will it get?",
		"play": "Race!  \u25B6", "watch": ""},
	"coins": {"title": "Coin Counter", "blurb": "Pennies, nickels and dimes \u2014\nmake the amount!",
		"play": "Play  \u25B6", "watch": ""},
}

var _ui: Control
var _header: Label
var _card: Control
var _hero: Panel
var _hero_symbol: Label
var _hero_icon: TextureRect
var _title: Label
var _example: Label
var _btn_primary: Button
var _btn_secondary: Button
var _tabs: MathTabBar
var _menu_btn: Button
var _menu: PopupMenu

var _tutorial: AdditionTutorial
var _block_tut: BlockTutorial
var _trains: TrainsScene
var _eggs: EggsScene
var _eggs_drag: EggsDragScene
var _practice: PracticeScene
var _coins: CoinsScene
var _back: Button
var _current_op: String = "add"
var _seen := ConfigFile.new()

func _ready() -> void:
	_seen.load(SEEN_PATH)

	var bg := ColorRect.new()
	bg.color = MathTheme.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_ui = Control.new()
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ui)

	_build_header()
	_build_card()

	_tabs = MathTabBar.new()
	_ui.add_child(_tabs)
	_tabs.selected.connect(_on_tab)

	_tutorial = AdditionTutorial.new()
	_tutorial.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tutorial.visible = false
	_ui.add_child(_tutorial)

	_block_tut = BlockTutorial.new()
	_block_tut.visible = false
	_ui.add_child(_block_tut)

	_trains = TrainsScene.new()
	_trains.visible = false
	_ui.add_child(_trains)

	_eggs = EggsScene.new()
	_eggs.visible = false
	_ui.add_child(_eggs)

	_eggs_drag = EggsDragScene.new()
	_eggs_drag.visible = false
	_ui.add_child(_eggs_drag)

	_practice = PracticeScene.new()
	_practice.visible = false
	_ui.add_child(_practice)

	_coins = CoinsScene.new()
	_coins.visible = false
	_ui.add_child(_coins)

	_build_back_button()
	_build_menu()

	_tabs.select(_current_op)

func _build_header() -> void:
	_header = Label.new()
	_header.text = "Math Explorer"
	_header.add_theme_font_size_override("font_size", 34)
	_header.add_theme_color_override("font_color", MathTheme.TEXT)
	_header.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header.position = Vector2(0, 16)
	_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_header)

func _build_card() -> void:
	_card = Control.new()
	_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_card)

	_hero = Panel.new()
	_hero.custom_minimum_size = Vector2(124, 124)
	_hero.size = Vector2(124, 124)
	_hero.position = Vector2(578, 66)
	_hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(_hero)

	_hero_symbol = Label.new()
	_hero_symbol.add_theme_font_size_override("font_size", 80)
	_hero_symbol.add_theme_color_override("font_color", Color(1, 1, 1))
	_hero_symbol.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hero_symbol.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hero_symbol.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hero_symbol.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hero.add_child(_hero_symbol)

	_hero_icon = TextureRect.new()
	_hero_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hero_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_hero_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hero_icon.offset_left = 12
	_hero_icon.offset_top = 12
	_hero_icon.offset_right = -12
	_hero_icon.offset_bottom = -12
	_hero_icon.visible = false
	_hero_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hero.add_child(_hero_icon)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 36)
	_title.add_theme_color_override("font_color", MathTheme.TEXT)
	_title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.position = Vector2(0, 198)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(_title)

	_example = Label.new()
	_example.add_theme_font_size_override("font_size", 22)
	_example.add_theme_color_override("font_color", MathTheme.TEXT_DIM)
	_example.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_example.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_example.position = Vector2(0, 244)
	_example.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(_example)

	_btn_primary = Button.new()
	_btn_primary.custom_minimum_size = Vector2(340, 66)
	_btn_primary.size = Vector2(340, 66)
	_btn_primary.position = Vector2(470, 316)
	_btn_primary.focus_mode = Control.FOCUS_NONE
	_btn_primary.add_theme_font_size_override("font_size", 27)
	_style_primary(_btn_primary)
	_btn_primary.pressed.connect(_on_primary)
	_card.add_child(_btn_primary)

	_btn_secondary = Button.new()
	_btn_secondary.custom_minimum_size = Vector2(340, 56)
	_btn_secondary.size = Vector2(340, 56)
	_btn_secondary.position = Vector2(470, 396)
	_btn_secondary.focus_mode = Control.FOCUS_NONE
	_btn_secondary.add_theme_font_size_override("font_size", 24)
	_style_secondary(_btn_secondary)
	_btn_secondary.pressed.connect(_on_secondary)
	_card.add_child(_btn_secondary)

func _build_back_button() -> void:
	_back = Button.new()
	_back.text = "\u25C0  Back"
	_back.custom_minimum_size = Vector2(130, 52)
	_back.size = Vector2(130, 52)
	_back.position = Vector2(20, 16)
	_back.focus_mode = Control.FOCUS_NONE
	_back.add_theme_font_size_override("font_size", 22)
	_style_primary(_back)
	_back.visible = false
	_back.pressed.connect(_show_card)
	_ui.add_child(_back)

## ☰ Math Concepts Library — block tutorials on top, then games, then concepts.
func _build_menu() -> void:
	_menu_btn = Button.new()
	_menu_btn.text = "\u2630"
	_menu_btn.custom_minimum_size = Vector2(56, 52)
	_menu_btn.size = Vector2(56, 52)
	_menu_btn.position = Vector2(20, 16)
	_menu_btn.focus_mode = Control.FOCUS_NONE
	_menu_btn.add_theme_font_size_override("font_size", 26)
	_style_secondary(_menu_btn)
	_menu_btn.pressed.connect(_open_menu)
	_ui.add_child(_menu_btn)

	_menu = PopupMenu.new()
	_menu.add_theme_font_size_override("font_size", 22)
	_menu.add_separator("  Tutorials")
	_menu.add_item("Addition blocks", 0)
	_menu.add_item("Subtraction blocks", 1)
	_menu.add_item("Multiplication blocks", 2)
	_menu.add_item("Division blocks", 3)
	_menu.add_separator("  Games")
	_menu.add_item("Chickens & eggs", 10)
	_menu.add_item("Two trains race", 11)
	_menu.add_item("Coin counter", 12)
	_menu.add_separator("  Concepts")
	_menu.add_item("Watch: chickens & eggs", 20)
	_menu.add_item("Watch: two trains", 21)
	_menu.add_item("Big kid ideas (soon)", 22)
	_menu.id_pressed.connect(_on_menu_item)
	_ui.add_child(_menu)

func _open_menu() -> void:
	_menu.popup(Rect2i(Vector2i(20, 72), Vector2i(340, 0)))

func _on_menu_item(id: int) -> void:
	match id:
		0: _play_tutorial_for("add")
		1: _play_tutorial_for("sub")
		2: _play_tutorial_for("mul")
		3: _play_tutorial_for("div")
		10:
			_tabs.select("eggs")
			_launch_game("eggs")
		11:
			_tabs.select("trains")
			_launch_game("trains")
		12:
			_tabs.select("coins")
			_launch_game("coins")
		20:
			_enter_scene(_eggs)
			_eggs.start(-1)
		21:
			_enter_scene(_trains)
			_trains.start(-1)
		22:
			Narrator.speak("Big kid ideas are coming soon!")

# ---- tab / card --------------------------------------------------------------

func _on_tab(tab_id: String) -> void:
	_current_op = tab_id
	_show_card()
	if MathTheme.OPS.has(tab_id):
		var meta: Dictionary = MathTheme.OPS[tab_id]
		_hero_symbol.visible = true
		_hero_icon.visible = false
		_hero_symbol.text = str(meta["symbol"])
		_set_hero_box(meta["color"])
		_title.text = str(meta["label"])
		var tut: Dictionary = MathData.tutorial_for_op(tab_id)
		_example.text = "e.g.  %s" % (tut.get("example", "") if not tut.is_empty() else "")
		_btn_primary.text = "Practice  \u25B6"
		_btn_secondary.text = "Watch the tutorial  \u25B6"
		_btn_secondary.visible = true
		Narrator.speak(str(meta["label"]))
	else:
		var g: Dictionary = MathTabBar.GAME_TABS[tab_id]
		var card: Dictionary = GAME_CARDS[tab_id]
		_hero_symbol.visible = false
		_hero_icon.visible = true
		_hero_icon.texture = StorySprites.texture(str(g["sprite"]))
		_set_hero_box(g["color"])
		_title.text = str(card["title"])
		_example.text = str(card["blurb"])
		_btn_primary.text = str(card["play"])
		_btn_secondary.text = str(card["watch"])
		_btn_secondary.visible = str(card["watch"]) != ""
		Narrator.speak(str(card["title"]))

func _set_hero_box(color: Color) -> void:
	var sb := MathTheme.rounded_box(color, 28)
	sb.set_border_width_all(4)
	sb.border_color = Color(1, 1, 1, 0.35)
	_hero.add_theme_stylebox_override("panel", sb)

func _on_primary() -> void:
	if MathTheme.OPS.has(_current_op):
		# First practice on a tab: play its block tutorial first.
		if not _was_seen("tut_" + _current_op):
			_mark_seen("tut_" + _current_op)
			_play_tutorial_for(_current_op)
			return
		_enter_scene(_practice)
		_practice.start(_current_op)
	else:
		_launch_game(_current_op)

func _on_secondary() -> void:
	if MathTheme.OPS.has(_current_op):
		_play_tutorial_for(_current_op)
	elif _current_op == "eggs":
		_enter_scene(_eggs)
		_eggs.start(-1)

func _play_tutorial_for(op: String) -> void:
	_mark_seen("tut_" + op)
	if op == "add":
		_enter_scene(_tutorial)
		_tutorial.start(7, 4)
	else:
		_enter_scene(_block_tut)
		_block_tut.start(op)

func _launch_game(game: String) -> void:
	match game:
		"eggs":
			# First time: the animated walkthrough teaches the game.
			if not _was_seen("game_eggs"):
				_mark_seen("game_eggs")
				_enter_scene(_eggs)
				_eggs.start(-1)
				return
			_enter_scene(_eggs_drag)
			_eggs_drag.start(-1)
		"trains":
			_enter_scene(_trains)
			_trains.start(-1)
		"coins":
			_enter_scene(_coins)
			_coins.start()

# ---- scene switching -----------------------------------------------------------

func _enter_scene(scene: Control) -> void:
	_hide_scenes()
	_card.visible = false
	_header.visible = false
	_menu_btn.visible = false
	_tabs.visible = false
	_back.visible = true
	scene.visible = true

func _hide_scenes() -> void:
	_tutorial.visible = false
	_block_tut.visible = false
	_trains.visible = false
	_eggs.visible = false
	_eggs_drag.visible = false
	_practice.visible = false
	_practice.stop()
	_coins.visible = false
	_coins.stop()

func _show_card() -> void:
	Narrator.stop()
	_hide_scenes()
	_back.visible = false
	_header.visible = true
	_menu_btn.visible = true
	_tabs.visible = true
	_card.visible = true

# ---- seen flags -----------------------------------------------------------------

func _was_seen(key: String) -> bool:
	return bool(_seen.get_value("seen", key, false))

func _mark_seen(key: String) -> void:
	_seen.set_value("seen", key, true)
	_seen.save(SEEN_PATH)

# ---- styles ---------------------------------------------------------------------

func _style_primary(b: Button) -> void:
	b.add_theme_color_override("font_color", Color(0.06, 0.06, 0.12))
	b.add_theme_color_override("font_hover_color", Color(0.06, 0.06, 0.12))
	b.add_theme_color_override("font_pressed_color", Color(0.06, 0.06, 0.12))
	var sb := StyleBoxFlat.new()
	sb.bg_color = MathTheme.GOLD
	sb.set_corner_radius_all(20)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 6
	var pressed := sb.duplicate() as StyleBoxFlat
	pressed.bg_color = MathTheme.GOLD.darkened(0.12)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("focus", sb)
	b.add_theme_stylebox_override("pressed", pressed)

func _style_secondary(b: Button) -> void:
	b.add_theme_color_override("font_color", MathTheme.TEXT)
	b.add_theme_color_override("font_hover_color", MathTheme.TEXT)
	b.add_theme_color_override("font_pressed_color", MathTheme.TEXT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = MathTheme.PANEL
	sb.set_corner_radius_all(18)
	sb.set_border_width_all(2)
	sb.border_color = Color(1, 1, 1, 0.28)
	var pressed := sb.duplicate() as StyleBoxFlat
	pressed.bg_color = MathTheme.PANEL.lightened(0.06)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("focus", sb)
	b.add_theme_stylebox_override("pressed", pressed)

extends Node
## Math Explorer — preview flow controller.
##
##   Header + big operation card (symbol, example, "Watch the tutorial")
##   Four rounded tabs across the bottom: + − × ÷
##   Tapping "Watch the tutorial" plays the narrated, animated choreography.
##
## Only the Addition tutorial is fully animated in this preview; the others are
## specced in docs/STRATEGY_MATH_EXPLORER.md and announce "coming soon".

const MathTabBar := preload("res://scripts/TabBar.gd")
const AdditionTutorial := preload("res://scripts/AdditionTutorial.gd")
const TrainsScene := preload("res://scripts/TrainsScene.gd")
const EggsScene := preload("res://scripts/EggsScene.gd")
const EggsDragScene := preload("res://scripts/EggsDragScene.gd")
const PracticeScene := preload("res://scripts/PracticeScene.gd")

var _ui: Control
var _card: Control
var _hero: Panel
var _hero_symbol: Label
var _title: Label
var _example: Label
var _tabs: MathTabBar
var _tutorial: AdditionTutorial
var _trains: TrainsScene
var _eggs: EggsScene
var _eggs_drag: EggsDragScene
var _practice: PracticeScene
var _back: Button
var _current_op: String = "add"

func _ready() -> void:
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
	_tutorial.finished.connect(_on_tutorial_finished)
	_ui.add_child(_tutorial)

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

	_build_back_button()

	_tabs.select(_current_op)

func _build_header() -> void:
	var h := Label.new()
	h.text = "Math Explorer"
	h.add_theme_font_size_override("font_size", 34)
	h.add_theme_color_override("font_color", MathTheme.TEXT)
	h.set_anchors_preset(Control.PRESET_TOP_WIDE)
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.position = Vector2(0, 16)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(h)

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

	var play := Button.new()
	play.text = "Watch the tutorial  \u25B6"
	play.custom_minimum_size = Vector2(340, 62)
	play.size = Vector2(340, 62)
	play.position = Vector2(470, 288)
	play.focus_mode = Control.FOCUS_NONE
	play.add_theme_font_size_override("font_size", 26)
	_style_primary(play)
	play.pressed.connect(_on_play_tutorial)
	_card.add_child(play)

	var story := Button.new()
	story.text = "Story problem  \u25B6"
	story.custom_minimum_size = Vector2(340, 56)
	story.size = Vector2(340, 56)
	story.position = Vector2(470, 360)
	story.focus_mode = Control.FOCUS_NONE
	story.add_theme_font_size_override("font_size", 24)
	_style_secondary(story)
	story.pressed.connect(_on_play_story)
	_card.add_child(story)

	var practice := Button.new()
	practice.text = "Practice  \u25B6"
	practice.custom_minimum_size = Vector2(340, 56)
	practice.size = Vector2(340, 56)
	practice.position = Vector2(470, 426)
	practice.focus_mode = Control.FOCUS_NONE
	practice.add_theme_font_size_override("font_size", 24)
	_style_secondary(practice)
	practice.pressed.connect(_on_play_practice)
	_card.add_child(practice)

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

func _on_tab(op_id: String) -> void:
	_current_op = op_id
	_show_card()
	var meta: Dictionary = MathTheme.OPS[op_id]
	_hero_symbol.text = str(meta["symbol"])
	var sb := MathTheme.rounded_box(meta["color"], 28)
	sb.set_border_width_all(4)
	sb.border_color = Color(1, 1, 1, 0.35)
	_hero.add_theme_stylebox_override("panel", sb)
	_title.text = str(meta["label"])
	var tut: Dictionary = MathData.tutorial_for_op(op_id)
	_example.text = "e.g.  %s" % (tut.get("example", "") if not tut.is_empty() else "")
	Narrator.speak(str(meta["label"]))

func _on_play_tutorial() -> void:
	if _current_op == "add":
		_enter_scene(_tutorial)
		_tutorial.start(7, 4)
	elif _current_op == "mul":
		# The animated chickens & eggs walkthrough doubles as the ×-tutorial.
		_enter_scene(_eggs)
		_eggs.start(-1)
	else:
		Narrator.speak("The %s tutorial is coming soon!" % MathTheme.OPS[_current_op]["label"])

func _on_tutorial_finished() -> void:
	# Leave the finished frame up; the Back button returns to the card.
	pass

## Route the "Story problem" button by the active tab:
##   ×  → chickens & eggs   |   −  → two trains   |   others → coming soon
func _on_play_story() -> void:
	if _current_op == "mul":
		_enter_scene(_eggs_drag)
		_eggs_drag.start(-1)
	elif _current_op == "sub":
		_enter_scene(_trains)
		_trains.start(-1)
	else:
		Narrator.speak("A story problem for %s is coming soon!" % MathTheme.OPS[_current_op]["label"])

## Practice works on every tab: endless procedural equations with cube UX.
func _on_play_practice() -> void:
	_enter_scene(_practice)
	_practice.start(_current_op)

func _enter_scene(scene: Control) -> void:
	_hide_scenes()
	_card.visible = false
	_back.visible = true
	scene.visible = true

func _hide_scenes() -> void:
	_tutorial.visible = false
	_trains.visible = false
	_eggs.visible = false
	_eggs_drag.visible = false
	_practice.visible = false
	_practice.stop()

func _show_card() -> void:
	Narrator.stop()
	_hide_scenes()
	_back.visible = false
	_card.visible = true

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


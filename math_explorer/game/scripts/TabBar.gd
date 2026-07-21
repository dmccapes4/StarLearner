class_name MathTabBar
extends Control
## Two tab strips:
##   • Bottom, centred: the four operations (+ − × ÷)
##   • Top-right, vertical: story games (chickens, trains, coins)
## Op tabs are rounded colour squares with the symbol; game tabs show their
## sprite. Emits `selected(tab_id)`. `set_tour_highlight` draws a gold outline
## without selecting (used by the launch intro tour).

signal selected(op_id: String)

const TILE := 84.0
const BAR_H := 104.0
const STORY_W := 110.0

const GAME_TABS := {
	"eggs": {"label": "chickens", "sprite": "chicken_white", "color": Color(0.72, 0.46, 0.20)},
	"trains": {"label": "trains", "sprite": "train_b", "color": Color(0.28, 0.42, 0.62)},
	"coins": {"label": "coins", "sprite": "piggy_bank", "color": Color(0.62, 0.34, 0.52)},
}
const GAME_ORDER := ["eggs", "trains", "coins"]

var _buttons: Dictionary = {}   # tab_id -> Button
var _active: String = ""
var _tour: String = ""        # intro-tour highlight (not a selection)
var _ops_bar: Control
var _story_rail: Control

static func all_tabs() -> Array:
	var out: Array = []
	out.append_array(MathTheme.OP_ORDER)
	out.append_array(GAME_ORDER)
	return out

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ops_bar()
	_build_story_rail()

func _build_ops_bar() -> void:
	_ops_bar = Control.new()
	_ops_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_ops_bar.custom_minimum_size = Vector2(0, BAR_H)
	_ops_bar.offset_top = -BAR_H
	# Leave the story-rail column free so + − × ÷ centre in the main area.
	_ops_bar.offset_right = -(STORY_W + 24.0)
	_ops_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ops_bar)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 28)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ops_bar.add_child(row)

	for op in MathTheme.OP_ORDER:
		var meta: Dictionary = MathTheme.OPS[op]
		_add_tab(row, op, str(meta["label"]).to_lower(), str(meta["symbol"]), null, meta["color"])

func _build_story_rail() -> void:
	_story_rail = Control.new()
	_story_rail.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_story_rail.position = Vector2(-STORY_W - 12.0, 16.0)
	_story_rail.size = Vector2(STORY_W, 460.0)
	_story_rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_story_rail)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_BEGIN
	col.add_theme_constant_override("separation", 14)
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_story_rail.add_child(col)

	for gid in GAME_ORDER:
		var g: Dictionary = GAME_TABS[gid]
		_add_tab(col, gid, str(g["label"]), "", StorySprites.texture(str(g["sprite"])), g["color"])

func _add_tab(parent: Container, id: String, label: String, symbol: String,
		icon: Texture2D, color: Color) -> void:
	var wrap := VBoxContainer.new()
	wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	wrap.add_theme_constant_override("separation", 2)
	parent.add_child(wrap)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(TILE, TILE)
	btn.focus_mode = Control.FOCUS_NONE
	if icon != null:
		btn.icon = icon
		btn.expand_icon = true
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.add_theme_constant_override("icon_max_width", int(TILE - 18))
	else:
		btn.text = symbol
		btn.add_theme_font_size_override("font_size", 46)
	_style_button(btn, color, false, false)
	btn.pressed.connect(func() -> void: select(id))
	wrap.add_child(btn)
	_buttons[id] = btn

	var name_lbl := Label.new()
	name_lbl.text = label
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", MathTheme.TEXT_DIM)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wrap.add_child(name_lbl)

func select(op_id: String) -> void:
	if not _buttons.has(op_id):
		return
	_active = op_id
	_tour = ""
	_refresh_styles()
	selected.emit(op_id)

## No tile selected — home state after launch / after Back with no prior pick.
func clear_selection() -> void:
	_active = ""
	_tour = ""
	_refresh_styles()

## Temporary gold outline for the intro tour (does not select or emit).
func set_tour_highlight(id: String) -> void:
	_tour = id if _buttons.has(id) else ""
	_refresh_styles()

func button_for(id: String) -> Button:
	return _buttons.get(id, null) as Button

func _refresh_styles() -> void:
	for id in _buttons:
		var active: bool = id == _active
		var tour: bool = id == _tour
		_style_button(_buttons[id], _tab_color(id), active, tour)

static func _tab_color(id: String) -> Color:
	if MathTheme.OPS.has(id):
		return MathTheme.OPS[id]["color"]
	return GAME_TABS[id]["color"]

func _style_button(btn: Button, color: Color, active: bool, tour: bool) -> void:
	btn.add_theme_color_override("font_color", Color(1, 1, 1))
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
	var sb := StyleBoxFlat.new()
	sb.bg_color = color if (active or tour) else color.darkened(0.28)
	sb.set_corner_radius_all(20)
	if active or tour:
		sb.set_border_width_all(4)
		sb.border_color = MathTheme.GOLD
		sb.shadow_color = Color(MathTheme.GOLD, 0.45)
		sb.shadow_size = 8
	var pressed := sb.duplicate() as StyleBoxFlat
	pressed.bg_color = color.darkened(0.1)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.add_theme_stylebox_override("focus", sb)
	btn.add_theme_stylebox_override("pressed", pressed)

## Gold outline for a non-tab Control (the ☰ menu) during the intro tour.
static func style_tour_control(btn: Button, on: bool, base_style: Callable = Callable()) -> void:
	if on:
		var sb := StyleBoxFlat.new()
		sb.bg_color = MathTheme.PANEL
		sb.set_corner_radius_all(18)
		sb.set_border_width_all(4)
		sb.border_color = MathTheme.GOLD
		sb.shadow_color = Color(MathTheme.GOLD, 0.45)
		sb.shadow_size = 8
		for state in ["normal", "hover", "focus", "pressed"]:
			btn.add_theme_stylebox_override(state, sb)
	elif base_style.is_valid():
		base_style.call(btn)

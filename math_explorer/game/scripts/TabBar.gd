class_name MathTabBar
extends Control
## Tabs across the bottom: the four operations (+ − × ÷) plus the game tabs —
## chickens (egg-packing), trains (the race), and coins (make the amount).
## Op tabs are rounded colour squares with the symbol; game tabs show their
## sprite. Emits `selected(tab_id)` and highlights the active one.

signal selected(op_id: String)

const BAR_H := 104.0
const TILE := 84.0

## Game tabs appended after the four operations.
const GAME_TABS := {
	"eggs": {"label": "chickens", "sprite": "chicken_white", "color": Color(0.72, 0.46, 0.20)},
	"trains": {"label": "trains", "sprite": "train_b", "color": Color(0.28, 0.42, 0.62)},
	"coins": {"label": "coins", "sprite": "piggy_bank", "color": Color(0.62, 0.34, 0.52)},
}
const GAME_ORDER := ["eggs", "trains", "coins"]

var _buttons: Dictionary = {}   # tab_id -> Button
var _active: String = ""

static func all_tabs() -> Array:
	var out: Array = []
	out.append_array(MathTheme.OP_ORDER)
	out.append_array(GAME_ORDER)
	return out

func _ready() -> void:
	set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	custom_minimum_size = Vector2(0, BAR_H)
	offset_top = -BAR_H
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(row)

	for op in MathTheme.OP_ORDER:
		var meta: Dictionary = MathTheme.OPS[op]
		_add_tab(row, op, str(meta["label"]).to_lower(), str(meta["symbol"]), null, meta["color"])
	for gid in GAME_ORDER:
		var g: Dictionary = GAME_TABS[gid]
		_add_tab(row, gid, str(g["label"]), "", StorySprites.texture(str(g["sprite"])), g["color"])

func _add_tab(row: HBoxContainer, id: String, label: String, symbol: String,
		icon: Texture2D, color: Color) -> void:
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)

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
	_style_button(btn, color, false)
	btn.pressed.connect(func() -> void: select(id))
	col.add_child(btn)
	_buttons[id] = btn

	var name_lbl := Label.new()
	name_lbl.text = label
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", MathTheme.TEXT_DIM)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(name_lbl)

func select(op_id: String) -> void:
	if not _buttons.has(op_id):
		return
	_active = op_id
	for id in _buttons:
		_style_button(_buttons[id], _tab_color(id), id == op_id)
	selected.emit(op_id)

static func _tab_color(id: String) -> Color:
	if MathTheme.OPS.has(id):
		return MathTheme.OPS[id]["color"]
	return GAME_TABS[id]["color"]

func _style_button(btn: Button, color: Color, active: bool) -> void:
	btn.add_theme_color_override("font_color", Color(1, 1, 1))
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
	var sb := StyleBoxFlat.new()
	sb.bg_color = color if active else color.darkened(0.28)
	sb.set_corner_radius_all(20)
	if active:
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

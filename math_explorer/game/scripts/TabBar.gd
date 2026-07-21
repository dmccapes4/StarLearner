class_name MathTabBar
extends Control
## Four rounded-square tabs across the bottom: addition, subtraction,
## multiplication, division. Emits `selected(op_id)` and highlights the active one.

signal selected(op_id: String)

const BAR_H := 104.0
const TILE := 84.0

var _buttons: Dictionary = {}   # op_id -> Button
var _active: String = ""

func _ready() -> void:
	set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	custom_minimum_size = Vector2(0, BAR_H)
	offset_top = -BAR_H
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 26)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(row)

	for op in MathTheme.OP_ORDER:
		var meta: Dictionary = MathTheme.OPS[op]
		var col := VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_theme_constant_override("separation", 2)
		row.add_child(col)

		var btn := Button.new()
		btn.text = str(meta["symbol"])
		btn.custom_minimum_size = Vector2(TILE, TILE)
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_size_override("font_size", 46)
		_style_button(btn, meta["color"], false)
		btn.pressed.connect(func() -> void: select(op))
		col.add_child(btn)
		_buttons[op] = btn

		var name_lbl := Label.new()
		name_lbl.text = str(meta["label"])
		name_lbl.add_theme_font_size_override("font_size", 15)
		name_lbl.add_theme_color_override("font_color", MathTheme.TEXT_DIM)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(name_lbl)

func select(op_id: String) -> void:
	if not _buttons.has(op_id):
		return
	_active = op_id
	for id in _buttons:
		_style_button(_buttons[id], MathTheme.OPS[id]["color"], id == op_id)
	selected.emit(op_id)

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

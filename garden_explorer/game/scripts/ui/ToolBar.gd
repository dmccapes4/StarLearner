class_name ToolBar
extends CanvasLayer
## Bottom tools: big square icon tiles. Tap selects, narrates, gold outline + slight enlarge.

var _bar: HBoxContainer
var _buttons: Dictionary = {} ## id -> Button
var _icons: Dictionary = {} ## id -> Control (visual)
var tool_id: String = "water"

const TOOLS := [
	{"id": "water", "label": "Water", "line": "Water can ready. Tap a thirsty plant."},
	{"id": "harvest", "label": "Harvest", "line": "Harvest basket ready. Tap a grown plant."},
	{"id": "uproot", "label": "Uproot", "line": "Uproot ready. Tap a plant to pull it out."},
]

func _ready() -> void:
	layer = 25
	_build()
	## Persistent tool intent removed — actions appear at interactables.
	## Do not emit tool_changed here; ShedUI / save owns the hand.
	visible = false
	tool_id = ""
	_sync_buttons()

func hide_bar() -> void:
	visible = false

func get_tool() -> String:
	return tool_id

func set_tool(id: String, speak: bool = true) -> void:
	tool_id = id
	_sync_buttons()
	Events.tool_changed.emit(tool_id)
	if speak:
		var line := id.capitalize()
		for t in TOOLS:
			if str(t.id) == id:
				line = str(t.line)
				break
		var SpeakScript := preload("res://scripts/audio/Speak.gd")
		SpeakScript.line(line)

func _build() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_bar = HBoxContainer.new()
	_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_bar.offset_left = -200
	_bar.offset_right = 200
	_bar.offset_top = -130
	_bar.offset_bottom = -24
	_bar.add_theme_constant_override("separation", 18)
	_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(_bar)

	for t in TOOLS:
		var id := str(t.id)
		var btn := _mk_tile(id)
		_buttons[id] = btn
		_bar.add_child(btn)

func _mk_tile(id: String) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(108, 108)
	b.pressed.connect(func() -> void: set_tool(id, true))
	var icon := _make_icon(id)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 18
	icon.offset_top = 18
	icon.offset_right = -18
	icon.offset_bottom = -18
	b.add_child(icon)
	_icons[id] = icon
	return b

func _make_icon(id: String) -> Control:
	## Simple vector glyphs — readable at kid-thumb size without emoji fonts.
	var wrap := Control.new()
	wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	match id:
		"water":
			var drop := Polygon2D.new()
			drop.color = Color(0.35, 0.65, 0.95, 1)
			drop.polygon = PackedVector2Array([
				Vector2(36, 8), Vector2(56, 36), Vector2(48, 58), Vector2(24, 58), Vector2(16, 36),
			])
			wrap.add_child(drop)
		"harvest":
			var basket := Polygon2D.new()
			basket.color = Color(0.72, 0.48, 0.22, 1)
			basket.polygon = PackedVector2Array([
				Vector2(14, 28), Vector2(58, 28), Vector2(52, 58), Vector2(20, 58),
			])
			wrap.add_child(basket)
			var handle := Polygon2D.new()
			handle.color = Color(0.55, 0.35, 0.16, 1)
			handle.polygon = PackedVector2Array([
				Vector2(22, 28), Vector2(28, 14), Vector2(44, 14), Vector2(50, 28),
				Vector2(44, 28), Vector2(40, 20), Vector2(32, 20), Vector2(28, 28),
			])
			wrap.add_child(handle)
		"uproot":
			var leaf := Polygon2D.new()
			leaf.color = Color(0.45, 0.75, 0.35, 1)
			leaf.polygon = PackedVector2Array([
				Vector2(36, 10), Vector2(54, 28), Vector2(40, 34), Vector2(48, 52),
				Vector2(36, 42), Vector2(24, 52), Vector2(32, 34), Vector2(18, 28),
			])
			wrap.add_child(leaf)
			var root := Polygon2D.new()
			root.color = Color(0.55, 0.38, 0.18, 1)
			root.polygon = PackedVector2Array([
				Vector2(30, 48), Vector2(42, 48), Vector2(46, 62), Vector2(36, 56), Vector2(26, 62),
			])
			wrap.add_child(root)
		_:
			pass
	return wrap

func _sync_buttons() -> void:
	for id in _buttons.keys():
		var btn: Button = _buttons[id]
		var selected := str(id) == tool_id
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.16, 0.22, 0.14, 0.92) if not selected else Color(0.22, 0.30, 0.16, 0.98)
		sb.set_corner_radius_all(18)
		var border := 6 if selected else 2
		sb.set_border_width_all(border)
		sb.border_color = Color(1.0, 0.82, 0.2, 1.0) if selected else Color(1, 1, 1, 0.2)
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("hover", sb)
		btn.add_theme_stylebox_override("pressed", sb)
		btn.scale = Vector2(1.12, 1.12) if selected else Vector2.ONE
		## Keep layout stable: pivot from center.
		btn.pivot_offset = btn.custom_minimum_size * 0.5

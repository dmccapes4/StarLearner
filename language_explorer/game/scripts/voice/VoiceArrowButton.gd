class_name VoiceArrowButton
extends Button
## Tall silver triangle for Voice practice navigation (no chrome tile background).

enum Dir { LEFT, RIGHT }

const SILVER := Color(0.76, 0.80, 0.88)
const SILVER_HOVER := Color(0.92, 0.94, 0.98)
const SILVER_PRESSED := Color(0.58, 0.62, 0.72)
const SILVER_DISABLED := Color(0.42, 0.45, 0.52)

var direction: int = Dir.LEFT
var _visually_pressed: bool = false

func _ready() -> void:
	text = ""
	focus_mode = Control.FOCUS_NONE
	var empty := StyleBoxEmpty.new()
	add_theme_stylebox_override("normal", empty)
	add_theme_stylebox_override("hover", empty)
	add_theme_stylebox_override("pressed", empty)
	add_theme_stylebox_override("focus", empty)
	add_theme_stylebox_override("disabled", empty)
	mouse_entered.connect(func() -> void: queue_redraw())
	mouse_exited.connect(func() -> void: queue_redraw())
	button_down.connect(func() -> void:
		_visually_pressed = true
		queue_redraw())
	button_up.connect(func() -> void:
		_visually_pressed = false
		queue_redraw())

func _draw() -> void:
	var fill := SILVER
	if disabled:
		fill = SILVER_DISABLED
	elif _visually_pressed:
		fill = SILVER_PRESSED
	elif is_hovered():
		fill = SILVER_HOVER
	var w := size.x
	var h := size.y
	var inset := 6.0
	var tip_inset := 10.0
	var pts: PackedVector2Array
	if direction == Dir.LEFT:
		pts = PackedVector2Array([
			Vector2(w - tip_inset, inset),
			Vector2(w - tip_inset, h - inset),
			Vector2(inset, h * 0.5),
		])
	else:
		pts = PackedVector2Array([
			Vector2(tip_inset, inset),
			Vector2(tip_inset, h - inset),
			Vector2(w - inset, h * 0.5),
		])
	draw_colored_polygon(pts, fill)
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color(1, 1, 1, 0.22), 2.0, true)

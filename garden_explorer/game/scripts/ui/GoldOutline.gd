class_name GoldOutline
extends Node2D
## Pulsing gold ring around a guidance target (beds / shed / fence).

var _active: bool = false
var _radius: float = 48.0
var _left: float = 0.0
var _pulse: float = 0.0

func _ready() -> void:
	z_index = 80
	visible = false
	set_process(true)

func show_at(world_pos: Vector2, radius: float = 56.0, duration: float = 4.5) -> void:
	global_position = world_pos
	_radius = radius
	_left = duration
	_pulse = 0.0
	_active = true
	visible = true
	queue_redraw()

func hide_outline() -> void:
	_active = false
	_left = 0.0
	visible = false
	queue_redraw()

func is_active() -> bool:
	return _active

func _process(delta: float) -> void:
	if not _active:
		return
	_pulse += delta * 3.2
	_left -= delta
	if _left <= 0.0:
		hide_outline()
		return
	queue_redraw()

func _draw() -> void:
	if not _active:
		return
	var a := 0.55 + 0.35 * sin(_pulse)
	var r := _radius * (1.0 + 0.08 * sin(_pulse * 1.3))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(1.0, 0.85, 0.25, a), 5.0, true)
	draw_arc(Vector2.ZERO, r * 0.72, 0.0, TAU, 32, Color(1.0, 0.95, 0.45, a * 0.55), 3.0, true)

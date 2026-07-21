extends Node2D
## Glowing knowledge-star marker — documentary plays on player approach (Phase 5).

var star_id: String = ""
var collected: bool = false
var _pulse: float = 0.0
var _body: Polygon2D
var _pulse_speed: float = 3.0
var _pulse_amp: float = 0.18

func setup(id: String, pos: Vector2) -> void:
	star_id = id
	global_position = pos
	z_index = 40
	var scale := 2.4
	if Config and Config.data:
		scale = Config.data.star_visual_scale
	var r := 16.0 * scale
	_body = Polygon2D.new()
	_body.color = Color(1.0, 0.9, 0.35, 0.95)
	_body.polygon = PackedVector2Array([
		Vector2(0, -r), Vector2(r * 0.25, -r * 0.25), Vector2(r, 0), Vector2(r * 0.25, r * 0.25),
		Vector2(0, r), Vector2(-r * 0.25, r * 0.25), Vector2(-r, 0), Vector2(-r * 0.25, -r * 0.25),
	])
	add_child(_body)


func set_collected(on: bool) -> void:
	collected = on
	if on:
		_pulse_speed = 1.6
		_pulse_amp = 0.08
		if _body:
			_body.color = Color(0.75, 0.62, 0.22, 0.75)
	else:
		_pulse_speed = 3.0
		_pulse_amp = 0.18
		if _body:
			_body.color = Color(1.0, 0.9, 0.35, 0.95)


func _process(delta: float) -> void:
	_pulse += delta * _pulse_speed
	var s := 1.0 + _pulse_amp * sin(_pulse)
	scale = Vector2(s, s)
	if _body:
		var alpha_base := 0.65 if collected else 0.75
		_body.modulate.a = alpha_base + 0.25 * sin(_pulse * 1.3)

extends Node2D
## Pheromone-trail entry icon — a pulsing role-colored scent drop, tapped to
## join that job (same interaction model as knowledge stars).

const TAP_RADIUS := 110.0

var role: int = AntEnums.Role.NONE
var _pulse: float = 0.0
var _drop: Polygon2D
var _ring: Polygon2D

func setup(p_role: int, pos: Vector2) -> void:
	role = p_role
	global_position = pos
	z_index = 40
	var col := AntEnums.role_color(role)

	_ring = Polygon2D.new()
	_ring.color = Color(col.r, col.g, col.b, 0.28)
	_ring.polygon = _circle(46.0)
	add_child(_ring)

	_drop = Polygon2D.new()
	_drop.color = Color(col.r, col.g, col.b, 0.95)
	_drop.polygon = _circle(28.0)
	add_child(_drop)

	# Little scent dots trailing off, so it reads as pheromone.
	for i in 3:
		var dot := Polygon2D.new()
		dot.color = Color(col.r, col.g, col.b, 0.7 - float(i) * 0.18)
		dot.polygon = _circle(8.0 - float(i) * 2.0)
		dot.position = Vector2(34.0 + float(i) * 20.0, 26.0 + float(i) * 12.0)
		add_child(dot)

func hit_test(world_pos: Vector2) -> bool:
	return global_position.distance_to(world_pos) <= TAP_RADIUS

func _process(delta: float) -> void:
	_pulse += delta * 2.6
	var s := 1.0 + 0.14 * sin(_pulse)
	scale = Vector2(s, s)
	if _ring:
		_ring.modulate.a = 0.7 + 0.3 * sin(_pulse * 1.3)

static func _circle(r: float, segments: int = 20) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in segments:
		var a := TAU * float(i) / float(segments)
		pts.append(Vector2(cos(a), sin(a)) * r)
	return pts

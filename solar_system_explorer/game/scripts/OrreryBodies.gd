class_name OrreryBodies
extends Node2D
## Top-down animated orrery: the Sun, the eight planets tracing flattened
## ellipses, and the asteroid belt as a scattered ring between Mars and Jupiter.
## Purely visual — the tour logic lives in OrreryView.

const CENTER := Vector2(640, 312)
const FLATTEN := 0.42  ## ellipse height / width, gives the "looking down" feel

var t: float = 0.0
var running: bool = false
var highlight_id: String = ""

var _orbiting: Array = SolarData.orbiting()
var _belt: Dictionary = SolarData.belt()
var _belt_rocks: Array = _make_belt_rocks()

func _process(delta: float) -> void:
	if running:
		t += delta
		queue_redraw()

func set_highlight(id: String) -> void:
	highlight_id = id
	queue_redraw()

func _planet_radius(draw_radius: float) -> float:
	return clampf(draw_radius * 0.30, 6.0, 34.0)

func _make_belt_rocks() -> Array:
	var out: Array = []
	if _belt.is_empty():
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	for i in 90:
		out.append({
			"ang": rng.randf() * TAU,
			"jitter": rng.randf_range(-12.0, 12.0),
			"size": rng.randf_range(1.4, 3.0),
		})
	return out

func _draw() -> void:
	# Sun.
	draw_circle(CENTER, 40.0, Color(1.0, 0.86, 0.35, 0.28))
	draw_circle(CENTER, 30.0, Color(1.0, 0.80, 0.24))

	for b in _orbiting:
		var rx: float = float(b["orrery_rx"])
		_draw_orbit(rx, rx * FLATTEN)

	_draw_belt()

	for b in _orbiting:
		var rx: float = float(b["orrery_rx"])
		var ry: float = rx * FLATTEN
		var period: float = maxf(0.5, float(b["period"]))
		var ang: float = t * TAU / period + float(b["orbit_index"]) * 0.7
		var pos := CENTER + Vector2(cos(ang) * rx, sin(ang) * ry)
		var pr := _planet_radius(float(b["draw_radius"]))
		if str(b["id"]) == highlight_id:
			draw_arc(pos, pr + 9.0, 0.0, TAU, 40, Color(1, 1, 1, 0.9), 3.0)
		draw_circle(pos, pr, b["color"])
		if str(b["id"]) == highlight_id:
			_label(b["name"], pos + Vector2(0, -pr - 16.0))

func _draw_belt() -> void:
	if _belt.is_empty():
		return
	var rx: float = float(_belt["orrery_rx"])
	var ry: float = rx * FLATTEN
	var hot := highlight_id == str(_belt["id"])
	var col := Color(0.85, 0.82, 0.72, 0.95) if hot else Color(0.66, 0.62, 0.55, 0.7)
	var spin := t * 0.05
	for rock in _belt_rocks:
		var a: float = float(rock["ang"]) + spin
		var j: float = float(rock["jitter"])
		var pos := CENTER + Vector2(cos(a) * (rx + j), sin(a) * (ry + j * FLATTEN))
		draw_circle(pos, float(rock["size"]), col)
	if hot:
		_label(_belt["name"], CENTER + Vector2(0, -ry - 18.0))

func _label(text: String, at: Vector2) -> void:
	var font := ThemeDB.fallback_font
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	draw_string(font, at + Vector2(-w * 0.5, 0), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 1, 1))

func _draw_orbit(rx: float, ry: float) -> void:
	var pts := PackedVector2Array()
	var steps := 64
	for i in steps + 1:
		var a := TAU * float(i) / float(steps)
		pts.append(CENTER + Vector2(cos(a) * rx, sin(a) * ry))
	draw_polyline(pts, Color(0.5, 0.56, 0.85, 0.25), 1.5)

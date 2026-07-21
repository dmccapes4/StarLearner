class_name BodyCell
extends Control
## Visual-only body in the horizontal strip (disc + name). Taps are handled by
## ScrollView so swipes always scroll the strip.

const DISC_Y := 220.0

var body: Dictionary

func setup(b: Dictionary) -> void:
	body = b
	var r: float = float(b["draw_radius"])
	custom_minimum_size = Vector2(2.0 * r + 40.0, 560.0)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_text = b["name"]
	queue_redraw()

func contains_local_point(local: Vector2) -> bool:
	## Generous disc hit target (not the full tall cell) so gaps scroll cleanly.
	var r: float = float(body["draw_radius"]) + 28.0
	var c := Vector2(size.x * 0.5, DISC_Y)
	return local.distance_to(c) <= r

func _draw() -> void:
	var r: float = float(body["draw_radius"])
	var c := Vector2(size.x * 0.5, DISC_Y)
	if bool(body.get("belt", false)):
		_draw_belt(c, r)
	else:
		if bool(body.get("ring", false)):
			_draw_ring(c, r)
		draw_circle(c, r, body["color"])
		draw_circle(c + Vector2(-r * 0.28, -r * 0.28), r * 0.55, Color(1, 1, 1, 0.10))

	var font := ThemeDB.fallback_font
	_centered(font, body["name"], 30, Color(1, 1, 1), 430.0)
	if bool(body.get("dwarf", false)):
		_centered(font, "(not a planet anymore)", 20, Color(1.0, 0.62, 0.55), 466.0)
	elif bool(body.get("is_star", false)):
		_centered(font, "our star", 20, Color(1.0, 0.86, 0.5), 466.0)
	else:
		_centered(font, "tap to explore", 20, Color(0.72, 0.8, 1.0), 466.0)

func _draw_belt(c: Vector2, r: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 909090
	for i in 60:
		var ang := rng.randf() * TAU
		var rad := rng.randf_range(0.15, 1.0) * r
		var p := c + Vector2(cos(ang) * rad, sin(ang) * rad * 0.9)
		draw_circle(p, rng.randf_range(2.0, 5.5), body["color"])

func _centered(font: Font, text: String, fsize: int, col: Color, y: float) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
	draw_string(font, Vector2(size.x * 0.5 - w * 0.5, y), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)

func _draw_ring(c: Vector2, r: float) -> void:
	var pts := PackedVector2Array()
	var steps := 48
	for i in steps + 1:
		var a := TAU * float(i) / float(steps)
		pts.append(c + Vector2(cos(a) * r * 1.7, sin(a) * r * 0.5))
	draw_polyline(pts, Color(0.9, 0.85, 0.6, 0.8), 5.0)

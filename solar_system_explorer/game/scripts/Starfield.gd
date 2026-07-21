class_name Starfield
extends Node2D
## Static seeded backdrop of stars. Drawn once behind every view.

const DESIGN := Vector2(1280, 600)
const COUNT := 140

func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260721
	for i in COUNT:
		var p := Vector2(rng.randf() * DESIGN.x, rng.randf() * DESIGN.y)
		var r := rng.randf_range(0.6, 1.8)
		var a := rng.randf_range(0.25, 0.9)
		draw_circle(p, r, Color(1, 1, 1, a))

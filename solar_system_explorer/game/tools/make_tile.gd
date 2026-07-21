extends SceneTree
## Dev-only: render a 512x512 launcher tile for the Star Learner home shell,
## purely procedurally (no art assets). Writes docs/tile_solar.png.
##   DISPLAY=:1 godot --path . -s res://tools/make_tile.gd

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var tile := TileArt.new()
	root.add_child(tile)
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := get_root().get_texture().get_image()
	var cut := img.get_region(Rect2i(0, 0, 512, 512))
	var out := "res://docs/tile_solar.png"
	cut.save_png(ProjectSettings.globalize_path(out))
	print("wrote ", out)
	quit()

class TileArt extends Node2D:
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 512, 512), Color(0.04, 0.06, 0.18))
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for i in 60:
			draw_circle(Vector2(rng.randf() * 512, rng.randf() * 512),
				rng.randf_range(0.8, 2.0), Color(1, 1, 1, rng.randf_range(0.3, 0.9)))
		var c := Vector2(150, 300)
		# orbit
		var pts := PackedVector2Array()
		for i in 65:
			var a := TAU * float(i) / 64.0
			pts.append(c + Vector2(cos(a) * 300.0, sin(a) * 150.0))
		draw_polyline(pts, Color(0.5, 0.56, 0.85, 0.35), 2.0)
		# sun
		draw_circle(c, 120.0, Color(1.0, 0.86, 0.35, 0.30))
		draw_circle(c, 92.0, Color(1.0, 0.80, 0.24))
		# a couple planets
		draw_circle(c + Vector2(300, 40), 30.0, Color(0.28, 0.55, 0.85))
		draw_circle(c + Vector2(150, -150), 20.0, Color(0.80, 0.36, 0.22))
		var s := c + Vector2(340, -120)
		var ring := PackedVector2Array()
		for i in 49:
			var a := TAU * float(i) / 48.0
			ring.append(s + Vector2(cos(a) * 70.0, sin(a) * 22.0))
		draw_polyline(ring, Color(0.9, 0.85, 0.6, 0.8), 4.0)
		draw_circle(s, 34.0, Color(0.86, 0.78, 0.55))

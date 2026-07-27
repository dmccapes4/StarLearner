extends SceneTree
## Screenshot every ORBIT_CINEMATIC (13 destinations) at a mid-play beat.
##   DISPLAY=:1 godot --path . -s res://tools/capture_cinematics.gd

const OrbitCinematic := preload("res://scripts/OrbitCinematic.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var dir := "res://docs/screenshots/cinematics"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	root.get_viewport().size = Vector2i(1280, 600)
	var cine: OrbitCinematic = OrbitCinematic.new()
	root.add_child(cine)
	var ids := ["sun", "mercury", "venus", "earth", "mars", "jupiter",
		"saturn", "uranus", "neptune", "pluto", "ceres", "vesta", "psyche"]
	for id in ids:
		cine.play(id)
		# Advance to the title beat (~60% in) and settle a few frames.
		cine._t = OrbitCinematic.DURATION_S * 0.6
		cine._place_cam(0.6)
		for i in 6:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_viewport().get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path("%s/%s.png" % [dir, id]))
		print("  shot: ", id)
		cine.stop()
	print("CINEMATIC shots → ", ProjectSettings.globalize_path(dir))
	quit(0)

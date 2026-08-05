extends SceneTree
## Capture spring/summer/fall/winter yard shots for season FX review.
## Run: godot --path game --headless -s res://tools/shot_season_fx.gd
## (Needs a display / xvfb for Viewport textures.)

const OUT := "res://docs/screenshots/ux"

func _initialize() -> void:
	await process_frame
	var main_ps := load("res://scenes/Main.tscn") as PackedScene
	var main: Node = main_ps.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var world: Node = main.get_node_or_null("World")
	if world == null:
		push_error("no World")
		quit(1)
		return
	## Skip intro if present.
	var intro := root.get_node_or_null("IntroPanel")
	if intro == null:
		intro = main.get_node_or_null("IntroPanel")
	if intro and intro.has_method("close_intro"):
		intro.call("close_intro")
	elif intro and intro.has_method("hide_panel"):
		intro.call("hide_panel")
	elif intro:
		intro.visible = false
	await process_frame
	var farm: FarmMap = world.get("farm_map")
	var cam: Camera2D = world.get_node_or_null("CameraFollow") as Camera2D
	if cam and farm:
		cam.global_position = farm.spawn_world
		## Match play zoom so tree placement is judged fairly.
		cam.zoom = Vector2(2.05, 2.05)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for sid in ["spring", "summer", "fall", "winter"]:
		if farm:
			farm.apply_season_tint(sid)
		print("trees=", farm._meadow_trees.size() if farm else -1)
		## Give weather overlay + particles time to fill the view.
		await create_timer(1.6).timeout
		await process_frame
		await process_frame
		var img: Image = root.get_viewport().get_texture().get_image()
		var path := "%s/season_fx_%s.png" % [OUT, sid]
		img.save_png(ProjectSettings.globalize_path(path))
		print("wrote ", path, " weather=", farm.get_node_or_null("SeasonWeather") != null if farm else false)
	quit(0)

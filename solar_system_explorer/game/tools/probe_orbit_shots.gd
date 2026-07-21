extends SceneTree
## Render probe — screenshot Mercury orbit at several light settings and print
## the average brightness of the planet area so we can pick readable knobs.
##   DISPLAY=:1 godot --path . -s res://tools/probe_orbit_shots.gd

const FlyScene := preload("res://scripts/FlyScene.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var dir := "res://docs/screenshots/probe"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var cfg := SolarFlyerConfig.load_default()
	var fly: FlyScene = FlyScene.new()
	root.add_child(fly)
	fly.set_active(true)
	var earth := SolarData.flyer_body_by_id("earth", cfg)
	var merc := SolarData.flyer_body_by_id("mercury", cfg)
	var standoff := OrbitMath.orbit_standoff(float(earth["hero_r"]))
	var route := OrbitMath.plot_route(OrbitMath.body_pos(earth, 0.0), merc, 0.0, cfg, standoff)
	fly.begin_flight("mercury", route, 0.0)
	fly._flight_t = float(route["duration"]) * 0.97
	await process_frame
	if not fly._orbiting:
		fly._try_enter_orbit_from_approach(true)

	for setup in [
		{"tag": "a0_e10", "energy": 1.0, "atten": 0.0},
		{"tag": "a0_e15", "energy": 1.5, "atten": 0.0},
		{"tag": "a0_e22", "energy": 2.2, "atten": 0.0},
		{"tag": "a01_e15", "energy": 1.5, "atten": 0.1},
	]:
		fly._sun_light.light_energy = float(setup["energy"])
		fly._sun_light.omni_attenuation = float(setup["atten"])
		for i in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := get_root().get_texture().get_image()
		var path := ProjectSettings.globalize_path(dir + "/orbit_%s.png" % setup["tag"])
		img.save_png(path)
		# Sample the center of the window (planet fills it in orbit).
		var sum := 0.0
		var n := 0
		for y in range(200, 300, 10):
			for x in range(460, 580, 10):
				var c := img.get_pixel(x, y)
				sum += (c.r + c.g + c.b) / 3.0
				n += 1
		print("%s: avg planet brightness %.3f  (%s)" % [setup["tag"], sum / n, path])
	quit()

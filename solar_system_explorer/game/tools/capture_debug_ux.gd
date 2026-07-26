extends SceneTree
## Debug screenshots for ScrollView skins + flight/orbit.
##   DISPLAY=:1 godot --path . -s res://tools/capture_debug_ux.gd

const Starfield := preload("res://scripts/Starfield.gd")
const ScrollView := preload("res://scripts/ScrollView.gd")
const PlotBoard := preload("res://scripts/PlotBoard.gd")
const FlyScene := preload("res://scripts/FlyScene.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var dir := "res://docs/screenshots/debug"
	var abs_dir := ProjectSettings.globalize_path(dir)
	DirAccess.make_dir_recursive_absolute(abs_dir)

	# Scroll strip — Earth-centered, then mid-spin frames.
	var bg := Starfield.new()
	var scroll: ScrollView = ScrollView.new()
	root.add_child(bg)
	root.add_child(scroll)
	scroll.begin_exploration()
	for i in 10:
		await process_frame
	await _shot(dir + "/10_scroll_earth.png")

	# Wait so discs advance spin (if any).
	for i in 45:
		await process_frame
	await _shot(dir + "/11_scroll_spin_a.png")
	for i in 45:
		await process_frame
	await _shot(dir + "/12_scroll_spin_b.png")

	# Fly ship toward Jupiter on the strip.
	scroll._on_body_tapped(6)
	for i in 12:
		await process_frame
	await _shot(dir + "/13_scroll_flight_mid.png")
	for i in 40:
		await process_frame
	await _shot(dir + "/14_scroll_flight_near.png")
	scroll.queue_free()
	bg.queue_free()
	await process_frame

	# Plot board top-down.
	bg = Starfield.new()
	var board: PlotBoard = PlotBoard.new()
	root.add_child(bg)
	root.add_child(board)
	board.set_ship_at("earth")
	board.begin_plot("mars")
	for i in 20:
		await process_frame
	await _shot(dir + "/20_plot_chart.png")
	for i in 90:
		await process_frame
	await _shot(dir + "/21_plot_ready.png")
	board.queue_free()
	bg.queue_free()
	await process_frame

	# Flight scene — approach + orbit frames.
	bg = Starfield.new()
	var fly: FlyScene = FlyScene.new()
	root.add_child(bg)
	root.add_child(fly)
	fly.visible = true
	fly.set_active(true)
	var cfg := SolarFlyerConfig.load_default()
	var earth := SolarData.flyer_body_by_id("earth", cfg)
	var mars := SolarData.flyer_body_by_id("mars", cfg)
	var route := OrbitMath.plot_route(OrbitMath.body_pos(earth, 0.0), mars, 0.0, cfg)
	route["travel_au"] = absf(float(mars["a_au"]) - float(earth["a_au"]))
	fly.begin_flight("mars", route, 0.0)
	for u_i in [0, 15, 35, 55, 75, 88]:
		fly._play_u = float(u_i) / 100.0
		fly._progress_u = fly._play_u
		fly._flying = false
		fly._orbiting = false
		fly._highlight_id = ""
		fly._place_ship_at_path(fly._play_u)
		fly._place_bodies_at(fly._clock)
		fly._update_markers()
		await process_frame
		await _shot(dir + "/30_fly_u%03d.png" % u_i)
	# Orbit entry is baked into the timeline's final frame — jump to it.
	fly._enter_orbit()
	await _shot(dir + "/30_fly_entered_orbit.png")
	for ang_i in 4:
		fly._orbit_ang = float(ang_i) * 0.7
		fly._place_orbit_cam()
		fly._update_markers()
		for i in 4:
			await process_frame
		await _shot(dir + "/40_orbit_%02d.png" % ang_i)
	fly.queue_free()
	bg.queue_free()
	await process_frame

	# Outer-hop plot zoom (Uranus).
	bg = Starfield.new()
	var board_u: PlotBoard = PlotBoard.new()
	root.add_child(bg)
	root.add_child(board_u)
	board_u.set_ship_at("earth")
	board_u.begin_plot("uranus")
	for i in 40:
		await process_frame
	await _shot(dir + "/22_plot_uranus_zoom.png")
	board_u.queue_free()
	bg.queue_free()

	print("DEBUG shots → ", abs_dir)
	quit()

func _shot(res_path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_root().get_texture().get_image()
	var path := ProjectSettings.globalize_path(res_path)
	img.save_png(path)
	print("wrote ", path)

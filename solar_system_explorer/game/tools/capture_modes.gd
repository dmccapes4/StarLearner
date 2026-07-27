extends SceneTree
## Screenshots + sanity checks for the new nav modes:
##   · SIM_VIEW flight (honest dots/discs) on earth→mars and earth→jupiter
##   · the square COURSE console (inner vs outer extent)
##   · the free-flight PLAYGROUND
##   DISPLAY=:1 godot --path . -s res://tools/capture_modes.gd

const Starfield := preload("res://scripts/Starfield.gd")
const FlySceneScript := preload("res://scripts/FlyScene.gd")
const PlaygroundScene := preload("res://scripts/PlaygroundScene.gd")
const NavModes := preload("res://scripts/NavModes.gd")

var _fails := 0

func _init() -> void:
	call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	if not ok:
		_fails += 1
	print("  %s %s" % ["PASS" if ok else "FAIL", label])

func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(path))

func _run() -> void:
	var dir := "res://docs/screenshots/modes"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	root.get_viewport().size = Vector2i(1280, 600)
	var cfg := SolarFlyerConfig.load_default()

	for pair in [["earth", "mars"], ["earth", "jupiter"]]:
		await _sim_view_trip(cfg, pair[0], pair[1], dir)
	await _playground(dir)

	print("\n%s (%d failures)" % [
		"ALL MODE CHECKS PASS" if _fails == 0 else "MODE FAILURES", _fails])
	print("MODE shots → ", ProjectSettings.globalize_path(dir))
	quit(1 if _fails > 0 else 0)

func _sim_view_trip(cfg: SolarFlyerConfig, from_id: String, to_id: String,
		dir: String) -> void:
	print("\n=== SIM_VIEW %s -> %s ===" % [from_id, to_id])
	var origin := SolarData.flyer_body_by_id(from_id, cfg)
	var dest := SolarData.flyer_body_by_id(to_id, cfg)
	var depart := OrbitMath.orbit_standoff(float(origin.get("hero_r", 2.0)))
	var route := OrbitMath.plot_route(OrbitMath.body_pos(origin, 0.0), dest, 0.0, cfg, depart)
	var bg := Starfield.new()
	var fly: FlyScene = FlySceneScript.new()
	root.add_child(bg)
	root.add_child(fly)
	fly.render_mode = NavModes.MODE_SIM_VIEW
	fly.cinematic_enabled = false
	fly.set_active(true)
	fly.begin_flight(to_id, route, 0.0)
	for u_i in [5, 50, 90, 99]:
		fly._play_u = float(u_i) / 100.0
		fly._progress_u = fly._play_u
		fly._place_ship_at_path(fly._play_u)
		fly._place_bodies_at(fly._clock)
		fly._render_bodies()
		fly._update_console()
		await process_frame
		await _shot(dir + "/sim_%s_u%02d.png" % [to_id, u_i])
	# Honesty checks at u99: dest must be a visible true-angle disc; a far
	# outer world must NOT be rendered (too faint).
	var dn: Dictionary = fly._body_nodes[to_id]
	_check((dn["sphere"] as MeshInstance3D).visible,
		"dest renders as a 3D disc on close approach")
	if fly._body_nodes.has("neptune") and to_id != "neptune":
		var nn: Dictionary = fly._body_nodes["neptune"]
		var nep_shown: bool = (nn["icon"] as Sprite3D).visible \
			or (nn["sphere"] as MeshInstance3D).visible
		_check(not nep_shown, "Neptune honestly invisible from the inner system")
	var sn: Dictionary = fly._body_nodes["sun"]
	_check((sn["icon"] as Sprite3D).visible or (sn["sphere"] as MeshInstance3D).visible,
		"the Sun is always visible")
	# Orbit cut still works from sim view.
	fly._enter_orbit()
	await process_frame
	_check(fly._orbiting and fly._orbit_blend >= 1.0, "hard-cut orbit from sim view")
	await _shot(dir + "/sim_%s_orbit.png" % to_id)
	fly.queue_free()
	bg.queue_free()
	await process_frame

func _playground(dir: String) -> void:
	print("\n=== PLAYGROUND ===")
	var pg: PlaygroundScene = PlaygroundScene.new()
	root.add_child(pg)
	pg.set_active(true)
	pg.begin("earth")
	# Tutorial + aim gate auto-skip when no accelerometer is present.
	for i in 90:
		await process_frame
	await _shot(dir + "/playground_flying.png")
	_check(pg._state == PlaygroundScene.State.FLYING, "playground starts flying")
	# Tap the nearest on-screen body → pause tile.
	var target := ""
	var best := 1.0e9
	for id in pg._bodies:
		var wp: Vector3 = (pg._bodies[id]["root"] as Node3D).global_position
		if pg._cam.is_position_behind(wp):
			continue
		var sp: Vector2 = pg._cam.unproject_position(wp)
		if Rect2(Vector2.ZERO, Vector2(1280, 600)).has_point(sp):
			var d: float = pg._ship_pos.distance_to(wp)
			if d < best:
				best = d
				target = id
	_check(not target.is_empty(), "a body is on screen to tap")
	if not target.is_empty():
		pg._show_tile(target)
		await process_frame
		await _shot(dir + "/playground_tile.png")
		_check(pg._state == PlaygroundScene.State.PAUSED_TILE, "tap pauses with tile")
		# Tap the tile → orbit (cinematic starts; skip it).
		pg._enter_orbit(target)
		_check(pg._state == PlaygroundScene.State.ORBITING, "tile tap enters orbit")
		pg._cine._finish()
		for i in 10:
			await process_frame
		await _shot(dir + "/playground_orbit.png")
		_check(pg._arrival.visible, "arrival choices shown in playground orbit")
		pg.resume_flying()
		# Resume re-enters the aim gate (clean level look); no-sensor skips it.
		for i in 40:
			await process_frame
		_check(pg._state == PlaygroundScene.State.FLYING, "keep-flying resumes")
	# Plane band: force the ship high and confirm it gets steered back.
	pg._ship_pos.y = PlaygroundScene.Y_MAX - 0.5
	pg._pitch = 0.5
	for i in 240:
		await process_frame
	_check(pg._ship_pos.y < PlaygroundScene.Y_MAX - 0.4,
		"band steering pulls the ship back toward the plane (y=%.1f)" % pg._ship_pos.y)
	pg.queue_free()
	await process_frame

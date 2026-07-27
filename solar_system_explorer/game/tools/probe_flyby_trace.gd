extends SceneTree
## Fly-by diagnosis probe — plays the earth→neptune (and earth→uranus) hop the
## way the USER sees it (_flying = true, real playback pacing) and traces every
## non-destination body whose fly-by MESH becomes visible: how close the camera
## gets relative to the mesh radius (ratio < 1 means the camera is INSIDE the
## planet — the "flew through Earth and Mars" bug). Screenshots the worst frame
## per body.
##   DISPLAY=:1 godot --path . -s res://tools/probe_flyby_trace.gd

const Starfield := preload("res://scripts/Starfield.gd")
const FlyScene := preload("res://scripts/FlyScene.gd")

const TRIPS := [
	{"from": "earth", "to": "neptune"},
	{"from": "earth", "to": "uranus"},
]

var _fails := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var dir := "res://docs/screenshots/flyby_trace"
	var abs_dir := ProjectSettings.globalize_path(dir)
	DirAccess.make_dir_recursive_absolute(abs_dir)
	var cfg := SolarFlyerConfig.load_default()

	for trip in TRIPS:
		var from_id: String = trip["from"]
		var to_id: String = trip["to"]
		var tag := "%s_to_%s" % [from_id, to_id]
		print("\n=== FLY-BY TRACE %s ===" % tag)
		var origin := SolarData.flyer_body_by_id(from_id, cfg)
		var dest := SolarData.flyer_body_by_id(to_id, cfg)
		var prefer := OrbitMath.body_pos(dest, 0.0)
		var ship_pos := OrbitMath.park_pos(origin, 0.0, cfg, prefer)
		var standoff := OrbitMath.orbit_standoff(float(origin.get("hero_r", 2.0)))
		var route := OrbitMath.plot_route(ship_pos, dest, 0.0, cfg, standoff)

		var bg := Starfield.new()
		var fly: FlyScene = FlyScene.new()
		root.add_child(bg)
		root.add_child(fly)
		fly.cinematic_enabled = false
		fly.set_active(true)
		fly.begin_flight(to_id, route, 0.0)

		# worst-case tracker per body: [min dist/scale ratio, u at worst]
		var worst: Dictionary = {}
		var seen: Dictionary = {}
		# Step playback exactly like _process does, at a fixed 30 fps delta.
		var delta := 1.0 / 30.0
		var guard := 0
		while fly._play_u < 1.0 and guard < 6000:
			guard += 1
			fly._play_u = minf(1.0, fly._play_u + delta
				* OrbitMath.flight_play_rate(fly._play_u, fly._duration) / fly._duration)
			fly._progress_u = fly._play_u
			fly._place_ship_at_path(fly._play_u)
			fly._place_bodies_at(fly._clock)
			fly._update_markers()
			var cam_pos: Vector3 = fly._cam.global_position
			for id in fly._body_nodes:
				if id == to_id:
					continue
				var mesh: MeshInstance3D = fly._body_nodes[id]["sphere"]
				if not mesh.visible:
					continue
				var d: float = cam_pos.distance_to(
					(fly._body_nodes[id]["root"] as Node3D).global_position)
				var ratio: float = d / maxf(mesh.scale.x, 0.001)
				if not seen.has(id):
					seen[id] = fly._play_u
					print("  mesh ON  %-10s u=%.3f dist=%.1f scale=%.2f ratio=%.2f" % [
						id, fly._play_u, d, mesh.scale.x, ratio])
				if not worst.has(id) or ratio < float(worst[id][0]):
					worst[id] = [ratio, fly._play_u]
		print("  playback done, u=%.3f (frames=%d)" % [fly._play_u, guard])
		for id in worst:
			var ratio: float = float(worst[id][0])
			var at_u: float = float(worst[id][1])
			print("  WORST %-10s ratio=%.2f at u=%.3f %s" % [
				id, ratio, at_u, "<<< CAMERA INSIDE MESH" if ratio < 1.0 else ""])
			# Screenshot the worst frame so the weirdness is visible.
			fly._play_u = at_u
			fly._progress_u = at_u
			fly._flying = true
			fly._place_ship_at_path(at_u)
			fly._place_bodies_at(fly._clock)
			fly._update_markers()
			await process_frame
			await _shot(dir + "/%s_%s_worst.png" % [tag, id])
			_check(ratio >= 1.6,
				"%s: camera keeps clear margin from %s fly-by mesh (ratio %.2f)" % [
					tag, id, ratio])
		fly.queue_free()
		bg.queue_free()
		await process_frame

	print("\nFLY-BY trace shots → ", abs_dir)
	quit(0 if _fails == 0 else 1)

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  OK   ", msg)
	else:
		_fails += 1
		print("  FAIL ", msg)

func _shot(res_path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_root().get_texture().get_image()
	var path := ProjectSettings.globalize_path(res_path)
	img.save_png(path)
	print("  wrote ", path)

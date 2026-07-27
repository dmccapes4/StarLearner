extends SceneTree
## Dev probe: approach stays on the sim path; orbit is a hard cut with the
## planet looming. No course-continuation blend, no sharp turn-away path.
##   DISPLAY=:1 godot --path game -s res://tools/probe_orbit_entry.gd

const Starfield := preload("res://scripts/Starfield.gd")
const FlySceneScript := preload("res://scripts/FlyScene.gd")

var _fails: int = 0

func _init() -> void:
	call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	if not ok:
		_fails += 1
	print("  %s %s" % ["PASS" if ok else "FAIL", label])

func _run() -> void:
	root.get_viewport().size = Vector2i(1280, 600)
	var cfg := SolarFlyerConfig.load_default()
	var trips := [["earth", "mars"], ["earth", "jupiter"], ["earth", "ceres"],
		["mars", "venus"]]
	for pair in trips:
		for jump in [false, true]:
			await _fly_arrival(cfg, pair[0], pair[1], jump)
	print("\n%s (%d failures)" % ["ALL SEAM CHECKS PASS" if _fails == 0 else "SEAM FAILURES", _fails])
	quit(1 if _fails > 0 else 0)

func _fly_arrival(cfg: SolarFlyerConfig, from_id: String, to_id: String,
		jump: bool) -> void:
	var origin := SolarData.flyer_body_by_id(from_id, cfg)
	var dest := SolarData.flyer_body_by_id(to_id, cfg)
	var ship_pos := OrbitMath.body_pos(origin, 0.0)
	var depart := OrbitMath.orbit_standoff(float(origin.get("hero_r", 2.0)))
	var route := OrbitMath.plot_route(ship_pos, dest, 0.0, cfg, depart)
	var standoff := OrbitMath.sun_approach_standoff(cfg) \
		if bool(dest.get("is_star", false)) \
		else OrbitMath.orbit_standoff(float(dest.get("hero_r", 2.0)))

	var bg := Starfield.new()
	var fly: FlyScene = FlySceneScript.new()
	root.add_child(bg)
	root.add_child(fly)
	fly.cinematic_enabled = false   # probe measures the orbit cut directly
	fly.set_active(true)
	fly.begin_flight(to_id, route, 0.0)
	var dur: float = float(route["duration"])
	print("\n=== %s -> %s %s  (dur %.1fs, park standoff %.1f) ===" % [
		from_id, to_id, "JUMP" if jump else "smooth", dur, standoff])

	# Late approach on the sim path — dest marker must outgrow peers.
	fly._play_u = 0.70 if jump else 0.90
	fly._progress_u = fly._play_u
	fly._place_ship_at_path(fly._play_u)
	fly._update_markers()
	await process_frame
	await process_frame
	if jump:
		fly._play_u = 0.97
		fly._progress_u = fly._play_u
		fly._place_ship_at_path(fly._play_u)
		fly._update_markers()
		await process_frame
	if fly._body_nodes.has(to_id) and fly._play_u >= FlyScene.APPROACH_GROW_U:
		# Compare SCREEN size (world_size / dist), not Sprite3D.pixel_size —
		# pixel_size scales with distance to keep peers constant on glass.
		var cam_pos: Vector3 = fly._cam.global_position
		var dest_root: Node3D = fly._body_nodes[to_id]["root"]
		var dest_d: float = maxf(cam_pos.distance_to(dest_root.global_position), 0.001)
		var dest_w: float = (fly._body_nodes[to_id]["icon"] as Sprite3D).pixel_size \
			* float(FlyScene.ICON_TEX_PX)
		var dest_screen: float = dest_w / dest_d
		var peer_max := 0.0
		for oid in fly._body_nodes:
			if oid == to_id:
				continue
			var pr: Node3D = fly._body_nodes[oid]["root"]
			var pd: float = maxf(cam_pos.distance_to(pr.global_position), 0.001)
			# Measure whichever representation is actually shown: marker
			# icon width, or fly-by mesh diameter.
			var picon: Sprite3D = fly._body_nodes[oid]["icon"]
			var pmesh: MeshInstance3D = fly._body_nodes[oid]["sphere"]
			var pw: float = 0.0
			if pmesh.visible:
				pw = pmesh.scale.x * 2.0
			elif picon.visible:
				pw = picon.pixel_size * float(FlyScene.ICON_TEX_PX)
			peer_max = maxf(peer_max, pw / pd)
		_check(dest_screen > peer_max * 1.05,
			"approach dest larger on screen (%.4f vs %.4f)" % [dest_screen, peer_max])

	# Cruise heading should still face travel (no look-at-planet turn-away).
	var travel: Vector3 = Vector3.ZERO
	if fly._tl_fwd.size() > 0:
		var fi: int = mini(int(fly._flight_t / maxf(fly._tl_dt, 0.001)),
			fly._tl_fwd.size() - 1)
		travel = fly._tl_fwd[fi]
	var cam_fwd: Vector3 = -fly._cam.global_transform.basis.z
	if travel.length() > 0.001:
		_check(cam_fwd.angle_to(travel.normalized()) < deg_to_rad(12.0),
			"approach still faces travel (%.1f°)" % rad_to_deg(
				cam_fwd.angle_to(travel.normalized())))

	# Hard cut to orbit — planet looms at park radius.
	fly._play_u = 1.0
	fly._progress_u = 1.0
	fly._place_ship_at_path(1.0)
	await process_frame
	fly._enter_orbit_from_timeline()
	await process_frame
	_check(fly._orbiting and fly._orbit_blend >= 1.0, "hard-cut orbit")
	var center := OrbitMath.body_pos(dest, fly._clock)
	var d: float = fly._cam.global_position.distance_to(center)
	# Orbit camera sits on park radius with a small height lift (~2–3%).
	_check(d > standoff * 0.95 and d < standoff * 1.08 + 0.5,
		"orbit cut at parking (d=%.1f vs %.1f)" % [d, standoff])
	if fly._body_nodes.has(to_id):
		var mesh: MeshInstance3D = fly._body_nodes[to_id]["sphere"]
		var hero: float = float(dest.get("hero_r", 1.0))
		_check(mesh.visible and absf(mesh.scale.x - hero) < hero * 0.05,
			"destination mesh looming at hero size")

	# Free orbit should not spiral out.
	var d0: float = d
	for _i in 90:
		await process_frame
	var d1: float = fly._cam.global_position.distance_to(
		OrbitMath.body_pos(dest, fly._clock))
	_check(absf(d1 - d0) < standoff * 0.08 + 0.5,
		"orbit radius stable (%.1f → %.1f)" % [d0, d1])

	fly.queue_free()
	bg.queue_free()
	await process_frame

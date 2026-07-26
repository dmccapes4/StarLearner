extends SceneTree
## Dev probe: verify the orbit-entry seam has no "collision course → recoil".
## Measures camera motion RELATIVE to the destination planet through entry.
## Two scenarios per trip:
##   smooth — plain real-time arrival (~last 10% flown frame by frame)
##   jump   — one huge _flight_t jump right before arrival (boost tap /
##            frame hitch stand-in) that used to overshoot inside standoff
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
	fly.set_active(true)
	fly.begin_flight(to_id, route, 0.0)
	var dur: float = float(route["duration"])
	print("\n=== %s -> %s %s  (dur %.1fs, park standoff %.1f) ===" % [
		from_id, to_id, "JUMP" if jump else "smooth", dur, standoff])

	# Approach: run real frames from 90% of the hop; in jump mode, first let
	# a couple frames process at ~70% so _prev_u is a sane pre-jump sample,
	# then slam _flight_t forward (worst-case boost tap / frame hitch).
	fly._flight_t = dur * (0.70 if jump else 0.90)
	await process_frame
	await process_frame
	if jump:
		fly._flight_t = dur * 0.999
	var d_entry: float = -1.0
	var d_min: float = INF
	var d_max_blend: float = -1.0
	var max_out_rate: float = 0.0   # planet-relative outward speed, u/s
	var max_turn: float = 0.0       # camera heading change per frame, deg
	var seam_frame := -1
	var prev_d: float = -1.0
	var prev_fwd := Vector3.ZERO
	var frames := 0
	while frames < 2400:
		await process_frame
		frames += 1
		var center := OrbitMath.body_pos(dest, fly._clock)
		var d: float = fly._cam.global_position.distance_to(center)
		var fwd: Vector3 = -fly._cam.global_transform.basis.z
		if fly._orbiting:
			if seam_frame < 0:
				seam_frame = frames
				d_entry = d
			d_min = minf(d_min, d)
			if fly._orbit_blend < 1.0:
				d_max_blend = maxf(d_max_blend, d)
				if prev_d > 0.0:
					# Positive = camera backing away from the planet.
					max_out_rate = maxf(max_out_rate, (d - prev_d) * 60.0)
				if prev_fwd.length() > 0.5:
					max_turn = maxf(max_turn, rad_to_deg(prev_fwd.angle_to(fwd)))
			else:
				break
		prev_d = d
		prev_fwd = fwd
	_check(seam_frame > 0, "entered orbit")
	if seam_frame > 0:
		print("  entry d=%.2f  blend d_max=%.2f d_min=%.2f  out_rate=%.2f u/s  turn=%.1f°/f" % [
			d_entry, d_max_blend, d_min, max_out_rate, max_turn])
		_check(d_entry > standoff * 0.90 and d_entry < standoff * 1.12,
			"entry at the parking radius (d=%.1f vs %.1f)" % [d_entry, standoff])
		# The gentle 0.22·r camera lift adds ~2.4% distance over the blend;
		# anything beyond that reads as the ship recoiling off the planet.
		_check(d_max_blend < standoff * 1.06 + 0.5,
			"no backwards recoil during blend (d_max=%.1f)" % d_max_blend)
		_check(max_out_rate < standoff * 0.05 + 1.0,
			"outward drift stays gentle (%.2f u/s)" % max_out_rate)
		_check(max_turn < 4.0, "camera heading continuous (%.1f°/frame)" % max_turn)
	fly.queue_free()
	bg.queue_free()
	await process_frame

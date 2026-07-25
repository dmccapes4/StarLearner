extends SceneTree
## Trip verification harness — flies several hops, printing the spoken narration
## next to the *measured* course geometry so claims can be checked line by line,
## and screenshots plot / departure / cruise / approach / orbit for each trip.
##   DISPLAY=:1 godot --path . -s res://tools/capture_trips.gd

const Starfield := preload("res://scripts/Starfield.gd")
const PlotBoard := preload("res://scripts/PlotBoard.gd")
const FlyScene := preload("res://scripts/FlyScene.gd")

const TRIPS := [
	{"from": "earth", "to": "jupiter"},
	{"from": "earth", "to": "mercury"},
	{"from": "earth", "to": "neptune"},
	{"from": "jupiter", "to": "mars"},   # crosses the belt — rock reveal shots
	{"from": "earth", "to": "asteroid_belt"},  # resolves to nearest asteroid
	{"from": "earth", "to": "saturn"},
]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var dir := "res://docs/screenshots/trips"
	var abs_dir := ProjectSettings.globalize_path(dir)
	DirAccess.make_dir_recursive_absolute(abs_dir)
	var cfg := SolarFlyerConfig.load_default()

	for trip in TRIPS:
		var from_id: String = trip["from"]
		var to_id: String = trip["to"]
		var tag := "%s_to_%s" % [from_id, to_id]
		var origin := SolarData.flyer_body_by_id(from_id, cfg)
		# The belt is never flown to directly — the tap resolves to the nearest
		# major asteroid, exactly as PlotBoard does (STRATEGY §5.3).
		if to_id == "asteroid_belt":
			to_id = SolarData.nearest_major_asteroid(
				OrbitMath.body_pos(origin, 0.0), 0.0, cfg, from_id)
			print("\nBELT TAP resolved to: ", to_id)
			_check(not to_id.is_empty(), "belt tap resolves to a major asteroid")
			var res_body := SolarData.flyer_body_by_id(to_id, cfg)
			_check(bool(res_body.get("major_asteroid", false)),
				"resolved body is a major asteroid")
			print("  belt intro: ", OrbitMath.belt_intro_sentence(res_body))
		var dest := SolarData.flyer_body_by_id(to_id, cfg)
		var ship_pos := OrbitMath.body_pos(origin, 0.0)
		var standoff := OrbitMath.orbit_standoff(float(origin.get("hero_r", 2.0)))
		var route := OrbitMath.plot_route(ship_pos, dest, 0.0, cfg, standoff,
			OrbitMath.sweep_bodies_for(from_id, to_id, cfg))
		route["travel_au"] = absf(float(dest.get("a_au", 0.0)) - float(origin.get("a_au", 0.0)))
		var narr := OrbitMath.trip_narration(origin, dest, route, cfg)

		# ── Geometry vs narration report ──
		print("\n=== TRIP %s → %s ===" % [from_id, to_id])
		print("  narration: ", narr)
		var min_sun: float = float(route["min_sun_dist"])
		var r0: float = float(origin.get("orbit_r", 0.0))
		var r1: float = float(dest.get("orbit_r", 0.0))
		print("  min_sun_dist=%.1f  origin_r=%.1f  dest_r=%.1f" % [min_sun, r0, r1])
		var claims_flyby: bool = narr.find("close to the Sun") >= 0
		if claims_flyby:
			_check(min_sun < minf(r0, r1) * 0.55, "sun-flyby claim matches geometry")
		else:
			_check(min_sun >= minf(r0, r1) * 0.55, "no flyby claimed and course stays wide")
			_check(not (r1 > r0 + 0.5) or narr.find("away from the Sun") >= 0,
				"outward hop narrated as outward")
			_check(not (r1 < r0 - 0.5) or narr.find("toward the Sun") >= 0,
				"inward hop narrated as inward")
		for b in OrbitMath.bodies_along_hop(origin, dest, cfg).slice(0, 2):
			_check(narr.find(str(b["name"])) >= 0,
				"crossed orbit of %s is mentioned" % b["name"])
		var start_p: Vector3 = OrbitMath.path_sample(route["curve"], 0.0)
		var launch_gap := start_p.distance_to(ship_pos)
		# Trim is capped at 30% of the hop span so short hops keep a real cruise.
		var span := ship_pos.distance_to(route["arrival_pos"])
		var want_trim := minf(standoff, span * 0.3)
		print("  launch gap from %s center: %.1f (want %.1f, standoff %.1f)" % [
			from_id, launch_gap, want_trim, standoff])
		_check(launch_gap >= want_trim * 0.9, "launch clears origin planet")

		# ── Sweep / slingshot honesty ──
		var conflicts := 0
		for s in route.get("sweeps", []):
			if str(s["class"]) == "conflict":
				conflicts += 1
				print("  CONFLICT %s sep=%.1f clear=%.1f" % [
					s["id"], float(s["min_sep"]), float(s["clearance"])])
		_check(conflicts == 0, "refined course clears every world")
		var sling: Dictionary = route.get("slingshot", {})
		if not sling.is_empty():
			print("  slingshot: %s (CPA sep %.1f)" % [
				sling["id"], float(sling.get("min_sep", -1.0))])
			_check(narr.find("slingshot") >= 0, "slingshot narrated when charted")
		else:
			_check(narr.find("slingshot") < 0, "no slingshot claim without one")
		for d in route.get("deflections", []):
			print("  deflection: steer wide of %s (mag %.1f)" % [d["id"], float(d["mag"])])

		# ── Plot board shot ──
		var bg := Starfield.new()
		var board: PlotBoard = PlotBoard.new()
		root.add_child(bg)
		root.add_child(board)
		board.set_ship_at(from_id)
		board.begin_plot(str(trip["to"]))  # original tap — board resolves belt itself
		for i in 100:
			await process_frame
		await _shot(dir + "/%s_0_plot.png" % tag)
		board.queue_free()
		bg.queue_free()
		await process_frame

		# ── Flight frames ──
		bg = Starfield.new()
		var fly: FlyScene = FlyScene.new()
		root.add_child(bg)
		root.add_child(fly)
		fly.set_active(true)
		fly.begin_flight(to_id, route, 0.0)
		var curve: Curve3D = route["curve"]
		var clen: float = maxf(curve.get_baked_length(), 0.001)
		# Find the deepest belt approach so we can screenshot the rock reveal —
		# the part the harness must prove is still cool. The callout is only
		# demanded when the path dives well inside the field (frame-time slop
		# means grazing passes may or may not land a frame in the band).
		var belt_r: float = float(SolarData.flyer_body_by_id("asteroid_belt", cfg)["orbit_r"])
		var u_belt: int = -1
		var d_belt_min: float = INF
		for ui in range(1, 100):
			var prog := OrbitMath.route_progress(float(ui) / 100.0, route, cfg)
			var p := curve.sample_baked(prog * clen)
			var rd: float = absf(Vector2(p.x, p.z).length() - belt_r)
			var d := sqrt(rd * rd + p.y * p.y)
			if d < d_belt_min:
				d_belt_min = d
				u_belt = ui
		var demand_callout: bool = d_belt_min < cfg.belt_fade_near * 0.8 - 4.0
		var samples: Array = [0, 3, 15, 40, 70, 90, 97]
		if demand_callout and not samples.has(u_belt):
			samples.append(u_belt)
			samples.sort()
		for u_i in samples:
			fly._flight_t = float(route["duration"]) * (float(u_i) / 100.0)
			fly._flying = true
			fly._orbiting = false
			await process_frame
			# Camera contract: forward == path tangent, every sampled frame.
			if not fly._orbiting and u_i >= 3 and u_i <= 90:
				var s0: float = fly._progress_u * clen
				var p0: Vector3 = curve.sample_baked(s0)
				var p1: Vector3 = curve.sample_baked(minf(s0 + 0.8, clen))
				if p1.distance_to(p0) > 0.05:
					var tang: Vector3 = (p1 - p0).normalized()
					var fwd: Vector3 = -fly._cam.global_transform.basis.z
					_check(fwd.angle_to(tang) < deg_to_rad(6.0),
						"camera faces travel direction at u%02d (off %.1f°)" % [
							u_i, rad_to_deg(fwd.angle_to(tang))])
			# Belt cull contract with hysteresis: frame-delta slop moves the
			# camera a few units past the sampled fraction, so only assert
			# clearly-inside / clearly-outside cases.
			if fly._belt_mm != null and not fly._orbiting:
				var cp: Vector3 = fly._cam.global_position
				var crd: float = absf(Vector2(cp.x, cp.z).length() - belt_r)
				var cd: float = sqrt(crd * crd + cp.y * cp.y)
				if cd < cfg.belt_cull_dist - 12.0:
					_check(fly._belt_mm.visible, "belt rocks on near ring at u%02d (d=%.0f)" % [u_i, cd])
				elif cd > cfg.belt_cull_dist + 12.0:
					_check(not fly._belt_mm.visible, "belt rocks culled far from ring at u%02d (d=%.0f)" % [u_i, cd])
			if u_i == u_belt and demand_callout:
				await _shot(dir + "/%s_1_belt_u%03d.png" % [tag, u_i])
			await _shot(dir + "/%s_1_fly_u%03d.png" % [tag, u_i])
			if fly._orbiting:
				break
		if demand_callout:
			_check(fly._belt_called,
				"belt crossing fired callout (deepest d=%.0f)" % d_belt_min)
		if not fly._orbiting:
			fly._try_enter_orbit_from_approach(true)
		# Entry seam contract (STRATEGY §4): the camera heading never jumps —
		# < 4°/frame through the whole entry blend.
		var prev_fwd: Vector3 = -fly._cam.global_transform.basis.z
		var worst_step := 0.0
		for i in 90:
			await process_frame
			var now_fwd: Vector3 = -fly._cam.global_transform.basis.z
			worst_step = maxf(worst_step, rad_to_deg(prev_fwd.angle_to(now_fwd)))
			prev_fwd = now_fwd
		_check(worst_step < 4.0,
			"orbit entry heading continuous (worst %.1f°/frame)" % worst_step)
		await _shot(dir + "/%s_2_orbit.png" % tag)
		# A second orbit shot half a lap later — the abeam framing + icons.
		for i in 120:
			await process_frame
		await _shot(dir + "/%s_3_orbit_later.png" % tag)
		fly.queue_free()
		bg.queue_free()
		await process_frame

	print("\nTRIP shots → ", abs_dir)
	quit(0 if _fails == 0 else 1)

var _fails := 0

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

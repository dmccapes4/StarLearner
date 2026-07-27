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
		# Plot EXACTLY like PlotBoard: park_pos departure aimed at the target.
		var prefer := OrbitMath.body_pos(dest, 0.0)
		if prefer.length() < 0.001:
			prefer = Vector3.RIGHT
		var ship_pos := OrbitMath.park_pos(origin, 0.0, cfg, prefer)
		var standoff := 0.0
		if not bool(origin.get("is_star", false)):
			standoff = OrbitMath.orbit_standoff(float(origin.get("hero_r", 2.0)))
		var route := OrbitMath.plot_route(ship_pos, dest, 0.0, cfg, standoff)
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
		# Trim is capped at 30% of the COURSE span (launch point → parking-
		# sphere entry, i.e. the curve's own endpoints) so short hops keep a
		# real cruise — measuring to the planet CENTER overstates the span.
		var span := ship_pos.distance_to(OrbitMath.path_sample(route["curve"], 1.0))
		var want_trim := minf(standoff, span * 0.3)
		print("  launch gap from %s center: %.1f (want %.1f, standoff %.1f)" % [
			from_id, launch_gap, want_trim, standoff])
		_check(launch_gap >= want_trim * 0.9, "launch clears origin planet")

		# ── Simulation honesty: worlds are points, space is empty — nothing
		# is dodged, nothing is detected, nothing is called out mid-cruise.
		_check(narr.find("slingshot") < 0 and narr.find("steer wide") < 0
			and narr.find("launch window") < 0
			and narr.find("fly right past") < 0, "narration invents no maneuvers")
		var tl0: Dictionary = route["timeline"]
		for ev0 in (tl0["events"] as Array):
			_check(str(ev0["kind"]) == "phase",
				"timeline carries only burn-phase events (got %s)" % ev0["kind"])

		# ── Plot board shot — AFTER the chart animation finishes drawing.
		# (Screenshotting mid-draw was what made charted courses look
		# truncated in earlier clip reviews.)
		var bg := Starfield.new()
		var board: PlotBoard = PlotBoard.new()
		root.add_child(bg)
		root.add_child(board)
		board.set_ship_at(from_id)
		board.begin_plot(str(trip["to"]))  # original tap — board resolves belt itself
		var wait_frames := 0
		while board._phase == PlotBoard.Phase.CHART and wait_frames < 1200:
			await process_frame
			wait_frames += 1
		_check(board._phase != PlotBoard.Phase.CHART, "chart animation completed")
		for i in 20:
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
		fly.cinematic_enabled = false   # harness inspects the orbit view directly
		fly.set_active(true)
		fly.begin_flight(to_id, route, 0.0)
		var curve: Curve3D = route["curve"]
		var clen: float = maxf(curve.get_baked_length(), 0.001)
		# For a rocks-out-the-window screenshot, find where the SIMULATED path
		# passes nearest the belt ring (pure scenery — no alarm, no event).
		var belt_r: float = float(SolarData.flyer_body_by_id("asteroid_belt", cfg)["orbit_r"])
		var tl: Dictionary = route["timeline"]
		var dur_total: float = maxf(float(route["duration"]), 0.001)
		var tl_pos0: PackedVector3Array = tl["pos"]
		var u_belt: int = -1
		var best_ring := INF
		for i in tl_pos0.size():
			var rd: float = OrbitMath.belt_band_dist(tl_pos0[i], belt_r)
			if rd < best_ring:
				best_ring = rd
				u_belt = clampi(int(float(i) * float(tl["dt"]) / dur_total * 100.0), 1, 99)
		var want_belt_shot: bool = best_ring < cfg.belt_fade_near
		# Rock encounter contract: rocks exist only on ring-crossing flights,
		# freshly scattered around the path and never ON it.
		var n_rocks: int = 0
		if fly._belt_mm != null:
			n_rocks = fly._belt_mm.multimesh.instance_count
		if best_ring < OrbitMath.BELT_CORRIDOR:
			_check(n_rocks > 0, "rock encounter spawned on a ring crossing")
			var min_clear := INF
			for ri in n_rocks:
				var ro: Vector3 = fly._belt_mm.multimesh \
					.get_instance_transform(ri).origin
				for pi in range(0, tl_pos0.size(), 3):
					min_clear = minf(min_clear, ro.distance_to(tl_pos0[pi]))
			_check(min_clear >= 3.0,
				"every rock clear of the flown path (min %.1f)" % min_clear)
		else:
			_check(n_rocks == 0, "no rocks spawned away from the ring")
		var samples: Array = [0, 3, 15, 40, 70, 90, 97]
		if want_belt_shot and not samples.has(u_belt):
			samples.append(u_belt)
			samples.sort()
		for u_i in samples:
			# Seek by PATH fraction and pose without advancing the clock.
			fly._play_u = float(u_i) / 100.0
			fly._progress_u = fly._play_u
			fly._flying = false
			fly._orbiting = false
			fly._place_ship_at_path(fly._play_u)
			fly._place_bodies_at(fly._clock)
			fly._update_markers()
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
			# Marker contract: in flight every world is an icon marker — no
			# meshes — and the destination marker never reads LARGE on screen.
			if not fly._orbiting and fly._body_nodes.has(to_id):
				var dn: Dictionary = fly._body_nodes[to_id]
				_check(not (dn["sphere"] as MeshInstance3D).visible,
					"destination stays a marker mid-flight at u%02d" % u_i)
				var ic: Sprite3D = dn["icon"]
				_check(not ic.shaded, "marker Sprite3D is unshaded at u%02d" % u_i)
				var dd: float = fly._cam.global_position.distance_to(
					(dn["root"] as Node3D).global_position)
				var scr_px: float = ic.pixel_size * FlyScene.ICON_TEX_PX \
					/ (2.0 * maxf(dd, 0.01) * tan(deg_to_rad(65.0 * 0.5))) * 600.0
				_check(scr_px < 55.0,
					"destination marker stays a small marker at u%02d (%.0f px)" % [u_i, scr_px])
			if u_i == u_belt and want_belt_shot:
				await _shot(dir + "/%s_1_belt_u%03d.png" % [tag, u_i])
			await _shot(dir + "/%s_1_fly_u%03d.png" % [tag, u_i])
			if fly._orbiting:
				break
		# Late approach still on the sim path: dest marker should already
		# read bigger than peers before the hard orbit cut.
		if not fly._orbiting:
			fly._play_u = 0.97
			fly._progress_u = fly._play_u
			fly._flying = true
			fly._place_ship_at_path(fly._play_u)
			fly._update_markers()
			await process_frame
			await _shot(dir + "/%s_2_approach.png" % tag)
			if fly._body_nodes.has(to_id):
				# Screen size = world_size / dist (pixel_size alone tracks distance).
				var cam_pos: Vector3 = fly._cam.global_position
				var dest_root: Node3D = fly._body_nodes[to_id]["root"]
				var dest_d: float = maxf(cam_pos.distance_to(
					dest_root.global_position), 0.001)
				var dest_w: float = (fly._body_nodes[to_id]["icon"] as Sprite3D) \
					.pixel_size * float(FlyScene.ICON_TEX_PX)
				var dest_screen: float = dest_w / dest_d
				var peer_max := 0.0
				for oid in fly._body_nodes:
					if oid == to_id:
						continue
					var pr: Node3D = fly._body_nodes[oid]["root"]
					var pd: float = maxf(cam_pos.distance_to(pr.global_position), 0.001)
					# Whichever representation is shown: marker icon width
					# or fly-by mesh diameter.
					var picon: Sprite3D = fly._body_nodes[oid]["icon"]
					var pmesh: MeshInstance3D = fly._body_nodes[oid]["sphere"]
					var pw: float = 0.0
					if pmesh.visible:
						pw = pmesh.scale.x * 2.0
					elif picon.visible:
						pw = picon.pixel_size * float(FlyScene.ICON_TEX_PX)
					peer_max = maxf(peer_max, pw / pd)
				_check(dest_screen > peer_max * 1.05,
					"approach dest larger on screen (%.4f vs %.4f)" % [
						dest_screen, peer_max])
			fly._play_u = 1.0
			fly._progress_u = 1.0
			fly._place_ship_at_path(1.0)
			await process_frame
			fly._enter_orbit_from_timeline()
			await process_frame
		# Hard cut: blend is immediate; planet mesh looms at full hero.
		_check(fly._orbit_blend >= 1.0, "hard-cut orbit engaged")
		if fly._body_nodes.has(to_id):
			var dn2: Dictionary = fly._body_nodes[to_id]
			_check((dn2["sphere"] as MeshInstance3D).visible,
				"destination mesh shown in orbit")
			var hero2: float = float(dest.get("hero_r", 1.0))
			_check(absf((dn2["sphere"] as MeshInstance3D).scale.x - hero2) < hero2 * 0.05,
				"destination at full hero size in orbit")
			for oid in fly._body_nodes:
				if oid == to_id:
					continue
				if (fly._body_nodes[oid]["sphere"] as MeshInstance3D).visible:
					_check(false, "non-destination %s shows a mesh in orbit" % oid)
		var dstand: float = OrbitMath.sun_approach_standoff(cfg) \
			if bool(dest.get("is_star", false)) \
			else OrbitMath.orbit_standoff(float(dest.get("hero_r", 2.0)))
		_check(absf(fly._orbit_park - dstand) < 0.25,
			"orbit park radius (%.1f vs %.1f)" % [fly._orbit_park, dstand])
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

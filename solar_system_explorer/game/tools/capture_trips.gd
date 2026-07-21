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
	{"from": "jupiter", "to": "mars"},
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
		var dest := SolarData.flyer_body_by_id(to_id, cfg)
		var ship_pos := OrbitMath.body_pos(origin, 0.0)
		var standoff := OrbitMath.orbit_standoff(float(origin.get("hero_r", 2.0)))
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
		# Trim is capped at 30% of the hop span so short hops keep a real cruise.
		var span := ship_pos.distance_to(route["arrival_pos"])
		var want_trim := minf(standoff, span * 0.3)
		print("  launch gap from %s center: %.1f (want %.1f, standoff %.1f)" % [
			from_id, launch_gap, want_trim, standoff])
		_check(launch_gap >= want_trim * 0.9, "launch clears origin planet")

		# ── Plot board shot ──
		var bg := Starfield.new()
		var board: PlotBoard = PlotBoard.new()
		root.add_child(bg)
		root.add_child(board)
		board.set_ship_at(from_id)
		board.begin_plot(to_id)
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
		for u_i in [0, 3, 15, 40, 70, 90, 97]:
			fly._flight_t = float(route["duration"]) * (float(u_i) / 100.0)
			fly._flying = true
			fly._orbiting = false
			await process_frame
			await _shot(dir + "/%s_1_fly_u%03d.png" % [tag, u_i])
			if fly._orbiting:
				break
		if not fly._orbiting:
			fly._try_enter_orbit_from_approach(true)
		for i in 6:
			await process_frame
		await _shot(dir + "/%s_2_orbit.png" % tag)
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

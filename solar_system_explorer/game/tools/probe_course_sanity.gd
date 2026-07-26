extends SceneTree
## Headless course-sanity probe: plots routes EXACTLY the way PlotBoard does
## (park_pos departure, live t0) and grades each charted course on
##   - bends: signed-curvature direction changes (S-wiggles read as drunk).
##     A transfer arc keeps one curvature sign the whole way → at most 1 bend.
##   - turn: total heading change along the course (rad). An arc may sweep up
##     to ~π around the Sun, never more.
##   - end error: the course must END on the destination's parking sphere —
##     |dist(curve end, planet at arrival) − orbit standoff|
##   - ring error: |arrival_pos| vs the destination's orbit radius
##   godot --headless --path game -s res://tools/probe_course_sanity.gd

var _fails: int = 0

func _init() -> void:
	_run()
	quit(1 if _fails > 0 else 0)

func _check(ok: bool, label: String) -> void:
	if not ok:
		_fails += 1
		print("  FAIL %s" % label)

func _run() -> void:
	var cfg := SolarFlyerConfig.load_default()
	var dests: Array = []
	for b in SolarData.flyer_destinations(cfg):
		dests.append(str(b["id"]))
	var origins := ["earth", "mars", "jupiter", "ceres"]
	var worst_bends := 0
	var worst_tag := ""
	print("%-24s %5s %6s %7s %7s" % [
		"trip", "bends", "turn", "endErr", "ringErr"])
	for from_id in origins:
		for to_id in dests:
			if to_id == from_id:
				continue
			for t0 in [0.0, 11.0, 23.0, 37.0]:
				var m := _grade(cfg, from_id, to_id, float(t0))
				if m.is_empty():
					continue
				var tag := "%s->%s t=%.0f" % [from_id, to_id, t0]
				if int(m["bends"]) > worst_bends:
					worst_bends = int(m["bends"])
					worst_tag = tag
				var noisy: bool = int(m["bends"]) > 1 or float(m["end_err"]) > 1.0 \
					or float(m["ring_err"]) > 0.5
				if noisy or (from_id == "earth" and int(t0) == 0):
					print("%-24s %5d %6.2f %7.2f %7.2f" % [tag,
						m["bends"], m["turn"], m["end_err"], m["ring_err"]])
				_check(int(m["bends"]) <= 1,
					"%s: %d bends — a transfer arc never S-wiggles" % [tag, m["bends"]])
				_check(float(m["turn"]) < 3.4,
					"%s: %.2f rad total turn — course meanders" % [tag, m["turn"]])
				_check(float(m["end_err"]) < 1.0,
					"%s: course end misses the parking sphere by %.1f" % [tag, m["end_err"]])
				_check(float(m["ring_err"]) < 0.5,
					"%s: aim-here %.1f off the destination ring" % [tag, m["ring_err"]])
	print("\nworst bends: %d (%s)" % [worst_bends, worst_tag])
	print("%s (%d failures)" % ["ALL COURSE CHECKS PASS" if _fails == 0 else "COURSE FAILURES", _fails])

func _grade(cfg: SolarFlyerConfig, from_id: String, to_id: String, t0: float) -> Dictionary:
	var origin := SolarData.flyer_body_by_id(from_id, cfg)
	var target := SolarData.flyer_body_by_id(to_id, cfg)
	if origin.is_empty() or target.is_empty():
		return {}
	# Mirror PlotBoard._plot_to exactly.
	var prefer := OrbitMath.body_pos(target, t0)
	if prefer.length() < 0.001:
		prefer = Vector3.RIGHT
	var ship_pos := OrbitMath.park_pos(origin, t0, cfg, prefer)
	var depart := 0.0
	if not bool(origin.get("is_star", false)):
		depart = OrbitMath.orbit_standoff(float(origin.get("hero_r", 2.0)))
	var route := OrbitMath.plot_route(ship_pos, target, t0, cfg, depart)
	var curve: Curve3D = route["curve"]
	var clen: float = maxf(curve.get_baked_length(), 0.001)
	var dur: float = float(route["duration"])

	# Bends: signed curvature (XZ) direction changes with an amplitude gate,
	# so numeric noise doesn't count but real S-wiggles do.
	var n := 200
	var pts: Array = []
	for i in n + 1:
		pts.append(curve.sample_baked(float(i) / float(n) * clen))
	# Bend counting with sign HYSTERESIS: a curvature-direction segment only
	# closes when the opposite direction accumulates a meaningful turn
	# (> ~4°). Polyline joints flicker around zero curvature; without the
	# hysteresis one smooth arc reads as many "bends".
	var turn_total := 0.0
	var bends := 0
	var cur_sign := 0
	var seg_amp := 0.0
	var opp_amp := 0.0
	for i in range(1, n):
		var a: Vector3 = pts[i] - pts[i - 1]
		var b: Vector3 = pts[i + 1] - pts[i]
		if a.length() < 0.001 or b.length() < 0.001:
			continue
		var cross_y: float = a.x * b.z - a.z * b.x
		var ang: float = a.angle_to(b)
		turn_total += ang
		if absf(cross_y) < 1e-6:
			continue
		var s: int = 1 if cross_y > 0.0 else -1
		if cur_sign == 0:
			cur_sign = s
			seg_amp = ang
		elif s == cur_sign:
			seg_amp += ang
			opp_amp = 0.0
		else:
			opp_amp += ang
			if opp_amp > 0.07:
				if seg_amp > 0.07:
					bends += 1
				cur_sign = s
				seg_amp = opp_amp
				opp_amp = 0.0
	if seg_amp > 0.07:
		bends += 1

	var end_pos: Vector3 = pts[n]
	var planet_at_arr := OrbitMath.body_pos(target, t0 + dur)
	var star: bool = bool(target.get("is_star", false))
	var dest_stand := OrbitMath.sun_approach_standoff(cfg) if star \
		else OrbitMath.orbit_standoff(float(target.get("hero_r", 2.0)))
	var end_err: float = absf(end_pos.distance_to(Vector3.ZERO if star
		else planet_at_arr) - dest_stand)
	var ring_err: float = 0.0 if star else absf(
		Vector3(route["arrival_pos"]).length() - float(target.get("orbit_r", 0.0)))
	return {
		"bends": bends, "turn": turn_total, "end_err": end_err,
		"ring_err": ring_err,
	}

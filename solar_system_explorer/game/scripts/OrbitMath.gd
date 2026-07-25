class_name OrbitMath
extends RefCounted
## Headless orbital math for the 3D flyer (STRATEGY_3D_FLYER §3–4 / §16).
## No Node3D required — unit-tested from run_tests.gd.

## Compress real AU → game orbit radius (XZ plane, Sun at origin).
static func compress_orbit_r(a_au: float, cfg: SolarFlyerConfig) -> float:
	if a_au <= 0.0:
		return 0.0
	var t: float = clampf(a_au / maxf(cfg.a_max_au, 0.001), 0.0, 1.0)
	return cfg.distance_base + cfg.distance_span * pow(t, cfg.compression_exp)

## Hero sphere radius from size rank (0 = smallest, 1 = largest among planets).
static func hero_radius(rank01: float, cfg: SolarFlyerConfig) -> float:
	return lerpf(cfg.hero_min, cfg.hero_max, sqrt(clampf(rank01, 0.0, 1.0)))

static func omega_from_period_yr(period_yr: float, cfg: SolarFlyerConfig) -> float:
	if period_yr <= 0.0:
		return 0.0
	return TAU / (period_yr * cfg.game_year_seconds)

## Position on the ecliptic (XZ, Y-up) at absolute time t.
static func body_pos(b: Dictionary, t: float) -> Vector3:
	var r: float = float(b.get("orbit_r", 0.0))
	if r <= 0.0:
		return Vector3.ZERO
	var ang: float = float(b.get("theta0", 0.0)) + float(b.get("omega", 0.0)) * t
	return Vector3(cos(ang) * r, 0.0, sin(ang) * r)

## Fixed-point intercept: aim where the target *will be* on arrival.
static func solve_intercept(ship_pos: Vector3, target: Dictionary, t0: float,
		cruise: float, iters: int = 4) -> Dictionary:
	var speed: float = maxf(cruise, 0.001)
	var t: float = ship_pos.distance_to(body_pos(target, t0)) / speed
	for _i in iters:
		var aim := body_pos(target, t0 + t)
		t = ship_pos.distance_to(aim) / speed
	var arrival := body_pos(target, t0 + t)
	return {"arrival_pos": arrival, "t_arr": t}

# ── Burn simulation (STRATEGY_FLIGHT_DYNAMICS_AND_PROXIMITY §1) ─────
# Constant-thrust trapezoid: accelerate at burn_accel to v_max, coast,
# flip-and-brake symmetrically. Short hops go triangular (never reach v_max).
# All closed-form and headless-testable; trip time EMERGES from distance —
# there is no duration clamp anymore.

## Total trip time to cover distance d under the burn profile.
static func burn_travel_time(d: float, cfg: SolarFlyerConfig) -> float:
	var a: float = maxf(cfg.burn_accel, 0.001)
	var v: float = maxf(cfg.v_max, 0.001)
	var dist: float = maxf(d, 0.0)
	if dist <= v * v / a:  # triangular: brake starts before reaching v_max
		return 2.0 * sqrt(dist / a)
	return dist / v + v / a

## Peak speed reached on a hop of distance d.
static func burn_peak_speed(d: float, cfg: SolarFlyerConfig) -> float:
	var a: float = maxf(cfg.burn_accel, 0.001)
	var v: float = maxf(cfg.v_max, 0.001)
	return minf(v, sqrt(maxf(d, 0.0) * a))

## Distance covered t seconds into a hop of total distance d.
static func burn_dist_at(t: float, d: float, cfg: SolarFlyerConfig) -> float:
	var a: float = maxf(cfg.burn_accel, 0.001)
	var dist: float = maxf(d, 0.0)
	var total: float = burn_travel_time(dist, cfg)
	var tt: float = clampf(t, 0.0, total)
	var vp: float = burn_peak_speed(dist, cfg)
	var t_ramp: float = vp / a
	if tt <= t_ramp:
		return 0.5 * a * tt * tt
	if tt >= total - t_ramp:
		var tb: float = total - tt  # time still to brake
		return dist - 0.5 * a * tb * tb
	return 0.5 * a * t_ramp * t_ramp + vp * (tt - t_ramp)

## Path progress 0..1 at wall-time fraction u_time of the hop. Normalized so
## progress(1) == 1 exactly even if the route's duration was solved against a
## slightly different length (intercept residual) — same shape, exact endpoints.
static func burn_progress(u_time: float, d: float, cfg: SolarFlyerConfig) -> float:
	var dist: float = maxf(d, 0.001)
	var total: float = burn_travel_time(dist, cfg)
	return clampf(burn_dist_at(clampf(u_time, 0.0, 1.0) * total, dist, cfg) / dist, 0.0, 1.0)

const PHASE_BURN := 0
const PHASE_COAST := 1
const PHASE_BRAKE := 2

## Which burn phase the ship is in at wall-time fraction u_time.
static func burn_phase(u_time: float, d: float, cfg: SolarFlyerConfig) -> int:
	var a: float = maxf(cfg.burn_accel, 0.001)
	var dist: float = maxf(d, 0.001)
	var total: float = burn_travel_time(dist, cfg)
	var t: float = clampf(u_time, 0.0, 1.0) * total
	var t_ramp: float = burn_peak_speed(dist, cfg) / a
	if t < t_ramp:
		return PHASE_BURN
	# >= so a triangular hop flips straight from BURN to BRAKE at the apex.
	if t >= total - t_ramp:
		return PHASE_BRAKE
	return PHASE_COAST

# ── Plot-time collision sweep, deflection, slingshot (STRATEGY §3.3–3.4) ──

const SLINGSHOT_HERO_MIN := 6.0   ## big worlds only (Jupiter, Saturn)
const SLINGSHOT_BOOST := 1.3      ## v_max multiplier after the swing
const FLYBY_WINDOW_K := 7.0       ## CPA < 7·hero_r counts as a flyby

## Launch-window candidates tried when a hop can't sweep clean at t=0 —
## real missions wait for windows too (the compressed system makes inner-world
## conjunctions genuinely undodgeable by geometry alone).
const LAUNCH_WINDOWS: Array = [0.0, 2.0, 4.0, 6.0, 8.0]

## Safe separation from a world's center — outside its largest rendered size.
static func clearance_for(hero_r: float) -> float:
	return 2.2 * hero_r + 2.0

## Clearance capped by the body's ring gap to its orbital neighbours: in the
## compressed system Venus's ideal clearance (11.0) exceeds the Venus–Earth
## gap (10.1), which would make conjunction launches impossible by contract.
## Never drops below 1.6 × hero (safely outside the rendered sphere).
static func clearance_for_body(b: Dictionary, cfg: SolarFlyerConfig) -> float:
	if bool(b.get("is_star", false)):
		return cfg.sun_clearance
	var hero: float = float(b.get("hero_r", 1.0))
	var my_r: float = float(b.get("orbit_r", 0.0))
	var gap := INF
	for o in SolarData.flyer_bodies(cfg):
		if str(o.get("id", "")) == str(b.get("id", "")) or bool(o.get("is_star", false)):
			continue
		var d: float = absf(float(o.get("orbit_r", 0.0)) - my_r)
		if d > 0.001:
			gap = minf(gap, d)
	return maxf(minf(clearance_for(hero), gap * 0.85), hero * 1.6)

## Bodies the sweep must respect on a hop: everything except the origin (we
## launch from its standoff), the destination (the course ends there), and the
## belt pseudo-body (a ring, not a point — its rocks are scenery, not hazards).
static func sweep_bodies_for(origin_id: String, dest_id: String,
		cfg: SolarFlyerConfig) -> Array:
	var out: Array = []
	for b in SolarData.flyer_bodies(cfg):
		var id := str(b.get("id", ""))
		if id == origin_id or id == dest_id or bool(b.get("belt", false)):
			continue
		out.append(b)
	return out

## Inverse of burn_dist_at: time at which the ship has covered path distance s.
static func burn_time_at_dist(s: float, d: float, cfg: SolarFlyerConfig) -> float:
	var a: float = maxf(cfg.burn_accel, 0.001)
	var dist: float = maxf(d, 0.001)
	var ss: float = clampf(s, 0.0, dist)
	var vp: float = burn_peak_speed(dist, cfg)
	var t_ramp: float = vp / a
	var s_ramp: float = 0.5 * a * t_ramp * t_ramp
	var total: float = burn_travel_time(dist, cfg)
	if ss <= s_ramp:
		return sqrt(2.0 * ss / a)
	if ss >= dist - s_ramp:
		return total - sqrt(2.0 * maxf(dist - ss, 0.0) / a)
	return t_ramp + (ss - s_ramp) / vp

## Trip time when everything after the slingshot CPA (path distance s_cpa)
## runs `boost`× faster — same geometry, hotter engine.
static func boosted_travel_time(d: float, s_cpa: float, boost: float,
		cfg: SolarFlyerConfig) -> float:
	var t_cpa: float = burn_time_at_dist(s_cpa, d, cfg)
	return t_cpa + (burn_travel_time(d, cfg) - t_cpa) / maxf(boost, 0.001)

## Path progress under the boosted profile at wall-time fraction u_time.
static func boosted_progress(u_time: float, d: float, s_cpa: float, boost: float,
		cfg: SolarFlyerConfig) -> float:
	var dist: float = maxf(d, 0.001)
	var total: float = boosted_travel_time(dist, s_cpa, boost, cfg)
	var t: float = clampf(u_time, 0.0, 1.0) * total
	var t_cpa: float = burn_time_at_dist(s_cpa, dist, cfg)
	var t_plain: float = t if t <= t_cpa else t_cpa + (t - t_cpa) * maxf(boost, 0.001)
	return clampf(burn_dist_at(t_plain, dist, cfg) / dist, 0.0, 1.0)

const PHASE_HOLD := 3   ## parked at the launch point, waiting for a window

## Flight-only trip time for a route shape (excludes any launch hold).
static func route_flight_time(route: Dictionary, cfg: SolarFlyerConfig) -> float:
	var d: float = maxf(float(route.get("path_len", 1.0)), 0.001)
	var sl: Dictionary = route.get("slingshot", {})
	if sl.is_empty():
		return burn_travel_time(d, cfg)
	return boosted_travel_time(d, float(sl.get("s_cpa", d * 0.5)),
		float(sl.get("boost", SLINGSHOT_BOOST)), cfg)

## Route-aware progress: launch hold (parked), then the burn profile, with the
## slingshot boost applied when the hop has one.
static func route_progress(u_time: float, route: Dictionary, cfg: SolarFlyerConfig) -> float:
	var d: float = maxf(float(route.get("path_len", 1.0)), 0.001)
	var delay: float = maxf(float(route.get("launch_delay", 0.0)), 0.0)
	var t_flight: float = route_flight_time(route, cfg)
	var total: float = delay + t_flight
	var t: float = clampf(u_time, 0.0, 1.0) * total
	if t <= delay:
		return 0.0
	var uf: float = (t - delay) / maxf(t_flight, 0.001)
	var sl: Dictionary = route.get("slingshot", {})
	if sl.is_empty():
		return burn_progress(uf, d, cfg)
	return boosted_progress(uf, d, float(sl.get("s_cpa", d * 0.5)),
		float(sl.get("boost", SLINGSHOT_BOOST)), cfg)

## Route-aware burn phase (hold → burn → coast → brake; slingshot remaps time).
static func route_phase(u_time: float, route: Dictionary, cfg: SolarFlyerConfig) -> int:
	var d: float = maxf(float(route.get("path_len", 1.0)), 0.001)
	var delay: float = maxf(float(route.get("launch_delay", 0.0)), 0.0)
	var t_flight: float = route_flight_time(route, cfg)
	var total: float = delay + t_flight
	var t: float = clampf(u_time, 0.0, 1.0) * total
	if t < delay:
		return PHASE_HOLD
	var tf: float = t - delay
	var sl: Dictionary = route.get("slingshot", {})
	if sl.is_empty():
		return burn_phase(tf / maxf(t_flight, 0.001), d, cfg)
	var boost: float = float(sl.get("boost", SLINGSHOT_BOOST))
	var s_cpa: float = float(sl.get("s_cpa", d * 0.5))
	var t_cpa: float = burn_time_at_dist(s_cpa, d, cfg)
	var t_plain: float = tf if tf <= t_cpa else t_cpa + (tf - t_cpa) * boost
	return burn_phase(t_plain / maxf(burn_travel_time(d, cfg), 0.001), d, cfg)

## True moving-target sweep: sample the hop uniformly in TIME (ship via the
## burn profile, worlds via their orbits at the same clock) and record each
## body's closest approach. route_like needs path_len (+ slingshot if any).
static func sweep_course(curve: Curve3D, route_like: Dictionary, bodies: Array,
		t0: float, cfg: SolarFlyerConfig, steps: int = 100) -> Array:
	var out: Array = []
	var clen: float = maxf(curve.get_baked_length(), 0.001)
	var dur: float = maxf(float(route_like.get("duration",
		burn_travel_time(clen, cfg))), 0.001)
	var delay: float = maxf(float(route_like.get("launch_delay", 0.0)), 0.0)
	for b in bodies:
		var best_sep := INF
		var best_u := 0.0
		for i in steps + 1:
			var u_t: float = float(i) / float(steps)
			# While holding for the launch window the ship is docked at the
			# origin world — passing traffic is not a collision hazard there.
			if u_t * dur < delay:
				continue
			var p := curve.sample_baked(route_progress(u_t, route_like, cfg) * clen)
			var q := body_pos(b, t0 + u_t * dur)
			var sep: float = p.distance_to(q)
			if sep < best_sep:
				best_sep = sep
				best_u = u_t
		var hero: float = float(b.get("hero_r", 1.0))
		var clear: float = clearance_for_body(b, cfg)
		var klass := "clear"
		if best_sep < clear:
			klass = "conflict"
		elif best_sep < FLYBY_WINDOW_K * hero:
			klass = "flyby"
		out.append({
			"id": str(b.get("id", "")), "min_sep": best_sep, "u_cpa": best_u,
			"clearance": clear, "class": klass, "hero_r": hero,
			"is_star": bool(b.get("is_star", false)),
		})
	return out

## Smooth lateral bump: displace the course's sampled points along `dir` with a
## cos² window centered at path progress p_cpa. Endpoints stay pinned so the
## launch point and the intercept never move. Negative mag pulls TOWARD a body
## (slingshot skim). Returns a rebuilt Curve3D.
static func deflect_course(curve: Curve3D, p_cpa: float, dir: Vector3, mag: float,
		width: float = 0.12) -> Curve3D:
	var out := Curve3D.new()
	var n: int = curve.get_point_count()
	for i in n:
		var p := curve.get_point_position(i)
		var pu: float = float(i) / float(maxi(n - 1, 1))
		var x: float = (pu - p_cpa) / maxf(width, 0.001)
		var bump: float = 0.0
		if absf(x) < 1.0:
			bump = pow(cos(x * PI * 0.5), 2.0)
		# Pin the endpoints (launch + intercept are promises).
		bump *= clampf(pu / 0.08, 0.0, 1.0) * clampf((1.0 - pu) / 0.08, 0.0, 1.0)
		out.add_point(p + dir * (mag * bump))
	return out

## Sweep + deflect + slingshot until the course is clean (≤ max_passes; the
## field is sparse, it settles fast). Returns {curve, duration, sweeps,
## deflections, slingshot}.
## Try the candidate deflection sides (radially away from the body, and both
## path perpendiculars) against the ACTUAL moving-target sweep, then keep the
## side that best restores clearance — tie-broken toward the Sun-away option
## so outward-bound courses never get shoved into the inner system.
static func _deflect_best_side(cur: Curve3D, route_like: Dictionary, body: Dictionary,
		t0: float, cfg: SolarFlyerConfig, center: float, width: float, mag: float,
		rel: Vector3, p_cpa: float, clen: float) -> Curve3D:
	var tang := (cur.sample_baked(minf(p_cpa * clen + 1.0, clen))
		- cur.sample_baked(maxf(p_cpa * clen - 1.0, 0.0)))
	tang.y = 0.0
	var candidates: Array = []
	if rel.length() > 0.001:
		candidates.append(rel.normalized())
	if tang.length() > 0.001:
		var perp := Vector3(-tang.z, 0.0, tang.x).normalized()
		candidates.append(perp)
		candidates.append(-perp)
	if candidates.is_empty():
		candidates.append(Vector3.RIGHT)
	var best_curve: Curve3D = cur
	var best_score := -INF
	var clear: float = clearance_for_body(body, cfg)
	for dir in candidates:
		var trial := deflect_course(cur, center, dir, mag, width)
		var sw := sweep_course(trial, route_like, [body], t0, cfg, 60)
		var sep: float = float(sw[0]["min_sep"]) if not sw.is_empty() else 0.0
		# Separation first (capped once safely clear), Sun distance second.
		var score: float = minf(sep, clear + 3.0) * 10.0 \
			+ course_min_sun_dist(trial) * 0.5
		if score > best_score:
			best_score = score
			best_curve = trial
	return best_curve

## Attenuation of a deflection bump at path progress p for a bump centered at
## `center` (cos² window × endpoint pinning) — used to size the magnitude so
## the SHIP at CPA actually moves by the full requested amount.
static func _bump_effect(p: float, center: float, width: float) -> float:
	var x: float = (p - center) / maxf(width, 0.001)
	if absf(x) >= 1.0:
		return 0.0
	var e: float = pow(cos(x * PI * 0.5), 2.0)
	return e * clampf(p / 0.08, 0.0, 1.0) * clampf((1.0 - p) / 0.08, 0.0, 1.0)

static func refine_course(curve: Curve3D, t0: float, cfg: SolarFlyerConfig,
		sweep_bodies: Array, launch_delay: float = 0.0, max_passes: int = 6) -> Dictionary:
	var cur := curve
	var slingshot: Dictionary = {}
	var deflections: Array = []
	var sweeps: Array = []
	for _pass in max_passes:
		var clen: float = maxf(cur.get_baked_length(), 0.001)
		var route_like := {"path_len": clen, "slingshot": slingshot,
			"launch_delay": launch_delay}
		route_like["duration"] = launch_delay + route_flight_time(route_like, cfg)
		sweeps = sweep_course(cur, route_like, sweep_bodies, t0, cfg)
		# Pick the worst offender this pass: conflicts first, then a big-world
		# flyby we can turn into a slingshot (one per hop).
		var act: Dictionary = {}
		for s in sweeps:
			if s["class"] == "conflict":
				if act.is_empty() or float(s["min_sep"]) - float(s["clearance"]) \
						< float(act["min_sep"]) - float(act["clearance"]):
					act = s
		if act.is_empty() and slingshot.is_empty():
			for s in sweeps:
				if s["class"] == "flyby" and not bool(s["is_star"]) \
						and float(s["hero_r"]) >= SLINGSHOT_HERO_MIN:
					act = s
					break
		if act.is_empty():
			break
		var dur: float = float(route_like["duration"])
		var u_cpa: float = float(act["u_cpa"])
		var p_cpa: float = route_progress(u_cpa, route_like, cfg)
		var ship_at := cur.sample_baked(p_cpa * clen)
		var body := SolarData.flyer_body_by_id(str(act["id"]), cfg)
		var body_at := body_pos(body, t0 + u_cpa * dur)
		var rel := ship_at - body_at
		rel.y = 0.0
		var big: bool = float(act["hero_r"]) >= SLINGSHOT_HERO_MIN \
			and not bool(act["is_star"])
		# CPAs near the endpoints get their bump attenuated by pinning —
		# recenter slightly downstream and compensate the magnitude so the
		# ship at CPA moves by the full requested amount.
		var width := 0.2
		var center: float = clampf(p_cpa, 0.10, 0.90)
		var eff: float = maxf(_bump_effect(p_cpa, center, width), 0.30)
		if big:
			# Slingshot: snap the course to SKIM the clearance sphere (pull in
			# or push out to the skim radius) and boost the rest of the hop.
			var skim: float = float(act["clearance"]) * 1.15
			var dir := rel.normalized() if rel.length() > 0.001 else Vector3.RIGHT
			cur = deflect_course(cur, center, dir,
				(skim - float(act["min_sep"])) / eff, width)
			slingshot = {"id": str(act["id"]), "boost": SLINGSHOT_BOOST}
		else:
			var mag: float = (float(act["clearance"]) - float(act["min_sep"]) + 2.0) / eff
			cur = _deflect_best_side(cur, route_like, body, t0, cfg,
				center, width, mag, rel, p_cpa, clen)
			deflections.append({"id": str(act["id"]), "mag": mag})
	var final_len: float = maxf(cur.get_baked_length(), 0.001)
	if not slingshot.is_empty():
		# Locate the final CPA arc-length for the boost handoff (plain flight
		# timing; the hold just offsets the clock).
		var body := SolarData.flyer_body_by_id(str(slingshot["id"]), cfg)
		var best_sep := INF
		var best_p := 0.5
		var dur0: float = burn_travel_time(final_len, cfg)
		for i in 101:
			var u_t: float = float(i) / 100.0
			var pr: float = burn_progress(u_t, final_len, cfg)
			var sep: float = cur.sample_baked(pr * final_len).distance_to(
				body_pos(body, t0 + launch_delay + u_t * dur0))
			if sep < best_sep:
				best_sep = sep
				best_p = pr
		slingshot["s_cpa"] = best_p * final_len
		slingshot["min_sep"] = best_sep
	var shape := {"path_len": final_len, "slingshot": slingshot,
		"launch_delay": launch_delay}
	return {
		"curve": cur, "duration": launch_delay + route_flight_time(shape, cfg),
		"sweeps": sweeps, "deflections": deflections, "slingshot": slingshot,
		"launch_delay": launch_delay,
	}

## Damped fixed-point intercept under the burn profile. Fast inner planets
## (Mercury) move quicker than the ship, so the naive iteration is
## non-contractive — the 0.5 damping restores convergence; iterations are
## capped and the scene stays self-consistent regardless (the clock, the
## course endpoint, and the ghost all use the same t).
static func solve_intercept_burn(ship_pos: Vector3, target: Dictionary, t0: float,
		cfg: SolarFlyerConfig, depart_standoff: float = 0.0) -> Dictionary:
	var t: float = burn_travel_time(
		ship_pos.distance_to(body_pos(target, t0)), cfg)
	for _i in maxi(cfg.intercept_iters, 4):
		var aim := body_pos(target, t0 + t)
		var coarse := build_course(ship_pos, aim, 16, depart_standoff)
		var t_new: float = burn_travel_time(coarse.get_baked_length(), cfg)
		if absf(t_new - t) < 0.02:
			t = t_new
			break
		t = 0.5 * (t + t_new)
	return {"arrival_pos": body_pos(target, t0 + t), "t_arr": t}

## Quadratic Bézier bowed outward from the Sun so courses don't cut through it.
## depart_standoff trims the start so we launch from outside the origin planet
## instead of its center (no "backing out of the planet" on takeoff).
static func build_course(ship_pos: Vector3, arrival_pos: Vector3,
		samples: int = 48, depart_standoff: float = 0.0) -> Curve3D:
	var span: float = ship_pos.distance_to(arrival_pos)
	var start := ship_pos
	if depart_standoff > 0.001 and span > 0.001:
		var trim: float = minf(depart_standoff, span * 0.3)
		start = ship_pos + (arrival_pos - ship_pos).normalized() * trim
	var mid := (start + arrival_pos) * 0.5
	var out_dir := mid.normalized() if mid.length() > 0.001 else Vector3.FORWARD
	var ctrl := mid + out_dir * (span * 0.35)
	var curve := Curve3D.new()
	var n: int = maxi(samples, 2)
	for i in n + 1:
		var u := float(i) / float(n)
		var p := start.lerp(ctrl, u).lerp(ctrl.lerp(arrival_pos, u), u)
		curve.add_point(p)
	return curve

## Minimum distance from the Sun (origin) along a sampled course.
static func course_min_sun_dist(curve: Curve3D) -> float:
	var best := INF
	var n: int = curve.get_point_count()
	for i in n:
		var d: float = curve.get_point_position(i).length()
		if d < best:
			best = d
	return best

## Apparent size LOD (STRATEGY §3.3): far → min_dot, near → hero_r.
## Soft far presence + accelerating bloom near focus_dist so approach feels
## dramatic. Hard-capped at hero_r — passing worlds must never balloon past
## their true hero size (it read as the camera rubber-necking).
static func apparent_size(dist: float, hero_r: float, cfg: SolarFlyerConfig) -> float:
	var d: float = maxf(dist, 0.001)
	var ratio: float = cfg.focus_dist / d
	# Compress the mid-range so growth ramps hard in the last stretch.
	var u: float = clampf(pow(ratio, 0.72), 0.0, 1.0)
	return clampf(hero_r * u, cfg.min_dot, hero_r)

## Proximity render trigger: bigger worlds bloom from farther away.
static func render_in_dist(hero_r: float, cfg: SolarFlyerConfig) -> float:
	return clampf(cfg.render_in_k * hero_r, cfg.render_in_min, cfg.render_in_max)

## World-space size of a constant-screen-size icon billboard at camera
## distance `dist` for a body of icon tier `tier`.
static func icon_world_size(dist: float, tier: float, cfg: SolarFlyerConfig) -> float:
	return maxf(cfg.icon_scale * maxf(dist, 0.001) * tier, 0.3)

## Safe parking distance outside the Sun's hero sphere (never dive into the star).
static func sun_approach_standoff(cfg: SolarFlyerConfig) -> float:
	return maxf(cfg.sun_clearance, orbit_standoff(cfg.sun_hero_r))

## Where the ship sits when "at" a body. Planets use their orbital position;
## the Sun is fixed at the origin, so we park on a safe radial standoff.
static func park_pos(body: Dictionary, t: float, cfg: SolarFlyerConfig,
		prefer_from: Vector3 = Vector3.RIGHT) -> Vector3:
	if bool(body.get("is_star", false)):
		var stand := sun_approach_standoff(cfg)
		var dir := prefer_from
		if dir.length() < 0.001:
			dir = Vector3.RIGHT
		return dir.normalized() * stand
	return body_pos(body, t)

## Arrival line spoken when the ship parks in orbit. Shared with the VO dump
## tool so every possible sentence is enumerated and baked ahead of time.
static func arrival_narration(place: String, travel_au: float,
		is_star: bool = false) -> String:
	var miles := format_travel_miles(travel_au)
	var au_txt: String = "%.1f" % travel_au if travel_au < 10.0 else "%.0f" % travel_au
	if is_star:
		return (
			"We've come as close as we safely can to the Sun. You traveled %s astronomical units. "
			+ "That's %s miles! Stars are far too hot to land on. "
			+ "Click to learn more or click the star panel to chart a new course."
		) % [au_txt, miles]
	return (
		"You have arrived at %s. You traveled %s astronomical units. That's %s miles! "
		+ "Click to learn more or click the star panel to chart a new course."
	) % [place, au_txt, miles]

## Kid-readable miles string from AU traveled (1 AU ≈ 93 million miles).
static func format_travel_miles(travel_au: float) -> String:
	var miles: float = maxf(travel_au, 0.0) * 93_000_000.0
	if miles >= 1_000_000_000.0:
		return "%.1f billion" % (miles / 1_000_000_000.0)
	if miles >= 1_000_000.0:
		return "%.0f million" % (miles / 1_000_000.0)
	return "%.0f" % miles

## Camera offset for a gentle orbit around a destination (Y-up).
static func orbit_offset(angle: float, radius: float, height: float = 0.35) -> Vector3:
	return Vector3(cos(angle) * radius, height * radius, sin(angle) * radius)

## Direction of travel along a parked orbit circle at `angle`, for orbit
## direction dir (+1 counter-clockwise in the XZ plane, −1 clockwise).
static func orbit_tangent(angle: float, dir: float = 1.0) -> Vector3:
	return Vector3(-sin(angle), 0.0, cos(angle)) * signf(dir)

## Safe standoff distance for parking in orbit (outside the hero sphere).
static func orbit_standoff(hero_r: float) -> float:
	return maxf(hero_r * 4.2, 9.0)

## Worlds whose orbits sit between origin and destination (radial hop).
static func bodies_along_hop(origin: Dictionary, dest: Dictionary, cfg: SolarFlyerConfig) -> Array:
	var r0: float = float(origin.get("orbit_r", 0.0))
	var r1: float = float(dest.get("orbit_r", 0.0))
	var lo: float = minf(r0, r1)
	var hi: float = maxf(r0, r1)
	var out: Array = []
	for b in SolarData.flyer_bodies(cfg):
		var id := str(b.get("id", ""))
		if id == str(origin.get("id", "")) or id == str(dest.get("id", "")):
			continue
		if bool(b.get("is_star", false)) or bool(b.get("belt", false)):
			continue
		var r: float = float(b.get("orbit_r", 0.0))
		if r > lo + 0.5 and r < hi - 0.5:
			out.append(b)
	out.sort_custom(func(a, c): return float(a["orbit_r"]) < float(c["orbit_r"]))
	return out

## Kid-readable course line spoken when a hop is plotted.
## Every claim is derived from the actual course geometry — never a guess:
##   · sun proximity comes from the sampled curve's min_sun_dist,
##   · direction comes from origin vs destination orbit radii,
##   · "cross the orbit of X" is literally true for any radial hop.
static func trip_narration(origin: Dictionary, dest: Dictionary, route: Dictionary,
		cfg: SolarFlyerConfig) -> String:
	# Destination is the Sun itself — a special, honest "approach but don't land" hop.
	if bool(dest.get("is_star", false)):
		var line := _trip_open_sentence("the Sun", "to_sun")
		var cross := _trip_cross_sentence(origin, dest, cfg)
		if not cross.is_empty():
			line += " " + cross
		line += " " + _trip_aim_sentence("sun")
		return line

	var dest_name := str(dest.get("name", "our destination"))
	var r0: float = float(origin.get("orbit_r", 0.0))
	var r1: float = float(dest.get("orbit_r", 0.0))
	# Only claim a sun flyby when the curve truly dips inside both endpoint orbits.
	var near_sun: bool = float(route.get("min_sun_dist", INF)) < minf(r0, r1) * 0.55

	var line := ""
	if near_sun:
		line = _trip_open_sentence(dest_name, "flyby")
	elif r1 > r0 + 0.5:
		line = _trip_open_sentence(dest_name, "outward")
	elif r1 < r0 - 0.5:
		line = _trip_open_sentence(dest_name, "inward")
	else:
		line = _trip_open_sentence(dest_name, "plain")
	var cross := _trip_cross_sentence(origin, dest, cfg)
	if not cross.is_empty():
		line += " " + cross
	# Slingshot / steer-wide claims come straight from the refined course —
	# spoken only when the sweep actually bent the trajectory.
	var sling: Dictionary = route.get("slingshot", {})
	if not sling.is_empty():
		line += " " + _trip_slingshot_sentence(_spoken_body_name(str(sling["id"]), cfg))
	else:
		var defl: Array = route.get("deflections", [])
		if not defl.is_empty():
			line += " " + _trip_steer_sentence(_spoken_body_name(str(defl[0]["id"]), cfg))
	if float(route.get("launch_delay", 0.0)) > 0.01:
		line += " " + _trip_window_sentence()
	line += " " + _trip_aim_sentence(dest_name)
	# Honest bonus lesson: a fast inner world can lap the Sun before we arrive.
	# Claimed only when the measured trip time × the body's omega proves it.
	if float(dest.get("omega", 0.0)) * float(route.get("t_arr", 0.0)) >= TAU:
		line += " " + _trip_lap_sentence(dest_name)
	return line

static func _spoken_body_name(id: String, cfg: SolarFlyerConfig) -> String:
	var b := SolarData.flyer_body_by_id(id, cfg)
	if bool(b.get("is_star", false)):
		return "the Sun"  # mid-sentence, not the display name "The Sun"
	return str(b.get("name", id))

static func _trip_slingshot_sentence(body_name: String) -> String:
	return ("We'll slingshot around %s — its gravity gives us a speed boost!"
		% body_name)

static func _trip_steer_sentence(body_name: String) -> String:
	return "We'll steer wide of %s to keep a safe distance." % body_name

static func _trip_window_sentence() -> String:
	return "Traffic ahead — we'll hold for a clear launch window first."

static func _trip_lap_sentence(dest_name: String) -> String:
	return ("%s is so quick it will zoom all the way around the Sun " +
		"before we get there!") % dest_name

static func _trip_open_sentence(dest_name: String, kind: String) -> String:
	match kind:
		"to_sun":
			return "We're flying in toward the Sun."
		"flyby":
			return "This course swings us close to the Sun on the way to %s." % dest_name
		"outward":
			return "We're heading away from the Sun, out to %s." % dest_name
		"inward":
			return "We're heading in toward the Sun, to %s." % dest_name
	return "Plotting a course to %s." % dest_name

static func _trip_cross_sentence(origin: Dictionary, dest: Dictionary,
		cfg: SolarFlyerConfig) -> String:
	var names: Array = []
	for b in bodies_along_hop(origin, dest, cfg):
		names.append(str(b["name"]))
		if names.size() >= 2:
			break
	if names.size() == 1:
		return "We'll cross the orbit of %s on the way." % names[0]
	if names.size() >= 2:
		return "We'll cross the orbits of %s and %s on the way." % [names[0], names[1]]
	return ""

## Spoken when a tap on the belt ring resolves to a named asteroid — the
## lesson (what the belt IS) plus the invitation (which rock, and why).
static func belt_intro_sentence(asteroid: Dictionary) -> String:
	return "The asteroid belt is a wide ring of space rocks between Mars and Jupiter. We'll visit %s — %s!" % [
		str(asteroid.get("name", "an asteroid")),
		str(asteroid.get("belt_hook", "one of the biggest rocks"))]

static func _trip_aim_sentence(dest_name: String) -> String:
	if dest_name == "sun":
		return "We can't land on a star — we'll park at a safe distance and look!"
	return "%s is moving, so we aim ahead of it!" % dest_name

## Every sentence trip_narration could ever emit for this pair — the geometry
## picks the opener at runtime, so the VO baker records all variants.
static func trip_narration_sentences_all(origin: Dictionary, dest: Dictionary,
		cfg: SolarFlyerConfig) -> Array:
	var out: Array = []
	if bool(dest.get("is_star", false)):
		out.append(_trip_open_sentence("the Sun", "to_sun"))
		var cross_s := _trip_cross_sentence(origin, dest, cfg)
		if not cross_s.is_empty():
			out.append(cross_s)
		out.append(_trip_aim_sentence("sun"))
		return out
	var dest_name := str(dest.get("name", "our destination"))
	for kind in ["flyby", "outward", "inward", "plain"]:
		out.append(_trip_open_sentence(dest_name, kind))
	var cross := _trip_cross_sentence(origin, dest, cfg)
	if not cross.is_empty():
		out.append(cross)
	out.append(_trip_aim_sentence(dest_name))
	out.append(_trip_lap_sentence(dest_name))
	# Slingshot / steer variants for every possible flyby world on this pair.
	for b in SolarData.flyer_bodies(cfg):
		if bool(b.get("belt", false)):
			continue
		var nm := _spoken_body_name(str(b["id"]), cfg)
		if float(b.get("hero_r", 0.0)) >= SLINGSHOT_HERO_MIN and not bool(b.get("is_star", false)):
			out.append(_trip_slingshot_sentence(nm))
		out.append(_trip_steer_sentence(nm))
	out.append(_trip_window_sentence())
	return out

## Hop duration from path length under the burn profile. NO clamp — the
## hop_min_s/hop_max_s band is a ScaleTune design assertion on the knobs,
## never a runtime lie (a clamp made short hops fly a slow-motion sky).
static func hop_duration(path_len: float, cfg: SolarFlyerConfig) -> float:
	return burn_travel_time(path_len, cfg)

## Snapshot every flyer-capable body at t0 (angles freeze for the plot).
static func snapshot_angles(bodies: Array, t0: float) -> Dictionary:
	var out := {}
	for b in bodies:
		var id := str(b.get("id", ""))
		if id.is_empty():
			continue
		out[id] = float(b.get("theta0", 0.0)) + float(b.get("omega", 0.0)) * t0
	return out

## Full plot package for destination select (Beat A).
## depart_standoff (game units) trims the launch point clear of the origin planet.
## The Sun is a fixed target: we aim at a safe standoff on the approach radial,
## never the star's center.
## sweep_bodies (all worlds except origin + destination) activates the plot-time
## collision sweep, lateral deflection, and slingshot (STRATEGY §3.3–3.4) —
## the refine pass runs INSIDE the intercept iteration so the charted time
## already includes every swerve and boost.
## Invariant: duration == t_arr — the wall-clock flight and the orbital clock
## are the SAME time, so the charted intercept and the flown sky always agree.
static func plot_route(ship_pos: Vector3, target: Dictionary, t0: float,
		cfg: SolarFlyerConfig, depart_standoff: float = 0.0,
		sweep_bodies: Array = []) -> Dictionary:
	var star: bool = bool(target.get("is_star", false))
	var fixed_arrival := Vector3.ZERO
	if star:
		var stand := sun_approach_standoff(cfg)
		var radial := ship_pos if ship_pos.length() > 0.001 else Vector3.RIGHT
		fixed_arrival = radial.normalized() * stand

	# Launch-window loop: if a hop can't sweep clean at the tapped moment
	# (fast inner worlds at conjunction are genuinely undodgeable), hold at
	# the launch point and try again a little later — like real missions.
	var best: Dictionary = {}
	var best_conflicts: int = 1 << 30
	var windows: Array = LAUNCH_WINDOWS if not sweep_bodies.is_empty() else [0.0]
	for delay in windows:
		var t: float = float(delay) + burn_travel_time(ship_pos.distance_to(
			fixed_arrival if star else body_pos(target, t0)), cfg)
		var refined: Dictionary = {}
		var arrival := fixed_arrival
		for _i in maxi(cfg.intercept_iters, 4):
			arrival = fixed_arrival if star else body_pos(target, t0 + t)
			var c := build_course(ship_pos, arrival, cfg.course_samples, depart_standoff)
			if sweep_bodies.is_empty():
				refined = {
					"curve": c,
					"duration": burn_travel_time(c.get_baked_length(), cfg),
					"sweeps": [], "deflections": [], "slingshot": {},
					"launch_delay": 0.0,
				}
			else:
				refined = refine_course(c, t0, cfg, sweep_bodies, float(delay))
			var t_new: float = float(refined["duration"])
			if absf(t_new - t) < 0.02:
				t = t_new
				break
			t = 0.5 * (t + t_new)
		var conflicts := 0
		for s in refined.get("sweeps", []):
			if str(s["class"]) == "conflict":
				conflicts += 1
		if conflicts < best_conflicts:
			best_conflicts = conflicts
			best = {"refined": refined, "t": t, "arrival": arrival}
		if conflicts == 0:
			break

	var refined: Dictionary = best["refined"]
	var t_final: float = float(best["t"])
	var curve: Curve3D = refined["curve"]
	return {
		"arrival_pos": best["arrival"],
		"t_arr": t_final,
		"curve": curve,
		"path_len": curve.get_baked_length(),
		"duration": t_final,
		"min_sun_dist": course_min_sun_dist(curve),
		"sweeps": refined["sweeps"],
		"deflections": refined["deflections"],
		"slingshot": refined["slingshot"],
		"launch_delay": refined.get("launch_delay", 0.0),
	}

# ── Phase 3 flight helpers (headless-testable) ──────────────────────

## Cubic ease-in-out on linear 0..1 (matches Tween TRANS_CUBIC / EASE_IN_OUT).
static func ease_cubic_inout(x: float) -> float:
	var t: float = clampf(x, 0.0, 1.0)
	if t < 0.5:
		return 4.0 * t * t * t
	return 1.0 - pow(-2.0 * t + 2.0, 3.0) / 2.0

## Orbital clock during a hop: lerp t0 → t0+t_arr by eased progress.
static func flight_clock(t0: float, t_arr: float, progress_u: float) -> float:
	return t0 + t_arr * clampf(progress_u, 0.0, 1.0)

## Sample a course curve at eased/linear progress ratio 0..1.
static func path_sample(curve: Curve3D, progress_u: float) -> Vector3:
	if curve == null or curve.get_point_count() == 0:
		return Vector3.ZERO
	var len: float = maxf(curve.get_baked_length(), 0.001)
	return curve.sample_baked(clampf(progress_u, 0.0, 1.0) * len)

## LOD hysteresis: turn mesh ON inside mesh_in, OFF only past mesh_out.
static func lod_want_mesh(dist: float, currently_on: bool, mesh_in: float,
		mesh_out: float) -> bool:
	if dist < mesh_in:
		return true
	if dist > mesh_out:
		return false
	return currently_on

## Prefer mesh longer for the Sun / active destination (bloom framing).
static func lod_want_mesh_priority(dist: float, currently_on: bool, cfg: SolarFlyerConfig,
		priority: bool) -> bool:
	var out: float = cfg.mesh_out * (1.6 if priority else 1.0)
	var inn: float = cfg.mesh_in
	return lod_want_mesh(dist, currently_on, inn, out)

## Camera look blend weight: 0 = path-forward, 1 = stare at destination.
static func look_blend_weight(progress_u: float, start: float = 0.35) -> float:
	return smoothstep(start, 1.0, clampf(progress_u, 0.0, 1.0))

## Harmless BOOST: nudge linear flight time forward (seconds of hop).
static func apply_boost(flight_t: float, duration: float, nudge_ratio: float = 0.08) -> float:
	var dur: float = maxf(duration, 0.001)
	return minf(dur, flight_t + dur * nudge_ratio)

## Distance from ship on the path to the destination body at the same clock.
static func ship_to_dest_dist(curve: Curve3D, progress_u: float, dest: Dictionary,
		t0: float, t_arr: float) -> float:
	var ship := path_sample(curve, progress_u)
	var clock := flight_clock(t0, t_arr, progress_u)
	return ship.distance_to(body_pos(dest, clock))

## Deterministic belt rock transforms (MultiMesh). Returns Array of Transform3D.
static func belt_transforms(orbit_r: float, count: int = 280, seed: int = 909091) -> Array:
	var out: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for i in count:
		var ang: float = rng.randf() * TAU
		var rr: float = orbit_r + rng.randf_range(-9.0, 9.0)
		var y: float = rng.randf_range(-2.0, 2.0)
		var s: float = rng.randf_range(0.5, 1.8)
		var sy: float = s * rng.randf_range(0.6, 1.2)
		var xf := Transform3D.IDENTITY.scaled(Vector3(s, sy, s))
		xf.origin = Vector3(cos(ang) * rr, y, sin(ang) * rr)
		out.append(xf)
	return out

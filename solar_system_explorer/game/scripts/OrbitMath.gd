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
## Soft far presence + accelerating bloom near focus_dist so approach feels dramatic.
static func apparent_size(dist: float, hero_r: float, cfg: SolarFlyerConfig) -> float:
	var d: float = maxf(dist, 0.001)
	var ratio: float = cfg.focus_dist / d
	# Compress the mid-range so growth ramps hard in the last stretch.
	var u: float = clampf(pow(ratio, 0.72), 0.0, 1.35)
	var bloom: float = hero_r * minf(u, 1.0)
	# Tiny far floor so worlds stay readable dots before mesh LOD.
	return clampf(bloom, cfg.min_dot, hero_r * 1.25)

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
	line += " " + _trip_aim_sentence(dest_name)
	return line

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
	return out

## Hop duration from path length, clamped to the design band.
static func hop_duration(path_len: float, cfg: SolarFlyerConfig) -> float:
	return clampf(path_len / maxf(cfg.cruise_speed, 0.001), cfg.hop_min_s, cfg.hop_max_s)

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
static func plot_route(ship_pos: Vector3, target: Dictionary, t0: float,
		cfg: SolarFlyerConfig, depart_standoff: float = 0.0) -> Dictionary:
	var arrival: Vector3
	var t_arr: float
	if bool(target.get("is_star", false)):
		var stand := sun_approach_standoff(cfg)
		var radial := ship_pos
		if radial.length() < 0.001:
			radial = Vector3.RIGHT * stand
		arrival = radial.normalized() * stand
		t_arr = ship_pos.distance_to(arrival) / maxf(cfg.cruise_speed, 0.001)
	else:
		var hit := solve_intercept(ship_pos, target, t0, cfg.cruise_speed, cfg.intercept_iters)
		arrival = hit["arrival_pos"]
		t_arr = float(hit["t_arr"])
	var curve := build_course(ship_pos, arrival, cfg.course_samples, depart_standoff)
	var path_len: float = curve.get_baked_length()
	return {
		"arrival_pos": arrival,
		"t_arr": t_arr,
		"curve": curve,
		"path_len": path_len,
		"duration": hop_duration(path_len, cfg),
		"min_sun_dist": course_min_sun_dist(curve),
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
		var rr: float = orbit_r + rng.randf_range(-6.0, 6.0)
		var y: float = rng.randf_range(-1.2, 1.2)
		var s: float = rng.randf_range(0.4, 1.3)
		var sy: float = s * rng.randf_range(0.6, 1.2)
		var xf := Transform3D.IDENTITY.scaled(Vector3(s, sy, s))
		xf.origin = Vector3(cos(ang) * rr, y, sin(ang) * rr)
		out.append(xf)
	return out

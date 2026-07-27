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

# ── Plot-time navigation simulation (sim-first, STRATEGY §3) ─────────
# The course is REAL physics on a curved TRANSFER ARC around the Sun (see
# build_course) flown with the burn profile. The whole hop is then SIMULATED
# at plot time at a fixed step: ship via the burn profile, worlds via their
# orbits. The sim's timeline (positions, headings, events, orbit entry) is
# ground truth — the renderer plays it back and never re-derives geometry.

## Fixed simulation step (game seconds). 30 Hz over a ≤60 s hop is ≤1800
## frames — trivial memory, exact enough for every event we narrate.
const SIM_DT := 1.0 / 30.0

## Space is EMPTY: planets are POINTS compared to the gulf between them, so
## the flown arc never hits anything (and its radius never drops below the
## inner endpoint's orbit, so the Sun is cleared by construction). There is
## NO collision detection, no launch holds, and no flyby machinery — the sim
## records ship kinematics and burn phases; the renderer draws every world
## as a sized icon marker at its true bearing.

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

## Trip time for a route shape — pure burn profile, launches are immediate.
static func route_flight_time(route: Dictionary, cfg: SolarFlyerConfig) -> float:
	return burn_travel_time(maxf(float(route.get("path_len", 1.0)), 0.001), cfg)

## Route-aware progress along the plain burn profile.
static func route_progress(u_time: float, route: Dictionary, cfg: SolarFlyerConfig) -> float:
	return burn_progress(clampf(u_time, 0.0, 1.0),
		maxf(float(route.get("path_len", 1.0)), 0.001), cfg)

## Route-aware burn phase (burn → coast → brake).
static func route_phase(u_time: float, route: Dictionary, cfg: SolarFlyerConfig) -> int:
	return burn_phase(clampf(u_time, 0.0, 1.0),
		maxf(float(route.get("path_len", 1.0)), 0.001), cfg)

## Distance from a point to the belt's rock band (torus centerline circle).
static func belt_band_dist(p: Vector3, ring_r: float) -> float:
	var rd: float = absf(Vector2(p.x, p.z).length() - ring_r)
	return sqrt(rd * rd + p.y * p.y)

## Physics course: a TRANSFER ARC around the Sun, the way real interplanetary
## trajectories read. In heliocentric polar coordinates the bearing sweeps
## from the launch point to the intercept point while the orbital radius
## eases from the origin's orbit to the destination's — a smooth curved arc,
## never a straight line. Because the radius stays between the two endpoint
## radii, the arc can never dive at the Sun; no clearance bow is needed.
static func build_course(ship_pos: Vector3, arrival_pos: Vector3,
		samples: int = 48, depart_standoff: float = 0.0) -> Curve3D:
	var span: float = ship_pos.distance_to(arrival_pos)
	if span < 0.01:
		# Degenerate candidate (close conjunction sweeps the parking sphere
		# over the ship during the intercept scan): keep the curve non-zero
		# so Curve3D's up-vector baking never sees coincident points.
		arrival_pos = ship_pos + Vector3(0.01, 0.0, 0.0)
		span = 0.01
	var r0: float = maxf(ship_pos.length(), 0.01)
	var r1: float = maxf(arrival_pos.length(), 0.01)
	var th0: float = atan2(ship_pos.z, ship_pos.x)
	var dth: float = wrapf(atan2(arrival_pos.z, arrival_pos.x) - th0, -PI, PI)
	var curve := Curve3D.new()
	var n: int = maxi(samples, 2)
	# Launch trim: skip the first stretch of the arc so the course starts
	# outside the origin planet's standoff (capped at 30% of the span so a
	# short hop keeps a real cruise). Binary search the exact arc parameter
	# at that distance from the ship.
	var u0: float = 0.0
	var trim: float = minf(depart_standoff, span * 0.3)
	if trim > 0.001 and _arc_pt(r0, r1, th0, dth, 0.5).distance_to(ship_pos) > trim:
		var hi := 0.5
		var lo := 0.0
		for _i in 24:
			var mid: float = (lo + hi) * 0.5
			if _arc_pt(r0, r1, th0, dth, mid).distance_to(ship_pos) >= trim:
				hi = mid
			else:
				lo = mid
		u0 = hi
	# Sample the open interval, then pin the exact arrival point so the last
	# segment has no polar-rounding kink (the charted line == the sim path).
	for i in n:
		var u: float = lerpf(u0, 1.0, float(i) / float(n))
		curve.add_point(_arc_pt(r0, r1, th0, dth, u))
	curve.add_point(arrival_pos)
	curve.bake_interval = 0.5
	return curve

## Point on the transfer arc at parameter u: linear radius + linear sweep =
## an Archimedean spiral segment. Curvature keeps ONE sign the whole way
## (a clean swept arc, never an S-wiggle), and the radius stays bounded by
## the endpoint orbits — the arc can never dive at the Sun.
static func _arc_pt(r0: float, r1: float, th0: float, dth: float, u: float) -> Vector3:
	var r: float = lerpf(r0, r1, u)
	var th: float = th0 + dth * u
	return Vector3(cos(th) * r, 0.0, sin(th) * r)

## Run the whole hop at SIM_DT: ship along the course via the burn profile,
## worlds on their orbits at the same clock. Produces the ground-truth
## timeline the renderer plays back: positions, headings, burn-phase events,
## and the exact orbit-entry state (the course END is the parking radius by
## construction). Nothing else — worlds are points, there is nothing to
## detect or dodge.
static func simulate_route(curve: Curve3D, target: Dictionary, t0: float,
		t_fly: float, cfg: SolarFlyerConfig) -> Dictionary:
	var clen: float = maxf(curve.get_baked_length(), 0.001)
	var total: float = maxf(t_fly, 0.001)
	var steps: int = maxi(int(ceil(total / SIM_DT)), 2)
	var pos := PackedVector3Array()
	var fwd := PackedVector3Array()
	var events: Array = []
	var min_sun := INF
	var phase_prev := -99
	var last_fwd := Vector3.RIGHT
	for k in steps + 1:
		var t: float = minf(float(k) * SIM_DT, total)
		var uf: float = t / total
		# burn_progress is endpoint-normalized: the playback lands ON the
		# curve end (the parking sphere) at exactly t = t_fly.
		var s: float = burn_progress(uf, clen, cfg) * clen
		var ph: int = burn_phase(uf, clen, cfg)
		var p := curve.sample_baked(s)
		var ahead := curve.sample_baked(minf(s + 0.75, clen))
		var f := ahead - p
		if f.length() < 0.001:
			f = last_fwd
		else:
			f = f.normalized()
			last_fwd = f
		pos.append(p)
		fwd.append(f)
		min_sun = minf(min_sun, p.length())
		if ph != phase_prev:
			events.append({"t": t, "kind": "phase", "phase": ph})
			phase_prev = ph
	# Orbit-entry state at the timeline's end. The course ends ON the parking
	# sphere, so entry radius == standoff exactly — no recoil, no spiral-out.
	var end_p: Vector3 = pos[pos.size() - 1]
	var center := Vector3.ZERO if bool(target.get("is_star", false)) \
		else body_pos(target, t0 + total)
	var rel := end_p - center
	var ang: float = atan2(rel.z, rel.x)
	var efwd: Vector3 = fwd[fwd.size() - 1]
	var dir: float = 1.0 if efwd.dot(orbit_tangent(ang, 1.0)) >= 0.0 else -1.0
	var entry := {"pos": end_p, "fwd": efwd, "rad": rel.length(),
		"ang": ang, "dir": dir}
	return {
		"timeline": {
			"dt": SIM_DT, "pos": pos, "fwd": fwd, "events": events,
			## Arrival pose for the hard-cut orbit cinematic (not a path blend).
			"entry": entry,
		},
		"min_sun_dist": min_sun,
	}

## Minimum distance from the Sun (origin) along a sampled course.
static func course_min_sun_dist(curve: Curve3D) -> float:
	var best := INF
	var n: int = curve.get_point_count()
	for i in n:
		var d: float = curve.get_point_position(i).length()
		if d < best:
			best = d
	return best

## MARKERS, not planets: every world is drawn as a small legible icon of
## CONSTANT screen size REGARDLESS OF PROXIMITY, sized only by a simple
## recognition tier (Jupiter reads double Earth, the Sun a bright yellow ball
## bigger than everything). Markers are identifiers for where a world is —
## honest little dots on the sky — never a rendering of the world itself.
## Real geometry appears only after the hard-cut orbit cinematic; cruise and
## approach keep every world (including the destination) as a marker.
static func marker_world_size(dist: float, tier: float, cfg: SolarFlyerConfig) -> float:
	return maxf(cfg.icon_scale * maxf(dist, 0.001) * tier, 0.05)

## ── Fly-by rendering (Mode 1) ───────────────────────────────────────
## A close pass swaps the constant-size marker for the real 3D mesh so a
## near world reads BIGGER than distant markers. Starts at the marker's
## world size (seamless swap) and grows to full hero as the ship passes.
const FLYBY_FAR_X := 14.0    ## dist/hero where the mesh starts appearing
const FLYBY_NEAR_X := 5.0    ## dist/hero where the mesh is full hero size
## The camera must NEVER enter the mesh: a course that passes right through a
## world (worlds are points — nothing is dodged) would put the camera inside
## a back-face-culled sphere, so the planet grows huge then just VANISHES.
## Cap the mesh radius at a fraction of the camera distance instead: the
## closest pass reads as a big world sliding past (~⅓ of the glass), never
## a full-screen wall and never a clip-through.
const FLYBY_CLEARANCE := 0.30   ## max mesh radius as a fraction of camera dist

static func flyby_mesh_scale(dist: float, hero: float, marker_world: float) -> float:
	var x: float = dist / maxf(hero, 0.001)
	if x >= FLYBY_FAR_X:
		return 0.0
	var u: float = clampf((FLYBY_FAR_X - x) / (FLYBY_FAR_X - FLYBY_NEAR_X), 0.0, 1.0)
	var s: float = lerpf(minf(marker_world, hero), hero, smoothstep(0.0, 1.0, u))
	return minf(s, dist * FLYBY_CLEARANCE)

## ── Presentation pacing (Mode 1) ────────────────────────────────────
## Playback rate over path fraction u: wall time is bounded so an outer hop
## (Uranus) never drags, with a gentle launch ramp and a soft final brake.
## The sim clock stays synced to path position — only pacing changes.
const WALL_TIME_FACTOR := 0.55
const WALL_MIN_S := 10.0
const WALL_MAX_S := 26.0

static func flight_play_rate(u: float, duration: float) -> float:
	var wall: float = clampf(duration * WALL_TIME_FACTOR, WALL_MIN_S, WALL_MAX_S)
	var base: float = maxf(duration, 0.001) / wall
	var launch: float = lerpf(0.55, 1.0, smoothstep(0.0, 0.12, u))
	var brake: float = lerpf(1.0, 0.42, smoothstep(0.80, 1.0, u))
	return base * launch * brake

## ── Real-scale reconstruction (Mode 2 honest rendering) ─────────────
## The nav sim runs on compressed radii. To render what the cockpit would
## ACTUALLY see we decompress positions back to real AU (same angles) and
## compute true angular sizes from real_radius_km and true relative
## brightness from inverse-square sun/ship distances. Nothing faked.
const KM_PER_AU := 1.495978707e8
## Reference reflected flux: Venus near closest approach (R=6052 km,
## d_sun=0.72 AU, d_ship=0.28 AU) — the brightest planet in our sky = 1.0.
const BRIGHTNESS_REF := 9.0e8

static func decompress_radius_au(r_sim: float, cfg: SolarFlyerConfig) -> float:
	var u: float = (r_sim - cfg.distance_base) / maxf(cfg.distance_span, 0.001)
	if u <= 0.0:
		return 0.0
	return pow(minf(u, 1.0), 1.0 / maxf(cfg.compression_exp, 0.001)) * cfg.a_max_au

static func real_pos_au(sim_pos: Vector3, cfg: SolarFlyerConfig) -> Vector3:
	var r: float = sim_pos.length()
	if r < 0.0001:
		return Vector3.ZERO
	return sim_pos / r * decompress_radius_au(r, cfg)

## Half-angle subtended by a body (radians). Floor keeps the destination
## finite when ship and planet decompress to nearly the same point.
static func apparent_radius_rad(radius_km: float, dist_au: float) -> float:
	var d_km: float = maxf(dist_au * KM_PER_AU, radius_km * 2.5)
	return atan(radius_km / d_km)

## Reflected-light flux relative to Venus at its brightest (1.0). Purely
## geometric (albedo/phase ignored) — monotonic and honest.
static func apparent_brightness(radius_km: float, d_sun_au: float,
		d_ship_au: float) -> float:
	var den: float = maxf(
		d_sun_au * d_sun_au * d_ship_au * d_ship_au, 1.0e-12)
	return (radius_km * radius_km) / den / BRIGHTNESS_REF

## Display alpha 0..1 from relative flux, log-scaled: Venus-bright = 1,
## a thousandth of Venus fades to invisible (below → don't render at all).
static func brightness_alpha(flux: float) -> float:
	if flux <= 0.0:
		return 0.0
	return clampf((log(flux) / log(10.0) + 3.0) / 3.0, 0.0, 1.0)

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

## Full plot package for destination select (Beat A) — SIM-FIRST.
## 1. Intercept: solve the arrival time so the course ends ON the
##    destination's parking sphere (orbit standoff) exactly when the planet
##    gets there. The Sun is a fixed target at a radial standoff.
## 2. Geometry: a transfer arc that sweeps around the Sun between the two
##    orbits (build_course) — real curved trajectory, no hand-drawn swerves,
##    and NO collision dodging: worlds are points and space is empty.
## 3. Simulation: the whole hop runs at SIM_DT; the timeline (positions,
##    headings, phase events, orbit entry) is ground truth for the renderer.
## Invariant: duration == t_arr — wall-clock flight and orbital clock agree.
##
## The intercept solves f(T) = burn_time(course_length(T)) − T = 0: the time
## physics needs to fly the course must equal the time the planet needs to
## reach its end. A damped fixed-point iteration is NOT contractive for fast
## inner planets (Mercury laps faster than we fly), so we scan T for the
## first sign change and bisect — always converges, honest endpoint.
static func plot_route(ship_pos: Vector3, target: Dictionary, t0: float,
		cfg: SolarFlyerConfig, depart_standoff: float = 0.0) -> Dictionary:
	var star: bool = bool(target.get("is_star", false))
	var dest_stand: float = sun_approach_standoff(cfg) if star \
		else orbit_standoff(float(target.get("hero_r", 2.0)))
	var fixed_arrival := Vector3.ZERO
	if star:
		var radial := ship_pos if ship_pos.length() > 0.001 else Vector3.RIGHT
		fixed_arrival = radial.normalized() * dest_stand

	var t_max: float = burn_travel_time(ship_pos.length()
		+ float(target.get("orbit_r", 0.0)) + dest_stand + 60.0, cfg) + 4.0
	var lo: float = 0.05
	var hi: float = -1.0
	var prev_t: float = lo
	var prev_err: float = _hop_err(prev_t, ship_pos, target, t0, cfg,
		depart_standoff, dest_stand, fixed_arrival, star)
	var scan_steps := 48
	for k in range(1, scan_steps + 1):
		var t: float = lo + (t_max - lo) * float(k) / float(scan_steps)
		var err: float = _hop_err(t, ship_pos, target, t0, cfg,
			depart_standoff, dest_stand, fixed_arrival, star)
		if prev_err > 0.0 and err <= 0.0:
			lo = prev_t
			hi = t
			break
		prev_t = t
		prev_err = err
	var t_fly: float = t_max
	if hi > 0.0:
		for _i in 32:
			var mid: float = (lo + hi) * 0.5
			if _hop_err(mid, ship_pos, target, t0, cfg, depart_standoff,
					dest_stand, fixed_arrival, star) > 0.0:
				lo = mid
			else:
				hi = mid
		t_fly = (lo + hi) * 0.5
	var planet_arr := fixed_arrival if star else body_pos(target, t0 + t_fly)
	var curve := build_course(ship_pos,
		_hop_entry(planet_arr, ship_pos, dest_stand, star),
		cfg.course_samples, depart_standoff)
	var sim := simulate_route(curve, target, t0, t_fly, cfg)
	return {
		"arrival_pos": planet_arr,
		"t_arr": t_fly,
		"curve": curve,
		"path_len": curve.get_baked_length(),
		"duration": t_fly,
		"min_sun_dist": float(sim["min_sun_dist"]),
		"timeline": sim["timeline"],
	}

## Course endpoint for a planet at planet_arr: the point of its parking
## sphere on the ship's side of the planet. Stars are already aimed at a
## fixed standoff. The course ALWAYS ends on the sphere — at a close
## conjunction (ship already inside the sphere) the hop is the short leg
## outward to it. Length |d − standoff| is continuous in T, so the intercept
## root-finder stays honest; only d ≈ 0 (ship at the planet's center) would
## flip the bearing, and that never occurs.
static func _hop_entry(planet_arr: Vector3, ship_pos: Vector3,
		dest_stand: float, star: bool) -> Vector3:
	if star:
		return planet_arr
	var app := planet_arr - ship_pos
	var d: float = app.length()
	if d < 0.001:
		return planet_arr
	return planet_arr - app.normalized() * dest_stand

## Intercept residual at candidate flight time T. Full-sample geometry so the
## solved time matches the final course length EXACTLY (duration honesty).
static func _hop_err(T: float, ship_pos: Vector3, target: Dictionary, t0: float,
		cfg: SolarFlyerConfig, depart_standoff: float,
		dest_stand: float, fixed_arrival: Vector3, star: bool) -> float:
	var planet_arr := fixed_arrival if star else body_pos(target, t0 + T)
	var c := build_course(ship_pos,
		_hop_entry(planet_arr, ship_pos, dest_stand, star),
		cfg.course_samples, depart_standoff)
	return burn_travel_time(c.get_baked_length(), cfg) - T

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

## Belt rock ENCOUNTER — a per-flight cinematic, not persistent scenery.
## The only belt objects the game tracks (marks, meshes, narrates) are the
## three NAMED asteroids; the field itself is a sparse handful of small dark
## rocks — plus one big one that drifts by — procedurally scattered around
## the flown path wherever it crosses the ring, with a fresh seed every
## flight so each passthrough looks different. Rendering the whole ring
## looked ridiculous; a few rocks sliding past make the real objects matter.
## Every rock is offset ≥ BELT_ROCK_CLEARANCE perpendicular to the course,
## so the pre-determined array can never collide with the camera.
const BELT_CORRIDOR := 45.0        ## path-to-ring distance that counts as a crossing
const BELT_ROCK_CLEARANCE := 5.0
const BELT_ROCKS_SMALL := 26
const BELT_ROCKS_BIG := 1

static func belt_encounter_transforms(path: PackedVector3Array, ring_r: float,
		seed: int) -> Array:
	var out: Array = []
	if path.size() < 2 or ring_r <= 0.001:
		return out
	# Contiguous stretch of the flown path inside the ring corridor.
	var i0 := -1
	var i1 := -1
	for i in path.size():
		if belt_band_dist(path[i], ring_r) < BELT_CORRIDOR:
			if i0 < 0:
				i0 = i
			i1 = i
	if i0 < 0 or i1 <= i0:
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for k in BELT_ROCKS_SMALL + BELT_ROCKS_BIG:
		var big: bool = k >= BELT_ROCKS_SMALL
		var i: int = rng.randi_range(i0, maxi(i1 - 1, i0))
		var f: Vector3 = path[mini(i + 1, path.size() - 1)] - path[i]
		f = f.normalized() if f.length() > 0.001 else Vector3.RIGHT
		var side: Vector3 = f.cross(Vector3.UP)
		if side.length() < 0.5:
			side = Vector3.RIGHT
		side = side.normalized()
		# Offset strictly perpendicular to the local course direction: the
		# rock glides past the window, never through it.
		var ang: float = rng.randf() * TAU
		var off: Vector3 = side * cos(ang) + Vector3.UP * sin(ang)
		var r_off: float = rng.randf_range(8.0, 14.0) if big \
			else rng.randf_range(BELT_ROCK_CLEARANCE, 30.0)
		var s: float = rng.randf_range(3.2, 4.8) if big \
			else rng.randf_range(0.25, 1.0)
		var xf := Transform3D.IDENTITY.scaled(
			Vector3(s, s * rng.randf_range(0.6, 1.1), s))
		xf.origin = path[i] + off * r_off
		out.append(xf)
	return out

extends SceneTree
## Headless logic tests for the Solar System Explorer preview.
##   godot --headless --path . -s res://tests/run_tests.gd
## Exit code 0 = all passed; 1 = failures. Also force-loads every view script so
## a compile error anywhere fails the run (headless can't render the scenes).

## Preloaded (not class_name lookups) so headless runs see fresh classes
## before the editor rescans the global class cache.
const NavModes := preload("res://scripts/NavModes.gd")
const PlaygroundScene := preload("res://scripts/PlaygroundScene.gd")

var _pass := 0
var _fail := 0

func _init() -> void:
	call_deferred("_run")

func _ok(cond: bool, msg: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: ", msg)

func _run() -> void:
	print("======== Solar System Explorer tests ========")
	_test_data()
	_test_belt_asteroids()
	_test_layout()
	_test_orbit_math()
	_test_flight()
	_test_scale_tune()
	_test_cockpit_hud()
	_test_ux_cruise()
	_test_nav_modes()
	_test_narration_vo()
	_test_realism_budget()
	_test_astrogator_panel()
	_test_scripts_compile()
	print("======== TOTAL: %d passed, %d failed ========" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)

func _test_data() -> void:
	var bodies := SolarData.bodies()
	_ok(bodies.size() == 11, "11 bodies (Sun + 8 planets + asteroid belt + Pluto)")

	var ids := {}
	for b in bodies:
		ids[b["id"]] = true
		_ok(not str(b["blurb"]).is_empty(), "%s has a blurb" % b["id"])
		_ok((b.get("facts", []) as Array).size() >= 1, "%s has facts" % b["id"])
	_ok(ids.size() == 11, "all body ids unique")
	_ok(ids.has("sun") and ids.has("earth") and ids.has("pluto"), "key ids present")
	_ok(ids.has("asteroid_belt"), "asteroid belt present")

	var pluto := _by_id(bodies, "pluto")
	_ok(bool(pluto.get("dwarf", false)), "Pluto flagged as dwarf")
	var sun := _by_id(bodies, "sun")
	_ok(bool(sun.get("is_star", false)), "Sun flagged as star")

	var belt := SolarData.belt()
	_ok(bool(belt.get("belt", false)), "belt() returns the flagged belt body")
	_ok(str(belt.get("id", "")) == "asteroid_belt", "belt id is asteroid_belt")

	var order := _id_order(bodies)
	_ok(order.find("asteroid_belt") > order.find("mars"), "belt after Mars in strip")
	_ok(order.find("asteroid_belt") < order.find("jupiter"), "belt before Jupiter in strip")

	var orbiting := SolarData.orbiting()
	_ok(orbiting.size() == 8, "exactly 8 planets orbit in the orrery")
	_ok(not _contains_id(orbiting, "sun"), "Sun does not orbit itself")
	_ok(not _contains_id(orbiting, "pluto"), "Pluto not in orrery tour")
	_ok(not _contains_id(orbiting, "asteroid_belt"), "belt is not a single orbiting disc")
	for i in orbiting.size() - 1:
		_ok(float(orbiting[i]["orrery_rx"]) < float(orbiting[i + 1]["orrery_rx"]),
			"orbit radii increase outward at %d" % i)

	var tour := SolarData.tour_sequence()
	_ok(tour.size() == 9, "narrated tour is 8 planets + asteroid belt")
	_ok(_contains_id(tour, "asteroid_belt"), "belt is narrated in the tour")
	_ok(not _contains_id(tour, "sun") and not _contains_id(tour, "pluto"),
		"tour excludes Sun and Pluto")

func _test_belt_asteroids() -> void:
	## Phase 5 — named worlds in the belt; the ring itself is not a destination.
	var cfg := SolarFlyerConfig.load_default()
	var asts := SolarData.major_asteroids()
	_ok(asts.size() == 3, "three major asteroids (Ceres, Vesta, Psyche)")
	for a in asts:
		_ok(bool(a.get("major_asteroid", false)), "%s flagged major_asteroid" % a["id"])
		_ok(not str(a.get("blurb", "")).is_empty(), "%s has a blurb" % a["id"])
		_ok((a.get("facts", []) as Array).size() >= 1, "%s has facts" % a["id"])
		_ok(not str(a.get("belt_hook", "")).is_empty(), "%s has a belt hook" % a["id"])
	_ok(str(asts[0]["id"]) == "ceres" and bool(asts[0].get("dwarf", false)),
		"Ceres is the dwarf planet")

	# Strip stays clean: asteroids live in the flyer, not the scroll strip.
	_ok(SolarData.bodies().size() == 11, "scroll strip unchanged (11 bodies)")
	var by_id := {}
	for b in SolarData.flyer_bodies(cfg):
		by_id[str(b["id"])] = b
	for want in ["ceres", "vesta", "psyche"]:
		_ok(by_id.has(want), "%s in flyer bodies" % want)

	# Belt ring is not a destination; each asteroid is.
	var dest_ids := {}
	for d in SolarData.flyer_destinations(cfg):
		dest_ids[str(d["id"])] = true
	_ok(not dest_ids.has("asteroid_belt"), "belt ring is not a destination")
	for want in ["ceres", "vesta", "psyche"]:
		_ok(dest_ids.has(want), "%s is a destination" % want)

	# Asteroids read smaller than every planet, and sit inside the belt band.
	var merc_hero: float = float(by_id["mercury"]["hero_r"])
	var belt_r: float = float(by_id["asteroid_belt"]["orbit_r"])
	for want in ["ceres", "vesta", "psyche"]:
		_ok(float(by_id[want]["hero_r"]) < merc_hero,
			"%s hero smaller than Mercury" % want)
		_ok(absf(float(by_id[want]["orbit_r"]) - belt_r) < belt_r * 0.2,
			"%s orbits near the belt ring" % want)

	# theta0 spread: the three rocks never bunch up (nearest varies by epoch).
	var t0s := [float(by_id["ceres"]["theta0"]), float(by_id["vesta"]["theta0"]),
		float(by_id["psyche"]["theta0"])]
	_ok(absf(t0s[0] - t0s[1]) > 0.8 and absf(t0s[1] - t0s[2]) > 0.8
		and absf(t0s[0] - t0s[2]) > 0.8, "asteroid start angles spread out")

	# Belt-tap resolution: nearest by real position, exclusion respected.
	var near_ceres := OrbitMath.body_pos(by_id["ceres"], 0.0) * 1.02
	_ok(SolarData.nearest_major_asteroid(near_ceres, 0.0, cfg) == "ceres",
		"resolution picks the nearest asteroid")
	var resolved_excl := SolarData.nearest_major_asteroid(near_ceres, 0.0, cfg, "ceres")
	_ok(resolved_excl != "ceres" and not resolved_excl.is_empty(),
		"resolution skips the parked-at asteroid")

	# Belt intro narration carries the name and the hook.
	var intro := OrbitMath.belt_intro_sentence(by_id["vesta"])
	_ok(intro.find("Vesta") >= 0, "belt intro names the asteroid")
	_ok(intro.find("Everest") >= 0, "belt intro speaks the hook")
	_ok(intro.find("between Mars and Jupiter") >= 0, "belt intro teaches the belt")

	# Reveal knobs: fade band ordered.
	_ok(cfg.belt_fade_near > 0.0 and cfg.belt_fade_near < cfg.belt_fade_far,
		"belt fade band ordered")

	# Rock ENCOUNTER: a per-flight cinematic scattered around the flown path
	# where it crosses the ring — sparse, seeded, never colliding.
	var ring_r: float = float(by_id["asteroid_belt"]["orbit_r"])
	var path := PackedVector3Array()
	for i in 121:
		path.append(Vector3(
			lerpf(-ring_r - 60.0, ring_r + 60.0, float(i) / 120.0), 0.0, 3.0))
	var rocks := OrbitMath.belt_encounter_transforms(path, ring_r, 777)
	_ok(rocks.size() == OrbitMath.BELT_ROCKS_SMALL + OrbitMath.BELT_ROCKS_BIG,
		"crossing spawns the sparse rock handful")
	var min_clear := INF
	var big_scale := 0.0
	for xf: Transform3D in rocks:
		big_scale = maxf(big_scale, xf.basis.get_scale().x)
		var dmin := INF
		for p in path:
			dmin = minf(dmin, (xf.origin - p).length())
		min_clear = minf(min_clear, dmin)
	_ok(min_clear >= OrbitMath.BELT_ROCK_CLEARANCE - 1.5,
		"every rock clear of the flown path (min %.1f)" % min_clear)
	_ok(big_scale >= 3.0, "one big rock drifts by (scale %.1f)" % big_scale)
	var rocks_b := OrbitMath.belt_encounter_transforms(path, ring_r, 777)
	_ok((rocks[0] as Transform3D).origin.is_equal_approx((rocks_b[0] as Transform3D).origin),
		"encounter deterministic for a fixed seed")
	var rocks_c := OrbitMath.belt_encounter_transforms(path, ring_r, 778)
	_ok(not (rocks[0] as Transform3D).origin.is_equal_approx((rocks_c[0] as Transform3D).origin),
		"a fresh seed gives a different passthrough")
	# A course nowhere near the ring spawns nothing.
	var path_in := PackedVector3Array()
	for i in 40:
		path_in.append(Vector3(lerpf(20.0, 60.0, float(i) / 39.0), 0.0, 0.0))
	_ok(OrbitMath.belt_encounter_transforms(path_in, ring_r, 777).is_empty(),
		"no rocks away from the ring")

func _test_layout() -> void:
	var layout := SolarData.scroll_layout()
	var xs: Array = layout["xs"]
	_ok(xs.size() == 11, "one scroll x per body")
	for i in xs.size() - 1:
		_ok(float(xs[i]) < float(xs[i + 1]), "scroll xs strictly increasing at %d" % i)
	_ok(float(layout["width"]) > float(xs[xs.size() - 1]), "strip width past last body")

func _test_orbit_math() -> void:
	var cfg := SolarFlyerConfig.new()
	var flyers := SolarData.flyer_bodies(cfg)
	_ok(flyers.size() == 14, "flyer_bodies returns 14 (11 + 3 major asteroids)")

	var by_id := {}
	for b in flyers:
		by_id[b["id"]] = b
		_ok(b.has("orbit_r") and b.has("omega") and b.has("hero_r"),
			"%s has flyer fields" % b["id"])

	var sun: Dictionary = by_id["sun"]
	_ok(float(sun["orbit_r"]) == 0.0 and float(sun["omega"]) == 0.0, "Sun at origin")
	_ok(float(by_id["mercury"]["orbit_r"]) < float(by_id["earth"]["orbit_r"]),
		"Mercury inside Earth")
	_ok(float(by_id["earth"]["orbit_r"]) < float(by_id["jupiter"]["orbit_r"]),
		"Earth inside Jupiter")
	_ok(float(by_id["jupiter"]["orbit_r"]) < float(by_id["neptune"]["orbit_r"]),
		"Jupiter inside Neptune")
	_ok(float(by_id["pluto"]["orbit_r"]) > float(by_id["neptune"]["orbit_r"]) * 0.9,
		"Pluto at outer rim")
	_ok(float(by_id["jupiter"]["hero_r"]) > float(by_id["mercury"]["hero_r"]),
		"Jupiter hero bigger than Mercury")

	# body_pos determinism
	var earth: Dictionary = by_id["earth"]
	var p0 := OrbitMath.body_pos(earth, 0.0)
	var p1 := OrbitMath.body_pos(earth, 0.0)
	_ok(p0.is_equal_approx(p1), "body_pos deterministic")
	_ok(is_equal_approx(p0.y, 0.0), "coplanar y=0")
	_ok(p0.length() > 0.0, "Earth not at origin")

	# Intercept converges for every planetary destination from Earth.
	var ship := OrbitMath.body_pos(earth, 0.0)
	for b in SolarData.flyer_destinations(cfg):
		if str(b["id"]) == "earth" or bool(b.get("is_star", false)):
			continue
		var hit := OrbitMath.solve_intercept(ship, b, 0.0, cfg.cruise_speed, cfg.intercept_iters)
		_ok(float(hit["t_arr"]) > 0.0, "intercept t_arr > 0 for %s" % b["id"])
		var route := OrbitMath.plot_route(ship, b, 0.0, cfg)
		_ok(route["curve"] is Curve3D, "route curve for %s" % b["id"])
		_ok(float(route["min_sun_dist"]) >= cfg.sun_clearance * 0.5,
			"course clears Sun for %s (min=%.1f)" % [b["id"], float(route["min_sun_dist"])])
		_ok(float(route["duration"]) >= cfg.hop_min_s - 0.01, "hop >= min for %s" % b["id"])
		_ok(float(route["duration"]) <= cfg.hop_max_s + 0.01, "hop <= max for %s" % b["id"])

	# Sun hop: approach a safe standoff, never the star's center.
	var route_sun := OrbitMath.plot_route(ship, by_id["sun"], 0.0, cfg)
	var sun_end: Vector3 = OrbitMath.path_sample(route_sun["curve"], 1.0)
	var stand := OrbitMath.sun_approach_standoff(cfg)
	_ok(absf(sun_end.length() - stand) < 1.0, "Sun hop ends at standoff (%.1f ≈ %.1f)" % [
		sun_end.length(), stand])
	_ok(float(route_sun["min_sun_dist"]) >= stand * 0.9, "Sun hop never dives inside standoff")
	var narr_sun := OrbitMath.trip_narration(earth, by_id["sun"], route_sun, cfg)
	_ok(narr_sun.find("can't land") >= 0 or narr_sun.find("safe distance") >= 0,
		"Sun trip narration explains no landing")
	var arr_sun := OrbitMath.arrival_narration("The Sun", 1.0, true)
	_ok(arr_sun.find("too hot") >= 0, "Sun arrival explains heat / no landing")

	# Marker size rule: markers are MARKERS — a legible constant screen size
	# with recognition tiers, REGARDLESS of proximity. No scale model, no
	# proximity bump: the size at parking distance equals the size at cruise.
	var hero: float = float(by_id["mars"]["hero_r"])
	var stand_m := OrbitMath.orbit_standoff(hero)
	var scr_near := OrbitMath.marker_world_size(stand_m, 0.8, cfg) / stand_m
	var scr_far := OrbitMath.marker_world_size(4000.0, 0.8, cfg) / 4000.0
	_ok(absf(scr_near - scr_far) < 0.001,
		"marker screen size identical at parking distance and deep cruise")
	# Even at the parking standoff the marker still reads far away.
	var w_max := OrbitMath.marker_world_size(stand_m, 2.0, cfg)
	_ok(w_max / stand_m < 0.12, "marker still reads far away up close")

	# Recognition tiers: Earth-class is the 1.0 legible baseline; Jupiter
	# reads exactly DOUBLE Earth; monotonic vs real radius.
	# Tiers track ScrollView draw_radius / 54 (Earth).
	_ok(is_equal_approx(SolarData.icon_tier_for(by_id["earth"]), 1.0), "Earth icon tier 1.0")
	_ok(is_equal_approx(SolarData.icon_tier_for(by_id["jupiter"]), 112.0 / 54.0),
		"Jupiter icon tier = draw_radius ratio")
	_ok(is_equal_approx(SolarData.icon_tier_for(by_id["saturn"]), 94.0 / 54.0),
		"Saturn icon tier = draw_radius ratio")
	_ok(SolarData.icon_tier_for(by_id["jupiter"])
		>= SolarData.icon_tier_for(by_id["earth"]) * 2.0,
		"Jupiter marker reads at least double Earth")
	_ok(is_equal_approx(SolarData.icon_tier_for(by_id["mercury"]), 34.0 / 54.0),
		"Mercury icon tier = draw_radius ratio")
	_ok(is_equal_approx(SolarData.icon_tier_for(by_id["neptune"]), 68.0 / 54.0),
		"Neptune icon tier = draw_radius ratio")
	_ok(is_equal_approx(SolarData.icon_tier_for(by_id["sun"]), 150.0 / 54.0),
		"Sun icon tier = draw_radius ratio")
	_ok(PlanetSkins.has_pixel_marker("earth") and PlanetSkins.has_pixel_marker("jupiter"),
		"baked pixel AR markers exist for Earth and Jupiter")
	var prev_tier := -1.0
	var order_r := ["pluto", "mercury", "mars", "venus", "earth", "neptune",
		"uranus", "saturn", "jupiter"]
	var tier_mono := true
	for oid in order_r:
		var tr: float = SolarData.icon_tier_for(by_id[oid])
		if tr < prev_tier - 0.001:
			tier_mono = false
		prev_tier = tr
	_ok(tier_mono, "icon tiers monotonic vs real radius")

	# Markers hold constant screen size: world size ∝ distance.
	var iw_near := OrbitMath.marker_world_size(500.0, 1.0, cfg)
	var iw_far := OrbitMath.marker_world_size(2000.0, 1.0, cfg)
	_ok(absf(iw_far / iw_near - 4.0) < 0.05,
		"marker world size scales with distance (constant screen size)")
	# The Sun's marker outranks every planet's, slightly.
	_ok(SolarData.icon_tier_for(by_id["sun"]) > SolarData.icon_tier_for(by_id["jupiter"]),
		"Sun marker tier tops the chart")

	# Mercury is fast — intercept still finite.
	var merc: Dictionary = by_id["mercury"]
	var hit_m := OrbitMath.solve_intercept(ship, merc, 0.0, cfg.cruise_speed, 4)
	_ok(is_finite(float(hit_m["t_arr"])), "Mercury intercept finite")

	# Plot-board instrument API: OrreryBodies PLOT mode + hit targets.
	var board := OrreryBodies.new()
	board.cfg = cfg
	board.set_mode(OrreryBodies.Mode.PLOT)
	board.ship_id = "earth"
	var route := OrbitMath.plot_route(ship, by_id["mars"], 0.0, cfg)
	board.set_route("mars", route, 0.0)
	_ok(board.dest_id == "mars", "plot board stores dest")
	_ok(not board.route.is_empty(), "plot board stores route")
	board.ff_u = 1.0
	board.course_draw_u = 1.0
	var mars_screen: Vector2 = board._body_screen(by_id["mars"], float(route["t_arr"]))
	_ok(board.hit_test(mars_screen) == "mars", "plot board hits Mars at intercept")
	board.clear_route()
	_ok(board.dest_id == "" and board.route.is_empty(), "clear_route resets")
	board.free()

func _test_flight() -> void:
	## Phase 3 — autopilot flight math (no GPU / display required).
	var cfg := SolarFlyerConfig.new()
	var by_id := {}
	for b in SolarData.flyer_bodies(cfg):
		by_id[b["id"]] = b
	var earth: Dictionary = by_id["earth"]
	var ship := OrbitMath.body_pos(earth, 0.0)

	# Ease curve endpoints + mid behaviour.
	_ok(is_equal_approx(OrbitMath.ease_cubic_inout(0.0), 0.0), "ease(0)=0")
	_ok(is_equal_approx(OrbitMath.ease_cubic_inout(1.0), 1.0), "ease(1)=1")
	_ok(OrbitMath.ease_cubic_inout(0.5) > 0.4 and OrbitMath.ease_cubic_inout(0.5) < 0.6,
		"ease mid near 0.5")
	_ok(OrbitMath.ease_cubic_inout(0.25) < 0.25, "ease accelerates from rest")

	# ── Burn profile (accelerate → coast → flip-and-brake) ──
	var d_tri: float = cfg.v_max * cfg.v_max / cfg.burn_accel * 0.5   # triangular
	var d_trap: float = cfg.v_max * cfg.v_max / cfg.burn_accel * 3.0  # trapezoid
	_ok(is_equal_approx(OrbitMath.burn_travel_time(d_tri, cfg),
		2.0 * sqrt(d_tri / cfg.burn_accel)), "triangular hop time exact")
	_ok(is_equal_approx(OrbitMath.burn_travel_time(d_trap, cfg),
		d_trap / cfg.v_max + cfg.v_max / cfg.burn_accel), "trapezoid hop time exact")
	var d_edge: float = cfg.v_max * cfg.v_max / cfg.burn_accel
	_ok(absf(OrbitMath.burn_travel_time(d_edge * 0.999, cfg)
		- OrbitMath.burn_travel_time(d_edge * 1.001, cfg)) < 0.1,
		"profile continuous at triangular/trapezoid threshold")
	_ok(OrbitMath.burn_peak_speed(d_tri, cfg) < cfg.v_max, "short hop never reaches v_max")
	_ok(is_equal_approx(OrbitMath.burn_peak_speed(d_trap, cfg), cfg.v_max),
		"long hop caps at v_max")
	for dd in [d_tri, d_trap]:
		var tot: float = OrbitMath.burn_travel_time(dd, cfg)
		_ok(is_equal_approx(OrbitMath.burn_dist_at(0.0, dd, cfg), 0.0), "burn s(0)=0")
		_ok(absf(OrbitMath.burn_dist_at(tot, dd, cfg) - dd) < 0.01, "burn s(T)=d")
		var prev := -1.0
		var mono := true
		for i in 21:
			var s: float = OrbitMath.burn_dist_at(tot * float(i) / 20.0, dd, cfg)
			if s < prev - 0.001:
				mono = false
			prev = s
		_ok(mono, "burn s(t) monotonic")
	_ok(is_equal_approx(OrbitMath.burn_progress(0.0, d_trap, cfg), 0.0), "burn progress(0)=0")
	_ok(is_equal_approx(OrbitMath.burn_progress(1.0, d_trap, cfg), 1.0), "burn progress(1)=1")
	_ok(OrbitMath.burn_progress(0.15, d_trap, cfg) < 0.15,
		"burn progress starts slower than time (accelerating)")
	_ok(OrbitMath.burn_phase(0.02, d_trap, cfg) == OrbitMath.PHASE_BURN, "launch phase BURN")
	_ok(OrbitMath.burn_phase(0.5, d_trap, cfg) == OrbitMath.PHASE_COAST, "mid phase COAST")
	_ok(OrbitMath.burn_phase(0.98, d_trap, cfg) == OrbitMath.PHASE_BRAKE, "arrival phase BRAKE")
	_ok(OrbitMath.burn_phase(0.5, d_tri, cfg) != OrbitMath.PHASE_COAST,
		"triangular hop has no coast")

	# duration == t_arr for every planetary hop (the clock-honesty invariant),
	# and the solved time matches the final course length within tolerance.
	for b in SolarData.flyer_destinations(cfg):
		if str(b["id"]) == "earth":
			continue
		var route_b := OrbitMath.plot_route(ship, b, 0.0, cfg)
		_ok(is_equal_approx(float(route_b["duration"]), float(route_b["t_arr"])),
			"duration == t_arr for %s" % b["id"])
		var t_len: float = OrbitMath.burn_travel_time(float(route_b["path_len"]), cfg)
		_ok(absf(t_len - float(route_b["t_arr"])) < 2.0,
			"intercept time near course time for %s (Δ%.2fs)" % [
				b["id"], absf(t_len - float(route_b["t_arr"]))])

	# ── Physics course + navigation simulation (sim-first, STRATEGY §3) ──
	# burn_time_at_dist inverts burn_dist_at.
	var d_inv: float = 180.0
	for frac in [0.1, 0.35, 0.5, 0.8, 0.95]:
		var s_q: float = d_inv * float(frac)
		var t_q := OrbitMath.burn_time_at_dist(s_q, d_inv, cfg)
		_ok(absf(OrbitMath.burn_dist_at(t_q, d_inv, cfg) - s_q) < 0.05,
			"burn_time_at_dist inverts s(t) at %.2f" % frac)
	# A physics course is a TRANSFER ARC, never a straight line: the bearing
	# sweeps around the Sun while the radius eases between the two orbits.
	var arc := OrbitMath.build_course(Vector3(60, 0, 0), Vector3(90, 0, 40), 48, 0.0)
	var chord_a: Vector3 = arc.get_point_position(0)
	var chord_dir: Vector3 = (arc.get_point_position(48) - chord_a).normalized()
	var dev_max := 0.0
	for i in 49:
		var rel: Vector3 = arc.get_point_position(i) - chord_a
		dev_max = maxf(dev_max, (rel - chord_dir * rel.dot(chord_dir)).length())
	_ok(dev_max > 1.0, "course curves like a real transfer, not a line (dev %.1f)" % dev_max)
	_ok(arc.get_point_position(48).distance_to(Vector3(90, 0, 40)) < 0.01,
		"transfer arc ends exactly at the intercept point")
	# Radius bounded by the endpoint orbits, in-plane: the arc can never dive
	# at the Sun, so no clearance bow is needed or drawn.
	var r_lo := minf(chord_a.length(), arc.get_point_position(48).length())
	var r_hi := maxf(chord_a.length(), arc.get_point_position(48).length())
	var radius_ok := true
	var planar_ok := true
	for i in 49:
		var p: Vector3 = arc.get_point_position(i)
		if p.length() < r_lo - 0.5 or p.length() > r_hi + 0.5:
			radius_ok = false
		if absf(p.y) > 0.001:
			planar_ok = false
	_ok(radius_ok, "arc radius stays between the endpoint orbits (Sun-safe)")
	_ok(planar_ok, "arc stays in the ecliptic plane")
	# Opposite side of the Sun: the arc sweeps AROUND, never through.
	var around := OrbitMath.build_course(Vector3(60, 0, 0), Vector3(-90, 0, 4), 48, 0.0)
	_ok(OrbitMath.course_min_sun_dist(around) >= 59.0,
		"antipodal hop sweeps around the Sun (min %.1f)" %
		OrbitMath.course_min_sun_dist(around))

	# Every hop from Earth with the full sim: the timeline is honest
	# (monotonic, ends on the parking sphere), carries only burn-phase
	# events, and nothing narrated is derived outside the sim.
	for b in SolarData.flyer_destinations(cfg):
		if str(b["id"]) == "earth":
			continue
		var route_s := OrbitMath.plot_route(ship, b, 0.0, cfg, 0.0)
		_ok(is_equal_approx(float(route_s["duration"]), float(route_s["t_arr"])),
			"simulated route keeps duration == t_arr for %s" % b["id"])
		var tl: Dictionary = route_s["timeline"]
		var tl_pos: PackedVector3Array = tl["pos"]
		var tl_fwd: PackedVector3Array = tl["fwd"]
		_ok(tl_pos.size() >= 2 and tl_pos.size() == tl_fwd.size(),
			"timeline frames present for %s" % b["id"])
		var frames_expected: int = int(ceil(float(route_s["duration"]) / float(tl["dt"]))) + 1
		_ok(absf(tl_pos.size() - frames_expected) <= 1,
			"timeline covers the whole hop for %s" % b["id"])
		# Playback distance along the hop never runs backwards.
		var s_prev := -1.0
		var mono_tl := true
		for i in tl_pos.size():
			var s_here: float = tl_pos[0].distance_to(tl_pos[i])
			if s_here < s_prev - 0.5:
				mono_tl = false
			s_prev = maxf(s_prev, s_here)
		_ok(mono_tl, "timeline playback monotonic for %s" % b["id"])
		# The timeline ENDS on the destination's parking sphere — orbit entry
		# is a precomputed state, not a live geometric check.
		var entry: Dictionary = tl["entry"]
		var d_stand: float = OrbitMath.sun_approach_standoff(cfg) \
			if bool(b.get("is_star", false)) \
			else OrbitMath.orbit_standoff(float(b.get("hero_r", 2.0)))
		_ok(absf(float(entry["rad"]) - d_stand) < 1.0,
			"entry exactly at parking radius for %s (%.1f vs %.1f)" % [
				b["id"], float(entry["rad"]), d_stand])
		var center_arr := Vector3.ZERO if bool(b.get("is_star", false)) \
			else OrbitMath.body_pos(b, float(route_s["t_arr"]))
		_ok(absf(tl_pos[tl_pos.size() - 1].distance_to(center_arr) - d_stand) < 1.0,
			"timeline end on the parking sphere for %s" % b["id"])
		# Orbit is a hard cut from timeline end — entry only stores ang/dir.
		_ok(entry.has("ang") and entry.has("dir"),
			"entry pose recorded for orbit cut %s" % b["id"])
		_ok(not tl.has("entry_cine") or (tl.get("entry_cine", {}) as Dictionary).is_empty(),
			"no baked course-continuation cinematic for %s" % b["id"])
		# Determinism: replotting the same hop yields the same timeline.
		var route_s2 := OrbitMath.plot_route(ship, b, 0.0, cfg, 0.0)
		var tl2_pos: PackedVector3Array = route_s2["timeline"]["pos"]
		var same := tl2_pos.size() == tl_pos.size()
		if same:
			for i in tl_pos.size():
				if tl_pos[i].distance_to(tl2_pos[i]) > 0.001:
					same = false
					break
		_ok(same, "navigation sim deterministic for %s" % b["id"])
		# No slingshot/steer/hold/flyby claims exist — narration must not lie.
		var narr_s := OrbitMath.trip_narration(earth, b, route_s, cfg)
		_ok(narr_s.find("slingshot") < 0 and narr_s.find("steer wide") < 0
			and narr_s.find("launch window") < 0
			and narr_s.find("fly right past") < 0,
			"no invented maneuver claims for earth→%s" % b["id"])
		# The sim records burn phases and nothing else — no alarms, no
		# detections; every phase sequence is monotonic in time.
		var t_prev := -1.0
		for ev in (tl["events"] as Array):
			_ok(str(ev["kind"]) == "phase",
				"timeline events are phase-only for %s" % b["id"])
			_ok(float(ev["t"]) >= t_prev, "events ordered for %s" % b["id"])
			t_prev = float(ev["t"])

	# BOOST clamps.
	_ok(is_equal_approx(OrbitMath.apply_boost(0.0, 20.0, 0.08), 1.6), "boost nudges 8%")
	_ok(is_equal_approx(OrbitMath.apply_boost(19.0, 20.0, 0.5), 20.0), "boost clamps to duration")

	# Every planetary hop: path endpoints, clock, parking honesty, duration band.
	for b in SolarData.flyer_destinations(cfg):
		if str(b["id"]) == "earth" or bool(b.get("is_star", false)):
			continue
		var route := OrbitMath.plot_route(ship, b, 0.0, cfg)
		var curve: Curve3D = route["curve"]
		var t_arr: float = float(route["t_arr"])
		var arrival: Vector3 = route["arrival_pos"]
		var park_b := OrbitMath.orbit_standoff(float(b["hero_r"]))

		var p_start := OrbitMath.path_sample(curve, 0.0)
		var p_end := OrbitMath.path_sample(curve, 1.0)
		_ok(p_start.distance_to(ship) < 0.5, "path starts at ship for %s" % b["id"])
		# The course ends ON the parking sphere of the intercept point — orbit
		# entry is the last playback frame, never a dive-and-recoil.
		_ok(absf(p_end.distance_to(arrival) - park_b) < 1.0,
			"path ends on the parking sphere for %s (%.1f vs %.1f)" % [
				b["id"], p_end.distance_to(arrival), park_b])

		var clock0 := OrbitMath.flight_clock(0.0, t_arr, 0.0)
		var clock1 := OrbitMath.flight_clock(0.0, t_arr, 1.0)
		_ok(is_equal_approx(clock0, 0.0), "flight clock start for %s" % b["id"])
		_ok(is_equal_approx(clock1, t_arr), "flight clock end for %s" % b["id"])

		# At arrival the ship parks at the standoff (destination fills the
		# canopy from there; the renderer holds it at hero size in orbit).
		var dist_end := OrbitMath.ship_to_dest_dist(curve, 1.0, b, 0.0, t_arr)
		_ok(absf(dist_end - park_b) < 1.5,
			"arrival parks at the standoff for %s (d=%.2f)" % [b["id"], dist_end])

		# Mid-hop: destination still farther than at the end (generally).
		var dist_mid := OrbitMath.ship_to_dest_dist(curve, 0.35, b, 0.0, t_arr)
		_ok(dist_mid > dist_end, "closes on target for %s" % b["id"])

func _test_scale_tune() -> void:
	## Phase 4 — happy-medium contracts for the shipped .tres knobs.
	var cfg := SolarFlyerConfig.load_default()
	_ok(cfg != null, "load_default returns config")
	_ok(is_equal_approx(cfg.burn_accel, 1.1), "shipped burn_accel is 1.1")
	_ok(is_equal_approx(cfg.v_max, 17.0), "shipped v_max is 17")
	_ok(is_equal_approx(cfg.game_year_seconds, 45.0), "shipped game year is 45s")
	_ok(cfg.orbit_time_scale > 0.0 and cfg.orbit_time_scale <= 0.25,
		"orbit rest scale slow but alive (0 < s <= 0.25)")
	_ok(cfg.distance_span >= 300.0, "larger space: distance_span >= 300")
	_ok(cfg.icon_scale > 0.0, "far-visibility angular floor enabled")

	var report := ScaleTune.evaluate(cfg)
	if not bool(report["ok"]):
		for issue in report["issues"]:
			print("  scale issue: ", issue)
	_ok(bool(report["ok"]), "shipped config passes happy-medium checks")
	_ok((report["hops"] as Array).size() >= 9, "scale report covers destinations")

	# Outer hops park exactly at the standoff (orbit entry honesty).
	for h in report["hops"]:
		if str(h["id"]) in ["jupiter", "saturn", "uranus", "neptune", "pluto"]:
			_ok(absf(float(h["d_end"])
				- OrbitMath.orbit_standoff(float(h["hero_r"]))) < 1.5,
				"%s parks at the standoff" % h["id"])

	# Duration variety across the system.
	var durs: Array = []
	for h in report["hops"]:
		durs.append(float(h["duration"]))
	durs.sort()
	_ok(float(durs[durs.size() - 1]) - float(durs[0]) >= 5.0,
		"hop duration span ≥ 5s (got %.1f)" % (float(durs[durs.size() - 1]) - float(durs[0])))
	var floor_hits := 0
	for d in durs:
		if absf(float(d) - cfg.hop_min_s) < 0.05:
			floor_hits += 1
	_ok(floor_hits < durs.size(), "not every hop stuck at hop_min")

	# JSON overlay apply + reject a too-hot burn (hops collapse under hop_min).
	var tuned := cfg.duplicate(true) as SolarFlyerConfig
	ScaleTune.apply_overrides(tuned, {"burn_accel": 40.0, "v_max": 120.0})
	_ok(is_equal_approx(tuned.burn_accel, 40.0), "overlay sets burn_accel")
	var bad := ScaleTune.evaluate(tuned)
	_ok(not bool(bad["ok"]), "too-hot burn fails happy-medium")
	var mentions_dur := false
	for issue in bad["issues"]:
		if str(issue).find("duration") >= 0 or str(issue).find("outside") >= 0 \
				or str(issue).find("variety") >= 0:
			mentions_dur = true
	_ok(mentions_dur, "failure mentions duration band")

	# Markers never grow with proximity: the destination's marker screen size
	# at the end of the hop equals its size at launch (constant, honest).
	var earth := SolarData.flyer_body_by_id("earth", cfg)
	var jup := SolarData.flyer_body_by_id("jupiter", cfg)
	var route := OrbitMath.plot_route(OrbitMath.body_pos(earth, 0.0), jup, 0.0, cfg)
	var tier_j := SolarData.icon_tier_for(jup)
	var d_launch := OrbitMath.ship_to_dest_dist(route["curve"], 0.0, jup, 0.0, route["t_arr"])
	var d_park := OrbitMath.ship_to_dest_dist(route["curve"], 1.0, jup, 0.0, route["t_arr"])
	var scr_launch := OrbitMath.marker_world_size(d_launch, tier_j, cfg) / d_launch
	var scr_park := OrbitMath.marker_world_size(d_park, tier_j, cfg) / d_park
	_ok(absf(scr_launch - scr_park) < 0.001,
		"Jupiter marker holds constant screen size across the whole hop")

func _test_cockpit_hud() -> void:
	## Phase 5 — cockpit asset + icon HUD helpers.
	_ok(ResourceLoader.exists("res://images/cockpit.png"), "cockpit.png present")
	var tex := load("res://images/cockpit.png") as Texture2D
	_ok(tex != null, "cockpit texture loads")
	if tex != null:
		var img: Image = tex.get_image()
		if img == null:
			# Imported textures may need decompress.
			img = tex.get_image()
		_ok(img != null, "cockpit image readable")
		if img != null:
			var w := img.get_width()
			var h := img.get_height()
			_ok(w >= 640 and h >= 360, "cockpit is landscape-ish (%dx%d)" % [w, h])
			# Central canopy should be transparent.
			var clear := 0
			var total := 0
			var cx0 := int(w * 0.22)
			var cx1 := int(w * 0.78)
			var cy0 := int(h * 0.10)
			var cy1 := int(h * 0.58)
			for y in range(cy0, cy1, 4):
				for x in range(cx0, cx1, 4):
					total += 1
					if img.get_pixel(x, y).a < 0.05:
						clear += 1
			var ratio: float = float(clear) / float(maxi(total, 1))
			_ok(ratio >= 0.85, "cockpit window mostly clear (%.0f%%)" % (ratio * 100.0))
			# Frame corners stay opaque.
			_ok(img.get_pixel(8, 8).a > 0.5, "cockpit frame corner opaque")

	_ok(is_equal_approx(CockpitHud.distance_bar_fill(0.0), 1.0), "bar full at launch")
	_ok(is_equal_approx(CockpitHud.distance_bar_fill(1.0), 0.0), "bar empty on arrival")
	_ok(CockpitHud.distance_bar_fill(0.5) > 0.4 and CockpitHud.distance_bar_fill(0.5) < 0.6,
		"bar mid ≈ 0.5")

	var ahead := CockpitHud.heading_angle(Vector3.FORWARD, Vector3.FORWARD)
	_ok(absf(ahead) < 0.05, "heading 0 when aimed ahead")
	var right := CockpitHud.heading_angle(Vector3.FORWARD, Vector3.RIGHT)
	_ok(right > 0.5, "heading positive toward +X")
	var left := CockpitHud.heading_angle(Vector3.FORWARD, Vector3.LEFT)
	_ok(left < -0.5, "heading negative toward -X")

	_ok(CockpitHud.bloom_vignette(0.0) < 0.05, "vignette off early")
	_ok(CockpitHud.bloom_vignette(1.0) > 0.2, "vignette on at arrival")

	var thumb := CockpitHud.make_planet_thumb(Color(0.8, 0.3, 0.2), 64)
	_ok(thumb != null and thumb.get_width() == 64, "planet thumb texture")
	var fallback := CockpitHud.make_fallback_frame(320, 180)
	_ok(fallback != null and fallback.get_width() == 320, "fallback cockpit frame")
	var fb_img := fallback.get_image()
	_ok(fb_img != null, "fallback image readable")
	if fb_img != null:
		_ok(fb_img.get_pixel(160, 60).a < 0.05, "fallback window clear")
		_ok(fb_img.get_pixel(10, 10).a > 0.5, "fallback frame opaque")

	# Build HUD off-tree (headless has no scene tree entry for orphans).
	var hud := CockpitHud.new()
	hud._build()
	_ok(hud.has_cockpit_asset(), "HUD uses cockpit.png asset")
	hud.set_destination({"color": Color(0.2, 0.5, 0.9), "name": "Earth"})
	hud.update_flight(0.25, 0.3)
	_ok(is_equal_approx(CockpitHud.distance_bar_fill(0.25), 0.75), "HUD bar math consistent")
	hud.free()

func _test_ux_cruise() -> void:
	## Selection → slow plot → approach bloom → orbit helpers → optional video.
	_ok(ResourceLoader.exists("res://images/planets/earth.png"), "earth skin present")
	_ok(ResourceLoader.exists("res://images/planets/jupiter.png"), "jupiter skin present")
	_ok(PlanetSkins.texture_for("mars") != null, "PlanetSkins loads mars")
	var mat := PlanetSkins.make_skinned_material({
		"id": "earth", "color": Color(0.2, 0.5, 0.8), "is_star": false,
	})
	_ok(mat != null, "skinned earth material")
	var disc := PlanetSkins.make_disc_texture("earth", Color(0.2, 0.5, 0.8), 64)
	_ok(disc != null and disc.get_width() == 64, "scroll strip disc texture")

	var near := PlotBoard.plot_beat_seconds(12.0)
	var far := PlotBoard.plot_beat_seconds(40.0)
	_ok(float(far["chart"]) > float(near["chart"]), "far hops chart longer")
	_ok(float(near["chart"]) <= 2.2, "close hop chart stays snappy")
	_ok(float(far["chart"]) >= 4.0, "far hop chart is readable")

	_ok(OrbitMath.format_travel_miles(1.0).find("million") >= 0, "1 AU → million miles")
	_ok(OrbitMath.format_travel_miles(30.0).find("billion") >= 0
		or OrbitMath.format_travel_miles(30.0).find("million") >= 0,
		"outer hop miles readable")

	var off := OrbitMath.orbit_offset(0.0, 10.0, 0.3)
	_ok(is_equal_approx(off.x, 10.0) and is_equal_approx(off.z, 0.0), "orbit offset at ang0")

	# Orbit tangent: perpendicular to the radial offset, in the XZ plane,
	# and flipped by direction sign (Phase 4 forward-facing orbit camera).
	for ang in [0.0, 1.1, 2.7, 4.6]:
		var rad_dir := Vector3(cos(ang), 0.0, sin(ang))
		var tan_ccw := OrbitMath.orbit_tangent(ang, 1.0)
		var tan_cw := OrbitMath.orbit_tangent(ang, -1.0)
		_ok(absf(tan_ccw.dot(rad_dir)) < 0.001, "orbit tangent ⟂ radial at %.1f" % ang)
		_ok(is_equal_approx(tan_ccw.length(), 1.0), "orbit tangent unit at %.1f" % ang)
		_ok(tan_ccw.is_equal_approx(-tan_cw), "orbit tangent flips with dir at %.1f" % ang)
	_ok(OrbitMath.orbit_tangent(0.0, 1.0).is_equal_approx(Vector3(0, 0, 1)),
		"orbit tangent handedness (+Z at ang0 ccw)")

	var cfg := SolarFlyerConfig.load_default()
	# Markers hold their angular size no matter how close a world gets —
	# proximity NEVER grows a marker; only the destination's cinematic does.
	var ang_far: float = OrbitMath.marker_world_size(400.0, 1.6, cfg) / 400.0
	var ang_near: float = OrbitMath.marker_world_size(40.0, 1.6, cfg) / 40.0
	_ok(absf(ang_near - ang_far) < 0.001,
		"marker angular size constant regardless of proximity")
	_ok(OrbitMath.orbit_standoff(4.0) > 4.0 * 1.5, "orbit stays outside hero radius")

	var earth := SolarData.flyer_body_by_id("earth", cfg)
	var uranus := SolarData.flyer_body_by_id("uranus", cfg)
	var route_u := OrbitMath.plot_route(OrbitMath.body_pos(earth, 0.0), uranus, 0.0, cfg)
	var narr := OrbitMath.trip_narration(earth, uranus, route_u, cfg)
	_ok(narr.find("Uranus") >= 0, "trip narration names destination")
	# Either claim is fine — but it must match the measured course.
	if narr.find("close to the Sun") >= 0:
		_ok(float(route_u["min_sun_dist"]) < float(earth["orbit_r"]) * 0.55,
			"Earth→Uranus sun-flyby claim backed by geometry")
	else:
		_ok(narr.find("away from the Sun") >= 0, "outward hop says away from the Sun")
	var along := OrbitMath.bodies_along_hop(earth, uranus, cfg, true)
	_ok(along.size() >= 2, "Earth→Uranus crosses inner/outer worlds")
	_ok(narr.find("Vesta") < 0 and narr.find("Ceres") < 0,
		"Earth→Uranus narration skips asteroids")
	# Pass-by claims only for forward mid-cruise encounters (not radial rings).
	for e in route_u.get("encounters", []):
		_ok(float(e.get("path_u", 0.0)) >= OrbitMath.ENCOUNTER_U_MIN,
			"Uranus encounter %s not a departure ghost" % e.get("id", "?"))

	# Narration honesty: outward hops never claim a Sun flyby (the transfer
	# arc's radius never drops below the inner endpoint's orbit).
	var jup := SolarData.flyer_body_by_id("jupiter", cfg)
	var route_j := OrbitMath.plot_route(OrbitMath.body_pos(earth, 0.0), jup, 0.0, cfg)
	var narr_j := OrbitMath.trip_narration(earth, jup, route_j, cfg)
	_ok(narr_j.find("close to the Sun") < 0 and narr_j.find("around the Sun") < 0,
		"Earth→Jupiter never claims a Sun flyby")
	# Origin falling aft at depart is never a "pass by Earth".
	for e in route_j.get("encounters", []):
		_ok(str(e.get("id", "")) != "earth",
			"Earth→Jupiter does not chart a pass-by of origin Earth")
	_ok(narr_j.find("pass close by Earth") < 0,
		"Earth→Jupiter narration skips aft departure Earth")
	var mercury := SolarData.flyer_body_by_id("mercury", cfg)
	var route_m := OrbitMath.plot_route(OrbitMath.body_pos(earth, 0.0), mercury, 0.0, cfg)
	var narr_m := OrbitMath.trip_narration(earth, mercury, route_m, cfg)
	_ok(narr_m.find("toward the Sun") >= 0, "inward hop says toward the Sun")
	# "Around the Sun" may only ever describe the PLANET lapping (honest —
	# gated on measured sweep), never the ship's course circling.
	if narr_m.find("zoom all the way around the Sun") >= 0:
		_ok(float(mercury["omega"]) * float(route_m["t_arr"]) >= TAU,
			"Mercury lap claim backed by measured sweep")
	else:
		_ok(narr_m.find("around the Sun") < 0, "inward hop never claims circling the Sun")
	for b in SolarData.flyer_destinations(cfg):
		if str(b["id"]) == "earth":
			continue
		var r := OrbitMath.plot_route(OrbitMath.body_pos(earth, 0.0), b, 0.0, cfg)
		var n := OrbitMath.trip_narration(earth, b, r, cfg)
		if n.find("close to the Sun") >= 0:
			_ok(float(r["min_sun_dist"]) <
				minf(float(earth["orbit_r"]), float(b.get("orbit_r", 0.0))) * 0.55,
				"Sun-flyby claim backed by course geometry for %s" % b["id"])

	# Departure standoff: course starts clear of the origin planet, not its center.
	var standoff := OrbitMath.orbit_standoff(float(earth["hero_r"]))
	var route_d := OrbitMath.plot_route(OrbitMath.body_pos(earth, 0.0), jup, 0.0, cfg, standoff)
	var start_d: Vector3 = OrbitMath.path_sample(route_d["curve"], 0.0)
	_ok(start_d.distance_to(OrbitMath.body_pos(earth, 0.0)) >= standoff * 0.9,
		"course launch point sits at standoff from origin")
	var end_d: Vector3 = OrbitMath.path_sample(route_d["curve"], 1.0)
	_ok(absf(end_d.distance_to(route_d["arrival_pos"])
		- OrbitMath.orbit_standoff(float(jup["hero_r"]))) < 1.0,
		"trimmed course still ends on the parking sphere")

	var p := CockpitHud.console_project(Vector3(0, 0, 0), Vector2(-10, -10), Vector2(10, 10),
		Vector2(300, 130))
	_ok(p.x > 100 and p.x < 200, "console projects origin near center-ish")

	_ok(is_equal_approx(OrreryBodies.FLATTEN_PLOT, 1.0), "plot board is true top-down")
	var board := OrreryBodies.new()
	board.cfg = cfg
	board.set_mode(OrreryBodies.Mode.PLOT)
	board.ship_id = "earth"
	board.set_route("uranus", route_u, 0.0)
	_ok(board.board_scale < OrreryBodies.BOARD_SCALE_DEFAULT - 0.05,
		"outer hop zooms plot board out (scale %.2f)" % board.board_scale)
	board.free()

func _test_nav_modes() -> void:
	## New nav-mode math: pacing bounds, fly-by swap, and the honest
	## real-scale reconstruction behind SIM_VIEW.
	var cfg := SolarFlyerConfig.load_default()

	# Pacing: wall time is bounded — long hops play faster, short hops slower.
	for dur in [3.0, 12.0, 30.0, 55.0]:
		var wall := 0.0
		var u := 0.0
		var steps := 0
		while u < 1.0 and steps < 100000:
			var rate := OrbitMath.flight_play_rate(u, dur)
			u += (1.0 / 60.0) * rate / dur
			wall += 1.0 / 60.0
			steps += 1
		_ok(wall <= OrbitMath.WALL_MAX_S * 1.55,
			"hop of %.0fs plays in %.1fs wall (bounded)" % [dur, wall])
		_ok(wall >= 3.0, "hop of %.0fs not instant (%.1fs)" % [dur, wall])
	_ok(OrbitMath.flight_play_rate(0.95, 40.0) < OrbitMath.flight_play_rate(0.5, 40.0),
		"pacing eases near arrival")

	# Fly-by (legacy cfg-less path): far away no mesh; inside the window grows.
	_ok(OrbitMath.flyby_mesh_scale(200.0, 5.0, 2.0) == 0.0, "no fly-by mesh at distance")
	var mid := OrbitMath.flyby_mesh_scale(9.0 * 5.0, 5.0, 2.0)
	_ok(mid > 0.0 and mid <= 5.0, "fly-by mesh appears inside the window")
	var close_d := OrbitMath.FLYBY_NEAR_X * 5.0
	var close_s := OrbitMath.flyby_mesh_scale(close_d, 5.0, 2.0)
	_ok(close_s > 0.0 and close_s <= close_d * OrbitMath.FLYBY_CLEARANCE + 0.01,
		"fly-by mesh on close pass (got %.2f at d=%.1f)" % [close_s, close_d])
	# Handoff capped so compressed-system cruise keeps giants as pins.
	var handoff := OrbitMath.flyby_handoff_dist(5.0, 1.0, cfg)
	_ok(handoff <= 5.0 * OrbitMath.FLYBY_HANDOFF_MAX_X + 0.01,
		"handoff capped at MAX_X·hero (got %.1f)" % handoff)
	var jup := SolarData.flyer_body_by_id("jupiter", cfg)
	var j_hand := OrbitMath.flyby_handoff_dist(
		float(jup.get("hero_r", 12.0)), SolarData.icon_tier_for(jup), cfg)
	_ok(j_hand <= float(jup.get("hero_r", 12.0)) * OrbitMath.FLYBY_HANDOFF_MAX_X + 0.01,
		"Jupiter handoff capped (%.1f) — not system-wide loom" % j_hand)
	_ok(OrbitMath.flyby_mesh_scale(handoff * 1.05, 5.0, 2.0, 1.0, cfg) == 0.0,
		"no mesh just outside handoff")
	_ok(OrbitMath.flyby_mesh_scale(handoff * 0.95, 5.0, 2.0, 1.0, cfg) > 0.0,
		"mesh appears inside handoff")
	# Destination handoff is wider so mid-cruise closing can loom as mesh.
	var dest_hand := OrbitMath.flyby_handoff_dist(5.0, 1.0, cfg, true)
	_ok(dest_hand > handoff + 0.01,
		"dest handoff wider than peer (%.1f > %.1f)" % [dest_hand, handoff])
	_ok(dest_hand <= 5.0 * OrbitMath.FLYBY_HANDOFF_MAX_X_DEST + 0.01,
		"dest handoff still capped")
	_ok(OrbitMath.flyby_mesh_scale(7.0 * 5.0, 5.0, 2.0, 1.0, cfg, false) == 0.0,
		"peer stays pin at 7×hero")
	_ok(OrbitMath.flyby_mesh_scale(7.0 * 5.0, 5.0, 2.0, 1.0, cfg, true) > 0.0,
		"dest mesh at 7×hero (Mars mid-cruise)")
	# Encounter spotlight: peak at path_u, zero outside the window.
	_ok(OrbitMath.encounter_spotlight(0.58, 0.58) > 0.99, "spotlight peaks on cue")
	_ok(OrbitMath.encounter_spotlight(0.58 + OrbitMath.ENCOUNTER_SPOT_HALF_U + 0.01, 0.58) == 0.0,
		"spotlight off outside window")
	_ok(OrbitMath.encounter_spotlight_for("jupiter", 0.58, [
		{"id": "jupiter", "path_u": 0.58},
		{"id": "venus", "path_u": 0.10},
	]) > 0.99, "spotlight_for picks matching encounter")
	_ok(OrbitMath.encounter_spotlight_for("mars", 0.58, [
		{"id": "jupiter", "path_u": 0.58},
	]) == 0.0, "spotlight_for ignores other bodies")
	# Camera clearance: a course straight through a world never puts the
	# camera inside the mesh — the radius is capped below the camera distance.
	for d in [0.5, 2.0, 6.0, 12.0]:
		_ok(OrbitMath.flyby_mesh_scale(d, 5.0, 2.0) <= d * OrbitMath.FLYBY_CLEARANCE + 0.001,
			"fly-by mesh keeps camera clearance at dist %.1f" % d)

	# Real-scale reconstruction: decompress inverts compress at the orbits.
	for a in [0.39, 1.0, 5.2, 19.2, 39.5]:
		var r_sim := OrbitMath.compress_orbit_r(a, cfg)
		var back := OrbitMath.decompress_radius_au(r_sim, cfg)
		_ok(absf(back - a) < a * 0.02 + 0.01,
			"decompress inverts compress at %.2f AU (got %.2f)" % [a, back])

	# Apparent sizes: real sun from Earth ≈ 0.25° half-angle; Mars from
	# Earth at closest approach is tiny (that's WHY it's a dot).
	var sun_half := OrbitMath.apparent_radius_rad(695700.0, 1.0)
	_ok(absf(rad_to_deg(sun_half) - 0.266) < 0.03,
		"sun subtends ~0.27 deg half-angle at 1 AU (%.3f)" % rad_to_deg(sun_half))
	var mars_half := OrbitMath.apparent_radius_rad(3390.0, 0.52)
	_ok(rad_to_deg(mars_half) < 0.01, "mars is honestly a dot from Earth")

	# Brightness: Venus at its brightest ≈ 1; Neptune from Earth is far
	# below the visibility floor (honest sky: you can't see it unaided).
	var venus_b := OrbitMath.apparent_brightness(6052.0, 0.72, 0.28)
	_ok(absf(venus_b - 1.0) < 0.1, "Venus reference brightness ≈ 1 (%.2f)" % venus_b)
	var nep_b := OrbitMath.apparent_brightness(24622.0, 30.05, 29.05)
	_ok(OrbitMath.brightness_alpha(nep_b) < 0.35,
		"Neptune from Earth renders faint-to-invisible")
	_ok(OrbitMath.brightness_alpha(1.0) >= 0.99, "full-flux body renders at full alpha")

	# Playground tilt response: deadzoned around the calibrated neutral,
	# smooth, symmetric, saturating at TILT_FULL_RAD.
	_ok(PlaygroundScene._tilt_axis(0.0) == 0.0, "tilt: neutral is dead center")
	_ok(PlaygroundScene._tilt_axis(PlaygroundScene.TILT_DEAD_RAD * 0.9) == 0.0,
		"tilt: inside the deadzone nothing moves")
	var half := PlaygroundScene._tilt_axis(PlaygroundScene.TILT_FULL_RAD * 0.6)
	_ok(half > 0.05 and half < 0.95, "tilt: partial tilt steers partially")
	_ok(absf(PlaygroundScene._tilt_axis(PlaygroundScene.TILT_FULL_RAD) - 1.0) < 0.001,
		"tilt: full tilt = full deflection")
	_ok(PlaygroundScene._tilt_axis(-PlaygroundScene.TILT_FULL_RAD) == \
		-PlaygroundScene._tilt_axis(PlaygroundScene.TILT_FULL_RAD),
		"tilt: response is symmetric")
	_ok(PlaygroundScene._tilt_axis(99.0) <= 1.0, "tilt: response saturates")
	# Angle extraction: sensitivity must not collapse for a vertical grip.
	# 15° of pitch from the measured on-device neutral (near-vertical) must
	# move the pitch angle by ~15° — the raw Y component only moved ~0.04 g.
	var n_ang := PlaygroundScene._tilt_angles(Vector3(0.32, -9.98, -1.02))
	var up_ang := PlaygroundScene._tilt_angles(
		Vector3(0.32, -9.98, -1.02).rotated(Vector3.RIGHT, deg_to_rad(15.0)))
	_ok(absf(absf(up_ang.y - n_ang.y) - deg_to_rad(15.0)) < deg_to_rad(1.5),
		"tilt: pitch angle tracks device pitch at a vertical grip")
	var roll_ang := PlaygroundScene._tilt_angles(
		Vector3(0.32, -9.98, -1.02).rotated(Vector3(0, 0, -1).normalized(), deg_to_rad(15.0)))
	_ok(absf(roll_ang.x - n_ang.x) > deg_to_rad(8.0),
		"tilt: roll angle responds to device roll")
	# Pitch direction: facing the phone up (screen toward the ceiling —
	# z picks up more of gravity) must RAISE the pitch angle.
	_ok(PlaygroundScene._tilt_angles(Vector3(0, -9.4, -2.8)).y \
		> PlaygroundScene._tilt_angles(Vector3(0, -9.8, -0.5)).y,
		"tilt: facing the phone up raises the pitch angle")

	# Band hysteresis helpers (constants used by the soft-edge logic).
	_ok(PlaygroundScene.Y_CLEAR < PlaygroundScene.Y_SOFT,
		"band: clear band is inside the soft edge (hysteresis)")
	_ok(PlaygroundScene.BAND_COOLDOWN_S >= 5.0,
		"band: narration cooldown prevents edge-bounce spam")

	# Offline voice-speed envelope matcher.
	var VoiceCommands := preload("res://scripts/voice/VoiceCommands.gd")
	var a := PackedFloat32Array()
	var b := PackedFloat32Array()
	var c := PackedFloat32Array()
	for i in VoiceCommands.ENVELOPE_BINS:
		a.append(sin(float(i) * 0.4) * 0.5 + 0.5)
		b.append(sin(float(i) * 0.4 + 0.05) * 0.5 + 0.5)  # near-match
		c.append(sin(float(i) * 1.7) * 0.5 + 0.5)          # different shape
	_ok(VoiceCommands.envelope_score(a, b) > 0.9,
		"voice: near-identical envelopes score high")
	_ok(VoiceCommands.envelope_score(a, c) < VoiceCommands.envelope_score(a, b),
		"voice: different envelopes score lower than near-matches")
	_ok(VoiceCommands.envelope_score(a, a) > 0.99,
		"voice: identical envelopes score ~1")
	_ok(VoiceCommands.MATCH_MIN < 0.9,
		"voice: match threshold leaves room for natural variation")

	# Down-side detection: a decisively flipped vertical component rotates
	# the frame 180° (x and y negate, z is unchanged).
	var pg := PlaygroundScene.new()
	var flipped: Vector3 = pg._frame_adjust(Vector3(0.5, 9.9, -1.0))
	_ok(pg._flip == -1.0, "downside: +y gravity flips the frame")
	_ok(flipped.is_equal_approx(Vector3(-0.5, -9.9, -1.0)),
		"downside: flip negates x and y, keeps z")
	var back: Vector3 = pg._frame_adjust(Vector3(0.3, -9.8, -1.0))
	_ok(pg._flip == 1.0 and back.is_equal_approx(Vector3(0.3, -9.8, -1.0)),
		"downside: -y gravity restores the identity frame")
	var weak: Vector3 = pg._frame_adjust(Vector3(0.0, 2.0, -9.6))
	_ok(pg._flip == 1.0 and weak.is_equal_approx(Vector3(0.0, 2.0, -9.6)),
		"downside: an indecisive vertical never toggles the flip")
	pg.free()

	# NavModes persistence round-trip.
	var before := NavModes.mode()
	NavModes.set_mode(NavModes.MODE_SIM_VIEW)
	NavModes._mode = -1   # force re-load from disk
	_ok(NavModes.mode() == NavModes.MODE_SIM_VIEW, "nav mode persists")
	NavModes.set_mode(before)
	_ok(NavModes.label(NavModes.MODE_PLAYGROUND) == "Free flight", "mode labels")

func _test_narration_vo() -> void:
	## Baked ElevenLabs narration: every sentence the game can speak must have
	## a clip in audio/vo (Narrator falls back to robo-TTS only if one is missing).
	var narrator := load("res://scripts/Narrator.gd")

	var sents: PackedStringArray = narrator.split_sentences("Hello there. Off we go! Ready?")
	_ok(sents.size() == 3, "split_sentences splits on . ! ?")
	_ok(sents[1] == "Off we go!", "split keeps punctuation")
	var dec: PackedStringArray = narrator.split_sentences(
		"You traveled 5.2 astronomical units. That's 484 million miles!")
	_ok(dec.size() == 2, "decimals do not split sentences")
	_ok(dec[0].find("5.2") >= 0, "decimal AU stays intact")
	_ok(narrator.normalize_line("  a   b  ") == "a b", "normalize collapses whitespace")
	_ok(narrator.vo_key("Hello.") == narrator.vo_key(" Hello. "), "key ignores padding")

	_ok(FileAccess.file_exists("res://data/solar_vo_manifest.json"), "VO manifest present")
	var manifest: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/solar_vo_manifest.json"))
	_ok(manifest.size() >= 150, "manifest covers all sentences (%d)" % manifest.size())

	# Every runtime-constructed line must resolve to baked sentences.
	var cfg := SolarFlyerConfig.load_default()
	var lines: Array = [
		load("res://scripts/TitleView.gd").WELCOME,
		load("res://scripts/OrreryView.gd").CLOSING,
		load("res://scripts/AstronautIntro.gd").BRIEFING_MISSION,
		load("res://scripts/AstronautIntro.gd").BRIEFING_FREE_FLIGHT,
	]
	for b in SolarData.bodies():
		lines.append(str(b.get("blurb", "")) + " A video about it is coming soon.")
	var dests := SolarData.flyer_destinations(cfg)
	for origin in dests:
		for dest in dests:
			if str(origin["id"]) == str(dest["id"]):
				continue
			var route := OrbitMath.plot_route(
				OrbitMath.body_pos(origin, 0.0), dest, 0.0, cfg, 0.0)
			lines.append(OrbitMath.trip_narration(origin, dest, route, cfg))
			var au: float = absf(float(dest.get("a_au", 0.0)) - float(origin.get("a_au", 0.0)))
			lines.append(OrbitMath.arrival_narration(str(dest.get("name", "")), au,
				bool(dest.get("is_star", false))))
	var missing := 0
	for line in lines:
		for s in narrator.split_sentences(str(line)):
			var key: String = narrator.vo_key(s)
			if not manifest.has(key):
				missing += 1
				print("  missing from manifest: ", s)
			elif not FileAccess.file_exists("res://audio/vo/%s.wav" % key):
				missing += 1
				print("  missing clip: ", s)
	_ok(missing == 0, "every speakable sentence has a baked clip (missing %d)" % missing)

	# Clips are parseable WAVs.
	var vo_stream := load("res://scripts/VoStream.gd")
	var first_key: String = narrator.vo_key(narrator.split_sentences(str(lines[0]))[0])
	var stream: AudioStream = vo_stream.load_path("res://audio/vo/%s.wav" % first_key)
	_ok(stream != null, "welcome clip loads as AudioStream")
	if stream != null:
		_ok(stream.get_length() > 0.5, "welcome clip has audio (%.1fs)" % stream.get_length())

func _test_scripts_compile() -> void:
	for path in [
		"res://scripts/Main.gd", "res://scripts/Starfield.gd",
		"res://scripts/TitleView.gd", "res://scripts/OrreryView.gd",
		"res://scripts/OrreryBodies.gd", "res://scripts/ScrollView.gd",
		"res://scripts/BodyCell.gd", "res://scripts/VideoPanel.gd",
		"res://scripts/Narrator.gd", "res://scripts/SolarData.gd",
		"res://scripts/AstronautIntro.gd", "res://scripts/ComingSoon.gd",
		"res://scripts/SolarFlyerConfig.gd", "res://scripts/OrbitMath.gd",
		"res://scripts/PlotBoard.gd", "res://scripts/FlyScene.gd",
		"res://scripts/ScaleTune.gd", "res://scripts/CockpitHud.gd",
		"res://scripts/PlanetSkins.gd", "res://scripts/VoStream.gd",
		"res://scripts/NarratorVoice.gd", "res://scripts/NavModes.gd",
		"res://scripts/OrbitCinematic.gd", "res://scripts/PlaygroundScene.gd",
		"res://scripts/FlightChooser.gd", "res://scripts/RealismBudget.gd",
		"res://scripts/AstrogatorPanel.gd",
		"res://scripts/CourseModeChooser.gd",
		"res://scripts/PropulsionChooser.gd",
	]:
		_ok(load(path) != null, "compiles: %s" % path)

func _test_realism_budget() -> void:
	## Phase A — STRATEGY_REAL_ROCKET_SCIENCE.md discovery math.
	for c in RealismBudget.phase_a_checks():
		_ok(bool(c.get("ok", false)), "%s — %s" % [c.get("name"), c.get("detail")])
	var earth := {"id": "earth", "a_au": 1.0, "period_yr": 1.0}
	var mars := {"id": "mars", "a_au": 1.52, "period_yr": 1.88}
	var b: Dictionary = RealismBudget.hop_budget(earth, mars, 0.0)
	_ok(bool(b.get("ok", false)), "earth→mars hop_budget ok")
	_ok(float(b.get("synodic_yr", 0.0)) > 2.0 and float(b.get("synodic_yr", 0.0)) < 2.3,
		"earth→mars synodic from hop_budget")
	_ok(b.has("fuels") and (b["fuels"] as Dictionary).has("orion"),
		"hop_budget includes orion fuel fraction")

func _test_astrogator_panel() -> void:
	## Phase B — route stamp helpers + kid copy (no scene tree required).
	_ok(AstrogatorPanel.is_propulsion_id("chemical"), "chemical propulsion id")
	_ok(AstrogatorPanel.is_propulsion_id("orion"), "orion propulsion id")
	_ok(not AstrogatorPanel.is_propulsion_id("warp"), "reject unknown propulsion")
	var earth := {"id": "earth", "a_au": 1.0, "period_yr": 1.0}
	var jup := {"id": "jupiter", "a_au": 5.2, "period_yr": 11.86}
	var bud: Dictionary = RealismBudget.hop_budget(earth, jup, 0.0)
	var ledger := AstrogatorPanel.ledger_lines(bud, "chemical")
	_ok(ledger.contains("Coast"), "ledger has coast line")
	_ok(ledger.contains("Most of this rocket is fuel"),
		"chemical Jupiter mostly-fuel copy")
	var f_orion := AstrogatorPanel.fuel_frac_for(bud, "orion")
	var f_chem := AstrogatorPanel.fuel_frac_for(bud, "chemical")
	_ok(f_orion < f_chem * 0.5, "orion far cheaper than chemical on Jupiter")
	var cal := AstrogatorPanel.calendar_label(100.0, 200.0)
	_ok(cal.contains("Coast calendar"), "calendar label format")
	var narr := AstrogatorPanel.launch_narration(bud, "orion")
	_ok(narr.contains("Astrogator"), "launch narration mentions Astrogator")
	_ok(narr.contains("nuclear pulse"), "launch narration names pulse ship")
	var earth_b := SolarData.flyer_body_by_id("earth", SolarFlyerConfig.load_default())
	var jup_b := SolarData.flyer_body_by_id("jupiter", SolarFlyerConfig.load_default())
	var brief := AstrogatorPanel.mission_briefing(
		earth_b, jup_b, bud, "chemical", SolarFlyerConfig.load_default())
	_ok(brief.contains("Chemical rockets") or brief.contains("chemical"),
		"mission briefing explains chemical engines")
	_ok(brief.contains("percent") or brief.contains("fuel"),
		"mission briefing mentions fuel weight")
	_ok(brief.contains("gravity kick") or brief.contains("engines do"),
		"mission briefing is honest about gravity assists")
	_ok(AstrogatorPanel.engine_explain("ntp").contains("reactor"),
		"NTP engine explain mentions reactor")

func _by_id(bodies: Array, id: String) -> Dictionary:
	for b in bodies:
		if b["id"] == id:
			return b
	return {}

func _contains_id(bodies: Array, id: String) -> bool:
	for b in bodies:
		if b["id"] == id:
			return true
	return false

func _id_order(bodies: Array) -> Array:
	var out: Array = []
	for b in bodies:
		out.append(str(b["id"]))
	return out

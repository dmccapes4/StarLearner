extends SceneTree
## Headless logic tests for the Solar System Explorer preview.
##   godot --headless --path . -s res://tests/run_tests.gd
## Exit code 0 = all passed; 1 = failures. Also force-loads every view script so
## a compile error anywhere fails the run (headless can't render the scenes).

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
	_test_layout()
	_test_orbit_math()
	_test_flight()
	_test_scale_tune()
	_test_cockpit_hud()
	_test_ux_cruise()
	_test_narration_vo()
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
	_ok(flyers.size() == 11, "flyer_bodies returns 11")

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

	# Apparent size monotonic decreasing with distance.
	var hero: float = float(by_id["mars"]["hero_r"])
	var a_near := OrbitMath.apparent_size(10.0, hero, cfg)
	var a_far := OrbitMath.apparent_size(200.0, hero, cfg)
	_ok(a_near >= a_far, "apparent size shrinks with distance")
	_ok(a_far >= cfg.min_dot - 0.001, "far clamp to min_dot")

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

	# LOD hysteresis band.
	_ok(OrbitMath.lod_want_mesh(10.0, false, cfg.mesh_in, cfg.mesh_out), "LOD on inside mesh_in")
	_ok(not OrbitMath.lod_want_mesh(500.0, true, cfg.mesh_in, cfg.mesh_out), "LOD off past mesh_out")
	var mid: float = (cfg.mesh_in + cfg.mesh_out) * 0.5
	_ok(OrbitMath.lod_want_mesh(mid, true, cfg.mesh_in, cfg.mesh_out), "LOD holds ON in band")
	_ok(not OrbitMath.lod_want_mesh(mid, false, cfg.mesh_in, cfg.mesh_out), "LOD holds OFF in band")
	var past_normal: float = cfg.mesh_out * 1.15
	_ok(OrbitMath.lod_want_mesh_priority(past_normal, true, cfg, true),
		"priority keeps mesh ON past normal mesh_out")
	_ok(not OrbitMath.lod_want_mesh_priority(past_normal, true, cfg, false),
		"non-priority turns mesh OFF past mesh_out")

	# Look blend: off early, full at arrival.
	_ok(is_equal_approx(OrbitMath.look_blend_weight(0.0), 0.0), "look blend 0 at start")
	_ok(OrbitMath.look_blend_weight(0.5) > 0.0, "look blend rising mid-hop")
	_ok(is_equal_approx(OrbitMath.look_blend_weight(1.0), 1.0), "look blend 1 at end")

	# BOOST clamps.
	_ok(is_equal_approx(OrbitMath.apply_boost(0.0, 20.0, 0.08), 1.6), "boost nudges 8%")
	_ok(is_equal_approx(OrbitMath.apply_boost(19.0, 20.0, 0.5), 20.0), "boost clamps to duration")

	# Every planetary hop: path endpoints, clock, bloom-at-arrival, duration band.
	for b in SolarData.flyer_destinations(cfg):
		if str(b["id"]) == "earth" or bool(b.get("is_star", false)):
			continue
		var route := OrbitMath.plot_route(ship, b, 0.0, cfg)
		var curve: Curve3D = route["curve"]
		var t_arr: float = float(route["t_arr"])
		var arrival: Vector3 = route["arrival_pos"]

		var p_start := OrbitMath.path_sample(curve, 0.0)
		var p_end := OrbitMath.path_sample(curve, 1.0)
		_ok(p_start.distance_to(ship) < 0.5, "path starts at ship for %s" % b["id"])
		_ok(p_end.distance_to(arrival) < 0.5, "path ends at intercept for %s" % b["id"])

		var clock0 := OrbitMath.flight_clock(0.0, t_arr, 0.0)
		var clock1 := OrbitMath.flight_clock(0.0, t_arr, 1.0)
		_ok(is_equal_approx(clock0, 0.0), "flight clock start for %s" % b["id"])
		_ok(is_equal_approx(clock1, t_arr), "flight clock end for %s" % b["id"])

		# At arrival the ship is on top of the destination → bloom (hero-sized).
		var dist_end := OrbitMath.ship_to_dest_dist(curve, 1.0, b, 0.0, t_arr)
		_ok(dist_end < maxf(float(b["hero_r"]) * 2.0, 2.0),
			"arrival close enough to bloom for %s (d=%.2f)" % [b["id"], dist_end])
		var app_end := OrbitMath.apparent_size(maxf(dist_end, 0.01), float(b["hero_r"]), cfg)
		_ok(app_end >= float(b["hero_r"]) * 0.85,
			"apparent size near hero at arrival for %s" % b["id"])

		# Mid-hop: destination still farther than at the end (generally).
		var dist_mid := OrbitMath.ship_to_dest_dist(curve, 0.35, b, 0.0, t_arr)
		_ok(dist_mid > dist_end, "closes on target for %s" % b["id"])

	# Belt MultiMesh: deterministic seed, rocks stay near belt radius.
	var belt: Dictionary = by_id["asteroid_belt"]
	var xforms := OrbitMath.belt_transforms(float(belt["orbit_r"]), 40, 909091)
	var xforms2 := OrbitMath.belt_transforms(float(belt["orbit_r"]), 40, 909091)
	_ok(xforms.size() == 40, "belt transform count")
	_ok(xforms[0].origin.is_equal_approx(xforms2[0].origin), "belt transforms deterministic")
	var r0: float = float(belt["orbit_r"])
	for xf in xforms:
		var xz: float = Vector2(xf.origin.x, xf.origin.z).length()
		_ok(xz > r0 - 8.0 and xz < r0 + 8.0, "belt rock near ring radius")
		_ok(absf(xf.origin.y) <= 1.25, "belt rock small Y jitter")

func _test_scale_tune() -> void:
	## Phase 4 — happy-medium contracts for the shipped .tres knobs.
	var cfg := SolarFlyerConfig.load_default()
	_ok(cfg != null, "load_default returns config")
	_ok(is_equal_approx(cfg.cruise_speed, 11.0), "shipped cruise_speed is 11")
	_ok(is_equal_approx(cfg.focus_dist, 26.0), "shipped focus_dist is 26")
	_ok(cfg.distance_span >= 300.0, "larger space: distance_span >= 300")
	_ok(cfg.mesh_in < cfg.mesh_out, "LOD hysteresis band")
	_ok(cfg.mesh_out >= 100.0, "mesh_out keeps far worlds as spheres")

	var report := ScaleTune.evaluate(cfg)
	if not bool(report["ok"]):
		for issue in report["issues"]:
			print("  scale issue: ", issue)
	_ok(bool(report["ok"]), "shipped config passes happy-medium checks")
	_ok((report["hops"] as Array).size() >= 9, "scale report covers destinations")

	# Outer hops bloom after mid-cruise.
	var late_blooms := 0
	for h in report["hops"]:
		if str(h["id"]) in ["jupiter", "saturn", "uranus", "neptune", "pluto"]:
			if float(h["bloom_u"]) >= 0.50:
				late_blooms += 1
			_ok(float(h["app_end"]) >= float(h["hero_r"]) * 0.8,
				"%s blooms to hero at arrival" % h["id"])
	_ok(late_blooms >= 3, "at least 3 outer hops bloom late")

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

	# JSON overlay apply + reject a too-fast cruise.
	var tuned := cfg.duplicate(true) as SolarFlyerConfig
	ScaleTune.apply_overrides(tuned, {"cruise_speed": 80.0, "focus_dist": 22.0})
	_ok(is_equal_approx(tuned.cruise_speed, 80.0), "overlay sets cruise_speed")
	var bad := ScaleTune.evaluate(tuned)
	_ok(not bool(bad["ok"]), "too-fast cruise fails happy-medium")
	var mentions_cruise := false
	for issue in bad["issues"]:
		if str(issue).find("cruise") >= 0 or str(issue).find("hop_min") >= 0 \
				or str(issue).find("variety") >= 0:
			mentions_cruise = true
	_ok(mentions_cruise, "failure mentions cruise/duration")

	# bloom_progress monotonic-ish: higher frac → later or equal u
	var earth := SolarData.flyer_body_by_id("earth", cfg)
	var jup := SolarData.flyer_body_by_id("jupiter", cfg)
	var route := OrbitMath.plot_route(OrbitMath.body_pos(earth, 0.0), jup, 0.0, cfg)
	var u55 := ScaleTune.bloom_progress(route["curve"], jup, 0.0, route["t_arr"], cfg, 0.55)
	var u90 := ScaleTune.bloom_progress(route["curve"], jup, 0.0, route["t_arr"], cfg, 0.90)
	_ok(u90 >= u55 - 0.001, "higher bloom frac → later progress")

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

	var cfg := SolarFlyerConfig.load_default()
	var app_far := OrbitMath.apparent_size(200.0, 8.0, cfg)
	var app_near := OrbitMath.apparent_size(20.0, 8.0, cfg)
	_ok(app_near > app_far * 1.5, "approach grows apparent size")
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
	var along := OrbitMath.bodies_along_hop(earth, uranus, cfg)
	_ok(along.size() >= 2, "Earth→Uranus crosses inner/outer worlds")

	# Narration honesty: outward hops never claim a Sun flyby (the Bézier bows
	# outward, so min_sun_dist ≈ the inner endpoint's orbit — never near the Sun).
	var jup := SolarData.flyer_body_by_id("jupiter", cfg)
	var route_j := OrbitMath.plot_route(OrbitMath.body_pos(earth, 0.0), jup, 0.0, cfg)
	var narr_j := OrbitMath.trip_narration(earth, jup, route_j, cfg)
	_ok(narr_j.find("close to the Sun") < 0 and narr_j.find("around the Sun") < 0,
		"Earth→Jupiter never claims a Sun flyby")
	_ok(narr_j.find("Mars") >= 0, "Earth→Jupiter mentions crossing Mars's orbit")
	var mercury := SolarData.flyer_body_by_id("mercury", cfg)
	var route_m := OrbitMath.plot_route(OrbitMath.body_pos(earth, 0.0), mercury, 0.0, cfg)
	var narr_m := OrbitMath.trip_narration(earth, mercury, route_m, cfg)
	_ok(narr_m.find("toward the Sun") >= 0, "inward hop says toward the Sun")
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
	_ok(end_d.distance_to(route_d["arrival_pos"]) < 0.5, "trimmed course still ends at intercept")

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
		load("res://scripts/AstronautIntro.gd").BRIEFING,
	]
	for b in SolarData.bodies():
		lines.append(str(b.get("blurb", "")) + " A video about it is coming soon.")
	var dests := SolarData.flyer_destinations(cfg)
	for origin in dests:
		for dest in dests:
			if str(origin["id"]) == str(dest["id"]):
				continue
			var route := OrbitMath.plot_route(
				OrbitMath.body_pos(origin, 0.0), dest, 0.0, cfg)
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
		"res://scripts/NarratorVoice.gd",
	]:
		_ok(load(path) != null, "compiles: %s" % path)

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

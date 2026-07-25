extends SceneTree
## One-shot probe: camera-to-belt-ring distance along flown routes, to tune
## the belt reveal band and verify the crossing predictor in capture_trips.
##   godot --headless --path . -s res://tools/probe_belt_cross.gd

func _init() -> void:
	var cfg := SolarFlyerConfig.load_default()
	var belt_r: float = float(SolarData.flyer_body_by_id("asteroid_belt", cfg)["orbit_r"])
	print("belt ring r = %.1f  fade %s/%s cull %s" % [
		belt_r, cfg.belt_fade_near, cfg.belt_fade_far, cfg.belt_cull_dist])
	for pair in [["earth", "jupiter"], ["earth", "neptune"], ["jupiter", "mars"],
			["earth", "asteroid_belt"]]:
		var from_id: String = pair[0]
		var to_id: String = pair[1]
		if to_id == "asteroid_belt":
			to_id = SolarData.nearest_major_asteroid(
				OrbitMath.body_pos(SolarData.flyer_body_by_id(from_id, cfg), 0.0),
				0.0, cfg, from_id)
		var origin := SolarData.flyer_body_by_id(from_id, cfg)
		var dest := SolarData.flyer_body_by_id(to_id, cfg)
		var ship := OrbitMath.body_pos(origin, 0.0)
		var standoff := OrbitMath.orbit_standoff(float(origin.get("hero_r", 2.0)))
		var route := OrbitMath.plot_route(ship, dest, 0.0, cfg, standoff,
			OrbitMath.sweep_bodies_for(from_id, to_id, cfg))
		var curve: Curve3D = route["curve"]
		var clen: float = curve.get_baked_length()
		var line := "%s→%s d(ring):" % [from_id, to_id]
		for ui in [0, 15, 21, 26, 40, 55, 70, 85, 97]:
			var prog := OrbitMath.route_progress(float(ui) / 100.0, route, cfg)
			var p := curve.sample_baked(prog * clen)
			var rd: float = absf(Vector2(p.x, p.z).length() - belt_r)
			var d: float = sqrt(rd * rd + p.y * p.y)
			line += " u%02d=%.0f" % [ui, d]
		print(line)
	quit(0)

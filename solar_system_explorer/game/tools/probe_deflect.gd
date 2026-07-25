extends SceneTree
## Debug the sweep/deflect loop for the stubborn Venus conflicts.
##   godot --headless --path . -s res://tools/probe_deflect.gd

func _init() -> void:
	var cfg := SolarFlyerConfig.load_default()
	for dest_id in ["uranus", "neptune"]:
		var earth := SolarData.flyer_body_by_id("earth", cfg)
		var dest := SolarData.flyer_body_by_id(dest_id, cfg)
		var ship := OrbitMath.body_pos(earth, 0.0)
		var sweep_bodies := OrbitMath.sweep_bodies_for("earth", dest_id, cfg)
		print("\n=== earth → %s ===" % dest_id)
		# Reproduce refine_course pass by pass with logging.
		var hit := OrbitMath.plot_route(ship, dest, 0.0, cfg)  # plain seed route
		var cur: Curve3D = hit["curve"]
		for pass_i in 8:
			var clen: float = cur.get_baked_length()
			var route_like := {"path_len": clen,
				"duration": OrbitMath.burn_travel_time(clen, cfg), "slingshot": {}}
			var sweeps := OrbitMath.sweep_course(cur, route_like, sweep_bodies, 0.0, cfg)
			var worst: Dictionary = {}
			for s in sweeps:
				if str(s["class"]) == "conflict":
					print("  pass %d: CONFLICT %-8s sep=%5.1f clear=%4.1f u_cpa=%.3f" % [
						pass_i, s["id"], float(s["min_sep"]), float(s["clearance"]),
						float(s["u_cpa"])])
					if worst.is_empty() or float(s["min_sep"]) - float(s["clearance"]) \
							< float(worst["min_sep"]) - float(worst["clearance"]):
						worst = s
			if worst.is_empty():
				print("  pass %d: clean" % pass_i)
				break
			var dur: float = float(route_like["duration"])
			var u_cpa: float = float(worst["u_cpa"])
			var p_cpa: float = OrbitMath.route_progress(u_cpa, route_like, cfg)
			var ship_at: Vector3 = cur.sample_baked(p_cpa * clen)
			var body := SolarData.flyer_body_by_id(str(worst["id"]), cfg)
			var body_at := OrbitMath.body_pos(body, u_cpa * dur)
			var rel := ship_at - body_at
			rel.y = 0.0
			var dir := rel.normalized() if rel.length() > 0.001 else Vector3.RIGHT
			var center: float = clampf(p_cpa, 0.10, 0.90)
			var eff: float = maxf(OrbitMath._bump_effect(p_cpa, center, 0.15), 0.30)
			var mag: float = (float(worst["clearance"]) - float(worst["min_sep"]) + 2.0) / eff
			print("    deflect %s: p_cpa=%.3f center=%.2f eff=%.2f mag=%.1f dir=(%.2f,%.2f)" % [
				worst["id"], p_cpa, center, eff, mag, dir.x, dir.z])
			cur = OrbitMath.deflect_course(cur, center, dir, mag, 0.15)
	quit(0)

extends SceneTree
## Earth→Saturn: Jupiter pin only when abeam (not nose-on / not mesh).
##   godot --headless --path game -s res://tools/probe_jup_abeam.gd
const FlyScene := preload("res://scripts/FlyScene.gd")
const NavModes := preload("res://scripts/NavModes.gd")
const Starfield := preload("res://scripts/Starfield.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var cfg := SolarFlyerConfig.load_default()
	var origin := SolarData.flyer_body_by_id("earth", cfg)
	var dest := SolarData.flyer_body_by_id("saturn", cfg)
	var prefer := OrbitMath.body_pos(dest, 0.0)
	var ship_pos := OrbitMath.park_pos(origin, 0.0, cfg, prefer)
	var standoff := OrbitMath.orbit_standoff(float(origin.get("hero_r", 2.0)))
	var route := OrbitMath.plot_route(ship_pos, dest, 0.0, cfg, standoff)
	print("encounters=", route.get("encounters", []))
	var bg := Starfield.new()
	var fly: FlyScene = FlyScene.new()
	root.add_child(bg)
	root.add_child(fly)
	fly.cinematic_enabled = false
	fly.render_mode = NavModes.MODE_SIM_VIEW
	fly.set_active(true)
	fly.begin_flight("saturn", route, 0.0)
	var nose_vis := 0
	var abeam_vis := 0
	var mesh_vis := 0
	var samples := 200
	for i in samples + 1:
		var u := float(i) / float(samples)
		fly._play_u = u
		fly._progress_u = u
		fly._place_ship_at_path(u)
		fly._place_bodies_at(fly._clock)
		fly._update_sim_view()
		if not fly._body_nodes.has("jupiter"):
			continue
		var info = fly._body_nodes["jupiter"]
		var icon: Sprite3D = info["icon"]
		var mesh: MeshInstance3D = info["sphere"]
		var body_sim: Vector3 = OrbitMath.body_pos(info["data"], fly._clock)
		var cam_pos: Vector3 = fly._cam.global_position
		var dir: Vector3 = (body_sim - cam_pos).normalized()
		var fwd: Vector3 = -fly._cam.global_transform.basis.z
		var bearing: float = rad_to_deg(acos(clampf(fwd.dot(dir), -1.0, 1.0)))
		var iv := icon.visible
		var mv := mesh.visible
		if mv:
			mesh_vis += 1
		if iv and bearing < 32.0:
			nose_vis += 1
			print("FAIL nose pin u=%.3f bearing=%.1f" % [u, bearing])
		if iv and bearing >= 32.0 and bearing <= 98.0:
			abeam_vis += 1
			if abeam_vis <= 8 or i % 25 == 0:
				print("OK  abeam pin u=%.3f bearing=%.1f" % [u, bearing])
		elif iv:
			print("WARN pin outside window u=%.3f bearing=%.1f" % [u, bearing])
	print("SUMMARY nose_vis=%d abeam_vis=%d mesh_vis=%d" % [nose_vis, abeam_vis, mesh_vis])
	if nose_vis > 0 or mesh_vis > 0:
		print("RESULT FAIL")
		quit(1)
	elif abeam_vis < 1:
		print("RESULT FAIL (never showed abeam pin)")
		quit(1)
	else:
		# Closest approach ~0.6 — pin must not appear at departure.
		fly._play_u = 0.02
		fly._progress_u = 0.02
		fly._place_ship_at_path(0.02)
		fly._place_bodies_at(fly._clock)
		fly._update_sim_view()
		if fly._body_nodes["jupiter"]["icon"].visible:
			print("RESULT FAIL (early departure pin)")
			quit(1)
		print("RESULT PASS")
		quit(0)

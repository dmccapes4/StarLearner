extends SceneTree
## Marker LOD suite — pixel AR pins vs 3D mesh handoff for every flyer body.
##
##   ./qa/run_marker_lod_suite.sh
##
## For each object: far (pin only) → handoff (mesh ≈ marker size) → near (mesh).
## Exit 0 = all checks passed.

const VIEW := Vector2i(1280, 600)
const FlySceneScript := preload("res://scripts/FlyScene.gd")
const Starfield := preload("res://scripts/Starfield.gd")
const NavModes := preload("res://scripts/NavModes.gd")

var _shot_i: int = 0
var _out_abs: String = ""
var _manifest: Dictionary = {}
var _checks: Array = []

func _init() -> void:
	call_deferred("_run")

func _qa_out_root() -> String:
	var game_dir := ProjectSettings.globalize_path("res://").rstrip("/")
	return game_dir.get_base_dir().path_join("qa/out/marker_lod")

func _run() -> void:
	print("======== Solar MARKER LOD suite ========")
	root.get_viewport().size = VIEW
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	_out_abs = _qa_out_root().path_join(stamp)
	DirAccess.make_dir_recursive_absolute(_out_abs)
	_manifest = {
		"suite": "marker_lod",
		"stamp": stamp,
		"viewport": {"w": VIEW.x, "h": VIEW.y},
		"shots": [],
		"checks": [],
		"agent_brief": _agent_brief(),
	}

	var cfg := SolarFlyerConfig.load_default()
	_check_global_assets(cfg)
	await _check_every_body(cfg)

	_manifest["checks"] = _checks
	FileAccess.open(_out_abs.path_join("report.json"), FileAccess.WRITE) \
		.store_string(JSON.stringify(_manifest, "\t"))
	var fails := 0
	for c in _checks:
		if not c.get("ok", false):
			fails += 1
			print(" FAIL ", c.get("name"), " — ", c.get("detail"))
	print("MARKER LOD done → %s (%d shots, %d fails)" % [_out_abs, _shot_i, fails])
	quit(1 if fails > 0 else 0)

func _check_global_assets(cfg: SolarFlyerConfig) -> void:
	var earth_t := SolarData.icon_tier_for(SolarData.flyer_body_by_id("earth", cfg))
	_check("earth_tier_1", is_equal_approx(earth_t, 1.0), "tier=%s" % earth_t)
	var j_t := SolarData.icon_tier_for(SolarData.flyer_body_by_id("jupiter", cfg))
	var e_t := earth_t
	_check("jupiter_gt_2x_earth_tier", j_t >= e_t * 2.0, "j=%.2f e=%.2f" % [j_t, e_t])
	for b in SolarData.flyer_bodies(cfg):
		var id := str(b["id"])
		if bool(b.get("belt", false)):
			continue
		_check("pixel_marker_%s" % id, PlanetSkins.has_pixel_marker(id),
			PlanetSkins.marker_path_for(id))

func _check_every_body(cfg: SolarFlyerConfig) -> void:
	var bg := Starfield.new()
	root.add_child(bg)
	var fly: FlyScene = FlySceneScript.new()
	root.add_child(fly)
	fly.render_mode = NavModes.MODE_MARKERS
	fly.cinematic_enabled = false

	# Park a dummy Earth→Mars route so FlyScene is in flying state with bodies.
	var origin := SolarData.flyer_body_by_id("earth", cfg)
	var dest := SolarData.flyer_body_by_id("mars", cfg)
	var depart := OrbitMath.orbit_standoff(float(origin.get("hero_r", 2.0)))
	var route := OrbitMath.plot_route(OrbitMath.body_pos(origin, 0.0), dest, 0.0, cfg, depart)
	fly.set_active(true)
	fly.begin_flight("mars", route, 0.0)
	await _settle(6)
	# Freeze sim clock so probes are not racing autopilot completion.
	fly.set_process(false)
	fly.set_physics_process(false)
	fly._flying = true
	fly._orbiting = false

	var bodies: Array = []
	for b in SolarData.flyer_bodies(cfg):
		if bool(b.get("belt", false)):
			continue
		bodies.append(b)

	for b in bodies:
		await _probe_body(fly, cfg, b)

	# Earth→Saturn mid-cruise: Mars/Jupiter must stay AR pins (not playground 3D).
	await _probe_saturn_cruise_peers(fly, cfg)

	fly.queue_free()
	bg.queue_free()
	await _settle(2)

func _probe_saturn_cruise_peers(fly: FlyScene, cfg: SolarFlyerConfig) -> void:
	var earth := SolarData.flyer_body_by_id("earth", cfg)
	var saturn := SolarData.flyer_body_by_id("saturn", cfg)
	var depart := OrbitMath.orbit_standoff(float(earth.get("hero_r", 2.0)))
	var route := OrbitMath.plot_route(
		OrbitMath.body_pos(earth, 0.0), saturn, 0.0, cfg, depart)
	fly.set_process(false)
	fly.set_physics_process(false)
	fly.begin_flight("saturn", route, 0.0)
	fly.set_process(false)
	fly.set_physics_process(false)
	fly._flying = true
	fly._orbiting = false
	# Mid-course samples where peers used to loom as full hero meshes.
	for u in [0.25, 0.45, 0.65]:
		fly._play_u = u
		fly._place_ship_at_path(u)
		fly._update_markers()
		await process_frame
		for peer_id in ["mars", "jupiter"]:
			if not fly._body_nodes.has(peer_id):
				continue
			var info: Dictionary = fly._body_nodes[peer_id]
			var mesh: MeshInstance3D = info["sphere"]
			var icon: Sprite3D = info["icon"]
			var root: Node3D = info["root"]
			var dist: float = fly._cam.global_position.distance_to(root.global_position)
			var hero: float = float(info["data"].get("hero_r", 1.0))
			var handoff: float = OrbitMath.flyby_handoff_dist(
				hero, float(info["tier"]), cfg)
			# Outside handoff: must be AR pin (the Earth→Saturn loom bug).
			if dist > handoff:
				_check("saturn_cruise_%s_u%.2f_pin" % [peer_id, u],
					icon.visible and not mesh.visible,
					"icon=%s mesh=%s dist=%.1f handoff=%.1f" % [
						icon.visible, mesh.visible, dist, handoff])
			else:
				_check("saturn_cruise_%s_u%.2f_close_ok" % [peer_id, u],
					mesh.visible or icon.visible,
					"close pass dist=%.1f handoff=%.1f mesh_s=%.2f" % [
						dist, handoff, mesh.scale.x if mesh.visible else 0.0])
		await _shot("saturn_cruise_u%.0f" % (u * 100.0),
			"Earth→Saturn cruise u=%.2f — peers as AR pins unless true flyby" % u)

func _probe_body(fly: FlyScene, cfg: SolarFlyerConfig, b: Dictionary) -> void:
	var id := str(b["id"])
	if not fly._body_nodes.has(id):
		_check("body_built_%s" % id, false, "missing from FlyScene")
		return
	var info: Dictionary = fly._body_nodes[id]
	var root: Node3D = info["root"]
	var icon: Sprite3D = info["icon"]
	var mesh: MeshInstance3D = info["sphere"]
	var hero: float = float(b.get("hero_r", 1.0))
	var tier: float = float(info["tier"])
	var handoff: float = OrbitMath.flyby_handoff_dist(hero, tier, cfg)

	# Force camera looking at body from controlled distances.
	var body_pos: Vector3 = root.global_position
	if body_pos.length() < 0.01:
		body_pos = Vector3(hero * 20.0, 0, 0)
		root.global_position = body_pos

	# FAR — clearly outside handoff (not the trip destination → peer rules)
	var d_far: float = handoff * 2.5
	_place_cam(fly, body_pos, d_far)
	fly._flying = true
	fly._orbiting = false
	fly._play_u = 0.4
	fly._dest_id = "mars" if id != "mars" else "earth"
	fly._update_markers()
	await process_frame
	var far_icon: bool = icon.visible
	var far_mesh: bool = mesh.visible
	# Sun as non-dest stays pin; others stay pin when far.
	_check("%s_far_pin" % id, far_icon and not far_mesh,
		"icon=%s mesh=%s dist=%.1f handoff=%.1f" % [far_icon, far_mesh, d_far, handoff])
	_check("%s_far_pixel_tex" % id,
		icon.texture != null and PlanetSkins.has_pixel_marker(id),
		"has baked marker")
	await _shot("%s_far" % id, "FAR %s — AR pin only (chunky pixels, no 3D planet)" % id)

	# HANDOFF — just inside handoff; probe as destination so Sun also swaps.
	var d_hand: float = handoff * 0.92
	_place_cam(fly, body_pos, d_hand)
	fly._flying = true
	fly._orbiting = false
	fly._dest_id = id
	fly._play_u = 0.5
	fly._update_markers()
	await process_frame
	var hand_mesh: bool = mesh.visible
	var hand_icon: bool = icon.visible
	var scale_ok := true
	var detail := "icon=%s mesh=%s" % [hand_icon, hand_mesh]
	if hand_mesh:
		var ms: float = mesh.scale.x
		var marker_w: float = OrbitMath.marker_world_size(d_hand, tier, cfg)
		# Mesh should be near marker size at onset (not a huge nearby planet).
		scale_ok = ms <= maxf(marker_w * 1.6, 0.12) + 0.05 and ms > 0.02 \
			and ms < hero * 0.55 + 0.05
		detail += " mesh_s=%.2f marker_w=%.2f hero=%.2f" % [ms, marker_w, hero]
	_check("%s_handoff_mesh" % id, hand_mesh and not hand_icon,
		detail)
	_check("%s_handoff_size_match" % id, scale_ok, detail)
	await _shot("%s_handoff" % id,
		"HANDOFF %s — 3D replaces pin near marker size" % id)

	# NEAR — closer; mesh grows (clearance-capped)
	var d_near: float = maxf(handoff * 0.35, hero * 3.0)
	_place_cam(fly, body_pos, d_near)
	fly._flying = true
	fly._orbiting = false
	fly._dest_id = id
	fly._play_u = 0.5
	fly._update_markers()
	await process_frame
	_check("%s_near_mesh" % id, mesh.visible and not icon.visible,
		"scale=%.2f dist=%.1f" % [mesh.scale.x, d_near])
	if mesh.visible:
		_check("%s_near_clearance" % id,
			mesh.scale.x <= d_near * OrbitMath.FLYBY_CLEARANCE + 0.05,
			"scale=%.2f cap=%.2f" % [mesh.scale.x, d_near * OrbitMath.FLYBY_CLEARANCE])
	await _shot("%s_near" % id, "NEAR %s — 3D mesh, pin gone" % id)

func _place_cam(fly: FlyScene, body_pos: Vector3, dist: float) -> void:
	var cam: Camera3D = fly._cam
	var dir := Vector3(0, 0.08, 1).normalized()
	cam.global_position = body_pos + dir * dist
	cam.look_at(body_pos, Vector3.UP)

func _shot(id: String, note: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var file := "%02d_%s.png" % [_shot_i, id]
	var img: Image = root.get_viewport().get_texture().get_image()
	if img:
		img.save_png(_out_abs.path_join(file))
	_manifest["shots"].append({"file": file, "id": id, "note": note})
	_shot_i += 1
	print(" shot ", file)

func _settle(n: int) -> void:
	for _i in n:
		await process_frame

func _check(name: String, ok: bool, detail: String) -> void:
	_checks.append({"name": name, "ok": ok, "detail": detail})
	print(("OK  " if ok else "FAIL"), " ", name, " — ", detail)

func _agent_brief() -> String:
	return """Marker LOD suite. For each body id look at *_far.png (chunky AR pin with brackets — NOT a smooth planet photo), *_handoff.png (3D mesh replaces pin at similar size), *_near.png (3D only). FAIL means wrong visibility or mesh oversized at handoff. Fix FlyScene/OrbitMath/PlanetSkins — do not soften asserts."""

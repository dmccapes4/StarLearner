extends SceneTree
## Depth interaction stress suite — for agents to run and interpret screenshots.
##
##   ./qa/run_depth_suite.sh
##   godot --path game -s res://tools/depth_suite.gd
##
## Places the player at known stress points (beds, path, gate, coop, shed),
## waits for depth settle, and writes PNGs + a JSON manifest under:
##   qa/out/depth_suite/<timestamp>/
##
## Exit 0 = captures completed (agent judges PNGs). Exit 1 = setup failure.

const VIEW := Vector2i(1280, 720)

var _shot_i: int = 0
var _out_abs: String = ""
var _manifest: Dictionary = {}
var _checks: Array = []

func _init() -> void:
	call_deferred("_run")

func _qa_out_root() -> String:
	## game/ → garden_explorer/qa/out/depth_suite
	var game_dir := ProjectSettings.globalize_path("res://").rstrip("/")
	return game_dir.get_base_dir().path_join("qa/out/depth_suite")

func _run() -> void:
	print("======== Garden Explorer DEPTH suite ========")
	root.get_viewport().size = VIEW
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	_out_abs = _qa_out_root().path_join(stamp)
	DirAccess.make_dir_recursive_absolute(_out_abs)
	_manifest = {
		"suite": "depth",
		"stamp": stamp,
		"viewport": {"w": VIEW.x, "h": VIEW.y},
		"shots": [],
		"checks": [],
		"agent_brief": _agent_brief(),
	}

	var save := root.get_node_or_null("/root/Save")
	if save:
		if save.has_method("clear_all"):
			save.clear_all()
		if save.has_method("set_intro_completed"):
			save.set_intro_completed(true)
		if save.has_method("set_flag"):
			save.set_flag("shed_tools_intro", true)
	var ig := root.get_node_or_null("/root/IdleGuard")
	if ig and ig.has_method("set_active"):
		ig.set_active(false)

	var MainScene := load("res://scenes/Main.tscn")
	if MainScene == null:
		_fail_quit("Main.tscn failed to load")
		return
	var main: Node = MainScene.instantiate()
	root.add_child(main)
	await _settle(12)
	paused = false
	await _skip_intro(main)

	var world: Node = main.get_node_or_null("World")
	if world == null:
		_fail_quit("World missing")
		return
	var farm: FarmMap = world.get("farm_map") as FarmMap
	var player: Node2D = world.get("player") as Node2D
	var gate: Node2D = world.get("pen_gate") as Node2D
	if farm == null:
		farm = main.find_child("FarmMap", true, false) as FarmMap
	if player == null:
		player = main.find_child("Player", true, false) as Node2D
	if farm == null or player == null:
		_fail_quit("FarmMap/Player missing")
		return

	_check("six_beds", farm.bed_count() == 6, "beds=%d" % farm.bed_count())
	_check("gate_world", farm.gate_world != Vector2.ZERO, "gate=%s" % farm.gate_world)
	_check("coop_solid", farm.is_blocked(farm.coop_world), "coop blocked")

	## --- Stress points (world coords). Agent: inspect each PNG for z-order. ---
	var points: Array = _stress_points(farm)
	for p in points:
		await _capture_pose(player, farm, gate, str(p["id"]), str(p["note"]), p["pos"] as Vector2, bool(p.get("open_gate", false)))

	## Walk-past simulation: short path along dirt, frames while moving.
	await _walk_capture(world, player, farm, "walk_path_beds",
		farm.slot_world("bed_0", 2) + Vector2(0, 40),
		farm.slot_world("bed_2", 2) + Vector2(0, 40),
		[0.15, 0.4, 0.65, 0.9])

	await _walk_capture(world, player, farm, "walk_south_beds",
		farm.bed_centers["bed_3"] + Vector2(-80, 50),
		farm.bed_centers["bed_5"] + Vector2(80, 50),
		[0.2, 0.5, 0.8])

	await _walk_capture(world, player, farm, "walk_gate",
		farm.gate_world + Vector2(-90, 24),
		farm.gate_world + Vector2(40, 10),
		[0.0, 0.35, 0.7, 1.0])

	_manifest["checks"] = _checks
	var report_path := _out_abs.path_join("report.json")
	FileAccess.open(report_path, FileAccess.WRITE).store_string(JSON.stringify(_manifest, "\t"))
	print("DEPTH suite done → %s (%d shots)" % [_out_abs, _shot_i])
	var fails := 0
	for c in _checks:
		if not c.get("ok", false):
			fails += 1
			print(" FAIL ", c.get("name"), " — ", c.get("detail"))
	quit(1 if fails > 0 else 0)

func _stress_points(farm: FarmMap) -> Array:
	var gw: Vector2 = farm.gate_world
	var path_y := IsoUtil.tile_to_world(Vector2(3.0, float(farm.data.get("path", {}).get("tile_y", 3.0)))).y
	return [
		{"id": "01_spawn", "note": "Spawn on path — baseline feet vs ground",
			"pos": farm.spawn_world},
		{"id": "02_path_north_bed1", "note": "On path beside north bed_1 — feet must NOT sink under bed lip incorrectly; bed must NOT float over torso when south of bed",
			"pos": Vector2(farm.bed_centers["bed_1"].x, path_y)},
		{"id": "03_path_south_bed4", "note": "On path beside south bed_4 — must NOT walk ON TOP of bed (player over soil). Bed lip may cover feet (behind).",
			"pos": Vector2(farm.bed_centers["bed_4"].x, path_y)},
		{"id": "04_south_of_bed4", "note": "South of bed_4 (in front) — player draws in FRONT of bed walls/top",
			"pos": farm.bed_centers["bed_4"] + Vector2(0, 55)},
		{"id": "05_north_of_bed1", "note": "North of bed_1 (behind) — bed should occlude player feet/body",
			"pos": farm.bed_centers["bed_1"] + Vector2(0, -48)},
		{"id": "06_aisle_beds_01", "note": "Aisle between bed_0 and bed_1",
			"pos": (farm.bed_centers["bed_0"] + farm.bed_centers["bed_1"]) * 0.5 + Vector2(0, 8)},
		{"id": "07_bed4_approach", "note": "Nearest walkable to bed_4 slot — not inside solid",
			"pos": farm.nearest_walkable(farm.slot_world("bed_4", 0))},
		{"id": "08_gate_closed", "note": "Outside gate — leaf rails level with fence; end post present (not a rail fork)",
			"pos": gw + Vector2(-70, 20), "open_gate": false},
		{"id": "09_gate_open", "note": "In open range — gate swings; depth vs posts OK",
			"pos": gw + Vector2(-18, 8), "open_gate": true},
		{"id": "10_coop_door", "note": "Coop door apron — player in front of coop, not through body",
			"pos": farm.coop_approach_world()},
		{"id": "11_coop_behind", "note": "Behind coop — path routes around; sprite occludes correctly",
			"pos": farm.nearest_walkable(farm.coop_world + Vector2(0, -70))},
		{"id": "12_shed_door", "note": "Shed door apron — in front of facade",
			"pos": farm.shed_door_world if farm.shed_door_world != Vector2.ZERO else farm.nearest_walkable(farm.shed_center + Vector2(40, 24))},
		{"id": "13_pen_inside", "note": "Inside pen near gate — fence posts vs player",
			"pos": gw + Vector2(50, 20), "open_gate": true},
	]

func _capture_pose(player: Node2D, farm: FarmMap, gate: Node2D, id: String, note: String, pos: Vector2, open_gate: bool) -> void:
	var goal := farm.nearest_walkable(pos)
	player.global_position = goal
	if player.has_method("stop"):
		player.call("stop")
	## Nudge gate open/closed by proximity.
	if gate != null and open_gate:
		player.global_position = farm.gate_world + Vector2(-15, 6)
	await _settle(8)
	_aim_cam(player)
	await _settle(4)
	var file := "%02d_%s.png" % [_shot_i, id]
	_save_png(file)
	_manifest["shots"].append({
		"file": file,
		"id": id,
		"note": note,
		"player": {"x": player.global_position.x, "y": player.global_position.y},
		"open_gate": open_gate,
	})
	print(" shot ", file, " — ", note)

func _walk_capture(world: Node, player: Node2D, farm: FarmMap, prefix: String, a: Vector2, b: Vector2, fracs: Array) -> void:
	a = farm.nearest_walkable(a)
	b = farm.nearest_walkable(b)
	player.global_position = a
	if player.has_method("stop"):
		player.call("stop")
	await _settle(4)
	## Instant poses along the segment (deterministic for agents).
	for f in fracs:
		var t := float(f)
		var p: Vector2 = a.lerp(b, t)
		player.global_position = farm.nearest_walkable(p)
		IsoUtil.apply_depth(player, player.global_position.y, IsoUtil.BIAS_PLAYER)
		await _settle(5)
		_aim_cam(player)
		await _settle(3)
		var file := "%02d_%s_t%.2f.png" % [_shot_i, prefix, t]
		_save_png(file)
		_manifest["shots"].append({
			"file": file,
			"id": "%s_t%.2f" % [prefix, t],
			"note": "Walk segment %s at t=%.2f — check bed/fence/gate occlusion vs feet" % [prefix, t],
			"player": {"x": player.global_position.x, "y": player.global_position.y},
		})
		print(" shot ", file)

func _aim_cam(player: Node2D) -> void:
	var cam := player.get_parent().get_node_or_null("CameraFollow") as Camera2D
	if cam == null:
		cam = root.find_child("CameraFollow", true, false) as Camera2D
	if cam:
		if cam.has_method("set_follow_target"):
			cam.call("set_follow_target", player)
		if cam.has_method("snap_to_target"):
			cam.call("snap_to_target")
		else:
			cam.global_position = player.global_position

func _save_png(file_name: String) -> void:
	await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	if img == null:
		print("WARN no image for ", file_name)
		return
	var path := _out_abs.path_join(file_name)
	img.save_png(path)
	_shot_i += 1

func _skip_intro(main: Node) -> void:
	var intro: Node = main.get_node_or_null("IntroPanel")
	if intro and intro.has_method("_on_start"):
		intro.visible = true
		if intro.get("_panel") != null:
			intro._panel.visible = true
		intro.call("_on_start")
		await _settle(6)
		var video: Node = main.get_node_or_null("VideoPanel")
		if video and video.has_method("is_open") and bool(video.call("is_open")) and video.has_method("_close"):
			video.call("_close")
		intro.visible = false
	paused = false
	await _settle(4)

func _settle(frames: int) -> void:
	for _i in frames:
		await process_frame

func _check(name: String, ok: bool, detail: String) -> void:
	_checks.append({"name": name, "ok": ok, "detail": detail})
	print(("OK  " if ok else "FAIL"), " ", name, " — ", detail)

func _fail_quit(msg: String) -> void:
	print("FATAL ", msg)
	_manifest["fatal"] = msg
	DirAccess.make_dir_recursive_absolute(_out_abs)
	FileAccess.open(_out_abs.path_join("report.json"), FileAccess.WRITE).store_string(JSON.stringify(_manifest, "\t"))
	quit(1)

func _agent_brief() -> String:
	return """Interpret each PNG in shots[]. For beds: player must not appear to walk on soil (sprite over bed top while feet in footprint). Standing south of a bed → player in front; north → bed occludes. Gate: rails level with fence; swinging end has a post (not a bare fork). Coop/shed: feet in front when on door apron. Write a short verdict per shot id in your reply to the user."""

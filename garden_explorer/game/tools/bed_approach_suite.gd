extends SceneTree
## Bed approach / gap-routing suite — for agents to run and refine.
##
##   ./qa/run_bed_approach_suite.sh
##
## Asserts that tapping a nearby bed chooses a short path through the row gap /
## dirt path, and that the stand face matches tap side. Writes screenshots +
## report under qa/out/bed_approach/<stamp>/.

const VIEW := Vector2i(1280, 720)

var _out_abs: String = ""
var _shot_i: int = 0
var _checks: Array = []
var _shots: Array = []

func _init() -> void:
	call_deferred("_run")

func _qa_root() -> String:
	var game_dir := ProjectSettings.globalize_path("res://").rstrip("/")
	return game_dir.get_base_dir().path_join("qa/out/bed_approach")

func _run() -> void:
	print("======== Garden Explorer BED APPROACH suite ========")
	root.get_viewport().size = VIEW
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	_out_abs = _qa_root().path_join(stamp)
	DirAccess.make_dir_recursive_absolute(_out_abs)

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

	var main: Node = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _settle(12)
	paused = false
	await _skip_intro(main)

	var world: Node = main.get_node_or_null("World")
	var farm: FarmMap = world.get("farm_map") as FarmMap if world else null
	var player: Node2D = world.get("player") as Node2D if world else null
	if farm == null or player == null:
		_finish(false, "FarmMap/Player missing")
		return

	_check("has_bed_approach", farm.has_method("bed_approach_world"), "API present")

	## Case A: on path beside bed_0, tap bed_1 (upper middle to the right).
	## Must go along the path / gap — not loop south around bed_3/4/5.
	var path_y := IsoUtil.tile_to_world(Vector2(0.0, float(farm.data.get("path", {}).get("tile_y", 3.0)))).y
	var start_a := farm.nearest_walkable(Vector2(farm.bed_centers["bed_0"].x, path_y))
	var tap_a: Vector2 = farm.bed_centers["bed_1"]
	var ap_a: Vector2 = farm.bed_approach_world("bed_1", start_a, tap_a)
	var len_a := farm.path_world_length(start_a, ap_a)
	## Naive far-side approach (south of bed_1) should be a worse detour.
	var south_face := farm.nearest_walkable(farm.bed_centers["bed_1"] + Vector2(0, 70))
	var len_naive := farm.path_world_length(start_a, south_face)
	_check("path_to_bed1_short", len_a < 220.0, "len=%.1f (want <220)" % len_a)
	_check("path_beats_far_loop", len_a <= len_naive * 0.85 or len_a < len_naive - 40.0,
		"chosen=%.1f naive_south=%.1f" % [len_a, len_naive])
	_check("approach_not_deep_south", ap_a.y < farm.bed_centers["bed_3"].y + 8.0,
		"approach.y=%.1f bed3.y=%.1f" % [ap_a.y, farm.bed_centers["bed_3"].y])
	_check("approach_not_world_south_aisle",
		ap_a.distance_to(farm.bed_centers["bed_1"]) <= 64.0 \
		or absf(ap_a.x - farm.bed_centers["bed_1"].x) >= 18.0,
		"ap=%s (iso face, not pure +Y aisle)" % ap_a)
	## From the dirt path, stand on the path-side (south) of the north bed — not behind it.
	_check("bed1_from_path_stands_south",
		ap_a.y >= farm.bed_centers["bed_1"].y + 12.0,
		"approach.y=%.1f bed1.y=%.1f (want path/south face)" % [ap_a.y, farm.bed_centers["bed_1"].y])
	await _shot_case(player, farm, start_a, ap_a, tap_a, "A_path_bed0_to_bed1",
		"From path at bed_0, tap bed_1 — route should stay on path/gap")

	## Case B: on path, tap south bed_4 — approach north face (path side).
	var start_b := farm.nearest_walkable(Vector2(farm.bed_centers["bed_4"].x, path_y))
	var tap_b_north: Vector2 = farm.bed_centers["bed_4"] + Vector2(0, -20)
	var ap_b: Vector2 = farm.bed_approach_world("bed_4", start_b, tap_b_north)
	var south_b := farm.nearest_walkable(farm.bed_centers["bed_4"] + Vector2(0, 70))
	_check("bed4_from_path_prefers_north",
		ap_b.distance_to(start_b) < south_b.distance_to(start_b) + 30.0 \
		and farm.path_world_length(start_b, ap_b) <= farm.path_world_length(start_b, south_b) * 1.05,
		"ap=%s south=%s" % [ap_b, south_b])
	await _shot_case(player, farm, start_b, ap_b, tap_b_north, "B_path_to_bed4_north",
		"From path, tap north lip of bed_4 — stand on path side")

	## Case C: south of bed_4, tap south lip — approach south face, short walk.
	var start_c := farm.nearest_walkable(farm.bed_centers["bed_4"] + Vector2(0, 80))
	var tap_c: Vector2 = farm.bed_centers["bed_4"] + Vector2(0, 25)
	var ap_c: Vector2 = farm.bed_approach_world("bed_4", start_c, tap_c)
	var len_c := farm.path_world_length(start_c, ap_c)
	_check("bed4_from_south_short", len_c < 120.0, "len=%.1f" % len_c)
	_check("bed4_from_south_face", ap_c.y >= farm.bed_centers["bed_4"].y - 10.0,
		"approach.y=%.1f center.y=%.1f" % [ap_c.y, farm.bed_centers["bed_4"].y])
	await _shot_case(player, farm, start_c, ap_c, tap_c, "C_south_to_bed4",
		"From south of bed_4, tap south lip — short walk to near face")

	## Case D: between bed_0 and bed_1 on path, tap bed_2 — through gaps eastward.
	var start_d := farm.nearest_walkable(Vector2(
		(farm.bed_centers["bed_0"].x + farm.bed_centers["bed_1"].x) * 0.5, path_y))
	var tap_d: Vector2 = farm.bed_centers["bed_2"]
	var ap_d: Vector2 = farm.bed_approach_world("bed_2", start_d, tap_d)
	var len_d := farm.path_world_length(start_d, ap_d)
	var path_d := farm.find_path(start_d, ap_d)
	var max_y := start_d.y
	for p in path_d:
		max_y = maxf(max_y, p.y)
	_check("bed2_gap_route", len_d < 280.0, "len=%.1f" % len_d)
	_check("bed2_not_loop_south_meadow", max_y < farm.bed_centers["bed_4"].y + 40.0,
		"max_path_y=%.1f" % max_y)
	await _shot_case(player, farm, start_d, ap_d, tap_d, "D_gap_to_bed2",
		"Between bed_0/1, tap bed_2 — east along path, not around south row")

	## Case E: World interact uses the same API (live walk).
	player.global_position = start_a
	if player.has_method("stop"):
		player.call("stop")
	await _settle(4)
	var ev: Node = root.get_node_or_null("/root/Events")
	if ev:
		ev.world_tapped.emit(tap_a)
	await _settle(8)
	var pending: Variant = world.get("_pending")
	var live_ap := Vector2.ZERO
	if typeof(pending) == TYPE_DICTIONARY:
		live_ap = (pending as Dictionary).get("approach", Vector2.ZERO)
	if live_ap == Vector2.ZERO and player.get("target") != null:
		live_ap = player.get("target") as Vector2
	var live_len := farm.path_world_length(start_a, live_ap) if live_ap != Vector2.ZERO else 9999.0
	_check("world_queue_uses_smart_approach", live_ap != Vector2.ZERO and live_len < 240.0,
		"pending=%s len=%.1f" % [pending, live_len])
	await _settle(30)
	_aim(player)
	await _settle(4)
	await _save_png("E_live_tap_bed1_midwalk.png", "Live tap bed_1 from path — mid-walk frame")

	## Case F: stand next to bed lip (clear of wood, not mid-path) + face the bed.
	for bid in ["bed_1", "bed_4"]:
		var ctr: Vector2 = farm.bed_centers[bid]
		var from_f := farm.nearest_walkable(Vector2(ctr.x, path_y))
		var ap_f: Vector2 = farm.bed_approach_world(bid, from_f, ctr)
		var d_f := ap_f.distance_to(ctr)
		_check("stand_next_to_%s" % bid,
			d_f >= 36.0 and d_f <= 72.0 and not farm.is_blocked(ap_f),
			"dist=%.1f blocked=%s" % [d_f, farm.is_blocked(ap_f)])
	## Live interact pose via World (snap + face + depth nudge).
	player.global_position = start_a
	if player.has_method("stop"):
		player.call("stop")
	await _settle(3)
	var ev2: Node = root.get_node_or_null("/root/Events")
	if ev2:
		ev2.world_tapped.emit(tap_a)
	## Wait for walk-arrive + prompt pose.
	for _i in 90:
		await process_frame
		if not bool(player.get("moving")):
			break
	await _settle(8)
	_aim(player)
	await _settle(4)
	var pose_pos: Vector2 = player.global_position
	var pose_d := pose_pos.distance_to(farm.bed_centers["bed_1"])
	_check("interact_stand_next_to_bed",
		pose_d >= 36.0 and pose_d <= 90.0 and not farm.is_blocked(pose_pos),
		"dist=%.1f pos=%s" % [pose_d, pose_pos])
	## Depth: walk stand should already clear the lip (no post-arrive teleport).
	var pose_need_z := -9999
	for suffix in ["", "_soil", "_wall_e", "_wall_w", "_grid_a", "_grid_b"]:
		var piece: CanvasItem = farm.get_node_or_null("bed_1" + suffix) as CanvasItem
		if piece:
			pose_need_z = maxi(pose_need_z, piece.z_index)
	_check("interact_depth_in_front", player.z_index >= pose_need_z,
		"player.z=%d need.z=%d" % [player.z_index, pose_need_z])
	var to_bed2: Vector2 = farm.bed_centers["bed_1"] - pose_pos
	var row2 := int(player.get("_dir_row")) if player.get("_dir_row") != null else -1
	var face_ok2 := false
	if absf(to_bed2.x) >= absf(to_bed2.y) * 0.85:
		face_ok2 = row2 == 1
	else:
		face_ok2 = (row2 == 2 and to_bed2.y < 0.0) or (row2 == 0 and to_bed2.y > 0.0)
	_check("face_bed_on_interact_pose", face_ok2,
		"dir_row=%s to_bed=%s" % [row2, to_bed2])
	## Raised NW corner must not sit above the gardener (deck z < player z).
	var deck_z := -9999
	for suffix in ["", "_soil"]:
		var deck_piece: CanvasItem = farm.get_node_or_null("bed_1" + suffix) as CanvasItem
		if deck_piece:
			deck_z = maxi(deck_z, deck_piece.z_index)
	_check("interact_above_raised_corner", player.z_index > deck_z,
		"player.z=%d deck.z=%d" % [player.z_index, deck_z])
	await _save_png("F_interact_pose_bed1.png",
		"Interact pose: next to bed_1 lip, facing bed, clear of raised NW corner")
	_shots.append({"id": "F_interact_pose", "note": "next to bed + facing it",
		"approach": _v(pose_pos), "tap": _v(tap_a)})

	## Case G: west of bed_1, tap east lip — walk BETWEEN beds (gap), not around south row.
	var west_g := farm.nearest_walkable(farm.bed_centers["bed_1"] + Vector2(-70, 10))
	var tap_east: Vector2 = farm.bed_centers["bed_1"] + Vector2(40, 0)
	var ap_g: Vector2 = farm.bed_approach_world("bed_1", west_g, tap_east)
	var path_g := farm.find_path(west_g, ap_g)
	var len_g := farm.path_world_length(west_g, ap_g)
	var max_y_g := west_g.y
	for p in path_g:
		max_y_g = maxf(max_y_g, p.y)
	_check("opposite_side_gap_short", len_g < FarmMap.BED_GAP_PATH_MAX, "len=%.1f" % len_g)
	_check("opposite_side_not_south_loop", max_y_g < farm.bed_centers["bed_4"].y + 30.0,
		"max_y=%.1f bed4.y=%.1f" % [max_y_g, farm.bed_centers["bed_4"].y])
	_check("opposite_side_stands_eastish",
		ap_g.x >= farm.bed_centers["bed_1"].x - 8.0,
		"ap.x=%.1f center.x=%.1f" % [ap_g.x, farm.bed_centers["bed_1"].x])
	await _shot_case(player, farm, west_g, ap_g, tap_east, "G_west_tap_east_gap",
		"West of bed_1, tap east — through gap between beds, stand on east face")

	## Case H: dog stays clear of beds (nav + depth — not painted under wood).
	var dog: Node2D = null
	for a in world.get_children():
		if a is Node2D and str(a.get("animal_id")) == "dog":
			dog = a
			break
	if dog == null:
		dog = world.find_child("RoamingAnimal*", true, false) as Node2D
	_check("dog_present", dog != null, "yard dog node")
	if dog:
		_check("dog_spawn_not_on_bed", not farm.is_blocked(dog.global_position) \
			and not farm.is_blocked_for_dog(dog.global_position),
			"pos=%s" % dog.global_position)
		## Path-side rim south of bed_1 (pause AI — dog ejects from bed clearance).
		var dog_stand: Vector2 = farm.nearest_walkable(farm.bed_centers["bed_1"] + Vector2(0, 58))
		var dog_saved := dog.global_position
		dog.set_process(false)
		dog.global_position = dog_stand
		IsoUtil.apply_depth(dog, dog.global_position.y, IsoUtil.BIAS_ANIMAL)
		await _settle(3)
		var bed_node: CanvasItem = farm.get_node_or_null("bed_1") as CanvasItem
		var bed_z := bed_node.z_index if bed_node else -9999
		var dog_z_expect := IsoUtil.depth_z(dog_stand.y, IsoUtil.BIAS_ANIMAL)
		_check("dog_depth_in_front_of_bed", dog.z_index >= bed_z and dog_z_expect >= bed_z,
			"dog.z=%d expect=%d bed.z=%d stand.y=%.1f" % [dog.z_index, dog_z_expect, bed_z, dog_stand.y])
		_check("dog_stand_not_in_bed_poly", not farm.is_blocked(dog.global_position),
			"blocked=%s" % farm.is_blocked(dog.global_position))
		_aim(dog)
		await _settle(3)
		await _save_png("H_dog_at_bed1_rim.png", "Dog south of bed_1 — clear of lip, in front of wood")
		dog.global_position = dog_saved
		IsoUtil.apply_depth(dog, dog.global_position.y, IsoUtil.BIAS_ANIMAL)
		dog.set_process(true)

	## Case I: bug ejects from bed solid + sorts in front when south of bed.
	var spawner: Node = world.get("bug_spawner") as Node
	if spawner == null:
		spawner = world.get_node_or_null("BugSpawner")
	_check("bug_spawner_present", spawner != null and spawner.has_method("force_spawn"), "BugSpawner")
	if spawner and spawner.has_method("force_spawn"):
		var bug: Node2D = spawner.call("force_spawn", "ladybug",
			farm.bed_centers["bed_1"] + Vector2(0, 70)) as Node2D
		_check("bug_spawned", bug != null, "force_spawn ladybug")
		if bug:
			_check("bug_spawn_not_on_bed", not farm.is_blocked_for_bug(bug.global_position),
				"pos=%s" % bug.global_position)
			## Drop onto bed soil — next frames must eject clear of the lip.
			bug.global_position = farm.bed_centers["bed_1"]
			for _i in 10:
				bug.set_process(true)
				await process_frame
			_check("bug_ejects_from_bed", not farm.is_blocked_for_bug(bug.global_position),
				"pos=%s blocked=%s" % [bug.global_position, farm.is_blocked_for_bug(bug.global_position)])
			## South stand: depth in front of bed top.
			bug.global_position = farm.nearest_walkable(farm.bed_centers["bed_1"] + Vector2(0, 70))
			IsoUtil.apply_depth(bug, bug.global_position.y, IsoUtil.BIAS_ANIMAL)
			await _settle(3)
			var bed_n2: CanvasItem = farm.get_node_or_null("bed_1") as CanvasItem
			var bed_z2 := bed_n2.z_index if bed_n2 else -9999
			_check("bug_depth_in_front_of_bed", bug.z_index >= bed_z2,
				"bug.z=%d bed.z=%d" % [bug.z_index, bed_z2])
			_check("bug_rim_clear_of_lip",
				bug.global_position.distance_to(farm.bed_centers["bed_1"]) >= 60.0,
				"dist=%.1f" % bug.global_position.distance_to(farm.bed_centers["bed_1"]))
			_aim(bug)
			await _settle(3)
			await _save_png("I_bug_at_bed1_rim.png", "Bug on bed_1 rim — not under wood")
			if bug.has_method("catch_and_free"):
				bug.call("catch_and_free")

	_finish(true, "")

func _shot_case(player: Node2D, farm: FarmMap, start: Vector2, approach: Vector2, tap: Vector2, id: String, note: String) -> void:
	player.global_position = start
	if player.has_method("stop"):
		player.call("stop")
	await _settle(4)
	_aim(player)
	await _settle(3)
	await _save_png("%s_start.png" % id, note + " (start)")
	## Draw path endpoints: teleport to approach for end pose.
	player.global_position = approach
	IsoUtil.apply_depth(player, player.global_position.y, IsoUtil.BIAS_PLAYER)
	await _settle(4)
	_aim(player)
	await _settle(3)
	await _save_png("%s_approach.png" % id, note + " (approach stand)")
	_shots.append({"id": id, "note": note, "start": _v(start), "approach": _v(approach), "tap": _v(tap)})

func _v(p: Vector2) -> Dictionary:
	return {"x": p.x, "y": p.y}

func _aim(player: Node2D) -> void:
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

func _save_png(file_name: String, note: String) -> void:
	await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	if img:
		img.save_png(_out_abs.path_join(file_name))
	_shot_i += 1
	_shots.append({"file": file_name, "note": note})
	print(" shot ", file_name)

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

func _settle(n: int) -> void:
	for _i in n:
		await process_frame

func _check(name: String, ok: bool, detail: String) -> void:
	_checks.append({"name": name, "ok": ok, "detail": detail})
	print(("OK  " if ok else "FAIL"), " ", name, " — ", detail)

func _finish(ok_setup: bool, fatal: String) -> void:
	var fails := 0
	for c in _checks:
		if not c.get("ok", false):
			fails += 1
	var report := {
		"suite": "bed_approach",
		"fatal": fatal,
		"checks": _checks,
		"shots": _shots,
		"agent_brief": "Fail = long loop around beds or wrong face. Pass = short path through dirt path / gaps; stand face matches tap side.",
	}
	FileAccess.open(_out_abs.path_join("report.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("BED APPROACH suite → %s  fails=%d" % [_out_abs, fails])
	quit(1 if (not ok_setup or fails > 0) else 0)

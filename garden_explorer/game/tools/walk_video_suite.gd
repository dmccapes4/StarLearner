extends SceneTree
## Record short yard-walk clips with per-frame game-state ground truth.
##
##   ./qa/run_walk_video_suite.sh
##
## Each clip folder under qa/out/walk_video/<stamp>/<clip_id>/:
##   frames/f_XXXX.png   — rendered yard
##   state.jsonl         — one JSON object per frame (sim / expected UX)
##   route.json          — clip intent + waypoints
##   meta.json           — timing / fps
##
## Shell runner muxes frames → walk.mp4 and optionally runs Grok vision review.

const NarratorLib := preload("res://scripts/audio/Narrator.gd")

## Match project window (even dims for ffmpeg/libx264).
const VIEW := Vector2i(1280, 600)
const CAPTURE_FPS := 12
const TARGET_S := 7.0

var _ev: Node ## /root/Events (resolved at runtime for -s scripts)

## Kid-shaped stress clips: movement routing, depth, seeds, Buddy, gate, shed.
const CLIPS := [
	{
		"id": "walk_path_beds",
		"note": "Dirt path past north beds — player must not sink under bed lips; route stays on path",
		"setup": "empty",
		"from": "path_west",
		"to": "path_east",
	},
	{
		"id": "walk_south_lip",
		"note": "South of bed_4/5 — gardener draws in FRONT of bed + grown packs (not under soil)",
		"setup": "grown_south",
		"from": "south_bed3",
		"to": "south_bed5",
	},
	{
		"id": "plant_seed_bed",
		"note": "Fresh seeds on bed_1 — four plot-centered seed clusters visible on soil, not under wood",
		"setup": "seed_bed1",
		"from": "path_west",
		"to": "south_bed1_near",
	},
	{
		"id": "gate_to_pen",
		"note": "Approach + cross pen gate — rails/posts depth, no fence fork, pen pets look natural",
		"setup": "empty",
		"from": "path_east",
		"to": "pen_in",
	},
	{
		"id": "dog_yard_walk",
		"note": "Walk past Buddy — facing should follow walk, not snap to dog; dog sprite matches pen animals",
		"setup": "empty",
		"from": "path_east",
		"to": "path_west",
	},
	{
		"id": "shed_approach",
		"note": "Walk to shed door apron — player in front of facade, not through walls",
		"setup": "empty",
		"from": "path_east",
		"to": "shed_door",
	},
]

var _out_abs: String = ""
var _manifest: Dictionary = {}
var _checks: Array = []
var _world: Node = null
var _farm: FarmMap = null
var _player: Player = null
var _garden: GardenState = null
var _plant_layer: PlantLayer = null
var _seed_db: SeedDB = null
var _gate: Node2D = null

func _init() -> void:
	call_deferred("_run")

func _qa_root() -> String:
	var game_dir := ProjectSettings.globalize_path("res://").rstrip("/")
	return game_dir.get_base_dir().path_join("qa/out/walk_video")

func _run() -> void:
	print("======== Garden Explorer WALK VIDEO suite ========")
	root.get_viewport().size = VIEW
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	_out_abs = _qa_root().path_join(stamp)
	DirAccess.make_dir_recursive_absolute(_out_abs)
	_manifest = {
		"suite": "walk_video",
		"stamp": stamp,
		"viewport": {"w": VIEW.x, "h": VIEW.y},
		"capture_fps": CAPTURE_FPS,
		"target_s": TARGET_S,
		"clips": [],
		"checks": [],
		"agent_brief": _agent_brief(),
	}

	_prep_save()
	var main: Node = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _settle(12)
	paused = false
	await _skip_intro(main)

	_world = main.get_node_or_null("World")
	if _world == null:
		_finish_fail("World missing")
		return
	_farm = _world.get("farm_map") as FarmMap
	_player = _world.get("player") as Player
	_garden = _world.get("garden") as GardenState
	_plant_layer = _world.get("plant_layer") as PlantLayer
	_seed_db = _world.get("seed_db") as SeedDB
	_gate = _world.get("pen_gate") as Node2D
	if _farm == null or _player == null or _garden == null:
		_finish_fail("FarmMap/Player/Garden missing")
		return

	## Freeze season clock so clips stay stable.
	var clock: Node = _world.get("season_clock") as Node
	if clock and clock.get("paused") != null:
		clock.set("paused", true)
	NarratorLib.stop()
	_ev = root.get_node_or_null("/root/Events")
	_check("events_autoload", _ev != null, "/root/Events")

	for clip in CLIPS:
		await _capture_clip(clip)

	_manifest["checks"] = _checks
	FileAccess.open(_out_abs.path_join("report.json"), FileAccess.WRITE) \
		.store_string(JSON.stringify(_manifest, "\t"))
	var fails := 0
	for c in _checks:
		if not c.get("ok", false):
			fails += 1
	print("WALK_VIDEO done → %s (%d clips, %d fails)" % [
		_out_abs, (_manifest["clips"] as Array).size(), fails])
	quit(1 if fails > 0 else 0)

func _prep_save() -> void:
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

func _capture_clip(clip: Dictionary) -> void:
	var cid: String = str(clip["id"])
	print("\n=== CAPTURE ", cid, " ===")
	var clip_dir := _out_abs.path_join(cid)
	var frames_dir := clip_dir.path_join("frames")
	DirAccess.make_dir_recursive_absolute(frames_dir)

	_apply_setup(str(clip.get("setup", "empty")))
	await _settle(6)

	var start: Vector2 = _named_pos(str(clip["from"]))
	var goal: Vector2 = _named_pos(str(clip["to"]))
	start = _farm.nearest_walkable(start)
	goal = _farm.nearest_walkable(goal)
	_player.place_at(start)
	await _settle(4)
	_aim_cam()
	await _settle(2)

	var path: PackedVector2Array = _farm.find_path(start, goal)
	var route := {
		"id": cid,
		"note": str(clip.get("note", "")),
		"setup": str(clip.get("setup", "")),
		"from": str(clip["from"]),
		"to": str(clip["to"]),
		"start": {"x": start.x, "y": start.y},
		"goal": {"x": goal.x, "y": goal.y},
		"path_len": _farm.path_world_length(start, goal),
		"waypoint_count": path.size(),
		"expect": _expect_for_clip(cid),
	}
	FileAccess.open(clip_dir.path_join("route.json"), FileAccess.WRITE) \
		.store_string(JSON.stringify(route, "\t"))

	## Start real walk so facing / anim / soft-avoid run.
	if _ev:
		_ev.player_path_requested.emit(goal)
	else:
		_player.call("_on_path_requested", goal)

	var total_frames: int = int(round(TARGET_S * float(CAPTURE_FPS)))
	var sim_path := clip_dir.path_join("state.jsonl")
	var tick_path := clip_dir.path_join("ticks.jsonl")
	var sim_f := FileAccess.open(sim_path, FileAccess.WRITE)
	var tick_f := FileAccess.open(tick_path, FileAccess.WRITE)
	_check("%s_state_file" % cid, sim_f != null, sim_path)
	_check("%s_ticks_file" % cid, tick_f != null, tick_path)
	var last_tick_s := -1

	for fi in total_frames:
		var movie_t: float = float(fi) / float(CAPTURE_FPS)
		## Keep process running so Player._process advances the walk.
		await process_frame
		await process_frame
		_aim_cam()

		var snap: Dictionary = _state_snapshot(cid, fi, movie_t, start, goal, path)
		if sim_f != null:
			sim_f.store_line(JSON.stringify(snap))
		## Whole-second tick for Grok: one ground-truth row per second mark.
		var tick_s := int(floor(movie_t + 0.001))
		if tick_f != null and tick_s != last_tick_s and tick_s <= int(TARGET_S):
			last_tick_s = tick_s
			var tick := snap.duplicate(true)
			tick["tick_s"] = tick_s
			tick["is_second_mark"] = true
			tick["direct_checks"] = _direct_checks(snap, cid)
			tick_f.store_line(JSON.stringify(tick))

		var img: Image = root.get_viewport().get_texture().get_image()
		if img != null:
			img.save_png(frames_dir.path_join("f_%04d.png" % fi))

	if sim_f != null:
		sim_f.close()
	if tick_f != null:
		tick_f.close()
	_player.stop()

	var meta := {
		"id": cid,
		"note": str(clip.get("note", "")),
		"setup": str(clip.get("setup", "")),
		"capture_fps": CAPTURE_FPS,
		"target_s": TARGET_S,
		"frame_count": total_frames,
		"frames_dir": "frames",
		"state_jsonl": "state.jsonl",
		"ticks_jsonl": "ticks.jsonl",
		"route_json": "route.json",
	}
	FileAccess.open(clip_dir.path_join("meta.json"), FileAccess.WRITE) \
		.store_string(JSON.stringify(meta, "\t"))
	(_manifest["clips"] as Array).append(meta)
	_check("%s_frames" % cid, DirAccess.open(frames_dir) != null, "frames written")

func _apply_setup(kind: String) -> void:
	## Reset beds then apply scenario.
	for bed_id in _garden.beds.keys():
		_garden.uproot_bed(str(bed_id))
	match kind:
		"seed_bed1":
			_garden.plant_bed("bed_1", "carrot")
		"grown_south":
			for bid in ["bed_3", "bed_4", "bed_5"]:
				_garden.plant_bed(bid, "carrot" if bid != "bed_5" else "lettuce")
				_force_stage(bid, GardenState.STAGE_GROWN)
		_:
			pass
	if _plant_layer:
		_plant_layer.rebuild_all()

func _force_stage(bed_id: String, target: String) -> void:
	if _garden == null or _seed_db == null:
		return
	for _i in 24:
		if _garden.bed_stage(bed_id) == target:
			return
		if _garden.is_bed_empty(bed_id):
			return
		if _garden.is_bed_thirsty(bed_id):
			_garden.water_bed(bed_id, _seed_db)
		_garden.tick(30.0, _seed_db)
	## Last resort: poke slot dicts if still stuck.
	if _garden.bed_stage(bed_id) != target and _garden.beds.has(bed_id):
		var slots: Array = _garden.beds[bed_id]
		for i in slots.size():
			var s: Dictionary = slots[i]
			if str(s.get("plant_id", "")).is_empty():
				continue
			s["stage"] = target
			s["thirsty"] = false
			s["progress"] = 1.0
			slots[i] = s
		_garden.beds[bed_id] = slots
		if _garden.has_signal("bed_changed"):
			_garden.bed_changed.emit(bed_id)

func _named_pos(key: String) -> Vector2:
	var path_y := IsoUtil.tile_to_world(
		Vector2(0.0, float(_farm.data.get("path", {}).get("tile_y", 3.0)))).y
	match key:
		"path_bed0":
			return Vector2(_farm.bed_centers["bed_0"].x, path_y)
		"path_bed1":
			return Vector2(_farm.bed_centers["bed_1"].x, path_y)
		"path_bed2":
			return Vector2(_farm.bed_centers["bed_2"].x, path_y)
		## Longer path endpoints so ~7s clips stay in motion.
		"path_west":
			return Vector2(_farm.bed_centers["bed_0"].x - 90.0, path_y)
		"path_east":
			return Vector2(_farm.bed_centers["bed_2"].x + 70.0, path_y)
		"south_bed1_near":
			return _farm.nearest_walkable(_farm.bed_centers["bed_1"] + Vector2(0, 56))
		"south_bed3":
			return _farm.nearest_walkable(_farm.bed_centers["bed_3"] + Vector2(-40, 56))
		"south_bed5":
			return _farm.nearest_walkable(_farm.bed_centers["bed_5"] + Vector2(40, 56))
		"gate_out":
			return _farm.gate_world + Vector2(-90, 24)
		"pen_in":
			return _farm.gate_world + Vector2(55, 18)
		"dog_near":
			var dog: Vector2 = _farm.dog_spawn_world if _farm.dog_spawn_world != Vector2.ZERO \
				else _farm.spawn_world + Vector2(40, 30)
			return dog + Vector2(36, 10)
		"shed_door":
			if _farm.has_method("shed_approach_world"):
				return _farm.shed_approach_world()
			var door: Vector2 = _farm.shed_door_world if _farm.shed_door_world != Vector2.ZERO \
				else _farm.nearest_walkable(_farm.shed_center + Vector2(40, 24))
			return _farm.nearest_walkable(door + Vector2(0, 18))
		_:
			return _farm.spawn_world

func _expect_for_clip(cid: String) -> Dictionary:
	match cid:
		"walk_path_beds":
			return {
				"player_on_path": true,
				"no_bed_underpaint": true,
				"ux": ["natural walk facing", "beds stay planted/empty as setup"],
			}
		"walk_south_lip":
			return {
				"player_in_front_of_south_beds": true,
				"grown_packs_visible": true,
				"ux": ["no head-under-soil", "harvest stars above foliage if present"],
			}
		"plant_seed_bed":
			return {
				"seeds_visible_on_bed_1": true,
				"seed_count": 4,
				"ux": ["seeds on soil not under wood", "plot-centered clusters"],
			}
		"gate_to_pen":
			return {
				"gate_usable": true,
				"ux": ["gate has end post", "player crosses into pen", "pets look Sprout-Lands consistent"],
			}
		"dog_yard_walk":
			return {
				"buddy_visible": true,
				"ux": ["Buddy red collar dog", "walk facing not glued to dog", "no teleport snaps"],
			}
		"shed_approach":
			return {
				"player_in_front_of_shed": true,
				"ux": ["feet on apron not through shed", "natural approach path"],
			}
		_:
			return {}

func _state_snapshot(cid: String, fi: int, movie_t: float, start: Vector2, goal: Vector2, path: PackedVector2Array) -> Dictionary:
	var ppos := _player.global_position
	var depth_y := ppos.y
	if _farm.has_method("player_depth_y"):
		depth_y = _farm.player_depth_y(ppos)
	var facing_row := int(_player.get("_dir_row")) if _player.get("_dir_row") != null else -1
	var face_left := bool(_player.get("_face_left")) if _player.get("_face_left") != null else false
	var cam := _world.get_node_or_null("CameraFollow") as Camera2D
	var cam_pos := cam.global_position if cam else ppos
	var player_z_computed := IsoUtil.depth_z(depth_y, IsoUtil.BIAS_PLAYER)
	var nw: Vector2 = _farm.nearest_walkable(ppos)
	var blocked := _farm.is_blocked(ppos)

	var beds: Array = []
	var nearest_bed := ""
	var nearest_bed_dist := 1.0e9
	for bed_id in _garden.beds.keys():
		var bid := str(bed_id)
		var bed_node := _farm.get_node_or_null(bid) as CanvasItem
		var plant_node: CanvasItem = null
		if _plant_layer:
			plant_node = _plant_layer.get_node_or_null("BedPlants_%s" % bid) as CanvasItem
			if plant_node == null and _plant_layer.get("_beds") is Dictionary:
				var bn = (_plant_layer._beds as Dictionary).get(bid)
				if bn is CanvasItem:
					plant_node = bn as CanvasItem
		var seed_n := 0
		if plant_node:
			for c in plant_node.get_children():
				if c is Sprite2D:
					seed_n += 1
		var stage := _garden.bed_stage(bid)
		var bed_z := bed_node.z_index if bed_node else -1
		var plant_z := plant_node.z_index if plant_node else -1
		var center: Vector2 = _farm.bed_centers.get(bid, Vector2.ZERO)
		var sort_y: float = _farm.bed_sort_y(bid) if _farm.has_method("bed_sort_y") else center.y
		var bed_z_computed := IsoUtil.depth_z(sort_y, IsoUtil.BIAS_BUILDING) + 3
		var plant_z_computed := IsoUtil.depth_z(sort_y, IsoUtil.BIAS_PLANT)
		var d := ppos.distance_to(center)
		if d < nearest_bed_dist:
			nearest_bed_dist = d
			nearest_bed = bid
		## South of bed sort line + within footprint radius → must paint in front.
		var player_south_of_sort := ppos.y >= sort_y - 10.0
		var player_south := ppos.y > center.y + 12.0
		var near_footprint := d < 90.0
		var expect_player_above := near_footprint and player_south_of_sort
		var z_says_ok := _player.z_index > maxi(bed_z, plant_z)
		beds.append({
			"id": bid,
			"stage": stage,
			"plant_id": _garden.bed_plant_id(bid),
			"empty": _garden.is_bed_empty(bid),
			"thirsty": _garden.is_bed_thirsty(bid),
			"harvestable": _garden.is_bed_harvestable(bid),
			"center": {"x": snappedf(center.x, 0.1), "y": snappedf(center.y, 0.1)},
			"sort_y": snappedf(sort_y, 0.1),
			"bed_z": bed_z,
			"plant_z": plant_z,
			"bed_z_computed": bed_z_computed,
			"plant_z_computed": plant_z_computed,
			"dist_player": snappedf(d, 0.1),
			"sprite_count": seed_n,
			"expect_seeds_visible": stage == GardenState.STAGE_SEED and seed_n >= 4,
			"expect_pack_visible": stage != GardenState.STAGE_SEED and stage != "" and not _garden.is_bed_empty(bid),
			"player_south_of_bed": player_south,
			"player_south_of_sort": player_south_of_sort,
			"near_footprint": near_footprint,
			"expect_player_in_front": expect_player_above,
			"z_index_says_in_front": z_says_ok,
			"depth_contract": (
				"EXPECT player IN FRONT of %s (player_z=%d > plant_z=%d, south_of_sort=%s). "
				+ "If image shows player under wood/plants → depth_sort_bug."
			) % [bid, _player.z_index, maxi(bed_z, plant_z), str(player_south_of_sort)] if expect_player_above \
				else "no frontness contract",
		})

	var animals: Array = []
	if _world.get("roaming_animals") is Dictionary:
		for aid in (_world.roaming_animals as Dictionary).keys():
			var actor: Node2D = (_world.roaming_animals as Dictionary)[aid] as Node2D
			if actor == null or not is_instance_valid(actor):
				continue
			var spr: Sprite2D = actor.get_node_or_null("Sprite") as Sprite2D
			var tex_path := ""
			var frame := -1
			var hframes := 0
			var vframes := 0
			var has_walk := bool(actor.get("_has_walk_sheet")) if actor.get("_has_walk_sheet") != null else false
			var kind := "dog" if str(aid).begins_with("dog") else str(aid).get_slice("_", 0)
			if spr and spr.texture:
				tex_path = str(spr.texture.resource_path)
				frame = spr.frame
				hframes = spr.hframes
				vframes = spr.vframes
			animals.append({
				"id": str(aid),
				"kind": kind,
				"x": snappedf(actor.global_position.x, 0.1),
				"y": snappedf(actor.global_position.y, 0.1),
				"z_index": actor.z_index,
				"dist_player": snappedf(ppos.distance_to(actor.global_position), 0.1),
				"is_dog": str(aid).begins_with("dog"),
				"texture_path": tex_path,
				"has_walk_sheet": has_walk,
				"sprite_frame": frame,
				"hframes": hframes,
				"vframes": vframes,
				"expect_dog_art": "tan dog + red collar (dog_idle/dog_walk)" if str(aid).begins_with("dog") else "",
			})

	var bugs: Array = []
	var spawner: Node = _world.get_node_or_null("BugSpawner")
	if spawner == null:
		spawner = _world.find_child("BugSpawner", true, false)
	if spawner:
		for c in spawner.get_children():
			if c is Node2D and str(c.name).begins_with("Bug"):
				bugs.append({
					"name": c.name,
					"x": snappedf((c as Node2D).global_position.x, 0.1),
					"y": snappedf((c as Node2D).global_position.y, 0.1),
					"z_index": (c as CanvasItem).z_index,
				})

	var season := ""
	if _seed_db:
		season = str(_seed_db.current_season)

	var progress := 0.0
	var path_len := _farm.path_world_length(start, goal)
	if path_len > 1.0:
		progress = clampf(1.0 - ppos.distance_to(goal) / maxf(path_len, 1.0), 0.0, 1.0)
	var wp_i := int(_player.get("_wp_i")) if _player.get("_wp_i") != null else 0
	var wp_n := path.size()
	var target: Vector2 = _player.target if _player.get("target") != null else goal

	var shed_door: Vector2 = _farm.shed_door_world if _farm.shed_door_world != Vector2.ZERO \
		else _farm.shed_center
	var gate: Vector2 = _farm.gate_world

	var depth_mismatches: Array = []
	for b in beds:
		if b.get("expect_player_in_front") and not b.get("z_index_says_in_front"):
			depth_mismatches.append(b.get("id"))

	## Contracts the vision model should verify against the matching frame.
	var contracts: Array = []
	for b in beds:
		if b.get("expect_player_in_front"):
			contracts.append(str(b.get("depth_contract")))
		if b.get("expect_seeds_visible"):
			contracts.append("EXPECT 4 seed sprites on %s soil (sprite_count=%d)." % [
				b.get("id"), b.get("sprite_count")])
	for a in animals:
		if a.get("is_dog"):
			contracts.append(
				"EXPECT Buddy texture dog_idle/dog_walk (path=%s frame=%s). If image looks like bear/cow → wrong_sprite." % [
					a.get("texture_path"), a.get("sprite_frame")])
			if float(a.get("dist_player", 999.0)) < 40.0:
				contracts.append(
					"Buddy within 40px — player facing must follow walk velocity, not snap to dog.")

	return {
		"frame": fi,
		"movie_t": snappedf(movie_t, 0.001),
		"clip_id": cid,
		"season": season,
		"progress_est": snappedf(progress, 0.001),
		"nav": {
			"start": {"x": snappedf(start.x, 0.1), "y": snappedf(start.y, 0.1)},
			"goal": {"x": snappedf(goal.x, 0.1), "y": snappedf(goal.y, 0.1)},
			"target": {"x": snappedf(target.x, 0.1), "y": snappedf(target.y, 0.1)},
			"path_len": snappedf(path_len, 0.1),
			"waypoint_i": wp_i,
			"waypoint_count": wp_n,
			"dist_to_goal": snappedf(ppos.distance_to(goal), 0.1),
			"blocked_at_feet": blocked,
			"nearest_walkable_delta": {
				"x": snappedf(nw.x - ppos.x, 0.1),
				"y": snappedf(nw.y - ppos.y, 0.1),
			},
			"arrived": (not _player.moving) and ppos.distance_to(goal) < 18.0,
		},
		"anchors": {
			"shed_door": {"x": snappedf(shed_door.x, 0.1), "y": snappedf(shed_door.y, 0.1)},
			"gate": {"x": snappedf(gate.x, 0.1), "y": snappedf(gate.y, 0.1)},
			"dist_shed_door": snappedf(ppos.distance_to(shed_door), 0.1),
			"dist_gate": snappedf(ppos.distance_to(gate), 0.1),
			"nearest_bed": nearest_bed,
			"nearest_bed_dist": snappedf(nearest_bed_dist, 0.1),
		},
		"player": {
			"x": snappedf(ppos.x, 0.1),
			"y": snappedf(ppos.y, 0.1),
			"z_index": _player.z_index,
			"z_computed": player_z_computed,
			"depth_y": snappedf(depth_y, 0.1),
			"feet_y_raw": snappedf(ppos.y, 0.1),
			"bias": IsoUtil.BIAS_PLAYER,
			"moving": _player.moving,
			"facing_row": facing_row,
			"face_left": face_left,
			"facing_label": _facing_label(facing_row, face_left),
		},
		"camera": {"x": snappedf(cam_pos.x, 0.1), "y": snappedf(cam_pos.y, 0.1)},
		"beds": beds,
		"animals": animals,
		"bugs": bugs,
		"depth_mismatches_z": depth_mismatches,
		"contracts": contracts,
		"expect": _expect_for_clip(cid),
		"biases": {
			"BUILDING": IsoUtil.BIAS_BUILDING,
			"SEED": IsoUtil.BIAS_SEED,
			"PLANT": IsoUtil.BIAS_PLANT,
			"PLAYER": IsoUtil.BIAS_PLAYER,
			"ANIMAL": IsoUtil.BIAS_ANIMAL,
			"GATE": IsoUtil.BIAS_GATE,
			"RAIL": IsoUtil.BIAS_RAIL,
		},
	}

func _facing_label(row: int, face_left: bool) -> String:
	match row:
		0:
			return "toward_camera_south"
		1:
			return "left" if face_left else "right"
		2:
			return "away_north"
		_:
			return "unknown"

func _direct_checks(snap: Dictionary, cid: String) -> Array:
	## Yes/no questions the model must answer for this second-mark frame.
	var out: Array = []
	out.append({
		"id": "arrived",
		"ask": "Has the player arrived (nav.arrived)?",
		"state": snap.get("nav", {}).get("arrived"),
	})
	out.append({
		"id": "moving",
		"ask": "Is the player still moving?",
		"state": snap.get("player", {}).get("moving"),
	})
	for b in snap.get("beds", []):
		if b.get("expect_player_in_front"):
			out.append({
				"id": "front_%s" % b.get("id"),
				"ask": "Is the gardener painted IN FRONT of %s (not under soil/wood/plants)?" % b.get("id"),
				"state_expect": true,
				"state_z_ok": b.get("z_index_says_in_front"),
				"note": b.get("depth_contract"),
			})
		if b.get("expect_seeds_visible"):
			out.append({
				"id": "seeds_%s" % b.get("id"),
				"ask": "Are four seed clusters visible on %s soil?" % b.get("id"),
				"state_expect": true,
				"state_sprite_count": b.get("sprite_count"),
			})
	for a in snap.get("animals", []):
		if a.get("is_dog"):
			out.append({
				"id": "buddy_art",
				"ask": "Is Buddy the tan dog with red collar (not a bear/cow)?",
				"state_texture": a.get("texture_path"),
				"state_expect": "dog_idle or dog_walk in texture_path",
			})
	match cid:
		"shed_approach":
			out.append({
				"id": "on_shed_apron",
				"ask": "Are the player's feet on the shed door apron (clear of beds, in front of facade)?",
				"state_dist_shed_door": snap.get("anchors", {}).get("dist_shed_door"),
				"state_blocked": snap.get("nav", {}).get("blocked_at_feet"),
			})
		"gate_to_pen":
			out.append({
				"id": "gate_clear",
				"ask": "Is the player clearly visible crossing the gate (not buried under a post)?",
				"state_dist_gate": snap.get("anchors", {}).get("dist_gate"),
			})
		_:
			pass
	return out

func _aim_cam() -> void:
	var cam := _world.get_node_or_null("CameraFollow") as Camera2D
	if cam == null:
		return
	if cam.has_method("set_follow_target"):
		cam.call("set_follow_target", _player)
	if cam.has_method("snap_to_target"):
		cam.call("snap_to_target")
	else:
		cam.global_position = _player.global_position

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

func _finish_fail(msg: String) -> void:
	print("FATAL ", msg)
	_manifest["fatal"] = msg
	_manifest["checks"] = _checks
	FileAccess.open(_out_abs.path_join("report.json"), FileAccess.WRITE) \
		.store_string(JSON.stringify(_manifest, "\t"))
	quit(1)

func _agent_brief() -> String:
	return ("Walk video QA. Each clip has frames/ + state.jsonl + route.json. "
		+ "Review with qa/review_walk_videos.py (Grok) — compare render to state "
		+ "(depth, seeds, Buddy, gate, shed). Flag all clear UX / unnatural issues. "
		+ "FAIL in report.json means capture broke.")

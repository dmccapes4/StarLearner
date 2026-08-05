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
## Override with WALK_TARGET_S=10 (routing set defaults to 10).
const TARGET_S_DEFAULT := 7.0

var _ev: Node ## /root/Events (resolved at runtime for -s scripts)
var _target_s: float = TARGET_S_DEFAULT
var _clip_set: String = "default"

## Kid-shaped stress clips: movement routing, depth, seeds, Buddy, gate, shed.
const CLIPS_DEFAULT := [
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

## Routing / detour stress — playtest: tap shed from beside western south bed
## must NOT loop east around middle beds then between beds and south fence.
## Uses production World shed interact when interact=shed.
const CLIPS_ROUTING := [
	{
		"id": "shed_from_south_bed3",
		"note": "USER BUG: stand south of westernmost south bed (bed_3) by shed — tap shed. Expect short NW onto path then west to apron; FAIL if east loop around bed_4/5 then south-fence corridor.",
		"setup": "empty",
		"from": "south_bed3_by_shed",
		"to": "shed_door",
		"interact": "shed",
		"expect_corridor": "path_or_west_aisle",
		"max_detour_ratio": 2.2,
	},
	{
		"id": "shed_from_bed3_west_gap",
		"note": "West rim of bed_3 toward shed — should stay west of bed cluster, not circle the farm.",
		"setup": "empty",
		"from": "bed3_west_gap",
		"to": "shed_door",
		"interact": "shed",
		"expect_corridor": "west_aisle",
		"max_detour_ratio": 2.0,
	},
	{
		"id": "shed_from_path_near",
		"note": "Path stand near shed → apron. Baseline short walk; compare detour_ratio to south-bed starts.",
		"setup": "empty",
		"from": "path_by_shed",
		"to": "shed_door",
		"interact": "shed",
		"expect_corridor": "path",
		"max_detour_ratio": 2.0,
	},
	{
		"id": "shed_retap_midwalk",
		"note": "Start south of bed_3 toward shed; re-emit shed interact at t≈2.5s (kid re-tap). Must not restart a longer loop.",
		"setup": "empty",
		"from": "south_bed3_by_shed",
		"to": "shed_door",
		"interact": "shed",
		"retap_interact": "shed",
		"retap_at_s": 2.5,
		"expect_corridor": "path_or_west_aisle",
		"max_detour_ratio": 2.4,
	},
	{
		"id": "path_west_to_shed",
		"note": "West path endpoint → shed via find_path only (no World interact).",
		"setup": "empty",
		"from": "path_west",
		"to": "shed_door",
		"expect_corridor": "path",
		"max_detour_ratio": 1.8,
	},
	{
		"id": "aisle_bed0_to_bed3",
		"note": "North bed_0 south-lip → south bed_3 north-lip — short aisle, not east around bed_1/2.",
		"setup": "empty",
		"from": "south_of_bed0",
		"to": "north_of_bed3",
		"expect_corridor": "west_aisle",
		"max_detour_ratio": 2.0,
	},
	{
		"id": "south_lip_no_fence_trap",
		"note": "South lip bed_3→bed_5: stay on lip; should not bounce into south perimeter fence trap.",
		"setup": "grown_south",
		"from": "south_bed3",
		"to": "south_bed5",
		"expect_corridor": "south_lip",
		"max_detour_ratio": 1.8,
	},
	{
		"id": "bed3_approach_from_shed",
		"note": "Shed apron → bed_3 approach (production bed_approach_world). Short SE, not farm loop.",
		"setup": "empty",
		"from": "shed_door",
		"to": "bed3_approach",
		"expect_corridor": "path_or_west_aisle",
		"max_detour_ratio": 2.2,
	},
]

## Watering can + bed approach — shed pickup then tap beds (face + arrive + thirst VO).
const CLIPS_WATER := [
	{
		"id": "water_bed3_from_shed",
		"note": "USER: watering can from shed → nearest south bed (bed_3). Path-facing pane = NORTH for south-row beds.",
		"setup": "thirsty_beds",
		"tool": "water",
		"from": "shed_door",
		"to": "bed3_approach",
		"interact": "bed",
		"bed_id": "bed_3",
		"expect_corridor": "path_or_west_aisle",
		"expect_face": "north",
		"max_detour_ratio": 2.2,
		"expect_water": true,
	},
	{
		"id": "water_bed0_from_shed",
		"note": "USER BUG: from shed apron tap NW bed_0 — must stand on PATH/SOUTH lip, not walk around to north face.",
		"setup": "thirsty_beds",
		"tool": "water",
		"from": "shed_door",
		"to": "bed0_approach",
		"interact": "bed",
		"bed_id": "bed_0",
		"expect_corridor": "path",
		"expect_face": "south",
		"max_detour_ratio": 2.2,
		"expect_water": true,
	},
	{
		"id": "water_bed1_from_south_path",
		"note": "USER BUG: from path/south of bed_1 tap north-middle — south lip stand, not opposite north side.",
		"setup": "thirsty_beds",
		"tool": "water",
		"from": "path_bed1",
		"to": "bed1_approach",
		"interact": "bed",
		"bed_id": "bed_1",
		"expect_corridor": "path",
		"expect_face": "south",
		"max_detour_ratio": 2.0,
		"expect_water": true,
	},
	{
		"id": "water_bed0_from_bed3",
		"note": "From south of bed_3 (shed side) tap bed_0 — short path corridor / south face, not farm loop to north.",
		"setup": "thirsty_beds",
		"tool": "water",
		"from": "south_bed3_by_shed",
		"to": "bed0_approach",
		"interact": "bed",
		"bed_id": "bed_0",
		"expect_corridor": "path_or_west_aisle",
		"expect_face": "south",
		"max_detour_ratio": 2.4,
		"expect_water": true,
	},
	{
		"id": "water_double_tap_bed3",
		"note": "Water bed_3 then re-tap at t≈3.5s — must not replace success VO with soft 'not thirsty' (state/VO bug).",
		"setup": "thirsty_beds",
		"tool": "water",
		"from": "path_bed3",
		"to": "bed3_approach",
		"interact": "bed",
		"bed_id": "bed_3",
		"retap_interact": "bed",
		"retap_at_s": 3.5,
		"expect_corridor": "path",
		"expect_face": "north",
		"max_detour_ratio": 2.5,
		"expect_water": true,
		"expect_no_false_not_thirsty_vo": true,
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
	_clip_set = str(OS.get_environment("WALK_CLIP_SET")).strip_edges()
	if _clip_set.is_empty():
		_clip_set = "default"
	var ts_env := str(OS.get_environment("WALK_TARGET_S")).strip_edges()
	if not ts_env.is_empty():
		_target_s = maxf(4.0, float(ts_env))
	elif _clip_set == "routing" or _clip_set == "water":
		_target_s = 10.0
	else:
		_target_s = TARGET_S_DEFAULT
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	if _clip_set != "default":
		stamp = "%s_%s" % [stamp, _clip_set]
	_out_abs = _qa_root().path_join(stamp)
	DirAccess.make_dir_recursive_absolute(_out_abs)
	_manifest = {
		"suite": "walk_video",
		"clip_set": _clip_set,
		"stamp": stamp,
		"viewport": {"w": VIEW.x, "h": VIEW.y},
		"capture_fps": CAPTURE_FPS,
		"target_s": _target_s,
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

	_dump_mechanics()
	_write_nav_diagnostics()

	var clips: Array = CLIPS_DEFAULT
	match _clip_set:
		"routing":
			clips = CLIPS_ROUTING
		"water":
			clips = CLIPS_WATER
	print("clip_set=", _clip_set, " clips=", clips.size(), " target_s=", _target_s)
	for clip in clips:
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

	_reset_between_clips()
	_apply_setup(str(clip.get("setup", "empty")))
	_apply_tool(str(clip.get("tool", "")))
	await _settle(6)

	var start: Vector2 = _named_pos(str(clip["from"]))
	var goal: Vector2 = _named_pos(str(clip["to"]))
	start = _farm.nearest_walkable(start)
	goal = _farm.nearest_walkable(goal)
	## Production shed/bed goals (may differ from named_pos if interact overrides).
	var interact := str(clip.get("interact", ""))
	if interact == "shed" and _farm.has_method("shed_approach_world"):
		goal = _farm.shed_approach_world()
	elif interact == "bed" and clip.has("bed_id") and _farm.has_method("bed_approach_world"):
		goal = _farm.bed_approach_world(str(clip["bed_id"]), start, _farm.bed_centers.get(str(clip["bed_id"]), goal))
	_player.place_at(start)
	await _settle(4)
	_aim_cam()
	await _settle(2)

	var path: PackedVector2Array = _farm.find_path(start, goal)
	var path_q: Dictionary = _path_quality(start, goal, path, clip)
	var bed_id_r := str(clip.get("bed_id", ""))
	var approach_face := ""
	if not bed_id_r.is_empty() and _farm.bed_centers.has(bed_id_r):
		var bc: Vector2 = _farm.bed_centers[bed_id_r]
		approach_face = "south" if goal.y >= bc.y + 6.0 else ("north" if goal.y <= bc.y - 6.0 else "side")
		path_q["approach_face"] = approach_face
		path_q["expect_face"] = str(clip.get("expect_face", ""))
		path_q["goal_vs_center_y"] = snappedf(goal.y - bc.y, 0.1)
	var route := {
		"id": cid,
		"note": str(clip.get("note", "")),
		"setup": str(clip.get("setup", "")),
		"tool": str(clip.get("tool", "")),
		"bed_id": bed_id_r,
		"from": str(clip["from"]),
		"to": str(clip["to"]),
		"interact": interact,
		"retap_interact": str(clip.get("retap_interact", "")),
		"retap_at_s": float(clip.get("retap_at_s", -1.0)),
		"start": {"x": snappedf(start.x, 0.1), "y": snappedf(start.y, 0.1)},
		"goal": {"x": snappedf(goal.x, 0.1), "y": snappedf(goal.y, 0.1)},
		"approach_face": approach_face,
		"shed_door_world": {
			"x": snappedf(_farm.shed_door_world.x, 0.1),
			"y": snappedf(_farm.shed_door_world.y, 0.1),
		},
		"shed_center": {
			"x": snappedf(_farm.shed_center.x, 0.1),
			"y": snappedf(_farm.shed_center.y, 0.1),
		},
		"path_quality": path_q,
		"waypoints": _sample_waypoints(path, 24),
		"expect": _expect_for_clip(cid, clip),
		"mechanics_ref": "mechanics/README.md",
		"code_review_ref": "mechanics/REVIEW_BED_APPROACH_AND_WATER.md",
	}
	FileAccess.open(clip_dir.path_join("route.json"), FileAccess.WRITE) \
		.store_string(JSON.stringify(route, "\t"))
	## Capture-time assert on insane detours (vision still reviews images).
	## Skip ratio when crow is tiny — short hops inflate detour_ratio harmlessly.
	var max_r := float(clip.get("max_detour_ratio", 0.0))
	var crow_r := float(path_q.get("crow_flies", 0.0))
	if max_r > 0.0 and crow_r >= 40.0:
		var ratio := float(path_q.get("detour_ratio", 0.0))
		_check("%s_detour_ratio" % cid, ratio <= max_r,
			"detour=%.2f max=%.2f path_len=%.1f crow=%.1f south_loop=%s" % [
				ratio, max_r, float(path_q.get("path_len", 0.0)),
				crow_r, str(path_q.get("looks_like_south_fence_loop", false))])
	## Capture-time assert: chosen face matches expect (south for N-row, north for S-row path lip).
	var expect_face := str(clip.get("expect_face", ""))
	if expect_face == "south" or expect_face.begins_with("south"):
		_check("%s_approach_face" % cid,
			approach_face == "south" or approach_face == "side",
			"approach_face=%s expect=%s goal_dy=%s" % [
				approach_face, expect_face, str(path_q.get("goal_vs_center_y", "?"))])
	elif expect_face == "north":
		_check("%s_approach_face" % cid,
			approach_face == "north" or approach_face == "side",
			"approach_face=%s expect=%s goal_dy=%s" % [
				approach_face, expect_face, str(path_q.get("goal_vs_center_y", "?"))])

	## Start walk via production interact when requested (World → Events → Player).
	_start_walk(interact, goal, start, clip)
	var retap_at := float(clip.get("retap_at_s", -1.0))
	var retap_kind := str(clip.get("retap_interact", ""))
	var did_retap := false

	var total_frames: int = int(round(_target_s * float(CAPTURE_FPS)))
	var sim_path := clip_dir.path_join("state.jsonl")
	var tick_path := clip_dir.path_join("ticks.jsonl")
	var sim_f := FileAccess.open(sim_path, FileAccess.WRITE)
	var tick_f := FileAccess.open(tick_path, FileAccess.WRITE)
	_check("%s_state_file" % cid, sim_f != null, sim_path)
	_check("%s_ticks_file" % cid, tick_f != null, tick_path)
	var last_tick_s := -1
	## Live path (updates after retap).
	var live_path: PackedVector2Array = path
	var live_goal: Vector2 = goal

	for fi in total_frames:
		var movie_t: float = float(fi) / float(CAPTURE_FPS)
		if not did_retap and retap_at >= 0.0 and movie_t >= retap_at and not retap_kind.is_empty():
			did_retap = true
			_start_walk(retap_kind, live_goal, _player.global_position, clip)
			live_path = _farm.find_path(_player.global_position, live_goal)
			path_q = _path_quality(_player.global_position, live_goal, live_path, clip)
			path_q["retap"] = true
			path_q["retap_at_s"] = movie_t
		## Keep process running so Player._process advances the walk.
		await process_frame
		await process_frame
		_aim_cam()

		## Refresh live waypoints from Player when available.
		var pw = _player.get("_waypoints")
		if pw is PackedVector2Array and (pw as PackedVector2Array).size() > 0:
			live_path = pw as PackedVector2Array
		var snap: Dictionary = _state_snapshot(cid, fi, movie_t, start, live_goal, live_path, clip, path_q)
		if sim_f != null:
			sim_f.store_line(JSON.stringify(snap))
		## Whole-second tick for Grok: one ground-truth row per second mark.
		var tick_s := int(floor(movie_t + 0.001))
		if tick_f != null and tick_s != last_tick_s and tick_s <= int(_target_s):
			last_tick_s = tick_s
			var tick := snap.duplicate(true)
			tick["tick_s"] = tick_s
			tick["is_second_mark"] = true
			tick["direct_checks"] = _direct_checks(snap, cid, clip)
			tick_f.store_line(JSON.stringify(tick))

		var img: Image = root.get_viewport().get_texture().get_image()
		if img != null:
			img.save_png(frames_dir.path_join("f_%04d.png" % fi))

	if sim_f != null:
		sim_f.close()
	if tick_f != null:
		tick_f.close()
	_player.stop()

	## End-of-clip water / thirst asserts.
	if bool(clip.get("expect_water", false)) and not bed_id_r.is_empty():
		var still_thirsty := _garden.is_bed_thirsty(bed_id_r)
		_check("%s_water_cleared_thirst" % cid, not still_thirsty,
			"bed=%s thirsty=%s (expect watered)" % [bed_id_r, still_thirsty])

	var meta := {
		"id": cid,
		"note": str(clip.get("note", "")),
		"setup": str(clip.get("setup", "")),
		"tool": str(clip.get("tool", "")),
		"bed_id": bed_id_r,
		"clip_set": _clip_set,
		"capture_fps": CAPTURE_FPS,
		"target_s": _target_s,
		"frame_count": total_frames,
		"frames_dir": "frames",
		"state_jsonl": "state.jsonl",
		"ticks_jsonl": "ticks.jsonl",
		"route_json": "route.json",
		"final_path_quality": path_q,
		"final_thirsty": _garden.is_bed_thirsty(bed_id_r) if not bed_id_r.is_empty() else null,
	}
	FileAccess.open(clip_dir.path_join("meta.json"), FileAccess.WRITE) \
		.store_string(JSON.stringify(meta, "\t"))
	(_manifest["clips"] as Array).append(meta)
	_check("%s_frames" % cid, DirAccess.open(frames_dir) != null, "frames written")

func _reset_between_clips() -> void:
	## Clear shed/tool prompts + pending interact so the next clip can walk.
	if _player:
		_player.stop()
	if _world:
		if _world.get("_pending") != null:
			_world.set("_pending", {})
		if _world.has_method("_close_prompt"):
			_world.call("_close_prompt")
		elif _world.has_method("close_prompt"):
			_world.call("close_prompt")
	NarratorLib.stop()
	var main := root.get_child(root.get_child_count() - 1)
	for name in ["VideoPanel", "PromptPanel", "MediaPanel"]:
		var n: Node = main.get_node_or_null(name) if main else null
		if n == null:
			continue
		if n.has_method("_close"):
			n.call("_close")
		elif n.has_method("close"):
			n.call("close")
		if n.get("visible") != null:
			n.set("visible", false)

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
		"thirsty_beds":
			## Fresh plant_bed starts thirsty=true — watering can targets.
			for bid in ["bed_0", "bed_1", "bed_3"]:
				_garden.plant_bed(bid, "carrot")
		_:
			pass
	if _plant_layer:
		_plant_layer.rebuild_all()

func _apply_tool(tool_id: String) -> void:
	if tool_id.is_empty() or _world == null:
		return
	## Mirror shed watering-can pickup so _shed_tool() == water.
	if _world.shed_ui and _world.shed_ui.has_method("set_tool"):
		_world.shed_ui.call("set_tool", tool_id)
	elif _world.has_method("set_tool"):
		_world.call("set_tool", tool_id)
	if _world.get("tool_id") != null:
		_world.tool_id = tool_id

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

func _path_stand(x: float) -> Vector2:
	## Dirt strip on the path tile — keep stands on the corridor, not kicked onto
	## a bed's south lip by nearest_walkable.
	var path_y := IsoUtil.tile_to_world(
		Vector2(0.0, float(_farm.data.get("path", {}).get("tile_y", 3.0)))).y
	var ideal := Vector2(x, path_y + 6.0)
	var w := _farm.nearest_walkable(ideal)
	if absf(w.y - path_y) <= 28.0:
		return w
	for dy in [0.0, -8.0, 8.0, -16.0, 16.0, -24.0, 24.0]:
		var p := _farm.nearest_walkable(Vector2(x, path_y + dy))
		if absf(p.y - path_y) <= 28.0:
			return p
	return w

func _named_pos(key: String) -> Vector2:
	match key:
		"path_bed0":
			return _path_stand(_farm.bed_centers["bed_0"].x)
		"path_bed1":
			return _path_stand(_farm.bed_centers["bed_1"].x)
		"path_bed2":
			return _path_stand(_farm.bed_centers["bed_2"].x)
		"path_bed3":
			return _path_stand(_farm.bed_centers["bed_3"].x)
		## Longer path endpoints so ~7s clips stay in motion.
		"path_west":
			return _path_stand(_farm.bed_centers["bed_0"].x - 90.0)
		"path_east":
			return _path_stand(_farm.bed_centers["bed_2"].x + 70.0)
		"south_bed1_near":
			return _farm.nearest_walkable(_farm.bed_centers["bed_1"] + Vector2(0, 44))
		"south_bed3":
			return _farm.nearest_walkable(_farm.bed_centers["bed_3"] + Vector2(-40, 44))
		"south_bed5":
			## Stay on the lip, not jammed into the south perimeter rails.
			return _farm.nearest_walkable(_farm.bed_centers["bed_5"] + Vector2(24, 40))
		## Playtest: south of westernmost south bed, near shed (user tap).
		"south_bed3_by_shed":
			return _farm.nearest_walkable(_farm.bed_centers["bed_3"] + Vector2(-55, 36))
		"bed3_west_gap":
			return _farm.nearest_walkable(_farm.bed_centers["bed_3"] + Vector2(-70, 8))
		"path_by_shed":
			return _path_stand(_farm.shed_center.x + 70.0)
		"south_of_bed0":
			return _farm.nearest_walkable(_farm.bed_centers["bed_0"] + Vector2(0, 40))
		"north_of_bed3":
			return _farm.nearest_walkable(_farm.bed_centers["bed_3"] + Vector2(0, -40))
		"bed3_approach":
			if _farm.has_method("bed_approach_world"):
				return _farm.bed_approach_world(
					"bed_3", _farm.shed_door_world, _farm.bed_centers["bed_3"])
			return _farm.nearest_walkable(_farm.bed_centers["bed_3"] + Vector2(0, 40))
		"bed0_approach":
			if _farm.has_method("bed_approach_world"):
				return _farm.bed_approach_world(
					"bed_0", _farm.shed_door_world, _farm.bed_centers["bed_0"])
			return _farm.nearest_walkable(_farm.bed_centers["bed_0"] + Vector2(0, 40))
		"bed1_approach":
			if _farm.has_method("bed_approach_world"):
				return _farm.bed_approach_world(
					"bed_1", _path_stand(_farm.bed_centers["bed_1"].x), _farm.bed_centers["bed_1"])
			return _farm.nearest_walkable(_farm.bed_centers["bed_1"] + Vector2(0, 40))
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

func _expect_for_clip(cid: String, clip: Dictionary = {}) -> Dictionary:
	var base: Dictionary = {
		"expect_corridor": str(clip.get("expect_corridor", "")),
		"max_detour_ratio": float(clip.get("max_detour_ratio", 0.0)),
		"no_south_fence_loop": true,
		"ux": [] as Array,
	}
	match cid:
		"walk_path_beds":
			return {
				"player_on_path": true,
				"no_bed_underpaint": true,
				"ux": ["natural walk facing", "beds stay planted/empty as setup"],
			}
		"walk_south_lip", "south_lip_no_fence_trap":
			return {
				"player_in_front_of_south_beds": true,
				"grown_packs_visible": cid != "south_lip_no_fence_trap" or true,
				"expect_corridor": "south_lip",
				"ux": ["no head-under-soil", "no south-fence trap loop"],
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
		"shed_approach", "shed_from_south_bed3", "shed_from_bed3_west_gap", "shed_from_path_near", "shed_retap_midwalk", "path_west_to_shed":
			base["player_in_front_of_shed"] = true
			base["ux"] = [
				"feet on apron not through shed",
				"SHORT route — not east around middle beds then south fence",
				"detour_ratio under max in route.path_quality",
			]
			return base
		"aisle_bed0_to_bed3", "bed3_approach_from_shed":
			base["ux"] = ["short aisle / path corridor", "no farm-scale loop"]
			return base
		"water_bed3_from_shed", "water_bed0_from_shed", "water_bed1_from_south_path", \
		"water_bed0_from_bed3", "water_double_tap_bed3":
			base["expect_face"] = str(clip.get("expect_face", "south"))
			base["expect_water"] = bool(clip.get("expect_water", true))
			base["ux"] = [
				"stand on PATH/SOUTH lip of north beds (not north face)",
				"short corridor — no farm loop",
				"water applies on arrive when thirsty; success VO not replaced by not-thirsty",
			]
			return base
		_:
			return base if not base["expect_corridor"].is_empty() else {}

func _start_walk(interact: String, goal: Vector2, from_pos: Vector2, clip: Dictionary = {}) -> void:
	if interact == "shed" and _world != null and _world.has_method("_queue_interact"):
		## Same code path as tapping the shed sprite.
		_world.call("_queue_interact", "shed", "shed", _farm.shed_center)
		return
	if interact == "bed" and _world != null and _world.has_method("_queue_interact"):
		var bed_id := str(clip.get("bed_id", "bed_3"))
		_world.call("_queue_interact", "bed", bed_id, _farm.bed_centers.get(bed_id, goal))
		return
	if _ev:
		_ev.player_path_requested.emit(goal)
	else:
		_player.call("_on_path_requested", goal)

func _sample_waypoints(path: PackedVector2Array, max_n: int) -> Array:
	var out: Array = []
	if path.is_empty():
		return out
	var step := maxi(1, int(ceil(float(path.size()) / float(max_n))))
	for i in range(0, path.size(), step):
		var p: Vector2 = path[i]
		out.append({"i": i, "x": snappedf(p.x, 0.1), "y": snappedf(p.y, 0.1)})
	var last: Vector2 = path[path.size() - 1]
	if out.is_empty() or Vector2(out[out.size() - 1]["x"], out[out.size() - 1]["y"]).distance_to(last) > 2.0:
		out.append({"i": path.size() - 1, "x": snappedf(last.x, 0.1), "y": snappedf(last.y, 0.1)})
	return out

func _path_quality(start: Vector2, goal: Vector2, path: PackedVector2Array, clip: Dictionary) -> Dictionary:
	var crow := start.distance_to(goal)
	var plen := 0.0
	if path.size() >= 2:
		for i in range(1, path.size()):
			plen += path[i - 1].distance_to(path[i])
	else:
		plen = crow
	var detour := plen / maxf(crow, 1.0)
	var min_x := start.x
	var max_x := start.x
	var min_y := start.y
	var max_y := start.y
	for p in path:
		min_x = minf(min_x, p.x)
		max_x = maxf(max_x, p.x)
		min_y = minf(min_y, p.y)
		max_y = maxf(max_y, p.y)
	var bed3: Vector2 = _farm.bed_centers.get("bed_3", Vector2.ZERO)
	var bed4: Vector2 = _farm.bed_centers.get("bed_4", Vector2.ZERO)
	var bed5: Vector2 = _farm.bed_centers.get("bed_5", Vector2.ZERO)
	var south_row_y := maxf(bed3.y, maxf(bed4.y, bed5.y))
	## Loop signature: from a *west* start, path swings east of bed_4 AND deep
	## south of the south row (shed/path routes). Eastbound south-lip walks are OK.
	var went_east_of_bed4 := max_x > bed4.x + 20.0
	var went_south_of_beds := max_y > south_row_y + 50.0
	var expect_c := str(clip.get("expect_corridor", ""))
	var south_fence_loop := (
		expect_c != "south_lip"
		and went_east_of_bed4
		and went_south_of_beds
		and start.x < bed4.x
		and float(clip.get("max_detour_ratio", 0.0)) > 0.0
		and detour > float(clip.get("max_detour_ratio", 99.0))
	)
	## Ideal shed approach from bed_3: max_x should stay near start/goal band.
	var east_overshoot := max_x - maxf(start.x, goal.x)
	return {
		"crow_flies": snappedf(crow, 0.1),
		"path_len": snappedf(plen, 0.1),
		"detour_ratio": snappedf(detour, 0.01),
		"waypoint_count": path.size(),
		"bbox": {
			"min_x": snappedf(min_x, 0.1), "max_x": snappedf(max_x, 0.1),
			"min_y": snappedf(min_y, 0.1), "max_y": snappedf(max_y, 0.1),
		},
		"east_overshoot": snappedf(east_overshoot, 0.1),
		"went_east_of_bed4": went_east_of_bed4,
		"went_south_of_south_beds": went_south_of_beds,
		"looks_like_south_fence_loop": south_fence_loop,
		"expect_corridor": str(clip.get("expect_corridor", "")),
		"max_detour_ratio": float(clip.get("max_detour_ratio", 0.0)),
		"bed_solid_pad": 1.08,
		"hint": (
			"If looks_like_south_fence_loop or detour_ratio>>max → A* corridor blocked "
			+ "(BED_SOLID_PAD / _nav_point_blocked / diagonal mid checks / shed_approach)."
		),
	}

func _dump_mechanics() -> void:
	## Full source of every script that owns walk video / tap → path → move → depth.
	var mech := _out_abs.path_join("mechanics")
	DirAccess.make_dir_recursive_absolute(mech)
	var files := [
		"res://scripts/world/FarmMap.gd",
		"res://scripts/world/Player.gd",
		"res://scripts/world/World.gd",
		"res://scripts/world/PenGate.gd",
		"res://scripts/world/RoamingAnimal.gd",
		"res://scripts/sim/GardenState.gd",
		"res://scripts/audio/Narrator.gd",
		"res://scripts/audio/Speak.gd",
		"res://scripts/ui/ShedUI.gd",
		"res://scripts/render/IsoUtil.gd",
		"res://tools/walk_video_suite.gd",
		"res://data/map.json",
	]
	var index: Array = []
	for path in files:
		var res_path := str(path)
		var body := FileAccess.get_file_as_string(res_path)
		if body.is_empty():
			continue
		var base: String = res_path.get_file()
		var out_path := mech.path_join(base)
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		if f:
			f.store_string(body)
			f.close()
			index.append({"res": res_path, "file": base, "bytes": body.length()})
	## Code review for Grok Vision (bed approach + water state bugs).
	var game_dir := ProjectSettings.globalize_path("res://").rstrip("/")
	var review_src := game_dir.get_base_dir().path_join("docs/REVIEW_BED_APPROACH_AND_WATER.md")
	if FileAccess.file_exists(review_src):
		var rev := FileAccess.get_file_as_string(review_src)
		if not rev.is_empty():
			FileAccess.open(mech.path_join("REVIEW_BED_APPROACH_AND_WATER.md"), FileAccess.WRITE) \
				.store_string(rev)
			index.append({
				"res": "docs/REVIEW_BED_APPROACH_AND_WATER.md",
				"file": "REVIEW_BED_APPROACH_AND_WATER.md",
				"bytes": rev.length(),
			})
	var readme := PackedStringArray([
		"# Walk / tap mechanics dump",
		"",
		"Copied at capture time for Grok Vision + agents. Flow:",
		"",
		"1. `World._queue_interact` / ground tap → approach point",
		"2. `Events.player_path_requested` → `Player._on_path_requested`",
		"3. `FarmMap.find_path` / `_rebuild_nav` / `_nav_point_blocked` / solids",
		"4. `Player._process` soft collision + waypoint follow",
		"5. `FarmMap.player_depth_y` + `IsoUtil.apply_depth` each frame",
		"6. Bed water: `FarmMap.bed_approach_world` → arrive → `_apply_bed_tool` / `_do_water_bed`",
		"",
		"Read `REVIEW_BED_APPROACH_AND_WATER.md` first for known spaghetti / face / VO bugs.",
		"",
		"Suspect bandaids for south-fence loops: `BED_SOLID_PAD`, `_nav_point_blocked`",
		"bed samples, diagonal mid-point reject, `shed_approach_world` / `_near_bed_footprint`.",
		"",
		"Files:",
	])
	for it in index:
		readme.append("- `%s` (%d bytes) ← `%s`" % [it["file"], it["bytes"], it["res"]])
	FileAccess.open(mech.path_join("README.md"), FileAccess.WRITE) \
		.store_string("\n".join(readme) + "\n")
	_manifest["mechanics_dir"] = "mechanics"
	_manifest["mechanics_files"] = index
	print("mechanics dump → ", mech, " (", index.size(), " files)")

func _write_nav_diagnostics() -> void:
	## Snapshot bed centers + shed apron + a few probe paths for the stamp folder.
	var probes: Array = []
	var pairs := [
		["south_bed3_by_shed", "shed_door"],
		["bed3_west_gap", "shed_door"],
		["path_by_shed", "shed_door"],
		["path_west", "path_east"],
	]
	for pair in pairs:
		var a: Vector2 = _farm.nearest_walkable(_named_pos(str(pair[0])))
		var b: Vector2 = _farm.nearest_walkable(_named_pos(str(pair[1])))
		if str(pair[1]) == "shed_door" and _farm.has_method("shed_approach_world"):
			b = _farm.shed_approach_world()
		var path: PackedVector2Array = _farm.find_path(a, b)
		probes.append({
			"from": pair[0],
			"to": pair[1],
			"start": {"x": snappedf(a.x, 0.1), "y": snappedf(a.y, 0.1)},
			"goal": {"x": snappedf(b.x, 0.1), "y": snappedf(b.y, 0.1)},
			"path_quality": _path_quality(a, b, path, {"expect_corridor": "probe"}),
			"waypoints": _sample_waypoints(path, 16),
		})
	var beds: Array = []
	for id in _farm.bed_centers.keys():
		beds.append({
			"id": id,
			"center": {
				"x": snappedf((_farm.bed_centers[id] as Vector2).x, 0.1),
				"y": snappedf((_farm.bed_centers[id] as Vector2).y, 0.1),
			},
			"sort_y": snappedf(_farm.bed_sort_y(str(id)), 0.1) if _farm.has_method("bed_sort_y") else 0.0,
		})
	var diag := {
		"bed_solid_pad": 1.08,
		"shed_door_world": {
			"x": snappedf(_farm.shed_door_world.x, 0.1),
			"y": snappedf(_farm.shed_door_world.y, 0.1),
		},
		"shed_approach": (
			{"x": snappedf(_farm.shed_approach_world().x, 0.1),
				"y": snappedf(_farm.shed_approach_world().y, 0.1)}
			if _farm.has_method("shed_approach_world") else {}
		),
		"beds": beds,
		"probe_paths": probes,
	}
	FileAccess.open(_out_abs.path_join("nav_diagnostics.json"), FileAccess.WRITE) \
		.store_string(JSON.stringify(diag, "\t"))
	_manifest["nav_diagnostics"] = "nav_diagnostics.json"

func _state_snapshot(cid: String, fi: int, movie_t: float, start: Vector2, goal: Vector2, path: PackedVector2Array, clip: Dictionary = {}, path_q: Dictionary = {}) -> Dictionary:
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

	var pq: Dictionary = path_q if not path_q.is_empty() else _path_quality(start, goal, path, clip)
	var path_len := float(pq.get("path_len", _farm.path_world_length(start, goal)))
	var progress := 0.0
	if path_len > 1.0:
		progress = clampf(1.0 - ppos.distance_to(goal) / maxf(path_len, 1.0), 0.0, 1.0)
	var wp_i := int(_player.get("_wp_i")) if _player.get("_wp_i") != null else 0
	var wp_n := path.size()
	var target: Vector2 = _player.target if _player.get("target") != null else goal
	## Remaining polyline length from feet → current target → rest of path.
	var remain := ppos.distance_to(goal)
	if wp_n > 0 and wp_i < wp_n:
		remain = ppos.distance_to(target)
		for i in range(maxi(wp_i + 1, 1), wp_n):
			remain += path[i - 1].distance_to(path[i])

	var shed_door: Vector2 = _farm.shed_door_world if _farm.shed_door_world != Vector2.ZERO \
		else _farm.shed_center
	if _farm.has_method("shed_approach_world"):
		shed_door = _farm.shed_approach_world()
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
	if bool(pq.get("looks_like_south_fence_loop", false)):
		contracts.append(
			"ROUTE FLAG looks_like_south_fence_loop=true — image should show east-then-south detour; FAIL path_sensible.")
	if float(pq.get("max_detour_ratio", 0.0)) > 0.0 \
			and float(pq.get("detour_ratio", 0.0)) > float(pq.get("max_detour_ratio", 0.0)):
		contracts.append(
			"ROUTE FLAG detour_ratio=%.2f > max=%.2f — expect long unnatural loop in image." % [
				float(pq.get("detour_ratio", 0.0)), float(pq.get("max_detour_ratio", 0.0))])

	## Corridor hint from live position vs bed centers.
	var corridor_now := "unknown"
	var path_y := IsoUtil.tile_to_world(
		Vector2(0.0, float(_farm.data.get("path", {}).get("tile_y", 3.0)))).y
	if absf(ppos.y - path_y) < 28.0:
		corridor_now = "path"
	elif ppos.y > (_farm.bed_centers.get("bed_3", ppos) as Vector2).y + 30.0:
		corridor_now = "south_of_beds"
	elif ppos.x < (_farm.bed_centers.get("bed_3", ppos) as Vector2).x - 40.0:
		corridor_now = "west_aisle"

	return {
		"frame": fi,
		"movie_t": snappedf(movie_t, 0.001),
		"clip_id": cid,
		"clip_set": _clip_set,
		"season": season,
		"progress_est": snappedf(progress, 0.001),
		"path_quality": pq,
		"nav": {
			"start": {"x": snappedf(start.x, 0.1), "y": snappedf(start.y, 0.1)},
			"goal": {"x": snappedf(goal.x, 0.1), "y": snappedf(goal.y, 0.1)},
			"target": {"x": snappedf(target.x, 0.1), "y": snappedf(target.y, 0.1)},
			"path_len": snappedf(path_len, 0.1),
			"crow_flies": pq.get("crow_flies"),
			"detour_ratio": pq.get("detour_ratio"),
			"remain_est": snappedf(remain, 0.1),
			"waypoint_i": wp_i,
			"waypoint_count": wp_n,
			"waypoints_sample": _sample_waypoints(path, 12),
			"dist_to_goal": snappedf(ppos.distance_to(goal), 0.1),
			"blocked_at_feet": blocked,
			"corridor_now": corridor_now,
			"nearest_walkable_delta": {
				"x": snappedf(nw.x - ppos.x, 0.1),
				"y": snappedf(nw.y - ppos.y, 0.1),
			},
			"arrived": (not _player.moving) and ppos.distance_to(goal) < 18.0,
			"looks_like_south_fence_loop": pq.get("looks_like_south_fence_loop"),
		},
		"anchors": {
			"shed_door": {"x": snappedf(shed_door.x, 0.1), "y": snappedf(shed_door.y, 0.1)},
			"shed_center": {
				"x": snappedf(_farm.shed_center.x, 0.1),
				"y": snappedf(_farm.shed_center.y, 0.1),
			},
			"gate": {"x": snappedf(gate.x, 0.1), "y": snappedf(gate.y, 0.1)},
			"dist_shed_door": snappedf(ppos.distance_to(shed_door), 0.1),
			"dist_gate": snappedf(ppos.distance_to(gate), 0.1),
			"nearest_bed": nearest_bed,
			"nearest_bed_dist": snappedf(nearest_bed_dist, 0.1),
			"bed_3": {
				"x": snappedf((_farm.bed_centers.get("bed_3", Vector2.ZERO) as Vector2).x, 0.1),
				"y": snappedf((_farm.bed_centers.get("bed_3", Vector2.ZERO) as Vector2).y, 0.1),
			},
			"bed_4": {
				"x": snappedf((_farm.bed_centers.get("bed_4", Vector2.ZERO) as Vector2).x, 0.1),
				"y": snappedf((_farm.bed_centers.get("bed_4", Vector2.ZERO) as Vector2).y, 0.1),
			},
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
		"expect": _expect_for_clip(cid, clip),
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

func _direct_checks(snap: Dictionary, cid: String, clip: Dictionary = {}) -> Array:
	## Yes/no questions the model must answer for this second-mark frame.
	var out: Array = []
	var nav: Dictionary = snap.get("nav", {})
	var pq: Dictionary = snap.get("path_quality", {})
	out.append({
		"id": "arrived",
		"ask": "Has the player arrived (nav.arrived)?",
		"state": nav.get("arrived"),
	})
	out.append({
		"id": "moving",
		"ask": "Is the player still moving?",
		"state": snap.get("player", {}).get("moving"),
	})
	out.append({
		"id": "path_sensible",
		"ask": (
			"Is the walk taking a short sensible corridor (path / west aisle) "
			+ "rather than a long east-then-south fence loop around the beds?"
		),
		"state_detour_ratio": pq.get("detour_ratio"),
		"state_max_detour": pq.get("max_detour_ratio"),
		"state_south_fence_loop_flag": pq.get("looks_like_south_fence_loop"),
		"state_corridor_now": nav.get("corridor_now"),
		"state_expect_corridor": clip.get("expect_corridor", pq.get("expect_corridor")),
		"state_east_overshoot": pq.get("east_overshoot"),
		"note": (
			"FAIL if image shows gardener circling east past middle beds then "
			+ "between south beds and south fence when going to the shed."
		),
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
	if cid.begins_with("shed") or cid == "path_west_to_shed" or cid == "shed_approach":
		out.append({
			"id": "on_shed_apron",
			"ask": "If arrived (or nearly): are feet on the shed door apron (clear of beds, in front of facade)?",
			"state_dist_shed_door": snap.get("anchors", {}).get("dist_shed_door"),
			"state_blocked": nav.get("blocked_at_feet"),
			"state_arrived": nav.get("arrived"),
		})
	if cid == "gate_to_pen":
		out.append({
			"id": "gate_clear",
			"ask": "Is the player clearly visible crossing the gate (not buried under a post)?",
			"state_dist_gate": snap.get("anchors", {}).get("dist_gate"),
		})
	## Water / bed approach contracts (clip_set=water).
	if _clip_set == "water" or cid.begins_with("water_"):
		var bid := str(clip.get("bed_id", ""))
		var expect_face := str(clip.get("expect_face", "south"))
		var goal_y := float(nav.get("goal", {}).get("y", 0.0))
		var center_y := 0.0
		for b in snap.get("beds", []):
			if str(b.get("id", "")) == bid:
				center_y = float(b.get("sort_y", b.get("y", 0.0)))
				## Prefer bed center y from anchors/beds if present.
				if b.has("center_y"):
					center_y = float(b.get("center_y"))
				out.append({
					"id": "thirst_%s" % bid,
					"ask": "Is the bed thirsty (droplet/icon) matching state.thirsty?",
					"state_thirsty": b.get("thirsty"),
					"state_empty": b.get("empty"),
				})
				break
		if _farm and _farm.bed_centers.has(bid):
			center_y = (_farm.bed_centers[bid] as Vector2).y
		out.append({
			"id": "approach_face",
			"ask": (
				"Does the gardener stand on the PATH/SOUTH lip of the bed "
				+ "(south of bed center), not the far north side?"
			),
			"state_expect_face": expect_face,
			"state_approach_face": pq.get("approach_face"),
			"state_goal_y": goal_y,
			"state_center_y": center_y,
			"state_player_y": snap.get("player", {}).get("y"),
			"state_arrived": nav.get("arrived"),
			"note": (
				"FAIL as blocker if arrived standing north of a north-row bed when "
				+ "expect_face is south / south_or_west."
			),
		})
		out.append({
			"id": "water_applied",
			"ask": (
				"If arrived with water tool and bed was thirsty: did watering apply "
				+ "(thirst cleared / water UX)? No silent fail."
			),
			"state_expect_water": bool(clip.get("expect_water", false)),
			"state_tool": str(clip.get("tool", "")),
			"state_arrived": nav.get("arrived"),
		})
		if bool(clip.get("expect_no_false_not_thirsty_vo", false)):
			out.append({
				"id": "no_false_not_thirsty_vo",
				"ask": (
					"After a successful water, does UX wrongly frame the bed as "
					+ "'not thirsty' as the primary tip (double-tap VO bug)?"
				),
				"state_expect": "success water VO wins; soft not-thirsty must not replace it",
			})
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
	return ("Walk video QA (clip_set=%s). Each clip: frames/ + state.jsonl + ticks.jsonl "
		+ "+ route.json (path_quality, waypoints). Stamp also has mechanics/ (full "
		+ "FarmMap/Player/World/GardenState/Narrator/Speak/ShedUI + "
		+ "REVIEW_BED_APPROACH_AND_WATER.md) and nav_diagnostics.json. "
		+ "Routing set: shed taps from bed_3 — FAIL east+south fence loops. "
		+ "Water set: watering-can → bed approach face + thirst/VO. "
		+ "Review: qa/review_walk_videos.py.") % _clip_set

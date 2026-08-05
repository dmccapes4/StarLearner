extends SceneTree
## Record short walk clips with per-frame game-state sidecar for Grok vision QA.
##
##   ./qa/run_movement_video_suite.sh
##
## Each clip folder under qa/out/movement_video/<stamp>/<clip_id>/:
##   frames/f_XXXX.png   — rendered nest view
##   state.jsonl         — one JSON object per frame (ground truth)
##   route.json          — start/goal/path summary
##   meta.json           — clip config / timing
##
## Shell runner muxes frames → walk.mp4 and optionally runs vision review.

const VIEW := Vector2i(1280, 600)
const CAPTURE_FPS := 12
const TARGET_S := 14.0
const STAR_TRIGGER := preload("res://scripts/content/StarTrigger.gd")

## Diverse walks: tunnels, outdoor, star approach, trail, camera reveal tour.
const CLIPS := [
	{
		"id": "nursery_to_entrance",
		"start_zone": "nursery",
		"goal_zone": "entrance",
		"goal_kind": "chamber",
		"note": "Multi-hop tunnel walk — camera follow, corridor readability, no path loops",
	},
	{
		"id": "entrance_to_surface",
		"start_zone": "entrance",
		"goal_zone": "surface",
		"goal_kind": "chamber",
		"note": "Nest mouth → outdoor surface — lighting/depth transition should feel natural",
	},
	{
		"id": "walk_to_nursery_star",
		"start_zone": "nursery",
		"goal_zone": "nursery",
		"goal_kind": "star",
		"note": "Approach knowledge star — gold star stays readable; player should settle near it",
	},
	{
		"id": "surface_forager_trail",
		"start_zone": "surface",
		"goal_zone": "surface",
		"goal_kind": "trail",
		"goal_role": "forager",
		"note": "Approach pheromone trail icon — marker should stay tappable and on-screen",
	},
	{
		"id": "queen_to_deep",
		"start_zone": "queen",
		"goal_zone": "deep",
		"goal_kind": "chamber",
		"note": "Deeper nest hop — tunnels readable, camera should not jerk off the ant",
	},
	{
		"id": "locked_rail_reveal_tour",
		"start_zone": "nursery",
		"goal_zone": "pupae",
		"goal_kind": "reveal",
		"note": "Locked-rail reveal tour — camera pans to star, then returns; chrome/UX must read clearly",
	},
]

var _out_abs: String = ""
var _manifest: Dictionary = {}
var _checks: Array = []

func _init() -> void:
	call_deferred("_run")

func _qa_root() -> String:
	var game_dir := ProjectSettings.globalize_path("res://").rstrip("/")
	return game_dir.get_base_dir().path_join("qa/out/movement_video")

func _save() -> Node:
	return root.get_node("Save")

func _events() -> Node:
	return root.get_node("Events")

func _run() -> void:
	print("======== Ant Explorer MOVEMENT VIDEO suite ========")
	root.get_viewport().size = VIEW
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	_out_abs = _qa_root().path_join(stamp)
	DirAccess.make_dir_recursive_absolute(_out_abs)
	_manifest = {
		"suite": "movement_video",
		"stamp": stamp,
		"viewport": {"w": VIEW.x, "h": VIEW.y},
		"capture_fps": CAPTURE_FPS,
		"target_s": TARGET_S,
		"clips": [],
		"checks": [],
		"agent_brief": _agent_brief(),
	}

	var save := _save()
	if save:
		if save.has_method("clear_all"):
			save.call("clear_all")
		save.set("intro_completed", true)
		save.set("stars_collected", PackedStringArray())
		save.set("player_x", NAN)
		save.set("player_y", NAN)
	_silence_idle_guard()

	var main: Node = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _settle(16)
	paused = false
	await _skip_intro()
	var hud := main.get_node_or_null("DebugHUD")
	if hud:
		hud.visible = false

	var world: Node = get_first_node_in_group("world")
	if world == null:
		_finish_fatal("world group missing")
		return
	var colony: Node = world.get("colony")
	var graph = world.get("graph")
	var pathing = world.get("pathing")
	var map_builder = world.get("map_builder")
	if colony == null or graph == null or pathing == null or map_builder == null:
		_finish_fatal("colony/graph/pathing/map_builder missing")
		return
	if world.get("_intro_done") != null:
		world.set("_intro_done", true)

	for clip in CLIPS:
		await _capture_clip(world, colony, graph, pathing, map_builder, clip)

	_manifest["checks"] = _checks
	FileAccess.open(_out_abs.path_join("report.json"), FileAccess.WRITE) \
		.store_string(JSON.stringify(_manifest, "\t"))
	var fails := 0
	for c in _checks:
		if not c.get("ok", false):
			fails += 1
	print("MOVEMENT_VIDEO done → %s (%d clips, %d fails)" % [
		_out_abs, (_manifest["clips"] as Array).size(), fails])
	quit(1 if fails > 0 else 0)

func _capture_clip(world: Node, colony: Node, graph, pathing, map_builder, clip: Dictionary) -> void:
	var cid: String = str(clip["id"])
	print("\n=== CAPTURE ", cid, " ===")
	var clip_dir := _out_abs.path_join(cid)
	var frames_dir := clip_dir.path_join("frames")
	DirAccess.make_dir_recursive_absolute(frames_dir)

	await _reset_interaction(world, colony)
	await _resume_camera_follow(world, colony)

	var start_zone := str(clip["start_zone"])
	var goal_zone := str(clip["goal_zone"])
	var goal_kind := str(clip["goal_kind"])
	var start_ch = graph.call("get_chamber_by_name", start_zone)
	var goal_ch = graph.call("get_chamber_by_name", goal_zone)
	_check("%s_start_chamber" % cid, start_ch != null, start_zone)
	_check("%s_goal_chamber" % cid, goal_ch != null, goal_zone)
	if start_ch == null or goal_ch == null:
		return

	var start_pos: Vector2 = start_ch.center
	var goal_pos: Vector2 = goal_ch.center
	var goal_label := goal_zone
	var star_id := ""
	var trail_role := str(clip.get("goal_role", ""))

	match goal_kind:
		"star":
			var placements: Dictionary = map_builder.get("star_placements") as Dictionary
			if placements.has(goal_zone):
				var info: Dictionary = placements[goal_zone]
				goal_pos = info["pos"] as Vector2
				star_id = str(info.get("star_id", ""))
				goal_label = "star:%s" % star_id
				# Stand a short walk away so approach is visible.
				start_pos = goal_pos + Vector2(-90, 50)
				start_pos = start_ch.call("clamp_point", start_pos)
			else:
				_check("%s_star_placement" % cid, false, goal_zone)
				return
		"trail":
			# Stand across the chamber and walk toward the marker (not onto hit_test).
			var marker: Node2D = _trail_marker_near(world, goal_ch.center, trail_role)
			if marker != null:
				goal_pos = marker.global_position + Vector2(-150, 90)
				goal_pos = goal_ch.call("clamp_point", goal_pos)
				# Nudge until outside the trail join hitbox.
				if marker.has_method("hit_test"):
					var guard := 0
					while bool(marker.call("hit_test", goal_pos)) and guard < 8:
						goal_pos += Vector2(-40, 30)
						goal_pos = goal_ch.call("clamp_point", goal_pos)
						guard += 1
				start_pos = marker.global_position + Vector2(160, -100)
				start_pos = goal_ch.call("clamp_point", start_pos)
			else:
				goal_pos = goal_ch.center + Vector2(0, goal_ch.world_rect.size.y * 0.18)
				goal_pos = goal_ch.call("clamp_point", goal_pos)
				start_pos = goal_ch.center + Vector2(-120, -50)
				start_pos = goal_ch.call("clamp_point", start_pos)
			goal_label = "trail:%s" % trail_role
		"reveal":
			# Park away from destination star so reveal pan is a real camera move.
			start_pos = start_ch.center
			var placements2: Dictionary = map_builder.get("star_placements") as Dictionary
			if placements2.has(goal_zone):
				var info2: Dictionary = placements2[goal_zone]
				goal_pos = info2["pos"] as Vector2
				star_id = str(info2.get("star_id", ""))
				goal_label = "reveal:%s" % star_id
			else:
				_check("%s_reveal_star" % cid, false, goal_zone)
				return
		_:
			goal_label = "chamber:%s" % goal_zone

	_place(colony, start_pos)
	await _settle(6)
	await _reset_interaction(world, colony)
	await _resume_camera_follow(world, colony)

	var charted: PackedVector2Array = pathing.call("find_path", start_pos, goal_pos)
	var route_pub := {
		"id": cid,
		"note": str(clip.get("note", "")),
		"start_zone": start_zone,
		"goal_zone": goal_zone,
		"goal_kind": goal_kind,
		"goal_label": goal_label,
		"star_id": star_id,
		"trail_role": trail_role,
		"start": {"x": start_pos.x, "y": start_pos.y},
		"goal": {"x": goal_pos.x, "y": goal_pos.y},
		"path_points": charted.size(),
		"path_len": _path_len(charted),
		"path_preview": _path_preview(charted, 24),
	}
	FileAccess.open(clip_dir.path_join("route.json"), FileAccess.WRITE) \
		.store_string(JSON.stringify(route_pub, "\t"))
	_check("%s_route_path" % cid, charted.size() >= 1 or goal_kind == "reveal",
		"path_points=%d len=%.1f" % [charted.size(), float(route_pub["path_len"])])

	if goal_kind == "reveal":
		var shell: Node = get_first_node_in_group("landscape_shell")
		if shell != null and shell.has_method("reveal"):
			shell.call("reveal", float(Time.get_ticks_msec()) / 1000.0)
			await _settle(6)
		# Ensure World will accept the reveal (intro + no trail/discovery pause).
		if world.get("_intro_done") != null:
			world.set("_intro_done", true)
		_events().emit_signal("star_reveal_requested", star_id)
		await _settle(8)
		var reveal_armed := int(world.get("_reveal_phase")) != 0
		_check("%s_reveal_armed" % cid, reveal_armed,
			"reveal_phase=%s" % str(world.get("_reveal_phase")))
	else:
		# Bypass Events/_handle_tap — a tap on a trail/star would join/discover
		# instead of walking (and trail-entry pauses the tree).
		colony.call("request_player_path", goal_pos)
		await _settle(4)
		var player0 = colony.call("get_player")
		var walking0: bool = player0 != null and not player0.path.is_empty()
		var near0: bool = player0 != null and player0.cell.distance_to(goal_pos) < 64.0
		_check("%s_path_started" % cid, walking0 or near0,
			"path_len=%d dist=%.0f" % [
				player0.path.size() if player0 else -1,
				player0.cell.distance_to(goal_pos) if player0 else -1.0,
			])

	var total_frames: int = int(round(TARGET_S * float(CAPTURE_FPS)))
	var state_path := clip_dir.path_join("state.jsonl")
	var state_f := FileAccess.open(state_path, FileAccess.WRITE)
	_check("%s_state_file" % cid, state_f != null, state_path)

	# --fixed-fps 24 → capture every other frame for CAPTURE_FPS 12.
	var frames_per_sample := 2
	var arrived_early := false
	var frame_count := 0
	var settle_left := -1
	for fi in total_frames:
		# Trail-entry VO pauses the SceneTree — unstick and resume the walk.
		if world != null and bool(world.get("_trail_entry_active")):
			await _reset_interaction(world, colony)
			await _resume_camera_follow(world, colony)
			if goal_kind != "reveal":
				colony.call("request_player_path", goal_pos)
				await _settle(2)
		for _s in frames_per_sample:
			await process_frame
		var snap := _state_snapshot(
			world, colony, graph, map_builder, clip, fi, goal_pos, goal_kind, star_id, trail_role
		)
		if state_f != null:
			state_f.store_line(JSON.stringify(snap))
		var img: Image = root.get_viewport().get_texture().get_image()
		if img != null:
			img.save_png(frames_dir.path_join("f_%04d.png" % fi))
			frame_count += 1
		# Once arrived (walk clips), keep recording a short settle then stop early.
		if settle_left < 0 and goal_kind != "reveal" \
				and bool(snap.get("arrived", false)) and fi > int(total_frames * 0.35):
			arrived_early = true
			settle_left = 12
		if settle_left > 0:
			settle_left -= 1
			if settle_left == 0:
				break

	if state_f != null:
		state_f.close()

	var meta := {
		"id": cid,
		"note": str(clip.get("note", "")),
		"start_zone": start_zone,
		"goal_zone": goal_zone,
		"goal_kind": goal_kind,
		"goal_label": goal_label,
		"capture_fps": CAPTURE_FPS,
		"target_s": TARGET_S,
		"frame_count": frame_count,
		"arrived_early": arrived_early,
		"frames_dir": "frames",
		"state_jsonl": "state.jsonl",
		"route_json": "route.json",
	}
	FileAccess.open(clip_dir.path_join("meta.json"), FileAccess.WRITE) \
		.store_string(JSON.stringify(meta, "\t"))
	(_manifest["clips"] as Array).append(meta)
	_check("%s_frames" % cid, frame_count >= 8, "frames=%d" % frame_count)

	await _reset_interaction(world, colony)
	await _resume_camera_follow(world, colony)
	await _settle(4)

func _state_snapshot(
	world: Node,
	colony: Node,
	graph,
	map_builder,
	clip: Dictionary,
	fi: int,
	goal_pos: Vector2,
	goal_kind: String,
	star_id: String,
	trail_role: String,
) -> Dictionary:
	var movie_t: float = float(fi) / float(CAPTURE_FPS)
	var player = colony.call("get_player")
	var view: Node2D = colony.call("get_view", colony.get("player_id")) as Node2D
	var cam: Camera2D = world.get("camera") as Camera2D
	if cam == null:
		cam = world.get_node_or_null("CameraFollow") as Camera2D

	var cell := Vector2.ZERO
	var facing := Vector2.RIGHT
	var walking := false
	var path_remaining := 0
	var path_len := 0.0
	var state_i := 0
	var role_i := 0
	if player != null:
		cell = player.cell
		facing = player.facing
		state_i = int(player.state)
		role_i = int(player.role)
		walking = not player.path.is_empty() and int(player.state) == 1  ## WALK ≈ 1
		path_remaining = maxi(0, player.path.size() - int(player.path_index))
		path_len = _path_len(player.path)

	var chamber_name := ""
	var ch = graph.call("chamber_containing", cell) if graph else null
	if ch != null:
		chamber_name = str(ch.name)

	var cam_pos := cam.global_position if cam else Vector2.ZERO
	var cam_zoom := cam.zoom.x if cam else 1.0
	var cam_pan := false
	if cam != null and cam.has_method("is_panning"):
		cam_pan = bool(cam.call("is_panning"))

	var view_half := Vector2(float(VIEW.x), float(VIEW.y)) * 0.5 / maxf(cam_zoom, 0.05)
	var view_radius := view_half.length()

	var dist_goal := cell.distance_to(goal_pos)
	var arrived := dist_goal <= (120.0 if goal_kind == "star" else 56.0)
	var reveal_phase := int(world.get("_reveal_phase")) if world else 0
	if goal_kind == "reveal":
		# AT_STAR ≈ 2, BACK ≈ 3, AUTO_TRAVEL ≈ 4 — tour made it to the star (or past).
		arrived = reveal_phase >= 2

	var nearest_star := _nearest_star_info(map_builder, cell, cam_pos, view_radius)
	var nearest_trail := _nearest_trail_info(world, cell, cam_pos, view_radius, trail_role)

	var expect_player := true
	var player_view_pos := view.global_position if view != null else cell
	var player_on_screen := player_view_pos.distance_to(cam_pos) < view_radius * 1.15

	var expect_goal_visible := goal_pos.distance_to(cam_pos) < view_radius * 1.05
	var goal_in_fov := expect_goal_visible

	return {
		"frame": fi,
		"movie_t": movie_t,
		"clip_id": str(clip["id"]),
		"goal_kind": goal_kind,
		"goal_label": str(clip.get("goal_kind", "")) + ":" + str(clip.get("goal_zone", "")),
		"star_id": star_id,
		"arrived": arrived,
		"path_progress_u": _progress_u(path_remaining, path_len, dist_goal),
		"player": {
			"cell_x": cell.x,
			"cell_y": cell.y,
			"view_x": player_view_pos.x,
			"view_y": player_view_pos.y,
			"facing_x": facing.x,
			"facing_y": facing.y,
			"state": state_i,
			"role": role_i,
			"walking": walking,
			"path_remaining": path_remaining,
			"path_len": path_len,
			"dist_goal": dist_goal,
			"expect_visible": expect_player,
			"on_screen_estimate": player_on_screen,
			"mismatch": expect_player and not player_on_screen,
		},
		"camera": {
			"x": cam_pos.x,
			"y": cam_pos.y,
			"zoom": cam_zoom,
			"panning": cam_pan,
			"mode": "pan" if cam_pan else "follow",
		},
		"chamber": chamber_name,
		"goal": {
			"x": goal_pos.x,
			"y": goal_pos.y,
			"dist": dist_goal,
			"in_fov": goal_in_fov,
			"expect_visible": expect_goal_visible and (arrived or dist_goal < view_radius),
			"kind": goal_kind,
		},
		"nearest_star": nearest_star,
		"nearest_trail": nearest_trail,
		"discovery_active": bool(world.get("_discovery_active")) if world else false,
		"reveal_phase": reveal_phase,
		"trail_entry_active": bool(world.get("_trail_entry_active")) if world else false,
		"tree_paused": paused,
		"viewport": {"w": VIEW.x, "h": VIEW.y},
	}

func _nearest_star_info(map_builder, cell: Vector2, cam_pos: Vector2, view_radius: float) -> Dictionary:
	var best := {}
	var best_d := 1e12
	if map_builder == null:
		return best
	var placements = map_builder.get("star_placements")
	if typeof(placements) != TYPE_DICTIONARY:
		return best
	for zone in placements.keys():
		var info: Dictionary = placements[zone]
		var pos: Vector2 = info.get("pos", Vector2.ZERO) as Vector2
		var d := cell.distance_to(pos)
		if d < best_d:
			best_d = d
			var cam_d := cam_pos.distance_to(pos)
			best = {
				"zone": str(zone),
				"star_id": str(info.get("star_id", "")),
				"dist": d,
				"cam_dist": cam_d,
				"in_approach": STAR_TRIGGER.inside_radius(cell, pos, 120.0),
				"in_fov": cam_d < view_radius,
				"expect_visible": cam_d < view_radius * 0.95,
				"pos": {"x": pos.x, "y": pos.y},
			}
	return best

func _nearest_trail_info(
	world: Node, cell: Vector2, cam_pos: Vector2, view_radius: float, prefer_role: String
) -> Dictionary:
	var best := {}
	var best_d := 1e12
	var trails: Array = world.get("trails") as Array if world else []
	for t in trails:
		if t == null or not (t is Node2D):
			continue
		var m := t as Node2D
		var role := str(m.get("role")) if m.get("role") != null else ""
		var d := cell.distance_to(m.global_position)
		# Prefer matching role when set.
		if not prefer_role.is_empty() and role != prefer_role and d > 80.0:
			continue
		if d < best_d:
			best_d = d
			var cam_d := cam_pos.distance_to(m.global_position)
			best = {
				"role": role,
				"dist": d,
				"cam_dist": cam_d,
				"in_fov": cam_d < view_radius,
				"expect_visible": cam_d < view_radius * 0.95,
				"pos": {"x": m.global_position.x, "y": m.global_position.y},
			}
	return best

func _progress_u(path_remaining: int, path_len: float, dist_goal: float) -> float:
	if path_len <= 1.0:
		return 1.0 if dist_goal < 40.0 else 0.0
	# Rough: remaining path length fraction unknown; use remaining waypoints + dist.
	var u := 1.0 - clampf(dist_goal / maxf(path_len, 1.0), 0.0, 1.0)
	if path_remaining <= 0 and dist_goal < 48.0:
		return 1.0
	return u

func _path_preview(path: PackedVector2Array, max_pts: int) -> Array:
	var out: Array = []
	if path.is_empty():
		return out
	var step := maxi(1, int(ceil(float(path.size()) / float(maxi(max_pts, 1)))))
	var i := 0
	while i < path.size():
		out.append({"x": path[i].x, "y": path[i].y})
		i += step
	var last: Vector2 = path[path.size() - 1]
	if out.is_empty() or Vector2(out[-1]["x"], out[-1]["y"]).distance_to(last) > 1.0:
		out.append({"x": last.x, "y": last.y})
	return out

func _path_len(path: PackedVector2Array) -> float:
	var total := 0.0
	for i in range(path.size() - 1):
		total += path[i].distance_to(path[i + 1])
	return total

func _trail_marker_near(world: Node, pos: Vector2, role: String) -> Node2D:
	var trails: Array = world.get("trails") as Array
	var best: Node2D = null
	var best_d := 999999.0
	for t in trails:
		if t == null or not (t is Node2D):
			continue
		var m := t as Node2D
		if not role.is_empty() and str(m.get("role")) != role:
			continue
		var d := m.global_position.distance_to(pos)
		if d < best_d:
			best_d = d
			best = m
	if best != null and best_d < 280.0:
		return best
	return null

func _place(colony: Node, pos: Vector2) -> void:
	if colony == null:
		return
	var player = colony.call("get_player")
	if player == null:
		return
	player.cell = pos
	player.prev_cell = pos
	if player.has_method("clear_path"):
		player.call("clear_path")
	var view = colony.call("get_view", colony.get("player_id"))
	if view != null:
		view.global_position = pos

func _resume_camera_follow(world: Node, colony: Node) -> void:
	var cam: Camera2D = world.get("camera") as Camera2D if world else null
	if cam == null:
		return
	var view: Node2D = colony.call("get_view", colony.get("player_id")) as Node2D if colony else null
	if cam.has_method("resume_follow"):
		cam.call("resume_follow", view, true)
	elif cam.has_method("set_follow_target") and view != null:
		cam.call("set_follow_target", view)
	# Comfortable nest zoom for kids.
	cam.zoom = Vector2(0.72, 0.72)

func _reset_interaction(world: Node, colony: Node = null) -> void:
	## Clear discovery / trail-entry / reveal and unpause — trail VO pauses the tree.
	var panel := get_first_node_in_group("video_panel")
	if panel != null and panel.has_method("is_open") and bool(panel.call("is_open")):
		if panel.has_method("_close"):
			panel.call("_close")
		await _settle(4)
	if world != null and world.has_method("_finish_trail_entry") \
			and bool(world.get("_trail_entry_active")):
		world.call("_finish_trail_entry")
	if world != null and world.has_method("_end_star_discovery"):
		world.call("_end_star_discovery")
	if world != null and world.has_method("_end_reveal_tour"):
		world.call("_end_reveal_tour", true)
	if colony != null and colony.has_method("player_has_role") \
			and bool(colony.call("player_has_role")):
		colony.call("set_player_role", 0)
	var player = colony.call("get_player") if colony else null
	if player != null and player.has_method("clear_path"):
		player.call("clear_path")
	paused = false
	_silence_idle_guard()
	var clock := root.get_node_or_null("SimClock")
	if clock != null and clock.has_method("set_enabled"):
		clock.call("set_enabled", true)
	var narrator := root.get_node_or_null("Narrator")
	if narrator != null and narrator.has_method("cancel"):
		narrator.call("cancel", "chamber:")
		narrator.call("cancel", "role:")
		narrator.call("cancel", "trail:")
		narrator.call("cancel", "star:")
	await _settle(2)

func _skip_intro() -> void:
	var intro: Node = get_first_node_in_group("intro_panel")
	if intro == null:
		await _settle(4)
		return
	if bool(intro.get("intro_done")):
		await _settle(4)
		return
	if intro.has_method("_finish"):
		intro.call("_finish")
	paused = false
	await _settle(8)

func _silence_idle_guard() -> void:
	var ig := root.get_node_or_null("IdleGuard")
	if ig and ig.has_method("set_active"):
		ig.call("set_active", false)
	var clock := root.get_node_or_null("SimClock")
	if clock:
		if clock.has_method("set_gate_on_app_pause"):
			clock.call("set_gate_on_app_pause", false)
		if clock.has_method("set_enabled"):
			clock.call("set_enabled", true)

func _settle(n: int) -> void:
	for _i in n:
		await process_frame

func _check(name: String, ok: bool, detail: String) -> void:
	_checks.append({"name": name, "ok": ok, "detail": detail})
	print(("OK  " if ok else "FAIL"), " ", name, " — ", detail)

func _finish_fatal(msg: String) -> void:
	_manifest["fatal"] = msg
	_manifest["checks"] = _checks
	FileAccess.open(_out_abs.path_join("report.json"), FileAccess.WRITE) \
		.store_string(JSON.stringify(_manifest, "\t"))
	print("FATAL ", msg)
	quit(1)

func _agent_brief() -> String:
	return ("Movement video QA. Each clip has frames/ + state.jsonl + route.json. "
		+ "Review with ./qa/review_movement_videos.py — compare rendered nest walk "
		+ "to state (player on-screen, camera follow/pan, star/trail visibility, "
		+ "pathing / unnatural motion). FAIL means capture broke; vision blocker/major "
		+ "means UX/render issues to fix.")

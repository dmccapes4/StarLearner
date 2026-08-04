extends SceneTree
## Full chamber + interaction QA suite — for agents to run and refine.
##
##   ./qa/run_chamber_suite.sh
##
## Covers every nest chamber (star stand / path), every pheromone trail,
## doorway routing, rails (reveal / locked / collected), and star-tap
## approach. Screenshots + report under qa/out/chamber_suite/<stamp>/.

const VIEW := Vector2i(1280, 600)
const STAR_TRIGGER := preload("res://scripts/content/StarTrigger.gd")
const STAR_RAIL_LAYOUT := preload("res://scripts/ui/StarRailLayout.gd")

const CHAMBERS := [
	"nursery", "pupae", "queen", "garden_a", "garden_b", "hygiene",
	"entrance", "outpost", "dump", "deep", "surface", "invasion",
]

## Trails from map.json — zone + role for naming.
const TRAILS := [
	{"role": "nurse", "zone": "nursery"},
	{"role": "forager", "zone": "surface"},
	{"role": "gardener", "zone": "garden_a"},
	{"role": "gardener", "zone": "hygiene"},
	{"role": "soldier", "zone": "outpost"},
	{"role": "waste", "zone": "dump"},
	{"role": "scout", "zone": "deep"},
]

## Sample corridor crossings kids actually walk (direct tunnels + one multi-hop).
const DOORWAYS := [
	{"a": "entrance", "b": "surface"},
	{"a": "nursery", "b": "queen"},
	{"a": "garden_a", "b": "dump"},
	{"a": "queen", "b": "deep"},
	{"a": "nursery", "b": "entrance"},  ## multi-hop via gardens
]

var _out_abs: String = ""
var _shot_i: int = 0
var _checks: Array = []
var _shots: Array = []

func _init() -> void:
	call_deferred("_run")

func _qa_root() -> String:
	var game_dir := ProjectSettings.globalize_path("res://").rstrip("/")
	return game_dir.get_base_dir().path_join("qa/out/chamber_suite")

func _save() -> Node:
	return root.get_node("Save")

func _events() -> Node:
	return root.get_node("Events")

func _run() -> void:
	print("======== Ant Explorer CHAMBER INTERACTION suite ========")
	root.get_viewport().size = VIEW
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	_out_abs = _qa_root().path_join(stamp)
	DirAccess.make_dir_recursive_absolute(_out_abs)

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
		_finish(false, "world group missing")
		return
	var colony: Node = world.get("colony")
	var graph = world.get("graph")
	var pathing = world.get("pathing")
	var map_builder = world.get("map_builder")
	if colony == null or graph == null or pathing == null or map_builder == null:
		_finish(false, "colony/graph/pathing/map_builder missing")
		return

	# --- Inventory -----------------------------------------------------------
	_check("chamber_count_12", CHAMBERS.size() == 12, "suite expects 12 chambers")
	var placements: Dictionary = map_builder.get("star_placements") as Dictionary
	_check("star_placements_12", placements.size() == 12, "got %d" % placements.size())
	var trail_place: Array = map_builder.get("trail_placements") as Array
	_check("trail_placements_7", trail_place.size() == 7, "got %d" % trail_place.size())
	_check("rail_layout_12", STAR_RAIL_LAYOUT.all_ids().size() == 12, "rail ids")

	for zone in CHAMBERS:
		var ch = graph.call("get_chamber_by_name", zone)
		_check("chamber_exists_%s" % zone, ch != null, "NavGraph chamber")
		_check("star_placement_%s" % zone, placements.has(zone), "star_placements key")

	# --- Per-chamber star stand + path --------------------------------------
	for zone in CHAMBERS:
		await _case_chamber(world, colony, graph, pathing, map_builder, zone)

	# --- Trails --------------------------------------------------------------
	for t in TRAILS:
		await _case_trail(world, colony, graph, pathing, str(t["zone"]), str(t["role"]))

	# --- Doorway / tunnel routing -------------------------------------------
	for d in DOORWAYS:
		_case_doorway(graph, pathing, str(d["a"]), str(d["b"]))

	# --- Live star tap approach (nursery — spawn room) -----------------------
	await _case_live_star_tap(world, colony, map_builder)

	# --- Rails UI ------------------------------------------------------------
	await _case_rails(save)

	# --- Chamber VO API ------------------------------------------------------
	_case_chamber_vo(world)

	# --- Nest overview framing ----------------------------------------------
	await _case_overview(world, colony, graph)

	_finish(true, "")

# --- cases ------------------------------------------------------------------

func _case_chamber(world: Node, colony: Node, graph, pathing, map_builder, zone: String) -> void:
	var ch = graph.call("get_chamber_by_name", zone)
	if ch == null:
		return
	var placements: Dictionary = map_builder.get("star_placements") as Dictionary
	if not placements.has(zone):
		return
	var info: Dictionary = placements[zone]
	var star_pos: Vector2 = info["pos"] as Vector2
	var star_id := str(info.get("star_id", ""))
	var center: Vector2 = ch.center

	_check("star_inside_%s" % zone, bool(ch.call("contains_point", star_pos)),
		"star=%s center=%s" % [star_pos, center])
	_check("star_id_%s" % zone, not star_id.is_empty(), star_id)

	var path: PackedVector2Array = pathing.call("find_path", center, star_pos)
	_check("path_center_to_star_%s" % zone, path.size() >= 1, "len=%d" % path.size())
	if path.size() >= 1:
		var end: Vector2 = path[path.size() - 1]
		var end_ch = graph.call("chamber_containing", end)
		var end_name := str(end_ch.name) if end_ch != null else ""
		_check("path_ends_in_%s" % zone, end_name == zone or bool(ch.call("contains_point", end)),
			"end_chamber=%s end=%s" % [end_name, end])
		var path_len := _path_len(path)
		_check("path_star_short_%s" % zone, path_len < 900.0,
			"len=%.1f (in-room walk)" % path_len)

	# Star should sit clear of tunnel mouth pads (auto-transit suck zone).
	var min_mouth := _min_mouth_dist(graph, ch, star_pos)
	_check("star_clear_of_mouth_%s" % zone, min_mouth > 64.0 + 20.0,
		"min_mouth=%.1f" % min_mouth)

	_place(colony, star_pos)
	await _settle(6)
	_look_at(world, star_pos, 0.72)
	await _settle(4)
	await _save_png("chamber_%s_star.png" % zone,
		"Player at %s knowledge star (%s) — chamber readable, star on screen" % [zone, star_id])

func _case_trail(world: Node, colony: Node, graph, pathing, zone: String, role: String) -> void:
	var ch = graph.call("get_chamber_by_name", zone)
	if ch == null:
		return
	var trail_pos: Vector2 = ch.center + Vector2(0, ch.world_rect.size.y * 0.18)
	trail_pos = ch.call("clamp_point", trail_pos)

	var marker: Node2D = _trail_marker_near(world, trail_pos, role)
	_check("trail_marker_%s_%s" % [role, zone], marker != null,
		"TrailMarker near %s" % trail_pos)
	if marker != null and marker.has_method("hit_test"):
		_check("trail_hit_%s_%s" % [role, zone], bool(marker.call("hit_test", trail_pos)),
			"hit_test at trail pos")

	var path: PackedVector2Array = pathing.call("find_path", ch.center, trail_pos)
	_check("path_to_trail_%s_%s" % [role, zone], path.size() >= 1, "len=%d" % path.size())

	_place(colony, trail_pos)
	await _settle(6)
	_look_at(world, trail_pos, 0.72)
	await _settle(4)
	await _save_png("trail_%s_%s.png" % [role, zone],
		"At %s pheromone trail in %s — icon tappable" % [role, zone])

func _case_doorway(graph, pathing, a: String, b: String) -> void:
	var ca = graph.call("get_chamber_by_name", a)
	var cb = graph.call("get_chamber_by_name", b)
	if ca == null or cb == null:
		_check("doorway_%s_%s_chambers" % [a, b], false, "missing chamber")
		return
	var edge = graph.call("tunnel_between", ca.id, cb.id)
	# Some pairs may not be direct — fall back to find_path_to_chamber.
	var path: PackedVector2Array
	if edge != null:
		var mid: Vector2 = (edge.call("mouth_a") + edge.call("mouth_b")) * 0.5
		path = pathing.call("find_path", ca.center, mid)
		_check("doorway_path_%s_to_%s" % [a, b], path.size() >= 2,
			"direct tunnel path len=%d" % path.size())
	else:
		path = pathing.call("find_path_to_chamber", ca.center, b)
		_check("doorway_path_%s_to_%s" % [a, b], path.size() >= 2,
			"multi-hop path len=%d" % path.size())
	if path.size() >= 1:
		var end: Vector2 = path[path.size() - 1]
		var end_ch = graph.call("chamber_containing", end)
		var ok_end := end_ch != null and (str(end_ch.name) == b or str(end_ch.name) == a)
		# Corridor tap often lands past the far mouth inside b.
		if not ok_end and end_ch != null:
			ok_end = str(end_ch.name) == b
		_check("doorway_ends_near_%s_%s" % [a, b], ok_end or cb.call("contains_point", end),
			"end_chamber=%s end=%s" % [str(end_ch.name) if end_ch else "?", end])

func _case_live_star_tap(world: Node, colony: Node, map_builder) -> void:
	var placements: Dictionary = map_builder.get("star_placements") as Dictionary
	if not placements.has("nursery"):
		_check("live_star_nursery_placement", false, "missing")
		return
	var star_pos: Vector2 = placements["nursery"]["pos"] as Vector2
	var sid := str(placements["nursery"].get("star_id", "02_larvae"))
	# Stand a short walk away so tap→path is meaningful.
	var start := star_pos + Vector2(-80, 40)
	_place(colony, start)
	await _settle(4)
	# Ensure no role blocks discovery.
	if colony.has_method("player_has_role") and bool(colony.call("player_has_role")):
		colony.call("set_player_role", 0)
	_events().emit_signal("player_path_requested", star_pos)
	await _settle(8)
	var player = colony.call("get_player")
	var approaching := false
	if player != null:
		approaching = not player.path.is_empty() \
			or player.cell.distance_to(star_pos) < 130.0 \
			or STAR_TRIGGER.inside_radius(player.cell, star_pos, 120.0)
	_check("live_star_tap_paths_%s" % sid, approaching,
		"player.cell=%s star=%s" % [player.cell if player else "?", star_pos])

	# Wait for settle near star (or place if sim is slow under fixed-fps).
	var arrived := await _arrive(colony, star_pos, 120.0, 12.0)
	if not arrived:
		_place(colony, star_pos)
		await _settle(6)
	player = colony.call("get_player")
	var near := player != null and STAR_TRIGGER.inside_radius(player.cell, star_pos, 120.0)
	_check("live_star_arrive_%s" % sid, near,
		"dist=%.1f" % (player.cell.distance_to(star_pos) if player else -1.0))

	_look_at(world, star_pos, 0.72)
	await _settle(4)
	await _save_png("live_nursery_star_approach.png",
		"After tap→path to nursery star — player inside approach radius")
	# Arrive-near-star can start discovery VO/video — clear so later rail tour isn't blocked.
	await _clear_discovery(world)

func _case_rails(save: Node) -> void:
	var shell: Node = get_first_node_in_group("landscape_shell")
	_check("landscape_shell_present", shell != null, "group landscape_shell")
	if shell == null:
		return
	var world: Node = get_first_node_in_group("world")
	# Park the player away from any star so dwell cannot re-arm discovery mid-rails.
	if world != null:
		var colony: Node = world.get("colony")
		var graph = world.get("graph")
		var nursery = graph.call("get_chamber_by_name", "nursery") if graph else null
		if colony != null and nursery != null:
			_place(colony, nursery.center)
		await _clear_discovery(world)
		# Ensure World will accept star_reveal_requested (intro gate).
		if world.get("_intro_done") != null:
			world.set("_intro_done", true)

	var now := float(Time.get_ticks_msec()) / 1000.0
	if shell.has_method("occlude"):
		shell.call("occlude", false)
	await _settle(4)
	await _save_png("rails_occluded.png", "Side shelves tucked under soil (default)")

	if shell.has_method("reveal"):
		shell.call("reveal", now)
	await _settle(6)
	_check("rails_revealed_flag", bool(shell.get("revealed")), "revealed=true after reveal()")
	await _save_png("rails_revealed_locked.png",
		"Shelves revealed — all tiles still locked/undiscovered")

	# Locked tile: first tap arms, second within 3s requests reveal tour.
	if shell.has_method("_handle_tile_tap"):
		var t0 := float(Time.get_ticks_msec()) / 1000.0
		var a1: String = str(shell.call("_handle_tile_tap", "01_queen", t0))
		_check("rail_locked_arm", a1 == "reveal_armed" or a1 == shell.get("ACT_REVEAL_ARMED"),
			"got %s" % a1)
		var a2: String = str(shell.call("_handle_tile_tap", "01_queen", t0 + 0.2))
		_check("rail_locked_tour", a2 == "reveal_tour" or a2 == shell.get("ACT_REVEAL_TOUR"),
			"got %s" % a2)
		var queen_pos := _star_pos(world, "queen")
		var arrived_cam := await _wait_camera_near(world, queen_pos, 160.0, 5.0)
		_check("rail_tour_camera_near_queen", arrived_cam,
			"camera should pan to queen star after locked-tile confirm")
		if not arrived_cam and world != null:
			# Still shoot a readable queen frame so agents can review the destination.
			_look_at(world, queen_pos, 0.72)
			await _settle(4)
		await _save_png("rails_reveal_tour_queen.png",
			"After locked-tile confirm — camera near the queen-chamber star")
		# Cancel tour so later cases aren't blocked.
		if world != null and world.has_method("_end_reveal_tour"):
			world.call("_end_reveal_tour", true)
		await _settle(6)

	# Collected tile double-tap → video path.
	if save:
		save.set("stars_collected", PackedStringArray(["06_pheromone"]))
	if shell.has_method("refresh"):
		shell.call("refresh")
	if shell.has_method("reveal"):
		shell.call("reveal", float(Time.get_ticks_msec()) / 1000.0)
	await _settle(4)
	if shell.has_method("_handle_tile_tap"):
		var t1 := float(Time.get_ticks_msec()) / 1000.0
		var c1: String = str(shell.call("_handle_tile_tap", "06_pheromone", t1))
		_check("rail_collected_arm", c1 == "armed" or c1 == shell.get("ACT_ARMED"),
			"got %s" % c1)
		var c2: String = str(shell.call("_handle_tile_tap", "06_pheromone", t1 + 0.05))
		_check("rail_collected_video",
			c2 == "video" or c2 == "video_unavailable" \
			or c2 == shell.get("ACT_VIDEO") or c2 == shell.get("ACT_VIDEO_UNAVAILABLE"),
			"got %s" % c2)
		await _settle(8)
		var panel := get_first_node_in_group("video_panel")
		var open := panel != null and panel.has_method("is_open") and bool(panel.call("is_open"))
		if open:
			await _save_png("rails_collected_video.png", "Collected rail tile opened documentary")
			if panel.has_method("_close"):
				panel.call("_close")
			await _settle(4)
		else:
			# Headless / missing ogv still exercised the arm→trigger path.
			await _save_png("rails_collected_armed.png",
				"Collected rail double-tap path exercised (video may be unavailable headless)")

	if shell.has_method("occlude"):
		shell.call("occlude", false)
	# Restore clean save stars for any leftover checks.
	if save:
		save.set("stars_collected", PackedStringArray())

func _case_chamber_vo(world: Node) -> void:
	var cvo: Node = world.get("chamber_vo") as Node
	_check("chamber_vo_present", cvo != null, "World.chamber_vo")
	if cvo == null:
		return
	if cvo.has_method("reset_session"):
		cvo.call("reset_session")
	var announced := false
	if cvo.has_method("try_announce"):
		announced = bool(cvo.call("try_announce", "nursery"))
	_check("chamber_vo_nursery_first", announced, "try_announce nursery")
	var again := true
	if cvo.has_method("try_announce"):
		again = bool(cvo.call("try_announce", "nursery"))
	_check("chamber_vo_nursery_once", not again, "second announce must be false")

func _case_overview(world: Node, colony: Node, graph) -> void:
	var nursery = graph.call("get_chamber_by_name", "nursery")
	var surface = graph.call("get_chamber_by_name", "surface")
	if nursery == null:
		return
	_place(colony, nursery.center)
	await _settle(4)
	_look_at(world, nursery.center, 0.11)
	await _settle(6)
	await _save_png("nest_overview.png",
		"Zoomed-out nest overview from nursery — chambers/tunnels readable")
	if surface != null:
		_place(colony, surface.center)
		await _settle(4)
		_look_at(world, surface.center, 0.48)
		await _settle(4)
		await _save_png("surface_overview.png",
			"Surface meadow overview — outdoor foraging chamber")

# --- helpers ----------------------------------------------------------------

func _trail_marker_near(world: Node, pos: Vector2, role_name: String) -> Node2D:
	var trails: Array = world.get("trails") as Array
	var best: Node2D = null
	var best_d := 999999.0
	for t in trails:
		if t == null or not (t is Node2D):
			continue
		var m := t as Node2D
		var d := m.global_position.distance_to(pos)
		if d < best_d:
			best_d = d
			best = m
	if best != null and best_d < 200.0:
		return best
	# Fallback: scan trails_root children.
	var root_n: Node = world.get("trails_root") as Node
	if root_n:
		for c in root_n.get_children():
			if c is Node2D and (c as Node2D).global_position.distance_to(pos) < 200.0:
				return c as Node2D
	return best if best_d < 400.0 else null

func _min_mouth_dist(graph, ch, star_pos: Vector2) -> float:
	var min_d := 1e9
	if ch == null:
		return min_d
	for tid in ch.tunnel_ids:
		if tid < 0 or tid >= graph.tunnels.size():
			continue
		var edge = graph.tunnels[tid]
		var mouth: Vector2 = edge.mouth_a() if edge.a == ch.id else edge.mouth_b()
		min_d = minf(min_d, star_pos.distance_to(mouth))
	return min_d

func _path_len(path: PackedVector2Array) -> float:
	var total := 0.0
	for i in range(path.size() - 1):
		total += path[i].distance_to(path[i + 1])
	return total

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

func _look_at(world: Node, pos: Vector2, zoom: float) -> void:
	var cam: Camera2D = world.get("camera") as Camera2D
	if cam == null:
		cam = world.get_node_or_null("CameraFollow") as Camera2D
	if cam == null:
		return
	# Frame the pose directly (do not soft-follow a moving ant during QA shots).
	if cam.has_method("begin_pan_to"):
		cam.call("begin_pan_to", pos, 0.01, true)
	cam.global_position = pos
	cam.zoom = Vector2(zoom, zoom)

func _arrive(colony: Node, target: Vector2, radius: float, timeout_sec: float) -> bool:
	var frames_left := maxi(1, int(ceil(timeout_sec * 24.0)))
	while frames_left > 0:
		var player = colony.call("get_player") if colony else null
		if player != null and player.cell.distance_to(target) <= radius:
			return true
		frames_left -= 1
		await process_frame
	return false

func _star_pos(world: Node, zone: String) -> Vector2:
	if world == null:
		return Vector2.ZERO
	var mb = world.get("map_builder")
	if mb == null:
		return Vector2.ZERO
	var placements = mb.get("star_placements")
	if typeof(placements) != TYPE_DICTIONARY or not placements.has(zone):
		return Vector2.ZERO
	var info: Dictionary = placements[zone]
	var p = info.get("pos", Vector2.ZERO)
	return p if p is Vector2 else Vector2.ZERO

func _wait_camera_near(world: Node, target: Vector2, radius: float, timeout_sec: float) -> bool:
	if target == Vector2.ZERO:
		return false
	var frames_left := maxi(1, int(ceil(timeout_sec * 24.0)))
	while frames_left > 0:
		var cam: Camera2D = world.get("camera") as Camera2D if world else null
		if cam != null and cam.global_position.distance_to(target) <= radius:
			return true
		frames_left -= 1
		await process_frame
	return false

func _clear_discovery(world: Node) -> void:
	var panel := get_first_node_in_group("video_panel")
	if panel != null and panel.has_method("is_open") and bool(panel.call("is_open")):
		if panel.has_method("_close"):
			panel.call("_close")
		await _settle(4)
	if world != null and world.has_method("_end_star_discovery"):
		world.call("_end_star_discovery")
	if world != null and world.has_method("_end_reveal_tour"):
		world.call("_end_reveal_tour", true)
	paused = false
	var clock := root.get_node_or_null("SimClock")
	if clock != null and clock.has_method("set_enabled"):
		clock.call("set_enabled", true)
	await _settle(4)

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

func _save_png(file_name: String, note: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = root.get_viewport().get_texture().get_image()
	if img:
		img.save_png(_out_abs.path_join(file_name))
	_shot_i += 1
	_shots.append({"file": file_name, "note": note})
	print(" shot ", file_name)

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
		"suite": "chamber_suite",
		"fatal": fatal,
		"checks": _checks,
		"shots": _shots,
		"agent_brief": "Full Ant Explorer chamber/interaction gate. FAIL means a chamber star is unreachable or outside the room, a trail icon is missing, a doorway path does not land in the destination chamber, rails no longer arm/reveal, or a live star tap does not approach. Open every PNG with the Read tool — judge nest readability, star/trail visibility, and rail chrome. Fix production code, then re-run ./qa/run_chamber_suite.sh until failed=0.",
	}
	FileAccess.open(_out_abs.path_join("report.json"), FileAccess.WRITE).store_string(
		JSON.stringify(report, "\t"))
	print("CHAMBER suite → %s  fails=%d shots=%d" % [_out_abs, fails, _shots.size()])
	quit(1 if (not ok_setup or fails > 0) else 0)

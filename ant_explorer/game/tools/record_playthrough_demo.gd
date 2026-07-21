extends SceneTree
## Automated demo playthrough for README / sharing.
##
##   GODOT_USER_DATA_DIR=/tmp/ant_demo_user \
##   godot --path game --fixed-fps 24 --write-movie /tmp/ant_demo.avi \
##     -s res://tools/record_playthrough_demo.gd
##
## Beats:
##   START → intro → entrance-room star (10s video) → check sides (tile lit)
##   → tunnel to pheromone trail → another star (10s) → check sides
##   → 15s wander → rail tile double-tap (3s video)
##
## Autoload singletons are resolved via /root at runtime — the -s entry script
## cannot see their compile-time names.

const FPS := 24.0
const STAR_ENTRANCE_FALLBACK := Vector2(-300, -2530)  ## 06_pheromone
const TRAIL_FORAGER := Vector2(-400, -3327)
const STAR_SURFACE_FALLBACK := Vector2(-400, -3740)   ## 05_forage
const WANDER_SPOTS := [
	Vector2(-500, -3400),
	Vector2(-250, -3550),
	Vector2(-550, -3600),
	Vector2(-380, -3480),
	Vector2(-420, -3650),
]

func _init() -> void:
	call_deferred("_run")

func _save() -> Node:
	return root.get_node("Save")

func _events() -> Node:
	return root.get_node("Events")

func _run() -> void:
	root.get_viewport().size = Vector2i(1280, 600)
	var save := _save()
	save.call("clear_all")
	save.set("intro_completed", false)
	save.set("stars_collected", PackedStringArray())
	save.set("player_x", NAN)
	save.set("player_y", NAN)

	var main: Node = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var hud := main.get_node_or_null("DebugHUD")
	if hud:
		hud.visible = false
	_silence_idle_guard()

	print("DEMO: waiting for intro panel")
	var intro: Node = await _wait_group("intro_panel", 10.0)
	if intro == null:
		push_error("DEMO: no intro_panel")
		quit(1)
		return

	await _sec(1.0)
	print("DEMO: START")
	if intro.has_method("_on_start_pressed"):
		intro.call("_on_start_pressed")

	if intro.has_signal("finished") and not bool(intro.get("intro_done")):
		await intro.finished
	print("DEMO: intro finished")

	var world: Node = get_first_node_in_group("world")
	if world == null:
		push_error("DEMO: no world")
		quit(1)
		return
	var colony: Node = world.get("colony")
	var star_entrance := _star_pos(world, "entrance", STAR_ENTRANCE_FALLBACK)
	var star_surface := _star_pos(world, "surface", STAR_SURFACE_FALLBACK)

	# 1–2) First star in the starting room, immediately — then 10s of video.
	print("DEMO: entrance-room star first thing")
	await _walk_or_place(colony, star_entrance, 55.0, 18.0)
	await _sec(0.6)
	await _watch_star_video(10.0)
	print("DEMO: closed entrance star")

	# 3) Exit video and check the side rails so the new tile is visible.
	print("DEMO: check sides (entrance tile)")
	await _check_sides(4.0)

	# 4) Tunnel up to the pheromone / leaf-cutter trail and ride it briefly.
	print("DEMO: tunnel to pheromone trail")
	await _walk_or_place(colony, TRAIL_FORAGER, 120.0, 40.0)
	_tap(TRAIL_FORAGER)
	await _sec(0.8)
	print("DEMO: on pheromone trail")
	await _sec(10.0)
	print("DEMO: exit trail")
	_tap(star_surface + Vector2(120, 80))
	await _sec(1.0)
	if colony != null and bool(colony.call("player_has_role")):
		colony.call("set_player_role", 0)  ## Role.NONE
		await _sec(0.3)

	# 5) Another star — surface forage — 10s video.
	print("DEMO: surface star 05_forage")
	await _walk_or_place(colony, star_surface, 50.0, 18.0)
	await _sec(0.8)
	await _watch_star_video(10.0)
	print("DEMO: closed surface star")

	# 6) Check sides again (second tile lit).
	print("DEMO: check sides (surface tile)")
	await _check_sides(4.0)

	# 7) Random exploration ~15s.
	print("DEMO: wander 15s")
	var wander_t := 0.0
	var wi := 0
	while wander_t < 15.0:
		_tap(WANDER_SPOTS[wi % WANDER_SPOTS.size()])
		var step := 2.5
		await _sec(step)
		wander_t += step
		wi += 1

	# 8) Click a collected rail tile and play its video for 3s.
	print("DEMO: rail tile video 3s")
	await _play_rail_tile("06_pheromone", 3.0)

	await _sec(0.8)
	print("DEMO: done")
	quit(0)

func _star_pos(world: Node, zone: String, fallback: Vector2) -> Vector2:
	var mb = world.get("map_builder") if world != null else null
	if mb == null:
		return fallback
	var placements = mb.get("star_placements")
	if typeof(placements) != TYPE_DICTIONARY or not placements.has(zone):
		return fallback
	var info: Dictionary = placements[zone]
	var p = info.get("pos", fallback)
	return p if p is Vector2 else fallback

## Reveal the side star-rails and hold them up so a newly collected tile reads.
func _check_sides(hold_sec: float) -> void:
	var shell: Node = get_first_node_in_group("landscape_shell")
	if shell == null:
		await _sec(hold_sec)
		return
	var now := float(Time.get_ticks_msec()) / 1000.0
	if shell.has_method("reveal"):
		shell.call("reveal", now)
	elif shell.has_method("_handle_side_touch"):
		shell.call("_handle_side_touch", now)
	await _sec(hold_sec)

func _play_rail_tile(star_id: String, watch_sec: float) -> void:
	var shell: Node = get_first_node_in_group("landscape_shell")
	if shell == null:
		print("DEMO: no landscape_shell for rail tile")
		return
	var now := float(Time.get_ticks_msec()) / 1000.0
	if shell.has_method("reveal"):
		shell.call("reveal", now)
	await _sec(0.6)
	if shell.has_method("_handle_tile_tap"):
		# Double-tap within 1s arms then plays a collected tile.
		var t0 := float(Time.get_ticks_msec()) / 1000.0
		shell.call("_handle_tile_tap", star_id, t0)
		await process_frame
		shell.call("_handle_tile_tap", star_id, t0 + 0.05)
	await _sec(0.5)
	var opened := await _wait_video_open(4.0)
	if not opened:
		print("DEMO: rail video did not open")
		return
	await _sec(watch_sec)
	_close_video()
	print("DEMO: closed rail video")

func _silence_idle_guard() -> void:
	var ig := root.get_node_or_null("IdleGuard")
	if ig == null:
		return
	if ig.has_method("set_active"):
		ig.call("set_active", false)
	else:
		ig.set_process(false)
		ig.set_process_input(false)
		ig.set_process_unhandled_input(false)
	var clock := root.get_node_or_null("SimClock")
	if clock != null:
		if clock.has_method("set_gate_on_app_pause"):
			clock.call("set_gate_on_app_pause", false)
		if clock.has_method("set_enabled"):
			clock.call("set_enabled", true)

func _bump_idle() -> void:
	var ig := root.get_node_or_null("IdleGuard")
	if ig != null and ig.has_method("bump"):
		ig.call("bump")

func _tap(world_pos: Vector2) -> void:
	_bump_idle()
	_events().emit_signal("player_path_requested", world_pos)

func _place(colony: Node, pos: Vector2) -> void:
	if colony == null:
		return
	var player = colony.call("get_player")
	if player == null:
		return
	player.cell = pos
	player.prev_cell = pos
	player.call("clear_path")
	var view = colony.call("get_view", colony.get("player_id"))
	if view != null:
		view.global_position = pos

func _walk_or_place(colony: Node, target: Vector2, radius: float, timeout_sec: float) -> void:
	_tap(target)
	var arrived := await _arrive(colony, target, radius, timeout_sec)
	if not arrived:
		print("DEMO: placing player at %s" % target)
		_place(colony, target)
		await _sec(0.4)

func _arrive(colony: Node, target: Vector2, radius: float, timeout_sec: float) -> bool:
	var frames_left := _frames(timeout_sec)
	while frames_left > 0:
		_bump_idle()
		if colony == null:
			return false
		var player = colony.call("get_player")
		if player != null and player.cell.distance_to(target) <= radius:
			return true
		frames_left -= 1
		await process_frame
	print("DEMO: arrive timeout near %s" % target)
	return false

func _watch_star_video(seconds: float) -> void:
	var opened := await _wait_video_open(20.0)
	if not opened:
		print("DEMO: video did not open; continuing")
		return
	await _sec(seconds)
	_close_video()
	await _sec(0.6)

func _wait_video_open(timeout_sec: float) -> bool:
	var frames_left := _frames(timeout_sec)
	while frames_left > 0:
		var panel := get_first_node_in_group("video_panel")
		if panel != null and panel.has_method("is_open") and bool(panel.call("is_open")):
			return true
		frames_left -= 1
		await process_frame
	return false

func _close_video() -> void:
	var panel := get_first_node_in_group("video_panel")
	if panel != null and panel.has_method("_close"):
		panel.call("_close")

func _wait_group(group: String, timeout_sec: float) -> Node:
	var frames_left := _frames(timeout_sec)
	while frames_left > 0:
		var n := get_first_node_in_group(group)
		if n != null:
			return n
		frames_left -= 1
		await process_frame
	return null

func _frames(seconds: float) -> int:
	return maxi(1, int(ceil(seconds * FPS)))

func _sec(seconds: float) -> void:
	for i in _frames(seconds):
		_bump_idle()
		await process_frame

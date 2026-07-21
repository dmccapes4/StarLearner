extends SceneTree
## Automated demo playthrough for README / sharing.
##
##   GODOT_USER_DATA_DIR=/tmp/ant_demo_user \
##   godot --path game --fixed-fps 24 --write-movie /tmp/ant_demo.avi \
##     -s res://tools/record_playthrough_demo.gd
##
## Beats: START → intro → entrance VO → nearest star (10s) → tunnel to surface →
## leaf-cutter trail (automate) → surface star (10s) → wander → rail video (3s).
##
## Autoload singletons are resolved via /root at runtime — the -s entry script
## cannot see their compile-time names.

const FPS := 24.0
const STAR_ENTRANCE := Vector2(-300, -2530)   ## 06_pheromone
const TRAIL_FORAGER := Vector2(-400, -3327)
const STAR_SURFACE := Vector2(-400, -3740)    ## 05_forage
const SURFACE_WANDER := [
	Vector2(-500, -3400),
	Vector2(-250, -3550),
	Vector2(-550, -3600),
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

	await _sec(1.2)
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

	print("DEMO: entrance narration")
	await _sec(7.5)

	print("DEMO: walk to entrance star 06_pheromone")
	await _walk_or_place(colony, STAR_ENTRANCE, 55.0, 20.0)
	await _sec(1.0)
	await _watch_star_video(10.0)
	print("DEMO: closed entrance star")

	print("DEMO: tunnel toward surface / leaf-cutter trail")
	# Walk most of the way so the tunnel reads on camera, then join the trail.
	await _walk_or_place(colony, TRAIL_FORAGER, 120.0, 40.0)
	_tap(TRAIL_FORAGER)  # trail hit-test is on tap position
	await _sec(0.8)
	print("DEMO: leaf-cutter trail automate")
	await _sec(12.0)

	print("DEMO: exit trail")
	_tap(STAR_SURFACE + Vector2(120, 80))
	await _sec(1.2)
	if colony != null and bool(colony.call("player_has_role")):
		colony.call("set_player_role", 0)  ## Role.NONE
		await _sec(0.3)

	print("DEMO: surface star 05_forage")
	await _walk_or_place(colony, STAR_SURFACE, 50.0, 18.0)
	await _sec(1.2)
	await _watch_star_video(10.0)
	print("DEMO: closed surface star")
	print("DEMO: wander")
	for i in 3:
		_tap(SURFACE_WANDER[i % SURFACE_WANDER.size()])
		await _sec(1.7)

	print("DEMO: open star rails")
	var shell: Node = get_first_node_in_group("landscape_shell")
	if shell != null and shell.has_method("reveal"):
		var now := float(Time.get_ticks_msec()) / 1000.0
		shell.call("reveal", now)
		await _sec(0.8)
		var pick := "06_pheromone"
		if shell.has_method("_handle_tile_tap"):
			var t_arm := float(Time.get_ticks_msec()) / 1000.0
			shell.call("_handle_tile_tap", pick, t_arm)
			await process_frame
			shell.call("_handle_tile_tap", pick, t_arm + 0.05)
		await _sec(0.8)
		await _wait_video_open(4.0)
		await _sec(3.0)
		_close_video()
		print("DEMO: closed rail video")

	await _sec(1.0)
	print("DEMO: done")
	quit(0)

func _silence_idle_guard() -> void:
	var ig := root.get_node_or_null("IdleGuard")
	if ig == null:
		return
	ig.set_process(false)
	ig.set_process_input(false)
	ig.set_process_unhandled_input(false)

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

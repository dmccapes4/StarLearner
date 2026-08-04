extends SceneTree
## Capture pen / gate verification screenshots (closed + open).
##
##   godot --path game --fixed-fps 24 -s res://tools/shot_pen_gate.gd

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.get_viewport().size = Vector2i(1280, 720)
	var save := root.get_node_or_null("/root/Save")
	if save and save.has_method("clear_all"):
		save.clear_all()
	if save and save.has_method("set_flag"):
		save.set_flag("shed_tools_intro", true)
		save.set_flag("intro_completed", true)
	var ig := root.get_node_or_null("/root/IdleGuard")
	if ig and ig.has_method("set_active"):
		ig.set_active(false)

	var main: Node = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await create_timer(0.6, true, false, true).timeout
	self.paused = false

	var intro: Node = main.get_node_or_null("IntroPanel")
	if intro and intro.has_method("_on_start"):
		intro.visible = true
		if intro.get("_panel") != null:
			intro._panel.visible = true
		intro.call("_on_start")
		await create_timer(0.5, true, false, true).timeout
		var video: Node = main.get_node_or_null("VideoPanel")
		if video and video.has_method("is_open") and bool(video.call("is_open")) and video.has_method("_close"):
			video.call("_close")
		if intro.has_method("close") or intro.has_method("_close"):
			pass
		intro.visible = false
		self.paused = false

	var world: Node = main.get_node_or_null("World")
	if world == null:
		for c in main.get_children():
			if str(c.name).to_lower().contains("world") or c.has_method("get") and c.get("farm_map") != null:
				world = c
				break
	## World is often the Main scene root script host — probe farm_map.
	var farm: Node = null
	var player: Node2D = null
	var gate: Node2D = null
	if world:
		farm = world.get("farm_map") as Node if world.get("farm_map") != null else null
		player = world.get("player") as Node2D if world.get("player") != null else null
		gate = world.get("pen_gate") as Node2D if world.get("pen_gate") != null else null
	if farm == null:
		farm = main.find_child("FarmMap", true, false)
	if player == null:
		player = main.find_child("Player", true, false) as Node2D
	if gate == null:
		gate = main.find_child("PenGate", true, false) as Node2D

	if farm == null or player == null:
		push_error("FarmMap/Player missing")
		quit(1)
		return

	var gate_pos: Vector2 = farm.get("gate_world") if farm.get("gate_world") != null else Vector2.ZERO
	if gate_pos == Vector2.ZERO:
		gate_pos = farm.get("fence_center") as Vector2
	## Stand outside the gate (closed shot).
	player.global_position = gate_pos + Vector2(-70, 20)
	if player.has_method("stop"):
		player.call("stop")
	await create_timer(0.4, true, false, true).timeout
	_shot_cam_on(player, gate_pos)
	await create_timer(0.2, true, false, true).timeout
	_save_shot("pen_gate_closed.png")

	## Walk into open range.
	player.global_position = gate_pos + Vector2(-20, 8)
	await create_timer(0.55, true, false, true).timeout
	_save_shot("pen_gate_open.png")

	## Wide overview of full-height pen + yard perimeter.
	var pen: Vector2 = farm.get("fence_center") as Vector2
	var yard_mid: Vector2 = farm.get("spawn_world") as Vector2
	player.global_position = yard_mid
	_shot_cam_on(player, pen)
	## Pull camera back if possible.
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if cam:
		cam.zoom = Vector2(0.72, 0.72)
		cam.global_position = (pen + yard_mid) * 0.5
	await create_timer(0.35, true, false, true).timeout
	_save_shot("pen_overview.png")

	print("OK pen gate shots written")
	quit(0)

func _shot_cam_on(player: Node2D, focus: Vector2) -> void:
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if cam:
		cam.make_current()
		cam.global_position = focus

func _save_shot(fname: String) -> void:
	var out_dir := "res://docs/screenshots/pen"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var img: Image = root.get_viewport().get_texture().get_image()
	var path := "%s/%s" % [out_dir, fname]
	img.save_png(path)
	print("wrote ", path)

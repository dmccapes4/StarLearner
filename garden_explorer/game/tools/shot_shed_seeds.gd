extends SceneTree
## Open the shed seed catalog and capture a verification screenshot.
##
##   godot --path game --fixed-fps 24 -s res://tools/shot_shed_seeds.gd

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.get_viewport().size = Vector2i(1280, 720)
	var save := root.get_node_or_null("/root/Save")
	if save and save.has_method("clear_all"):
		save.clear_all()
	if save and save.has_method("set_flag"):
		save.set_flag("shed_tools_intro", true)
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
		await create_timer(0.8, true, false, true).timeout
		var video: Node = main.get_node_or_null("VideoPanel")
		if video and video.has_method("is_open") and bool(video.call("is_open")) and video.has_method("_close"):
			video.call("_close")
		self.paused = false

	var shed: Node = main.get_node_or_null("ShedUI")
	if shed == null:
		push_error("ShedUI missing")
		quit(1)
		return
	if shed.has_method("open_shed"):
		shed.call("open_shed")
	await create_timer(0.35, true, false, true).timeout
	if shed.has_method("_on_tool_pressed"):
		shed.call("_on_tool_pressed", "seed")
	await create_timer(0.5, true, false, true).timeout

	var out_dir := "res://docs/screenshots/ux"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var path := "%s/shed_seed_catalog.png" % out_dir
	await process_frame
	await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	if img:
		img.save_png(ProjectSettings.globalize_path(path))
		print("SHOT → ", ProjectSettings.globalize_path(path))
	quit(0)

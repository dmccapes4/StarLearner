extends SceneTree
## One-shot south-fence tree framing check.
##   xvfb-run -a godot --path game -s res://tools/shot_south_trees.gd

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.get_viewport().size = Vector2i(1280, 600)
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

	var world: Node = main.get_node_or_null("World")
	var farm: FarmMap = world.get("farm_map") as FarmMap
	var player: Node2D = world.get("player") as Node2D
	farm.apply_season_tint("summer")
	farm._apply_meadow_tree_season("summer")
	await _settle(4)

	var souths: Array = farm._meadow_trees.duplicate()
	souths.sort_custom(func(a, b): return a.global_position.y > b.global_position.y)
	print("tree count ", farm._meadow_trees.size())
	for i in mini(6, souths.size()):
		var s: Sprite2D = souths[i]
		print(" south[%d] %s feet=%s pos=%s" % [
			i, s.get_meta("tree_variant"), s.get_meta("tree_feet_y"), s.global_position])

	var sw := IsoUtil.tile_to_world(Vector2(farm._yard_min.x, farm._yard_max.y))
	var se := IsoUtil.tile_to_world(farm._yard_max)
	var fence_mid: Vector2 = (sw + se) * 0.5
	## Frame fence + south crowns together (not the far meadow).
	var focus := fence_mid + Vector2(-40, 24)
	player.global_position = farm.nearest_walkable(fence_mid + Vector2(0, -30))
	if player.has_method("stop"):
		player.call("stop")
	var cam := world.get_node_or_null("CameraFollow") as Camera2D
	if cam:
		cam.zoom = Vector2(1.35, 1.35)
		cam.global_position = focus
	await _settle(10)

	var game_dir := ProjectSettings.globalize_path("res://").rstrip("/")
	var out := game_dir.get_base_dir().path_join(".cache/tree_preview/south_fence_summer.png")
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	var err := root.get_viewport().get_texture().get_image().save_png(out)
	print("wrote ", out, " err=", err)
	quit(0 if err == OK else 1)

func _settle(n: int) -> void:
	for _i in n:
		await process_frame

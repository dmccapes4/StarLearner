extends SceneTree
## Dev-only: render the card + the addition tutorial to docs/screenshots/.
##   DISPLAY=:0 godot --path . -s res://tools/capture_shots.gd

const AdditionTutorial := preload("res://scripts/AdditionTutorial.gd")
const TrainsScene := preload("res://scripts/TrainsScene.gd")
const EggsScene := preload("res://scripts/EggsScene.gd")
const EggsDragScene := preload("res://scripts/EggsDragScene.gd")
const PracticeScene := preload("res://scripts/PracticeScene.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var dir := "res://docs/screenshots"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))

	# 1) Main card view, once per operation tab.
	var MainScene := load("res://scenes/Main.tscn")
	var m: Node = MainScene.instantiate()
	get_root().add_child(m)
	for i in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(
		ProjectSettings.globalize_path(dir + "/00_card.png"))
	for op in ["sub", "mul", "div"]:
		m._tabs.select(op)
		for i in 5:
			await process_frame
		await _shot(dir + "/00_card_%s.png" % op)
	m.queue_free()
	await process_frame

	# 2) Addition tutorial, mid "count on".
	var bg := ColorRect.new()
	bg.color = MathTheme.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_root().add_child(bg)
	var t: AdditionTutorial = AdditionTutorial.new()
	t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_root().add_child(t)
	t.start(7, 4)
	await create_timer(8.5).timeout   # past red count, into blue/count-on
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(
		ProjectSettings.globalize_path(dir + "/01_tutorial.png"))

	# 3) Final answer frame.
	await create_timer(6.0).timeout
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(
		ProjectSettings.globalize_path(dir + "/02_tutorial_done.png"))

	# 4) Two-trains scene: mid (catch-up) and end (gap).
	await _reset_root()
	var trains: TrainsScene = TrainsScene.new()
	get_root().add_child(trains)
	trains.start(7)
	await create_timer(5.0).timeout
	await _shot(dir + "/03_trains_mid.png")
	await create_timer(5.0).timeout
	await _shot(dir + "/04_trains_done.png")
	trains.queue_free()

	# 5) Eggs scene: laying + equation, then cartons.
	await _reset_root()
	var eggs: EggsScene = EggsScene.new()
	get_root().add_child(eggs)
	eggs.start(0)
	await create_timer(7.0).timeout
	await _shot(dir + "/05_eggs_lay.png")
	await create_timer(9.0).timeout
	await _shot(dir + "/06_eggs_cartons.png")

	# 6) Interactive drag scene: initial layout (chickens + nests + egg pile),
	#    then jump to the packing phase for a second frame.
	await _reset_root()
	var drag: EggsDragScene = EggsDragScene.new()
	get_root().add_child(drag)
	drag.start(0)
	await create_timer(1.0).timeout
	await _shot(dir + "/07_eggs_drag.png")
	drag._start_pack()
	await create_timer(1.0).timeout
	await _shot(dir + "/08_eggs_drag_pack.png")

	# 7) Practice mode: one frame per operation.
	for op in ["add", "sub", "mul", "div"]:
		await _reset_root()
		var pr: PracticeScene = PracticeScene.new()
		get_root().add_child(pr)
		pr.start(op)
		await create_timer(0.8).timeout
		await _shot(dir + "/09_practice_%s.png" % op)
		pr.stop()

	print("captured math shots to ", dir)
	quit()

func _reset_root() -> void:
	for c in get_root().get_children():
		c.queue_free()
	await process_frame
	var bg := ColorRect.new()
	bg.color = MathTheme.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_root().add_child(bg)

func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(ProjectSettings.globalize_path(path))

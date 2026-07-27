extends SceneTree
## Capture representative screens to docs/screenshots/.
##   godot --path game -s res://tools/capture_shots.gd

var _main: Node

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.get_viewport().size = Vector2i(1280, 600)
	var save := root.get_node_or_null("/root/Save")
	if save:
		save.clear_all()
		save.set_intro_done(true)
		for tid in ["tut_read", "tut_books", "tut_write", "tut_alphabet"]:
			save.mark_seen(tid)

	_main = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	await _frames(5)
	await _shot("00_home")

	_main.call("_enter_tutorial", "tut_read")
	await _frames(4)
	await _shot("01_tutorial_read")
	_main._tutorial.stop(true)

	_main.call("_enter_books")
	await _frames(4)
	await _shot("03_books")

	_main.call("_enter_write")
	await _frames(4)
	await _shot("05_write_picker")

	_main._write_practice.call("_begin_word", "en_apple")
	await _frames(8)
	await _shot("06_alphabet_apple")

	print("captured Language Explorer shots")
	quit(0)

func _frames(count: int) -> void:
	for _i in count:
		await process_frame

func _shot(name: String) -> void:
	var dir := "res://docs/screenshots"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	await RenderingServer.frame_post_draw
	var image := root.get_viewport().get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path("%s/%s.png" % [dir, name]))

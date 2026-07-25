extends SceneTree
## Short automated product tour for Godot MovieWriter.

var _main: Node

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.get_viewport().size = Vector2i(1280, 600)
	var save := root.get_node_or_null("/root/Save")
	if save:
		save.clear_all()
		save.set_intro_done(true)

	_main = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	await _sec(1.5)

	_main.call("_enter_tutorial", "tut_read")
	await _sec(2.5)
	_main._tutorial.call("_advance")
	await _sec(2.0)
	_main._tutorial.stop(true)

	_main.call("_enter_read")
	await _sec(2.0)
	_main.call("_enter_books")
	await _sec(2.5)

	_main.call("_enter_write")
	await _sec(2.0)
	_main.call("_enter_write_images")
	await _sec(2.5)
	_main.call("_enter_write")
	await _sec(1.0)
	_main.call("_enter_write_narration")
	await _sec(2.5)

	_main.call("_show_home")
	await _sec(2.0)
	quit(0)

func _sec(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout

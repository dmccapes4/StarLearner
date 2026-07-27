extends SceneTree
## Automated Language Explorer playthrough for MovieWriter.
##
##   DISPLAY=:1 godot --path game --fixed-fps 24 --disable-vsync \
##     --write-movie /tmp/language_playthrough.avi \
##     -s res://tools/record_playthrough_demo.gd
##
## Beats: home → books shelf → write picker → Apple practice → home.

var _main: Node

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.get_viewport().size = Vector2i(1280, 600)
	var save := root.get_node_or_null("/root/Save")
	if save:
		save.clear_all()
		save.set_intro_done(true)
		save.set_letter_input("alphabet")
		for tid in ["tut_read", "tut_books", "tut_write", "tut_alphabet"]:
			save.mark_seen(tid)

	_main = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	await _sec(1.2)
	await _voice_idle()

	print("DEMO: books")
	_main.call("_enter_books")
	await _sec(0.6)
	await _voice_idle()
	await _sec(2.0)

	print("DEMO: write + apple")
	_main.call("_enter_write")
	await _sec(0.6)
	await _voice_idle()
	await _sec(1.0)
	if _main._write_practice.has_method("_begin_word"):
		_main._write_practice.call("_begin_word", "en_apple")
	await _sec(0.8)
	await _voice_idle()
	await _sec(2.5)

	print("DEMO: home")
	_main.call("_show_home")
	await _sec(2.0)
	quit(0)

func _sec(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout

func _voice_idle(max_wait: float = 20.0) -> void:
	var t := 0.0
	while Narrator.blocks_input() and t < max_wait:
		await _sec(0.2)
		t += 0.2

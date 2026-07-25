extends SceneTree
## Automated Language Explorer playthrough for MovieWriter.
##
##   DISPLAY=:1 godot --path game --fixed-fps 24 --disable-vsync \
##     --write-movie /tmp/language_playthrough.avi \
##     -s res://tools/record_playthrough_demo.gd
##
## Beats: home → Read home → books shelf → Write home → Images/Apple alphabet
## → Narration picker → home. Waits out Narrator locks so VO is not clipped.

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
		# Mark tutorials seen so first-entry overlays do not eat the tour.
		for tid in ["tut_read", "tut_sentences", "tut_books", "tut_write", "tut_alphabet", "tut_sketch"]:
			save.mark_seen(tid)

	_main = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	await _sec(1.2)
	await _voice_idle()

	print("DEMO: read home")
	_main.call("_enter_read")
	await _sec(0.6)
	await _voice_idle()
	await _sec(1.4)

	print("DEMO: books")
	_main.call("_enter_books")
	await _sec(0.6)
	await _voice_idle()
	await _sec(2.0)

	print("DEMO: write home")
	_main.call("_enter_write")
	await _sec(0.6)
	await _voice_idle()
	await _sec(1.4)

	print("DEMO: write images + apple")
	_main.call("_enter_write_images")
	await _sec(0.6)
	await _voice_idle()
	await _sec(1.0)
	if _main._write_images.has_method("_begin_word"):
		_main._write_images.call("_begin_word", "en_apple")
	await _sec(0.8)
	await _voice_idle()
	await _sec(2.5)

	print("DEMO: write narration")
	_main.call("_enter_write_narration")
	await _sec(0.6)
	await _voice_idle()
	await _sec(2.2)

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

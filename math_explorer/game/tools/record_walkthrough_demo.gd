extends SceneTree
## Automated walkthrough for README / kiosk demo videos.
##
##   DISPLAY=:1 godot --path game --fixed-fps 24 --disable-vsync \
##     --write-movie /tmp/math_walkthrough.avi \
##     -s res://tools/record_walkthrough_demo.gd
##
## Beats: card + tab tour → Addition tutorial (full) → two-trains story →
## chickens & eggs (animated) → Practice (one right, one wrong with the
## counting explanation) → back to the card.
##
## Baked ElevenLabs VO plays through the audio bus, so Godot embeds it in the
## AVI. (Practice's dynamic equation lines use OS TTS and stay silent here.)

var _main: Node = null

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.get_viewport().size = Vector2i(1280, 600)
	_main = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	await _sec(0.5)

	# 1) Tab tour on the card.
	print("DEMO: tab tour")
	await _sec(2.2)
	for op in ["sub", "mul", "div", "add"]:
		_main._tabs.select(op)
		await _sec(1.6)

	# 2) Addition tutorial, full run.
	print("DEMO: addition tutorial")
	_main._on_play_tutorial()
	await _wait_signal_or(_main._tutorial.finished, 40.0)
	await _sec(2.0)
	_main._show_card()
	await _sec(0.8)

	# 3) Two trains (subtraction story).
	print("DEMO: two trains")
	_main._tabs.select("sub")
	await _sec(1.2)
	_main._on_play_story()
	await _wait_signal_or(_main._trains.finished, 25.0)
	await _sec(2.5)
	_main._show_card()
	await _sec(0.8)

	# 4) Chickens & eggs, animated (multiplication tutorial).
	print("DEMO: chickens and eggs")
	_main._tabs.select("mul")
	await _sec(1.2)
	_main._on_play_tutorial()
	await _wait_signal_or(_main._eggs.finished, 45.0)
	await _sec(2.5)
	_main._show_card()
	await _sec(0.8)

	# 5) Practice: one correct answer, then one wrong (to show the coaching).
	print("DEMO: practice")
	_main._tabs.select("add")
	await _sec(1.2)
	_main._on_play_practice()
	await _sec(3.0)
	_press_practice_answer(true)
	await _sec(3.5)              # celebrate + next round appears
	_press_practice_answer(false)
	await _sec(14.0)             # the slow count-it-together explanation
	_main._show_card()
	await _sec(1.5)

	print("DEMO: done")
	quit()

func _press_practice_answer(correct: bool) -> void:
	var pr: Control = _main._practice
	var answer := str(pr._p["answer"])
	var pick := -1
	for i in 3:
		var is_answer: bool = (pr._buttons[i] as Button).text == answer
		if is_answer == correct:
			pick = i
			break
	if pick >= 0:
		pr._on_answer(pick)

func _wait_signal_or(sig: Signal, timeout: float) -> void:
	var done := [false]
	var cb := func() -> void: done[0] = true
	sig.connect(cb, CONNECT_ONE_SHOT)
	var t := 0.0
	while not done[0] and t < timeout:
		await _sec(0.25)
		t += 0.25

func _sec(s: float) -> void:
	await create_timer(s).timeout

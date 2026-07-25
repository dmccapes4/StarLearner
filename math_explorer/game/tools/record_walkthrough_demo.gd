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
	# Wipe saved state so this recording always plays the launch tour + the
	# first-time tutorials from a clean slate.
	var save := root.get_node_or_null("/root/Save")
	if save != null:
		save.call("clear_all")

	_main = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	await _sec(0.5)

	# 1) Launch intro: gold-highlight tour of every tile + the ☰ menu.
	print("DEMO: intro tour")
	var intro_t := 0.0
	while _main._intro_running and intro_t < 90.0:
		await _sec(0.25)
		intro_t += 0.25
	await _sec(1.0)

	# 2) First tap on Addition → "this is a tutorial…" then the block lesson.
	print("DEMO: addition tutorial")
	_main._tabs.select("add")
	await _sec(3.0)  # first-time VO line
	await _wait_signal_or(_main._tutorial.finished, 45.0)
	await _sec(2.0)
	_main._show_card()
	await _sec(0.8)

	# 3) First tap on Subtraction → same first-time line, then take-away.
	print("DEMO: subtraction tutorial")
	_main._tabs.select("sub")
	await _sec(3.0)
	await _wait_signal_or(_main._block_tut.finished, 45.0)
	await _sec(2.0)
	_main._show_card()
	await _sec(0.8)

	# 4) Practice: correct → Practice ▶ under cubes → wrong with coaching.
	print("DEMO: practice")
	_main._tabs.select("add")
	await _sec(1.2)
	_main._on_primary()
	await _sec(5.0)              # "Let's practice!" then the equation
	_press_practice_answer(true)
	await _sec(3.5)              # praise + Practice ▶ appears
	_main._practice._on_practice_again()
	await _sec(2.5)
	_press_practice_answer(false)
	await _sec(16.0)             # coaching + Practice ▶ again
	_main._show_card()
	await _sec(1.0)

	# 5) Chickens & eggs, animated walkthrough (its own tab now).
	print("DEMO: chickens and eggs")
	_main._tabs.select("eggs")
	await _sec(1.4)
	_main._enter_scene(_main._eggs)
	_main._eggs.start(-1)
	await _wait_signal_or(_main._eggs.finished, 45.0)
	await _sec(2.5)
	_main._show_card()
	await _sec(0.8)

	# 6) Two trains: race, then answer the miles-ahead question.
	print("DEMO: two trains")
	_main._tabs.select("trains")
	await _sec(1.4)
	_main._launch_game("trains")
	await _wait_trains_question(30.0)
	await _sec(1.5)
	_press_trains_answer(true)
	await _wait_signal_or(_main._trains.finished, 12.0)
	await _sec(2.5)
	_main._show_card()
	await _sec(0.8)

	# 7) Coin counter: drop coins to make the target.
	print("DEMO: coins")
	_main._tabs.select("coins")
	await _sec(1.4)
	_main._launch_game("coins")
	await _sec(3.0)
	await _play_coins()
	await _sec(3.0)
	_main._show_card()
	await _sec(1.5)

	print("DEMO: done")
	quit()

func _wait_trains_question(timeout: float) -> void:
	var t := 0.0
	while not _main._trains._answering and t < timeout:
		await _sec(0.25)
		t += 0.25

func _press_trains_answer(correct: bool) -> void:
	var tr: Control = _main._trains
	var answer := "%d mi" % int(tr._p["answer"])
	for i in 3:
		var is_answer: bool = (tr._buttons[i] as Button).text == answer
		if is_answer == correct:
			tr._on_answer(i)
			return

## Move coins into the tray one by one until the total is exact.
func _play_coins() -> void:
	var co: Control = _main._coins
	# Greedy: dimes, then nickels, then pennies.
	for kind in ["dime", "nickel", "penny"]:
		for c in co._coins:
			if co._total >= co._target:
				return
			if c.kind != kind or bool(c.get_meta("in_tray")):
				continue
			if co._total + int(c.value) > co._target:
				continue
			# Simulate the drag: press on the coin, release over the tray.
			co._begin_drag(c.position + c.size * 0.5)
			var target: Vector2 = co._tray.position + Vector2(80 + co._total * 3.0, 80)
			var steps := 10
			for s in steps:
				var p: Vector2 = (c.position + c.size * 0.5).lerp(target, float(s + 1) / steps)
				if co._dragging != null:
					co._dragging.position = p - co._drag_off
				await _sec(0.05)
			co._end_drag(target)
			await _sec(1.2)

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

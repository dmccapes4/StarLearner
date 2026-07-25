extends SceneTree
## Automated Solar System Explorer walkthrough for docs/demo.
##
##   DISPLAY=:1 GODOT_USER_DATA_DIR=/tmp/solar_demo_user \
##   godot --path game --fixed-fps 24 --disable-vsync \
##     --write-movie /tmp/solar_playthrough.avi \
##     -s res://tools/record_playthrough_demo.gd
##
## Beats: title hub → Spaceship → astronaut → scroll → plot Mars → fly →
## orbit → chart again → plot Sun → fly → arrive.

const FPS := 24.0
const MainScript := preload("res://scripts/Main.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.get_viewport().size = Vector2i(1280, 600)
	var main: Node = MainScript.new()
	root.add_child(main)
	await process_frame
	await process_frame
	print("DEMO: title hub")
	await _sec(2.0)

	# Spaceship tile → flight sim (astronaut briefing + strip).
	if main.has_method("_on_flight"):
		main._on_flight()
	print("DEMO: astronaut + scroll")
	await _sec(8.0)

	# Plot Earth → Mars
	print("DEMO: plot Mars")
	if main.has_method("_on_body_selected"):
		main._on_body_selected("mars")
	await _sec(10.0)
	var board = main.get("_board")
	if board != null and board.has_method("_commit"):
		board._commit()
	print("DEMO: fly Mars")
	await _sec(22.0)

	# Chart new course from arrival UI if present, else force scroll.
	var fly = main.get("_fly")
	if fly != null and fly.has_signal("chart_course"):
		fly.emit_signal("chart_course", "mars")
	await _sec(2.0)
	print("DEMO: plot Sun")
	if main.has_method("_on_body_selected"):
		main._on_body_selected("sun")
	await _sec(10.0)
	board = main.get("_board")
	if board != null and board.has_method("_commit"):
		board._commit()
	print("DEMO: fly Sun")
	await _sec(20.0)

	await _sec(3.0)
	print("DEMO: done")
	quit(0)

func _sec(seconds: float) -> void:
	for i in maxi(1, int(ceil(seconds * FPS))):
		await process_frame

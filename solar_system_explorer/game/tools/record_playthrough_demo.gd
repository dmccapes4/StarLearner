extends SceneTree
## Automated Solar System Explorer walkthrough for docs/demo.
##
##   DISPLAY=:1 GODOT_USER_DATA_DIR=/tmp/solar_demo_user \
##   godot --path game --fixed-fps 24 --disable-vsync \
##     --write-movie /tmp/solar_playthrough.avi \
##     -s res://tools/record_playthrough_demo.gd
##
## Beats: boot → title hub → Solar System peek → Spaceship chooser →
## Mission Flight (Jupiter + belt) → Free Flight playground (gears → fly).

const FPS := 24.0
const MainScript := preload("res://scripts/Main.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.get_viewport().size = Vector2i(1280, 600)
	var main: Node = MainScript.new()
	root.add_child(main)
	# Boot orrery welcome (~3s) then title hub.
	await _sec(5.0)

	print("DEMO: title hub")
	await _sec(2.5)

	# Brief Solar System (orrery) peek, then back to the hub.
	if main.has_method("_on_explainer"):
		main._on_explainer()
	print("DEMO: orrery peek")
	await _sec(7.0)
	if main.has_method("_show_title"):
		main._show_title()
	await _sec(1.5)

	# Spaceship → FlightChooser (Mission vs Free Flight).
	if main.has_method("_on_flight"):
		main._on_flight()
	print("DEMO: flight chooser")
	await _sec(3.5)

	# Mission Flight → astronaut briefing → strip.
	if main.has_method("_on_mission_flight"):
		main._on_mission_flight()
	print("DEMO: mission astronaut + scroll")
	await _sec(10.0)

	# Plot Earth → Jupiter (crosses the asteroid belt).
	print("DEMO: plot Jupiter")
	if main.has_method("_on_body_selected"):
		main._on_body_selected("jupiter")
	await _sec(10.0)
	var board = main.get("_board")
	if board != null and board.has_method("_commit"):
		board._commit()
	print("DEMO: fly Jupiter (belt)")
	await _sec(42.0)

	# Free Flight playground — back to hub path via Spaceship → Free Flight.
	if main.has_method("_show_title"):
		main._show_title()
	await _sec(1.2)
	if main.has_method("_on_flight"):
		main._on_flight()
	await _sec(2.0)
	if main.has_method("_on_free_flight"):
		main._on_free_flight()
	print("DEMO: free flight briefing")
	await _sec(10.0)

	var pg = main.get("_playground")
	if pg != null:
		# Speed pick → gears; no-sensor path auto-skips tutorial + aim gate.
		if pg.has_method("_on_speed_gears"):
			pg._on_speed_gears()
		print("DEMO: playground tutorial → fly")
		await _sec(8.0)
		# Ensure flying if gate already skipped; otherwise force launch.
		if pg.get("_state") != null and int(pg._state) != 3:  # State.FLYING
			if pg.has_method("_launch"):
				pg._launch(Vector2.ZERO)
		print("DEMO: playground flying")
		await _sec(14.0)

	await _sec(2.0)
	print("DEMO: done")
	quit(0)

func _sec(seconds: float) -> void:
	for i in maxi(1, int(ceil(seconds * FPS))):
		await process_frame

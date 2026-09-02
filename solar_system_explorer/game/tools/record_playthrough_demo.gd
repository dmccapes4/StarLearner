extends SceneTree
## Automated Solar System Explorer walkthrough for docs/demo.
##
##   DISPLAY=:1 GODOT_USER_DATA_DIR=/tmp/solar_demo_user \
##   godot --path game --fixed-fps 24 --disable-vsync \
##     --write-movie /tmp/solar_playthrough.avi \
##     -s res://tools/record_playthrough_demo.gd
##
## Beats: boot → title hub → Solar System peek → Zodiac peek →
## Spaceship chooser → Mission Flight (Jupiter + belt) →
## Free Flight (turns, speed, Mars seek, constellation shell).

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
	await _sec(6.0)
	if main.has_method("_show_title"):
		main._show_title()
	await _sec(1.2)

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

	# Free Flight playground — hub → Spaceship → Free Flight.
	if main.has_method("_show_title"):
		main._show_title()
	await _sec(1.2)
	if main.has_method("_on_flight"):
		main._on_flight()
	await _sec(2.0)
	if main.has_method("_on_free_flight"):
		main._on_free_flight()
	print("DEMO: free flight briefing")
	await _sec(9.0)

	var pg = main.get("_playground")
	if pg != null:
		# begin() already launches tap flight — do not re-enter speed pick/tutorial.
		print("DEMO: free flight cockpit")
		await _sec(2.0)
		await _cool_free_flight(pg)

	await _sec(1.5)
	print("DEMO: done")
	quit(0)

## Showcase tap-only Free Flight: bank, climb, rush, visit Mars, sky shell.
func _cool_free_flight(pg: Node) -> void:
	# Bank left across the inner system.
	pg.set("_tap_yaw_rate", 0.78)
	pg.set("_tap_pitch_rate", 0.0)
	print("DEMO: free flight bank left")
	await _sec(3.2)

	# Climb while turning — pill-band sightseeing.
	pg.set("_tap_yaw_rate", 0.42)
	pg.set("_tap_pitch_rate", 0.55)
	print("DEMO: free flight climb")
	await _sec(2.4)
	pg.set("_tap_pitch_rate", -0.25)
	await _sec(1.2)
	pg.set("_tap_pitch_rate", 0.0)
	pg.set("_tap_yaw_rate", 0.0)

	# Punch to max gear.
	if pg.has_method("_apply_speed_step"):
		pg._apply_speed_step(5, true)
	print("DEMO: free flight max speed")
	await _sec(2.0)

	# Auto-fly to Mars (tap-to-target).
	if pg.has_method("_begin_seek") and pg.get("_bodies").has("mars"):
		pg._begin_seek("mars")
		print("DEMO: free flight seek Mars")
		# Let seek run — capture or near approach looks great on film.
		for _i in int(FPS * 16.0):
			await process_frame
			if int(pg.get("_state")) == 5:  # ORBITING
				break
		# If we parked, show arrival tiles briefly then resume.
		if int(pg.get("_state")) == 5:
			print("DEMO: free flight Mars arrival")
			await _sec(2.5)
			if pg.has_method("resume_flying"):
				pg.resume_flying()
			await _sec(1.0)
		elif pg.has_method("_cancel_seek"):
			pg._cancel_seek()

	# Outer-shell constellations on — fly toward Leo.
	if pg.has_method("_set_zodiac_sky"):
		pg._set_zodiac_sky(true)
		print("DEMO: free flight constellations on")
		await _sec(1.5)
	if pg.has_method("_begin_const_focus") and pg.get("_signs").has("orion"):
		pg._begin_const_focus("orion")
		print("DEMO: free flight look at Orion")
		await _sec(8.0)
		if pg.has_method("_clear_const_focus"):
			pg._clear_const_focus()

	# Final cruise past the Sun tile heading.
	if pg.has_method("_begin_seek") and pg.get("_bodies").has("sun"):
		pg._begin_seek("sun")
		print("DEMO: free flight toward Sun")
		await _sec(7.0)
		if pg.has_method("_cancel_seek") and int(pg.get("_state")) == 4:
			pg._cancel_seek()

	# Level out and coast — hero end frame.
	pg.set("_tap_yaw_rate", 0.0)
	pg.set("_tap_pitch_rate", 0.0)
	if pg.has_method("_straighten_attitude"):
		pg._straighten_attitude()
	print("DEMO: free flight coast")
	await _sec(3.5)

func _sec(seconds: float) -> void:
	for i in maxi(1, int(ceil(seconds * FPS))):
		await process_frame

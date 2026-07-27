extends SceneTree
## Regression capture for the arrival cinematic AS THE PLAYER SEES IT — playing
## over a live FlyScene (HUD + flight world underneath), not standalone. The
## on-device bug: the cinematic's viewport drew transparent, so "the cinematic"
## was just letterbox bars + a title over the moving flight world.
##   DISPLAY=:1 godot --path . -s res://tools/capture_cine_ingame.gd

const Starfield := preload("res://scripts/Starfield.gd")
const FlyScene := preload("res://scripts/FlyScene.gd")

var _fails := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var dir := "res://docs/screenshots/modes"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var cfg := SolarFlyerConfig.load_default()
	var origin := SolarData.flyer_body_by_id("earth", cfg)
	var dest := SolarData.flyer_body_by_id("neptune", cfg)
	var ship_pos := OrbitMath.park_pos(origin, 0.0, cfg, OrbitMath.body_pos(dest, 0.0))
	var route := OrbitMath.plot_route(ship_pos, dest, 0.0, cfg,
		OrbitMath.orbit_standoff(float(origin.get("hero_r", 2.0))))

	var bg := Starfield.new()
	var fly: FlyScene = FlyScene.new()
	root.add_child(bg)
	root.add_child(fly)
	fly.set_active(true)
	fly.begin_flight("neptune", route, 0.0)
	# Jump to arrival with the cinematic ENABLED — the real player path.
	fly._enter_orbit()
	_check(fly._cine._playing, "cinematic playing on arrival")
	# Mid-dolly beat.
	for i in 90:
		await process_frame
	await _shot(dir + "/cine_ingame_neptune.png")
	# The cinematic viewport must actually be rendering something: sample the
	# center of ITS texture — a see-through/blank viewport reads ~0 alpha or
	# pure black (the flight world behind is NOT part of this texture).
	var tex := fly._cine._viewport.get_texture()
	var img := tex.get_image()
	var c := img.get_pixel(img.get_width() / 2, img.get_height() / 2)
	print("  cine viewport center pixel: ", c)
	_check(c.a > 0.9, "cinematic viewport is opaque at center (a=%.2f)" % c.a)
	_check(c.r + c.g + c.b > 0.15,
		"cinematic viewport shows the planet, not blank space (rgb sum %.2f)" % (
			c.r + c.g + c.b))
	# The BACKGROUND must be dark space — when SubViewports shared the root
	# World3D the cinematic camera filmed the flight world's sun (bright
	# yellow wall) and passing planets instead of its own empty sky.
	var e := img.get_pixel(img.get_width() / 8, img.get_height() / 2)
	print("  cine viewport edge pixel: ", e)
	_check(e.r + e.g + e.b < 0.5,
		"cinematic background is dark space, not another scene (rgb sum %.2f)" % (
			e.r + e.g + e.b))
	# Grace period: a tap right at arrival must NOT skip the cinematic.
	_check(fly._cine._t < OrbitCinematic.DURATION_S, "still inside the cinematic")
	var tap := InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	fly._cine._t = 0.5   # inside the grace window
	fly._cine._input(tap)
	_check(fly._cine._playing, "early tap ignored (grace window)")
	fly._cine._t = OrbitCinematic.SKIP_GRACE_S + 0.1
	fly._cine._input(tap)
	_check(not fly._cine._playing, "tap after grace skips the cinematic")
	fly.queue_free()
	bg.queue_free()
	await process_frame
	print("CINE-INGAME: %s" % ("PASS" if _fails == 0 else "FAIL"))
	quit(0 if _fails == 0 else 1)

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  OK   ", msg)
	else:
		_fails += 1
		print("  FAIL ", msg)

func _shot(res_path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_root().get_texture().get_image()
	var path := ProjectSettings.globalize_path(res_path)
	img.save_png(path)
	print("  wrote ", path)

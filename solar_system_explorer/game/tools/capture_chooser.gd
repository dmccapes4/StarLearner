extends SceneTree
## Screenshot the FlightChooser (Mission Flight / Free Flight tiles) and sanity
## check that both tiles carry their generated art.
##   DISPLAY=:1 godot --path . -s res://tools/capture_chooser.gd

const Starfield := preload("res://scripts/Starfield.gd")
const FlightChooser := preload("res://scripts/FlightChooser.gd")

var _fails := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var dir := "res://docs/screenshots/modes"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var bg := Starfield.new()
	var chooser: FlightChooser = FlightChooser.new()
	root.add_child(bg)
	root.add_child(chooser)
	_check(ResourceLoader.exists(FlightChooser.MISSION_TEX), "mission tile art exists")
	_check(ResourceLoader.exists(FlightChooser.FREE_TEX), "free-flight tile art exists")
	for i in 5:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := get_root().get_texture().get_image()
	var path := ProjectSettings.globalize_path(dir + "/flight_chooser.png")
	img.save_png(path)
	print("wrote ", path)
	quit(0 if _fails == 0 else 1)

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  OK   ", msg)
	else:
		_fails += 1
		print("  FAIL ", msg)

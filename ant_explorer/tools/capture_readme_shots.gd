extends SceneTree
## Boot Main.tscn and save README screenshots under docs/screenshots/.
## Captures the star shelves both OCCLUDED (soil) and REVEALED with a mix of
## collected / still-locked stars, plus a couple of world views.
## Run (needs a display — not --headless):
##   DISPLAY=:1 godot --path game -s res://../tools/capture_readme_shots.gd
## Or copy into game/ and use res://capture_readme_shots.gd

const OUT_DIR := "/home/dylanmccapes/dev/star_learning/ant_explorer/docs/screenshots"

# A believable "some progress" state: a mix on both rails so collected tiles
# show in colour and still-locked ones stay dim.
const COLLECTED := [
	"01_queen", "02_larvae", "04_fungus",
	"07_soldiers", "09_labor", "11_architecture",
]

func _init() -> void:
	call_deferred("_go")

func _go() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	root.get_viewport().size = Vector2i(1280, 600)

	var main: Node = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)

	# Cleaner README frames — hide debug meta.
	var hud := main.get_node_or_null("DebugHUD")
	if hud:
		hud.visible = false

	# Skip the (long) intro narration for capture.
	await _wait_frames(50)
	var intro := get_first_node_in_group("intro_panel")
	if intro != null and intro.has_method("_finish"):
		intro.call("_finish")
	await _wait_frames(45)

	var shell := get_first_node_in_group("landscape_shell")

	# 1) Shelves tucked under the soil (product default look).
	if shell != null:
		shell.call("occlude", false)
	await _wait_frames(20)
	_save("01_rails_soil.png")

	# 2) Shelves revealed with partial progress (colour vs dim tiles).
	# Reach Save via node path — as an external `-s` script this parses before
	# autoloads register as global identifiers.
	var save := root.get_node_or_null("/root/Save")
	if save != null:
		save.set("stars_collected", PackedStringArray(COLLECTED))
	if shell != null:
		shell.call("refresh")
		shell.call("begin_intro_hold")  # reveal + hold open (no auto re-occlude)
	await _wait_frames(30)
	_save("02_rails_revealed.png")

	# 3) + 4) World context with the shelves still revealed.
	var world := get_first_node_in_group("world")
	if world != null:
		_look_at(world, Vector2(-1550, -1250), 0.55)  # garden_a
		await _wait_frames(25)
		_save("03_garden.png")

		_look_at(world, Vector2(-400, -3500), 0.48)  # outdoor surface
		await _wait_frames(25)
		_save("04_surface.png")

	# 5) Colony-wide overview: hide the rail UI (it's chrome, not colony) and
	# frame the whole nest, then trim the empty world-background sides.
	if shell != null:
		var chrome := shell.get_node_or_null("Root")
		if chrome != null:
			chrome.visible = false
	if world != null:
		_look_at(world, Vector2(-200, -900), 0.11)  # whole nest
		await _wait_frames(30)
		_save_cropped("05_nest_overview.png")

	print("SHOTS_SAVED ", OUT_DIR)
	quit(0)

func _look_at(world: Node, pos: Vector2, zoom: float) -> void:
	var cam: Camera2D = world.get("camera") as Camera2D
	if cam == null:
		return
	var anchor := Node2D.new()
	anchor.position = pos
	world.add_child(anchor)
	if cam.has_method("set_follow_target"):
		cam.call("set_follow_target", anchor)
	if cam.has_method("snap_to_target"):
		cam.call("snap_to_target")
	else:
		cam.global_position = pos
	cam.zoom = Vector2(zoom, zoom)

func _wait_frames(n: int) -> void:
	for _i in n:
		await process_frame

func _save(name: String) -> void:
	var path := OUT_DIR.path_join(name)
	var img := root.get_viewport().get_texture().get_image()
	var err := img.save_png(path)
	print("saved ", path, " err=", err, " size=", img.get_width(), "x", img.get_height())

## Save, trimming any uniform border (the empty world-background "sides" around a
## zoomed-out overview) down to the actual content bounds.
func _save_cropped(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	var w := img.get_width()
	var h := img.get_height()
	var bg := img.get_pixel(4, 4)  # a corner = empty background
	var minx := w
	var miny := h
	var maxx := 0
	var maxy := 0
	var step := 2
	for y in range(0, h, step):
		for x in range(0, w, step):
			var c := img.get_pixel(x, y)
			var d := absf(c.r - bg.r) + absf(c.g - bg.g) + absf(c.b - bg.b)
			if d > 0.12:
				minx = mini(minx, x)
				maxx = maxi(maxx, x)
				miny = mini(miny, y)
				maxy = maxi(maxy, y)
	if maxx <= minx or maxy <= miny:
		_save(name)
		return
	var pad := 14
	minx = maxi(0, minx - pad)
	miny = maxi(0, miny - pad)
	maxx = mini(w - 1, maxx + pad)
	maxy = mini(h - 1, maxy + pad)
	var region := img.get_region(Rect2i(minx, miny, maxx - minx + 1, maxy - miny + 1))
	var path := OUT_DIR.path_join(name)
	var err := region.save_png(path)
	print("saved(crop) ", path, " err=", err, " size=", region.get_width(), "x", region.get_height())

extends SceneTree
## Dev-only: render the three main views to docs/screenshots/ for the README and
## for visual verification. Needs a real display (DISPLAY set), not --headless.
##   DISPLAY=:1 godot --path . -s res://tools/capture_preview_shots.gd

const Starfield := preload("res://scripts/Starfield.gd")
const TitleView := preload("res://scripts/TitleView.gd")
const OrreryView := preload("res://scripts/OrreryView.gd")
const ScrollView := preload("res://scripts/ScrollView.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var dir := "res://docs/screenshots"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))

	# Coming-soon teaser (the first thing on launch), mid fade-in.
	var ComingSoon := load("res://scripts/ComingSoon.gd")
	var cbg := Starfield.new()
	var coming = ComingSoon.new()
	root.add_child(cbg)
	root.add_child(coming)
	coming.begin()
	for i in 30:
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(
		ProjectSettings.globalize_path(dir + "/00_coming_soon.png"))
	coming.queue_free()
	cbg.queue_free()
	await process_frame

	await _shot_view(TitleView.new(), dir + "/01_title.png", 2)

	var orrery: OrreryView = OrreryView.new()
	await _shot_view(orrery, dir + "/02_orrery.png", 2, func() -> void:
		orrery.get_child(0).running = true
		orrery.get_child(0).t = 3.2
		orrery.get_child(0).set_highlight("asteroid_belt"))

	# Astronaut briefing overlay (over the scroll view, mid fade-in).
	var AstronautIntro := load("res://scripts/AstronautIntro.gd")
	var bg0 := Starfield.new()
	var behind: ScrollView = ScrollView.new()
	var astro = AstronautIntro.new()
	root.add_child(bg0)
	root.add_child(behind)
	root.add_child(astro)
	behind.begin_exploration()
	astro.begin()
	for i in 30:
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(
		ProjectSettings.globalize_path(dir + "/03_astronaut.png"))
	astro.queue_free()
	behind.queue_free()
	bg0.queue_free()
	await process_frame

	var scroll: ScrollView = ScrollView.new()
	await _shot_view(scroll, dir + "/04_scroll.png", 8, func() -> void:
		scroll.begin_exploration())

	# Ship mid-flight (exercises the fly-to tween: motion, tilt, facing).
	var bg2 := Starfield.new()
	var fly: ScrollView = ScrollView.new()
	root.add_child(bg2)
	root.add_child(fly)
	fly.set_active(true)
	fly.begin_exploration()
	for i in 6:
		await process_frame
	fly._on_body_tapped(6)  # Earth → Jupiter: a longer glide, mid-tilt
	for i in 22:
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(
		ProjectSettings.globalize_path(dir + "/04b_flight.png"))
	fly.queue_free()
	bg2.queue_free()
	await process_frame

	# Video panel playing a real clip (asteroid belt) from res://videos/.
	var VideoPanel := load("res://scripts/VideoPanel.gd")
	var vp = VideoPanel.new()
	var bg := Starfield.new()
	root.add_child(bg)
	root.add_child(vp)
	await process_frame
	vp.play_body("asteroid_belt")
	for i in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(
		ProjectSettings.globalize_path(dir + "/05_video.png"))
	vp.queue_free()
	bg.queue_free()

	print("captured preview shots to ", dir)
	quit()

func _shot_view(view: Node, path: String, frames: int, prep: Callable = Callable()) -> void:
	var bg := Starfield.new()
	root.add_child(bg)
	root.add_child(view)
	if view.has_method("set_active"):
		view.set_active(true)
	if prep.is_valid():
		prep.call()
	for i in frames:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := get_root().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(path))
	view.queue_free()
	bg.queue_free()
	await process_frame

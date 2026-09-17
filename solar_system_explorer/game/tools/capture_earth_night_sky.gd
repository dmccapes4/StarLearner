extends SceneTree
## Render EarthNightSkyScene (Mars Rx chart) to a PNG.
##   DISPLAY=:1 godot --path . -s res://tools/capture_earth_night_sky.gd

const EarthNightSkyScene := preload("res://scripts/EarthNightSkyScene.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var dir := "res://docs/screenshots"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var out := ProjectSettings.globalize_path(dir + "/earth_night_sky_mars_rx.png")

	var sky: EarthNightSkyScene = EarthNightSkyScene.new()
	root.add_child(sky)
	# Skip VO so capture finishes quickly.
	sky.begin()
	sky._vo_gen += 1
	Narrator.stop()
	# Mars at eastern station (terminus before Rx) — coincides with Moon.
	sky._mars_u = 0.0
	sky._mars_dir = 1.0

	for i in 12:
		await process_frame
	if sky._chart != null:
		sky._chart.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw

	var img: Image = get_root().get_texture().get_image()
	img.save_png(out)
	print("captured ", out)
	quit()

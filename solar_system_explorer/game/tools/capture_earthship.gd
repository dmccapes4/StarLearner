extends SceneTree
## Render the EarthShip screens to PNGs so the sky can be eyeballed without a
## phone in hand. Needs a real GPU context -- the SubViewport draws nothing
## headless -- so run it against an X display:
##
##   DISPLAY=:1 godot --path . -s res://tools/capture_earthship.gd
##
## Writes docs/screenshots/earthship_*.png.

const FlightChooserScript := preload("res://scripts/FlightChooser.gd")
const EarthShipScript := preload("res://scripts/EarthShipScene.gd")
const SkyViewerScript := preload("res://scripts/EarthSkyViewer.gd")
const ExposureScript := preload("res://scripts/Exposure.gd")

const OUT_DIR := "res://docs/screenshots"

## Each shot: file suffix, body, mode, latitude, year.
const SHOTS: Array = [
	["venus_38n", "venus", SkyViewerScript.Mode.RETROGRADE, 38.0, 2026],
	["venus_23s", "venus", SkyViewerScript.Mode.RETROGRADE, -23.5, 2026],
	["mercury_38n", "mercury", SkyViewerScript.Mode.RETROGRADE, 38.0, 2026],
	# Mars's 2024-25 loop, the one that arcs between Pollux and the Beehive.
	["mars_38n", "mars", SkyViewerScript.Mode.RETROGRADE, 38.0, 2024],
	["mars_23s", "mars", SkyViewerScript.Mode.RETROGRADE, -23.5, 2024],
	["jupiter_23n", "jupiter", SkyViewerScript.Mode.RETROGRADE, 23.5, 2026],
	["moon_equator", "moon", SkyViewerScript.Mode.ECLIPSE, 0.0, 2026],
	["sun_equator", "sun", SkyViewerScript.Mode.ECLIPSE, 0.0, 2026],
]

## Latitudes for the inversion pair, shot at the same instant.
const INVERSION_YEAR := 2026

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	# Narration would only stall the capture.
	Narrator.stop()

	await _shoot_chooser()
	await _shoot_hub()
	for s in SHOTS:
		await _shoot_sky(str(s[0]), str(s[1]), int(s[2]), float(s[3]), int(s[4]))
	quit()

func _shoot_chooser() -> void:
	var c = FlightChooserScript.new()
	root.add_child(c)
	c.visible = true
	await _settle(10)
	await _save("chooser")
	c.queue_free()
	await process_frame

func _shoot_hub() -> void:
	var hub = EarthShipScript.new()
	root.add_child(hub)
	hub.begin()
	await _settle(10)
	await _save("hub")
	hub.queue_free()
	await process_frame

## One sky shot, then a second one after the clock has run far enough for the
## exposure tail to have swept a good arc, so the trail is actually visible in
## the still.
func _shoot_sky(suffix: String, body: String, mode: int, lat: float,
		year: int) -> void:
	var v = SkyViewerScript.new()
	root.add_child(v)
	v.begin(body, mode, lat, year)
	v.set_paused(true)
	await _settle(16)
	await _save("sky_" + suffix)
	# Advance a third of a buffer and shoot again -- different point in the
	# loop, and it proves the tail redraws correctly after a clock jump.
	v._jd += ExposureScript.schedule_days(body) / 3.0
	v._refresh()
	await _settle(10)
	await _save("sky_" + suffix + "_later")
	# Eclipse mode has a zoom; shoot the close field too, since that is where
	# the terminator is actually legible.
	# Retrograde shots get a daylight-set-aside frame, since the inner planets
	# loop in a bright sky and that is the whole reason the toggle exists.
	if mode == SkyViewerScript.Mode.RETROGRADE:
		v.set_force_dark(true)
		await _settle(10)
		await _save("sky_" + suffix + "_darksky")
		v.set_force_dark(false)
		await _settle(4)
	if mode == SkyViewerScript.Mode.ECLIPSE:
		v.set_zoomed(true)
		await _settle(10)
		await _save("sky_" + suffix + "_zoom")
	v.queue_free()
	await process_frame

func _settle(frames: int) -> void:
	for i in frames:
		await process_frame

func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_root().get_texture().get_image()
	var out := ProjectSettings.globalize_path(
		"%s/earthship_%s.png" % [OUT_DIR, name])
	img.save_png(out)
	print("captured ", out)

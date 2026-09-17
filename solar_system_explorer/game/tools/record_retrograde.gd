extends SceneTree
## Records a retrograde loop as a PNG frame sequence for encoding to video.
##
## Needs a real GPU context, like capture_earthship.gd:
##
##   DISPLAY=:1 godot --path . -s res://tools/record_retrograde.gd
##
## Writes docs/video/<name>/frame_#####.png. Encode with tools/encode_video.sh.
##
## The clock is driven frame by frame rather than by the game loop, so the output
## is deterministic and one frame is exactly one step of simulated time no matter
## how long the render takes.

const SkyViewerScript := preload("res://scripts/EarthSkyViewer.gd")
const EphemerisScript := preload("res://scripts/Ephemeris.gd")
const ExposureScript := preload("res://scripts/Exposure.gd")

const OUT_ROOT := "res://docs/video"

## Mars's 2024-25 loop over Cancer, found by tools/find_cancer_loop.gd: it passes
## 2.4 degrees from Pollux and 2.2 from the Beehive, arcing between them almost
## exactly. Latitude 38 N is Napa, which is where the constellation notes are
## written from.
const NAME := "mars_cancer_2024"
const BODY := "mars"
const LAT := 38.0
## Year to find the loop in. The recorded span is derived from the loop's own
## stations rather than fixed, so the video always covers the whole reversal.
const YEAR := 2024
## Days of direct motion to show either side of the stations. The reversal means
## nothing without normal motion on both sides of it, and this is about as much as
## fits: the field is fitted to the exposure buffer, and Mars covers roughly half a
## degree a day outside the loop.
const PAD_DAYS := 10.0
const FPS := 30
## Simulated days per frame, giving about 11 seconds for a Mars loop -- slow enough
## to watch it stop, back up, and stop again.
const DAYS_PER_FRAME := 0.3

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var dir: String = "%s/%s" % [OUT_ROOT, NAME]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	Narrator.stop()

	var v = SkyViewerScript.new()
	root.add_child(v)
	v.begin(BODY, SkyViewerScript.Mode.RETROGRADE, LAT, YEAR)
	# The clock is stepped by hand, so the game loop must not also advance it.
	v.set_paused(true)

	var window: Dictionary = EphemerisScript.retrograde_window(
		BODY, EphemerisScript.jd_at_year_start(YEAR))
	var jd_from: float = float(window["start"]) - PAD_DAYS
	var jd_to: float = float(window["end"]) + PAD_DAYS
	# Park the clock at the end of the span first, so the exposure buffer holds the
	# entire loop when the field is locked to its centre. Locking from the opening
	# frame would aim at a buffer that has not reached the loop yet.
	v._jd = jd_to
	v._refresh()
	# Without this the camera follows Mars and Mars never appears to move.
	v.set_field_lock(true)
	# The year picker sits exactly where the Beehive lands.
	v.set_chrome_visible(false)
	print("  stations %s -> %s" % [
		EphemerisScript.date_label(float(window["start"])),
		EphemerisScript.date_label(float(window["end"]))])
	print("  field %.1f deg on a loop %.1f x %.1f deg" % [v.field_of_view(),
		float(v.loop_geometry()["length"]), float(v.loop_geometry()["width"])])

	var frames: int = int((jd_to - jd_from) / DAYS_PER_FRAME)
	print("recording %s: %s -> %s, %d frames at %d fps (%.1f s)" % [
		NAME, EphemerisScript.date_label(jd_from),
		EphemerisScript.date_label(jd_to), frames, FPS,
		float(frames) / float(FPS)])
	print("  exposure buffer %.0f days" % ExposureScript.schedule_days(BODY))

	# Let the first frame settle before anything is saved, or the opening frames
	# catch a half-built sky.
	v._jd = jd_from
	v._refresh()
	await _settle(16)

	for i in frames:
		v._jd = jd_from + float(i) * DAYS_PER_FRAME
		v._refresh()
		await RenderingServer.frame_post_draw
		var img: Image = get_root().get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path(
			"%s/frame_%05d.png" % [dir, i]))
		if i % 60 == 0:
			print("  frame %4d/%d  %s" % [i, frames,
				EphemerisScript.date_label(v._jd)])
	print("done: %d frames in %s" % [frames, dir])
	quit()

func _settle(frames: int) -> void:
	for _i in frames:
		await process_frame

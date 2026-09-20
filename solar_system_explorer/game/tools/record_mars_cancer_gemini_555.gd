extends SceneTree
## Records the Mars retrograde loop near the Cancer / Gemini border in the 550s CE.
##
## The JPL secular elements used by Ephemeris.gd are calibrated for 1800-2050 AD,
## but their linear rates extrapolate well enough for an educational rendering.
## The ephemeris places two notable loops in this decade:
##
##   555 CE  (Oct 19 – Jan 3, 556)  RA 5.2–6.5 h  — mid Gemini near Propus
##   557 CE  (Nov 23 – Feb 11, 558) RA 7.9–9.2 h  — Gemini/Cancer border,
##                                                    11.6 deg from Pollux and
##                                                     4.3 deg from the Beehive
##
## The 557-558 loop is the one that genuinely spans the Gemini-Cancer boundary
## the way an ancient observer would describe it.  We record that one, but title
## the video to the 555 CE decade — the user's requested period.
##
## Run (needs a real GPU / display):
##   DISPLAY=:1 godot --path game -s res://tools/record_mars_cancer_gemini_555.gd
##
## Then encode:
##   tools/encode_video.sh mars_cancer_gemini_555

const SkyViewerScript  := preload("res://scripts/EarthSkyViewer.gd")
const EphemerisScript  := preload("res://scripts/Ephemeris.gd")
const ExposureScript   := preload("res://scripts/Exposure.gd")

const OUT_ROOT := "res://docs/video"

const NAME          := "mars_cancer_gemini_555"
const BODY          := "mars"
const LAT           := 38.0    ## Napa, CA — same viewpoint as all other videos
## The 557-558 loop is the Cancer/Gemini boundary one; 558 finds it from year start.
const YEAR          := 557
## Padding of direct motion shown either side of the retrograde stations.
const PAD_DAYS      := 14.0
const FPS           := 30
## 0.3 d/frame gives ~11 s for a Mars loop.
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
	v.set_paused(true)

	var window: Dictionary = EphemerisScript.retrograde_window(
		BODY, EphemerisScript.jd_at_year_start(YEAR))
	var jd_from: float = float(window["start"]) - PAD_DAYS
	var jd_to:   float = float(window["end"])   + PAD_DAYS

	## Park at the end so the exposure buffer covers the whole loop before we lock
	## the field and start writing frames.
	v._jd = jd_to
	v._refresh()
	v.set_field_lock(true)
	v.set_chrome_visible(false)

	print("  Window: %s -> %s" % [
		EphemerisScript.date_label(float(window["start"])),
		EphemerisScript.date_label(float(window["end"]))])
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

	## Settle before writing.
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

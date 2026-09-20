extends SceneTree
## Records the Mars retrograde loop near the Cancer / Gemini border in the 550s CE.
##
## This is the "crab and twins" apparition — Mars arcs through southern Gemini
## into Cancer, 4.3° from the Beehive (M44) at its closest and 11.6° from Pollux.
## The exposure window is wide so the full in-bound and out-bound arcs are visible.
##
## Three improvements over v1:
##   1. set_links_always_dim(true) — Cancer and Gemini stick figures drawn at all
##      times, brightening when Mars is near them.
##   2. _lock_up overridden to ecliptic north (Vector3.UP in this scene's Godot
##      space) — the ecliptic runs horizontally across the middle of the frame
##      rather than at the tilt of the observer's local horizon.
##   3. tail_alpha_exponent = 0.60 + PAD_DAYS = 45 — the tail stays visible and
##      bright across the full 170-day window instead of fading fast.
##
## Run:
##   DISPLAY=:1 godot --path game -s res://tools/record_mars_cancer_gemini_555.gd
## Encode:
##   tools/encode_video.sh mars_cancer_gemini_555 30

const SkyViewerScript := preload("res://scripts/EarthSkyViewer.gd")
const EphemerisScript := preload("res://scripts/Ephemeris.gd")
const ExposureScript  := preload("res://scripts/Exposure.gd")

const OUT_ROOT := "res://docs/video"

const NAME          := "mars_cancer_gemini_555"
const BODY          := "mars"
const LAT           := 38.0        ## Napa, CA — same viewpoint as all other videos
const YEAR          := 557         ## The 557-558 loop is the Cancer/Gemini border one
const PAD_DAYS      := 45.0        ## Days of direct motion shown either side of stations
const FPS           := 30
const DAYS_PER_FRAME := 0.3        ## ~19 s for the full 170-day window

## Ecliptic north pole in this scene's Godot space.
## godot_dir_from_ecliptic(Vector3(0,0,1)) = Vector3(0,1,0) = Vector3.UP.
## Using this as the camera's up makes the ecliptic run horizontally.
const ECLIPTIC_NORTH := Vector3(0.0, 1.0, 0.0)

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

	## ── Fix 1: constellation lines always visible ──────────────────
	## v._sky is the ConstellationView backing the star sphere.  Calling
	## set_links_always_dim(true) keeps every stick figure at dim gold and
	## automatically brightens whichever one Mars is nearest to.
	v._sky.set_links_always_dim(true)

	## ── Fix 3a: slower tail fade ───────────────────────────────────
	v.tail_alpha_exponent = 0.60

	var window: Dictionary = EphemerisScript.retrograde_window(
		BODY, EphemerisScript.jd_at_year_start(YEAR))
	var jd_from: float = float(window["start"]) - PAD_DAYS
	var jd_to:   float = float(window["end"])   + PAD_DAYS

	## Park at jd_to so the exposure buffer covers the whole loop before we lock
	## the field.  This is the same technique as record_retrograde.gd.
	v._jd = jd_to
	v._refresh()
	v.set_field_lock(true)
	v.set_chrome_visible(false)

	## ── Fix 2: ecliptic-level camera ──────────────────────────────
	## _aim_camera() reads _lock_up BEFORE _draw_tail() writes it, so setting
	## _lock_up here (and again before every _refresh in the loop) keeps the
	## ecliptic horizontal for every frame.
	v._lock_up = ECLIPTIC_NORTH

	print("  Window: %s -> %s" % [
		EphemerisScript.date_label(float(window["start"])),
		EphemerisScript.date_label(float(window["end"]))])
	print("  field %.1f deg on a loop %.1f x %.1f deg" % [v.field_of_view(),
		float(v.loop_geometry()["length"]), float(v.loop_geometry()["width"])])

	var frames: int = int((jd_to - jd_from) / DAYS_PER_FRAME)
	print("recording %s: %s -> %s, %d frames at %d fps (%.1f s)" % [
		NAME, EphemerisScript.date_label(jd_from),
		EphemerisScript.date_label(jd_to), frames, FPS,
		float(frames) / float(FPS)])
	print("  exposure buffer %.0f days  (alpha exponent %.2f)" % [
		ExposureScript.schedule_days(BODY), v.tail_alpha_exponent])

	## Settle before writing.
	v._jd = jd_from
	v._lock_up = ECLIPTIC_NORTH
	v._refresh()
	await _settle(16)

	for i in frames:
		v._jd = jd_from + float(i) * DAYS_PER_FRAME
		## Override before _refresh so _aim_camera sees ecliptic north as up.
		v._lock_up = ECLIPTIC_NORTH
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

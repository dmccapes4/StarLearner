extends SceneTree
## Records the Mars retrograde loop (557 CE model year).
## Post-processed by narrate_555.sh which applies hflip + labels + narration.
##
## Run:
##   DISPLAY=:1 godot --path game -s res://tools/record_mars_cancer_gemini_555.gd
## Then:
##   bash game/tools/narrate_555.sh

const SkyViewerScript := preload("res://scripts/EarthSkyViewer.gd")
const EphemerisScript := preload("res://scripts/Ephemeris.gd")

const OUT_ROOT := "res://docs/video"
const NAME          := "mars_cancer_gemini_555"
const BODY          := "mars"
const LAT           := 38.0
const YEAR          := 557
const PAD_DAYS      := 45.0
const FPS           := 30
const DAYS_PER_FRAME := 0.10   ## 0.10 d/frame → ~57 s · slow enough for narration

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

	## ── 1. Constellation lines always on ──────────────────────────────
	v._sky.set_links_always_dim(true)

	## ── 2. Long tail ──────────────────────────────────────────────────
	v.tail_alpha_exponent = 0.60

	## ── 3. Hide all game HUD text ─────────────────────────────────────
	## narrate_555.sh will add clean labels and narration via ffmpeg.
	v.set_chrome_visible(false)
	for lbl_field in ["_title_lbl", "_date_lbl", "_badge_lbl", "_mag_lbl",
					   "_const_lbl", "_sky_lbl", "_note_lbl", "_strip_lbl",
					   "_year_lbl"]:
		var lbl: Node = v.get(lbl_field)
		if lbl != null:
			lbl.visible = false
	## Hide 3-D constellation name labels — they come out mirrored after
	## hflip.  narrate_555.sh overlays clean constellation names.
	v._sky._labels_wanted = false

	## ── 4. Celestial north up ─────────────────────────────────────────
	var window: Dictionary = EphemerisScript.retrograde_window(
		BODY, EphemerisScript.jd_at_year_start(YEAR))
	var jd_from: float = float(window["start"]) - PAD_DAYS
	var jd_to:   float = float(window["end"])   + PAD_DAYS
	var jd_mid: float  = (float(window["start"]) + float(window["end"])) / 2.0
	var t_cy: float = EphemerisScript.centuries_since_j2000(jd_mid)
	var eps: float  = deg_to_rad(EphemerisScript.obliquity_deg(t_cy))
	var cel_north   := Vector3(-sin(eps), cos(eps), 0.0)

	## ── 5. Wide field centred on Castor–Pollux–Beehive corridor ───────
	## Center RA 8.2h, Dec +22°: western station (7.85h) is just right of
	## Pollux (7.76h), eastern station (9.19h) is past the Beehive (8.67h).
	## This framing shows the arc spanning from near Pollux to past the Beehive.
	var view_ra_h := 8.2
	var view_dec  := 22.0
	var alpha     := deg_to_rad(view_ra_h * 15.0)
	var delta_r   := deg_to_rad(view_dec)
	var eq_dir    := Vector3(cos(delta_r)*cos(alpha), cos(delta_r)*sin(alpha), sin(delta_r))
	var ecl_dir   := EphemerisScript.equatorial_to_ecliptic(eq_dir, t_cy)
	const WIDE_FOV := 45.0

	v._jd = jd_to
	v._refresh()
	v.set_field_lock(true)
	v._lock_up  = cel_north
	v._lock_dir = EphemerisScript.godot_dir_from_ecliptic(ecl_dir)
	v._loop_fov = WIDE_FOV
	v._cam.fov  = WIDE_FOV
	v._sky.set_view(SkyViewerScript.VIEW_H, WIDE_FOV)

	var rd_mid := EphemerisScript.ra_dec(BODY, jd_mid)
	var frames: int = int((jd_to - jd_from) / DAYS_PER_FRAME)
	print("field RA %.2fh Dec %.1f° FOV %.0f°" % [view_ra_h, view_dec, WIDE_FOV])
	print("loop %s -> %s  midpoint RA=%.2fh Dec=%.1f°" % [
		EphemerisScript.date_label(float(window["start"])),
		EphemerisScript.date_label(float(window["end"])),
		rd_mid.x, rd_mid.y])
	print("recording %d frames (%s -> %s)  %.1f s" % [
		frames, EphemerisScript.date_label(jd_from),
		EphemerisScript.date_label(jd_to), float(frames)/float(FPS)])

	v._jd = jd_from
	v._lock_up  = cel_north
	v._refresh()
	await _settle(16)

	for i in frames:
		v._jd = jd_from + float(i) * DAYS_PER_FRAME
		v._lock_dir = EphemerisScript.godot_dir_from_ecliptic(ecl_dir)
		v._lock_up  = cel_north
		v._loop_fov = WIDE_FOV
		v._cam.fov  = WIDE_FOV
		v._sky.set_view(SkyViewerScript.VIEW_H, WIDE_FOV)
		v._refresh()
		## Force Cancer and Gemini to full-bright every frame so both are
		## clearly visible throughout — not just the one Mars is nearest.
		for cid in ["gemini", "cancer"]:
			var entry: Dictionary = v._sky._entries.get(cid, {})
			if not entry.is_empty():
				v._sky._set_link_look(entry["links"] as Node3D, true)
		await RenderingServer.frame_post_draw
		var img: Image = get_root().get_texture().get_image()
		## No flip here — narrate_555.sh applies hflip with ffmpeg so the
		## text labels added in post are readable.
		img.save_png(ProjectSettings.globalize_path(
			"%s/frame_%05d.png" % [dir, i]))
		if i % 100 == 0:
			print("  frame %4d/%d  %s" % [i, frames,
				EphemerisScript.date_label(v._jd)])
	print("done: %d frames" % frames)
	quit()

func _settle(n: int) -> void:
	for _i in n:
		await process_frame

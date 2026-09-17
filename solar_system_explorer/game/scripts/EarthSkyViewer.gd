class_name EarthSkyViewer
extends Control
## The sky engine behind RetrogradeViewer and EclipseViewer.
##
## A cockpit camera that sits on Earth at a chosen latitude and looks at one
## naked-eye body while months or years of simulated time run past. Everything
## it draws is computed from Ephemeris; nothing is a canned animation.
##
## HOW IT IS PUT TOGETHER
##
## The camera never moves -- it sits at the origin and only turns. Bodies are
## placed on a shell of fixed radius around it along their TRUE topocentric
## direction, and scaled to their TRUE angular size. This is the same trick
## FlyScene uses for its honest SIM_VIEW render mode, and it is what makes the
## picture correct: a shell placed at a made-up distance still gives the right
## bearing and the right subtended angle, which together are all the eye gets.
##
## Two consequences worth stating plainly:
##
##   - Planets are genuinely sub-pixel. Jupiter at opposition is 47 arcseconds
##     across, about a fiftieth of a degree. So what you actually see, and what
##     is drawn, is the SolarBrilliance glow -- scattered light in air and eye.
##     The disc mesh only appears once a body's true angular size is worth more
##     than a couple of pixels, which in practice means the Sun and the Moon.
##   - To make the Moon's phase readable, EclipseViewer narrows the field of
##     view rather than inflating the Moon. Zooming is honest; resizing is not.
##
## The exposure tail is COMPUTED, not accumulated: because the ephemeris is
## closed-form, the trail can be evaluated for any past instant directly. It is
## therefore correct on the very first frame and survives jumping the clock, so
## picking a new year never shows a half-grown trail.

const EphemerisScript := preload("res://scripts/Ephemeris.gd")
const ExposureScript := preload("res://scripts/Exposure.gd")
const BrillianceScript := preload("res://scripts/SolarBrilliance.gd")
const ConstellationViewScript := preload("res://scripts/ConstellationView.gd")
const PlanetSkinsScript := preload("res://scripts/PlanetSkins.gd")
const PointGlowScript := preload("res://scripts/PointGlow.gd")
const LunarCycleStripScript := preload("res://scripts/LunarCycleStrip.gd")

signal closed()

enum Mode {
	## RetrogradeViewer: a planet, a wide field, a retrograde-period exposure.
	RETROGRADE,
	## EclipseViewer: Sun or Moon, a narrow field, a lunar-cycle exposure.
	ECLIPSE,
}

const VIEW_W := 1280
const VIEW_H := 600

## Star sphere radius. Matches ConstellationData's default so the catalogue's
## absolute star sizes stay correctly scaled.
const SKY_R := 2800.0
## Bodies sit well inside the stars so they always draw in front of them.
const BODY_SHELL_R := 1500.0
## Exposure-tail samples sit just behind the live body, so the head of the tail
## never covers the planet itself.
const TAIL_SHELL_R := 1560.0

## Fallback field for RetrogradeViewer, used until the tail has been measured.
## The real field is fitted to the loop -- see `_fit_loop_fov`.
const FOV_RETROGRADE := 38.0
## Fitted fields are clamped to this range: wide enough that a fast inner-planet
## sweep still has stars around it for context, narrow enough that a slow outer
## planet's short arc is not a speck.
const FOV_LOOP_MIN := 9.0
const FOV_LOOP_MAX := 38.0
## How much sky to leave around the loop when fitting. Slightly over 1.5 keeps
## the whole track clear of the HUD strips at top and bottom.
const FOV_LOOP_MARGIN := 1.7
## The retrograde zoom button drops to this fraction of the fitted field. It
## exists because loop WIDTH and loop LENGTH differ by more than an order of
## magnitude: Jupiter's 2026 loop is 10 degrees long and 0.3 degrees wide, so the
## field that shows the whole track cannot also resolve the two legs crossing.
## Zooming trades one for the other instead of faking either.
const FOV_LOOP_ZOOM := 0.45
## EclipseViewer's default field. Wide enough that the Sun and Moon are both in
## frame whenever they are within 9 degrees of each other -- which is to say,
## through every solar eclipse and the days either side of new moon -- and still
## narrow enough that the Moon is 17 px across and its phase is plainly legible.
const FOV_ECLIPSE := 18.0
## What the zoom button drops to: the Moon nearly fills the frame, for looking at
## the terminator itself. Zooming is honest where inflating the Moon would not
## be, which is why the phase is read this way and not by resizing anything.
const FOV_ECLIPSE_CLOSE := 4.2
## A body's disc mesh is only drawn once it is at least this wide on screen.
## Below it the glow alone is a truer picture of what the eye receives.
const DISC_MIN_PX := 2.2
## Minimum reach of a resolved body's glare, as a multiple of its own diameter.
## Without it the halo hides inside the disc and the body looks like a sticker.
const CORONA_FLOOR := 1.25

## Wall-clock seconds for the exposure buffer to fill once. Normalising to the
## buffer rather than to days means Mercury's 25-day loop and Jupiter's 145-day
## loop both take the same pleasant time to draw themselves.
const BUFFER_WALL_S := 26.0

## Latitudes the spec calls for, north positive.
const LAT_SOUTH_TROPIC := -23.5
const LAT_NORTH_TROPIC := 23.5
const LAT_MID_NORTH := 38.0
const LAT_EQUATOR := 0.0

var _mode: int = Mode.RETROGRADE
var _target: String = EphemerisScript.MARS
var _lat: float = LAT_MID_NORTH
var _jd: float = EphemerisScript.J2000_JD
var _year: int = 2026
var _active: bool = false
var _paused: bool = false
var _speed: float = 1.0
var _narr_gen: int = 0
var _said_south: bool = false
## Observer longitude, Sun altitude and darkness for the current instant.
var _lon: float = 0.0
var _sun_alt: float = -90.0
## Darkness actually used for rendering, and the real darkness the Sun's altitude
## implies. They differ only while the daylight toggle is off, and keeping both
## means the readout can still say what the sky is really doing.
var _dark: float = 1.0
var _true_dark: float = 1.0
var _force_dark: bool = false
var _sky_btn: Button
var _back_btn: Button
var _clock_row: Control
var _env: Environment
var _zoomed: bool = false
var _zoom_btn: Button
## Field fitted to the selected body's actual loop, in degrees. Each body's
## retrograde track is a different size -- Mercury sweeps 8 degrees in 25 days,
## Jupiter 10 degrees in 145 -- so a single constant field either crops one or
## strands the other in the middle of an empty sky.
var _loop_fov: float = FOV_RETROGRADE
## Measured angular length and width of that loop, in degrees. Reported in the
## HUD because the ratio between them is the whole reason a zoom control exists.
var _loop_len: float = 0.0
var _loop_width: float = 0.0
## Fixed aim for the locked field: the centre of the loop, and the observer's
## zenith frozen at the epoch the loop was measured.
var _field_locked: bool = false
var _lock_dir: Vector3 = Vector3.ZERO
var _lock_up: Vector3 = Vector3.UP
## Untyped for the same reason as _sky: a headless run has not rescanned the
## global class cache, so annotating this as LunarCycleStrip fails to parse.
var _strip
var _strip_lbl: Label
## The strip is a month of ephemeris evaluations, far too much to redo per
## frame, so it is rebuilt only when the clock has moved a meaningful amount.
var _strip_jd: float = -1.0

var _host: SubViewportContainer
var _viewport: SubViewport
var _world: Node3D
var _cam: Camera3D
## Left untyped on purpose: a headless run has not rescanned the global class
## cache, so annotating this as ConstellationView fails to parse. Same reason
## Main.gd reaches for scripts through preload consts.
var _sky
## body id -> {root, glow, disc, mat}
var _bodies: Dictionary = {}
var _tail: Node3D
var _tail_dots: Array = []
var _glow_tex: Texture2D
var _disc_shader: Shader
var _glow_quad: QuadMesh

var _title_lbl: Label
var _date_lbl: Label
var _badge_lbl: Label
var _mag_lbl: Label
var _const_lbl: Label
var _lat_row: Control
var _lat_btns: Dictionary = {}
var _year_lbl: Label
var _pause_btn: Button
var _note_lbl: Label
var _sky_lbl: Label

## Earliest and latest year the picker allows. The Standish elements are fitted
## for 1800-2050, so the picker refuses to wander outside the range where the
## simulation is actually trustworthy.
const YEAR_MIN := 1800
const YEAR_MAX := 2050

const LINE_RETROGRADE := "Watch the glowing trail. Most of the time the planet drifts one way \u2014 then it slows, stops, and walks backwards for a while. That is retrograde."
const LINE_ECLIPSE := "The lit part you see is just sunlight bouncing off. When all three line up, one of them falls into the other's shadow."
## Spoken the first time the player crosses to the southern tropic, which is
## the moment the whole field turns over. Saying it once is enough.
const LINE_SOUTH := "Notice everything flipped over? From down south you are standing the other way up, so the whole sky, loop and all, arrives upside down."

# ── Lifecycle ───────────────────────────────────────────────────────

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_glow_tex = PointGlowScript.make_texture()
	_disc_shader = _make_disc_shader()
	_glow_quad = PointGlowScript.make_quad()
	_build_viewport()
	_build_world()
	_build_hud()
	visible = false

func set_active(on: bool) -> void:
	_active = on
	visible = on
	if not on:
		_narr_gen += 1
		Narrator.stop()
	if _viewport != null:
		# Views stay resident forever, so an idle SubViewport would keep
		# burning GPU on a phone. Stop it dead when hidden.
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on \
			else SubViewport.UPDATE_DISABLED

## Open the viewer on a body. `mode` picks RetrogradeViewer or EclipseViewer
## behaviour; `lat_deg` is the observer's latitude; `year` seeds the clock.
func begin(target_id: String, mode: int, lat_deg: float, year: int) -> void:
	_target = target_id
	_mode = mode
	_lat = lat_deg
	set_year(year)
	_zoomed = false
	if _cam != null:
		_cam.fov = _wanted_fov()
		_sky.set_view(float(VIEW_H), _cam.fov)
	_paused = false
	if _lat_row != null:
		# EclipseViewer is locked to the equator, so the latitude row has
		# nothing to offer there.
		_lat_row.visible = mode == Mode.RETROGRADE
	if _title_lbl != null:
		_title_lbl.text = "%s from Earth" % _body_name(target_id)
	if _note_lbl != null:
		_note_lbl.text = _mode_note()
	# The lunar cycle only means something for the Moon.
	if _strip != null:
		_strip.visible = mode == Mode.ECLIPSE \
			and target_id == EphemerisScript.MOON
	if _strip_lbl != null:
		_strip_lbl.visible = _strip != null and _strip.visible
	if _zoom_btn != null:
		# Both modes want zoom, for the same reason: the interesting detail (a
		# lunar terminator, the crossing point of a retrograde loop) is far
		# smaller than the thing it belongs to.
		_zoom_btn.visible = true
	_sync_lat_buttons()
	_said_south = false
	set_active(true)
	_refresh()
	_narr_gen += 1
	_narrate_open(_narr_gen)

## One line on entry explaining what to look for, keyed to the viewer's mode.
func _narrate_open(gen: int) -> void:
	await get_tree().create_timer(0.4).timeout
	if gen != _narr_gen or not visible:
		return
	Narrator.speak(LINE_ECLIPSE if _mode == Mode.ECLIPSE else LINE_RETROGRADE)

## Jump the clock to a year, landing on a moment worth arriving at.
##
## Picking "Jupiter, 2026" and being shown four months of Jupiter trudging in a
## straight line teaches nothing, so the clock goes to that year's first
## retrograde window. Which end of the window matters, for two reasons that
## happen to agree:
##
##   The trail looks BACK 1.2 retrograde periods. Arriving at the START of a loop
##   means the trail holds the approach and none of the reversal, and the loop
##   only appears if you sit and wait. Arriving just after the END means the
##   whole loop is already drawn on the first frame.
##
##   Mercury and Venus retrograde around inferior conjunction, right next to the
##   Sun, so mid-window is the WORST moment of the whole apparition to look --
##   the sky is broad daylight and the planet is in the glare. The ends of the
##   window are where elongation is greatest and the planet stands in a twilight
##   sky, which is exactly when people actually see it.
##
## So: aim near the end of the window -- far enough in that the trail already
## holds the reversal, but short of the exit, so the badge still reads retrograde
## and the second station plays out live within a few days of simulated time --
## then nudge to the most observable night nearby.
func set_year(year: int) -> void:
	_year = year
	var start: float = EphemerisScript.jd_at_year_start(year)
	var buffer: float = ExposureScript.schedule_days(_target)
	var window: Dictionary = {}
	if _mode == Mode.RETROGRADE:
		window = EphemerisScript.retrograde_window(_target, start)
	if window.is_empty():
		# Sun, Moon, or no loop within reach: just start the clock a full buffer
		# in, so the tail is complete on the first frame instead of growing out
		# of nothing.
		_jd = start + buffer
	else:
		var a: float = float(window["start"])
		var b: float = float(window["end"])
		_jd = _best_night_near(a + (b - a) * 0.9, 10.0)
	_fit_loop_fov()
	_update_note()
	_refresh()

## The note reports measured properties of the current loop, so it has to be
## rewritten whenever the loop changes -- a new year or a new latitude, not just
## a new body.
func _update_note() -> void:
	if _note_lbl != null:
		_note_lbl.text = _mode_note()

## Size the camera field to the track the exposure buffer is about to draw.
##
## The tail is computed from a closed-form ephemeris, so its full extent is known
## before anything is rendered -- measure it and fit the field to it. This is why
## Mercury and Jupiter both frame well despite loops of very different angular
## size, and it is only a zoom setting, so nothing about the sky is distorted to
## achieve it.
func _fit_loop_fov() -> void:
	if _mode != Mode.RETROGRADE:
		return
	var lon: float = EphemerisScript.best_view_longitude_deg(_target, _jd, _lat)
	# A coarse sample is plenty: this measures an envelope, not a shape.
	var tail: Array = ExposureScript.sample_tail(_target, _jd, _lat, lon, 24)
	if tail.size() < 2:
		_loop_fov = FOV_RETROGRADE
		return
	# Widest separation between any two samples, which is the angular diameter of
	# the whole track. Measuring from the head alone would under-read a loop that
	# doubles back past its own starting point.
	var extent: float = 0.0
	for i in tail.size():
		for j in range(i + 1, tail.size()):
			extent = maxf(extent, rad_to_deg(
				(tail[i]["dir"] as Vector3).angle_to(tail[j]["dir"] as Vector3)))
	_loop_len = extent
	_loop_fov = clampf(extent * FOV_LOOP_MARGIN, FOV_LOOP_MIN, FOV_LOOP_MAX)
	# The loop's WIDTH is its swing in ecliptic latitude. That is what decides
	# whether the track opens into a visible loop or closes into a line the
	# planet retraces: the two legs are separated by nothing else.
	var lo: float = 90.0
	var hi: float = -90.0
	for s in tail:
		var g: Vector3 = EphemerisScript.geocentric_ecliptic_au(
			_target, float(s["jd"]))
		var b: float = rad_to_deg(asin(g.z / maxf(g.length(), 1.0e-9)))
		lo = minf(lo, b)
		hi = maxf(hi, b)
	_loop_width = hi - lo
	# Centre of the loop, for the locked field: the mean of the track's directions
	# rather than the planet's current place, so the whole loop stays framed as it
	# is drawn instead of drifting off one edge.
	var sum := Vector3.ZERO
	for s in tail:
		sum += (s["dir"] as Vector3).normalized()
	if sum.length() > 0.001:
		_lock_dir = sum.normalized()
	_lock_up = EphemerisScript.zenith_dir(_jd, _lat, lon)

## Refit the loop field and push it to the camera and star sphere.
func _apply_fitted_fov() -> void:
	_fit_loop_fov()
	_update_note()
	if _cam != null:
		_cam.fov = _wanted_fov()
		_sky.set_view(float(VIEW_H), _cam.fov)

## The most observable night within `span` days of `about`: darkest sky with the
## target usefully high. Ties and a total absence of dark skies both fall back to
## `about` itself, so this can only improve on the guess it is given.
func _best_night_near(about: float, span: float) -> float:
	var best: float = about
	var best_score: float = -INF
	var steps: int = int(span)
	for i in range(-steps, steps + 1):
		var t: float = about + float(i)
		var lon: float = EphemerisScript.best_view_longitude_deg(_target, t, _lat)
		var dark: float = EphemerisScript.darkness01(
			EphemerisScript.sun_altitude_deg(t, _lat, lon))
		var rd: Vector2 = EphemerisScript.ra_dec(_target, t)
		var alt: float = EphemerisScript.alt_az(rd.x, rd.y, t, _lat, lon).x
		var score: float = dark * 100.0 + alt
		if score > best_score:
			best_score = score
			best = t
	return best

func set_latitude(lat_deg: float) -> void:
	var crossed: bool = lat_deg < 0.0 and _lat >= 0.0
	_lat = lat_deg
	_apply_fitted_fov()
	_refresh()
	if crossed and not _said_south:
		_said_south = true
		_narr_gen += 1
		Narrator.speak(LINE_SOUTH)

func set_paused(on: bool) -> void:
	_paused = on

func set_speed(mult: float) -> void:
	_speed = clampf(mult, 0.0, 8.0)

func current_jd() -> float:
	return _jd

func target_id() -> String:
	return _target

func latitude() -> float:
	return _lat

## Simulated days per wall-clock second, normalised to the exposure buffer.
func days_per_second() -> float:
	return ExposureScript.schedule_days(_target) / BUFFER_WALL_S * _speed

func _process(delta: float) -> void:
	if not _active:
		return
	if not _paused:
		_jd += delta * days_per_second()
	_refresh()

# ── Build ───────────────────────────────────────────────────────────

func _build_viewport() -> void:
	_host = SubViewportContainer.new()
	_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_host.stretch = true
	_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_host)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(VIEW_W, VIEW_H)
	# Mandatory: without its own world every SubViewport shares the root
	# World3D and the scenes end up filming each other's planets.
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_host.add_child(_viewport)

func _build_world() -> void:
	_world = Node3D.new()
	_world.name = "SkyWorld"
	_viewport.add_child(_world)

	var env := Environment.new()
	_env = env
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.008, 0.012, 0.028)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.04, 0.05, 0.08)
	# Very low ambient: a night sky, and a crisp terminator on the Moon needs
	# the dark limb to actually be dark.
	env.ambient_light_energy = 0.12
	# Emissive stars read as flat discs without this.
	env.glow_enabled = true
	env.glow_intensity = 0.75
	env.glow_bloom = 0.18
	var we := WorldEnvironment.new()
	we.environment = env
	_world.add_child(we)

	_cam = Camera3D.new()
	_cam.fov = FOV_RETROGRADE
	_cam.near = 0.5
	# Must clear the star sphere.
	_cam.far = SKY_R * 3.0
	_world.add_child(_cam)
	_cam.current = true

	_sky = ConstellationViewScript.new()
	_sky.name = "ConstellationView"
	_world.add_child(_sky)
	_sky.build(SKY_R)
	_sky.set_view(float(VIEW_H), _cam.fov)

	_tail = Node3D.new()
	_tail.name = "ExposureTail"
	_world.add_child(_tail)
	_build_tail_pool()
	_build_bodies()

func _make_glow_quad() -> MeshInstance3D:
	return PointGlowScript.make_quad_instance(_glow_quad, _glow_tex)

## One reusable quad per possible tail sample. Pooled so a months-long time
## lapse never allocates.
func _build_tail_pool() -> void:
	for _i in ExposureScript.DEFAULT_SAMPLES:
		var mi := _make_glow_quad()
		mi.visible = false
		_tail.add_child(mi)
		_tail_dots.append({
			"mi": mi,
			"mat": mi.material_override as StandardMaterial3D,
		})

func _build_bodies() -> void:
	for id in EphemerisScript.NAKED_EYE:
		var root := Node3D.new()
		root.name = id
		_world.add_child(root)
		# Glow: what the eye actually registers for a point source.
		var glow := _make_glow_quad()
		root.add_child(glow)
		# Disc: only shown when the true angular size earns it.
		var disc := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 1.0
		sphere.height = 2.0
		sphere.radial_segments = 32
		sphere.rings = 18
		disc.mesh = sphere
		var mat := ShaderMaterial.new()
		mat.shader = _disc_shader
		var tex: Texture2D = PlanetSkinsScript.texture_for(id)
		mat.set_shader_parameter("albedo_tex", tex)
		mat.set_shader_parameter("has_tex", tex != null)
		mat.set_shader_parameter("tint", _body_tint(id))
		mat.set_shader_parameter("is_star", id == EphemerisScript.SUN)
		# Earthshine makes the Moon's dark limb read as a sphere rather than a
		# bite taken out of the sky.
		mat.set_shader_parameter("night_glow",
			0.035 if id == EphemerisScript.MOON else 0.0)
		disc.material_override = mat
		disc.visible = false
		root.add_child(disc)
		_bodies[id] = {
			"root": root,
			"glow": glow,
			"glow_mat": glow.material_override as StandardMaterial3D,
			"disc": disc,
			"mat": mat,
		}

func _body_tint(id: String) -> Vector3:
	match id:
		EphemerisScript.SUN:
			return Vector3(1.0, 0.94, 0.78)
		EphemerisScript.MERCURY:
			return Vector3(0.82, 0.79, 0.74)
		EphemerisScript.VENUS:
			return Vector3(1.0, 0.97, 0.86)
		EphemerisScript.MARS:
			return Vector3(1.0, 0.58, 0.40)
		EphemerisScript.JUPITER:
			return Vector3(1.0, 0.89, 0.72)
		EphemerisScript.MOON:
			return Vector3(0.93, 0.93, 0.90)
		_:
			return Vector3.ONE

# ── Per-frame update ────────────────────────────────────────────────

func _refresh() -> void:
	if _cam == null or _sky == null:
		return
	# Stand where the target is actually observable, not merely highest.
	var lon: float = EphemerisScript.best_view_longitude_deg(_target, _jd, _lat)
	_lon = lon
	_sun_alt = EphemerisScript.sun_altitude_deg(_jd, _lat, lon)
	_true_dark = EphemerisScript.darkness01(_sun_alt)
	# The daylight model is physically right and can still be in the way: a
	# retrograde loop that happens in the daytime sky is real, but a blue sky
	# hides the constellations the loop is meant to be read against. The toggle
	# lifts the daylight without touching any position, so the geometry stays
	# exactly as computed and only the sky's own brightness is set aside.
	_dark = 1.0 if _force_dark else _true_dark
	_apply_sky_brightness()
	_aim_camera(lon)
	_place_bodies(lon)
	_draw_tail(lon)
	_sky.update_proximity(_cam)
	_sky.cull_labels(_cam, _hud_rects())
	_update_hud()

## Screen regions the HUD occupies, so sky labels can keep out of them. In
## viewport pixels, matching the SubViewport the camera renders into.
func _hud_rects() -> Array:
	var rects: Array = [
		# Title, date and status badge across the top centre.
		Rect2(300, 8, 680, 130),
		# Magnitude, constellation and sky condition, top right.
		Rect2(900, 8, 380, 110),
	]
	# The controls are the only part that can be hidden, so they are the only part
	# whose region is conditional. Reserving space for buttons that are not on
	# screen would push sky labels out of a band that is actually clear.
	if _back_btn != null and _back_btn.visible:
		rects.append(Rect2(8, 8, 110, 92))
	if _clock_row != null and _clock_row.visible:
		# Latitude row, year picker and the note along the bottom.
		rects.append(Rect2(0, 452, float(VIEW_W), float(VIEW_H) - 452.0))
	else:
		# The note still sits at the very bottom even with the controls gone.
		rects.append(Rect2(0, 546, float(VIEW_W), float(VIEW_H) - 546.0))
	if _strip != null and _strip.visible:
		rects.append(Rect2(8, 348, 560, 100))
	return rects

## Daylight is not a black sky with stars in it. Scattered sunlight both lights
## the sky and drowns everything fainter than the Moon, so the background colour
## and every point source have to answer to the Sun's altitude. This is what
## makes Venus behave like the evening star instead of a bead floating in space.
func _apply_sky_brightness() -> void:
	if _env == null:
		return
	_env.background_color = _sky_colour(-90.0 if _force_dark else _sun_alt)
	_sky.set_daylight(_dark)

## Point the cockpit camera at the target with the observer's local vertical as
## up. The up vector is the entire southern-hemisphere inversion.
func _aim_camera(lon_deg: float) -> void:
	var fwd: Vector3 = ExposureScript.observed_dir(_target, _jd, _lat, lon_deg)
	if fwd.length() < 0.001:
		return
	var up: Vector3 = EphemerisScript.zenith_dir(_jd, _lat, lon_deg)
	# Locked to the loop instead of to the planet. Pointing at the planet keeps it
	# pinned to the middle of the frame, so as the clock runs it is the STARS that
	# appear to move and the retrograde -- which is a motion against those stars --
	# becomes impossible to see. Holding the field still puts the motion back where
	# it belongs. The frozen up vector is the same trick: it is the field a real
	# observer gets by looking at the same local sidereal time each night, which is
	# exactly how retrograde composites are photographed.
	if _field_locked and _lock_dir.length() > 0.001:
		fwd = _lock_dir
		up = _lock_up
	# Guard the degenerate case where the target is at the zenith and up is
	# parallel to forward.
	if absf(up.dot(fwd.normalized())) > 0.999:
		up = Vector3.UP
	_cam.global_position = Vector3.ZERO
	_cam.look_at_from_position(Vector3.ZERO, fwd.normalized() * 100.0, up)

func _place_bodies(lon_deg: float) -> void:
	var px_per_rad: float = PointGlowScript.px_per_rad(float(VIEW_H), _cam.fov)
	for id in _bodies:
		var info: Dictionary = _bodies[id]
		var root: Node3D = info["root"] as Node3D
		var glow: MeshInstance3D = info["glow"] as MeshInstance3D
		var glow_mat: StandardMaterial3D = info["glow_mat"] as StandardMaterial3D
		var disc: MeshInstance3D = info["disc"] as MeshInstance3D
		var mat: ShaderMaterial = info["mat"] as ShaderMaterial
		var dir: Vector3 = ExposureScript.observed_dir(id, _jd, _lat, lon_deg)
		if dir.length() < 0.001:
			root.visible = false
			continue
		root.visible = true
		root.position = dir.normalized() * BODY_SHELL_R
		var mag: float = BrillianceScript.apparent_magnitude(id, _jd)
		var bright: float = BrillianceScript.brightness01(mag)
		# True angular size: honest, and usually far under a pixel.
		var theta: float = EphemerisScript.apparent_radius_rad(id, _jd)
		var radius_px: float = theta * px_per_rad
		# SolarBrilliance drives the halo, through the SAME magnitude-to-pixels
		# function the stars use -- that shared scale is what makes a planet
		# look like a planet against them.
		var glow_px: float = PointGlowScript.diameter_px(mag)
		var resolved: bool = radius_px * 2.0 >= DISC_MIN_PX
		# The Sun and, zoomed in, the Moon are the two bodies that actually
		# resolve, and a resolved disc needs its glare bounded from both sides.
		# Below a floor the halo disappears inside the disc and the body renders
		# as a flat sticker. Above a cap it swamps the terminator, which is the
		# entire subject of EclipseViewer. The Sun is deliberately exempt from the
		# cap: not being able to look anywhere near it is the defining fact about
		# the Sun, and the one thing this view should convey about why an eclipse
		# is worth travelling for.
		if resolved:
			glow_px = maxf(glow_px, radius_px * 2.0 * CORONA_FLOOR)
			var cap: float = _corona_cap(id)
			if cap > 0.0:
				glow_px = minf(glow_px, radius_px * 2.0 * cap)
		glow.scale = Vector3.ONE * maxf(
			_px_to_world(glow_px, px_per_rad, BODY_SHELL_R), 0.001)
		glow_mat.albedo_color = _glow_colour(id, bright, mag, resolved)
		if resolved:
			disc.visible = true
			disc.scale = Vector3.ONE * (BODY_SHELL_R * tan(theta))
			mat.set_shader_parameter("sun_dir",
				BrillianceScript.sun_dir_from(id, _jd))
			mat.set_shader_parameter("brightness", clampf(bright + 0.35, 0.0, 1.4))
		else:
			disc.visible = false

## Screen pixels to world units on a shell at `shell_r`.
static func _px_to_world(px: float, px_per_rad: float, shell_r: float) -> float:
	return px / maxf(px_per_rad, 0.001) * shell_r

## Sky colour for a given solar altitude. Four stops interpolated in order:
## night, astronomical twilight, the deep blue of civil twilight, and full
## daylight. The daylight value is deliberately not a photographic sky blue --
## the render has no atmospheric scattering model and a saturated blue would
## look like a painted backdrop -- but it is bright enough to be unmistakably
## day, which is the information that matters.
static func _sky_colour(sun_alt_deg: float) -> Color:
	const NIGHT := Color(0.008, 0.012, 0.028)
	const ASTRO := Color(0.020, 0.034, 0.075)
	const CIVIL := Color(0.075, 0.130, 0.250)
	const DAY := Color(0.290, 0.450, 0.680)
	if sun_alt_deg <= -18.0:
		return NIGHT
	if sun_alt_deg <= -6.0:
		return NIGHT.lerp(ASTRO, (sun_alt_deg + 18.0) / 12.0)
	if sun_alt_deg <= 0.0:
		return ASTRO.lerp(CIVIL, (sun_alt_deg + 6.0) / 6.0)
	# Brightens for the first few degrees after sunrise, then holds.
	return CIVIL.lerp(DAY, clampf(sun_alt_deg / 8.0, 0.0, 1.0))

## Upper bound on a resolved body's glare, as a multiple of its own diameter.
## Zero means no bound. The Moon's aureole is genuinely tight, and keeping it
## tight is what leaves the terminator readable; the Sun's is unbounded because
## its scatter really does fill the sky.
func _corona_cap(id: String) -> float:
	match id:
		EphemerisScript.SUN:
			# The Sun's vast halo is atmospheric scatter -- the same scatter that
			# makes the sky blue. So when the daylight is set aside the halo has
			# to go with it, or the toggle trades a blue sky that hides the stars
			# for a black one where the Sun still hides a quarter of them. What is
			# left is close to the airless truth: a disc and a little corona.
			return 2.5 if _force_dark else 0.0
		EphemerisScript.MOON:
			return 3.0
		_:
			return 6.0

## Glow colour and alpha for a body.
##
## Driven by apparent magnitude, which ALREADY accounts for phase -- that is what
## the phase correction in SolarBrilliance is for. Scaling the glare by
## illuminated fraction on top of that double-counts the phase, and the error is
## not subtle: Venus retrogrades near inferior conjunction as a thin crescent a
## few percent lit, yet at magnitude -4 she is the brightest thing in the sky
## after the Sun and Moon. Multiplying by 0.05 erased her from her own viewer.
##
## Resolved bodies get their glare damped, because a full-strength halo centred
## on a disc washes out the terminator that is the whole subject of EclipseViewer.
func _glow_colour(id: String, bright: float, mag: float,
		disc_visible: bool) -> Color:
	var t: Vector3 = _body_tint(id)
	var a: float = clampf(0.10 + 0.90 * bright, 0.0, 1.0)
	if id != EphemerisScript.SUN:
		a *= _visibility(mag)
		a *= _moon_new_falloff(id)
		if disc_visible:
			a *= 0.35
	return Color(t.x, t.y, t.z, a)

## Fades the Moon's glare out as it approaches new, 1 down to 0.
##
## This is a correction for a known limit of the model, not a general phase term.
## The Moon's magnitude law is fitted to about 150 degrees of phase angle and is
## meaningless beyond it -- extrapolated to a true new moon it still claims about
## magnitude -6. Left alone, the additive glow paints a bright blob through the
## middle of an unlit disc and a new moon renders as a grey ball: wrong, and the
## reverse of the point, since a new moon being invisible is exactly why nobody
## sees a solar eclipse coming. Only the Moon needs this; every other body's
## phase law holds across the range it can actually present to us.
func _moon_new_falloff(id: String) -> float:
	if id != EphemerisScript.MOON:
		return 1.0
	# 0.067 lit is the phase angle of 150 degrees where the fit gives out.
	return clampf(EphemerisScript.illuminated_fraction(id, _jd) / 0.067,
		0.0, 1.0)

## How much of a source of magnitude `mag` survives the current sky brightness,
## 0 to 1. Venus at -4 stays visible into daylight, which is true and is the
## reason for the occasional "Venus in the afternoon" story; Mercury at +1 does
## not stand a chance until the sky is properly dark.
func _visibility(mag: float) -> float:
	var limit: float = lerpf(-2.0, 6.0, _dark)
	return clampf((limit - mag) / 1.5, 0.0, 1.0)

## Lay the exposure tail out along the body's real past track.
func _draw_tail(lon_deg: float) -> void:
	var samples: Array = ExposureScript.sample_tail(_target, _jd, _lat, lon_deg,
		ExposureScript.DEFAULT_SAMPLES)
	var px_per_rad: float = PointGlowScript.px_per_rad(float(VIEW_H), _cam.fov)
	var tint: Vector3 = _body_tint(_target)
	var n: int = mini(samples.size(), _tail_dots.size())
	for i in n:
		var s: Dictionary = samples[i]
		var slot: Dictionary = _tail_dots[i]
		var mi: MeshInstance3D = slot["mi"] as MeshInstance3D
		var mat: StandardMaterial3D = slot["mat"] as StandardMaterial3D
		var w: float = float(s["weight"])
		var dir: Vector3 = s["dir"] as Vector3
		mi.visible = true
		mi.position = dir.normalized() * TAIL_SHELL_R
		# Each sample is exposed at the brightness the body really had then, so
		# the tail swells where the planet was near opposition.
		var mag: float = BrillianceScript.apparent_magnitude(_target,
			float(s["jd"]))
		# Tail dots stay small and roughly constant, and let ALPHA carry the
		# decay. Sizing them off the planet's own glare instead looked right in
		# principle and was wrong in practice: the 132 samples are about one per
		# night, and a retrograde loop is only a few degrees wide, so successive
		# dots land a pixel or two apart. Planet-sized dots then overlap into a
		# saturated bar that hides the planet at the head of its own trail.
		# Small dots read as what they are -- one observation per night.
		var px: float = 1.7 + 2.6 * w
		mi.scale = Vector3.ONE * maxf(
			_px_to_world(px, px_per_rad, TAIL_SHELL_R), 0.001)
		# Retrograde stretches run warmer, so the reversal reads as a distinct
		# part of the loop instead of a uniform smear.
		var warm: float = 1.0 if bool(s["retrograde"]) else 0.0
		# Alpha carries the decay. Raising the weight to a power above one makes
		# the fade read as a fade: a linear ramp on an additive blend over black
		# looks nearly uniform until it is almost gone.
		# The trail is a record of past nights, not a claim about what is in the
		# sky right now, so it keeps most of its strength in daylight. That
		# matters most for the one case where it is all you get: Mercury's loop
		# happens within a few degrees of the Sun, so the planet itself is lost
		# in the glare through the whole apparition -- which is why hardly anyone
		# has ever seen it -- and the trail is the only way to look at the loop
		# at all. It still dims a little, because a washed-out sky washes out
		# everything drawn on it.
		var a: float = pow(w, 1.45) * PointGlowScript.alpha_for(mag) * 0.55 \
			* lerpf(0.6, 1.0, _dark)
		mat.albedo_color = Color(
			tint.x + 0.10 * warm,
			tint.y - 0.05 * warm,
			tint.z - 0.12 * warm,
			clampf(a, 0.0, 1.0))
	for i in range(n, _tail_dots.size()):
		((_tail_dots[i] as Dictionary)["mi"] as MeshInstance3D).visible = false

# ── HUD ─────────────────────────────────────────────────────────────

func _build_hud() -> void:
	# Hardware Back means "pause" everywhere in this app, so an on-screen back
	# button is the only way out of a mode.
	var back := Button.new()
	back.text = "\u25C0"
	back.size = Vector2(84, 66)
	back.position = Vector2(20, 20)
	back.focus_mode = Control.FOCUS_NONE
	back.add_theme_font_size_override("font_size", 28)
	back.add_theme_stylebox_override("normal",
		_box(Color(0.95, 0.86, 0.45, 0.98), 16))
	back.pressed.connect(func() -> void: closed.emit())
	add_child(back)
	_back_btn = back

	_title_lbl = _label(Vector2(340, 20), Vector2(600, 40), 30,
		Color(0.94, 0.96, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	_date_lbl = _label(Vector2(340, 60), Vector2(600, 32), 24,
		Color(0.55, 0.92, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	_badge_lbl = _label(Vector2(340, 94), Vector2(600, 32), 22,
		Color(1.0, 0.86, 0.28), HORIZONTAL_ALIGNMENT_CENTER)
	_mag_lbl = _label(Vector2(920, 24), Vector2(340, 28), 18,
		Color(0.78, 0.84, 0.96), HORIZONTAL_ALIGNMENT_RIGHT)
	_const_lbl = _label(Vector2(920, 52), Vector2(340, 28), 18,
		Color(1.0, 0.87, 0.45), HORIZONTAL_ALIGNMENT_RIGHT)
	_sky_lbl = _label(Vector2(920, 80), Vector2(340, 28), 18,
		Color(0.66, 0.76, 0.92), HORIZONTAL_ALIGNMENT_RIGHT)
	# Full width and centred: the retrograde note is a long sentence and was
	# running off the right edge at 760 px.
	_note_lbl = _label(Vector2(24, 556), Vector2(1232, 30), 16,
		Color(0.62, 0.70, 0.86), HORIZONTAL_ALIGNMENT_CENTER)

	_build_lat_row()
	_build_clock_row()
	_build_lunar_strip()

## LunarCycleExposure, as a chart. See LunarCycleStrip for why the lunar cycle
## cannot live in the sky the way the retrograde loop does.
func _build_lunar_strip() -> void:
	_strip_lbl = _label(Vector2(24, 356), Vector2(420, 24), 15,
		Color(0.62, 0.70, 0.86), HORIZONTAL_ALIGNMENT_LEFT)
	_strip_lbl.text = "the last %.0f nights \u2014 every second night" \
		% ExposureScript.lunar_schedule_days()
	_strip_lbl.visible = false
	_strip = LunarCycleStripScript.new()
	_strip.position = Vector2(24, 382)
	_strip.visible = false
	add_child(_strip)

## The three observing latitudes the spec names. Southern-hemisphere viewing is
## the point of the exercise, so it is offered first.
func _build_lat_row() -> void:
	_lat_row = Control.new()
	_lat_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_lat_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_lat_row)
	var row := HBoxContainer.new()
	row.position = Vector2(24, 470)
	row.add_theme_constant_override("separation", 10)
	_lat_row.add_child(row)
	var choices := [
		[LAT_SOUTH_TROPIC, "23.5\u00B0 S", "Tropic of Capricorn"],
		[LAT_NORTH_TROPIC, "23.5\u00B0 N", "Tropic of Cancer"],
		[LAT_MID_NORTH, "38\u00B0 N", "mid-northern"],
	]
	for c in choices:
		var lat: float = float(c[0])
		var btn := Button.new()
		btn.text = "%s\n%s" % [str(c[1]), str(c[2])]
		btn.custom_minimum_size = Vector2(208, 62)
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_size_override("font_size", 17)
		btn.pressed.connect(func() -> void:
			set_latitude(lat)
			_sync_lat_buttons())
		row.add_child(btn)
		_lat_btns[lat] = btn
	_sync_lat_buttons()

func _sync_lat_buttons() -> void:
	for lat in _lat_btns:
		var btn: Button = _lat_btns[lat] as Button
		var on: bool = is_equal_approx(float(lat), _lat)
		btn.add_theme_stylebox_override("normal", _box(
			Color(0.95, 0.86, 0.45, 0.96) if on
			else Color(0.13, 0.18, 0.30, 0.90), 14))
		btn.add_theme_color_override("font_color",
			Color(0.06, 0.08, 0.12) if on else Color(0.82, 0.88, 0.98))

## Year picker plus pause. Choosing a year jumps the orrery to that epoch and
## the exposure tail is recomputed from scratch, so there is never a partially
## drawn trail after a jump.
func _build_clock_row() -> void:
	var row := HBoxContainer.new()
	_clock_row = row
	# Sized to end on the same 24 px margin the rest of the HUD uses, with room
	# for six controls.
	row.position = Vector2(736, 470)
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	var minus := _small_button("\u2039", func() -> void: step_year(-1))
	row.add_child(minus)
	_year_lbl = Label.new()
	_year_lbl.custom_minimum_size = Vector2(120, 62)
	_year_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_year_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_year_lbl.add_theme_font_size_override("font_size", 26)
	_year_lbl.add_theme_color_override("font_color", Color(0.94, 0.96, 1.0))
	row.add_child(_year_lbl)
	var plus := _small_button("\u203A", func() -> void: step_year(1))
	row.add_child(plus)
	_pause_btn = _small_button("\u23F8", func() -> void:
		set_paused(not _paused)
		_pause_btn.text = "\u25B6" if _paused else "\u23F8")
	_pause_btn.custom_minimum_size = Vector2(72, 62)
	row.add_child(_pause_btn)
	_zoom_btn = _small_button("\u2315", func() -> void: set_zoomed(not _zoomed))
	_zoom_btn.custom_minimum_size = Vector2(72, 62)
	_zoom_btn.visible = false
	row.add_child(_zoom_btn)
	_sky_btn = _small_button("\u2600", func() -> void:
		set_force_dark(not _force_dark))
	_sky_btn.custom_minimum_size = Vector2(72, 62)
	row.add_child(_sky_btn)
	_sync_sky_button()

## Field of view the current mode and zoom state ask for.
func _wanted_fov() -> float:
	if _mode != Mode.ECLIPSE:
		return _loop_fov * FOV_LOOP_ZOOM if _zoomed else _loop_fov
	return FOV_ECLIPSE_CLOSE if _zoomed else FOV_ECLIPSE

## Zoom in on the target. Only the field of view changes -- nothing is
## resized -- so the picture stays honest at both settings.
func set_zoomed(on: bool) -> void:
	_zoomed = on
	if _cam != null:
		_cam.fov = _wanted_fov()
		_sky.set_view(float(VIEW_H), _cam.fov)
	if _zoom_btn != null:
		_zoom_btn.text = "\u2296" if on else "\u2315"
	_refresh()

func zoomed() -> bool:
	return _zoomed

## Set aside the daylight sky so the stars stay visible whatever the Sun is doing.
##
## Nothing moves. Every position, magnitude and exposure weight is computed the
## same way either side of this switch -- the only thing suppressed is the sky's
## own brightness and the washing-out it causes. That distinction is why the
## toggle is honest: it is the difference between drawing the sky wrong and
## drawing a correct sky with the daylight taken off, the way a star chart does.
##
## It earns its place because the Sun otherwise gates the whole view. Mercury and
## Venus retrograde near conjunction, so their loops fall in the daytime sky, and
## the constellations those loops are meant to be read against are exactly what
## daylight removes.
func set_force_dark(on: bool) -> void:
	_force_dark = on
	_sync_sky_button()
	_refresh()

func force_dark() -> bool:
	return _force_dark

## Hold the field on the loop rather than on the planet, so the planet is what
## moves. See `_aim_camera` for why this is the difference between a visible
## retrograde and an invisible one.
func set_field_lock(on: bool) -> void:
	_field_locked = on
	if on:
		# Aim at the loop as it stands NOW. Locking is only useful once the clock
		# is sitting somewhere the buffer holds the whole loop, and the caller is
		# the one who knows when that is.
		_fit_loop_fov()
	_refresh()

func field_locked() -> bool:
	return _field_locked

## Hide the controls, keeping the readouts. For recording, where the buttons are
## dead weight and the bottom strip of them covers the part of the sky the loop
## runs through -- the Beehive sits right behind the year picker.
func set_chrome_visible(on: bool) -> void:
	if _back_btn != null:
		_back_btn.visible = on
	if _clock_row != null:
		_clock_row.visible = on
	if _lat_row != null:
		_lat_row.visible = on and _mode == Mode.RETROGRADE
	# Sky labels were being kept out of regions that are now empty.
	_refresh()

func _sync_sky_button() -> void:
	if _sky_btn == null:
		return
	_sky_btn.text = "\u263D" if _force_dark else "\u2600"
	# Gold while the override is on, matching how the latitude row marks the
	# active choice, so it is clear the sky is being held dark deliberately.
	_sky_btn.add_theme_stylebox_override("normal", _box(
		Color(0.95, 0.86, 0.45, 0.96) if _force_dark
		else Color(0.13, 0.18, 0.30, 0.90), 14))
	_sky_btn.add_theme_color_override("font_color",
		Color(0.10, 0.13, 0.20) if _force_dark else Color(0.90, 0.94, 1.0))

func field_of_view() -> float:
	return _cam.fov if _cam != null else _wanted_fov()

## Measured angular size of the loop currently in the exposure buffer, degrees.
func loop_geometry() -> Dictionary:
	return {"length": _loop_len, "width": _loop_width}

func step_year(delta_years: int) -> void:
	set_year(clampi(_year + delta_years, YEAR_MIN, YEAR_MAX))

func _small_button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(56, 62)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 26)
	b.add_theme_stylebox_override("normal",
		_box(Color(0.13, 0.18, 0.30, 0.90), 14))
	b.add_theme_color_override("font_color", Color(0.90, 0.94, 1.0))
	b.pressed.connect(on_press)
	return b

func _label(pos: Vector2, size: Vector2, font_size: int, col: Color,
		align: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = size
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l

func _box(col: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(radius)
	return sb

func _update_hud() -> void:
	if _date_lbl != null:
		_date_lbl.text = date_text()
	if _badge_lbl != null:
		_badge_lbl.text = retrograde_text()
	if _mag_lbl != null:
		_mag_lbl.text = magnitude_text()
	if _const_lbl != null:
		var c: String = constellation_text()
		_const_lbl.text = "among the stars of %s" % c if not c.is_empty() \
			else ""
	if _sky_lbl != null:
		_sky_lbl.text = sky_text()
	if _year_lbl != null:
		_year_lbl.text = str(_year)
	# Half a day of drift is invisible on a strip of every-other-night discs,
	# and rebuilding it costs 15 lunar evaluations.
	if _strip != null and _strip.visible and absf(_jd - _strip_jd) > 0.5:
		_strip_jd = _jd
		_strip.set_time(_jd)

## One honest line about what is on screen, so the view never implies that
## Earth is the centre of the system or that the tail is a real object.
func _mode_note() -> String:
	if _mode == Mode.ECLIPSE:
		if _target == EphemerisScript.MOON:
			# Says plainly why the cycle is a strip and the loop is not: the
			# Moon outruns any single field of view.
			return ("Seen from the equator. The Moon shifts about 13\u00B0 "
				+ "east each night \u2014 further than this whole view "
				+ "\u2014 so the %.0f-night cycle is charted below.") \
				% ExposureScript.lunar_schedule_days()
		return ("Seen from the equator. The trail is where the Sun has been "
			+ "against the stars \u2014 the path the Moon has to cross.")
	# The measured size of this particular loop, because it is not a constant:
	# the same body loops differently every apparition, and a loop 0.3 degrees
	# wide needs the zoom control that a loop 4 degrees wide does not.
	return ("%.0f-day exposure of where %s has been \u2014 a loop %.1f\u00B0 "
		+ "long and %.1f\u00B0 wide. This is Earth overtaking on the inside "
		+ "track, not %s reversing.") % [
			ExposureScript.retrograde_schedule_days(_target),
			_body_name(_target), _loop_len, _loop_width, _body_name(_target)]

func _body_name(id: String) -> String:
	return id.substr(0, 1).to_upper() + id.substr(1)

# ── Readouts ────────────────────────────────────────────────────────

func date_text() -> String:
	return EphemerisScript.date_label(_jd)

func latitude_text() -> String:
	if is_zero_approx(_lat):
		return "Equator, 0\u00B0"
	var hemi: String = "N" if _lat > 0.0 else "S"
	var name: String = ""
	if is_equal_approx(_lat, LAT_SOUTH_TROPIC):
		name = "Tropic of Capricorn, "
	elif is_equal_approx(_lat, LAT_NORTH_TROPIC):
		name = "Tropic of Cancer, "
	return "%s%.1f\u00B0 %s" % [name, absf(_lat), hemi]

func magnitude_text() -> String:
	# At new moon there is no lit face pointed at us, so there is no brightness
	# to report. Quoting a number here would be worse than saying nothing: the
	# formula's answer is around -6, which would read as "brighter than Venus"
	# for an object that cannot be seen at all.
	if _target == EphemerisScript.MOON \
			and EphemerisScript.illuminated_fraction(_target, _jd) < 0.01:
		return "no lit face turned our way"
	return BrillianceScript.magnitude_label(
		BrillianceScript.apparent_magnitude(_target, _jd))

func retrograde_text() -> String:
	if _target == EphemerisScript.SUN:
		return ""
	if _target == EphemerisScript.MOON:
		var lit: float = EphemerisScript.moon_illumination(_jd) * 100.0
		if lit < 1.0:
			return "new moon"
		if lit > 99.0:
			return "full moon"
		var phase: String = "waxing" if EphemerisScript.moon_waxing(_jd) \
			else "waning"
		return "%.0f%% lit, %s" % [lit, phase]
	if EphemerisScript.is_retrograde(_target, _jd):
		return "\u211E  retrograde"
	return "direct"

func constellation_text() -> String:
	if _sky == null:
		return ""
	return _sky.name_of(_sky.closest_id)

## What the sky is doing, and -- when it matters -- why you cannot see the thing
## you came to look at. Mercury and Venus retrograde near the Sun, so a washed
## out sky is not a bug in the simulation, it is the reason those two are the
## hardest naked-eye planets to catch.
func sky_text() -> String:
	var mag: float = BrillianceScript.apparent_magnitude(_target, _jd)
	var lost: bool = _target != EphemerisScript.SUN \
		and _visibility(mag) < 0.25
	# With the daylight set aside, say so and still say what the sky is really
	# doing. Reporting a flat "night" over a daytime sky would be a lie, and the
	# fact that a loop happens in the daytime is part of what it teaches.
	if _force_dark:
		if _true_dark >= 0.999:
			return "night"
		return "daylight set aside" if _sun_alt >= -6.0 else "twilight set aside"
	if _sun_alt >= 0.0:
		return "daylight \u2014 lost in the glare" if lost else "daylight"
	if _sun_alt >= -6.0:
		return "twilight \u2014 only just" if lost else "twilight"
	if _sun_alt >= -18.0:
		return "deep twilight"
	return "night"

## Sun altitude, exposed for tests.
func sun_altitude() -> float:
	return _sun_alt

## Darkness 0..1, exposed for tests.
func darkness() -> float:
	return _dark

# ── Assets ──────────────────────────────────────────────────────────

## Shades a body's disc by the TRUE direction to the Sun, so Venus shows a
## crescent and the Moon shows its phase without any of it being hand-animated.
## Unshaded on purpose: the scene has no light rig, the geometry is the light.
func _make_disc_shader() -> Shader:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;

uniform vec3 sun_dir = vec3(0.0, 0.0, -1.0);
uniform vec3 tint = vec3(1.0);
uniform sampler2D albedo_tex : source_color, hint_default_white;
uniform bool has_tex = false;
uniform bool is_star = false;
uniform float night_glow = 0.0;
uniform float brightness = 1.0;

varying vec3 v_n;

void vertex() {
	v_n = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 base = tint;
	if (has_tex) {
		base *= texture(albedo_tex, UV).rgb;
	}
	if (is_star) {
		// The Sun makes its own light; no terminator to draw.
		ALBEDO = base * brightness;
		EMISSION = base * 2.4;
	} else {
		float lit = max(dot(normalize(v_n), normalize(sun_dir)), 0.0);
		// Rough surfaces stay brighter toward the terminator than a smooth
		// Lambert sphere would, so the falloff is softened.
		lit = pow(lit, 0.62);
		ALBEDO = base * (lit * brightness + night_glow);
		EMISSION = base * lit * 0.25 * brightness;
	}
}
"""
	return sh

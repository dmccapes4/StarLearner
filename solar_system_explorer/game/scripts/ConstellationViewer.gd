class_name ConstellationViewer
extends Control
## Standalone constellation viewer: full sky anchored on the celestial equator.
##
## The camera sits at the origin of a star sphere and looks along the equatorial
## plane at whatever right-ascension the user has turned to. Left and right
## arrows rotate the view along the equator; tapping a constellation animates
## the camera to face it directly, brightens it, and shows its stick-figure and
## label. Tapping anywhere again returns to the equatorial-plane view.
##
## Latitude selection (same four choices as EarthSkyViewer) changes the
## observer's north. At 23.5° S the up vector flips, inverting the whole sky
## the way a southern observer standing with their back to the south pole sees
## it — the zodiac arcs across the northern sky instead of the southern one.

const ConstellationDataScript := preload("res://scripts/ConstellationData.gd")
const ConstellationViewScript := preload("res://scripts/ConstellationView.gd")

signal closed()

const VIEW_W := 1280
const VIEW_H := 600
const SKY_R := 2800.0

## Wide field of view so that a good swath of constellations fills the screen.
const FOV := 90.0

## Joystick pan speed: degrees-per-second at full stick deflection.
const JOY_PAN_DEG_S := 60.0

## Camera animation speed toward a focused constellation, degrees per second.
## Fast enough to feel instant; slow enough to read as a deliberate pan.
const AIM_DEG_S := 150.0

## Maximum angular distance from a tap ray to the nearest constellation centre
## to count as a tap on that constellation. 35° is generous on a tablet — the
## sky is big and accuracy is hard with a finger.
const TAP_REACH_DEG := 35.0

## Field-of-view limits and the three zoom steps.
const FOV_MAX := 90.0   ## overview — wide sky
const FOV_MID := 55.0   ## comfortable middle
const FOV_MIN := 30.0   ## close-up for a single constellation

## Observer latitudes offered, northernmost last so "south" is the first tab.
const LAT_CHOICES: Array = [
	[-23.5, "23.5\u00B0 S", "Tropic of Capricorn"],
	[0.0,   "0\u00B0",      "Equator"],
	[23.5,  "23.5\u00B0 N", "Tropic of Cancer"],
	[38.0,  "38\u00B0 N",   "mid-northern"],
]

var _active: bool = false
var _lat: float = 38.0

## Right ascension of the equatorial aim point while in free-look mode, hours.
var _ra_h: float = 6.0
## Declination offset of the aim point, degrees. Joystick vertical axis adjusts
## this. Clamped to ±82° so we never look straight into a pole.
var _dec_deg: float = 0.0

## Empty string while in free-look; id of the constellation being focused on.
var _focused_id: String = ""

## Animated camera forward direction (unit vector in the sky's world space).
var _cam_fwd: Vector3 = Vector3(0.0, 0.0, -1.0)

## Celestial north / south poles in the ConstellationData coordinate system,
## pre-computed once in _ready so we do not re-evaluate every frame.
var _north_pole: Vector3 = Vector3.ZERO
var _south_pole: Vector3 = Vector3.ZERO

## 3-D world (SubViewport → world → camera + sky).
var _host: SubViewportContainer
var _viewport: SubViewport
var _world: Node3D
var _cam: Camera3D
## Untyped: a headless test build has not rescanned the global class cache so
## annotating this as ConstellationView would fail to parse. Same reason
## EarthSkyViewer keeps its sky reference untyped.
var _sky

## FOV value the camera is currently using.
var _fov: float = FOV_MAX

## ── Virtual joystick ──────────────────────────────────────────────────────
## Outer ring radius and nub radius in *control* pixels.
const JOY_RING_R := 68.0
const JOY_NUB_R  := 26.0
## Bottom-right anchor position of the joystick ring centre, in control pixels
## relative to the bottom-right corner (both values are negative offsets).
const JOY_AX := -110.0   ## x offset from right edge to ring centre
const JOY_AY := -110.0   ## y offset from bottom edge to ring centre

## Current normalised joystick vector (x = RA, y = Dec).  Zero = centred.
var _joy_axis: Vector2 = Vector2.ZERO
## Index of the touch that "owns" the joystick right now, -1 when idle.
var _joy_touch_idx: int = -1
## On-screen position of the ring centre, updated when the control is resized.
var _joy_centre: Vector2 = Vector2.ZERO

## ── Pinch-to-zoom ─────────────────────────────────────────────────────────
## Distance between the two pinch fingers on the last drag event, -1 = idle.
var _pinch_dist: float = -1.0
## Tracks active non-joystick touches {index → position} for pinch detection.
var _sky_touches: Dictionary = {}

## ── HUD nodes ─────────────────────────────────────────────────────────────
var _back_btn: Button
var _zoom_in_btn: Button
var _zoom_out_btn: Button
var _hint_lbl: Label
var _focus_name_lbl: Label
var _focus_desc_lbl: Label
var _lat_row: Control
var _lat_btns: Dictionary = {}
## Joystick visuals — outer ring panel and inner nub panel.
var _joy_ring: Panel
var _joy_nub: Panel

# ── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Pre-compute pole directions once; sky_pos(0, ±90°) gives the poles in
	# ecliptic-based world space that ConstellationData uses for all star coords.
	_north_pole = ConstellationDataScript.sky_pos(0.0, 90.0, 1.0)
	_south_pole = -_north_pole
	_fov = FOV_MAX
	_build_viewport()
	_build_world()
	_build_hud()
	# Joy centre is relative to our size; update it when we know our size.
	_update_joy_centre()
	visible = false


func set_active(on: bool) -> void:
	_active = on
	visible = on
	# Stop GPU work while hidden — same pattern as EarthSkyViewer.
	if _viewport != null:
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on \
			else SubViewport.UPDATE_DISABLED


## Open the viewer. `lat_deg` seeds the latitude row; defaults to mid-northern.
func begin(lat_deg: float = 38.0) -> void:
	_lat = lat_deg
	_ra_h = 6.0        # Start on the prominent winter/spring equatorial region
	_dec_deg = 0.0
	_focused_id = ""
	_joy_axis = Vector2.ZERO
	_joy_touch_idx = -1
	_sky_touches.clear()
	_pinch_dist = -1.0
	_fov = FOV_MAX
	if _cam != null:
		_cam.fov = _fov
	if _sky != null:
		_sky.set_view(float(VIEW_H), _fov)
	# Seed the animated direction so the first frame has something sensible.
	_cam_fwd = ConstellationDataScript.sky_pos(_ra_h, 0.0, 1.0).normalized()
	_sync_lat_buttons()
	_update_focus_panel()
	_sync_zoom_buttons()
	_update_joy_nub()
	set_active(true)

# ── Per-frame update ─────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if not _active:
		return

	# Joystick pans RA (horizontal) and Dec (vertical) while in free-look.
	# While focused the camera animates to face the target regardless.
	if _focused_id.is_empty() and _joy_axis.length() > 0.05:
		var speed: float = JOY_PAN_DEG_S * delta
		_ra_h = fposmod(_ra_h + _joy_axis.x * speed / 15.0, 24.0)
		_dec_deg = clampf(_dec_deg - _joy_axis.y * speed, -82.0, 82.0)

	# Compute where the camera is supposed to be pointing.
	var target_fwd: Vector3
	if _focused_id.is_empty():
		target_fwd = ConstellationDataScript.sky_pos(_ra_h, _dec_deg, 1.0).normalized()
	else:
		var d: Vector3 = _sky.dir_of(_focused_id) if _sky != null else Vector3.ZERO
		target_fwd = d.normalized() if d.length() > 0.001 else _cam_fwd

	# Spherically interpolate the camera toward the target so focus / unfocus
	# reads as a smooth pan rather than a cut.
	if _cam_fwd.length() > 0.001 and target_fwd.length() > 0.001:
		var angle_deg: float = rad_to_deg(
			_cam_fwd.normalized().angle_to(target_fwd.normalized()))
		if angle_deg > 0.05:
			var step: float = minf(AIM_DEG_S * delta, angle_deg)
			_cam_fwd = _cam_fwd.normalized().slerp(
				target_fwd.normalized(), step / angle_deg).normalized()
		else:
			_cam_fwd = target_fwd.normalized()
	else:
		_cam_fwd = target_fwd.normalized()

	_update_camera()


func _update_camera() -> void:
	if _cam == null or _sky == null:
		return

	# Push current FOV to camera and star sphere.
	if not is_equal_approx(_cam.fov, _fov):
		_cam.fov = _fov
		_sky.set_view(float(VIEW_H), _fov)

	var up: Vector3 = _north_pole if _lat >= 0.0 else _south_pole
	var fwd: Vector3 = _cam_fwd.normalized()
	if fwd.length() < 0.001:
		return
	# Guard the degenerate case (looking straight at a pole).
	if absf(up.dot(fwd)) > 0.999:
		up = Vector3(up.x + 0.01, up.y, up.z).normalized()

	_cam.global_position = Vector3.ZERO
	_cam.look_at_from_position(Vector3.ZERO, fwd * 100.0, up)

	# Keep RA/Dec in sync with wherever the animated camera is pointing so that
	# when the user un-focuses, free-look resumes from the focused direction
	# rather than snapping back to the old equatorial position.
	if not _focused_id.is_empty():
		# Back-solve RA/Dec from the current forward vector.
		var len_xz: float = Vector2(fwd.x, fwd.z).length()
		if len_xz > 0.001:
			_ra_h = fposmod(rad_to_deg(atan2(-fwd.x, -fwd.z)) / 15.0, 24.0)
		_dec_deg = rad_to_deg(asin(clampf(fwd.y, -1.0, 1.0)))

	_sky.update_proximity(_cam)
	_sky.cull_labels(_cam, _hud_rects())
	_update_hint()


## Screen regions (in SubViewport pixels) that the HUD occupies, so sky labels
## stay clear of them.
func _hud_rects() -> Array:
	var jx: float = float(VIEW_W) + JOY_AX - JOY_RING_R - 8.0
	var jy: float = float(VIEW_H) + JOY_AY - JOY_RING_R - 8.0
	return [
		Rect2(0, 0, float(VIEW_W), 110.0),               # top bar
		Rect2(0, float(VIEW_H) - 130.0, float(VIEW_W), 130.0),  # lat row
		Rect2(jx, jy, float(VIEW_W) - jx, float(VIEW_H) - jy), # joystick
	]


func _update_hint() -> void:
	if _focused_id.is_empty():
		if _sky == null:
			return
		var near: String = _sky.nearest_id
		_hint_lbl.text = "Tap a constellation to learn more" \
			if near.is_empty() \
			else "\u25BA  %s  \u25BA" % _sky.name_of(near)
	else:
		_hint_lbl.text = "Tap anywhere to return to the sky"

# ── Input ────────────────────────────────────────────────────────────────────

# ── Input ────────────────────────────────────────────────────────────────────

## Recompute the on-screen position of the joystick ring centre whenever the
## control changes size (happens on first layout and any resize).
func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_joy_centre()


func _update_joy_centre() -> void:
	var s := get_size()
	_joy_centre = Vector2(s.x + JOY_AX, s.y + JOY_AY)


## Returns true when ctrl_pos (in this Control's coordinate space) is inside
## the joystick touch area (a circle of radius JOY_RING_R + 20px slop).
func _in_joystick(ctrl_pos: Vector2) -> bool:
	return ctrl_pos.distance_to(_joy_centre) <= JOY_RING_R + 20.0


func _gui_input(event: InputEvent) -> void:
	if not _active:
		return

	# ── Touchscreen ──────────────────────────────────────────────────
	if event is InputEventScreenTouch:
		var te := event as InputEventScreenTouch
		if te.pressed:
			if _in_joystick(te.position):
				# This touch drives the joystick.
				_joy_touch_idx = te.index
				_update_joystick_axis(te.position)
			else:
				# Track as a sky touch (for tap detection and pinch).
				_sky_touches[te.index] = te.position
		else:
			if te.index == _joy_touch_idx:
				# Joystick released — centre the stick.
				_joy_touch_idx = -1
				_joy_axis = Vector2.ZERO
				_update_joy_nub()
			else:
				# Sky touch released.
				var was_single: bool = _sky_touches.size() == 1 \
					and _sky_touches.has(te.index)
				_sky_touches.erase(te.index)
				if _sky_touches.is_empty():
					_pinch_dist = -1.0
				# Fire a tap if this was a lone finger lift (not a pinch release).
				if was_single and _pinch_dist < 0.0:
					_handle_tap(te.position)
		get_viewport().set_input_as_handled()
		return

	if event is InputEventScreenDrag:
		var de := event as InputEventScreenDrag
		if de.index == _joy_touch_idx:
			_update_joystick_axis(de.position)
			get_viewport().set_input_as_handled()
			return
		# Sky drag — update pinch tracking.
		_sky_touches[de.index] = de.position
		if _sky_touches.size() == 2:
			var keys := _sky_touches.keys()
			var d: float = (_sky_touches[keys[0]] as Vector2).distance_to(
				_sky_touches[keys[1]] as Vector2)
			if _pinch_dist > 0.0:
				_fov = clampf(_fov - (d - _pinch_dist) * 0.15, FOV_MIN, FOV_MAX)
				_sync_zoom_buttons()
			_pinch_dist = d
		get_viewport().set_input_as_handled()
		return

	# ── Mouse / keyboard (desktop testing) ───────────────────────────
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		match (event as InputEventMouseButton).button_index:
			MOUSE_BUTTON_LEFT:
				_handle_tap((event as InputEventMouseButton).position)
			MOUSE_BUTTON_WHEEL_UP:
				_step_zoom(-1)
			MOUSE_BUTTON_WHEEL_DOWN:
				_step_zoom(1)


## Update _joy_axis from a raw touch position (in control space).
func _update_joystick_axis(ctrl_pos: Vector2) -> void:
	var delta: Vector2 = ctrl_pos - _joy_centre
	if delta.length() > JOY_RING_R:
		delta = delta.normalized() * JOY_RING_R
	_joy_axis = delta / JOY_RING_R   # normalised -1..1
	_update_joy_nub()


## Move the nub visual to match _joy_axis.
func _update_joy_nub() -> void:
	if _joy_nub == null:
		return
	var ring_size: float = JOY_RING_R * 2.0
	# Nub centre offset from ring top-left in pixels.
	var nub_diam: float = JOY_NUB_R * 2.0
	var offset: Vector2 = _joy_axis * (JOY_RING_R - JOY_NUB_R)
	var centre_in_ring: Vector2 = Vector2(JOY_RING_R, JOY_RING_R) + offset
	_joy_nub.position = centre_in_ring - Vector2(JOY_NUB_R, JOY_NUB_R)
	_joy_nub.size = Vector2(nub_diam, nub_diam)


## Called deferred from the touch handler. If there is still exactly one finger
## down it is a real single-finger tap, not the start of a pinch.
func _deferred_tap_check(pos: Vector2) -> void:
	if _sky_touches.size() == 1:
		_handle_tap(pos)


func _handle_tap(ctrl_pos: Vector2) -> void:
	if not _focused_id.is_empty():
		# Any tap in focused mode returns to free-look view.
		_focused_id = ""
		_update_focus_panel()
		return

	if _cam == null or _viewport == null:
		return

	# Map from Control space (screen pixels) to SubViewport space (1280 × 600).
	var ctrl_size := get_size()
	var vp_size := Vector2(_viewport.size)
	if ctrl_size.x < 1.0 or ctrl_size.y < 1.0:
		return
	var vp_pos: Vector2 = ctrl_pos * (vp_size / ctrl_size)

	# Unproject the tap into a 3-D direction in the SubViewport world.
	var ray: Vector3 = _cam.project_ray_normal(vp_pos)

	# Find the constellation whose centre is closest to that ray.
	var best_id: String = ""
	var best_sep: float = TAP_REACH_DEG
	if _sky != null:
		for id in _sky.ids():
			var dir: Vector3 = _sky.dir_of(id)
			if dir.length() < 0.001:
				continue
			var sep: float = ConstellationViewScript.bearing_deg(
				ray, dir.normalized())
			if sep < best_sep:
				best_sep = sep
				best_id = id

	if not best_id.is_empty():
		_focused_id = best_id
		_update_focus_panel()


## Step the FOV by one level. dir=-1 zooms in (lower FOV), dir=+1 zooms out.
func _step_zoom(dir: int) -> void:
	var levels: Array = [FOV_MIN, FOV_MID, FOV_MAX]
	# Find current index (nearest level).
	var best_i: int = 0
	var best_d: float = INF
	for i in levels.size():
		var d: float = absf(_fov - float(levels[i]))
		if d < best_d:
			best_d = d
			best_i = i
	var new_i: int = clampi(best_i + dir, 0, levels.size() - 1)
	_fov = float(levels[new_i])
	_sync_zoom_buttons()


func _sync_zoom_buttons() -> void:
	if _zoom_in_btn != null:
		_zoom_in_btn.disabled = _fov <= FOV_MIN + 0.5
	if _zoom_out_btn != null:
		_zoom_out_btn.disabled = _fov >= FOV_MAX - 0.5


func _update_focus_panel() -> void:
	var focused: bool = not _focused_id.is_empty()
	_focus_name_lbl.visible = focused
	_focus_desc_lbl.visible = focused
	# Fade the joystick while reading a focused description so the ring does not
	# cover the text. It still receives input (the alpha is cosmetic only).
	if _joy_ring != null:
		_joy_ring.modulate.a = 0.25 if focused else 1.0

	if focused and _sky != null:
		_focus_name_lbl.text = _sky.name_of(_focused_id)
		var data: Dictionary = ConstellationDataScript.by_id(_focused_id)
		var napa: String = str(data.get("napa", ""))
		var culture: String = str(data.get("culture", ""))
		# Show both the location note and the cultural line, separated by a space.
		_focus_desc_lbl.text = (napa + "  " + culture).strip_edges()

# ── Build: viewport ──────────────────────────────────────────────────────────

func _build_viewport() -> void:
	_host = SubViewportContainer.new()
	_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_host.stretch = true
	_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_host)

	_viewport = SubViewport.new()
	_viewport.size = Vector2i(VIEW_W, VIEW_H)
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_host.add_child(_viewport)

# ── Build: 3-D world ─────────────────────────────────────────────────────────

func _build_world() -> void:
	_world = Node3D.new()
	_world.name = "ConstellationWorld"
	_viewport.add_child(_world)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.005, 0.009, 0.022)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.03, 0.04, 0.06)
	env.ambient_light_energy = 0.08
	env.glow_enabled = true
	env.glow_intensity = 0.90
	env.glow_bloom = 0.25
	var we := WorldEnvironment.new()
	we.environment = env
	_world.add_child(we)

	_cam = Camera3D.new()
	_cam.fov = FOV
	_cam.near = 0.5
	_cam.far = SKY_R * 3.0
	_world.add_child(_cam)
	_cam.current = true

	# ConstellationView handles all star placement, brightening, proximity
	# detection, and label management — the same instance EarthSkyViewer uses
	# as a background. Here it is the entire scene rather than a backdrop.
	_sky = ConstellationViewScript.new()
	_sky.name = "SkyView"
	_world.add_child(_sky)
	_sky.build(SKY_R)
	_sky.set_view(float(VIEW_H), FOV)
	# ConstellationViewer is a sky atlas: all stick-figure lines are always
	# visible at dim alpha; the nearest / focused one is brightened automatically.
	_sky.set_links_always_dim(true)
	# Always dark: there is no simulated Sun here, so stars are always visible.
	_sky.set_daylight(1.0)

# ── Build: HUD ───────────────────────────────────────────────────────────────

func _build_hud() -> void:
	# ── Back button (top-left) ───────────────────────────────────────
	_back_btn = _make_btn("\u25C0", 28)
	_back_btn.size = Vector2(84, 66)
	_back_btn.position = Vector2(20, 20)
	_back_btn.pressed.connect(func() -> void:
		set_active(false)
		closed.emit())
	add_child(_back_btn)

	# ── Title ────────────────────────────────────────────────────────
	var title := Label.new()
	title.text = "Night Sky"
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 18
	title.offset_bottom = 58
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.94, 0.96, 1.0))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)

	# ── Hint: nearest constellation or "tap to return" ───────────────
	_hint_lbl = Label.new()
	_hint_lbl.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_hint_lbl.offset_top = 62
	_hint_lbl.offset_bottom = 94
	_hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_lbl.add_theme_font_size_override("font_size", 20)
	_hint_lbl.add_theme_color_override("font_color", Color(0.70, 0.76, 0.96))
	_hint_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_lbl.text = "Tap a constellation to learn more"
	add_child(_hint_lbl)

	# ── Focus panel: large name ───────────────────────────────────────
	_focus_name_lbl = Label.new()
	_focus_name_lbl.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_focus_name_lbl.offset_top = 96
	_focus_name_lbl.offset_bottom = 146
	_focus_name_lbl.offset_left = -560
	_focus_name_lbl.offset_right = 560
	_focus_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_focus_name_lbl.add_theme_font_size_override("font_size", 42)
	_focus_name_lbl.add_theme_color_override("font_color", Color(1.0, 0.87, 0.38))
	_focus_name_lbl.visible = false
	_focus_name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_focus_name_lbl)

	# ── Focus panel: description ──────────────────────────────────────
	_focus_desc_lbl = Label.new()
	_focus_desc_lbl.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_focus_desc_lbl.offset_top = 152
	_focus_desc_lbl.offset_bottom = 248
	_focus_desc_lbl.offset_left = -500
	_focus_desc_lbl.offset_right = 500
	_focus_desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_focus_desc_lbl.add_theme_font_size_override("font_size", 17)
	_focus_desc_lbl.add_theme_color_override("font_color",
		Color(0.76, 0.82, 0.96, 0.92))
	_focus_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_focus_desc_lbl.visible = false
	_focus_desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_focus_desc_lbl)

	# ── Latitude selection row ────────────────────────────────────────
	_build_lat_row()

	# ── Zoom in / out buttons (top-right) ─────────────────────────────
	_zoom_in_btn = _make_btn("\u2295", 28)   # ⊕
	_zoom_in_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_zoom_in_btn.offset_left = -108
	_zoom_in_btn.offset_right = -16
	_zoom_in_btn.offset_top = 20
	_zoom_in_btn.offset_bottom = 52
	_zoom_in_btn.custom_minimum_size = Vector2(92, 52)
	_zoom_in_btn.pressed.connect(func() -> void: _step_zoom(-1))
	add_child(_zoom_in_btn)

	_zoom_out_btn = _make_btn("\u2296", 28)  # ⊖
	_zoom_out_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_zoom_out_btn.offset_left = -108
	_zoom_out_btn.offset_right = -16
	_zoom_out_btn.offset_top = 58
	_zoom_out_btn.offset_bottom = 90
	_zoom_out_btn.custom_minimum_size = Vector2(92, 52)
	_zoom_out_btn.pressed.connect(func() -> void: _step_zoom(1))
	add_child(_zoom_out_btn)
	_sync_zoom_buttons()

	# ── Virtual joystick (bottom-right) ──────────────────────────────
	_build_joystick()


func _build_joystick() -> void:
	## Outer ring — a semi-transparent dark circle.
	var ring_diam := JOY_RING_R * 2.0
	_joy_ring = Panel.new()
	_joy_ring.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_joy_ring.offset_left = JOY_AX - JOY_RING_R
	_joy_ring.offset_right = JOY_AX + JOY_RING_R
	_joy_ring.offset_top = JOY_AY - JOY_RING_R
	_joy_ring.offset_bottom = JOY_AY + JOY_RING_R
	_joy_ring.custom_minimum_size = Vector2(ring_diam, ring_diam)
	_joy_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ring_sb := StyleBoxFlat.new()
	ring_sb.bg_color = Color(0.08, 0.12, 0.24, 0.55)
	ring_sb.border_color = Color(0.55, 0.65, 0.90, 0.60)
	ring_sb.set_border_width_all(2)
	ring_sb.set_corner_radius_all(int(JOY_RING_R))
	_joy_ring.add_theme_stylebox_override("panel", ring_sb)
	add_child(_joy_ring)

	# Cardinal direction labels inside the ring.
	for lbl_cfg in [
		["\u2191", Vector2(JOY_RING_R - 10, 4)],
		["\u2193", Vector2(JOY_RING_R - 10, ring_diam - 28)],
		["\u2190", Vector2(4, JOY_RING_R - 14)],
		["\u2192", Vector2(ring_diam - 24, JOY_RING_R - 14)],
	]:
		var lbl := Label.new()
		lbl.text = str(lbl_cfg[0])
		lbl.position = lbl_cfg[1] as Vector2
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.add_theme_color_override("font_color", Color(0.70, 0.80, 1.0, 0.60))
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_joy_ring.add_child(lbl)

	## Inner nub — smaller bright circle.
	var nub_diam := JOY_NUB_R * 2.0
	_joy_nub = Panel.new()
	_joy_nub.size = Vector2(nub_diam, nub_diam)
	_joy_nub.position = Vector2(JOY_RING_R - JOY_NUB_R, JOY_RING_R - JOY_NUB_R)
	_joy_nub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var nub_sb := StyleBoxFlat.new()
	nub_sb.bg_color = Color(0.60, 0.72, 0.96, 0.88)
	nub_sb.set_corner_radius_all(int(JOY_NUB_R))
	_joy_nub.add_theme_stylebox_override("panel", nub_sb)
	_joy_ring.add_child(_joy_nub)


func _build_lat_row() -> void:
	_lat_row = Control.new()
	_lat_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_lat_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_lat_row)

	var row := HBoxContainer.new()
	row.position = Vector2(24, 470)
	row.add_theme_constant_override("separation", 10)
	_lat_row.add_child(row)

	for c in LAT_CHOICES:
		var lat: float = float(c[0])
		var btn := Button.new()
		btn.text = "%s\n%s" % [str(c[1]), str(c[2])]
		btn.custom_minimum_size = Vector2(186, 62)
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_size_override("font_size", 16)
		btn.pressed.connect(func() -> void: _set_latitude(lat))
		row.add_child(btn)
		_lat_btns[lat] = btn
	_sync_lat_buttons()


func _set_latitude(lat: float) -> void:
	_lat = lat
	_sync_lat_buttons()
	# If focused, the camera re-aims from the same constellation but with the
	# new up vector — the view appears to flip when crossing the equator.


func _sync_lat_buttons() -> void:
	for lat in _lat_btns:
		var btn: Button = _lat_btns[lat] as Button
		var on: bool = is_equal_approx(float(lat), _lat)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.95, 0.86, 0.45, 0.96) if on \
			else Color(0.13, 0.18, 0.30, 0.90)
		sb.set_corner_radius_all(14)
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_color_override("font_color",
			Color(0.06, 0.08, 0.12) if on else Color(0.82, 0.88, 0.98))


## Consistent button styling for every HUD control.
func _make_btn(text: String, font_size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", font_size)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.14, 0.26, 0.88)
	sb.set_corner_radius_all(14)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_color_override("font_color", Color(0.90, 0.94, 1.0))
	return b

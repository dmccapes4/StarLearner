class_name ConstellationScene
extends Control
## Night-sky mode: twelve zodiac asterisms on the outer ecliptic shell.
## Tap a sign to fly there, hear astronomy + astrology, then a season
## cinematic: Earth arrives on its real orbit (constellation naturally on
## the far shell), then the camera looks from Earth's perspective.

const ZodiacDataScript := preload("res://scripts/ZodiacData.gd")

signal go_home()

const LINE_WELCOME := "Welcome to the zodiac sky! Tap a constellation to fly there and learn its stars, its season, and what astrology says about the sign."
const SEEK_SPEED := 160.0
const SEEK_TURN := 2.4
const TAP_RADIUS_PX := 90.0
const ARRIVE_FRAC := 0.12   ## park this fraction of shell-radius from the asterism
const CINE_WIDE_S := 3.4
const CINE_LOOK_S := 2.8

enum State { FLYING, SEEKING, ARRIVING, EARTH_CINE, IDLE }

var _active: bool = false
var _state: State = State.FLYING
var _viewport: SubViewport
var _host: SubViewportContainer
var _world: Node3D
var _cam: Camera3D
var _signs: Dictionary = {}   ## id → {root, data}
var _ring_r: float = ZodiacDataScript.RING_R
var _ship_pos: Vector3 = Vector3.ZERO
var _yaw: float = 0.0
var _pitch: float = 0.0
var _seek_id: String = ""
var _sun: MeshInstance3D
var _earth: MeshInstance3D
var _earth_label: Label3D
var _hint: Label
var _title: Label
var _panel: Control
var _panel_title: Label
var _panel_body: Label
var _continue_btn: Button
var _home_btn: Button
var _tap_guard: float = 0.0
var _cine_t: float = 0.0
var _cine_phase: int = 0   ## 0 = Earth arrives in season; 1 = look from Earth
var _cine_from: Vector3 = Vector3.ZERO
var _cine_to: Vector3 = Vector3.ZERO
var _cine_look_from: Vector3 = Vector3.ZERO
var _cine_look_to: Vector3 = Vector3.ZERO
var _cine_earth_from: Vector3 = Vector3.ZERO
var _cine_earth_to: Vector3 = Vector3.ZERO
var _cine_sign_center: Vector3 = Vector3.ZERO
var _vo_queue: Array = []
var _vo_wait: float = 0.0
var _visit_id: String = ""

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()

func set_active(on: bool) -> void:
	_active = on
	visible = on
	if _viewport != null:
		_viewport.render_target_update_mode = (
			SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED)
	if not on:
		Narrator.stop()
		_state = State.FLYING
		_seek_id = ""
		_vo_queue.clear()
		if _panel != null:
			_panel.visible = false

func begin() -> void:
	set_active(true)
	_state = State.FLYING
	_seek_id = ""
	_visit_id = ""
	var er: float = ZodiacDataScript.earth_orbit_radius(_ring_r)
	_ship_pos = Vector3(0.0, er * 0.35, er * 0.75)
	_yaw = 0.0
	_pitch = -0.12
	_earth.visible = false
	_earth_label.visible = false
	if _sun != null:
		_sun.visible = true
	_panel.visible = false
	_vo_queue.clear()
	_hint.text = "Tap a constellation"
	_title.text = "Zodiac Sky"
	_place_cam()
	Narrator.speak(LINE_WELCOME)

## Jump straight into one sign's lesson (from Free Flight tap / Earth tiles).
func begin_at(sign_id: String) -> void:
	begin()
	Narrator.stop()
	if not _signs.has(sign_id):
		return
	_arrive(sign_id)

func _process(delta: float) -> void:
	if not _active:
		return
	_tap_guard = maxf(0.0, _tap_guard - delta)
	_tick_vo(delta)
	match _state:
		State.FLYING:
			_fly_idle(delta)
		State.SEEKING:
			_seek_tick(delta)
		State.ARRIVING:
			pass
		State.EARTH_CINE:
			_earth_cine_tick(delta)
		State.IDLE:
			pass
	_spin_earth(delta)

func _fly_idle(delta: float) -> void:
	# Gentle drift so the sky feels alive while waiting for a tap.
	_yaw += 0.015 * delta
	_place_cam()

func _seek_tick(delta: float) -> void:
	if _seek_id.is_empty() or not _signs.has(_seek_id):
		_state = State.FLYING
		return
	var target: Vector3 = ZodiacDataScript.center_of(_signs[_seek_id]["data"])
	var to: Vector3 = target - _ship_pos
	var dist: float = to.length()
	if dist < 0.05:
		_arrive(_seek_id)
		return
	var desired: Vector3 = to / dist
	var want_yaw: float = atan2(-desired.x, -desired.z)
	var want_pitch: float = asin(clampf(desired.y, -0.9, 0.9))
	var k: float = 1.0 - exp(-SEEK_TURN * delta)
	_yaw = lerp_angle(_yaw, want_yaw, k)
	_pitch = lerpf(_pitch, want_pitch, k)
	_ship_pos += _heading() * SEEK_SPEED * delta
	_place_cam()
	if dist <= _ring_r * ARRIVE_FRAC:
		_arrive(_seek_id)

func _arrive(id: String) -> void:
	_state = State.ARRIVING
	_seek_id = ""
	_visit_id = id
	var data: Dictionary = _signs[id]["data"]
	var center: Vector3 = ZodiacDataScript.center_of(data)
	# Park inside the shell looking out at the asterism (not past the stars).
	var outward: Vector3 = center.normalized()
	var standoff: float = _ring_r * ARRIVE_FRAC
	_ship_pos = center - outward * standoff + Vector3(0.0, standoff * 0.12, 0.0)
	_look_at_point(center)
	_place_cam()
	_hint.text = str(data["name"])
	_title.text = "%s  %s" % [str(data["symbol"]), str(data["name"])]
	_queue_vo([
		str(data["line_arrive"]),
		str(data["astronomy"]),
		str(data["line_astro"]),
	])
	_vo_queue.append({"kind": "earth_cine", "id": id})

func _start_earth_cine(id: String) -> void:
	if not _signs.has(id):
		_finish_visit(id)
		return
	_state = State.EARTH_CINE
	_cine_phase = 0
	_cine_t = 0.0
	var data: Dictionary = _signs[id]["data"]
	var long_deg: float = float(data.get("long_deg", 0.0))
	_cine_sign_center = ZodiacDataScript.center_of(data)
	var earth_r: float = ZodiacDataScript.earth_orbit_radius(_ring_r)
	_cine_earth_to = ZodiacDataScript.earth_season_pos(long_deg, earth_r)
	# Start a quarter-orbit away so the arrival reads clearly.
	_cine_earth_from = ZodiacDataScript.earth_season_pos(long_deg + 90.0, earth_r)
	_earth.global_position = _cine_earth_from
	_earth.visible = true
	_earth_label.visible = true
	_earth_label.global_position = _cine_earth_from + Vector3(0.0, earth_r * 0.08, 0.0)
	if _sun != null:
		_sun.visible = true
	# Wide high view: Sun + Earth path + constellation already on the shell.
	_cine_from = Vector3(0.0, earth_r * 1.55, earth_r * 1.85)
	_cine_to = _cine_from
	_cine_look_from = Vector3.ZERO
	_cine_look_to = Vector3.ZERO
	_ship_pos = _cine_from
	_look_at_point(_cine_look_from)
	_place_cam()
	_hint.text = "Earth arrives in season for %s" % str(data["name"])
	Narrator.speak(str(data["line_earth"]))

func _earth_cine_tick(delta: float) -> void:
	var dur: float = CINE_WIDE_S if _cine_phase == 0 else CINE_LOOK_S
	_cine_t = minf(1.0, _cine_t + delta / maxf(dur, 0.1))
	var u: float = _cine_t * _cine_t * (3.0 - 2.0 * _cine_t)
	if _cine_phase == 0:
		# Phase 0: Earth moves into seasonal place; constellation stays on shell.
		_earth.global_position = _cine_earth_from.lerp(_cine_earth_to, u)
		_earth_label.global_position = _earth.global_position \
			+ Vector3(0.0, ZodiacDataScript.earth_orbit_radius(_ring_r) * 0.08, 0.0)
		_ship_pos = _cine_from
		_look_at_point(_cine_look_from)
		_place_cam()
		if _cine_t >= 1.0:
			_cine_phase = 1
			_cine_t = 0.0
			_cine_from = _ship_pos
			# Near Earth, looking past the Sun toward the constellation.
			var outward: Vector3 = _cine_sign_center.normalized()
			var earth_r: float = ZodiacDataScript.earth_orbit_radius(_ring_r)
			_cine_to = _cine_earth_to + Vector3(0.0, earth_r * 0.045, 0.0) \
				- outward * (earth_r * 0.12)
			_cine_look_from = Vector3.ZERO
			_cine_look_to = _cine_sign_center
			_hint.text = "From Earth — looking toward %s" % str(
				_signs[_visit_id]["data"].get("name", "the stars") \
				if _signs.has(_visit_id) else "the stars")
	else:
		_earth.global_position = _cine_earth_to
		_earth_label.global_position = _cine_earth_to \
			+ Vector3(0.0, ZodiacDataScript.earth_orbit_radius(_ring_r) * 0.08, 0.0)
		_ship_pos = _cine_from.lerp(_cine_to, u)
		var look: Vector3 = _cine_look_from.lerp(_cine_look_to, u)
		_look_at_point(look)
		_place_cam()
		if _cine_t >= 1.0 and not Narrator.is_playing():
			_finish_visit(_visit_id)

func _finish_visit(id: String) -> void:
	_state = State.IDLE
	_visit_id = id
	var data: Dictionary = _signs[id]["data"] if _signs.has(id) else {}
	_panel_title.text = "%s  %s" % [
		str(data.get("symbol", "")), str(data.get("name", "Sign"))]
	_panel_body.text = (
		"Season: %s\n%s\n\n%s"
		% [str(data.get("months", "")), str(data.get("hemisphere", "")),
			str(data.get("astrology", ""))])
	_panel.visible = true
	_hint.text = "Keep exploring — tap another sign"

func _tick_vo(delta: float) -> void:
	if _vo_wait > 0.0:
		_vo_wait -= delta
		return
	if Narrator.is_playing():
		return
	if _vo_queue.is_empty():
		return
	var next = _vo_queue.pop_front()
	if typeof(next) == TYPE_DICTIONARY:
		if str(next.get("kind", "")) == "earth_cine":
			_visit_id = str(next.get("id", ""))
			_start_earth_cine(_visit_id)
		return
	Narrator.speak(str(next))
	_vo_wait = 0.15

func _queue_vo(lines: Array) -> void:
	_vo_queue.clear()
	for line in lines:
		_vo_queue.append(line)

func _heading() -> Vector3:
	return Vector3(
		-sin(_yaw) * cos(_pitch), sin(_pitch), -cos(_yaw) * cos(_pitch)).normalized()

func _look_at_point(p: Vector3) -> void:
	var to: Vector3 = p - _ship_pos
	if to.length() < 0.01:
		return
	var n := to.normalized()
	_yaw = atan2(-n.x, -n.z)
	_pitch = asin(clampf(n.y, -0.9, 0.9))

func _place_cam() -> void:
	_cam.global_position = _ship_pos
	_cam.look_at(_ship_pos + _heading(), Vector3.UP)

func _spin_earth(delta: float) -> void:
	if _earth != null and _earth.visible:
		_earth.rotate_y(0.35 * delta)

func _gui_input(event: InputEvent) -> void:
	if not _active:
		return
	var tap := false
	var pos := Vector2.ZERO
	if event is InputEventScreenTouch and event.pressed:
		tap = true
		pos = event.position
		_tap_guard = 0.28
	elif event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _tap_guard > 0.0:
			return
		tap = true
		pos = event.position
	if not tap:
		return
	if _panel.visible:
		return
	if _state == State.ARRIVING or _state == State.EARTH_CINE:
		return
	var vp_pos := _map_to_viewport(pos)
	var id := _sign_at_screen(vp_pos)
	if id.is_empty():
		if _state == State.SEEKING:
			_seek_id = ""
			_state = State.FLYING
			_hint.text = "Tap a constellation"
			Narrator.speak("Okay — keep exploring!")
		return
	_begin_seek(id)

func _begin_seek(id: String) -> void:
	if not _signs.has(id):
		return
	_earth.visible = false
	_earth_label.visible = false
	_panel.visible = false
	_vo_queue.clear()
	Narrator.stop()
	_seek_id = id
	_visit_id = id
	_state = State.SEEKING
	var data: Dictionary = _signs[id]["data"]
	_hint.text = "→ %s" % str(data["name"])
	Narrator.speak(str(data["line_seek"]))

func _map_to_viewport(local: Vector2) -> Vector2:
	var hs: Vector2 = _host.size
	if hs.x < 1.0 or hs.y < 1.0:
		return local
	var vs := Vector2(_viewport.size)
	return Vector2(local.x / hs.x * vs.x, local.y / hs.y * vs.y)

func _sign_at_screen(vp_pos: Vector2) -> String:
	var best := ""
	var best_d := TAP_RADIUS_PX
	for id in _signs:
		var center: Vector3 = ZodiacDataScript.center_of(_signs[id]["data"])
		if _cam.is_position_behind(center):
			continue
		var d: float = _cam.unproject_position(center).distance_to(vp_pos)
		if d < best_d:
			best_d = d
			best = id
	return best

func _build() -> void:
	_host = SubViewportContainer.new()
	_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_host.stretch = true
	_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_host)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1280, 600)
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_host.add_child(_viewport)

	_world = Node3D.new()
	_viewport.add_child(_world)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.01, 0.015, 0.04)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.15, 0.18, 0.28)
	e.ambient_light_energy = 0.55
	env.environment = e
	_world.add_child(env)

	var sun_light := OmniLight3D.new()
	sun_light.light_color = Color(1.0, 0.95, 0.85)
	sun_light.light_energy = 2.2
	sun_light.omni_range = 2800.0
	_world.add_child(sun_light)

	_sun = MeshInstance3D.new()
	var sun_mesh := SphereMesh.new()
	sun_mesh.radius = 14.0
	sun_mesh.height = 28.0
	sun_mesh.radial_segments = 20
	sun_mesh.rings = 10
	_sun.mesh = sun_mesh
	var sun_mat := StandardMaterial3D.new()
	sun_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sun_mat.albedo_color = Color(1.0, 0.92, 0.45)
	sun_mat.emission_enabled = true
	sun_mat.emission = Color(1.0, 0.85, 0.3)
	sun_mat.emission_energy_multiplier = 2.2
	_sun.material_override = sun_mat
	_sun.visible = true
	_world.add_child(_sun)

	_add_background_stars()
	_build_signs()
	_build_earth()

	_cam = Camera3D.new()
	_cam.fov = 68.0
	_cam.near = 0.2
	_cam.far = 5000.0
	_world.add_child(_cam)
	_cam.current = true

	_title = Label.new()
	_title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_title.offset_top = 12
	_title.offset_bottom = 52
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 30)
	_title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55))
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title)

	_hint = Label.new()
	_hint.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_hint.offset_top = 52
	_hint.offset_bottom = 86
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 20)
	_hint.add_theme_color_override("font_color", Color(0.8, 0.88, 1.0))
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)

	_home_btn = Button.new()
	_home_btn.text = "\u25C0"
	_home_btn.size = Vector2(84, 66)
	_home_btn.position = Vector2(20, 20)
	_home_btn.focus_mode = Control.FOCUS_NONE
	_home_btn.add_theme_font_size_override("font_size", 28)
	var hsb := StyleBoxFlat.new()
	hsb.bg_color = Color(0.95, 0.86, 0.45, 0.98)
	hsb.set_corner_radius_all(16)
	_home_btn.add_theme_stylebox_override("normal", hsb)
	_home_btn.pressed.connect(func() -> void:
		Narrator.stop()
		go_home.emit())
	add_child(_home_btn)

	_panel = PanelContainer.new()
	_panel.visible = false
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(520, 280)
	_panel.offset_left = -260
	_panel.offset_top = -140
	_panel.offset_right = 260
	_panel.offset_bottom = 140
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.06, 0.08, 0.16, 0.92)
	psb.set_corner_radius_all(18)
	psb.set_border_width_all(2)
	psb.border_color = Color(1.0, 0.85, 0.35, 0.75)
	_panel.add_theme_stylebox_override("panel", psb)
	add_child(_panel)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 10)
	_panel.add_child(pv)
	_panel_title = Label.new()
	_panel_title.add_theme_font_size_override("font_size", 28)
	_panel_title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.5))
	_panel_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pv.add_child(_panel_title)
	_panel_body = Label.new()
	_panel_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel_body.add_theme_font_size_override("font_size", 18)
	_panel_body.add_theme_color_override("font_color", Color(0.9, 0.93, 1.0))
	_panel_body.custom_minimum_size = Vector2(480, 140)
	pv.add_child(_panel_body)
	_continue_btn = Button.new()
	_continue_btn.text = "Keep exploring"
	_continue_btn.focus_mode = Control.FOCUS_NONE
	_continue_btn.custom_minimum_size = Vector2(200, 48)
	_continue_btn.pressed.connect(func() -> void:
		_panel.visible = false
		_earth.visible = false
		_earth_label.visible = false
		_state = State.FLYING
		_hint.text = "Tap a constellation")
	pv.add_child(_continue_btn)

func _add_background_stars() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 160:
		var m := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = rng.randf_range(0.35, 1.1)
		s.height = s.radius * 2.0
		s.radial_segments = 4
		s.rings = 2
		m.mesh = s
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var b: float = rng.randf_range(0.55, 1.0)
		mat.albedo_color = Color(b, b, 1.0)
		m.material_override = mat
		var dir := Vector3(
			rng.randf_range(-1.0, 1.0),
			rng.randf_range(-0.55, 0.55),
			rng.randf_range(-1.0, 1.0)).normalized()
		# Far behind the zodiac shell so asterisms stay the outer teaching layer.
		m.position = dir * rng.randf_range(_ring_r * 1.35, _ring_r * 1.85)
		_world.add_child(m)

func _build_signs() -> void:
	_ring_r = ZodiacDataScript.RING_R
	_signs = ZodiacDataScript.build_sky(_world, _ring_r)

func _build_earth() -> void:
	_earth = MeshInstance3D.new()
	var sm := SphereMesh.new()
	var er: float = maxf(5.5, ZodiacDataScript.earth_orbit_radius(_ring_r) * 0.04)
	sm.radius = er
	sm.height = er * 2.0
	sm.radial_segments = 24
	sm.rings = 12
	_earth.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.45, 0.85)
	mat.emission_enabled = true
	mat.emission = Color(0.1, 0.25, 0.55)
	mat.emission_energy_multiplier = 0.4
	_earth.material_override = mat
	_earth.visible = false
	_world.add_child(_earth)
	_earth_label = Label3D.new()
	_earth_label.text = "Earth"
	_earth_label.font_size = 42
	_earth_label.modulate = Color(0.6, 0.85, 1.0)
	_earth_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_earth_label.visible = false
	_world.add_child(_earth_label)

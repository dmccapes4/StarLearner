class_name PlotBoard
extends Control
## Top-down course plot after the horizontal ScrollView picks a destination.
## Owns choreography (chart → fast-forward lead → ship run → GO).

signal go_home()
signal course_committed(dest_id: String, route: Dictionary, t0: float)

enum Phase { IDLE, CHART, LEAD, PREVIEW, READY }

const AUTO_GO_DELAY := 2.4

var _cfg: SolarFlyerConfig
var _bodies: OrreryBodies
var _hint: Label
var _go_btn: Button
var _phase: Phase = Phase.IDLE
var _ship_id: String = "earth"
var _dest_id: String = ""
var _route: Dictionary = {}
var _t0: float = 0.0
var _auto_go_left: float = -1.0
var _active: bool = false
var _chart_s: float = 2.5
var _lead_s: float = 2.0
var _preview_s: float = 2.5

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_cfg = SolarFlyerConfig.load_default()

	_bodies = OrreryBodies.new()
	_bodies.cfg = _cfg
	_bodies.set_mode(OrreryBodies.Mode.PLOT)
	_bodies.running = false
	add_child(_bodies)

	_hint = Label.new()
	_hint.text = ""
	_hint.add_theme_font_size_override("font_size", 24)
	_hint.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	_hint.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.position = Vector2(0, 14)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)

	_go_btn = _make_go()
	add_child(_go_btn)
	add_child(_make_home())
	gui_input.connect(_on_gui_input)

func begin() -> void:
	## Idle top-down (rarely used — prefer begin_plot from ScrollView).
	_active = true
	visible = true
	_cfg = SolarFlyerConfig.load_default()
	_bodies.cfg = _cfg
	_bodies.set_mode(OrreryBodies.Mode.PLOT)
	_bodies.ship_id = _ship_id
	_bodies.running = true
	_bodies.clear_route()
	_bodies.visible = true
	_phase = Phase.IDLE
	_dest_id = ""
	_route = {}
	_auto_go_left = -1.0
	_go_btn.visible = false
	_hint.text = "Tap a planet to plot a course"

## Start the top-down intercept lesson for a destination chosen on the strip.
func begin_plot(dest_id: String) -> void:
	_active = true
	visible = true
	_cfg = SolarFlyerConfig.load_default()
	_bodies.cfg = _cfg
	_bodies.set_mode(OrreryBodies.Mode.PLOT)
	_bodies.ship_id = _ship_id
	_bodies.running = true
	_bodies.visible = true
	_go_btn.visible = false
	_plot_to(dest_id)

func set_active(on: bool) -> void:
	_active = on
	_bodies.running = on
	if not on:
		Narrator.stop()
		_auto_go_left = -1.0
		visible = false
	else:
		visible = true

func set_ship_at(id: String) -> void:
	_ship_id = id
	_bodies.ship_id = id

func _process(delta: float) -> void:
	if not _active:
		return
	match _phase:
		Phase.CHART:
			_bodies.course_draw_u = minf(1.0,
				_bodies.course_draw_u + delta / maxf(_chart_s, 0.1))
			_bodies.eta_lit = int(round(_bodies.course_draw_u * float(OrreryBodies.ETA_PIP_COUNT)))
			if _bodies.course_draw_u >= 1.0:
				_phase = Phase.LEAD
				_hint.text = "Watch — we aim ahead of where it's going"
		Phase.LEAD:
			_bodies.ff_u = minf(1.0, _bodies.ff_u + delta / maxf(_lead_s, 0.1))
			if _bodies.ff_u >= 1.0:
				_phase = Phase.PREVIEW
				_bodies.ship_preview_u = 0.0
				_hint.text = "Ship checks the path…"
		Phase.PREVIEW:
			_bodies.ship_preview_u = minf(1.0,
				_bodies.ship_preview_u + delta / maxf(_preview_s, 0.1))
			if _bodies.ship_preview_u >= 1.0:
				_phase = Phase.READY
				_go_btn.visible = true
				_hint.text = "Ready — tap GO to fly!"
				_auto_go_left = AUTO_GO_DELAY
				_bodies.eta_lit = _eta_pips_for_duration(float(_route.get("duration", 20.0)))
		Phase.READY:
			if _auto_go_left >= 0.0:
				_auto_go_left -= delta
				if _auto_go_left <= 0.0:
					_commit()
		_:
			pass

func _eta_pips_for_duration(dur: float) -> int:
	var u: float = inverse_lerp(_cfg.hop_min_s, _cfg.hop_max_s, dur)
	return clampi(int(round(lerpf(1.0, float(OrreryBodies.ETA_PIP_COUNT), clampf(u, 0.0, 1.0)))), 1,
		OrreryBodies.ETA_PIP_COUNT)

static func plot_beat_seconds(duration: float) -> Dictionary:
	var dur := maxf(duration, 1.0)
	var chart := clampf(dur * 0.14, 1.3, 5.5)
	var lead := clampf(dur * 0.10, 1.0, 4.0)
	var preview := clampf(dur * 0.12, 1.4, 5.0)
	return {"chart": chart, "lead": lead, "preview": preview}

func _on_gui_input(event: InputEvent) -> void:
	if not _active:
		return
	var tap := false
	var pos := Vector2.ZERO
	if event is InputEventScreenTouch and not event.pressed:
		tap = true
		pos = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		tap = true
		pos = event.position
	if not tap:
		return
	if _go_btn.visible and Rect2(_go_btn.position, _go_btn.size).has_point(pos):
		return
	var id := _bodies.hit_test(pos)
	if id.is_empty() or id == _ship_id:
		return
	_plot_to(id)

func _plot_to(id: String) -> void:
	var target := SolarData.flyer_body_by_id(id, _cfg)
	var origin := SolarData.flyer_body_by_id(_ship_id, _cfg)
	if target.is_empty() or origin.is_empty():
		return
	_t0 = _bodies.t if _bodies.t > 0.0 else 0.0
	# Prefer leaving the Sun along the destination's current radial so the
	# departure doesn't look like it pops out of nowhere at +X.
	var prefer := OrbitMath.body_pos(target, _t0)
	if prefer.length() < 0.001:
		prefer = Vector3.RIGHT
	var ship_pos := OrbitMath.park_pos(origin, _t0, _cfg, prefer)
	var depart := 0.0
	if not bool(origin.get("is_star", false)):
		depart = OrbitMath.orbit_standoff(float(origin.get("hero_r", 2.0)))
	_route = OrbitMath.plot_route(ship_pos, target, _t0, _cfg, depart)
	_route["travel_au"] = absf(float(target.get("a_au", 0.0)) - float(origin.get("a_au", 0.0)))
	_route["origin_id"] = _ship_id
	_route["dest_name"] = str(target.get("name", id))
	_dest_id = id
	_auto_go_left = -1.0
	_go_btn.visible = false
	_bodies.ship_id = _ship_id
	_bodies.set_route(id, _route, _t0)
	var beats := plot_beat_seconds(float(_route.get("duration", 20.0)))
	_chart_s = float(beats["chart"])
	_lead_s = float(beats["lead"])
	_preview_s = float(beats["preview"])
	_phase = Phase.CHART
	_hint.text = "Plotting a course to %s…" % str(target["name"])
	Narrator.speak(OrbitMath.trip_narration(origin, target, _route, _cfg))

func _commit() -> void:
	if _dest_id.is_empty() or _route.is_empty():
		return
	_auto_go_left = -1.0
	_go_btn.visible = false
	course_committed.emit(_dest_id, _route, _t0)

func _make_go() -> Button:
	var b := Button.new()
	b.text = "GO  ▶"
	b.visible = false
	b.custom_minimum_size = Vector2(240, 96)
	b.size = Vector2(240, 96)
	b.position = Vector2(520, 470)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 40)
	b.add_theme_color_override("font_color", Color(0.08, 0.06, 0.02))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.45, 0.92, 0.55, 0.98)
	sb.set_corner_radius_all(24)
	sb.set_border_width_all(4)
	sb.border_color = Color(1, 1, 1, 0.95)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.pressed.connect(_commit)
	return b

func _make_home() -> Button:
	var b := Button.new()
	b.text = "\u25C0"
	b.custom_minimum_size = Vector2(84, 66)
	b.size = Vector2(84, 66)
	b.position = Vector2(20, 20)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 28)
	b.add_theme_color_override("font_color", Color(0.06, 0.05, 0.02))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.95, 0.86, 0.45, 0.98)
	sb.set_corner_radius_all(16)
	sb.set_border_width_all(3)
	sb.border_color = Color(1, 1, 1, 0.9)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.pressed.connect(func() -> void: go_home.emit())
	return b

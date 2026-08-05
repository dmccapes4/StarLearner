class_name PlotBoard
extends Control
## Top-down course plot after the horizontal ScrollView picks a destination.
## Owns choreography (chart+lead together → ship run → GO).

signal go_home()
signal course_committed(dest_id: String, route: Dictionary, t0: float)

enum Phase { IDLE, WINDOW, CHART, LEAD, PREVIEW, ARMING, READY }

const AUTO_GO_DELAY := 1.6
const ARMING_S := 3.2
## Wall seconds for the orrery *alignment* beat (last few years only).
const WINDOW_ALIGN_WALL_S := 5.5
## Years of true alignment shown on the orrery. Longer waits (Saturn→Neptune
## ~36 yr) calendar-skip the bulk so planets don't whip around.
const WINDOW_ALIGN_YR := 2.0
const WINDOW_SKIP_WALL_MIN_S := 1.8
const WINDOW_SKIP_WALL_MAX_S := 3.2
const WINDOW_MIN_YR := 0.02
const LINE_ENGINES := "Engines getting ready!"
const LINE_WINDOW := ("Planets have to line up just right. Watch the orrery — "
	+ "we're waiting for the next Hohmann launch window…")
const LINE_WINDOW_SKIP := ("That's a long wait — skipping ahead on the calendar "
	+ "to the years when the planets line up…")

enum WindowSub { SKIP, ALIGN }

var _cfg: SolarFlyerConfig
var _bodies: OrreryBodies
var _hint: Label
var _go_btn: Button
var _astro: AstrogatorPanel
var _window_callout: Label
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
var _arming_t: float = -1.0
var _arming_said: int = -1
## Session-persistent Astrogator choices (survive re-plots).
var _pace_mode: String = AstrogatorPanel.PACE_KID
var _propulsion_id: String = AstrogatorPanel.PROP_CHEMICAL
## Window wait choreography (Rocket Science only).
var _window_t0: float = 0.0
var _window_t1: float = 0.0
var _window_wait_yr: float = 0.0
var _window_elapsed: float = 0.0
var _window_wall: float = WINDOW_ALIGN_WALL_S
var _window_sub: int = WindowSub.ALIGN
var _window_skip_yr: float = 0.0
var _window_align_yr: float = WINDOW_ALIGN_YR
var _pending_plot_id: String = ""
var _pending_from_belt: bool = false

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

	_astro = AstrogatorPanel.new()
	_astro.position = Vector2(24, 330)
	_astro.size = Vector2(420, 200)
	_astro.set_locked(true)  ## pace/engines chosen before chart
	add_child(_astro)

	_window_callout = Label.new()
	_window_callout.visible = false
	_window_callout.text = ""
	_window_callout.add_theme_font_size_override("font_size", 22)
	_window_callout.add_theme_color_override("font_color", Color(1.0, 0.92, 0.45))
	_window_callout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_window_callout.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_window_callout.position = Vector2(0, 52)
	_window_callout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_window_callout)

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
	_astro.hide_panel()
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
	_astro.hide_panel()
	_plot_to(dest_id)

func set_active(on: bool) -> void:
	_active = on
	_bodies.running = on
	if not on:
		Narrator.stop()
		_auto_go_left = -1.0
		_astro.hide_panel()
		_window_callout.visible = false
		_bodies.window_guide = false
		visible = false
	else:
		visible = true

func set_ship_at(id: String) -> void:
	_ship_id = id
	_bodies.ship_id = id

## Called by Main after CourseModeChooser / PropulsionChooser — before begin_plot.
func set_mission_mode(pace_mode: String, propulsion_id: String) -> void:
	_pace_mode = pace_mode if pace_mode == AstrogatorPanel.PACE_ASTROGATOR \
		else AstrogatorPanel.PACE_KID
	_propulsion_id = propulsion_id if AstrogatorPanel.is_propulsion_id(propulsion_id) \
		else AstrogatorPanel.PROP_CHEMICAL
	_astro.set_session(_pace_mode, _propulsion_id)

func _process(delta: float) -> void:
	if not _active:
		return
	match _phase:
		Phase.WINDOW:
			_process_window(delta)
		Phase.CHART:
			# Ship course and destination orbit lead grow together — the
			# "aim ahead" lesson reads while the path is still drawing.
			_bodies.course_draw_u = minf(1.0,
				_bodies.course_draw_u + delta / maxf(_chart_s, 0.1))
			_bodies.ff_u = _bodies.course_draw_u
			_bodies.eta_lit = int(round(_bodies.course_draw_u * float(OrreryBodies.ETA_PIP_COUNT)))
			if _bodies.course_draw_u >= 1.0:
				_bodies.ff_u = 1.0
				_phase = Phase.PREVIEW
				_bodies.ship_preview_u = 0.0
				_hint.text = "Ship checks the path…"
		Phase.LEAD:
			# Legacy beat — chart already finishes the lead in sync.
			_bodies.ff_u = 1.0
			_phase = Phase.PREVIEW
			_bodies.ship_preview_u = 0.0
			_hint.text = "Ship checks the path…"
		Phase.PREVIEW:
			_bodies.ship_preview_u = minf(1.0,
				_bodies.ship_preview_u + delta / maxf(_preview_s, 0.1))
			if _bodies.ship_preview_u >= 1.0:
				# Arming: entry cinematic is already baked into the route at
				# plot time; this beat just sells "getting ready" with a
				# short countdown before GO.
				_phase = Phase.ARMING
				_arming_t = 0.0
				_arming_said = -1
				_go_btn.visible = false
				_show_astrogator()
				_hint.text = "Engines getting ready…"
				Narrator.speak(LINE_ENGINES)
				_bodies.eta_lit = _eta_pips_for_duration(float(_route.get("duration", 20.0)))
		Phase.ARMING:
			_arming_t += delta
			var left: int = maxi(int(ceil(ARMING_S - _arming_t)), 0)
			if left != _arming_said and left > 0:
				_arming_said = left
				_hint.text = "Engines getting ready… %d" % left
			if _arming_t >= ARMING_S:
				_phase = Phase.READY
				_go_btn.visible = true
				_show_astrogator()
				_hint.text = "Ready — tap GO to fly!"
				_auto_go_left = AUTO_GO_DELAY
		Phase.READY:
			if _auto_go_left >= 0.0:
				_auto_go_left -= delta
				if _auto_go_left <= 0.0:
					_commit()
		_:
			pass

func _process_window(delta: float) -> void:
	_window_elapsed += delta
	var u: float = clampf(_window_elapsed / maxf(_window_wall, 0.1), 0.0, 1.0)
	var su: float = u * u * (3.0 - 2.0 * u)
	_window_callout.visible = true
	if _window_sub == WindowSub.SKIP:
		# Calendar-only beat: orrery stays put so outer-planet waits (~36 yr)
		# don't look like a blender. Years tick down in the callout.
		var left_yr: float = lerpf(_window_wait_yr, _window_align_yr, su)
		_window_callout.text = ("Calendar skip — %.0f years until the launch window…"
			% maxf(left_yr, 0.0))
		_hint.text = "Skipping ahead to the launch window…"
		if u >= 1.0:
			_begin_window_align()
		return
	# ALIGN: last few years of true geometry on the orrery.
	_bodies.t = lerpf(_window_t0, _window_t1, su)
	var left_align: float = _window_align_yr * (1.0 - su)
	_window_callout.text = ("Launch window — planets lining up… %.1f years left"
		% maxf(left_align, 0.0))
	_hint.text = "Waiting for the Hohmann launch window…"
	if u >= 1.0:
		_bodies.t = _window_t1
		_finish_window_chart()

func _begin_window_align() -> void:
	var gys: float = maxf(_cfg.game_year_seconds, 0.001)
	_window_t0 = _window_t1 - _window_align_yr * gys
	_bodies.t = _window_t0
	_window_sub = WindowSub.ALIGN
	_window_elapsed = 0.0
	_window_wall = WINDOW_ALIGN_WALL_S
	_window_callout.text = ("Launch window — planets lining up… %.1f years left"
		% _window_align_yr)
	_hint.text = "Waiting for the Hohmann launch window…"
	Narrator.speak(LINE_WINDOW)

func _eta_pips_for_duration(dur: float) -> int:
	var u: float = inverse_lerp(_cfg.hop_min_s, _cfg.hop_max_s, dur)
	return clampi(int(round(lerpf(1.0, float(OrreryBodies.ETA_PIP_COUNT), clampf(u, 0.0, 1.0)))), 1,
		OrreryBodies.ETA_PIP_COUNT)

static func plot_beat_seconds(duration: float) -> Dictionary:
	var dur := maxf(duration, 1.0)
	# Chart stays on screen long enough to finish the whole arc + the
	# narration that explains it — outer hops used to feel truncated when
	# the line animation raced ahead of the VO.
	var chart := clampf(dur * 0.18, 2.2, 8.0)
	var lead := clampf(dur * 0.10, 1.2, 4.0)
	var preview := clampf(dur * 0.12, 1.6, 5.0)
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
	if _astro.visible and Rect2(_astro.position, _astro.size).has_point(pos):
		return
	var id := _bodies.hit_test(pos)
	if id.is_empty() or id == _ship_id:
		return
	_plot_to(id)

func _plot_to(id: String) -> void:
	var origin := SolarData.flyer_body_by_id(_ship_id, _cfg)
	if origin.is_empty():
		return
	var t_now: float = _bodies.t if _bodies.t > 0.0 else 0.0
	# The belt ring is not a place — a belt tap resolves to the nearest major
	# asteroid right now (STRATEGY §5.3), skipping the one we're parked at.
	var from_belt := false
	if id == "asteroid_belt":
		from_belt = true
		id = SolarData.nearest_major_asteroid(
			OrbitMath.body_pos(origin, t_now), t_now, _cfg, _ship_id)
		if id.is_empty():
			return
	var target := SolarData.flyer_body_by_id(id, _cfg)
	if target.is_empty():
		return
	var phase_now := AstrogatorPanel.phase_now_rad(origin, target, t_now)
	var budget_now: Dictionary = RealismBudget.hop_budget(origin, target, phase_now)
	var wait_yr: float = 0.0
	if bool(budget_now.get("ok", false)):
		wait_yr = float(budget_now.get("window_wait_yr", 0.0))
	var t_depart: float = t_now + wait_yr * _cfg.game_year_seconds
	_auto_go_left = -1.0
	_go_btn.visible = false
	_astro.hide_panel()
	_window_callout.visible = false
	# Rocket Science: wait for the Hohmann window, then chart there.
	# Long waits (Saturn→Neptune ~36 yr) calendar-skip first, then show only
	# the last ~2 years of alignment on the orrery — never whip all decades.
	if _pace_mode == AstrogatorPanel.PACE_ASTROGATOR and wait_yr >= WINDOW_MIN_YR:
		_pending_plot_id = id
		_pending_from_belt = from_belt
		_window_t0 = t_now
		_window_t1 = t_depart
		_window_wait_yr = wait_yr
		_window_elapsed = 0.0
		_window_align_yr = minf(wait_yr, WINDOW_ALIGN_YR)
		_window_skip_yr = maxf(wait_yr - _window_align_yr, 0.0)
		_bodies.clear_route()
		_bodies.ship_id = _ship_id
		_bodies.dest_id = id
		_bodies.highlight_id = id
		_bodies.window_guide = true
		_bodies.t = t_now
		_phase = Phase.WINDOW
		_dest_id = id
		_window_callout.visible = true
		if _window_skip_yr > 0.15:
			_window_sub = WindowSub.SKIP
			_window_wall = clampf(
				1.6 + _window_skip_yr * 0.035,
				WINDOW_SKIP_WALL_MIN_S, WINDOW_SKIP_WALL_MAX_S)
			_hint.text = "Skipping ahead to the launch window…"
			_window_callout.text = ("Calendar skip — %.0f years until the launch window…"
				% wait_yr)
			Narrator.speak(LINE_WINDOW_SKIP)
		else:
			_window_sub = WindowSub.ALIGN
			_window_wall = clampf(2.8 + wait_yr * 0.5, 3.5, WINDOW_ALIGN_WALL_S)
			_hint.text = "Waiting for the Hohmann launch window…"
			_window_callout.text = ("Launch window — planets lining up… %.1f years left"
				% wait_yr)
			Narrator.speak(LINE_WINDOW)
		return
	_chart_at(id, t_depart if _pace_mode == AstrogatorPanel.PACE_ASTROGATOR else t_now,
		from_belt, wait_yr if _pace_mode == AstrogatorPanel.PACE_ASTROGATOR else 0.0)

## QA / skip helper — jump the orrery to t_depart and chart immediately.
func finish_window_now() -> void:
	if _phase != Phase.WINDOW:
		return
	_window_sub = WindowSub.ALIGN
	_bodies.t = _window_t1
	_finish_window_chart()

func _finish_window_chart() -> void:
	var id := _pending_plot_id
	var from_belt := _pending_from_belt
	var wait_yr := _window_wait_yr
	var t_depart := _window_t1
	_pending_plot_id = ""
	_pending_from_belt = false
	_bodies.window_guide = false
	_window_callout.visible = false
	_window_callout.text = ""
	if id.is_empty():
		_phase = Phase.IDLE
		return
	_chart_at(id, t_depart, from_belt, wait_yr)

func _chart_at(id: String, t_depart: float, from_belt: bool, window_wait_yr: float) -> void:
	var origin := SolarData.flyer_body_by_id(_ship_id, _cfg)
	var target := SolarData.flyer_body_by_id(id, _cfg)
	if origin.is_empty() or target.is_empty():
		return
	_t0 = t_depart
	_bodies.t = t_depart
	_bodies.window_guide = false
	# Prefer leaving the Sun along the destination's radial at the departure epoch.
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
	var phase_depart := AstrogatorPanel.phase_now_rad(origin, target, _t0)
	var budget: Dictionary = RealismBudget.hop_budget(origin, target, phase_depart)
	# Keep the wait we actually animated (ledger "next window" at depart ≈ 0).
	if not budget.is_empty():
		budget = budget.duplicate(true)
		budget["window_wait_yr"] = window_wait_yr
		budget["window_wait_applied_yr"] = window_wait_yr
	_route["realism"] = budget
	_route["pace_mode"] = _pace_mode
	_route["propulsion_id"] = _propulsion_id
	_route["t_depart"] = _t0
	_route["window_wait_yr"] = window_wait_yr
	_dest_id = id
	_auto_go_left = -1.0
	_go_btn.visible = false
	_astro.hide_panel()
	_window_callout.visible = false
	_bodies.ship_id = _ship_id
	_bodies.set_route(id, _route, _t0)
	var beats := plot_beat_seconds(float(_route.get("duration", 20.0)))
	_chart_s = float(beats["chart"])
	_lead_s = float(beats["lead"])
	_preview_s = float(beats["preview"])
	_phase = Phase.CHART
	_hint.text = "Plotting a course to %s…" % str(target["name"])
	# Rocket Science engine/window/fuel briefing already ran before chart.
	var narr := OrbitMath.trip_narration(origin, target, _route, _cfg)
	if from_belt:
		narr = OrbitMath.belt_intro_sentence(target) + " " + narr
	Narrator.speak(narr)

func _show_astrogator() -> void:
	## Read-only ledger for Rocket Science; hidden for Quick Course.
	if _pace_mode != AstrogatorPanel.PACE_ASTROGATOR:
		_astro.hide_panel()
		return
	_astro.set_session(_pace_mode, _propulsion_id)
	var budget: Dictionary = _route.get("realism", {})
	if budget.is_empty():
		budget = {"ok": false, "error": "no budget"}
	_astro.show_for_route(budget)

func _commit() -> void:
	if _dest_id.is_empty() or _route.is_empty():
		return
	_auto_go_left = -1.0
	_go_btn.visible = false
	_astro.stamp_route(_route)
	_pace_mode = str(_route.get("pace_mode", AstrogatorPanel.PACE_KID))
	_propulsion_id = str(_route.get("propulsion_id", AstrogatorPanel.PROP_CHEMICAL))
	_astro.hide_panel()
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

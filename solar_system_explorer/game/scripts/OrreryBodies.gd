class_name OrreryBodies
extends Node2D
## Top-down orrery instrument.
## TOUR mode — narrated preview (legacy orrery_rx ellipses).
## PLOT mode — Beat B plotting board: compressed flyer radii, course line,
## arrival ghost, fast-forward lead of the target, ship preview, ETA pips.

enum Mode { TOUR, PLOT }

const CENTER_TOUR := Vector2(640, 312)
const CENTER_PLOT := Vector2(640, 292)
## True top-down for course plotting (was 0.42 squash — hard to read the line).
const FLATTEN_PLOT := 1.0
const FLATTEN_TOUR := 0.42
const BOARD_SCALE_DEFAULT := 2.0
## Half-width budget (px) for the farthest orbit on the plot board.
## Keeps the intercept marker + label clear of the hint text at the top.
const BOARD_FIT_PX := 246.0
const SHIP_PATH := "res://images/spaceship.png"
const ETA_PIP_COUNT := 5

var mode: Mode = Mode.TOUR
var t: float = 0.0
var running: bool = false
var highlight_id: String = ""
## Live plot zoom (shrinks for Uranus/Neptune/Pluto hops).
var board_scale: float = BOARD_SCALE_DEFAULT

## PLOT-mode state (ignored in TOUR).
var cfg: SolarFlyerConfig
var ship_id: String = "earth"
var dest_id: String = ""
var route: Dictionary = {}
var t0: float = 0.0
var course_draw_u: float = 0.0     ## 0..1 charting the course line
var ff_u: float = 0.0              ## 0..1 target drifts toward intercept
var ship_preview_u: float = -1.0   ## -1 idle; 0..1 ship runs the line
var eta_lit: int = 0               ## how many ETA pips are filled

var _orbiting: Array = []
var _belt: Dictionary = {}
var _belt_rocks: Array = []
var _flyer: Array = []
var _ship_tex: Texture2D

func _ready() -> void:
	_ship_tex = load(SHIP_PATH) as Texture2D
	# Respect mode if the parent called set_mode() before add_child.
	if mode == Mode.PLOT:
		if cfg == null:
			cfg = SolarFlyerConfig.load_default()
		_reload_plot_data()
	else:
		_reload_tour_data()

func _process(delta: float) -> void:
	if running:
		# In PLOT with an active route, freeze the live clock at t0 so the
		# lead/ghost stay readable; otherwise advance normally.
		if mode != Mode.PLOT or route.is_empty():
			t += delta
		queue_redraw()

func set_mode(m: Mode) -> void:
	mode = m
	if mode == Mode.PLOT:
		if cfg == null:
			cfg = SolarFlyerConfig.load_default()
		_reload_plot_data()
	else:
		_reload_tour_data()
	queue_redraw()

func set_highlight(id: String) -> void:
	highlight_id = id
	queue_redraw()

func clear_route() -> void:
	dest_id = ""
	route = {}
	course_draw_u = 0.0
	ff_u = 0.0
	ship_preview_u = -1.0
	eta_lit = 0
	board_scale = BOARD_SCALE_DEFAULT
	queue_redraw()

func set_route(dest: String, r: Dictionary, freeze_t: float) -> void:
	dest_id = dest
	route = r
	t0 = freeze_t
	t = freeze_t
	course_draw_u = 0.0
	ff_u = 0.0
	ship_preview_u = -1.0
	eta_lit = 0
	highlight_id = dest
	_refit_board_scale()
	queue_redraw()

## Zoom out so the ship→destination span (plus course bow) fits the panel.
func _refit_board_scale() -> void:
	var max_r: float = 40.0
	var origin := SolarData.flyer_body_by_id(ship_id, cfg)
	var target := SolarData.flyer_body_by_id(dest_id, cfg)
	if not origin.is_empty():
		max_r = maxf(max_r, float(origin.get("orbit_r", 0.0)))
	if not target.is_empty():
		max_r = maxf(max_r, float(target.get("orbit_r", 0.0)))
	# Measure the actual arc — its radius is bounded by the endpoint orbits.
	if not route.is_empty() and route.has("curve"):
		var curve: Curve3D = route["curve"]
		var n: int = curve.get_point_count()
		for i in n:
			max_r = maxf(max_r, curve.get_point_position(i).length())
	else:
		max_r *= 1.18
	board_scale = clampf(BOARD_FIT_PX / maxf(max_r, 1.0), 0.72, BOARD_SCALE_DEFAULT)

func hit_test(screen: Vector2) -> String:
	if mode == Mode.TOUR:
		return _hit_tour(screen)
	return _hit_plot(screen)

func _reload_tour_data() -> void:
	_orbiting = SolarData.orbiting()
	_belt = SolarData.belt()
	_belt_rocks = _make_belt_rocks(90, 12.0)

func _reload_plot_data() -> void:
	_flyer = SolarData.flyer_bodies(cfg)
	_belt = SolarData.flyer_body_by_id("asteroid_belt", cfg)
	_belt_rocks = _make_belt_rocks(90, 8.0)

func _make_belt_rocks(count: int, jitter: float) -> Array:
	var out: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	for i in count:
		out.append({
			"ang": rng.randf() * TAU,
			"jitter": rng.randf_range(-jitter, jitter),
			"size": rng.randf_range(1.4, 3.0),
		})
	return out

func _center() -> Vector2:
	return CENTER_PLOT if mode == Mode.PLOT else CENTER_TOUR

func _flatten() -> float:
	return FLATTEN_PLOT if mode == Mode.PLOT else FLATTEN_TOUR

func _draw() -> void:
	if mode == Mode.PLOT:
		_draw_plot()
	else:
		_draw_tour()

# ── TOUR (unchanged feel) ───────────────────────────────────────────

func _draw_tour() -> void:
	var c := _center()
	var flat := _flatten()
	draw_circle(c, 40.0, Color(1.0, 0.86, 0.35, 0.28))
	draw_circle(c, 30.0, Color(1.0, 0.80, 0.24))
	for b in _orbiting:
		var rx: float = float(b["orrery_rx"])
		_draw_orbit(c, rx, rx * flat, Color(0.5, 0.56, 0.85, 0.25), 1.5)
	_draw_belt_tour(c)
	for b in _orbiting:
		var rx: float = float(b["orrery_rx"])
		var ry: float = rx * flat
		var period: float = maxf(0.5, float(b["period"]))
		var ang: float = t * TAU / period + float(b["orbit_index"]) * 0.7
		var pos := c + Vector2(cos(ang) * rx, sin(ang) * ry)
		var pr := clampf(float(b["draw_radius"]) * 0.30, 6.0, 34.0)
		if str(b["id"]) == highlight_id:
			draw_arc(pos, pr + 9.0, 0.0, TAU, 40, Color(1, 1, 1, 0.9), 3.0)
		draw_circle(pos, pr, b["color"])
		if str(b["id"]) == highlight_id:
			_label(str(b["name"]), pos + Vector2(0, -pr - 16.0), 24)

func _draw_belt_tour(c: Vector2) -> void:
	if _belt.is_empty():
		return
	var flat := _flatten()
	var rx: float = float(_belt["orrery_rx"])
	var ry: float = rx * flat
	var hot := highlight_id == str(_belt["id"])
	var col := Color(0.85, 0.82, 0.72, 0.95) if hot else Color(0.66, 0.62, 0.55, 0.7)
	var spin := t * 0.05
	for rock in _belt_rocks:
		var a: float = float(rock["ang"]) + spin
		var j: float = float(rock["jitter"])
		var pos := c + Vector2(cos(a) * (rx + j), sin(a) * (ry + j * flat))
		draw_circle(pos, float(rock["size"]), col)
	if hot:
		_label(str(_belt["name"]), c + Vector2(0, -ry - 18.0), 24)

func _hit_tour(screen: Vector2) -> String:
	# Tour doesn't need picking; kept for API symmetry.
	return ""

# ── PLOT board ──────────────────────────────────────────────────────

func _draw_plot() -> void:
	var c := _center()
	var flat := _flatten()
	# Soft instrument plate.
	draw_rect(Rect2(-20, -20, 1320, 640), Color(0.02, 0.03, 0.08, 0.55))
	draw_circle(c, 38.0, Color(1.0, 0.86, 0.35, 0.22))
	draw_circle(c, 28.0, Color(1.0, 0.80, 0.24))

	for b in _flyer:
		if bool(b.get("is_star", false)):
			continue
		var r: float = float(b["orbit_r"]) * board_scale
		var col := Color(0.55, 0.85, 1.0, 0.38) if str(b["id"]) == dest_id \
			else Color(0.5, 0.62, 0.9, 0.28)
		_draw_orbit(c, r, r * flat, col, 2.4 if str(b["id"]) == dest_id else 1.6)

	_draw_belt_plot(c)

	if not route.is_empty():
		_draw_course_overlay(c)
		_draw_target_lead(c)

	for b in _flyer:
		if bool(b.get("is_star", false)) or bool(b.get("belt", false)):
			continue
		var pos := _body_screen(b, _body_time(b))
		var pr: float = clampf(float(b["hero_r"]) * 1.7, 6.0, 24.0)
		var is_origin := str(b["id"]) == ship_id
		var is_dest := str(b["id"]) == dest_id
		if is_origin or is_dest:
			draw_arc(pos, pr + 12.0, 0.0, TAU, 40, Color(1, 1, 1, 0.95), 3.5)
		draw_circle(pos, pr, b["color"])
		# Always label worlds on the top-down board so kids can tell them apart.
		_label(str(b["name"]), pos + Vector2(0, -pr - 14), 18 if is_dest or is_origin else 15)
		if is_origin:
			_label("you are here", pos + Vector2(0, pr + 20), 16)

	_draw_ship_marker()
	_draw_eta_pips()

func _body_time(b: Dictionary) -> float:
	## Destination uses fast-forward blend during the lead preview; others freeze at t0 once routed.
	if not route.is_empty() and str(b["id"]) == dest_id:
		var t_arr: float = float(route.get("t_arr", 0.0))
		return t0 + t_arr * clampf(ff_u, 0.0, 1.0)
	if not route.is_empty():
		return t0
	return t

func _body_screen(b: Dictionary, at_t: float) -> Vector2:
	return _to_screen(OrbitMath.body_pos(b, at_t))

func _to_screen(pos: Vector3) -> Vector2:
	return _center() + Vector2(pos.x, pos.z * _flatten()) * board_scale

func _draw_belt_plot(c: Vector2) -> void:
	if _belt.is_empty():
		return
	var flat := _flatten()
	var rx: float = float(_belt["orbit_r"]) * board_scale
	var ry: float = rx * flat
	var hot := dest_id == str(_belt["id"])
	var col := Color(0.85, 0.82, 0.72, 0.95) if hot else Color(0.66, 0.62, 0.55, 0.7)
	var spin := (t0 if not route.is_empty() else t) * 0.04
	for rock in _belt_rocks:
		var a: float = float(rock["ang"]) + spin
		var j: float = float(rock["jitter"])
		var pos := c + Vector2(cos(a) * (rx + j), sin(a) * (ry + j * flat))
		draw_circle(pos, float(rock["size"]), col)
	_label(str(_belt["name"]), c + Vector2(rx * 0.7, -ry - 10.0), 16)
	if hot:
		_label(str(_belt["name"]), c + Vector2(0, -ry - 18.0), 22)

func _draw_course_overlay(_c: Vector2) -> void:
	var curve: Curve3D = route["curve"]
	var arrival: Vector3 = route["arrival_pos"]
	var len: float = maxf(curve.get_baked_length(), 0.001)
	var until: float = clampf(course_draw_u, 0.0, 1.0)
	var pts := PackedVector2Array()
	var n := 64
	for i in n + 1:
		var u := float(i) / float(n) * until
		pts.append(_to_screen(curve.sample_baked(u * len)))
	if pts.size() >= 2:
		# Outer glow + bright core so the course reads on a busy board.
		draw_polyline(pts, Color(0.15, 0.55, 0.85, 0.55), 10.0, true)
		draw_polyline(pts, Color(0.55, 0.98, 1.0, 0.98), 5.0, true)
	# Ghost at intercept.
	var ghost := _to_screen(arrival)
	var ghost_col := Color(1, 1, 1, 0.14)
	var target := SolarData.flyer_body_by_id(dest_id, cfg)
	if not target.is_empty():
		ghost_col = Color(target["color"].r, target["color"].g, target["color"].b, 0.28)
	draw_circle(ghost, 18.0, ghost_col)
	draw_arc(ghost, 16.0, 0.0, TAU, 32, Color(0.7, 0.95, 1.0, 0.95), 2.5)
	_label("aim here", ghost + Vector2(0, -24), 18)

func _draw_target_lead(_c: Vector2) -> void:
	## Arc along the destination orbit from now → intercept (the "aim ahead" lesson).
	if dest_id.is_empty() or route.is_empty():
		return
	var target := SolarData.flyer_body_by_id(dest_id, cfg)
	if target.is_empty() or bool(target.get("belt", false)):
		return
	var t_arr: float = float(route.get("t_arr", 0.0))
	var until: float = clampf(ff_u, 0.0, 1.0)
	if until <= 0.001:
		return
	var pts := PackedVector2Array()
	var n := 36
	for i in n + 1:
		var u := float(i) / float(n) * until
		pts.append(_body_screen(target, t0 + t_arr * u))
	if pts.size() >= 2:
		draw_polyline(pts, Color(1.0, 0.75, 0.15, 0.55), 7.0, true)
		draw_polyline(pts, Color(1.0, 0.9, 0.4, 0.95), 3.5, true)

func _draw_ship_marker() -> void:
	var p := _ship_screen_pos()
	if _ship_tex != null:
		var sz := Vector2(56, 36)
		var rect := Rect2(p - sz * 0.5, sz)
		draw_texture_rect(_ship_tex, rect, false)
	else:
		draw_circle(p, 8.0, Color(0.95, 0.9, 0.4))
		draw_circle(p, 4.0, Color(1, 1, 1))

func _ship_screen_pos() -> Vector2:
	if not route.is_empty() and ship_preview_u >= 0.0:
		var curve: Curve3D = route["curve"]
		var len: float = maxf(curve.get_baked_length(), 0.001)
		return _to_screen(curve.sample_baked(clampf(ship_preview_u, 0.0, 1.0) * len))
	var origin := SolarData.flyer_body_by_id(ship_id, cfg)
	if origin.is_empty():
		return _center()
	return _body_screen(origin, t0 if not route.is_empty() else t)

func _draw_eta_pips() -> void:
	if route.is_empty():
		return
	var base := Vector2(520, 545)
	_label("trip time", base + Vector2(100, -8), 16)
	for i in ETA_PIP_COUNT:
		var p := base + Vector2(i * 36.0, 10.0)
		var on := i < eta_lit
		draw_circle(p, 10.0, Color(0.25, 0.35, 0.45, 0.9))
		if on:
			draw_circle(p, 8.0, Color(0.45, 0.95, 0.65, 0.98))

func _hit_plot(screen: Vector2) -> String:
	var best := ""
	var best_d := 56.0
	for b in _flyer:
		if bool(b.get("is_star", false)):
			continue
		var pos: Vector2
		if bool(b.get("belt", false)):
			# Belt: hit near the ring midpoint on the right for a generous target.
			pos = _to_screen(OrbitMath.body_pos(b, t0 if not route.is_empty() else t))
		else:
			pos = _body_screen(b, _body_time(b))
		var d: float = screen.distance_to(pos)
		var hit_r: float = 32.0 + float(b.get("hero_r", 1.0)) * 1.4
		if bool(b.get("belt", false)):
			hit_r = 44.0
		if d < hit_r and d < best_d:
			best_d = d
			best = str(b["id"])
	return best

func _draw_orbit(c: Vector2, rx: float, ry: float, col: Color, width: float) -> void:
	var pts := PackedVector2Array()
	for i in 64 + 1:
		var a := TAU * float(i) / 64.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_polyline(pts, col, width, true)

func _label(text: String, at: Vector2, fsize: int) -> void:
	var font := ThemeDB.fallback_font
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
	draw_string(font, at + Vector2(-w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize,
		Color(1, 1, 1, 0.95))

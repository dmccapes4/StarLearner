class_name EarthNightSkyScene
extends Control
## Earth night-sky chart: Gemini · Cancer · Canis Minor with Mars (Rx),
## the Moon, and Jupiter — as seen looking east before dawn from Napa, CA.
## Mars is rendered in apparent retrograde (westward loop through Gemini).

const ConstellationDataScript := preload("res://scripts/ConstellationData.gd")

signal closed()

## Predawn eastern sky — RA increases to the LEFT (Gemini west / right of frame).
const VIEW_RA0_H := 8.35
const VIEW_DEC0_DEG := 16.0
const VIEW_RA_SPAN_H := 4.6
const VIEW_DEC_SPAN_DEG := 36.0

const LINE_OPEN := (
	"This is the morning sky from Earth near Napa, California. "
	+ "Look east before sunrise: Gemini, Cancer, and Canis Minor share the view."
)
const LINE_BODIES := (
	"The Moon sits between Gemini, Cancer, and Canis Minor — right where Mars stations "
	+ "before it turns. Jupiter hangs lower toward the horizon."
)
const LINE_RX := (
	"Mars looks like it is looping backward through Gemini. That is called retrograde. "
	+ "Mars is not really going backward — Earth is catching up on the inside track, "
	+ "so against the stars Mars briefly seems to reverse."
)

## Mean lunar angular diameter as seen from Earth (~31').
const MOON_ANG_DIAM_DEG := 0.52
const JUP_RA := 9.35
const JUP_DEC := 8.2
## Gemini · Cancer · Canis Minor triad center — Moon, and Mars at the
## eastern station (terminus before westward retrograde).
const TRIAD_RA := 7.7506
const TRIAD_DEC := 16.639
## Mars path: u=0 is the pre-Rx terminus (coincides with Moon / triad center),
## then westward (decreasing RA), then the turn back east.
const MARS_PATH: Array = [
	[7.7506, 16.639], [7.62, 17.10], [7.48, 17.45], [7.34, 17.35],
	[7.22, 16.85], [7.12, 16.15], [7.08, 15.35], [7.16, 14.75],
	[7.34, 14.45], [7.55, 14.90],
]

var _active: bool = false
var _mars_u: float = 0.35
var _mars_dir: float = 1.0
var _vo_gen: int = 0
var _chart: Control
var _home_btn: Button
var _hint: Label
var _rx_badge: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()


func set_active(on: bool) -> void:
	_active = on
	visible = on
	if not on:
		_vo_gen += 1
		Narrator.stop()


func begin() -> void:
	set_active(true)
	# Start at the eastern station — Moon and Mars coincide before Rx.
	_mars_u = 0.0
	_mars_dir = 1.0
	_hint.text = "From Earth · looking east before dawn · Napa, CA"
	_vo_gen += 1
	_narrate(_vo_gen)
	if _chart != null:
		_chart.queue_redraw()


func _build() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 1)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_chart = Control.new()
	_chart.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_chart.offset_top = 44
	_chart.offset_bottom = -52
	_chart.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chart.draw.connect(_draw_chart)
	add_child(_chart)

	_hint = Label.new()
	_hint.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_hint.offset_top = 10
	_hint.offset_bottom = 42
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 20)
	_hint.add_theme_color_override("font_color", Color(0.88, 0.90, 0.95))
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)

	_rx_badge = Label.new()
	_rx_badge.text = "Mars  ℞  retrograde"
	_rx_badge.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_rx_badge.offset_top = -44
	_rx_badge.offset_bottom = -12
	_rx_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rx_badge.add_theme_font_size_override("font_size", 18)
	_rx_badge.add_theme_color_override("font_color", Color(1.0, 0.86, 0.28))
	_rx_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rx_badge)

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
	_home_btn.pressed.connect(_on_home)
	add_child(_home_btn)


func _on_home() -> void:
	set_active(false)
	closed.emit()


func _process(delta: float) -> void:
	if not _active:
		return
	_mars_u += _mars_dir * delta * 0.045
	if _mars_u >= 0.92:
		_mars_u = 0.92
		_mars_dir = -1.0
	elif _mars_u <= 0.08:
		_mars_u = 0.08
		_mars_dir = 1.0
	if _chart != null:
		_chart.queue_redraw()


func _narrate(gen: int) -> void:
	Narrator.speak(LINE_OPEN)
	await _await_vo(gen)
	if gen != _vo_gen or not _active:
		return
	Narrator.speak(LINE_BODIES)
	await _await_vo(gen)
	if gen != _vo_gen or not _active:
		return
	Narrator.speak(LINE_RX)


func _await_vo(gen: int) -> void:
	await get_tree().process_frame
	var t := 0.0
	while Narrator.is_playing() and t < 30.0:
		if gen != _vo_gen:
			return
		await get_tree().create_timer(0.08).timeout
		t += 0.08
	if gen == _vo_gen:
		await get_tree().create_timer(0.35).timeout


static func project(ra_h: float, dec_deg: float, rect: Rect2) -> Vector2:
	var u: float = (VIEW_RA0_H - ra_h) / VIEW_RA_SPAN_H + 0.5
	var v: float = (VIEW_DEC0_DEG - dec_deg) / VIEW_DEC_SPAN_DEG + 0.5
	return Vector2(
		rect.position.x + clampf(u, -0.05, 1.05) * rect.size.x,
		rect.position.y + clampf(v, -0.05, 1.05) * rect.size.y)


## Mean of Gemini / Cancer / Canis Minor constellation centers.
static func triad_center() -> Vector2:
	var ids: Array = ["gemini", "cancer", "canis_minor"]
	var ra_sum := 0.0
	var dec_sum := 0.0
	for id in ids:
		var data: Dictionary = ConstellationDataScript.by_id(str(id))
		var eq: Array = data.get("star_eq", [])
		var cra := 0.0
		var cdec := 0.0
		for st in eq:
			cra += float(st[0])
			cdec += float(st[1])
		var n: float = maxf(float(eq.size()), 1.0)
		ra_sum += cra / n
		dec_sum += cdec / n
	return Vector2(ra_sum / float(ids.size()), dec_sum / float(ids.size()))


static func mars_at(u: float) -> Vector2:
	var t: float = clampf(u, 0.0, 1.0) * float(MARS_PATH.size() - 1)
	var i0: int = clampi(int(floor(t)), 0, MARS_PATH.size() - 2)
	var f: float = t - float(i0)
	var a: Array = MARS_PATH[i0]
	var b: Array = MARS_PATH[i0 + 1]
	return Vector2(
		lerpf(float(a[0]), float(b[0]), f),
		lerpf(float(a[1]), float(b[1]), f))


static func moon_radius_px(rect: Rect2) -> float:
	# Angular diameter → chart pixels using the Dec span of the view.
	return 0.5 * (MOON_ANG_DIAM_DEG / VIEW_DEC_SPAN_DEG) * rect.size.y


func _draw_chart() -> void:
	var rect := Rect2(Vector2.ZERO, _chart.size)
	_draw_field_stars(rect)
	_draw_constellation(rect, "gemini", "Gemini", Vector2(8, -18))
	_draw_constellation(rect, "cancer", "Cancer", Vector2(-70, 14))
	_draw_constellation(rect, "canis_minor", "Canis Minor", Vector2(-95, -4))
	_draw_mars_rx(rect)
	_draw_jupiter(rect)
	# Moon last — superimposed at triad center / Mars pre-Rx terminus.
	_draw_moon(rect)


func _draw_field_stars(rect: Rect2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260908
	for _i in 70:
		var p := Vector2(
			rng.randf_range(rect.position.x, rect.end.x),
			rng.randf_range(rect.position.y, rect.end.y))
		var a: float = rng.randf_range(0.15, 0.45)
		_chart.draw_circle(p, rng.randf_range(0.6, 1.4), Color(1, 1, 1, a))


func _draw_constellation(rect: Rect2, id: String, label: String,
		label_off: Vector2) -> void:
	var data: Dictionary = ConstellationDataScript.by_id(id)
	if data.is_empty():
		return
	var eq: Array = data.get("star_eq", [])
	var pts: Array = []
	# Stars only — no stick-figure / astrological connecting lines.
	for st in eq:
		pts.append(project(float(st[0]), float(st[1]), rect))
	for i in pts.size():
		var mag: float = float(eq[i][2]) if (eq[i] as Array).size() > 2 else 1.0
		var r: float = lerpf(1.6, 3.6, clampf((mag - 0.6) / 0.9, 0.0, 1.0))
		_draw_sky_point(pts[i], r, Color(0.96, 0.97, 1.0, 0.95), 0.55)
	if pts.is_empty():
		return
	var acc := Vector2.ZERO
	for p in pts:
		acc += p as Vector2
	var mid: Vector2 = acc / float(pts.size()) + label_off
	var font := ThemeDB.fallback_font
	_chart.draw_string(font, mid, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 20,
		Color(0.82, 0.86, 0.92, 0.72))


func _draw_mars_rx(rect: Rect2) -> void:
	var trail := PackedVector2Array()
	for i in 24:
		var u: float = float(i) / 23.0
		var rd: Vector2 = mars_at(u)
		trail.append(project(rd.x, rd.y, rect))
	# Soft dusty path — pedagogical, not a chart glyph.
	for i in trail.size() - 1:
		var a: float = 0.06 + 0.14 * float(i) / float(maxi(trail.size() - 1, 1))
		_chart.draw_line(trail[i], trail[i + 1], Color(0.92, 0.48, 0.32, a), 1.2, true)
	var now: Vector2 = mars_at(_mars_u)
	var p: Vector2 = project(now.x, now.y, rect)
	# Real Mars: small warm-red point, brighter than nearby stars.
	_draw_sky_point(p, 3.2, Color(1.0, 0.55, 0.38, 1.0), 1.15)
	_draw_label(p + Vector2(-46, 6), "Mars", Color(0.95, 0.72, 0.58, 0.85))


func _draw_moon(rect: Rect2) -> void:
	# Centered between Gemini, Cancer, and Canis Minor — same sky point as
	# Mars at its eastern station (terminus before retrograde).
	var p: Vector2 = project(TRIAD_RA, TRIAD_DEC, rect)
	var r: float = maxf(moon_radius_px(rect), 2.5)
	# Pale silver crescent at true Earth angular size (~0.5°).
	var lit := Color(0.94, 0.95, 0.90, 1.0)
	_chart.draw_circle(p, r * 1.8, Color(0.85, 0.88, 0.95, 0.12))
	_chart.draw_circle(p, r, lit)
	# Umbra offset: thin waxing crescent (lit on the left before dawn east).
	_chart.draw_circle(p + Vector2(r * 0.38, -r * 0.05), r * 0.94, Color(0, 0, 0, 1))
	_draw_label(p + Vector2(r + 8.0, 5), "Moon", Color(0.90, 0.92, 0.88, 0.82))


func _draw_jupiter(rect: Rect2) -> void:
	var p: Vector2 = project(JUP_RA, JUP_DEC, rect)
	# Jupiter outshines the stars: cream-white spark, no glyph ring.
	_draw_sky_point(p, 4.0, Color(1.0, 0.97, 0.88, 1.0), 1.6)
	_draw_label(p + Vector2(12, 6), "Jupiter", Color(0.92, 0.92, 0.86, 0.82))


func _draw_sky_point(p: Vector2, core_r: float, col: Color, glow: float) -> void:
	if glow > 0.01:
		_chart.draw_circle(p, core_r * (1.8 + glow * 0.35),
			Color(col.r, col.g, col.b, 0.10 + 0.08 * glow))
		_chart.draw_circle(p, core_r * (1.25 + glow * 0.15),
			Color(col.r, col.g, col.b, 0.28 + 0.12 * glow))
	_chart.draw_circle(p, core_r, col)
	_chart.draw_circle(p, maxf(core_r * 0.35, 0.8),
		Color(1.0, 1.0, 1.0, 0.55 + 0.2 * clampf(glow, 0.0, 1.0)))


func _draw_label(p: Vector2, text: String, col: Color) -> void:
	var font := ThemeDB.fallback_font
	_chart.draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, col)

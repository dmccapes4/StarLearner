class_name CockpitHud
extends CanvasLayer
## Cockpit frame + icon HUD + top-down course console above the wheel.
## Arrival choices: learn more (video) or star panel (chart a new course).

const COCKPIT_PATH := "res://images/cockpit.png"

signal boost_pressed()
signal go_home()
signal learn_more_pressed()
signal chart_course_pressed()

var _frame: TextureRect
var _vignette: ColorRect
var _thumb: TextureRect
var _bar_bg: ColorRect
var _bar_fill: ColorRect
var _arrow: Control
var _boost: Button
var _home: Button
var _console: Control
var _callout: Label
var _arrival: Control
var _using_asset: bool = false
var _dest_color: Color = Color(0.5, 0.7, 1.0)
var _bar_w: float = 280.0
## Console map state (fed each frame from FlyScene).
var _map_ship: Vector2 = Vector2.ZERO
var _map_dest: Vector2 = Vector2.ZERO
var _map_pts: PackedVector2Array = PackedVector2Array()
var _map_progress: float = 0.0
var _map_bodies: Array = []  ## [{pos: Vector2, color: Color, name: String}]

func _ready() -> void:
	layer = 15
	_build()

func has_cockpit_asset() -> bool:
	return _using_asset

func set_destination(body: Dictionary) -> void:
	_dest_color = body.get("color", Color(0.5, 0.7, 1.0))
	_thumb.texture = make_planet_thumb(_dest_color, 72)

func update_flight(progress_u: float, heading_rad: float) -> void:
	var fill: float = distance_bar_fill(progress_u)
	_bar_fill.size.x = _bar_w * fill
	_arrow.rotation = heading_rad
	var v: float = bloom_vignette(progress_u)
	_vignette.color = Color(0, 0, 0, v)
	_map_progress = progress_u
	if _console != null:
		_console.queue_redraw()

func set_console_map(ship: Vector2, dest: Vector2, course: PackedVector2Array,
		bodies: Array) -> void:
	_map_ship = ship
	_map_dest = dest
	_map_pts = course
	_map_bodies = bodies
	if _console != null:
		_console.queue_redraw()

func show_callout(text: String) -> void:
	_callout.text = text
	_callout.modulate.a = 1.0

func clear_callout() -> void:
	_callout.text = ""

func show_arrival_choices(place_name: String) -> void:
	_boost.visible = false
	_arrival.visible = true
	var title := _arrival.get_node("Title") as Label
	if title != null:
		title.text = "Arrived at %s" % place_name

func hide_arrival_choices() -> void:
	_arrival.visible = false
	_boost.visible = true

# ── Headless-testable helpers ───────────────────────────────────────

static func distance_bar_fill(progress_u: float) -> float:
	return 1.0 - clampf(progress_u, 0.0, 1.0)

static func heading_angle(forward: Vector3, to_dest: Vector3) -> float:
	var f := Vector3(forward.x, 0.0, forward.z)
	var t := Vector3(to_dest.x, 0.0, to_dest.z)
	if f.length() < 0.001 or t.length() < 0.001:
		return 0.0
	f = f.normalized()
	t = t.normalized()
	return -atan2(f.cross(t).y, f.dot(t))

static func bloom_vignette(progress_u: float) -> float:
	var u := clampf(progress_u, 0.0, 1.0)
	return smoothstep(0.7, 1.0, u) * 0.35

## Normalize world XZ into console panel coords (padding inset).
static func console_project(world: Vector3, bounds_min: Vector2, bounds_max: Vector2,
		panel: Vector2, pad: float = 18.0) -> Vector2:
	var span := bounds_max - bounds_min
	var ux := 0.5 if absf(span.x) < 0.001 else (world.x - bounds_min.x) / span.x
	var uz := 0.5 if absf(span.y) < 0.001 else (world.z - bounds_min.y) / span.y
	return Vector2(
		pad + ux * (panel.x - pad * 2.0),
		pad + uz * (panel.y - pad * 2.0))

static func make_planet_thumb(color: Color, size: int = 72) -> Texture2D:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Vector2(size * 0.5, size * 0.5)
	var r: float = size * 0.42
	for y in size:
		for x in size:
			var d: float = Vector2(x + 0.5, y + 0.5).distance_to(c)
			if d <= r:
				var shade: float = 1.0 - 0.35 * clampf((d / r), 0.0, 1.0)
				var hilite: float = 0.0
				if Vector2(x + 0.5, y + 0.5).distance_to(c + Vector2(-r * 0.28, -r * 0.28)) < r * 0.35:
					hilite = 0.18
				img.set_pixel(x, y, Color(
					clampf(color.r * shade + hilite, 0, 1),
					clampf(color.g * shade + hilite, 0, 1),
					clampf(color.b * shade + hilite, 0, 1), 1.0))
			elif d <= r + 2.0:
				img.set_pixel(x, y, Color(1, 1, 1, 0.55))
	return ImageTexture.create_from_image(img)

static func make_fallback_frame(w: int = 1280, h: int = 600) -> Texture2D:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var wx0 := int(w * 0.12)
	var wx1 := int(w * 0.88)
	var wy0 := int(h * 0.08)
	var wy1 := int(h * 0.62)
	for y in h:
		for x in w:
			if x > wx0 and x < wx1 and y > wy0 and y < wy1:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			else:
				var dash := y > int(h * 0.68)
				var col := Color(0.12, 0.18, 0.32, 0.92) if dash \
					else Color(0.18, 0.22, 0.34, 0.88)
				img.set_pixel(x, y, col)
	_disc(img, Vector2(w * 0.30, h * 0.82), 18, Color(0.3, 0.9, 0.4, 1))
	_disc(img, Vector2(w * 0.40, h * 0.82), 18, Color(0.95, 0.85, 0.25, 1))
	_disc(img, Vector2(w * 0.60, h * 0.82), 18, Color(0.3, 0.55, 0.95, 1))
	return ImageTexture.create_from_image(img)

static func _disc(img: Image, c: Vector2, r: float, col: Color) -> void:
	var w := img.get_width()
	var h := img.get_height()
	for y in range(maxi(0, int(c.y - r)), mini(h, int(c.y + r + 1))):
		for x in range(maxi(0, int(c.x - r)), mini(w, int(c.x + r + 1))):
			if Vector2(x + 0.5, y + 0.5).distance_to(c) <= r:
				img.set_pixel(x, y, col)

func _build() -> void:
	_frame = TextureRect.new()
	_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex: Texture2D = null
	if ResourceLoader.exists(COCKPIT_PATH):
		tex = load(COCKPIT_PATH) as Texture2D
	if tex != null:
		_frame.texture = tex
		_using_asset = true
	else:
		_frame.texture = make_fallback_frame()
		_using_asset = false
	add_child(_frame)

	_vignette = ColorRect.new()
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette.color = Color(0, 0, 0, 0)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_vignette)

	_thumb = TextureRect.new()
	_thumb.position = Vector2(1100, 70)
	_thumb.size = Vector2(72, 72)
	_thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_thumb.texture = make_planet_thumb(_dest_color, 72)
	add_child(_thumb)

	_bar_bg = ColorRect.new()
	_bar_bg.position = Vector2(980, 160)
	_bar_bg.size = Vector2(_bar_w, 16)
	_bar_bg.color = Color(0.15, 0.2, 0.3, 0.85)
	_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bar_bg)
	_bar_fill = ColorRect.new()
	_bar_fill.position = _bar_bg.position
	_bar_fill.size = Vector2(_bar_w, 16)
	_bar_fill.color = Color(0.45, 0.92, 0.65, 0.95)
	_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bar_fill)

	_arrow = _make_arrow()
	_arrow.position = Vector2(640, 90)
	add_child(_arrow)

	_callout = Label.new()
	_callout.position = Vector2(340, 120)
	_callout.size = Vector2(600, 36)
	_callout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_callout.add_theme_font_size_override("font_size", 26)
	_callout.add_theme_color_override("font_color", Color(1.0, 0.95, 0.55))
	_callout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_callout)

	_console = _make_console()
	add_child(_console)

	_boost = Button.new()
	_boost.text = "BOOST"
	_boost.custom_minimum_size = Vector2(160, 72)
	_boost.size = Vector2(160, 72)
	_boost.position = Vector2(1050, 500)
	_boost.focus_mode = Control.FOCUS_NONE
	_boost.add_theme_font_size_override("font_size", 28)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.95, 0.55, 0.25, 0.95)
	sb.set_corner_radius_all(18)
	_boost.add_theme_stylebox_override("normal", sb)
	_boost.add_theme_stylebox_override("pressed", sb)
	_boost.pressed.connect(func() -> void: boost_pressed.emit())
	add_child(_boost)

	_home = Button.new()
	_home.text = "\u25C0"
	_home.custom_minimum_size = Vector2(84, 66)
	_home.size = Vector2(84, 66)
	_home.position = Vector2(20, 20)
	_home.focus_mode = Control.FOCUS_NONE
	_home.add_theme_font_size_override("font_size", 28)
	var hsb := StyleBoxFlat.new()
	hsb.bg_color = Color(0.95, 0.86, 0.45, 0.98)
	hsb.set_corner_radius_all(16)
	_home.add_theme_stylebox_override("normal", hsb)
	_home.pressed.connect(func() -> void: go_home.emit())
	add_child(_home)

	_arrival = _make_arrival_panel()
	add_child(_arrival)

func _make_console() -> Control:
	## Top-down solar console parked above the steering wheel in the cockpit art.
	var c := Control.new()
	c.name = "CourseConsole"
	c.position = Vector2(490, 395)
	c.size = Vector2(300, 130)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func() -> void:
		var sz := c.size
		c.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.04, 0.08, 0.14, 0.82), true)
		c.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.45, 0.75, 1.0, 0.55), false, 2.0)
		# Sun
		c.draw_circle(sz * 0.5, 5.0, Color(1.0, 0.85, 0.3, 0.95))
		for b in _map_bodies:
			var p: Vector2 = b.get("pos", Vector2.ZERO)
			var col: Color = b.get("color", Color(0.7, 0.7, 0.8))
			c.draw_circle(p, 3.5, col)
		if _map_pts.size() >= 2:
			c.draw_polyline(_map_pts, Color(0.45, 0.95, 1.0, 0.9), 2.5, true)
		c.draw_circle(_map_dest, 6.0, Color(_dest_color.r, _dest_color.g, _dest_color.b, 0.9))
		c.draw_arc(_map_dest, 8.0, 0.0, TAU, 20, Color(1, 1, 1, 0.85), 1.5)
		# Ship wedge
		var ship_col := Color(0.95, 0.9, 0.35, 0.98)
		c.draw_circle(_map_ship, 4.5, ship_col)
		c.draw_string(ThemeDB.fallback_font, Vector2(8, 16), "COURSE",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.75, 0.9, 1.0, 0.9))
	)
	return c

func _make_arrival_panel() -> Control:
	var panel := Control.new()
	panel.name = "ArrivalChoices"
	panel.visible = false
	panel.position = Vector2(280, 200)
	panel.size = Vector2(720, 220)

	var title := Label.new()
	title.name = "Title"
	title.text = "Arrived"
	title.position = Vector2(0, 0)
	title.size = Vector2(720, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(1, 0.95, 0.6))
	panel.add_child(title)

	var learn := Button.new()
	learn.text = "Learn more ▶"
	learn.position = Vector2(80, 70)
	learn.size = Vector2(280, 72)
	learn.focus_mode = Control.FOCUS_NONE
	learn.add_theme_font_size_override("font_size", 26)
	var lsb := StyleBoxFlat.new()
	lsb.bg_color = Color(0.35, 0.7, 0.95, 0.96)
	lsb.set_corner_radius_all(18)
	learn.add_theme_stylebox_override("normal", lsb)
	learn.pressed.connect(func() -> void: learn_more_pressed.emit())
	panel.add_child(learn)

	var star := Button.new()
	star.text = "★  Chart a new course"
	star.position = Vector2(380, 70)
	star.size = Vector2(300, 72)
	star.focus_mode = Control.FOCUS_NONE
	star.add_theme_font_size_override("font_size", 24)
	var ssb := StyleBoxFlat.new()
	ssb.bg_color = Color(0.95, 0.75, 0.25, 0.96)
	ssb.set_corner_radius_all(18)
	star.add_theme_stylebox_override("normal", ssb)
	star.pressed.connect(func() -> void: chart_course_pressed.emit())
	panel.add_child(star)

	var tip := Label.new()
	tip.text = "Videos are optional — keep cruising if you like!"
	tip.position = Vector2(0, 160)
	tip.size = Vector2(720, 30)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.add_theme_font_size_override("font_size", 18)
	tip.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0, 0.85))
	panel.add_child(tip)
	return panel

func _make_arrow() -> Control:
	var lbl := Label.new()
	lbl.text = "▲"
	lbl.add_theme_font_size_override("font_size", 40)
	lbl.add_theme_color_override("font_color", Color(0.95, 0.9, 0.35, 0.95))
	lbl.custom_minimum_size = Vector2(48, 48)
	lbl.size = Vector2(48, 48)
	lbl.pivot_offset = Vector2(24, 24)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl

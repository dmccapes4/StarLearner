class_name ChromeIcons
extends RefCounted
## Chrome icons for pre-readers. Prefer painted PNGs under res://images/ui/;
## fall back to procedural draw if a file is missing.

const SIZE := 128
const UI_DIR := "res://images/ui"

static var _cache: Dictionary = {}

static func texture(id: String) -> Texture2D:
	if _cache.has(id):
		return _cache[id]
	var from_disk := _load_png(id)
	if from_disk != null:
		_cache[id] = from_disk
		return from_disk
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	match id:
		"home_read", "read":
			_draw_book_open(img)
		"home_write", "write":
			_draw_pencil(img)
		"home_voice", "voice":
			_draw_mic_pencil(img)
		"sentences":
			_draw_sentences(img)
		"books":
			_draw_book_closed(img)
		"images":
			_draw_picture(img)
		"narration":
			_draw_speaker(img)
		"alphabet":
			_draw_alphabet_tiles(img)
		"sketch":
			_draw_sketch(img)
		"back":
			_draw_chevron(img, true)
		"next":
			_draw_chevron(img, false)
		"done":
			_draw_check(img)
		"close":
			_draw_x(img)
		"read_slowly":
			_draw_turtle_book(img)
		"menu":
			_draw_menu(img)
		"english":
			_draw_lang(img, "Aa")
		"spanish":
			_draw_lang(img, "Ñ")
		"spell_demo", "apple_en", "apple_es":
			_draw_apple_badge(img)
		"credits":
			_draw_star(img)
		"hear":
			_draw_note(img)
		_:
			_fill_round_rect(img, Rect2(16, 16, 96, 96), 18, Color(0.45, 0.55, 0.80))
	var tex := ImageTexture.create_from_image(img)
	_cache[id] = tex
	return tex

static func _load_png(id: String) -> Texture2D:
	var path := "%s/%s.png" % [UI_DIR, id]
	if not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
		return null
	# Prefer imported Texture2D when the editor/export has scanned the PNG.
	if ResourceLoader.exists(path):
		var res: Resource = load(path)
		if res is Texture2D:
			return res as Texture2D
	var abs_path := ProjectSettings.globalize_path(path)
	var img := Image.new()
	if img.load(abs_path) != OK:
		return null
	return ImageTexture.create_from_image(img)

static func apply_button(b: Button, id: String, icon_max: int = 72) -> void:
	b.text = ""
	b.icon = texture(id)
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	b.add_theme_constant_override("icon_max_width", icon_max)

static func _draw_book_open(img: Image) -> void:
	_fill_round_rect(img, Rect2(14, 28, 46, 72), 10, Color(0.95, 0.94, 0.88))
	_fill_round_rect(img, Rect2(68, 28, 46, 72), 10, Color(0.95, 0.94, 0.88))
	_fill_rect(img, Rect2(58, 30, 12, 72), Color(0.75, 0.58, 0.18))
	_fill_round_rect(img, Rect2(22, 42, 30, 8), 4, Color(0.90, 0.30, 0.28))
	_fill_round_rect(img, Rect2(22, 58, 30, 8), 4, Color(0.30, 0.55, 0.95))
	_fill_round_rect(img, Rect2(22, 74, 30, 8), 4, Color(0.36, 0.78, 0.45))
	_fill_round_rect(img, Rect2(76, 42, 30, 8), 4, Color(0.90, 0.30, 0.28))
	_fill_round_rect(img, Rect2(76, 58, 30, 8), 4, Color(0.30, 0.55, 0.95))
	_fill_round_rect(img, Rect2(76, 74, 30, 8), 4, Color(0.36, 0.78, 0.45))

static func _draw_book_closed(img: Image) -> void:
	_fill_round_rect(img, Rect2(28, 22, 72, 88), 12, Color(0.30, 0.55, 0.95))
	_fill_rect(img, Rect2(28, 22, 14, 88), Color(0.22, 0.40, 0.75))
	_fill_round_rect(img, Rect2(50, 40, 40, 8), 4, Color(1.0, 0.82, 0.30))
	_fill_round_rect(img, Rect2(50, 56, 34, 6), 3, Color(0.95, 0.94, 0.88))
	_fill_round_rect(img, Rect2(50, 70, 34, 6), 3, Color(0.95, 0.94, 0.88))

static func _draw_pencil(img: Image) -> void:
	# Pencil body angled.
	_fill_tri(img, Vector2(34, 96), Vector2(48, 28), Vector2(62, 96), Color(1.0, 0.82, 0.30))
	_fill_tri(img, Vector2(48, 28), Vector2(40, 44), Vector2(56, 44), Color(0.95, 0.90, 0.78))
	_fill_tri(img, Vector2(48, 18), Vector2(40, 34), Vector2(56, 34), Color(0.20, 0.20, 0.24))
	_fill_rect(img, Rect2(42, 88, 16, 14), Color(0.90, 0.30, 0.28))
	# Scribble line.
	_fill_round_rect(img, Rect2(72, 78, 36, 8), 4, Color(0.30, 0.55, 0.95))
	_fill_round_rect(img, Rect2(80, 92, 28, 6), 3, Color(0.36, 0.78, 0.45))

static func _draw_mic_pencil(img: Image) -> void:
	# Mic capsule.
	_fill_round_rect(img, Rect2(28, 28, 36, 52), 16, Color(0.95, 0.94, 0.88))
	_fill_round_rect(img, Rect2(36, 36, 20, 36), 10, Color(0.45, 0.78, 0.55))
	_fill_rect(img, Rect2(42, 80, 8, 16), Color(0.72, 0.78, 0.92))
	_fill_round_rect(img, Rect2(30, 94, 32, 8), 4, Color(0.72, 0.78, 0.92))
	# Pencil.
	_fill_tri(img, Vector2(78, 90), Vector2(96, 34), Vector2(110, 90), Color(1.0, 0.82, 0.30))
	_fill_tri(img, Vector2(96, 28), Vector2(90, 42), Vector2(102, 42), Color(0.20, 0.20, 0.24))

static func _draw_sentences(img: Image) -> void:
	_fill_round_rect(img, Rect2(18, 28, 52, 52), 12, Color(0.36, 0.78, 0.45))
	_fill_circle(img, Vector2(44, 54), 14, Color(0.95, 0.94, 0.88))
	_fill_round_rect(img, Rect2(78, 34, 36, 12), 6, Color(0.90, 0.30, 0.28))
	_fill_round_rect(img, Rect2(78, 54, 36, 12), 6, Color(0.90, 0.30, 0.28))
	_fill_round_rect(img, Rect2(78, 74, 28, 12), 6, Color(0.90, 0.30, 0.28))

static func _draw_picture(img: Image) -> void:
	_fill_round_rect(img, Rect2(18, 22, 92, 84), 14, Color(0.95, 0.94, 0.88))
	_fill_round_rect(img, Rect2(26, 30, 76, 56), 10, Color(0.55, 0.75, 0.95))
	_fill_circle(img, Vector2(48, 48), 10, Color(1.0, 0.82, 0.30))
	_fill_tri(img, Vector2(34, 78), Vector2(58, 48), Vector2(82, 78), Color(0.36, 0.78, 0.45))
	_fill_round_rect(img, Rect2(34, 92, 60, 8), 4, Color(0.60, 0.63, 0.72))

static func _draw_speaker(img: Image) -> void:
	_fill_round_rect(img, Rect2(28, 48, 24, 32), 6, Color(1.0, 0.82, 0.30))
	_fill_tri(img, Vector2(48, 40), Vector2(48, 88), Vector2(78, 96), Color(1.0, 0.82, 0.30))
	_fill_tri(img, Vector2(48, 40), Vector2(48, 88), Vector2(78, 32), Color(1.0, 0.82, 0.30))
	_fill_arc_dots(img, Vector2(86, 64), 18, Color(0.95, 0.94, 0.88))
	_fill_arc_dots(img, Vector2(94, 64), 28, Color(0.72, 0.78, 0.92))

static func _draw_alphabet_tiles(img: Image) -> void:
	var tiles := [
		{"r": Rect2(16, 20, 44, 44), "c": Color(0.30, 0.55, 0.95)},
		{"r": Rect2(68, 20, 44, 44), "c": Color(0.90, 0.30, 0.28)},
		{"r": Rect2(16, 72, 44, 44), "c": Color(0.36, 0.78, 0.45)},
		{"r": Rect2(68, 72, 44, 44), "c": Color(1.0, 0.82, 0.30)},
	]
	for t in tiles:
		_fill_round_rect(img, t["r"], 10, t["c"])
	# Tiny letter-like bars (not readable words — just tile content).
	_fill_round_rect(img, Rect2(28, 34, 20, 6), 3, Color(1, 1, 1, 0.95))
	_fill_round_rect(img, Rect2(34, 42, 8, 14), 3, Color(1, 1, 1, 0.95))
	_fill_round_rect(img, Rect2(80, 34, 20, 6), 3, Color(1, 1, 1, 0.95))
	_fill_circle(img, Vector2(90, 50), 8, Color(1, 1, 1, 0.95))
	_fill_round_rect(img, Rect2(28, 86, 20, 6), 3, Color(0.12, 0.12, 0.16))
	_fill_round_rect(img, Rect2(28, 96, 14, 6), 3, Color(0.12, 0.12, 0.16))
	_fill_round_rect(img, Rect2(80, 86, 20, 16), 4, Color(0.12, 0.12, 0.16))

static func _draw_sketch(img: Image) -> void:
	# Grey letter outline.
	_fill_round_rect(img, Rect2(28, 24, 48, 72), 8, Color(0.60, 0.63, 0.72, 0.35))
	_stroke_round_rect(img, Rect2(28, 24, 48, 72), 8, Color(0.72, 0.78, 0.92), 4)
	# Hand / pencil tip.
	_fill_circle(img, Vector2(86, 78), 16, Color(0.95, 0.78, 0.62))
	_fill_tri(img, Vector2(72, 54), Vector2(96, 54), Vector2(84, 22), Color(1.0, 0.82, 0.30))
	_fill_tri(img, Vector2(84, 14), Vector2(78, 28), Vector2(90, 28), Color(0.20, 0.20, 0.24))
	_fill_round_rect(img, Rect2(40, 88, 36, 8), 4, Color(0.30, 0.55, 0.95))

static func _draw_chevron(img: Image, left: bool) -> void:
	var c := Color(0.06, 0.06, 0.12)
	if left:
		_fill_tri(img, Vector2(86, 24), Vector2(86, 104), Vector2(34, 64), c)
	else:
		_fill_tri(img, Vector2(42, 24), Vector2(42, 104), Vector2(94, 64), c)

static func _draw_check(img: Image) -> void:
	_fill_circle(img, Vector2(64, 64), 44, Color(0.36, 0.78, 0.45))
	_fill_tri(img, Vector2(36, 66), Vector2(56, 86), Vector2(52, 58), Color(0.06, 0.12, 0.08))
	_fill_tri(img, Vector2(52, 86), Vector2(96, 36), Vector2(60, 78), Color(0.06, 0.12, 0.08))

static func _draw_x(img: Image) -> void:
	_fill_circle(img, Vector2(64, 64), 44, Color(0.16, 0.19, 0.30))
	_fill_rect_rot(img, Vector2(64, 64), 56, 12, 0.7, Color(0.95, 0.94, 0.88))
	_fill_rect_rot(img, Vector2(64, 64), 56, 12, -0.7, Color(0.95, 0.94, 0.88))

static func _draw_turtle_book(img: Image) -> void:
	_fill_circle(img, Vector2(64, 70), 34, Color(0.36, 0.78, 0.45))
	_fill_circle(img, Vector2(64, 38), 16, Color(0.36, 0.78, 0.45))
	_fill_circle(img, Vector2(56, 34), 3, Color(0.10, 0.12, 0.16))
	_fill_circle(img, Vector2(72, 34), 3, Color(0.10, 0.12, 0.16))
	_fill_round_rect(img, Rect2(40, 58, 48, 10), 4, Color(0.22, 0.55, 0.32))
	_fill_round_rect(img, Rect2(86, 22, 28, 36), 6, Color(0.95, 0.94, 0.88))
	_fill_rect(img, Rect2(86, 22, 6, 36), Color(0.75, 0.58, 0.18))

static func _draw_menu(img: Image) -> void:
	for y in [36, 58, 80]:
		_fill_round_rect(img, Rect2(28, y, 72, 12), 6, Color(0.95, 0.94, 0.88))

static func _draw_lang(img: Image, badge: String) -> void:
	_fill_circle(img, Vector2(64, 64), 46, Color(0.16, 0.19, 0.30))
	_fill_circle(img, Vector2(64, 64), 38, Color(1.0, 0.82, 0.30))
	# Simple glyph bars instead of font raster.
	if badge == "Ñ":
		_fill_round_rect(img, Rect2(44, 44, 12, 40), 4, Color(0.10, 0.12, 0.16))
		_fill_round_rect(img, Rect2(72, 44, 12, 40), 4, Color(0.10, 0.12, 0.16))
		_fill_round_rect(img, Rect2(44, 44, 40, 12), 4, Color(0.10, 0.12, 0.16))
		_fill_round_rect(img, Rect2(48, 30, 32, 8), 4, Color(0.10, 0.12, 0.16))
	else:
		_fill_round_rect(img, Rect2(36, 40, 22, 8), 3, Color(0.10, 0.12, 0.16))
		_fill_round_rect(img, Rect2(43, 40, 8, 36), 3, Color(0.10, 0.12, 0.16))
		_fill_round_rect(img, Rect2(70, 52, 22, 8), 3, Color(0.10, 0.12, 0.16))
		_fill_circle(img, Vector2(81, 72), 10, Color(0.10, 0.12, 0.16))
		_fill_circle(img, Vector2(81, 72), 5, Color(1.0, 0.82, 0.30))

static func _draw_apple_badge(img: Image) -> void:
	_fill_circle(img, Vector2(64, 70), 34, Color(0.85, 0.22, 0.22))
	_fill_rect(img, Rect2(61, 28, 6, 18), Color(0.45, 0.28, 0.12))
	_fill_circle(img, Vector2(78, 40), 10, Color(0.30, 0.70, 0.35))
	_fill_round_rect(img, Rect2(20, 88, 28, 22), 6, Color(0.30, 0.55, 0.95))
	_fill_round_rect(img, Rect2(80, 88, 28, 22), 6, Color(0.90, 0.30, 0.28))

static func _draw_apple_flag(img: Image, badge: Color) -> void:
	_fill_circle(img, Vector2(56, 64), 36, Color(0.85, 0.22, 0.22))
	_fill_rect(img, Rect2(53, 24, 6, 18), Color(0.45, 0.28, 0.12))
	_fill_circle(img, Vector2(70, 36), 10, Color(0.30, 0.70, 0.35))
	_fill_round_rect(img, Rect2(88, 78, 28, 28), 8, badge)

static func _draw_star(img: Image) -> void:
	_fill_circle(img, Vector2(64, 64), 40, Color(1.0, 0.82, 0.30))
	_fill_circle(img, Vector2(64, 64), 18, Color(0.16, 0.19, 0.30))

static func _draw_note(img: Image) -> void:
	_fill_circle(img, Vector2(44, 88), 16, Color(1.0, 0.82, 0.30))
	_fill_rect(img, Rect2(56, 28, 10, 60), Color(1.0, 0.82, 0.30))
	_fill_round_rect(img, Rect2(56, 24, 36, 16), 6, Color(1.0, 0.82, 0.30))

static func _fill_arc_dots(img: Image, c: Vector2, r: float, color: Color) -> void:
	for a in range(-50, 55, 18):
		var rad := deg_to_rad(float(a))
		var p := c + Vector2(cos(rad), sin(rad)) * r
		_fill_circle(img, p, 4, color)

static func _fill_circle(img: Image, c: Vector2, r: float, color: Color) -> void:
	var r2 := r * r
	var x0 := maxi(0, int(c.x - r))
	var y0 := maxi(0, int(c.y - r))
	var x1 := mini(SIZE - 1, int(c.x + r))
	var y1 := mini(SIZE - 1, int(c.y + r))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var d := Vector2(float(x) + 0.5, float(y) + 0.5) - c
			if d.length_squared() <= r2:
				img.set_pixel(x, y, color)

static func _fill_rect(img: Image, r: Rect2, color: Color) -> void:
	var x0 := maxi(0, int(r.position.x))
	var y0 := maxi(0, int(r.position.y))
	var x1 := mini(SIZE - 1, int(r.position.x + r.size.x - 1))
	var y1 := mini(SIZE - 1, int(r.position.y + r.size.y - 1))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			img.set_pixel(x, y, color)

static func _fill_round_rect(img: Image, r: Rect2, radius: float, color: Color) -> void:
	_fill_rect(img, r, color)
	_fill_circle(img, r.position + Vector2(radius, radius), radius, color)
	_fill_circle(img, Vector2(r.position.x + r.size.x - radius, r.position.y + radius), radius, color)
	_fill_circle(img, Vector2(r.position.x + radius, r.position.y + r.size.y - radius), radius, color)
	_fill_circle(img, r.position + r.size - Vector2(radius, radius), radius, color)

static func _stroke_round_rect(img: Image, r: Rect2, radius: float, color: Color, w: int) -> void:
	for i in range(w):
		var rr := r.grow(-float(i))
		# Top / bottom
		_fill_rect(img, Rect2(rr.position.x + radius, rr.position.y, rr.size.x - radius * 2.0, 1), color)
		_fill_rect(img, Rect2(rr.position.x + radius, rr.position.y + rr.size.y - 1, rr.size.x - radius * 2.0, 1), color)
		_fill_rect(img, Rect2(rr.position.x, rr.position.y + radius, 1, rr.size.y - radius * 2.0), color)
		_fill_rect(img, Rect2(rr.position.x + rr.size.x - 1, rr.position.y + radius, 1, rr.size.y - radius * 2.0), color)

static func _fill_tri(img: Image, a: Vector2, b: Vector2, c: Vector2, color: Color) -> void:
	var min_x := int(minf(a.x, minf(b.x, c.x)))
	var max_x := int(maxf(a.x, maxf(b.x, c.x)))
	var min_y := int(minf(a.y, minf(b.y, c.y)))
	var max_y := int(maxf(a.y, maxf(b.y, c.y)))
	for y in range(maxi(0, min_y), mini(SIZE - 1, max_y) + 1):
		for x in range(maxi(0, min_x), mini(SIZE - 1, max_x) + 1):
			var p := Vector2(float(x) + 0.5, float(y) + 0.5)
			if _in_tri(p, a, b, c):
				img.set_pixel(x, y, color)

static func _in_tri(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> bool:
	var v0 := c - a
	var v1 := b - a
	var v2 := p - a
	var dot00 := v0.dot(v0)
	var dot01 := v0.dot(v1)
	var dot02 := v0.dot(v2)
	var dot11 := v1.dot(v1)
	var dot12 := v1.dot(v2)
	var den := dot00 * dot11 - dot01 * dot01
	if absf(den) < 0.0001:
		return false
	var inv := 1.0 / den
	var u := (dot11 * dot02 - dot01 * dot12) * inv
	var v := (dot00 * dot12 - dot01 * dot02) * inv
	return u >= 0.0 and v >= 0.0 and (u + v) < 1.0

static func _fill_rect_rot(img: Image, center: Vector2, length: float, thickness: float, angle: float, color: Color) -> void:
	var ca := cos(angle)
	var sa := sin(angle)
	var half_l := length * 0.5
	var half_t := thickness * 0.5
	var corners := [
		center + Vector2(ca * -half_l - sa * -half_t, sa * -half_l + ca * -half_t),
		center + Vector2(ca * half_l - sa * -half_t, sa * half_l + ca * -half_t),
		center + Vector2(ca * half_l - sa * half_t, sa * half_l + ca * half_t),
		center + Vector2(ca * -half_l - sa * half_t, sa * -half_l + ca * half_t),
	]
	# Split into two tris.
	_fill_tri(img, corners[0], corners[1], corners[2], color)
	_fill_tri(img, corners[0], corners[2], corners[3], color)

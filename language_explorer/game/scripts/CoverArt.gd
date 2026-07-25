class_name CoverArt
extends RefCounted
## Book cover textures. Prefer on-disk PNG; otherwise draw a motif placeholder.

const W := 160
const H := 200

static func texture_for(book: Dictionary) -> Texture2D:
	var path := str(book.get("cover", ""))
	if not path.is_empty() and FileAccess.file_exists(path):
		var res: Resource = load(path)
		if res is Texture2D:
			return res as Texture2D
	return _placeholder(str(book.get("cover_motif", book.get("id", "book"))), str(book.get("title", "")))

static func _placeholder(motif: String, title: String) -> Texture2D:
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.18, 0.22, 0.34, 1))
	# Border.
	for x in W:
		img.set_pixel(x, 0, LangTheme.GOLD)
		img.set_pixel(x, H - 1, LangTheme.GOLD)
	for y in H:
		img.set_pixel(0, y, LangTheme.GOLD)
		img.set_pixel(W - 1, y, LangTheme.GOLD)
	match motif:
		"rabbit":
			_fill_circle(img, Vector2(80, 110), 36, Color(0.92, 0.88, 0.82))
			_fill_ellipse(img, Vector2(58, 55), 10, 28, Color(0.92, 0.88, 0.82))
			_fill_ellipse(img, Vector2(102, 55), 10, 28, Color(0.92, 0.88, 0.82))
			_fill_circle(img, Vector2(68, 105), 4, Color(0.15, 0.12, 0.12))
			_fill_circle(img, Vector2(92, 105), 4, Color(0.15, 0.12, 0.12))
		"tortoise":
			_fill_ellipse(img, Vector2(80, 120), 42, 28, Color(0.35, 0.62, 0.38))
			_fill_circle(img, Vector2(48, 118), 12, Color(0.45, 0.70, 0.42))
			_fill_circle(img, Vector2(36, 110), 6, Color(0.20, 0.25, 0.18))
			_fill_rect(img, Rect2(60, 140, 8, 18), Color(0.35, 0.55, 0.32))
			_fill_rect(img, Rect2(92, 140, 8, 18), Color(0.35, 0.55, 0.32))
		_:
			_fill_rect(img, Rect2(40, 50, 80, 100), Color(0.55, 0.45, 0.70))
	# Title strip (simple bars — WordLabel renders the real title under the cover).
	_fill_rect(img, Rect2(12, 168, W - 24, 20), Color(0.10, 0.12, 0.20, 0.85))
	var _t := title  # reserved for future bitmap font
	return ImageTexture.create_from_image(img)

static func _fill_circle(img: Image, c: Vector2, r: float, color: Color) -> void:
	var r2 := r * r
	for y in range(maxi(0, int(c.y - r)), mini(H - 1, int(c.y + r)) + 1):
		for x in range(maxi(0, int(c.x - r)), mini(W - 1, int(c.x + r)) + 1):
			var d := Vector2(float(x) + 0.5, float(y) + 0.5) - c
			if d.length_squared() <= r2:
				img.set_pixel(x, y, color)

static func _fill_ellipse(img: Image, c: Vector2, rx: float, ry: float, color: Color) -> void:
	for y in range(maxi(0, int(c.y - ry)), mini(H - 1, int(c.y + ry)) + 1):
		for x in range(maxi(0, int(c.x - rx)), mini(W - 1, int(c.x + rx)) + 1):
			var dx := (float(x) + 0.5 - c.x) / rx
			var dy := (float(y) + 0.5 - c.y) / ry
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(x, y, color)

static func _fill_rect(img: Image, r: Rect2, color: Color) -> void:
	for y in range(maxi(0, int(r.position.y)), mini(H - 1, int(r.position.y + r.size.y)) + 1):
		for x in range(maxi(0, int(r.position.x)), mini(W - 1, int(r.position.x + r.size.x)) + 1):
			img.set_pixel(x, y, color)

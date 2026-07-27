class_name SpriteArt
extends RefCounted
## Resolve sentence sprite textures. Prefer on-disk PNGs; otherwise generate a
## simple flat placeholder so Phase 3 is playable without art drops.

const SIZE := 96

static func texture_for(sprite_id: String, image_path: String = "") -> Texture2D:
	if not image_path.is_empty() and FileAccess.file_exists(image_path):
		var res: Resource = load(image_path)
		if res is Texture2D:
			return res as Texture2D
	return _placeholder(sprite_id)

static func _placeholder(sprite_id: String) -> Texture2D:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	match sprite_id:
		"apple":
			_fill_circle(img, Vector2(48, 54), 30, Color(0.85, 0.22, 0.22))
			_fill_rect(img, Rect2(45, 18, 6, 16), Color(0.45, 0.28, 0.12))
			_fill_circle(img, Vector2(62, 28), 8, Color(0.30, 0.70, 0.35))
		"cat":
			_fill_circle(img, Vector2(48, 56), 28, Color(0.92, 0.62, 0.28))
			_fill_tri(img, Vector2(28, 40), Vector2(38, 18), Vector2(48, 40), Color(0.92, 0.62, 0.28))
			_fill_tri(img, Vector2(48, 40), Vector2(58, 18), Vector2(68, 40), Color(0.92, 0.62, 0.28))
			_fill_circle(img, Vector2(38, 54), 4, Color(0.12, 0.12, 0.14))
			_fill_circle(img, Vector2(58, 54), 4, Color(0.12, 0.12, 0.14))
		"hat":
			_fill_rect(img, Rect2(28, 34, 40, 28), Color(0.35, 0.28, 0.70))
			_fill_rect(img, Rect2(16, 58, 64, 12), Color(0.28, 0.22, 0.55))
			_fill_rect(img, Rect2(40, 24, 16, 14), Color(0.90, 0.78, 0.30))
		"sun":
			_fill_circle(img, Vector2(48, 48), 22, Color(1.0, 0.82, 0.25))
			for a in range(0, 360, 45):
				var rad := deg_to_rad(float(a))
				var p := Vector2(48, 48) + Vector2(cos(rad), sin(rad)) * 38.0
				_fill_circle(img, p, 5, Color(1.0, 0.72, 0.20))
		"swatch_red", "red":
			_fill_round_rect(img, Rect2(12, 12, 72, 72), Color(0.90, 0.30, 0.28))
		"swatch_gold", "big", "gold":
			_fill_round_rect(img, Rect2(12, 12, 72, 72), Color(1.0, 0.82, 0.30))
		"dog", "perro":
			_fill_circle(img, Vector2(48, 58), 26, Color(0.72, 0.48, 0.28))
			_fill_circle(img, Vector2(48, 36), 18, Color(0.72, 0.48, 0.28))
			_fill_circle(img, Vector2(40, 34), 3, Color(0.1, 0.1, 0.1))
			_fill_circle(img, Vector2(56, 34), 3, Color(0.1, 0.1, 0.1))
			_fill_tri(img, Vector2(30, 28), Vector2(36, 12), Vector2(42, 28), Color(0.62, 0.40, 0.22))
			_fill_tri(img, Vector2(54, 28), Vector2(60, 12), Vector2(66, 28), Color(0.62, 0.40, 0.22))
		"fish", "pez":
			_fill_circle(img, Vector2(44, 48), 22, Color(0.30, 0.62, 0.90))
			_fill_tri(img, Vector2(62, 48), Vector2(84, 30), Vector2(84, 66), Color(0.25, 0.52, 0.80))
			_fill_circle(img, Vector2(36, 44), 4, Color(0.05, 0.08, 0.12))
		"ball", "pelota":
			_fill_circle(img, Vector2(48, 48), 30, Color(0.95, 0.45, 0.20))
			_fill_rect(img, Rect2(18, 45, 60, 6), Color(1, 1, 1, 0.85))
			_fill_rect(img, Rect2(45, 18, 6, 60), Color(1, 1, 1, 0.85))
		"tree", "arbol", "árbol":
			_fill_rect(img, Rect2(42, 52, 12, 30), Color(0.45, 0.28, 0.14))
			_fill_circle(img, Vector2(48, 40), 26, Color(0.28, 0.62, 0.32))
			_fill_circle(img, Vector2(34, 48), 14, Color(0.24, 0.55, 0.28))
			_fill_circle(img, Vector2(62, 48), 14, Color(0.24, 0.55, 0.28))
		"star", "estrella":
			_fill_circle(img, Vector2(48, 48), 10, Color(1.0, 0.86, 0.30))
			for a in range(0, 360, 72):
				var rad := deg_to_rad(float(a) - 90.0)
				var p := Vector2(48, 48) + Vector2(cos(rad), sin(rad)) * 28.0
				_fill_circle(img, p, 7, Color(1.0, 0.82, 0.25))
		"moon", "luna":
			_fill_circle(img, Vector2(48, 48), 28, Color(0.92, 0.90, 0.70))
			_fill_circle(img, Vector2(60, 40), 22, Color(0.12, 0.16, 0.28))
		"bird", "pajaro", "pájaro":
			_fill_circle(img, Vector2(48, 50), 18, Color(0.35, 0.55, 0.85))
			_fill_circle(img, Vector2(62, 40), 12, Color(0.35, 0.55, 0.85))
			_fill_tri(img, Vector2(72, 40), Vector2(86, 36), Vector2(72, 48), Color(0.95, 0.70, 0.25))
			_fill_circle(img, Vector2(66, 38), 2, Color(0.08, 0.08, 0.1))
		"bee", "abeja":
			_fill_circle(img, Vector2(48, 52), 18, Color(1.0, 0.82, 0.20))
			_fill_rect(img, Rect2(30, 48, 36, 6), Color(0.12, 0.12, 0.12))
			_fill_circle(img, Vector2(34, 40), 10, Color(0.85, 0.92, 1.0, 0.7))
			_fill_circle(img, Vector2(62, 40), 10, Color(0.85, 0.92, 1.0, 0.7))
		_:
			_fill_round_rect(img, Rect2(12, 12, 72, 72), Color(0.45, 0.55, 0.80))
			_fill_circle(img, Vector2(48, 48), 18, Color(0.85, 0.90, 1.0))
	var tex := ImageTexture.create_from_image(img)
	return tex

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
	var x1 := mini(SIZE - 1, int(r.position.x + r.size.x))
	var y1 := mini(SIZE - 1, int(r.position.y + r.size.y))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			img.set_pixel(x, y, color)

static func _fill_round_rect(img: Image, r: Rect2, color: Color) -> void:
	_fill_rect(img, r, color)
	# Soft corners by clearing corners (cheap).
	var rad := 10.0
	for corner in [
		r.position,
		Vector2(r.position.x + r.size.x, r.position.y),
		Vector2(r.position.x, r.position.y + r.size.y),
		r.position + r.size,
	]:
		pass  # keep solid for readability at 96px
	_fill_circle(img, r.position + Vector2(rad, rad), rad, color)
	_fill_circle(img, Vector2(r.position.x + r.size.x - rad, r.position.y + rad), rad, color)
	_fill_circle(img, Vector2(r.position.x + rad, r.position.y + r.size.y - rad), rad, color)
	_fill_circle(img, r.position + r.size - Vector2(rad, rad), rad, color)

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
	var inv := 1.0 / (dot00 * dot11 - dot01 * dot01)
	var u := (dot11 * dot02 - dot01 * dot12) * inv
	var v := (dot00 * dot12 - dot01 * dot02) * inv
	return u >= 0.0 and v >= 0.0 and (u + v) < 1.0

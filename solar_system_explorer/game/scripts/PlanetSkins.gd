class_name PlanetSkins
extends RefCounted
## Albedo textures for flyer bodies. Prefers the generated photoreal
## cinematic maps (images/cinematic), falling back to the procedural skins
## (tools/gen_planet_skins.py) so nothing ever renders untextured.

const DIR := "res://images/planets"
const CINE_DIR := "res://images/cinematic"
## Chunky pixel AR pins for Mission Flight markers (tools/gen_marker_icons.py).
const MARKER_DIR := "res://images/markers"
const MARKER_CANVAS_PX := 64

static func texture_for(body_id: String) -> Texture2D:
	var cine := "%s/%s.png" % [CINE_DIR, body_id]
	if ResourceLoader.exists(cine):
		return load(cine) as Texture2D
	var path := "%s/%s.png" % [DIR, body_id]
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

## Circular disc for the 2D ScrollView strip (samples the equirectangular skin).
static func make_disc_texture(body_id: String, fallback: Color, diameter: int) -> Texture2D:
	var d: int = maxi(diameter, 8)
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var skin_tex := texture_for(body_id)
	var skin: Image = null
	if skin_tex != null:
		skin = skin_tex.get_image()
		if skin != null and skin.is_compressed():
			skin.decompress()
	var r: float = d * 0.5
	var cx := r
	var cy := r
	for y in d:
		for x in d:
			var dx: float = (x + 0.5) - cx
			var dy: float = (y + 0.5) - cy
			var dist: float = sqrt(dx * dx + dy * dy)
			if dist > r:
				continue
			# Soft sphere limb darkening.
			var nz: float = sqrt(maxf(0.0, 1.0 - (dist / r) * (dist / r)))
			var col: Color
			if skin != null:
				var u: float = 0.5 + atan2(dx, nz) / TAU
				var v: float = 0.5 - asin(clampf(dy / r, -1.0, 1.0)) / PI
				col = skin.get_pixel(
					clampi(int(u * float(skin.get_width())), 0, skin.get_width() - 1),
					clampi(int(v * float(skin.get_height())), 0, skin.get_height() - 1))
			else:
				col = fallback
			var shade: float = 0.55 + 0.45 * nz
			img.set_pixel(x, y, Color(col.r * shade, col.g * shade, col.b * shade, 1.0))
	return ImageTexture.create_from_image(img)

## Recognizable navigation MARKER: chunky pixel AR pin (not a tiny planet
## render). Prefers baked `images/markers/<id>.png`; falls back to a
## quantized procedural disc so headless never shows a photoreal skin.
static func make_icon_texture(b: Dictionary, size: int = MARKER_CANVAS_PX) -> Texture2D:
	var id := str(b.get("id", ""))
	var baked := marker_texture_for(id)
	if baked != null:
		return baked
	return _fallback_pixel_marker(b, maxi(size, 16))


static func marker_texture_for(body_id: String) -> Texture2D:
	var path := "%s/%s.png" % [MARKER_DIR, body_id]
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


static func marker_path_for(body_id: String) -> String:
	return "%s/%s.png" % [MARKER_DIR, body_id]


## True when the flyer will use a baked pixel AR marker (not a skin sample).
static func has_pixel_marker(body_id: String) -> bool:
	return ResourceLoader.exists(marker_path_for(body_id))


static func _fallback_pixel_marker(b: Dictionary, s: int) -> Texture2D:
	var id := str(b.get("id", ""))
	var col: Color = b.get("color", Color(0.7, 0.7, 0.7))
	if bool(b.get("is_star", false)):
		return _sun_marker_texture(s)
	var has_ring := bool(b.get("ring", false))
	var disc_d: int = int(s * (0.55 if has_ring else 0.62))
	disc_d = maxi(disc_d - (disc_d % 2), 8)
	var disc_img := _flat_marker_disc(id, col, disc_d)
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_draw_ar_brackets(img, s)
	var off := Vector2i((s - disc_d) / 2, (s - disc_d) / 2)
	var cx := s * 0.5
	var cy := s * 0.5
	var ring_col := Color(0.86, 0.78, 0.55, 0.95)
	if has_ring:
		_icon_ring(img, cx, cy, s, ring_col, false)
	img.blend_rect(disc_img, Rect2i(0, 0, disc_d, disc_d), off)
	if has_ring:
		_icon_ring(img, cx, cy, s, ring_col, true)
	return ImageTexture.create_from_image(img)


static func _draw_ar_brackets(img: Image, s: int) -> void:
	var c := Color(0.70, 1.0, 0.86, 0.85)
	var pad := 2
	var L: int = maxi(s / 6, 4)
	var t := 2
	# TL / TR / BL / BR
	for rect in [
		Rect2i(pad, pad, L, t), Rect2i(pad, pad, t, L),
		Rect2i(s - pad - L, pad, L, t), Rect2i(s - pad - t, pad, t, L),
		Rect2i(pad, s - pad - t, L, t), Rect2i(pad, s - pad - L, t, L),
		Rect2i(s - pad - L, s - pad - t, L, t), Rect2i(s - pad - t, s - pad - L, t, L),
	]:
		for y in range(rect.position.y, rect.position.y + rect.size.y):
			for x in range(rect.position.x, rect.position.x + rect.size.x):
				if x >= 0 and y >= 0 and x < s and y < s:
					img.set_pixel(x, y, c)

## Flat circular marker face for fallback only: solid quantized colour —
## never sample photoreal skins (those read as nearby planets).
static func _flat_marker_disc(_body_id: String, fallback: Color, diameter: int) -> Image:
	var d: int = maxi(diameter, 8)
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var col := _quantize_color(fallback, 6)
	var r: float = d * 0.5
	var cx := r
	var cy := r
	for y in d:
		for x in d:
			var dx: float = (x + 0.5) - cx
			var dy: float = (y + 0.5) - cy
			var dist: float = sqrt(dx * dx + dy * dy)
			if dist > r - 0.01:
				continue
			img.set_pixel(x, y, Color(col.r, col.g, col.b, 1.0))
	return img


static func _quantize_color(c: Color, steps: int) -> Color:
	var n: float = float(maxi(steps, 2) - 1)
	return Color(
		roundf(c.r * n) / n,
		roundf(c.g * n) / n,
		roundf(c.b * n) / n,
		c.a)

## The Sun's marker is a flat bright yellow disc with a soft glow halo —
## unmistakable and bigger than every other marker (tier 3.0).
static func _sun_marker_texture(s: int) -> Texture2D:
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c: float = s * 0.5
	var core: float = s * 0.34
	var halo: float = s * 0.48
	for y in s:
		for x in s:
			var d: float = Vector2(x + 0.5 - c, y + 0.5 - c).length()
			if d <= core:
				# Flat hot yellow — no sphere shading.
				img.set_pixel(x, y, Color(1.0, 0.92, 0.28, 1.0))
			elif d <= halo:
				var a: float = pow(1.0 - (d - core) / (halo - core), 1.6) * 0.75
				img.set_pixel(x, y, Color(1.0, 0.82, 0.25, a))
	return ImageTexture.create_from_image(img)

static func _icon_ring(img: Image, cx: float, cy: float, s: int, col: Color,
		front_half: bool) -> void:
	var rx: float = s * 0.47
	var ry: float = s * 0.16
	var thick: float = maxf(s * 0.05, 1.5)
	for y in s:
		for x in s:
			var py := float(y) + 0.5
			if front_half and py < cy:
				continue
			if not front_half and py >= cy:
				continue
			var dx := (float(x) + 0.5 - cx) / rx
			var dy := (py - cy) / ry
			var e := sqrt(dx * dx + dy * dy)
			# Signed distance from the ellipse edge, approximated in pixels.
			var dist_px: float = absf(e - 1.0) * minf(rx, ry) * 2.2
			if dist_px <= thick:
				var a: float = clampf(1.0 - dist_px / thick, 0.0, 1.0) * col.a
				var prev := img.get_pixel(x, y)
				img.set_pixel(x, y, prev.blend(Color(col.r, col.g, col.b, a)))

static func apply_to_material(mat: Material, body_id: String, fallback: Color) -> void:
	var tex := texture_for(body_id)
	if mat is StandardMaterial3D:
		var sm := mat as StandardMaterial3D
		if tex != null:
			sm.albedo_texture = tex
			sm.albedo_color = Color(1, 1, 1)
		else:
			sm.albedo_color = fallback
	elif mat is ShaderMaterial:
		var sh := mat as ShaderMaterial
		if tex != null and sh.shader != null:
			# Banded shader may ignore texture; set base_col from average.
			sh.set_shader_parameter("base_col", fallback)
			sh.set_shader_parameter("albedo_tex", tex)
			sh.set_shader_parameter("use_tex", 1.0)

static func make_skinned_material(b: Dictionary) -> Material:
	var id := str(b.get("id", ""))
	var col: Color = b.get("color", Color(0.7, 0.7, 0.7))
	var tex := texture_for(id)
	if bool(b.get("is_star", false)):
		var sun := StandardMaterial3D.new()
		sun.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sun.albedo_color = Color(1, 1, 1)
		if tex != null:
			sun.albedo_texture = tex
		else:
			sun.albedo_color = col
		sun.emission_enabled = true
		sun.emission = Color(1.0, 0.85, 0.35)
		sun.emission_energy_multiplier = 2.2
		return sun
	if id in ["jupiter", "saturn", "uranus", "neptune"]:
		var sh := Shader.new()
		sh.code = """
shader_type spatial;
render_mode unshaded, cull_back;
uniform vec4 base_col : source_color = vec4(0.8, 0.6, 0.4, 1.0);
uniform sampler2D albedo_tex : source_color;
uniform float use_tex = 0.0;
uniform float bands = 8.0;
void fragment() {
	vec3 texc = texture(albedo_tex, UV).rgb;
	float lat = UV.y;
	float stripe = 0.5 + 0.5 * sin(lat * bands * 3.14159);
	vec3 banded = mix(base_col.rgb * 0.75, base_col.rgb * 1.15, stripe);
	ALBEDO = mix(banded, texc, clamp(use_tex, 0.0, 1.0));
}
"""
		var sm := ShaderMaterial.new()
		sm.shader = sh
		sm.set_shader_parameter("base_col", col)
		sm.set_shader_parameter("bands", 14.0 if id == "jupiter" else 8.0)
		if tex != null:
			sm.set_shader_parameter("albedo_tex", tex)
			sm.set_shader_parameter("use_tex", 1.0)
		else:
			sm.set_shader_parameter("use_tex", 0.0)
		return sm
	var rocky := StandardMaterial3D.new()
	rocky.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	rocky.roughness = 0.88
	if tex != null:
		rocky.albedo_texture = tex
		rocky.albedo_color = Color(1, 1, 1)
	else:
		rocky.albedo_color = col
	return rocky

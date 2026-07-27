class_name PlanetSkins
extends RefCounted
## Albedo textures for flyer bodies. Prefers the generated photoreal
## cinematic maps (images/cinematic), falling back to the procedural skins
## (tools/gen_planet_skins.py) so nothing ever renders untextured.

const DIR := "res://images/planets"
const CINE_DIR := "res://images/cinematic"

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

## Recognizable navigation MARKER for the 3D flyer: a FLAT colored disc
## (no limb-darkening — markers are identifiers, not tiny planet renders),
## plus a ring silhouette for ringed worlds so Saturn still reads as Saturn.
## Baked once at load; billboarded unshaded in-flight.
static func make_icon_texture(b: Dictionary, size: int = 48) -> Texture2D:
	var s: int = maxi(size, 16)
	var id := str(b.get("id", ""))
	var col: Color = b.get("color", Color(0.7, 0.7, 0.7))
	if bool(b.get("is_star", false)):
		return _sun_marker_texture(s)
	var has_ring := bool(b.get("ring", false))
	# Keep the disc large even with rings — a tiny ringed disc made giants
	# look Earth-sized next to unringed markers.
	var disc_d: int = int(s * (0.72 if has_ring else 0.92))
	var disc_img := _flat_marker_disc(id, col, disc_d)

	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var off := Vector2i((s - disc_d) / 2, (s - disc_d) / 2)
	var cx := s * 0.5
	var cy := s * 0.5
	var ring_col := Color(0.86, 0.78, 0.55, 0.95)
	if has_ring:
		_icon_ring(img, cx, cy, s, ring_col, false)  # back half behind the disc
	img.blend_rect(disc_img, Rect2i(0, 0, disc_d, disc_d), off)
	if has_ring:
		_icon_ring(img, cx, cy, s, ring_col, true)   # front half over the disc
	return ImageTexture.create_from_image(img)

## Flat circular marker face: skin colours sampled as a disc (no sphere
## shading). Soft 1-px edge so it still reads as a clean pin, not a ball.
static func _flat_marker_disc(body_id: String, fallback: Color, diameter: int) -> Image:
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
			var col: Color
			if skin != null:
				var u: float = 0.5 + atan2(dx, r) / TAU
				var v: float = 0.5 + dy / (r * 2.0)
				col = skin.get_pixel(
					clampi(int(u * float(skin.get_width())), 0, skin.get_width() - 1),
					clampi(int(v * float(skin.get_height())), 0, skin.get_height() - 1))
			else:
				col = fallback
			# Soft edge only — no limb darkening.
			var edge: float = clampf((r - dist) * 2.0, 0.0, 1.0)
			img.set_pixel(x, y, Color(col.r, col.g, col.b, edge))
	return img

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

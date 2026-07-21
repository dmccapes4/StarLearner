class_name PlanetSkins
extends RefCounted
## Procedural albedo textures for flyer bodies (tools/gen_planet_skins.py).

const DIR := "res://images/planets"

static func texture_for(body_id: String) -> Texture2D:
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

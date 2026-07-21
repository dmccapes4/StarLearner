class_name BodyCell
extends Control
## Visual-only body in the horizontal strip. Skinned sphere via canvas shader
## (screen-fixed lighting + longitude spin — no rotating baked disc).

const DISC_Y := 220.0

var body: Dictionary
var _radius: float = 40.0
var _sphere: ColorRect
var _mat: ShaderMaterial
var _spin: float = 0.0

func setup(b: Dictionary) -> void:
	body = b
	_radius = float(b["draw_radius"])
	custom_minimum_size = Vector2(2.0 * _radius + 40.0, 560.0)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_text = b["name"]
	_spin = float(hash(str(b.get("id", ""))) % 1000) * 0.01
	_ensure_sphere()
	set_process(not bool(b.get("belt", false)))
	queue_redraw()

func contains_local_point(local: Vector2) -> bool:
	var r: float = _radius + 28.0
	var c := Vector2(size.x * 0.5, DISC_Y)
	return local.distance_to(c) <= r

func _process(delta: float) -> void:
	_spin += delta * (0.35 if not bool(body.get("is_star", false)) else 0.12)
	if _mat != null:
		_mat.set_shader_parameter("spin", _spin)

func _ensure_sphere() -> void:
	if bool(body.get("belt", false)):
		if _sphere != null:
			_sphere.visible = false
		return
	if _sphere == null:
		_sphere = ColorRect.new()
		_sphere.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_sphere)
		_mat = ShaderMaterial.new()
		_mat.shader = _sphere_shader()
		_sphere.material = _mat
	_sphere.visible = true
	_sphere.position = Vector2(size.x * 0.5 - _radius, DISC_Y - _radius)
	_sphere.size = Vector2(_radius * 2.0, _radius * 2.0)
	var col: Color = body.get("color", Color(0.7, 0.7, 0.7))
	_mat.set_shader_parameter("base_col", col)
	_mat.set_shader_parameter("spin", _spin)
	var tex := PlanetSkins.texture_for(str(body.get("id", "")))
	if tex != null:
		_mat.set_shader_parameter("skin", tex)
		_mat.set_shader_parameter("use_tex", 1.0)
	else:
		_mat.set_shader_parameter("use_tex", 0.0)

func _draw() -> void:
	var r: float = _radius
	var c := Vector2(size.x * 0.5, DISC_Y)
	if bool(body.get("belt", false)):
		_draw_belt(c, r)
	else:
		if bool(body.get("ring", false)):
			_draw_ring(c, r)
		# Soft rim (shader draws the filled sphere).
		draw_arc(c, r, 0.0, TAU, 48, Color(1, 1, 1, 0.22), 2.0)

	var font := ThemeDB.fallback_font
	_centered(font, body["name"], 30, Color(1, 1, 1), 430.0)
	if bool(body.get("dwarf", false)):
		_centered(font, "(not a planet anymore)", 20, Color(1.0, 0.62, 0.55), 466.0)
	elif bool(body.get("is_star", false)):
		_centered(font, "our star", 20, Color(1.0, 0.86, 0.5), 466.0)
	else:
		_centered(font, "tap to explore", 20, Color(0.72, 0.8, 1.0), 466.0)

func _sphere_shader() -> Shader:
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform vec4 base_col : source_color = vec4(0.7, 0.7, 0.7, 1.0);
uniform sampler2D skin : source_color, repeat_enable;
uniform float use_tex = 0.0;
uniform float spin = 0.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d2 = dot(p, p);
	if (d2 > 1.0) {
		discard;
	}
	float nz = sqrt(max(1.0 - d2, 0.0));
	float lon = atan(p.x, max(nz, 0.001)) + spin;
	float lat = asin(clamp(p.y, -1.0, 1.0));
	vec2 suv = vec2(fract(0.5 + lon / 6.2831853), clamp(0.5 - lat / 3.14159265, 0.0, 1.0));
	vec3 texc = texture(skin, suv).rgb;
	vec3 albedo = mix(base_col.rgb, texc, clamp(use_tex, 0.0, 1.0));
	// Soften equirectangular pole pinch (gray caps).
	float pole = smoothstep(0.72, 0.98, abs(p.y));
	albedo = mix(albedo, base_col.rgb, pole * 0.65);
	// Screen-fixed key light (does not spin with the planet).
	vec3 n = normalize(vec3(p.x, p.y, nz));
	vec3 l = normalize(vec3(-0.45, -0.55, 0.7));
	float lit = 0.38 + 0.62 * max(dot(n, l), 0.0);
	float limb = 0.78 + 0.22 * nz;
	COLOR = vec4(albedo * lit * limb, 1.0);
}
"""
	return sh

func _draw_belt(c: Vector2, r: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 909090
	for i in 60:
		var ang := rng.randf() * TAU
		var rad := rng.randf_range(0.15, 1.0) * r
		var p := c + Vector2(cos(ang) * rad, sin(ang) * rad * 0.9)
		draw_circle(p, rng.randf_range(2.0, 5.5), body["color"])

func _centered(font: Font, text: String, fsize: int, col: Color, y: float) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
	draw_string(font, Vector2(size.x * 0.5 - w * 0.5, y), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)

func _draw_ring(c: Vector2, r: float) -> void:
	var pts := PackedVector2Array()
	var steps := 48
	for i in steps + 1:
		var a := TAU * float(i) / float(steps)
		pts.append(c + Vector2(cos(a) * r * 1.7, sin(a) * r * 0.5))
	draw_polyline(pts, Color(0.9, 0.85, 0.6, 0.8), 5.0)

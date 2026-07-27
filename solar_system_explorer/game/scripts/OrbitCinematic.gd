class_name OrbitCinematic
extends Control
## Standalone arrival cinematic — one per destination, played on EVERY
## arrival, in any nav mode. Not tied to the flight scene's assets or state:
## its own world, its own lighting, its own camera move. Letterboxed slow
## dolly toward the world with an atmosphere rim, real ring geometry for the
## ringed giants, and a live corona for the Sun. Tap to skip.
##
## A full-rect CONTROL (not a CanvasLayer): on the Android mobile renderer a
## SubViewportContainer nested inside a CanvasLayer drew a TRANSPARENT
## texture, so "the cinematic" was letterbox bars + a title floating over the
## moving flight world behind it. Controls hosting SubViewportContainers are
## the pattern the device provably renders (FlyScene, Playground). The host
## scene hides its CanvasLayer HUD while the cinematic plays, and an opaque
## backdrop guarantees nothing behind can ever bleed through.

signal finished()

const DURATION_S := 9.0
## Taps within the grace window are ignored: arrival often lands mid button-
## mash (BOOST), and a stray touch must not skip the whole cinematic before
## a single frame of the destination has registered.
const SKIP_GRACE_S := 1.5
const TEX_DIR := "res://images/cinematic"

var _backdrop: ColorRect
var _host: SubViewportContainer
var _viewport: SubViewport
var _world: Node3D
var _cam: Camera3D
var _planet: Node3D
var _title: Label
var _bars_top: ColorRect
var _bars_bottom: ColorRect
var _t: float = 0.0
var _playing: bool = false
var _body_id: String = ""

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()

func play(body_id: String) -> void:
	_body_id = body_id
	_t = 0.0
	_playing = true
	visible = true
	move_to_front()   # above every sibling control of the host scene
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_build_subject(SolarData.flyer_body_by_id(body_id))
	_title.text = str(SolarData.flyer_body_by_id(body_id).get("name", body_id))
	_title.modulate.a = 0.0
	_place_cam(0.0)

func stop() -> void:
	_playing = false
	visible = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

func _process(delta: float) -> void:
	if not _playing:
		return
	_t += delta
	var u: float = clampf(_t / DURATION_S, 0.0, 1.0)
	_place_cam(u)
	if _planet != null:
		_planet.rotate_y(delta * 0.05)
	# Title: fade in over the first quarter, hold, fade near the end.
	_title.modulate.a = smoothstep(0.12, 0.30, u) * (1.0 - smoothstep(0.88, 1.0, u))
	if _t >= DURATION_S:
		_finish()

func _input(event: InputEvent) -> void:
	if not _playing or _t < SKIP_GRACE_S:
		return
	if (event is InputEventScreenTouch and event.pressed) \
			or (event is InputEventMouseButton and event.pressed):
		_finish()

func _finish() -> void:
	if not _playing:
		return
	stop()
	finished.emit()

## Slow approach dolly: start wide and high, ease into a low abeam pass —
## the world grows from a jewel to filling most of the glass.
func _place_cam(u: float) -> void:
	var e: float = smoothstep(0.0, 1.0, u)
	var dist: float = lerpf(9.5, 3.1, e)
	var ang: float = lerpf(-0.55, 0.25, e)
	var h: float = lerpf(1.7, 0.35, e)
	_cam.position = Vector3(cos(ang) * dist, h, sin(ang) * dist)
	_cam.look_at(Vector3(0.0, lerpf(0.25, 0.0, e), 0.0), Vector3.UP)

func _build() -> void:
	# Opaque backdrop: even if the 3D viewport ever failed to draw, the
	# cinematic reads as black space — never the scene behind it.
	_backdrop = ColorRect.new()
	_backdrop.color = Color(0, 0, 0, 1)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop)
	_host = SubViewportContainer.new()
	_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_host.stretch = true
	_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_host)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1280, 600)
	# CRITICAL: SubViewports share the ROOT viewport's World3D by default, so
	# the cinematic's camera (parked ~10 units from origin) was filming the
	# FLIGHT scene's sun and planets — "the cinematic flew past Earth and
	# Mars and never showed the destination". Every scene owns its world.
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_host.add_child(_viewport)

	_world = Node3D.new()
	_viewport.add_child(_world)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.004, 0.006, 0.016)
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.10, 0.12, 0.2)
	e.ambient_light_energy = 0.18
	e.glow_enabled = true
	e.glow_intensity = 0.55
	e.glow_bloom = 0.15
	e.glow_hdr_threshold = 1.0
	env.environment = e
	_world.add_child(env)

	var sun := DirectionalLight3D.new()
	sun.name = "KeyLight"
	sun.light_energy = 1.9
	sun.light_color = Color(1.0, 0.96, 0.9)
	sun.rotation_degrees = Vector3(-18, 128, 0)
	_world.add_child(sun)

	_add_stars()

	_cam = Camera3D.new()
	_cam.fov = 55.0
	_cam.near = 0.05
	_cam.far = 500.0
	_world.add_child(_cam)

	# Letterbox + title (cinema dressing).
	_bars_top = ColorRect.new()
	_bars_top.color = Color(0, 0, 0, 1)
	_bars_top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_bars_top.offset_bottom = 52
	_bars_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bars_top)
	_bars_bottom = ColorRect.new()
	_bars_bottom.color = Color(0, 0, 0, 1)
	_bars_bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_bars_bottom.offset_top = -52
	_bars_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bars_bottom)
	_title = Label.new()
	_title.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_title.offset_top = -130
	_title.offset_bottom = -70
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 44)
	_title.add_theme_color_override("font_color", Color(0.96, 0.97, 1.0))
	_title.add_theme_constant_override("shadow_offset_y", 2)
	_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title)

func _add_stars() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var cloud := Node3D.new()
	_world.add_child(cloud)
	for i in 140:
		var s := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = rng.randf_range(0.06, 0.22)
		sm.height = sm.radius * 2.0
		sm.radial_segments = 4
		sm.rings = 2
		s.mesh = sm
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.emission_enabled = true
		var warm: float = rng.randf()
		m.emission = Color(0.85 + warm * 0.15, 0.9, 1.0 - warm * 0.25)
		m.emission_energy_multiplier = rng.randf_range(0.8, 2.2)
		s.material_override = m
		s.position = Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.5, 0.5),
			rng.randf_range(-1, 1)).normalized() * rng.randf_range(120.0, 300.0)
		cloud.add_child(s)

## Cinematic texture: generated hero asset if present, procedural skin as a
## fallback so the scene never renders untextured.
static func texture_for(body_id: String) -> Texture2D:
	var path := "%s/%s.png" % [TEX_DIR, body_id]
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return PlanetSkins.texture_for(body_id)

func _build_subject(body: Dictionary) -> void:
	if _planet != null:
		_planet.queue_free()
	_planet = Node3D.new()
	_world.add_child(_planet)
	var id := str(body.get("id", _body_id))
	var col: Color = body.get("color", Color(0.7, 0.7, 0.75))
	var is_star := bool(body.get("is_star", false))

	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 64
	sphere.rings = 48
	mesh.mesh = sphere
	_planet.add_child(mesh)

	var tex := texture_for(id)
	if is_star:
		mesh.material_override = _sun_surface_material(tex)
		_planet.add_child(_corona_sprite())
	else:
		var m := StandardMaterial3D.new()
		m.roughness = 0.92
		if tex != null:
			m.albedo_texture = tex
			m.albedo_color = Color(1, 1, 1)
		else:
			m.albedo_color = col
		mesh.material_override = m
		_planet.add_child(_atmosphere_shell(_atmo_color(id, col)))

	if bool(body.get("ring", false)) or id == "uranus":
		_planet.add_child(_ring_disc(id))
	if id == "uranus":
		# Uranus rolls on its side — tip the whole world.
		_planet.rotation_degrees = Vector3(0, 0, 82)

## Thin fresnel-lit shell just above the surface — reads as an atmosphere.
func _atmosphere_shell(tint: Color) -> MeshInstance3D:
	var shell := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.03
	sm.height = 2.06
	sm.radial_segments = 48
	sm.rings = 32
	shell.mesh = sm
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode blend_add, unshaded, cull_back, depth_draw_never;
uniform vec4 tint : source_color = vec4(0.4, 0.6, 1.0, 1.0);
uniform float strength = 1.1;
void fragment() {
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.2);
	ALBEDO = tint.rgb * fres * strength;
	ALPHA = fres;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("tint", tint)
	shell.material_override = mat
	return shell

static func _atmo_color(id: String, base: Color) -> Color:
	match id:
		"earth":
			return Color(0.45, 0.65, 1.0)
		"venus":
			return Color(0.95, 0.82, 0.55)
		"mars":
			return Color(0.85, 0.55, 0.4)
		"jupiter", "saturn":
			return Color(0.9, 0.8, 0.6)
		"uranus", "neptune":
			return Color(0.5, 0.75, 0.95)
		_:
			# Airless rocks get a whisper-faint dusty limb, not a glow.
			return Color(base.r, base.g, base.b, 0.35)

## Flat annulus ring with soft radial banding (Saturn bold, Uranus faint).
func _ring_disc(id: String) -> MeshInstance3D:
	var ring := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(5.2, 5.2)
	ring.mesh = quad
	ring.rotation_degrees = Vector3(-90, 0, 0)
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled;
uniform vec4 tint : source_color = vec4(0.86, 0.78, 0.6, 1.0);
uniform float inner = 0.46;   // as fraction of quad half-size
uniform float outer = 0.95;
uniform float density = 0.8;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	if (r < inner || r > outer) { discard; }
	// Broad translucency zones + fine grooves, like Cassini division scans.
	float zones = 0.62 + 0.38 * sin(r * 34.0) * sin(r * 13.0 + 1.7);
	float fine = 0.92 + 0.08 * sin(r * 220.0);
	float band = zones * fine;
	float gap = 1.0 - 0.75 * smoothstep(0.72, 0.735, r) * (1.0 - smoothstep(0.75, 0.765, r));
	float edge = smoothstep(inner, inner + 0.03, r) * (1.0 - smoothstep(outer - 0.05, outer, r));
	ALBEDO = tint.rgb * (0.55 + 0.45 * band);
	ALPHA = band * gap * edge * density;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	if id == "uranus":
		mat.set_shader_parameter("tint", Color(0.7, 0.8, 0.85))
		mat.set_shader_parameter("density", 0.25)
		mat.set_shader_parameter("inner", 0.55)
		mat.set_shader_parameter("outer", 0.72)
	ring.material_override = mat
	return ring

## Boiling emissive surface for the Sun (animated value-noise cells).
func _sun_surface_material(tex: Texture2D) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_back;
uniform sampler2D surf : source_color;
uniform float use_tex = 0.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x),
		mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
void fragment() {
	vec2 uv = UV * vec2(8.0, 4.0);
	float n = vnoise(uv + TIME * 0.12) * 0.6 + vnoise(uv * 3.1 - TIME * 0.2) * 0.4;
	vec3 hot = vec3(1.0, 0.93, 0.55);
	vec3 cool = vec3(0.95, 0.45, 0.08);
	vec3 col = mix(cool, hot, n);
	if (use_tex > 0.5) { col = mix(col, texture(surf, UV).rgb, 0.45); }
	ALBEDO = col;
	EMISSION = col * 2.6;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	if tex != null:
		mat.set_shader_parameter("surf", tex)
		mat.set_shader_parameter("use_tex", 1.0)
	return mat

## Soft billboard corona behind the Sun.
func _corona_sprite() -> Sprite3D:
	var s := Sprite3D.new()
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.shaded = false
	s.double_sided = true
	var size := 256
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c: float = size * 0.5
	for y in size:
		for x in size:
			var d: float = Vector2(x + 0.5 - c, y + 0.5 - c).length() / c
			if d >= 1.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			else:
				var a: float = pow(maxf(1.0 - d, 0.0), 2.4) * 0.85
				img.set_pixel(x, y, Color(1.0, 0.8, 0.4, a))
	s.texture = ImageTexture.create_from_image(img)
	s.pixel_size = 0.022
	return s

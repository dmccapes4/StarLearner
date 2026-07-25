class_name FlyScene
extends Control
## Beat C — 3D autopilot flight through the compressed solar system.
## PathFollow3D on rails with cubic ease-in/out; LOD billboards; destination bloom.
## Cockpit/HUD overlay is wired (phase 5 asset) but flight math is independent.

signal arrived(dest_id: String)
signal go_home()
signal boost_pressed()
signal learn_more(dest_id: String)
signal chart_course(dest_id: String)

const BOOST_NUDGE := 0.08
const ORBIT_SPEED := 0.32
## Camera yaw from the orbit tangent toward the planet: with the 1280×600
## canopy's ~107° horizontal FOV this parks the planet in the side third of
## the glass (abeam-ish) while stars stream past ahead.
const ORBIT_CAM_YAW_DEG := 48.0
const ORBIT_ENTRY_BLEND_S := 1.6   ## seconds to blend path-forward → orbit view

## Burn-phase narration (baked VO; see dump_vo_lines.gd). The lines describe
## the ship, not passing geometry, so they can never go stale mid-flight.
const LINE_LAUNCH := "Engines on — hold tight, we're speeding up!"
const LINE_CRUISE := "Cruising speed!"
const LINE_FLIP := "Halfway there — time to turn the ship around and slow down!"
const LINE_HOLD := "Holding for our launch window…"
const LINE_BELT := "Whoa — we're inside the asteroid belt! Watch the space rocks glide past the window."

const ICON_TEX_PX := 48

var _cfg: SolarFlyerConfig
var _viewport: SubViewport
var _host: SubViewportContainer
var _world: Node3D
var _bodies_root: Node3D
var _path: Path3D
var _follow: PathFollow3D
var _cam: Camera3D
var _orbit_rig: Node3D
var _sun_light: OmniLight3D
var _body_nodes: Dictionary = {}
var _dest_id: String = ""
var _route: Dictionary = {}
var _t0: float = 0.0
var _flying: bool = false
var _orbiting: bool = false
var _flight_t: float = 0.0       ## linear seconds into the hop
var _duration: float = 20.0
var _path_len: float = 1.0
var _clock: float = 0.0
var _progress_u: float = 0.0     ## burn-profile path fraction 0..1
var _burn_phase: int = OrbitMath.PHASE_BURN
var _slung: bool = false
var _orbit_ang: float = 0.0
var _orbit_dir: float = 1.0        ## ±1, chosen to match arrival velocity
var _orbit_blend: float = 0.0      ## 0 at entry → 1 parked (camera + spiral-in)
var _orbit_entry_rad: float = 0.0  ## actual entry distance (spirals to standoff)
var _orbit_entry_fwd: Vector3 = Vector3.FORWARD
var _orbit_rest: float = 1.0       ## orbital clock scale, ramps to orbit_time_scale
var _belt_mm: MultiMeshInstance3D
var _belt_ring_r: float = 0.0
var _belt_called: bool = false     ## belt-crossing callout, once per hop
var _hud: CockpitHud
var _highlight_id: String = ""

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_cfg = SolarFlyerConfig.load_default()
	_build_viewport()
	_build_world()
	_hud = CockpitHud.new()
	add_child(_hud)
	_hud.boost_pressed.connect(_on_boost)
	_hud.go_home.connect(func() -> void: go_home.emit())
	_hud.learn_more_pressed.connect(func() -> void: learn_more.emit(_dest_id))
	_hud.chart_course_pressed.connect(func() -> void: chart_course.emit(_dest_id))
	visible = false

func set_active(on: bool) -> void:
	if not on:
		_flying = false
		_orbiting = false
		visible = false
		_hud.visible = false
		_hud.hide_arrival_choices()
		_hud.clear_callout()
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	else:
		visible = true
		_hud.visible = true
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

func begin_flight(dest_id: String, route: Dictionary, t0: float) -> void:
	# Reload knobs each hop so JSON overlays apply without restarting the app.
	_cfg = SolarFlyerConfig.load_default()
	_refresh_body_data()
	_dest_id = dest_id
	_route = route
	_t0 = t0
	_clock = t0
	_flight_t = 0.0
	_progress_u = 0.0
	_orbit_ang = 0.0
	_highlight_id = ""
	_duration = maxf(float(route.get("duration", 20.0)), 0.001)
	_path_len = maxf(float(route.get("path_len", 1.0)), 0.001)
	_burn_phase = OrbitMath.route_phase(0.0, route, _cfg)
	_slung = false
	_belt_called = false
	_flying = true
	_orbiting = false
	visible = true
	_hud.visible = true
	_hud.hide_arrival_choices()
	_hud.clear_callout()
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	var curve: Curve3D = route["curve"]
	_path.curve = curve
	_follow.progress_ratio = 0.0
	_follow.rotation_mode = PathFollow3D.ROTATION_ORIENTED
	# Re-parent camera onto the path follower for cruise.
	if _cam.get_parent() != _follow:
		_cam.reparent(_follow, false)
		_cam.position = Vector3.ZERO
		_cam.rotation = Vector3.ZERO
	_cam.current = true

	_place_bodies_at(_clock)
	_update_lod()
	var dest := SolarData.flyer_body_by_id(dest_id, _cfg)
	_hud.set_destination(dest)
	_hud.update_flight(0.0, 0.0)
	_hud.set_burn_phase(_burn_phase)
	_update_console()
	Narrator.speak(LINE_HOLD if _burn_phase == OrbitMath.PHASE_HOLD else LINE_LAUNCH)

func show_arrival_ui() -> void:
	var dest := SolarData.flyer_body_by_id(_dest_id, _cfg)
	_hud.show_arrival_choices(str(dest.get("name", _dest_id)))

func _refresh_body_data() -> void:
	var fresh := {}
	for b in SolarData.flyer_bodies(_cfg):
		fresh[str(b["id"])] = b
	for id in _body_nodes:
		if fresh.has(id):
			_body_nodes[id]["data"] = fresh[id]

func _process(delta: float) -> void:
	if _orbiting:
		_process_orbit(delta)
		return
	if not _flying:
		return

	_flight_t = minf(_duration, _flight_t + delta)
	var lin: float = clampf(_flight_t / _duration, 0.0, 1.0)
	_progress_u = OrbitMath.route_progress(lin, _route, _cfg)
	_follow.progress_ratio = _progress_u
	# duration == t_arr (plot_route invariant) → the sky runs at true rate.
	_clock = _t0 + _flight_t
	_update_burn_phase(lin)
	_update_slingshot(lin)
	_place_bodies_at(_clock)
	_aim_camera(_progress_u)
	_update_belt(_cam.global_position)
	_update_lod()
	_update_hud()
	_update_console()
	_spin_bodies(delta)

	# Peel off into orbit before the path dives into the planet center.
	if _try_enter_orbit_from_approach():
		return
	if lin >= 1.0:
		_try_enter_orbit_from_approach(true)

func _update_burn_phase(lin: float) -> void:
	var phase := OrbitMath.route_phase(lin, _route, _cfg)
	if phase == _burn_phase:
		return
	var was_hold: bool = _burn_phase == OrbitMath.PHASE_HOLD
	_burn_phase = phase
	_hud.set_burn_phase(phase)
	match phase:
		OrbitMath.PHASE_BURN:
			if was_hold:
				Narrator.speak(LINE_LAUNCH)
		OrbitMath.PHASE_COAST:
			Narrator.speak(LINE_CRUISE)
		OrbitMath.PHASE_BRAKE:
			Narrator.speak(LINE_FLIP)

func _update_slingshot(_lin: float) -> void:
	var sling: Dictionary = _route.get("slingshot", {})
	if sling.is_empty():
		if not _slung:
			return
		_slung = false
		return
	var past: bool = _progress_u * _path_len >= float(sling.get("s_cpa", INF))
	if past and not _slung:
		_slung = true
		_hud.show_callout("SLINGSHOT BOOST!")
	elif not past and _slung:
		_slung = false

func _spin_bodies(delta: float) -> void:
	for id in _body_nodes:
		var info: Dictionary = _body_nodes[id]
		var sph: Node3D = info["sphere"]
		if sph.visible:
			sph.rotate_y(float(info["data"].get("spin", 0.1)) * delta * 1.6)

func _try_enter_orbit_from_approach(force: bool = false) -> bool:
	var dest := SolarData.flyer_body_by_id(_dest_id, _cfg)
	if dest.is_empty():
		return false
	var center := OrbitMath.body_pos(dest, _clock)
	var hero: float = float(dest.get("hero_r", 2.0))
	var standoff: float = OrbitMath.sun_approach_standoff(_cfg) \
		if bool(dest.get("is_star", false)) else OrbitMath.orbit_standoff(hero)
	var ship: Vector3 = _follow.global_position
	var dist: float = ship.distance_to(center)
	if not force and dist > standoff:
		return false
	_flying = false
	_orbiting = true
	# Tangential entry (STRATEGY §4): keep the ship exactly where it arrived —
	# no teleport, no sunlit-side snap. The orbit direction is whichever way
	# best matches the arrival velocity, so travel direction is continuous;
	# the radius spirals in to the parking circle over the entry blend.
	var rel := ship - center
	if rel.length() < 0.001:
		rel = -_cam.global_transform.basis.z * standoff
	_orbit_ang = atan2(rel.z, rel.x)
	_orbit_entry_rad = maxf(rel.length(), standoff * 0.6)
	_orbit_entry_fwd = -_cam.global_transform.basis.z
	var tang_ccw := OrbitMath.orbit_tangent(_orbit_ang, 1.0)
	_orbit_dir = 1.0 if _orbit_entry_fwd.dot(tang_ccw) >= 0.0 else -1.0
	_orbit_blend = 0.0
	_orbit_rest = 1.0
	_hud.clear_callout()
	if _cam.get_parent() != _orbit_rig:
		_cam.reparent(_orbit_rig, false)
		_cam.position = Vector3.ZERO
		_cam.rotation = Vector3.ZERO
	_place_orbit_cam()
	arrived.emit(_dest_id)
	return true

func _enter_orbit() -> void:
	## Public/debug entry — prefer _try_enter_orbit_from_approach.
	_try_enter_orbit_from_approach(true)

func _process_orbit(delta: float) -> void:
	# The system rests while parked: the orbital clock ramps to a near-still
	# orbit_time_scale over ~2 s so narration plays over a calm sky. The
	# SHIP keeps circling — that motion is ours, not the planets'.
	_orbit_rest = maxf(_cfg.orbit_time_scale,
		_orbit_rest - delta * (1.0 - _cfg.orbit_time_scale) / 2.0)
	_clock += delta * _orbit_rest
	_orbit_blend = minf(1.0, _orbit_blend + delta / ORBIT_ENTRY_BLEND_S)
	_orbit_ang += delta * ORBIT_SPEED * _orbit_dir * _orbit_dwell_factor()
	_place_bodies_at(_clock)
	_place_orbit_cam()
	_update_belt(_cam.global_position)
	_update_lod()
	_update_console()
	_spin_bodies(delta)

## Sunlit-side bias without a snap: the ship hurries over the night side and
## lingers over the day side, so the parked view naturally settles where the
## planet is lit. The Sun itself glows from every angle — no bias needed.
func _orbit_dwell_factor() -> float:
	var dest := SolarData.flyer_body_by_id(_dest_id, _cfg)
	if dest.is_empty() or bool(dest.get("is_star", false)):
		return 1.0
	var center := OrbitMath.body_pos(dest, _clock)
	if center.length() < 0.001:
		return 1.0
	var sun_dir := -center.normalized()
	var off_dir := Vector3(cos(_orbit_ang), 0.0, sin(_orbit_ang))
	var dayness: float = 0.5 * (off_dir.dot(sun_dir) + 1.0)
	return lerpf(1.7, 0.55, dayness)

func _place_orbit_cam() -> void:
	var dest := SolarData.flyer_body_by_id(_dest_id, _cfg)
	if dest.is_empty():
		return
	var center := OrbitMath.body_pos(dest, _clock)
	var hero: float = float(dest.get("hero_r", 2.0))
	var standoff: float = OrbitMath.sun_approach_standoff(_cfg) \
		if bool(dest.get("is_star", false)) else OrbitMath.orbit_standoff(hero)
	# Spiral in: entry radius/height ease to the parking circle as we blend.
	var s: float = smoothstep(0.0, 1.0, _orbit_blend)
	var rad: float = lerpf(_orbit_entry_rad, standoff, s)
	var off := OrbitMath.orbit_offset(_orbit_ang, rad, 0.22 * s)
	_orbit_rig.global_position = center + off
	_cam.position = Vector3.ZERO
	# Forward-facing orbit camera: look along the direction of travel, yawed
	# toward the planet so it fills the side third of the canopy. The entry
	# blend slerps from the arrival heading — velocity direction stays
	# continuous through the seam (no look_at snap).
	var tangent := OrbitMath.orbit_tangent(_orbit_ang, _orbit_dir)
	var to_planet := (center - _orbit_rig.global_position).normalized()
	var side: float = signf(tangent.cross(to_planet).y)
	if side == 0.0:
		side = 1.0
	# Big worlds park abeam (full yaw) and fill the glass; small asteroids
	# get less yaw so they sit inside the frame instead of half off the edge.
	var yaw_deg: float = lerpf(28.0, ORBIT_CAM_YAW_DEG, clampf(hero / 6.0, 0.0, 1.0))
	var parked_fwd := tangent.rotated(Vector3.UP, side * deg_to_rad(yaw_deg))
	var fwd := _orbit_entry_fwd.slerp(parked_fwd, s)
	if fwd.length() > 0.001:
		_cam.look_at(_orbit_rig.global_position + fwd.normalized(), Vector3.UP)
	_hud.update_flight(1.0, CockpitHud.heading_angle(fwd, to_planet))

func _build_viewport() -> void:
	_host = SubViewportContainer.new()
	_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_host.stretch = true
	_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_host)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1280, 600)
	_viewport.transparent_bg = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_host.add_child(_viewport)

func _build_world() -> void:
	_world = Node3D.new()
	_viewport.add_child(_world)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.01, 0.015, 0.04)
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.22, 0.26, 0.38)
	e.ambient_light_energy = 0.55
	e.glow_enabled = true
	e.glow_intensity = 0.12
	e.glow_bloom = 0.05
	e.glow_hdr_threshold = 1.35
	env.environment = e
	_world.add_child(env)

	_sun_light = OmniLight3D.new()
	_sun_light.light_color = Color(1.0, 0.96, 0.88)
	_sun_light.light_energy = 2.0
	# No falloff — the compressed system spans ~650 units and real omni
	# attenuation left outer worlds (and even Mercury) nearly black.
	_sun_light.omni_attenuation = 0.0
	_sun_light.omni_range = 800.0
	_sun_light.shadow_enabled = false
	_world.add_child(_sun_light)

	_add_starfield()
	_bodies_root = Node3D.new()
	_world.add_child(_bodies_root)
	_build_bodies()
	_build_belt()

	_path = Path3D.new()
	_world.add_child(_path)
	_follow = PathFollow3D.new()
	_follow.loop = false
	_path.add_child(_follow)
	_orbit_rig = Node3D.new()
	_orbit_rig.name = "OrbitRig"
	_world.add_child(_orbit_rig)
	_cam = Camera3D.new()
	_cam.fov = 65.0
	_cam.near = 0.15
	_cam.far = 2000.0
	_follow.add_child(_cam)

func _build_bodies() -> void:
	for b in SolarData.flyer_bodies(_cfg):
		# The belt is a rock FIELD (_build_belt), not a body — no noise ball.
		if bool(b.get("belt", false)):
			continue
		var root := Node3D.new()
		root.name = str(b["id"])
		_bodies_root.add_child(root)

		var mesh := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 1.0
		sphere.height = 2.0
		sphere.radial_segments = 16
		sphere.rings = 12
		mesh.mesh = sphere
		mesh.material_override = PlanetSkins.make_skinned_material(b)
		mesh.name = "Sphere"
		root.add_child(mesh)

		if bool(b.get("ring", false)):
			var ring := MeshInstance3D.new()
			var torus := TorusMesh.new()
			torus.inner_radius = 1.35
			torus.outer_radius = 2.1
			torus.rings = 24
			torus.ring_segments = 8
			ring.mesh = torus
			var rm := StandardMaterial3D.new()
			rm.albedo_color = Color(0.86, 0.78, 0.55, 0.75)
			rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			ring.material_override = rm
			ring.rotation_degrees = Vector3(78, 0, 0)
			root.add_child(ring)

		# Thin gold outline ring (billboard) — never a filled yellow shell.
		var outline := Sprite3D.new()
		outline.name = "Outline"
		outline.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		outline.pixel_size = 0.045
		outline.texture = _make_ring_texture()
		outline.modulate = Color(1.0, 0.85, 0.25, 0.95)
		outline.visible = false
		outline.centered = true
		root.add_child(outline)

		# Recognizable icon billboard (constant screen size) instead of an
		# anonymous white dot — Saturn keeps its ring silhouette.
		var dot := Sprite3D.new()
		dot.name = "Icon"
		dot.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		dot.pixel_size = 0.04
		dot.texture = PlanetSkins.make_icon_texture(b, ICON_TEX_PX)
		dot.no_depth_test = true
		root.add_child(dot)

		_body_nodes[str(b["id"])] = {
			"root": root, "sphere": mesh, "dot": dot, "outline": outline, "data": b,
			"mesh_on": true, "tier": SolarData.icon_tier_for(b),
		}

func _make_ring_texture() -> Texture2D:
	var s := 64
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Vector2(s * 0.5, s * 0.5)
	var r_out := s * 0.48
	var r_in := s * 0.40
	for y in s:
		for x in s:
			var d: float = Vector2(x + 0.5, y + 0.5).distance_to(c)
			if d <= r_out and d >= r_in:
				var a: float = 1.0 - absf(d - (r_in + r_out) * 0.5) / ((r_out - r_in) * 0.5)
				img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)

func _build_belt() -> void:
	var belt := SolarData.flyer_body_by_id("asteroid_belt", _cfg)
	if belt.is_empty():
		return
	var mm := MultiMeshInstance3D.new()
	var multi := MultiMesh.new()
	var rock := SphereMesh.new()
	rock.radius = 0.35
	rock.height = 0.7
	rock.radial_segments = 6
	rock.rings = 4
	multi.mesh = rock
	multi.transform_format = MultiMesh.TRANSFORM_3D
	# 640 rocks, still one draw call; culled entirely beyond belt_cull_dist,
	# so the Moto G only ever pays for them while actually near the ring.
	var xforms: Array = OrbitMath.belt_transforms(float(belt["orbit_r"]), 640, 909091)
	multi.instance_count = xforms.size()
	for i in xforms.size():
		multi.set_instance_transform(i, xforms[i])
	mm.multimesh = multi
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.62, 0.58, 0.52)
	# Invisible until you're IN it (STRATEGY §5.1): dither-fade rocks out
	# between belt_fade_near and belt_fade_far of the camera. Dither, not
	# alpha — no transparency sorting cost on the Moto G.
	mat.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER
	mat.distance_fade_max_distance = _cfg.belt_fade_near
	mat.distance_fade_min_distance = _cfg.belt_fade_far
	mm.material_override = mat
	_world.add_child(mm)
	_belt_mm = mm
	_belt_ring_r = float(belt["orbit_r"])

## Skip the whole rock MultiMesh when the ship is far from the ring, and fire
## the belt-crossing moment (callout + narration) the first time the camera
## actually enters the rock field on a hop.
func _update_belt(cam_pos: Vector3) -> void:
	if _belt_mm == null:
		return
	var ring_d: float = absf(Vector2(cam_pos.x, cam_pos.z).length() - _belt_ring_r)
	var d: float = sqrt(ring_d * ring_d + cam_pos.y * cam_pos.y)
	_belt_mm.visible = d < _cfg.belt_cull_dist
	# Callout only when properly INSIDE the field (0.8× the fade band), so a
	# course that merely grazes the band never shouts over faint rocks.
	if _flying and not _belt_called and d < _cfg.belt_fade_near * 0.8:
		_belt_called = true
		_hud.show_callout("ASTEROID FIELD!")
		Narrator.speak(LINE_BELT)

func _add_starfield() -> void:
	var stars := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 900.0
	sphere.height = 1800.0
	sphere.radial_segments = 16
	sphere.rings = 12
	stars.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_FRONT
	mat.albedo_color = Color(0.02, 0.03, 0.06)
	stars.material_override = mat
	_world.add_child(stars)
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	var cloud := Node3D.new()
	_world.add_child(cloud)
	for i in 80:
		var s := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = rng.randf_range(0.4, 1.1)
		sm.height = sm.radius * 2.0
		sm.radial_segments = 4
		sm.rings = 2
		s.mesh = sm
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(1, 1, 1)
		m.emission_enabled = true
		m.emission = Color(0.9, 0.95, 1.0)
		m.emission_energy_multiplier = 1.2
		s.material_override = m
		var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.4, 0.4),
			rng.randf_range(-1, 1)).normalized()
		s.position = dir * rng.randf_range(420.0, 780.0)
		cloud.add_child(s)

func _place_bodies_at(at_t: float) -> void:
	for id in _body_nodes:
		var info: Dictionary = _body_nodes[id]
		var b: Dictionary = info["data"]
		var root: Node3D = info["root"]
		root.position = OrbitMath.body_pos(b, at_t)
		root.scale = Vector3.ONE * float(b.get("hero_r", 1.0))

func _aim_camera(u: float) -> void:
	# The camera faces the velocity vector, always: identity against the
	# oriented PathFollow3D (its -Z is the path tangent), plus a gentle roll.
	# No destination stare — the course ends at the intercept, so the target
	# slides to center on final approach purely from the geometry.
	_cam.rotation = Vector3(0.0, 0.0, deg_to_rad(sin(u * PI) * 3.0))

func _update_lod() -> void:
	# Per-body proximity rendering (STRATEGY_FLIGHT_DYNAMICS_AND_PROXIMITY §3.2):
	# beyond render_in a world is a constant-screen-size icon; crossing it, the
	# mesh appears scale-matched to the icon's current world size and grows by
	# genuine proximity from there — no pop, no ballooning past hero size.
	var cam_pos: Vector3 = _cam.global_position
	for id in _body_nodes:
		var info: Dictionary = _body_nodes[id]
		var b: Dictionary = info["data"]
		var root: Node3D = info["root"]
		var sph: MeshInstance3D = info["sphere"]
		var dot: Sprite3D = info["dot"]
		var outline: Sprite3D = info["outline"]
		var hero: float = float(b.get("hero_r", 1.0))
		var dist: float = cam_pos.distance_to(root.global_position)
		var is_star: bool = bool(b.get("is_star", false))
		var render_in: float = OrbitMath.render_in_dist(hero, _cfg)
		var icon_w: float = OrbitMath.icon_world_size(dist, float(info["tier"]), _cfg)
		# Small hysteresis so the icon↔mesh handoff can't flicker at the line.
		var mesh_on: bool = is_star or OrbitMath.lod_want_mesh(
			dist, bool(info["mesh_on"]), render_in * 0.97, render_in * 1.03)
		var apparent: float = OrbitMath.apparent_size(dist, hero, _cfg)
		# Destination grows toward hero size near arrival — capped at 1.0× hero.
		if id == _dest_id and (_progress_u > 0.7 or _orbiting):
			mesh_on = true
			apparent = maxf(apparent, hero * lerpf(0.85, 1.0, clampf(_progress_u, 0.0, 1.0)))
		info["mesh_on"] = mesh_on
		sph.visible = mesh_on
		dot.visible = not mesh_on
		# No gold ring in orbit — the parked world speaks for itself, and on
		# small asteroids the ring reads as clutter. (Proximity pings live on
		# the console, not in the sky.)
		outline.visible = false
		if mesh_on:
			# The Sun never scale-matches an icon (it is always a mesh). Other
			# worlds blend from the icon's exact world size at render_in down
			# to true proximity size across the 20% crossfade band — the mesh
			# literally starts as the icon and grows.
			var scale_w: float = apparent
			if not is_star:
				var band0: float = render_in * 0.8
				var w: float = clampf((dist - band0) / maxf(render_in - band0, 0.001), 0.0, 1.0)
				scale_w = lerpf(apparent, icon_w, w)
			if id == _dest_id and (_progress_u > 0.7 or _orbiting):
				scale_w = maxf(scale_w, apparent)
			root.scale = Vector3.ONE * scale_w
		else:
			root.scale = Vector3.ONE
			dot.pixel_size = icon_w / float(ICON_TEX_PX)

func _update_hud() -> void:
	var dest := SolarData.flyer_body_by_id(_dest_id, _cfg)
	if dest.is_empty():
		_hud.update_flight(_progress_u, 0.0)
		return
	var aim := OrbitMath.body_pos(dest, _clock) - _cam.global_position
	var forward := -_cam.global_transform.basis.z
	var heading := CockpitHud.heading_angle(forward, aim)
	_hud.update_flight(_progress_u, heading)

func _update_console() -> void:
	if _route.is_empty() or not _route.has("curve"):
		return
	var curve: Curve3D = _route["curve"]
	var panel := Vector2(300, 130)
	var bmin := Vector2(-5, -5)
	var bmax := Vector2(5, 5)
	for b in SolarData.flyer_bodies(_cfg):
		var p := OrbitMath.body_pos(b, _clock)
		bmin.x = minf(bmin.x, p.x)
		bmin.y = minf(bmin.y, p.z)
		bmax.x = maxf(bmax.x, p.x)
		bmax.y = maxf(bmax.y, p.z)
	var pad := (bmax - bmin) * 0.08
	bmin -= pad
	bmax += pad
	var bodies: Array = []
	for b in SolarData.flyer_bodies(_cfg):
		if bool(b.get("is_star", false)) or bool(b.get("belt", false)):
			continue
		var bid := str(b["id"])
		# Gold-ping worlds that triggered the proximity render mid-cruise —
		# the honest "look, we're passing close!" cue (no camera theft).
		var hot: bool = (not _orbiting) and bid != _dest_id \
			and _body_nodes.has(bid) and bool(_body_nodes[bid]["mesh_on"])
		var wp := OrbitMath.body_pos(b, _clock)
		bodies.append({
			"pos": CockpitHud.console_project(wp, bmin, bmax, panel),
			"color": b["color"],
			"name": b["name"],
			"hot": hot,
		})
	var pts := PackedVector2Array()
	var len: float = maxf(curve.get_baked_length(), 0.001)
	for i in 24:
		var u := float(i) / 23.0
		pts.append(CockpitHud.console_project(curve.sample_baked(u * len), bmin, bmax, panel))
	var ship_w: Vector3
	if _orbiting:
		ship_w = _orbit_rig.global_position
	else:
		ship_w = OrbitMath.path_sample(curve, _progress_u)
	var dest := SolarData.flyer_body_by_id(_dest_id, _cfg)
	var dest_w: Vector3 = Vector3.ZERO
	if not dest.is_empty():
		dest_w = OrbitMath.body_pos(dest, _clock)
	elif _route.has("arrival_pos"):
		dest_w = _route["arrival_pos"]
	_hud.set_console_map(
		CockpitHud.console_project(ship_w, bmin, bmax, panel),
		CockpitHud.console_project(dest_w, bmin, bmax, panel),
		pts, bodies)

func _on_boost() -> void:
	if not _flying:
		return
	_flight_t = OrbitMath.apply_boost(_flight_t, _duration, BOOST_NUDGE)
	boost_pressed.emit()

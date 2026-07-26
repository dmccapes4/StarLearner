class_name FlyScene
extends Control
## Beat C — 3D autopilot flight through the compressed solar system.
## SIM-FIRST: plot_route already ran the whole navigation simulation; this
## scene just PLAYS BACK the route's timeline (positions, headings, events)
## and never re-derives geometry live — what was charted is what flies.
##
## RENDERING: worlds are POINTS in the simulation. In flight every body —
## Sun, planets, and the three named asteroids alike — is a sized icon
## marker at its true bearing (constant screen size, tiered by real size
## rank). The destination marker swells modestly on final approach but never
## gets large: nearby worlds look far away. Planets are only ever BIG in
## orbit, via the precomputed entry cinematic — when the flight timeline
## ends on the parking sphere, the real skinned mesh takes over from the
## marker and grows through a close-up approach into a smooth parked orbit,
## with arrival narration, while the simulation keeps ticking underneath.

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
const ORBIT_ENTRY_BLEND_S := 3.5   ## seconds to blend approach heading → orbit view
const APPROACH_S := 6.0            ## approach cinematic: marker → full-size world
const ORBIT_HANDOFF_FRAC := 0.6    ## planet ~60% grown → orbit blend starts early
const ICON_TEX_PX := 48
## Playback rate of the sim timeline. Timing need not be constant: the
## cruise plays slower than sim time (space should feel like a CRUISE), and
## time eases down further on final approach for the cinematic.
const CRUISE_RATE := 0.55
const APPROACH_RATE := 0.22

## Burn-phase narration (baked VO; see dump_vo_lines.gd). The lines describe
## the ship, not passing geometry, so they can never go stale mid-flight.
## The ship never visibly flips — the camera faces the direction of travel
## the whole way; the brake line only talks about slowing down.
const LINE_LAUNCH := "Engines on — hold tight, we're speeding up!"
const LINE_CRUISE := "Cruising speed!"
const LINE_BRAKE := "Halfway there — time to start slowing down!"

var _cfg: SolarFlyerConfig
var _viewport: SubViewport
var _host: SubViewportContainer
var _world: Node3D
var _bodies_root: Node3D
var _ship_rig: Node3D            ## camera carrier during flight playback
var _cam: Camera3D
var _orbit_rig: Node3D
var _sun_light: OmniLight3D
var _body_nodes: Dictionary = {}
var _dest_id: String = ""
var _route: Dictionary = {}
var _tl_pos: PackedVector3Array = PackedVector3Array()
var _tl_fwd: PackedVector3Array = PackedVector3Array()
var _tl_dt: float = OrbitMath.SIM_DT
var _tl_events: Array = []
var _tl_entry: Dictionary = {}
var _ev_idx: int = 0             ## next timeline event to fire
var _t0: float = 0.0
var _flying: bool = false
var _orbiting: bool = false
var _flight_t: float = 0.0       ## linear seconds into the hop
var _duration: float = 20.0
var _path_len: float = 1.0
var _clock: float = 0.0
var _progress_u: float = 0.0     ## burn-profile path fraction 0..1
var _burn_phase: int = OrbitMath.PHASE_BURN
var _orbit_ang: float = 0.0
var _orbit_dir: float = 1.0        ## ±1, chosen to match arrival velocity
var _orbit_blend: float = 0.0      ## 0 at entry → 1 parked (camera + spiral-in)
var _orbit_entry_rad: float = 0.0  ## actual entry distance (spirals to standoff)
var _orbit_entry_fwd: Vector3 = Vector3.FORWARD
var _approach_t: float = 0.0       ## seconds into the approach cinematic
var _approach_d0: float = 1.0      ## virtual start distance (icon-matched)
var _orbit_rest: float = 1.0       ## orbital clock scale, ramps to orbit_time_scale
var _belt_mm: MultiMeshInstance3D
var _belt_ring_r: float = 0.0
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
	# The navigation simulation already ran at plot time — load its timeline.
	var tl: Dictionary = route.get("timeline", {})
	_tl_pos = tl.get("pos", PackedVector3Array())
	_tl_fwd = tl.get("fwd", PackedVector3Array())
	_tl_dt = maxf(float(tl.get("dt", OrbitMath.SIM_DT)), 0.001)
	_tl_events = tl.get("events", [])
	_tl_entry = tl.get("entry", {})
	_ev_idx = 0
	_spawn_belt_encounter()
	_flying = true
	_orbiting = false
	visible = true
	_hud.visible = true
	_hud.hide_arrival_choices()
	_hud.clear_callout()
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	# Camera rides the ship rig; the rig plays back the sim timeline.
	if _cam.get_parent() != _ship_rig:
		_cam.reparent(_ship_rig, false)
		_cam.position = Vector3.ZERO
		_cam.rotation = Vector3.ZERO
	_cam.current = true
	_place_ship_at(0.0)

	_place_bodies_at(_clock)
	_update_markers()
	var dest := SolarData.flyer_body_by_id(dest_id, _cfg)
	_hud.set_destination(dest)
	_hud.update_flight(0.0, 0.0)
	_hud.set_burn_phase(_burn_phase)
	_update_console()
	Narrator.speak(LINE_LAUNCH)
	# The t=0 phase event is spoken above — skip past it.
	while _ev_idx < _tl_events.size() and float(_tl_events[_ev_idx]["t"]) <= 0.0:
		_ev_idx += 1

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

	_flight_t = minf(_duration, _flight_t + delta * _flight_play_rate())
	var lin: float = clampf(_flight_t / _duration, 0.0, 1.0)
	_progress_u = OrbitMath.route_progress(lin, _route, _cfg)
	# duration == t_arr (plot_route invariant) → the sky runs at true rate.
	_clock = _t0 + _flight_t
	_place_ship_at(_flight_t)
	_fire_timeline_events()
	_place_bodies_at(_clock)
	_update_markers()
	_update_hud()
	_update_console()
	_spin_bodies(delta)

	# The simulation charted the hop to END on the parking sphere — when the
	# playback clock runs out, we are AT orbit entry. No live geometry check.
	if _flight_t >= _duration:
		_enter_orbit_from_timeline()

## Variable playback rate: slow cruise, easing down further as the ship
## nears the destination — the "approach trigger" slow-down that sets up the
## cinematic. Purely presentation; the sim timeline itself is untouched.
func _flight_play_rate() -> float:
	var dinfo: Dictionary = _body_nodes.get(_dest_id, {})
	if dinfo.is_empty():
		return CRUISE_RATE
	var hero: float = float(dinfo["data"].get("hero_r", 1.0))
	var stand: float = OrbitMath.sun_approach_standoff(_cfg) \
		if bool(dinfo["data"].get("is_star", false)) \
		else OrbitMath.orbit_standoff(hero)
	var dist: float = _cam.global_position.distance_to(
		(dinfo["root"] as Node3D).global_position)
	var far_d: float = stand * 2.5
	var t: float = clampf((far_d - dist) / maxf(far_d - stand, 0.001), 0.0, 1.0)
	return lerpf(CRUISE_RATE, APPROACH_RATE, smoothstep(0.0, 1.0, t))

## Playback: interpolate the sim timeline at t seconds into the hop and pose
## the ship rig. The camera faces the direction of travel, always — the ship
## never flips; deceleration is just the profile slowing down.
func _place_ship_at(t: float) -> void:
	if _tl_pos.size() < 2:
		return
	var idx_f: float = clampf(t / _tl_dt, 0.0, float(_tl_pos.size() - 1))
	var i: int = mini(int(idx_f), _tl_pos.size() - 2)
	var frac: float = clampf(idx_f - float(i), 0.0, 1.0)
	var p: Vector3 = _tl_pos[i].lerp(_tl_pos[i + 1], frac)
	var f: Vector3 = _tl_fwd[i].lerp(_tl_fwd[i + 1], frac)
	_ship_rig.global_position = p
	if f.length() > 0.001:
		_ship_rig.look_at(p + f.normalized(), Vector3.UP)
	# Gentle roll with course curvature — cosmetic only.
	_cam.rotation = Vector3(0.0, 0.0, deg_to_rad(sin(_progress_u * PI) * 3.0))

## Fire every pending sim event up to the playback clock. The sim records
## only burn-phase changes — there are no alarms and no flyby callouts.
func _fire_timeline_events() -> void:
	while _ev_idx < _tl_events.size() \
			and float(_tl_events[_ev_idx]["t"]) <= _flight_t:
		var ev: Dictionary = _tl_events[_ev_idx]
		_ev_idx += 1
		if str(ev["kind"]) == "phase":
			_apply_phase_event(int(ev["phase"]))

func _apply_phase_event(phase: int) -> void:
	if phase == _burn_phase:
		return
	_burn_phase = phase
	_hud.set_burn_phase(phase)
	match phase:
		OrbitMath.PHASE_COAST:
			Narrator.speak(LINE_CRUISE)
		OrbitMath.PHASE_BRAKE:
			Narrator.speak(LINE_BRAKE)

func _spin_bodies(delta: float) -> void:
	for id in _body_nodes:
		var info: Dictionary = _body_nodes[id]
		var sph: Node3D = info["sphere"]
		if sph.visible:
			sph.rotate_y(float(info["data"].get("spin", 0.1)) * delta * 1.6)

## Orbit entry straight from the simulation's precomputed entry state — the
## timeline ENDS on the parking sphere, so the seam is position- and
## heading-continuous by construction (no live checks, no recoil).
##
## The entry plays as TWO pre-computed cinematics while the simulation keeps
## ticking underneath:
##   1. APPROACH (APPROACH_S): the heading eases from the arc's arrival
##      bearing dead onto the planet; the marker hands off to the real
##      mesh at the exact same angular size, then grows by the true
##      perspective law (scale ∝ 1/virtual-distance) as if flying straight
##      in — natural growth, no lerp "inflation".
##   2. ORBIT BLEND (ORBIT_ENTRY_BLEND_S): heading slerps from the approach
##      bearing onto the orbit tangent and the parked lap begins.
func _enter_orbit_from_timeline() -> void:
	if _orbiting:
		return
	_flying = false
	_orbiting = true
	if _tl_entry.is_empty():
		# Defensive fallback (a route without a timeline): park on the
		# current approach bearing at the standoff radius.
		var dest := SolarData.flyer_body_by_id(_dest_id, _cfg)
		var center := OrbitMath.body_pos(dest, _clock)
		var rel := _ship_rig.global_position - center
		if rel.length() < 0.001:
			rel = Vector3.RIGHT
		_orbit_ang = atan2(rel.z, rel.x)
		_orbit_entry_rad = rel.length()
		_orbit_entry_fwd = -_cam.global_transform.basis.z
	else:
		_orbit_ang = float(_tl_entry["ang"])
		_orbit_entry_rad = float(_tl_entry["rad"])
		_orbit_entry_fwd = _tl_entry["fwd"]
	var tang_ccw := OrbitMath.orbit_tangent(_orbit_ang, 1.0)
	_orbit_dir = 1.0 if _orbit_entry_fwd.dot(tang_ccw) >= 0.0 else -1.0
	if not _tl_entry.is_empty():
		_orbit_dir = float(_tl_entry.get("dir", _orbit_dir))
	_orbit_blend = 0.0
	_orbit_rest = 1.0
	_approach_t = 0.0
	# Virtual approach start: the distance at which the TRUE mesh subtends
	# exactly the marker's final on-screen size — the handoff is seamless.
	var dinfo: Dictionary = _body_nodes.get(_dest_id, {})
	if not dinfo.is_empty():
		var hero: float = float(dinfo["data"].get("hero_r", 1.0))
		var icon_w: float = OrbitMath.marker_world_size(_orbit_entry_rad,
			float(dinfo["tier"]), _cfg)
		_approach_d0 = maxf(2.0 * hero * _orbit_entry_rad / maxf(icon_w, 0.001),
			_orbit_entry_rad)
	else:
		_approach_d0 = _orbit_entry_rad
	_hud.clear_callout()
	if _cam.get_parent() != _orbit_rig:
		_cam.reparent(_orbit_rig, false)
		_cam.position = Vector3.ZERO
		_cam.rotation = Vector3.ZERO
	_place_orbit_cam()
	arrived.emit(_dest_id)

func _enter_orbit() -> void:
	## Public/debug entry — jump playback to the end of the hop.
	_flight_t = _duration
	_enter_orbit_from_timeline()

func _process_orbit(delta: float) -> void:
	# The system rests while parked: the orbital clock ramps to a near-still
	# orbit_time_scale over ~2 s so narration plays over a calm sky. The
	# SHIP keeps circling — that motion is ours, not the planets'.
	_orbit_rest = maxf(_cfg.orbit_time_scale,
		_orbit_rest - delta * (1.0 - _cfg.orbit_time_scale) / 2.0)
	_clock += delta * _orbit_rest
	# Approach cinematic: the camera holds the straight-in arrival pose
	# while the planet grows. Once it reaches ~ORBIT_HANDOFF_FRAC of full
	# size the orbit blend starts EARLY, overlapping the tail of the growth
	# — the course adjustment onto the tangent is hardly noticed.
	if _approach_t < APPROACH_S:
		_approach_t += delta
	if _approach_frac() >= ORBIT_HANDOFF_FRAC or _approach_t >= APPROACH_S:
		_orbit_blend = minf(1.0, _orbit_blend + delta / ORBIT_ENTRY_BLEND_S)
		_orbit_ang += delta * ORBIT_SPEED * _orbit_dir * _orbit_dwell_factor()
	_place_bodies_at(_clock)
	_place_orbit_cam()
	_update_markers()
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
	# Approach faces the PLANET: the transfer arc arrives at the parking
	# sphere on a swept tangent, so over the first half of the approach the
	# heading eases from that arrival bearing dead onto the planet — it
	# grows centered in the glass, a genuine straight-in approach — before
	# the orbit blend swings it onto the parked tangent.
	var a: float = smoothstep(0.0, 1.0,
		clampf(_approach_t / (APPROACH_S * 0.5), 0.0, 1.0))
	var approach_fwd := _orbit_entry_fwd.slerp(to_planet, a)
	var fwd := approach_fwd.slerp(parked_fwd, s)
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

	_ship_rig = Node3D.new()
	_ship_rig.name = "ShipRig"
	_world.add_child(_ship_rig)
	_orbit_rig = Node3D.new()
	_orbit_rig.name = "OrbitRig"
	_world.add_child(_orbit_rig)
	_cam = Camera3D.new()
	_cam.fov = 65.0
	_cam.near = 0.15
	_cam.far = 2000.0
	_ship_rig.add_child(_cam)

## One node per body: a recognizable ICON billboard (the flight
## representation — Saturn keeps its ring silhouette) plus a hidden skinned
## mesh that only the orbit-entry cinematic ever shows. Sun, planets, and
## the named asteroids are all built identically.
func _build_bodies() -> void:
	for b in SolarData.flyer_bodies(_cfg):
		# The belt is a rock FIELD (_build_belt), not a body — no noise ball.
		if bool(b.get("belt", false)):
			continue
		var root := Node3D.new()
		root.name = str(b["id"])
		_bodies_root.add_child(root)

		var icon := Sprite3D.new()
		icon.name = "Icon"
		icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		icon.texture = PlanetSkins.make_icon_texture(b, ICON_TEX_PX)
		icon.pixel_size = 0.04
		root.add_child(icon)

		var mesh := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 1.0
		sphere.height = 2.0
		sphere.radial_segments = 16
		sphere.rings = 12
		mesh.mesh = sphere
		mesh.material_override = PlanetSkins.make_skinned_material(b)
		mesh.name = "Sphere"
		mesh.visible = false
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
			ring.name = "Ring"
			mesh.add_child(ring)

		_body_nodes[str(b["id"])] = {
			"root": root, "sphere": mesh, "icon": icon, "data": b,
			"tier": SolarData.icon_tier_for(b),
		}

## Empty MultiMesh shell; rocks are spawned per flight by
## _spawn_belt_encounter — a cinematic effect, not persistent scenery.
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
	multi.instance_count = 0
	mm.multimesh = multi
	var mat := StandardMaterial3D.new()
	# Dark, unremarkable rocks — the NAMED asteroids are the meaningful
	# objects; the field is just atmosphere drifting past the window.
	mat.albedo_color = Color(0.3, 0.28, 0.26)
	# Dither-fade with distance (no transparency sorting cost on the Moto G):
	# rocks appear only around the ship, deep inside the crossing.
	mat.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER
	mat.distance_fade_max_distance = _cfg.belt_fade_near
	mat.distance_fade_min_distance = _cfg.belt_fade_far
	mm.material_override = mat
	_world.add_child(mm)
	_belt_mm = mm
	_belt_ring_r = float(belt["orbit_r"])

## A fresh rock encounter every flight: scatter a sparse handful of rocks
## around the charted path where it crosses the ring, seeded randomly so
## each passthrough looks different. No crossing → no rocks.
func _spawn_belt_encounter() -> void:
	if _belt_mm == null:
		return
	var xforms: Array = OrbitMath.belt_encounter_transforms(
		_tl_pos, _belt_ring_r, randi())
	_belt_mm.multimesh.instance_count = xforms.size()
	for i in xforms.size():
		_belt_mm.multimesh.set_instance_transform(i, xforms[i])
	_belt_mm.visible = xforms.size() > 0

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
		var root: Node3D = info["root"]
		root.position = OrbitMath.body_pos(info["data"], at_t)

## Pure projection of the sim record: every world is a POINT drawn as a
## small legible icon MARKER at its true bearing (OrbitMath.marker_world_size
## — constant screen size, recognition tiers, NO proximity growth ever). The
## only mesh ever shown is the destination's, during the orbit-entry
## cinematic: it takes over from the marker at the marker's exact size and
## grows through a close-up approach to full hero size as the orbit parks.
func _update_markers() -> void:
	var cam_pos: Vector3 = _cam.global_position
	for id in _body_nodes:
		var info: Dictionary = _body_nodes[id]
		var root: Node3D = info["root"]
		var icon: Sprite3D = info["icon"]
		var mesh: MeshInstance3D = info["sphere"]
		var hero: float = float(info["data"].get("hero_r", 1.0))
		var dist: float = maxf(cam_pos.distance_to(root.global_position), 0.001)
		var in_entry: bool = _orbiting and id == _dest_id
		icon.visible = not in_entry
		mesh.visible = in_entry
		if in_entry:
			# Approach cinematic: the mesh grows by the TRUE perspective law.
			# A virtual straight-in dolly runs from _approach_d0 (where the
			# real planet subtends exactly the marker's size — seamless
			# handoff) down to the parking distance; scale = hero · dist/d,
			# so the growth is exactly what flying straight at the planet
			# looks like. Ends at full hero size as the orbit blend parks.
			var u: float = clampf(_approach_t / APPROACH_S, 0.0, 1.0)
			var d_virt: float = lerpf(_approach_d0, dist,
				smoothstep(0.0, 1.0, u))
			mesh.scale = Vector3.ONE * (hero * dist / maxf(d_virt, 0.001))
		else:
			icon.pixel_size = OrbitMath.marker_world_size(dist,
				float(info["tier"]), _cfg) / float(ICON_TEX_PX)

## Current approach growth fraction (mesh scale / full hero size).
func _approach_frac() -> float:
	var dinfo: Dictionary = _body_nodes.get(_dest_id, {})
	if dinfo.is_empty():
		return 1.0
	var hero: float = float(dinfo["data"].get("hero_r", 1.0))
	return clampf((dinfo["sphere"] as MeshInstance3D).scale.x
		/ maxf(hero, 0.001), 0.0, 1.0)

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
		var wp := OrbitMath.body_pos(b, _clock)
		bodies.append({
			"pos": CockpitHud.console_project(wp, bmin, bmax, panel),
			"color": b["color"],
			"name": b["name"],
			"hot": false,
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
		ship_w = _ship_rig.global_position
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

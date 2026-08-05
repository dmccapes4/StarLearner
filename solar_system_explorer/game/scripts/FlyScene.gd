class_name FlyScene
extends Control
## Beat C — 3D autopilot flight through the compressed solar system.
## SIM-FIRST: plot_route already ran the whole navigation simulation; this
## scene just PLAYS BACK the route's timeline (positions, headings, events)
## and never re-derives geometry live — what was charted is what flies.
##
## RENDERING — two nav modes (NavModes), same sim underneath:
##   MARKERS  — chunky pixel AR pins (constant screen size, strip-relative
##              tiers); mesh replaces the pin when hero apparent size reaches
##              the marker (fly-by / destination handoff).
##   SIM_VIEW — honest cockpit view: bearings from the sim, angular size and
##              brightness from decompressed REAL distances. Bodies are
##              brightness-scaled dots until their true angular size crosses
##              a pixel threshold, then discs subtending exactly that angle.
## Both end with a HARD-CUT to orbit; the standalone OrbitCinematic plays
## over the cut on every arrival.

## Preloaded so headless runs see fresh classes before the editor rescans
## the global class cache.
const NavModes := preload("res://scripts/NavModes.gd")
const OrbitCinematic := preload("res://scripts/OrbitCinematic.gd")

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
const APPROACH_S := 0.0            ## unused — approach is late sim playback
const ORBIT_ENTRY_BLEND_S := 0.0   ## unused — orbit is a hard cut
const ICON_TEX_PX := 64  ## matches PlanetSkins.MARKER_CANVAS_PX / gen_marker_icons.py
## Path fraction where the DESTINATION marker starts growing larger than
## every other marker (still a pin — mesh handoff uses apparent-size match).
## Also grows by proximity (dist/hero) so mid-cruise closing isn't stuck tiny.
const APPROACH_GROW_U := 0.55
const APPROACH_SCREEN_TIER := 5.2
## Dest pin starts swelling inside this hero-multiple (mesh handoff is wider).
const APPROACH_PROX_FAR_X := 14.0
const APPROACH_PROX_NEAR_X := 5.0
## Sim-view rendering: bodies sit on a fixed shell around the camera at
## their sim bearing; disc scale reproduces the true angular size exactly.
const SIM_SHELL_R := 400.0
const SIM_DISC_MIN_PX := 1.25   ## true angular radius (px) where dot → disc
const SIM_DEST_DISC_MIN_PX := 0.55  ## destination becomes a disc sooner (loom)
const SIM_DOT_PX := 2.6         ## screen size of a sub-threshold body dot
const SIM_MIN_ALPHA := 0.03     ## below this flux-alpha nothing is rendered
## Close flybys (Jupiter on Earth→Saturn) may loom, but never fill the glass.
const SIM_PEER_MAX_PX := 96.0
## Destination during cruise may grow, but must NOT fill the canopy — that reads
## as "we hit the planet" even when the charted park is still ~4×hero clear.
## Orbit cut may go full local (parking view). Presentation only; path is truth.
const SIM_DEST_CRUISE_MAX_PX := 56.0
## Local blend when dist/hero is small: destination park + real peer flybys.
## Far peers stay pure AU so they don't fake playground collisions.
const SIM_LOCAL_NEAR_X := 6.0   ## dist/hero fully in the local regime
const SIM_LOCAL_FAR_X := 36.0   ## dist/hero fully in the decompressed regime
## Peers start blending toward local size inside this hero-multiple.
const SIM_PEER_LOCAL_X := 10.0

## Burn-phase narration (baked VO; see dump_vo_lines.gd). The lines describe
## the ship, not passing geometry, so they can never go stale mid-flight.
## The ship never visibly flips — the camera faces the direction of travel
## the whole way; the brake line only talks about slowing down.
const LINE_LAUNCH := "Engines on — hold tight, we're speeding up!"
const LINE_CRUISE := "Cruising speed!"
const LINE_BRAKE := "Getting close — time to start slowing down!"
const LINE_COAST_BOOST := "We're coasting for real months now. Tap the glowing BOOST button if you want to skip ahead on the calendar!"
const LINE_COAST_SKIP := "Calendar skip — jumping ahead through the coast!"
## Astrogator coast wipe (only after kid taps BOOST): compress real months
## into a few wall seconds while burn/brake stay cinematic.
const ASTRO_COAST_WALL_S := 2.8
const BOOST_GOLD_S := 5.0

## Which nav rendering runs (NavModes.MODE_MARKERS / MODE_SIM_VIEW) — set by
## Main before begin_flight. Playground is its own scene, never this one.
var render_mode: int = NavModes.MODE_MARKERS
## Arrival cinematic overlay (standalone scene). Harnesses may disable it.
var cinematic_enabled: bool = true

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
var _origin_id: String = ""
var _route: Dictionary = {}
## Charted mid-cruise pass-bys from plot_route (id, path_u, name, …).
var _encounters: Array = []
## Encounter ids that already fired a "Passing X!" callout this hop.
var _encounter_announced: Dictionary = {}
var _tl_pos: PackedVector3Array = PackedVector3Array()
var _tl_fwd: PackedVector3Array = PackedVector3Array()
var _tl_path_u: PackedFloat32Array = PackedFloat32Array() ## cumulative path 0..1
var _tl_dt: float = OrbitMath.SIM_DT
var _tl_events: Array = []
var _tl_entry: Dictionary = {}     ## arrival ang/fwd/dir for the orbit cut
var _ev_idx: int = 0             ## next timeline event to fire
var _t0: float = 0.0
var _flying: bool = false
var _orbiting: bool = false
var _flight_t: float = 0.0       ## sim seconds into the hop (timeline clock)
var _play_u: float = 0.0         ## presentation path progress 0..1 (even cruise)
var _duration: float = 20.0
var _path_len: float = 1.0
var _clock: float = 0.0
var _progress_u: float = 0.0     ## path fraction 0..1 (== _play_u in flight)
var _burn_phase: int = OrbitMath.PHASE_BURN
var _orbit_ang: float = 0.0
var _orbit_dir: float = 1.0        ## ±1, chosen to match arrival velocity
var _orbit_blend: float = 0.0      ## 1 once parked (hard-cut orbit)
var _orbit_rest: float = 1.0       ## orbital clock scale, ramps to orbit_time_scale
var _orbit_park: float = 1.0       ## parking radius for the orbit cut
var _belt_mm: MultiMeshInstance3D
var _belt_ring_r: float = 0.0
var _hud: CockpitHud
var _highlight_id: String = ""
var _console_extent: float = 60.0   ## half-span (world units) of the course chart
var _cine: OrbitCinematic
## Astrogator (Phase B) — optional realism pacing from PlotBoard route stamp.
var _pace_mode: String = AstrogatorPanel.PACE_KID
var _propulsion_id: String = AstrogatorPanel.PROP_CHEMICAL
var _realism: Dictionary = {}
var _astro_coast: bool = false          ## Rocket Science trip (skip available)
var _coast_skip_active: bool = false    ## Kid opted in via BOOST
var _coast_path_u0: float = 0.0
var _coast_path_u1: float = 1.0
var _coast_days_total: float = 0.0
var _astro_launch_said: bool = false

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
	_cine = OrbitCinematic.new()
	add_child(_cine)
	_cine.finished.connect(_on_cinematic_finished)
	visible = false

func set_active(on: bool) -> void:
	if not on:
		_flying = false
		_orbiting = false
		visible = false
		_hud.visible = false
		_hud.hide_arrival_choices()
		_hud.clear_callout()
		_hud.hide_calendar()
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
	_origin_id = str(route.get("origin_id", ""))
	_route = route
	_encounters = route.get("encounters", [])
	_encounter_announced.clear()
	_t0 = t0
	_clock = t0
	_flight_t = 0.0
	_play_u = 0.0
	_progress_u = 0.0
	_orbit_ang = 0.0
	_highlight_id = ""
	_duration = maxf(float(route.get("duration", 20.0)), 0.001)
	_path_len = maxf(float(route.get("path_len", 1.0)), 0.001)
	_burn_phase = OrbitMath.route_phase(0.0, route, _cfg)
	_pace_mode = str(route.get("pace_mode", AstrogatorPanel.PACE_KID))
	_propulsion_id = str(route.get("propulsion_id", AstrogatorPanel.PROP_CHEMICAL))
	_realism = route.get("realism", {})
	_astro_coast = (_pace_mode == AstrogatorPanel.PACE_ASTROGATOR) \
		and bool(_realism.get("ok", false))
	_coast_skip_active = false
	_coast_days_total = float(_realism.get("coast_days", 0.0))
	_astro_launch_said = false
	# The navigation simulation already ran at plot time — load its timeline.
	var tl: Dictionary = route.get("timeline", {})
	_tl_pos = tl.get("pos", PackedVector3Array())
	_tl_fwd = tl.get("fwd", PackedVector3Array())
	_tl_dt = maxf(float(tl.get("dt", OrbitMath.SIM_DT)), 0.001)
	_tl_events = tl.get("events", [])
	_tl_entry = tl.get("entry", {})
	_ev_idx = 0
	_build_tl_path_u()
	_resolve_coast_path_bounds()
	if render_mode == NavModes.MODE_SIM_VIEW:
		# Honest view: the real belt is invisibly sparse — no cinematic rocks.
		if _belt_mm != null:
			_belt_mm.visible = false
			_belt_mm.multimesh.instance_count = 0
	else:
		_spawn_belt_encounter()
	_console_extent = _course_extent(route)
	_flying = true
	_orbiting = false
	_orbit_blend = 0.0
	visible = true
	_hud.visible = true
	_hud.hide_arrival_choices()
	_hud.clear_callout()
	_hud.hide_calendar()
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	# Camera rides the ship rig; the rig plays back the sim timeline.
	if _cam.get_parent() != _ship_rig:
		_cam.reparent(_ship_rig, false)
		_cam.position = Vector3.ZERO
		_cam.rotation = Vector3.ZERO
	_cam.current = true
	_cine.stop()
	_sun_light.position = Vector3.ZERO
	_place_ship_at_path(0.0)

	_place_bodies_at(_clock)
	_render_bodies()
	var dest := SolarData.flyer_body_by_id(dest_id, _cfg)
	_hud.set_destination(dest)
	_hud.update_flight(0.0, 0.0)
	_hud.set_burn_phase(_burn_phase)
	_update_console()
	_hud.clear_boost_gold()
	Narrator.speak(LINE_LAUNCH)
	_astro_launch_said = true
	# The t=0 phase event is spoken above — skip past it.
	while _ev_idx < _tl_events.size() and float(_tl_events[_ev_idx]["t"]) <= 0.0:
		_ev_idx += 1

## Path-u bounds of the coast segment (from timeline phase events).
func _resolve_coast_path_bounds() -> void:
	_coast_path_u0 = 0.25
	_coast_path_u1 = 0.75
	var t_coast := -1.0
	var t_brake := -1.0
	for ev in _tl_events:
		if str(ev.get("kind", "")) != "phase":
			continue
		var ph: int = int(ev.get("phase", -1))
		var t: float = float(ev.get("t", 0.0))
		if ph == OrbitMath.PHASE_COAST and t_coast < 0.0:
			t_coast = t
		elif ph == OrbitMath.PHASE_BRAKE and t_brake < 0.0:
			t_brake = t
	if t_coast >= 0.0:
		_coast_path_u0 = _path_u_at_sim_t(t_coast)
	if t_brake >= 0.0:
		_coast_path_u1 = _path_u_at_sim_t(t_brake)
	if _coast_path_u1 <= _coast_path_u0 + 0.02:
		_coast_path_u1 = minf(_coast_path_u0 + 0.35, 0.95)

func _path_u_at_sim_t(t: float) -> float:
	if _tl_path_u.is_empty():
		return clampf(t / maxf(_duration, 0.001), 0.0, 1.0)
	var idx: int = clampi(int(round(t / _tl_dt)), 0, _tl_path_u.size() - 1)
	return _tl_path_u[idx]

func is_astrogator_coast_active() -> bool:
	return _astro_coast and _coast_skip_active and _flying \
		and _burn_phase == OrbitMath.PHASE_COAST

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

	# Path-uniform playback of the sim (no live re-derivation). Pacing is
	# wall-time bounded (OrbitMath.flight_play_rate) so Uranus never drags.
	# Rocket Science: coast calendar skip only after the kid taps BOOST.
	var rate: float = OrbitMath.flight_play_rate(_play_u, _duration)
	if is_astrogator_coast_active():
		var span: float = maxf(_coast_path_u1 - _coast_path_u0, 0.05)
		rate = maxf(rate, span * _duration / ASTRO_COAST_WALL_S)
	_play_u = minf(1.0, _play_u + delta * rate / _duration)
	_progress_u = _play_u
	_place_ship_at_path(_play_u)
	_fire_timeline_events()
	_fire_encounter_callouts()
	_place_bodies_at(_clock)
	_render_bodies()
	_update_hud()
	_update_console()
	_update_astro_calendar()
	_spin_bodies(delta)

	# Path complete → hard cut to looming orbit (not a course continuation).
	if _play_u >= 1.0:
		_enter_orbit_from_timeline()

## Route to the active nav rendering (markers vs honest sim view).
func _render_bodies() -> void:
	# SIM_VIEW for flight AND orbit park — destination looms by true angle;
	# peers stay AU-honest (no playground hero spheres mid-cruise).
	if render_mode == NavModes.MODE_SIM_VIEW and (_flying or _orbiting):
		_update_sim_view()
	else:
		_update_markers()

## Cumulative path fraction along the timeline (for path-uniform playback).
func _build_tl_path_u() -> void:
	_tl_path_u = PackedFloat32Array()
	if _tl_pos.size() < 2:
		return
	var cum := PackedFloat32Array()
	cum.append(0.0)
	var total := 0.0
	for i in range(1, _tl_pos.size()):
		total += _tl_pos[i - 1].distance_to(_tl_pos[i])
		cum.append(total)
	var inv: float = 1.0 / maxf(total, 0.001)
	for i in cum.size():
		_tl_path_u.append(cum[i] * inv)
	_tl_path_u[_tl_path_u.size() - 1] = 1.0

## Pose the ship at a PATH fraction 0..1 (presentation). Syncs the sim clock
## to the timeline frame at that path so planets match the chart. Camera
## always faces the direction of travel — the ship never flips.
func _place_ship_at_path(path_u: float) -> void:
	if _tl_pos.size() < 2 or _tl_path_u.size() != _tl_pos.size():
		return
	var target: float = clampf(path_u, 0.0, 1.0)
	var i := 0
	while i < _tl_path_u.size() - 2 and _tl_path_u[i + 1] < target:
		i += 1
	var u0: float = _tl_path_u[i]
	var u1: float = _tl_path_u[i + 1]
	var frac: float = 0.0 if u1 <= u0 + 0.000001 \
		else clampf((target - u0) / (u1 - u0), 0.0, 1.0)
	var p: Vector3 = _tl_pos[i].lerp(_tl_pos[i + 1], frac)
	var f: Vector3 = _tl_fwd[i].lerp(_tl_fwd[i + 1], frac)
	# Cockpit always faces the direction of travel — never aim at the destination.
	if f.length() > 0.001:
		var fwd: Vector3 = f.normalized()
		_ship_rig.global_transform = Transform3D(
			Basis.looking_at(fwd, Vector3.UP), p)
	else:
		_ship_rig.global_position = p
	# Gentle roll with course curvature — cosmetic only; no pitch/yaw toward target.
	_cam.rotation = Vector3(0.0, 0.0, deg_to_rad(sin(target * PI) * 3.0))
	# Sim clock at this path position (planets where the chart said).
	_flight_t = (float(i) + frac) * _tl_dt
	_flight_t = minf(_flight_t, _duration)
	_clock = _t0 + _flight_t

## Fire every pending sim event up to the playback clock (burn-phase beats).
## Charted pass-bys get a separate cockpit callout via _fire_encounter_callouts.
func _fire_timeline_events() -> void:
	while _ev_idx < _tl_events.size() \
			and float(_tl_events[_ev_idx]["t"]) <= _flight_t:
		var ev: Dictionary = _tl_events[_ev_idx]
		_ev_idx += 1
		if str(ev["kind"]) == "phase":
			_apply_phase_event(int(ev["phase"]))

## Encounters stamp burn-TIME fraction; playback `_play_u` is path-ARC fraction.
func _encounter_play_u(e: Dictionary) -> float:
	if _cfg == null:
		return float(e.get("path_u", -1.0))
	return OrbitMath.burn_progress(float(e.get("path_u", -1.0)), _path_len, _cfg)

## One-shot HUD line only when the charted pass-by is actually on the glass.
func _fire_encounter_callouts() -> void:
	if _orbiting or not _flying or _cam == null:
		return
	var cam_pos: Vector3 = _cam.global_position
	for e in _encounters:
		var id := str(e.get("id", ""))
		if id.is_empty() or _encounter_announced.has(id):
			continue
		var w: float = OrbitMath.encounter_spotlight(_play_u, _encounter_play_u(e))
		if w < 0.55:
			continue
		if not _body_nodes.has(id):
			continue
		var data: Dictionary = _body_nodes[id]["data"]
		var body_sim: Vector3 = OrbitMath.body_pos(data, _clock)
		var dir: Vector3 = body_sim - cam_pos
		if dir.length() < 0.01 or not _dir_in_canopy_fov(dir.normalized()):
			continue  # aft / off-glass — do not highlight
		_encounter_announced[id] = true
		_hud.show_callout("Passing %s!" % str(e.get("name", id)))

func _spot_weight(body_id: String) -> float:
	if _orbiting or not _flying or _encounters.is_empty() or _cfg == null:
		return 0.0
	var best: float = 0.0
	for e in _encounters:
		if str(e.get("id", "")) != body_id:
			continue
		best = maxf(best, OrbitMath.encounter_spotlight(_play_u, _encounter_play_u(e)))
	return best

## True when a world-space direction lands inside the canopy camera FOV.
func _dir_in_canopy_fov(dir: Vector3) -> bool:
	if _cam == null or dir.length() < 0.001:
		return false
	var fwd: Vector3 = -_cam.global_transform.basis.z
	var bearing: float = rad_to_deg(acos(clampf(fwd.dot(dir.normalized()), -1.0, 1.0)))
	var fov_h: float = _cam.fov
	var aspect: float = float(VIEWPORT_W()) / maxf(float(VIEWPORT_H()), 1.0)
	var half_h: float = deg_to_rad(fov_h) * 0.5
	var half_w: float = atan(tan(half_h) * aspect)
	# Tighter than the full frustum — cockpit oval hides the FOV rim.
	return bearing <= rad_to_deg(maxf(half_w, half_h)) * 0.82

func _apply_phase_event(phase: int) -> void:
	if phase == _burn_phase:
		return
	_burn_phase = phase
	_hud.set_burn_phase(phase)
	match phase:
		OrbitMath.PHASE_COAST:
			if _astro_coast:
				_coast_skip_active = false
				_hud.hide_calendar()
				_hud.pulse_boost_gold(BOOST_GOLD_S)
				Narrator.speak(LINE_COAST_BOOST)
			else:
				Narrator.speak(LINE_CRUISE)
		OrbitMath.PHASE_BRAKE:
			_coast_skip_active = false
			_hud.clear_boost_gold()
			_hud.hide_calendar()
			Narrator.speak(LINE_BRAKE)

func _update_astro_calendar() -> void:
	if not is_astrogator_coast_active():
		if not _coast_skip_active:
			_hud.hide_calendar()
		return
	if _burn_phase != OrbitMath.PHASE_COAST:
		if _burn_phase == OrbitMath.PHASE_BRAKE or _orbiting:
			_hud.hide_calendar()
		return
	var span: float = maxf(_coast_path_u1 - _coast_path_u0, 0.001)
	var frac: float = clampf((_play_u - _coast_path_u0) / span, 0.0, 1.0)
	var days: float = frac * maxf(_coast_days_total, 1.0)
	_hud.show_calendar(AstrogatorPanel.calendar_label(days, _coast_days_total))

func _spin_bodies(delta: float) -> void:
	for id in _body_nodes:
		var info: Dictionary = _body_nodes[id]
		var sph: Node3D = info["sphere"]
		if sph.visible:
			sph.rotate_y(float(info["data"].get("spin", 0.1)) * delta * 1.6)

## Hard cut to the orbit cinematic: planet mesh at full hero size, camera
## parked on a close orbit with the world looming. Not a continuation of
## the transfer arc — arrival ang/dir only pick a nice starting abeam view.
func _enter_orbit_from_timeline() -> void:
	if _orbiting:
		return
	_flying = false
	_orbiting = true
	_hud.hide_calendar()
	var dest := SolarData.flyer_body_by_id(_dest_id, _cfg)
	var hero: float = float(dest.get("hero_r", 2.0))
	_orbit_park = OrbitMath.sun_approach_standoff(_cfg) \
		if bool(dest.get("is_star", false)) else OrbitMath.orbit_standoff(hero)
	_sun_light.position = Vector3.ZERO   # sim view may have moved it
	if _tl_entry.is_empty():
		var center := OrbitMath.body_pos(dest, _clock)
		var rel := _ship_rig.global_position - center
		if rel.length() < 0.001:
			rel = Vector3.RIGHT
		_orbit_ang = atan2(rel.z, rel.x)
		_orbit_dir = 1.0
	else:
		_orbit_ang = float(_tl_entry["ang"])
		_orbit_dir = float(_tl_entry.get("dir", 1.0))
	# Prefer a sunlit abeam start so the cut lands on a lit face.
	_orbit_ang = _sunlit_orbit_ang(dest, _orbit_ang)
	_orbit_blend = 1.0
	_orbit_rest = 1.0
	_hud.clear_callout()
	if _cam.get_parent() != _orbit_rig:
		_cam.reparent(_orbit_rig, false)
		_cam.position = Vector3.ZERO
		_cam.rotation = Vector3.ZERO
	_place_parked_cam()
	_render_bodies()
	# The standalone arrival cinematic plays over the cut; narration and the
	# arrival UI wait for it (Main reacts to `arrived`). The cockpit HUD (a
	# higher CanvasLayer) hides for a full-bleed letterboxed picture.
	if cinematic_enabled and _cine != null:
		_hud.visible = false
		_cine.play(_dest_id)
	else:
		arrived.emit(_dest_id)

func _on_cinematic_finished() -> void:
	_hud.visible = true
	if _orbiting:
		arrived.emit(_dest_id)

func _enter_orbit() -> void:
	## Public/debug entry — jump playback to the end of the hop.
	_play_u = 1.0
	_progress_u = 1.0
	_flight_t = _duration
	_enter_orbit_from_timeline()

func _process_orbit(delta: float) -> void:
	# Free-run the parking lap. Orbital clock eases toward orbit_time_scale
	# so arrival narration plays over a calm sky.
	_orbit_rest = maxf(_cfg.orbit_time_scale,
		_orbit_rest - delta * (1.0 - _cfg.orbit_time_scale) / 2.0)
	_clock += delta * _orbit_rest
	_orbit_ang += delta * ORBIT_SPEED * _orbit_dir * _orbit_dwell_factor()
	_place_parked_cam()
	_place_bodies_at(_clock)
	_render_bodies()
	_update_console()
	_spin_bodies(delta)

## Bias the starting orbit angle toward the day side when possible.
func _sunlit_orbit_ang(dest: Dictionary, ang: float) -> float:
	if dest.is_empty() or bool(dest.get("is_star", false)):
		return ang
	var center := OrbitMath.body_pos(dest, _clock)
	if center.length() < 0.001:
		return ang
	var sun_dir := -center.normalized()
	var day_ang := atan2(sun_dir.z, sun_dir.x)
	# Park ~90° from the sun-planet line so the lit face fills the glass.
	return day_ang + PI * 0.5 * _orbit_dir

## Sunlit-side bias without a snap: hurry over night, linger over day.
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

## Orbit cut camera: travel-tangent with yaw so the planet looms abeam.
func _place_parked_cam() -> void:
	var dest := SolarData.flyer_body_by_id(_dest_id, _cfg)
	if dest.is_empty():
		return
	var center := OrbitMath.body_pos(dest, _clock)
	var hero: float = float(dest.get("hero_r", 2.0))
	var off := OrbitMath.orbit_offset(_orbit_ang, _orbit_park, 0.22)
	_orbit_rig.global_position = center + off
	_cam.position = Vector3.ZERO
	var tangent := OrbitMath.orbit_tangent(_orbit_ang, _orbit_dir)
	var to_planet := (center - _orbit_rig.global_position).normalized()
	var side: float = signf(tangent.cross(to_planet).y)
	if side == 0.0:
		side = 1.0
	var yaw_deg: float = lerpf(28.0, ORBIT_CAM_YAW_DEG, clampf(hero / 6.0, 0.0, 1.0))
	var fwd := tangent.rotated(Vector3.UP, side * deg_to_rad(yaw_deg))
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
	# Isolated world: without this every SubViewport shares the root World3D,
	# so the flight, playground and cinematic scenes all coexisted in ONE
	# 3D world and filmed each other's planets.
	_viewport.own_world_3d = true
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
		icon.shaded = false
		icon.double_sided = true
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

## Markers: chunky pixel AR pins, constant screen size + strip-relative tiers.
## Mesh replaces the pin when hero apparent size ≈ marker size (destination
## and peers alike). Orbit cut keeps dest at full hero mesh.
func _update_markers() -> void:
	var cam_pos: Vector3 = _cam.global_position
	var grow_u: float = 0.0
	if _flying and _play_u >= APPROACH_GROW_U:
		grow_u = smoothstep(0.0, 1.0,
			(_play_u - APPROACH_GROW_U) / maxf(1.0 - APPROACH_GROW_U, 0.001))
	for id in _body_nodes:
		var info: Dictionary = _body_nodes[id]
		var root: Node3D = info["root"]
		var icon: Sprite3D = info["icon"]
		var mesh: MeshInstance3D = info["sphere"]
		var hero: float = float(info["data"].get("hero_r", 1.0))
		var dist: float = maxf(cam_pos.distance_to(root.global_position), 0.001)
		var tier: float = float(info["tier"])
		var is_dest: bool = id == _dest_id
		# Hide worlds behind the camera — no ghost meshes after a pass slides aft.
		var to_cam: Vector3 = root.global_position - cam_pos
		var ahead: bool = true
		if to_cam.length() > 0.01 and _cam != null:
			ahead = (-_cam.global_transform.basis.z).dot(to_cam.normalized()) > 0.05
		if not ahead and not (_orbiting and is_dest):
			icon.visible = false
			mesh.visible = false
			continue
		var use_tier: float = tier
		if is_dest and not _orbiting and _flying:
			var prox_grow: float = 1.0 - smoothstep(
				APPROACH_PROX_NEAR_X, APPROACH_PROX_FAR_X, dist / maxf(hero, 0.001))
			use_tier = lerpf(tier, APPROACH_SCREEN_TIER, maxf(grow_u, prox_grow))
		var base: float = OrbitMath.marker_world_size(dist, use_tier, _cfg)
		icon.modulate = Color(1, 1, 1, 1)
		icon.pixel_size = base / float(ICON_TEX_PX)
		if _orbiting and is_dest:
			icon.visible = false
			mesh.visible = true
			mesh.scale = Vector3.ONE * hero
			continue
		# Sun stays a pin unless it is the destination (huge hero would dominate).
		# Origin never mesh-looms: park departure sits ~1×hero and would look
		# like a bounce off the launch world (meshes are not course truth).
		var is_origin: bool = (not _origin_id.is_empty()) and id == _origin_id
		var allow_mesh: bool = _flying and not is_origin and (
			is_dest or not bool(info["data"].get("is_star", false)))
		var flyby: float = 0.0
		if allow_mesh:
			flyby = OrbitMath.flyby_mesh_scale(
				dist, hero, base, use_tier, _cfg, is_dest)
			# During late approach, ease peer meshes out so dest wins the glass.
			if not is_dest and grow_u > 0.0:
				flyby *= 1.0 - smoothstep(0.3, 0.8, grow_u)
		if flyby > 0.05:
			icon.visible = false
			mesh.visible = true
			mesh.scale = Vector3.ONE * flyby
		else:
			icon.visible = true
			mesh.visible = false

## Honest cockpit rendering (SIM_VIEW): each body sits on a fixed shell at
## its sim bearing; its disc subtends the TRUE angle computed from real AU
## distances and real radii, its dot brightness follows real inverse-square
## flux. Bodies too faint to see are not rendered at all. The camera is the
## reference point — objects enter ITS field of view; nothing is faked.
##
## Peers NEVER use the hero-local blend (that reintroduced mini-playground
## Jupiter). Only the destination blends toward local scale near park so the
## world looms into orbit without a pin stuck until the hard cut.
func _update_sim_view() -> void:
	var cam_pos: Vector3 = _cam.global_position
	var ship_real: Vector3 = OrbitMath.real_pos_au(cam_pos, _cfg)
	var px_per_rad: float = float(_viewport.size.y) / deg_to_rad(_cam.fov)
	for id in _body_nodes:
		var info: Dictionary = _body_nodes[id]
		var root: Node3D = info["root"]
		var icon: Sprite3D = info["icon"]
		var mesh: MeshInstance3D = info["sphere"]
		var data: Dictionary = info["data"]
		var body_sim: Vector3 = OrbitMath.body_pos(data, _clock)
		var dir: Vector3 = body_sim - cam_pos
		if dir.length() < 0.01:
			icon.visible = false
			mesh.visible = false
			continue
		dir = dir.normalized()
		var is_star: bool = bool(data.get("is_star", false))
		var is_dest: bool = id == _dest_id
		# Peers outside the canopy oval stay hidden (mesh under the frame
		# confused QA with render_mesh=true on an empty glass).
		var on_glass: bool = is_dest or is_star or _dir_in_canopy_fov(dir)
		if not on_glass:
			icon.visible = false
			mesh.visible = false
			continue
		# Charted pass-by on the glass: keep a normal pin even if AU size is
		# sub-pixel. No size faking, no pull — out of FOV means no cue.
		var charted_on_glass: bool = (not is_dest and not is_star
			and _spot_weight(id) > 0.0)
		var body_real: Vector3 = OrbitMath.real_pos_au(body_sim, _cfg)
		var radius_km: float = float(data.get("real_radius_km", 1000.0))
		var hero: float = maxf(float(data.get("hero_r", 1.0)), 0.001)
		var dist_sim: float = cam_pos.distance_to(body_sim)
		var d_far_au: float = maxf(ship_real.distance_to(body_real), 1.0e-6)
		var d_ship_au: float = d_far_au
		var x_hero: float = dist_sim / hero
		# Destination always blends local near park. Peers blend only on real
		# close approaches during cruise (Jupiter ~1.5×hero) — never in orbit,
		# where a neighbor at ~orbit radius would fake a collision disc.
		var use_local: bool = is_dest or (
			not is_star and not _orbiting and x_hero < SIM_PEER_LOCAL_X)
		if use_local:
			var d_local_au: float = maxf(
				x_hero * radius_km / OrbitMath.KM_PER_AU, 1.0e-9)
			var local_w: float = 1.0
			if is_dest and _orbiting:
				local_w = 1.0
			elif is_dest:
				local_w = 1.0 - smoothstep(
					SIM_LOCAL_NEAR_X, SIM_LOCAL_FAR_X, x_hero)
			else:
				# Peer flyby: fully local inside ENCOUNTER band, fade out by 10×.
				local_w = 1.0 - smoothstep(
					OrbitMath.ENCOUNTER_HERO_X * 0.5, SIM_PEER_LOCAL_X, x_hero)
			d_ship_au = exp(lerpf(log(d_far_au), log(d_local_au), local_w))
		var theta: float = OrbitMath.apparent_radius_rad(radius_km, d_ship_au)
		var alpha: float = 1.0
		if not is_star:
			var d_sun_au: float = maxf(body_real.length(), 0.05)
			alpha = OrbitMath.brightness_alpha(
				OrbitMath.apparent_brightness(radius_km, d_sun_au, d_ship_au))
			# Close flybys must stay visible even if AU flux is tiny.
			if use_local and not is_dest:
				alpha = maxf(alpha, 0.55)
		root.position = cam_pos + dir * SIM_SHELL_R
		var radius_px: float = theta * px_per_rad
		if not is_dest and not is_star and radius_px > SIM_PEER_MAX_PX:
			radius_px = SIM_PEER_MAX_PX
			theta = radius_px / maxf(px_per_rad, 1.0)
		elif is_dest and not _orbiting and radius_px > SIM_DEST_CRUISE_MAX_PX:
			# Chart parks outside the planet — never paint a glass-filling hit.
			radius_px = SIM_DEST_CRUISE_MAX_PX
			theta = radius_px / maxf(px_per_rad, 1.0)
		var disc_min: float = SIM_DEST_DISC_MIN_PX if is_dest else SIM_DISC_MIN_PX
		# Tiny meshes read as empty sky — prefer a normal pin under ~5px.
		var prefer_pin: bool = (not is_dest) and radius_px < 5.0
		# Sub-pixel peers stay hidden unless a charted pass is on the glass
		# (then a normal pixel pin is enough — no fake loom).
		var dot_ok: bool = is_dest or is_star or charted_on_glass or radius_px >= 0.8
		if radius_px >= disc_min and not prefer_pin:
			icon.visible = false
			mesh.visible = true
			mesh.scale = Vector3.ONE * (SIM_SHELL_R * tan(theta))
		elif dot_ok and (is_dest or is_star or charted_on_glass or alpha >= SIM_MIN_ALPHA):
			icon.visible = true
			mesh.visible = false
			var a: float = 1.0 if is_star else maxf(
				alpha, 0.45 if (is_dest or charted_on_glass) else 0.12)
			icon.modulate = Color(1, 1, 1, a)
			icon.pixel_size = (SIM_DOT_PX * SIM_SHELL_R / px_per_rad) / float(ICON_TEX_PX)
		else:
			icon.visible = false
			mesh.visible = false
		if is_star:
			_sun_light.position = root.position

## Full FOV visibility snapshot for flight-video QA (sim truth vs render).
func debug_visibility_snapshot(path_u: float, movie_t: float) -> Dictionary:
	var cam_pos: Vector3 = _cam.global_position if _cam != null else Vector3.ZERO
	var fwd: Vector3 = -_cam.global_transform.basis.z if _cam != null else Vector3.FORWARD
	var fov_h: float = _cam.fov if _cam != null else 65.0
	var markers: bool = render_mode == NavModes.MODE_MARKERS
	var bodies: Array = []
	for id in _body_nodes:
		var info: Dictionary = _body_nodes[id]
		var data: Dictionary = info["data"]
		var body_sim: Vector3 = OrbitMath.body_pos(data, _clock)
		var rel: Vector3 = body_sim - cam_pos
		var dist: float = rel.length()
		var dir: Vector3 = rel.normalized() if dist > 0.001 else Vector3.FORWARD
		var bearing: float = rad_to_deg(acos(clampf(fwd.dot(dir), -1.0, 1.0)))
		var ang_px: float = debug_sim_angular_radius_px(id)
		var icon: Sprite3D = info["icon"]
		var mesh: MeshInstance3D = info["sphere"]
		# Match render: canopy oval, not the full camera frustum.
		var in_fov: bool = _dir_in_canopy_fov(dir)
		var is_dest: bool = id == _dest_id
		var spot: float = 0.0 if is_dest else _spot_weight(id)
		var charted_on_glass: bool = spot > 0.0 and in_fov
		var hero: float = maxf(float(data.get("hero_r", 1.0)), 0.001)
		var x_hero: float = dist / hero
		var expect_mesh := false
		var expect_vis := false
		if markers:
			# MARKERS: pins are intentional sky labels; "loom" = dest/peer mesh.
			# Origin never mesh-looms (park departure would look like a hit).
			var is_origin: bool = (not _origin_id.is_empty()) and id == _origin_id
			var max_x: float = OrbitMath.FLYBY_HANDOFF_MAX_X_DEST if is_dest \
				else OrbitMath.FLYBY_HANDOFF_MAX_X
			expect_mesh = in_fov and _flying and not is_origin and x_hero <= max_x and (
				is_dest or not bool(data.get("is_star", false)))
			if _orbiting and is_dest:
				expect_mesh = true
			# Don't QA-expect asteroid/sub-pixel pins — kids won't miss them.
			var is_asteroid: bool = bool(data.get("major_asteroid", false)) \
				or bool(data.get("belt", false))
			expect_vis = in_fov and (is_dest or is_asteroid == false) \
				and (is_dest or ang_px >= 0.5 or x_hero < 40.0)
			# Report pin-ish size unless mesh should loom.
			if expect_mesh:
				ang_px = maxf(ang_px, 8.0)
		else:
			expect_vis = in_fov and (ang_px >= 0.8 or is_dest or charted_on_glass)
			expect_mesh = expect_vis and ang_px >= (
				SIM_DEST_DISC_MIN_PX if is_dest else SIM_DISC_MIN_PX)
		bodies.append({
			"id": id,
			"name": str(data.get("name", id)),
			"is_dest": is_dest,
			"dist_sim": dist,
			"hero_r": hero,
			"dist_hero_x": x_hero,
			"bearing_from_fwd_deg": bearing,
			"ang_radius_px": ang_px,
			"in_fov": in_fov,
			"spotlight": spot,
			"charted_on_glass": charted_on_glass,
			"expect_visible": expect_vis,
			"expect_mesh": expect_mesh,
			"render_icon": icon != null and icon.visible,
			"render_mesh": mesh != null and mesh.visible,
			"mismatch": false,
		})
	# Flag sim-vs-render mismatches for the reviewer.
	for b in bodies:
		var got_mesh: bool = bool(b["render_mesh"])
		var got_any: bool = bool(b["render_icon"]) or got_mesh
		if markers:
			# Only flag missing dest/peer loom, not "extra" AR pins.
			b["mismatch"] = bool(b["expect_mesh"]) and not got_mesh and bool(b["in_fov"])
		else:
			b["mismatch"] = bool(b["expect_visible"]) != got_any and bool(b["in_fov"])
	bodies.sort_custom(func(a, c): return float(a["bearing_from_fwd_deg"]) < float(c["bearing_from_fwd_deg"]))
	return {
		"movie_t": movie_t,
		"path_u": path_u,
		"clock": _clock,
		"flight_t": _flight_t,
		"burn_phase": _burn_phase,
		"render_mode": render_mode,
		"ship_pos": {"x": cam_pos.x, "y": cam_pos.y, "z": cam_pos.z},
		"fwd": {"x": fwd.x, "y": fwd.y, "z": fwd.z},
		"fov_deg": fov_h,
		"dest_id": _dest_id,
		"encounters": _encounters,
		"bodies": bodies,
	}

func VIEWPORT_W() -> int:
	return _viewport.size.x if _viewport != null else 1280

func VIEWPORT_H() -> int:
	return _viewport.size.y if _viewport != null else 600

## QA / probe: apparent angular radius in viewport pixels (SIM_VIEW math).
func debug_sim_angular_radius_px(body_id: String) -> float:
	if _cam == null or _cfg == null:
		return 0.0
	var data := SolarData.flyer_body_by_id(body_id, _cfg)
	if data.is_empty():
		return 0.0
	var cam_pos: Vector3 = _cam.global_position
	var ship_real: Vector3 = OrbitMath.real_pos_au(cam_pos, _cfg)
	var body_sim: Vector3 = OrbitMath.body_pos(data, _clock)
	var body_real: Vector3 = OrbitMath.real_pos_au(body_sim, _cfg)
	var radius_km: float = float(data.get("real_radius_km", 1000.0))
	var hero: float = maxf(float(data.get("hero_r", 1.0)), 0.001)
	var dist_sim: float = cam_pos.distance_to(body_sim)
	var d_far_au: float = maxf(ship_real.distance_to(body_real), 1.0e-6)
	var d_ship_au: float = d_far_au
	var is_dest: bool = body_id == _dest_id
	var x_hero: float = dist_sim / hero
	var use_local: bool = is_dest or (
		not bool(data.get("is_star", false))
		and not _orbiting
		and x_hero < SIM_PEER_LOCAL_X)
	if use_local:
		var d_local_au: float = maxf(
			x_hero * radius_km / OrbitMath.KM_PER_AU, 1.0e-9)
		var local_w: float = 1.0
		if is_dest and _orbiting:
			local_w = 1.0
		elif is_dest:
			local_w = 1.0 - smoothstep(SIM_LOCAL_NEAR_X, SIM_LOCAL_FAR_X, x_hero)
		else:
			local_w = 1.0 - smoothstep(
				OrbitMath.ENCOUNTER_HERO_X * 0.5, SIM_PEER_LOCAL_X, x_hero)
		d_ship_au = exp(lerpf(log(d_far_au), log(d_local_au), local_w))
	var theta: float = OrbitMath.apparent_radius_rad(radius_km, d_ship_au)
	var px_per_rad: float = float(_viewport.size.y) / deg_to_rad(_cam.fov)
	var radius_px: float = theta * px_per_rad
	if not is_dest and not bool(data.get("is_star", false)):
		radius_px = minf(radius_px, SIM_PEER_MAX_PX)
	elif is_dest and not _orbiting:
		radius_px = minf(radius_px, SIM_DEST_CRUISE_MAX_PX)
	return radius_px

func _update_hud() -> void:
	var dest := SolarData.flyer_body_by_id(_dest_id, _cfg)
	if dest.is_empty():
		_hud.update_flight(_progress_u, 0.0)
		return
	var aim := OrbitMath.body_pos(dest, _clock) - _cam.global_position
	var forward := -_cam.global_transform.basis.z
	var heading := CockpitHud.heading_angle(forward, aim)
	_hud.update_flight(_progress_u, heading)

## Half-span of the COURSE chart: at least the inner system (Mars orbit),
## grown to fit the flown curve + destination orbit for outer hops.
func _course_extent(route: Dictionary) -> float:
	var mars := SolarData.flyer_body_by_id("mars", _cfg)
	var extent: float = float(mars.get("orbit_r", 55.0)) * 1.05
	var dest := SolarData.flyer_body_by_id(_dest_id, _cfg)
	extent = maxf(extent, float(dest.get("orbit_r", 0.0)) * 1.06)
	if route.has("curve"):
		var curve: Curve3D = route["curve"]
		var len: float = maxf(curve.get_baked_length(), 0.001)
		for i in 33:
			var p: Vector3 = curve.sample_baked(float(i) / 32.0 * len)
			extent = maxf(extent, maxf(absf(p.x), absf(p.z)) * 1.06)
	return extent

## Project world XZ into COURSE panel pixels (Sun-centred, uniform scale).
func _console_px(world: Vector3) -> Vector2:
	var half: float = CockpitHud.CONSOLE_SIZE.x * 0.5
	var k: float = (half - CockpitHud.CONSOLE_PAD) / maxf(_console_extent, 0.001)
	return Vector2(half + world.x * k, half + world.z * k)

## Flat solar-system overview: faint orbit rings + belt band + planets as
## very small circles (sizes derived from the scroll strip's draw_radius,
## shrinking further on wide charts), the flown course, ship and target.
func _update_console() -> void:
	if _route.is_empty() or not _route.has("curve"):
		return
	var curve: Curve3D = _route["curve"]
	var half: float = CockpitHud.CONSOLE_SIZE.x * 0.5
	var k: float = (half - CockpitHud.CONSOLE_PAD) / maxf(_console_extent, 0.001)
	var mars := SolarData.flyer_body_by_id("mars", _cfg)
	var mars_extent: float = float(mars.get("orbit_r", 55.0)) * 1.05
	# Circles shrink as the chart widens (Uranus chart → smaller dots).
	var size_k: float = clampf(mars_extent / _console_extent, 0.5, 1.0)
	var rings := PackedFloat32Array()
	var bodies: Array = []
	var belt_band := Vector2.ZERO
	for b in SolarData.flyer_bodies(_cfg):
		var orbit_r: float = float(b.get("orbit_r", 0.0))
		if bool(b.get("belt", false)):
			if orbit_r * k < half:
				belt_band = Vector2(orbit_r * 0.88 * k, orbit_r * 1.12 * k)
			continue
		if bool(b.get("major_asteroid", false)):
			continue   # the belt band already tells that story at this scale
		if bool(b.get("is_star", false)):
			continue
		if orbit_r > _console_extent * 1.42:
			continue   # off-chart world: no ring, no dot
		rings.append(orbit_r * k)
		var wp := OrbitMath.body_pos(b, _clock)
		bodies.append({
			"pos": _console_px(wp),
			"color": b["color"],
			"r": maxf(1.0, float(b.get("draw_radius", 40.0)) * 0.042 * size_k),
			"hot": str(b["id"]) == _dest_id,
		})
	# Console course = the sim curve exactly (same path the ship flies).
	var pts := PackedVector2Array()
	var len: float = maxf(curve.get_baked_length(), 0.001)
	for i in 48:
		var u := float(i) / 47.0
		pts.append(_console_px(curve.sample_baked(u * len)))
	var ship_w: Vector3 = _orbit_rig.global_position if _orbiting \
		else _ship_rig.global_position
	# Dest pin sits on the sim endpoint (parking arrival), not the planet
	# center — so the line never looks like it jumps at the finish.
	_hud.set_console_map(
		_console_px(ship_w),
		_console_px(curve.sample_baked(len)),
		pts, bodies, rings, belt_band)

func _on_boost() -> void:
	if not _flying:
		return
	# Rocket Science coast: BOOST opts into calendar skip (not auto).
	if _astro_coast and _burn_phase == OrbitMath.PHASE_COAST and not _coast_skip_active:
		_coast_skip_active = true
		_hud.clear_boost_gold()
		Narrator.speak(LINE_COAST_SKIP)
		_update_astro_calendar()
		boost_pressed.emit()
		return
	# Otherwise BOOST nudges PATH progress (what the kid sees).
	_play_u = minf(1.0, _play_u + BOOST_NUDGE)
	_progress_u = _play_u
	_place_ship_at_path(_play_u)
	boost_pressed.emit()

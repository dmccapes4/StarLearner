class_name PlaygroundScene
extends Control
## Mode 3 — 3D FLIGHT PLAYGROUND. A fun mini solar system with relative-sized
## planets and simplified dynamics. The player IS the pilot (tap-only):
##   · tap a world (even while turning) → auto-fly there; empty cancels
##   · tap beside the cross → turn; farther from center = more turn (slow coast)
##   · Sun tile (bottom-left) → fly to the Sun; arrow points toward it
##   · tap joystick forward → speed up; back → slow down
##   · red octagon → stop; green circle → cruise
##   · fly into a world → orbit cinematic (collision capture)
## Motion (tilt/lift) code remains for QA helpers but is not used in flight.


const OrbitCinematic := preload("res://scripts/OrbitCinematic.gd")
const SpeedModeChooser := preload("res://scripts/SpeedModeChooser.gd")

signal arrived(dest_id: String)
signal go_home()
signal learn_more(dest_id: String)

const SPACING := 1.8           ## orbit_r multiplier — room for steer between worlds
## Decorative belt rocks (visual only — never registered in `_bodies`).
const BELT_DECOR_COUNT := 64
const BELT_DECOR_RADIAL := 0.10   ## ± fraction of belt ring radius
const BELT_DECOR_Y := 5.0
const SPEED := 26.0            ## cruise / step 4 / lift resume
const SPEED_MIN := 0.0
const TURN_RATE := 1.4         ## rad/s at full tilt (legacy motion)
const PITCH_RATE := 0.9
const SEEK_TURN := 2.2         ## auto-aim rate while seeking a tapped world
const SEEK_SPEED_MIN := SPEED * 0.75  ## never crawl while auto-flying
const Y_MAX := 220.0           ## soft ceiling — far above/below for sightseeing
const Y_SOFT := 70.0           ## gentle pitch bias toward level / plane starts here
const Y_CLEAR := 40.0          ## clear rare band VO once back inside
const BAND_COOLDOWN_S := 20.0  ## don't re-narrate the band every bounce
const PITCH_ATTITUDE_DECAY := 0.28  ## legacy tilt-band helper only (unused in tap flight)
const ORBIT_SPEED := 0.3
const TAP_RADIUS_PX := 72.0       ## center / intentional planet pick
const TAP_PLANET_TIGHT_PX := 34.0 ## outer taps: must hit this close to seek
const TAP_GUARD_S := 0.28      ## ignore mouse echo after a touch
const TIME_SCALE := 0.22       ## planets drift slowly — easy targets

## ── Tap flight (primary controls) ──────────────────────────────────
## One tap sets a coasting turn rate from how far the finger is from the
## cross (near = nudge, far = big swing). Slow decay — no mash required.
## Pitch/yaw hold after a coast — no idle auto-level.
const TAP_RATE_MIN := 0.24       ## rad/s just outside the home cross
const TAP_RATE_MAX := 0.92       ## rad/s at full reach (slightly less twitchy)
const TAP_RATE_DECAY := 0.32     ## rad/s² coast back to 0 (~3s from full)
const TAP_HOME_RADIUS_PX := 70.0 ## near cross: clear turn rates / level nose
const TAP_REACH_FRAC := 0.42     ## full turn = this × min(screen w,h)
const TAP_TURNING_EPS := 0.07    ## |rate| above this → still coasting a turn
const TAP_YAW_STEP := 0.55       ## keyboard / suite medium impulse (rad/s)
const TAP_PITCH_STEP := 0.50     ## keyboard / suite medium pitch impulse
const TAP_SPEED_CD_S := 0.12     ## short debounce — mash still reaches limit
const SPEED_CRUISE_DECAY_S := 2.2 ## after last stick tap, step toward cruise
const SPEED_VO_CD_S := 0.85      ## don't spam Speeding/Slowing while mashing
const LINE_WELCOME_TAP := "You're cleared! Tap a planet to visit — even while turning. Farther from the cross means a bigger turn. Sun tile flies you to the Sun."
const LINE_CRUISE_DECAY := "Back to cruising speed."

## ── Tilt steering (calibrated, angle-based) ────────────────────────
const CAL_TIME_S := 0.6
const TILT_FULL_RAD := 0.30
const TILT_DEAD_RAD := 0.035
const TILT_LP_TAU_S := 0.12

## ── Surge speed (lift/lower) — same idea as tilt, not a gesture FSM ──
## Accel residual along −ĝ vs rest. Cross FIRE once → ±1 gear (or
## cruise/stop); must return below DEAD before the next step.
## Gears polarity (matches preferred feel + joystick):
##   lift phone → slow down (stick forward); lower → speed up (stick aft).
const SURGE_DEAD := 0.32
const SURGE_FIRE := 0.62
const SURGE_ARM_DEFAULT := SURGE_FIRE   ## suite/telem alias
const SURGE_JERK_DEFAULT := SURGE_FIRE
const SURGE_JERK_CD_S := 2.0            ## cool-off after a gear change
const SURGE_LP_TAU_S := 0.05
const SURGE_PITCH_HOLD_S := 0.35
const SURGE_QUIET_S := 0.35
const SURGE_QUIET_EPS := 0.18
const SURGE_POST_NEUTRAL_S := 0.35
const SURGE_TIP_BLOCK := 0.40           ## |pitch| above this blocks soft surges
const SURGE_READY_GRACE_S := 0.45       ## no fire right after "Joystick ready"
const TUT_SURGE_MIN := 0.28
const TUT_SURGE_SETTLE_S := 0.12        ## short rest after VO before listening
## 0 = stop; 1..5 = five flying gears (3 = cruise / launch default)
const SPEED_STEP_STOP := 0
const SPEED_STEP_MIN := 1
const SPEED_STEP_CRUISE := 3
const SPEED_STEP_MAX := 5
const SPEED_BLEND_S := 1.2
## Multipliers vs SPEED for gears 1..5.
const SPEED_STEP_MULT: Array = [0.40, 0.65, 1.0, 1.35, 1.75]

## ── Surge displacement telemetry (diagnostic only, no gameplay effect) ──
const SURGE_ACCEL_QUIET := 0.40
const SURGE_DISP_BAND_MIN := 0.22
const SURGE_VEL_TAU_S := 0.45
const SURGE_VEL_QUIET := 0.25

## ── Every-launch tutorial + aim gate ───────────────────────────────
const TUT_ANGLE_RAD := 0.20
const TUT_HOLD_S := 0.3
const TUT_SETTLE_S := 0.5
const GATE_RADIUS_RAD := 0.26
const GATE_HOLD_S := 0.8
const NO_SENSOR_SKIP_FRAMES := 12

## ── Orbit capture (head-on only) ───────────────────────────────────
const CAPTURE_HERO_X := 1.6
const CAPTURE_AIM_DOT := 0.25
const CAPTURE_GRACE_S := 2.5

const TELEMETRY := true
const TEL_PERIOD_S := 0.25

const LINE_WELCOME := "You're cleared for takeoff — have fun out there!"
const LINE_BAND := "Let's stay where the planets are — gently turning back!"
const LINE_SEEK := "On our way to %s! Tap anywhere else to cancel."
const LINE_SEEK_CANCEL := "Okay — keep exploring!"
const LINE_TUT_RIGHT := "Let's learn to steer! Tilt the phone to the right, like turning a wheel."
const LINE_TUT_LEFT := "Great! Now tilt it to the left."
const LINE_TUT_UP := "Now point the phone up, to climb."
const LINE_TUT_DOWN := "And point it down, to dive."
const LINE_TUT_LIFT := "Lift to slow down."
const LINE_TUT_LOWER := "Lower to speed up."
const LINE_TUT_LIFT_CRUISE := "Lift to cruise."
const LINE_TUT_LOWER_CRUISE := "Lower to stop."
const LINE_AIM := "Now aim the phone straight ahead and hold it steady. Get ready to launch!"
const LINE_STOP := "Holding position."
const LINE_RESUME := "Cruising!"
const LINE_SPEEDING := "Speeding up."
const LINE_SLOWING := "Slowing down."
const LINE_JOY_READY := "Joystick ready."
const LINE_MIN := "You are at minimum velocity."
const LINE_CRUISE_SPEED := "You are at cruising speed."
const LINE_MAX := "You are at maximum velocity."
const LINE_ALREADY_MAX := "You are already at maximum velocity."
const LINE_ALREADY_STOP := "You are already stopped."

## Gears: five-speed jerks. Cruise: cruise/stop jerks.
const TUT_STEPS_GEARS: Array = [
	{"kind": "tilt", "axis": 0, "dir": 1.0, "learn": true, "arrow": "→",
		"hint": "Tilt RIGHT", "line": LINE_TUT_RIGHT},
	{"kind": "tilt", "axis": 0, "dir": -1.0, "learn": false, "arrow": "←",
		"hint": "Tilt LEFT", "line": LINE_TUT_LEFT},
	{"kind": "tilt", "axis": 1, "dir": 1.0, "learn": true, "arrow": "↑",
		"hint": "Point UP", "line": LINE_TUT_UP},
	{"kind": "tilt", "axis": 1, "dir": -1.0, "learn": false, "arrow": "↓",
		"hint": "Point DOWN", "line": LINE_TUT_DOWN},
	{"kind": "surge", "dir": -1.0, "motion": 1.0, "learn": true, "arrow": "▲",
		"hint": "LIFT — slower", "line": LINE_TUT_LIFT},
	{"kind": "surge", "dir": 1.0, "motion": -1.0, "learn": false, "arrow": "▼",
		"hint": "LOWER — faster", "line": LINE_TUT_LOWER},
]

const TUT_STEPS_CRUISE: Array = [
	{"kind": "tilt", "axis": 0, "dir": 1.0, "learn": true, "arrow": "→",
		"hint": "Tilt RIGHT", "line": LINE_TUT_RIGHT},
	{"kind": "tilt", "axis": 0, "dir": -1.0, "learn": false, "arrow": "←",
		"hint": "Tilt LEFT", "line": LINE_TUT_LEFT},
	{"kind": "tilt", "axis": 1, "dir": 1.0, "learn": true, "arrow": "↑",
		"hint": "Point UP", "line": LINE_TUT_UP},
	{"kind": "tilt", "axis": 1, "dir": -1.0, "learn": false, "arrow": "↓",
		"hint": "Point DOWN", "line": LINE_TUT_DOWN},
	{"kind": "surge", "dir": 1.0, "learn": true, "arrow": "▲",
		"hint": "LIFT — cruise", "line": LINE_TUT_LIFT_CRUISE},
	{"kind": "surge", "dir": -1.0, "learn": false, "arrow": "▼",
		"hint": "LOWER — stop", "line": LINE_TUT_LOWER_CRUISE},
]

enum State { SPEED_PICK, TUTORIAL, AIM_GATE, FLYING, SEEKING, ORBITING }

var _cfg: SolarFlyerConfig
var _viewport: SubViewport
var _host: SubViewportContainer
var _world: Node3D
var _cam: Camera3D
var _bodies: Dictionary = {}     ## id → {root, mesh, icon, data, hero}
var _belt_decor: MultiMeshInstance3D = null  ## rocks only; never tapped/captured
var _state: State = State.FLYING
var _ship_pos: Vector3 = Vector3.ZERO
var _yaw: float = 0.0
var _pitch: float = 0.0
var _speed: float = SPEED
var _speed_step: int = SPEED_STEP_CRUISE   ## 0 stop; 1..5 gears
var _speed_from: float = SPEED
var _speed_to: float = SPEED
var _speed_blend_t: float = 0.0
var _speed_blending: bool = false
var _start_at: String = "earth"
var _look_yaw: float = 0.0   ## level "forward" look reset between tutorial steps
var _clock: float = 0.0
var _band_warned: bool = false
var _band_cd: float = 0.0
var _tilt_neutral: Vector2 = Vector2.ZERO   ## (roll, pitch) angles at rest
var _cal_sum: Vector2 = Vector2.ZERO
var _cal_t: float = 0.0
var _calibrated: bool = false
var _g_filt: Vector3 = Vector3.ZERO         ## low-passed gravity estimate
var _sx: float = 1.0     ## roll sign (identity; tutorial may learn otherwise)
var _sy: float = 1.0     ## pitch sign
var _sz: float = -1.0    ## gears default: lift → negative surge → slow down
var _flip: float = 1.0   ## −1 when the sensor frame is 180° from the screen
var _speed_gears: bool = true  ## false = cruise/stop jerks only
var _tut_steps: Array = []
var _tut_i: int = 0
var _tut_ref: Vector2 = Vector2.ZERO
var _tut_ref_sum: Vector2 = Vector2.ZERO
var _tut_ref_t: float = 0.0
var _tut_hold: float = 0.0
var _gate_hold: float = 0.0
var _gate_sum: Vector2 = Vector2.ZERO
var _no_sensor_frames: int = 0
var _capture_grace: float = 0.0
var _last_tilt: Vector2 = Vector2.ZERO
var _raw_tilt_y: float = 0.0   ## pitch before surge suppress — prioritizes climb/dive
var _last_surge: float = 0.0   ## signed: gears + = speed up (lower), − = slow (lift)
var _surge_filt: float = 0.0   ## raw vertical (lift/lower) linear accel (pre-_sz)
var _surge_neutral: float = 0.0  ## rest baseline
var _surge_pitch_cd: float = 0.0
var _surge_need_recenter: bool = true
var _surge_quiet_t: float = 0.0
var _surge_prev_filt: float = 0.0
var _surge_post_neutral: float = 0.0
var _surge_await_rest: bool = false
var _surge_armed: bool = false          ## must return to rest before next fire
var _surge_ready_grace: float = 0.0     ## blocks fire after ready VO
## Displacement telemetry only (PGTEL).
var _surge_vel: float = 0.0
var _surge_disp: float = 0.0
var _surge_disp_band: float = SURGE_DISP_BAND_MIN
var _surge_disp_quiet_t: float = 0.0
var _surge_arm: float = SURGE_FIRE
var _surge_jerk: float = SURGE_FIRE
## surge tutorial: pose → go → accept (instant, like tilt)
var _tut_surge_phase: String = "pose"
var _tut_surge_phase_t: float = 0.0
var _jerk_cd: float = 0.0
var _joy_ready_announced: bool = false
var _tel_t: float = 0.0
var _orbit_id: String = ""
var _orbit_ang: float = 0.0
var _seek_id: String = ""
var _tap_guard_t: float = 0.0  ## ignore mouse echo after a touch
var _active: bool = false
var _cine: OrbitCinematic
var _sun_light: OmniLight3D
var _hint: Label
var _speed_bar: SpeedBar
var _gear_joy: GearJoystick
var _home_btn: Button
var _reticle: AimReticle
var _aim_mark: FlyAimMarker
var _stop_btn: StopCruiseButton
var _tut_arrow: Label
var _tut_phone: PhoneTiltHint
var _speed_pick: SpeedModeChooser
var _arrival_title: Label
var _arrival: Control
var _arrival_planet_pic: TextureRect
var _arrival_planet_lbl: Label
var _tap_yaw_rate: float = 0.0
var _tap_pitch_rate: float = 0.0
var _tap_speed_cd: float = 0.0
var _tap_x_sign: float = 1.0   ## screen-left → +yaw (turn left); set at launch
var _cruise_decay_t: float = -1.0  ## <0 inactive; else seconds to next cruise step
var _held_stopped: bool = false    ## STOP button or mashed to stop — no auto-cruise
var _speed_vo_cd: float = 0.0
var _sun_tile: SunCompassTile

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_cfg = SolarFlyerConfig.load_default()
	_build_viewport()
	_build_world()
	_build_ui()
	_cine = OrbitCinematic.new()
	add_child(_cine)
	_cine.finished.connect(_on_cinematic_done)
	visible = false

func begin(start_at: String = "earth") -> void:
	_cfg = SolarFlyerConfig.load_default()
	_active = true
	visible = true
	_start_at = start_at
	_clock = 0.0
	_band_warned = false
	_band_cd = 0.0
	_speed = SPEED
	_speed_step = SPEED_STEP_CRUISE
	_speed_from = SPEED
	_speed_to = SPEED
	_speed_blend_t = 0.0
	_speed_blending = false
	_jerk_cd = 0.0
	_surge_filt = 0.0
	_surge_neutral = 0.0
	_surge_pitch_cd = 0.0
	_surge_need_recenter = true
	_surge_quiet_t = 0.0
	_surge_prev_filt = 0.0
	_surge_post_neutral = 0.0
	_surge_await_rest = false
	_surge_armed = false
	_surge_ready_grace = 0.0
	_surge_arm = SURGE_FIRE
	_surge_jerk = SURGE_FIRE
	_tut_surge_phase = "pose"
	_tut_surge_phase_t = 0.0
	_speed_gears = true
	_sz = -1.0
	_joy_ready_announced = false
	_surge_vel = 0.0
	_surge_disp = 0.0
	_surge_disp_band = SURGE_DISP_BAND_MIN
	_surge_disp_quiet_t = 0.0
	_tut_steps = []
	_seek_id = ""
	_tap_guard_t = 0.0
	_tap_yaw_rate = 0.0
	_tap_pitch_rate = 0.0
	_tap_speed_cd = 0.0
	_cruise_decay_t = -1.0
	_held_stopped = false
	_speed_vo_cd = 0.0
	_arrival.visible = false
	if _gear_joy != null:
		_gear_joy.visible = false
		_gear_joy.set_ready()
	if _stop_btn != null:
		_stop_btn.visible = false
	if _aim_mark != null:
		_aim_mark.visible = false
	if _speed_pick != null:
		_speed_pick.visible = false
		_speed_pick.set_active(false)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_place_bodies()
	_spawn_start(start_at)
	_recalibrate()
	_apply_cam()
	_tel_event("begin at=%s pos=(%.1f,%.1f,%.1f) yaw=%.2f" % [
		start_at, _ship_pos.x, _ship_pos.y, _ship_pos.z, _yaw])
	_launch_tap()

func _enter_speed_pick() -> void:
	_state = State.SPEED_PICK
	_reticle.visible = false
	_tut_arrow.visible = false
	_tut_phone.visible = false
	_hint.text = "Choose how to control speed"
	if _speed_bar != null:
		_speed_bar.visible = false
	if _gear_joy != null:
		_gear_joy.visible = false
	_speed_pick.set_active(true)
	_tel_event("speed pick enter")

func _on_speed_gears() -> void:
	_speed_gears = true
	_sz = -1.0  ## lift → slow, lower → faster
	_speed_pick.set_active(false)
	_tel_event("speed mode=gears")
	_enter_tutorial()

func _on_speed_cruise_stop() -> void:
	_speed_gears = false
	_sz = 1.0  ## lift → cruise, lower → stop
	if _gear_joy != null:
		_gear_joy.visible = false
	_speed_pick.set_active(false)
	_tel_event("speed mode=cruise_stop")
	_enter_tutorial()

func set_active(on: bool) -> void:
	_active = on
	visible = on
	if not on:
		_cine.stop()
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		Narrator.stop()
		if _speed_pick != null:
			_speed_pick.set_active(false)
	else:
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

func resume_flying() -> void:
	## After a video or an orbit stay — back to tap flight.
	_arrival.visible = false
	_seek_id = ""
	if not _orbit_id.is_empty():
		# Leave orbit outward so we don't instantly re-capture.
		var b := SolarData.flyer_body_by_id(_orbit_id, _cfg)
		var center := _body_playground_pos(b, _clock)
		var out := (_ship_pos - center)
		if out.length() < 0.01:
			out = Vector3.RIGHT
		var hero: float = float(b.get("hero_r", 2.0))
		_ship_pos = center + out.normalized() \
			* OrbitMath.orbit_standoff(hero) * 2.2
		var away := out.normalized()
		# _heading() is (-sin yaw, ·, -cos yaw): solve so we fly AWAY.
		_yaw = atan2(-away.x, -away.z)
		_pitch = 0.0
		_orbit_id = ""
	_speed_step = SPEED_STEP_CRUISE
	_speed = SPEED
	_speed_blending = false
	_surge_need_recenter = true
	_launch_tap()
	_tel_event("resume pos=(%.1f,%.1f,%.1f)" % [
		_ship_pos.x, _ship_pos.y, _ship_pos.z])

func _process(delta: float) -> void:
	if not _active:
		return
	_tap_guard_t = maxf(0.0, _tap_guard_t - delta)
	match _state:
		State.SPEED_PICK:
			pass
		State.TUTORIAL:
			_tut_tick(delta)
		State.AIM_GATE:
			_gate_tick(delta)
		State.FLYING:
			_clock += delta * TIME_SCALE
			_capture_grace = maxf(0.0, _capture_grace - delta)
			_band_cd = maxf(0.0, _band_cd - delta)
			_tap_speed_cd = maxf(0.0, _tap_speed_cd - delta)
			_speed_vo_cd = maxf(0.0, _speed_vo_cd - delta)
			_tick_speed_blend(delta)
			_tick_cruise_decay(delta)
			_tap_steer_tick(delta)
			_fly(delta)
			_check_capture()
			_tick_tap_hud()
			_telemetry(delta)
		State.SEEKING:
			_clock += delta * TIME_SCALE
			_band_cd = maxf(0.0, _band_cd - delta)
			_tap_speed_cd = maxf(0.0, _tap_speed_cd - delta)
			_speed_vo_cd = maxf(0.0, _speed_vo_cd - delta)
			_tick_speed_blend(delta)
			_tick_cruise_decay(delta)
			_tick_tap_hud()
			_seek_tick(delta)
			_telemetry(delta)
		State.ORBITING:
			_clock += delta * TIME_SCALE * 0.4
			_orbit_ang += delta * ORBIT_SPEED
			_place_orbit_cam()
	_place_bodies()
	_update_markers()

## ── Tap flight: stacked turn rates that decay back to center ─────────
func _launch_tap() -> void:
	_speed_gears = true
	_sz = -1.0
	_calibrated = true
	_state = State.FLYING
	_capture_grace = CAPTURE_GRACE_S
	_apply_speed_step(SPEED_STEP_CRUISE, false)
	_tap_yaw_rate = 0.0
	_tap_pitch_rate = 0.0
	_tap_speed_cd = 0.0
	_cruise_decay_t = -1.0
	_held_stopped = false
	_speed_vo_cd = 0.0
	_refresh_tap_screen_signs()
	_band_warned = false
	_reticle.visible = false
	_tut_arrow.visible = false
	_tut_phone.visible = false
	if _speed_pick != null:
		_speed_pick.set_active(false)
	_reset_level_look()
	_show_tap_hud(true)
	_update_speed_hint()
	_tel_event("launch_tap cruise step=%d x_sign=%.0f" % [
		_speed_step, _tap_x_sign])
	Narrator.speak(LINE_WELCOME_TAP)

## Map screen left/right → ship yaw for this bootloaded landscape kiosk.
## Heading: increasing yaw faces −X (left when looking down −Z). Viewport x
## grows to the visual right, so tap-left should increase yaw. Reverse
## landscape is checked in case a future image flips the sensor frame.
func _refresh_tap_screen_signs() -> void:
	_tap_x_sign = 1.0
	var ori := DisplayServer.screen_get_orientation()
	# Godot viewport x is already visual; reverse landscape rarely needs flip.
	# If Ant Phone ever boots reverse and L/R feel wrong again, invert here.
	if ori == DisplayServer.SCREEN_REVERSE_LANDSCAPE \
			or ori == DisplayServer.SCREEN_SENSOR_LANDSCAPE:
		# SENSOR_LANDSCAPE may settle either way — keep visual mapping (+1)
		# and log so a field check can confirm.
		pass
	_tel_event("tap_signs ori=%d x_sign=%.0f" % [int(ori), _tap_x_sign])

func _show_tap_hud(on: bool) -> void:
	if _aim_mark != null:
		_aim_mark.visible = on
	if _gear_joy != null:
		_gear_joy.visible = on
		if on:
			_gear_joy.gear = _speed_step
			# Never call set_ready here — that was wiping throw_forward/aft art.
	if _speed_bar != null:
		_speed_bar.visible = on
		if on:
			_speed_bar.horizontal = true
			_speed_bar.step = _speed_step
			_speed_bar.speed = _speed
			_speed_bar.blending = _speed_blending
			_speed_bar.queue_redraw()
	if _stop_btn != null:
		_stop_btn.visible = on
		if on:
			_stop_btn.set_stopped(_speed_step <= SPEED_STEP_STOP)
	if _sun_tile != null:
		_sun_tile.visible = on
		if on:
			_update_sun_tile()

func _tick_tap_hud() -> void:
	if _gear_joy != null and _gear_joy.visible:
		_gear_joy.gear = _speed_step
	if _speed_bar != null and _speed_bar.visible:
		_speed_bar.step = _speed_step
		_speed_bar.speed = _speed
		_speed_bar.blending = _speed_blending
		_speed_bar.queue_redraw()
	if _stop_btn != null and _stop_btn.visible:
		_stop_btn.set_stopped(_speed_step <= SPEED_STEP_STOP)
	if _sun_tile != null and _sun_tile.visible:
		_update_sun_tile()

func _update_sun_tile() -> void:
	if _sun_tile == null:
		return
	# Relative bearing: 0 = sun dead ahead, + = sun to the right.
	var want: float = _yaw_facing_flat(_sun_world_pos() - _ship_pos)
	_sun_tile.bearing = wrapf(want - _yaw, -PI, PI)
	_sun_tile.queue_redraw()

func _tap_steer_tick(delta: float) -> void:
	# Desktop arrows: medium impulse (same as a mid-screen tap).
	if Input.is_action_just_pressed("ui_left"):
		_nudge_yaw(_tap_x_sign)
	if Input.is_action_just_pressed("ui_right"):
		_nudge_yaw(-_tap_x_sign)
	if Input.is_action_just_pressed("ui_up"):
		_nudge_pitch(1.0)
	if Input.is_action_just_pressed("ui_down"):
		_nudge_pitch(-1.0)
	# Apply turn rates first, then slow-coast decay.
	# Attitude holds: rate→0 stops turning, but pitch/yaw stay put until
	# the player taps near the cross (_straighten_attitude) or turns again.
	_last_tilt = Vector2(_tap_yaw_rate / TAP_RATE_MAX, _tap_pitch_rate / TAP_RATE_MAX)
	_yaw += _tap_yaw_rate * delta
	_pitch = clampf(_pitch + _tap_pitch_rate * delta, -0.85, 0.85)
	_tap_yaw_rate = move_toward(_tap_yaw_rate, 0.0, TAP_RATE_DECAY * delta)
	_tap_pitch_rate = move_toward(_tap_pitch_rate, 0.0, TAP_RATE_DECAY * delta)
	var ay: float = absf(_ship_pos.y)
	if ay > Y_MAX:
		_ship_pos.y = signf(_ship_pos.y) * Y_MAX
	if ay < Y_CLEAR:
		_band_warned = false
	elif ay > Y_MAX * 0.92 and not _band_warned and _band_cd <= 0.0:
		_band_warned = true
		_band_cd = BAND_COOLDOWN_S
		_tel_event("band ceiling y=%.1f" % _ship_pos.y)

func _is_turning() -> bool:
	return absf(_tap_yaw_rate) > TAP_TURNING_EPS \
		or absf(_tap_pitch_rate) > TAP_TURNING_EPS

func _sun_world_pos() -> Vector3:
	if _bodies.has("sun"):
		return (_bodies["sun"]["root"] as Node3D).global_position
	return Vector3.ZERO

func _yaw_facing_flat(dir: Vector3) -> float:
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length() < 0.01:
		return _yaw
	flat = flat.normalized()
	# _heading flat: (-sin yaw, 0, -cos yaw) == flat
	return atan2(-flat.x, -flat.z)

func _face_sun() -> void:
	_yaw = _yaw_facing_flat(_sun_world_pos() - _ship_pos)
	_pitch = 0.0

## Just outside / behind home world, a little above the ecliptic, facing the Sun.
func _spawn_start(start_at: String) -> void:
	var body := SolarData.flyer_body_by_id(start_at, _cfg)
	var p := _body_playground_pos(body, 0.0)
	var hero: float = float(body.get("hero_r", 2.0))
	var sun := _sun_world_pos()
	var radial := Vector3(p.x - sun.x, 0.0, p.z - sun.z)
	if radial.length() < 0.01:
		radial = Vector3(0.0, 0.0, 1.0)
	radial = radial.normalized()
	var standoff: float = OrbitMath.orbit_standoff(hero) * 3.2
	# Behind Earth (further from the Sun than home) + slightly above the plane.
	_ship_pos = p + radial * standoff
	_ship_pos.y = 14.0
	_face_sun()
	_look_yaw = _yaw

func _tap_reach_px() -> float:
	return maxf(minf(size.x, size.y) * TAP_REACH_FRAC, TAP_HOME_RADIUS_PX + 80.0)

func _tap_strength_from_dist(dist_px: float) -> float:
	## 0 at home edge → 1 at full reach. Smoothstep so far taps feel bigger.
	var u: float = clampf(
		(dist_px - TAP_HOME_RADIUS_PX) / (_tap_reach_px() - TAP_HOME_RADIUS_PX),
		0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)

func _rate_from_strength(strength: float) -> float:
	return lerpf(TAP_RATE_MIN, TAP_RATE_MAX, clampf(strength, 0.0, 1.0))

func _nudge_yaw(dir: float, strength: float = 0.55) -> void:
	## dir > 0 = turn left (visual left of cross, after _tap_x_sign).
	## Replaces rate (no mash-stack) — farther taps pass higher strength.
	var rate: float = signf(dir) * _rate_from_strength(strength)
	_tap_yaw_rate = rate
	_tap_pitch_rate = 0.0
	_tel_event("tap yaw dir=%.0f str=%.2f rate=%.2f" % [dir, strength, rate])

func _nudge_pitch(dir: float, strength: float = 0.55) -> void:
	## dir > 0 = climb (tap above cross).
	var rate: float = signf(dir) * _rate_from_strength(strength)
	_tap_pitch_rate = rate
	_tap_yaw_rate = 0.0
	_tel_event("tap pitch dir=%.0f str=%.2f rate=%.2f" % [dir, strength, rate])

func _straighten_attitude() -> void:
	## Clear coasting turn and level the nose — does not move the ship.
	_tap_yaw_rate = 0.0
	_tap_pitch_rate = 0.0
	_pitch = 0.0
	_tel_event("tap straighten attitude")

func _on_empty_flight_tap(local: Vector2) -> void:
	var c := size * 0.5
	var d: Vector2 = local - c
	var dist: float = d.length()
	if dist <= TAP_HOME_RADIUS_PX:
		_straighten_attitude()
		return
	var strength: float = _tap_strength_from_dist(dist)
	if absf(d.x) >= absf(d.y):
		# Visual left (d.x < 0) → turn left via _tap_x_sign.
		var side: float = -signf(d.x)  ## left → +1, right → −1
		_nudge_yaw(side * _tap_x_sign, strength)
	else:
		_nudge_pitch(1.0 if d.y < 0.0 else -1.0, strength)

func _on_sun_tile_pressed() -> void:
	if _state != State.FLYING and _state != State.SEEKING:
		return
	if _bodies.has("sun"):
		_begin_seek("sun")
	else:
		_face_sun()
		_straighten_attitude()
		_tel_event("sun tile face (no body)")

func _tap_speed_delta(delta_step: int) -> void:
	## Mash-friendly: short CD only (blend does not block). Forward → max,
	## aft → stop; then cruise-decay unless held stopped.
	if _tap_speed_cd > 0.0:
		return
	if delta_step > 0:
		_held_stopped = false
		if _speed_step >= SPEED_STEP_MAX:
			if _speed_vo_cd <= 0.0:
				Narrator.speak(LINE_ALREADY_MAX)
				_speed_vo_cd = SPEED_VO_CD_S
			return
		if _gear_joy != null:
			_gear_joy.throw_forward()
		var prev_up: int = _speed_step
		_apply_speed_step(_speed_step + 1, true)
		_maybe_narrate_speed(prev_up, _speed_step)
		_cruise_decay_t = SPEED_CRUISE_DECAY_S
		_tel_event("tap gear %d→%d faster" % [prev_up, _speed_step])
	else:
		if _speed_step <= SPEED_STEP_STOP:
			_held_stopped = true
			_cruise_decay_t = -1.0
			if _speed_vo_cd <= 0.0:
				Narrator.speak(LINE_ALREADY_STOP)
				_speed_vo_cd = SPEED_VO_CD_S
			return
		if _gear_joy != null:
			_gear_joy.throw_aft()
		var prev_dn: int = _speed_step
		_apply_speed_step(_speed_step - 1, true)
		_maybe_narrate_speed(prev_dn, _speed_step)
		if _speed_step <= SPEED_STEP_STOP:
			_held_stopped = true
			_cruise_decay_t = -1.0
		else:
			_held_stopped = false
			_cruise_decay_t = SPEED_CRUISE_DECAY_S
		_tel_event("tap gear %d→%d slower" % [prev_dn, _speed_step])
	_tap_speed_cd = TAP_SPEED_CD_S
	_update_speed_hint()

func _maybe_narrate_speed(prev: int, step: int) -> void:
	if _speed_vo_cd > 0.0:
		return
	_narrate_speed_change(prev, step)
	_speed_vo_cd = SPEED_VO_CD_S

func _tick_cruise_decay(delta: float) -> void:
	if _held_stopped or _cruise_decay_t < 0.0:
		return
	if _speed_step == SPEED_STEP_CRUISE:
		_cruise_decay_t = -1.0
		return
	if _speed_blending:
		return
	_cruise_decay_t -= delta
	if _cruise_decay_t > 0.0:
		return
	var prev: int = _speed_step
	if _speed_step > SPEED_STEP_CRUISE:
		_apply_speed_step(_speed_step - 1, true)
	elif _speed_step < SPEED_STEP_CRUISE:
		_apply_speed_step(_speed_step + 1, true)
	_tel_event("cruise_decay %d→%d" % [prev, _speed_step])
	if _speed_step == SPEED_STEP_CRUISE:
		_cruise_decay_t = -1.0
		Narrator.speak(LINE_CRUISE_DECAY)
	else:
		_cruise_decay_t = SPEED_CRUISE_DECAY_S
	_update_speed_hint()

func _on_stop_cruise_pressed() -> void:
	if _state != State.FLYING and _state != State.SEEKING:
		return
	if _tap_speed_cd > 0.0:
		return
	_tap_guard_t = TAP_GUARD_S
	_tap_speed_cd = TAP_SPEED_CD_S
	if _speed_step <= SPEED_STEP_STOP and _state != State.SEEKING:
		_held_stopped = false
		_apply_speed_step(SPEED_STEP_CRUISE, false)
		_cruise_decay_t = -1.0
		Narrator.speak(LINE_RESUME)
		_tel_event("tap cruise")
	else:
		# STOP while seeking: cancel autopilot AND hold position.
		if _state == State.SEEKING:
			_tel_event("seek cancel via stop id=%s" % _seek_id)
			_seek_id = ""
			_state = State.FLYING
		_held_stopped = true
		_cruise_decay_t = -1.0
		_apply_speed_step(SPEED_STEP_STOP, false)
		_tap_yaw_rate = 0.0
		_tap_pitch_rate = 0.0
		Narrator.speak(LINE_STOP)
		_tel_event("tap stop")
	_update_speed_hint()

func _on_joy_gui_input(event: InputEvent) -> void:
	if _state != State.FLYING and _state != State.SEEKING:
		return
	var tap := false
	var pos := Vector2.ZERO
	if event is InputEventScreenTouch and event.pressed:
		tap = true
		pos = event.position
		_tap_guard_t = TAP_GUARD_S
	elif event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _tap_guard_t > 0.0:
			return
		tap = true
		pos = event.position
	if not tap:
		return
	accept_event()
	# Upper half of stick = forward = faster; lower = aft = slower.
	if pos.y < _gear_joy.size.y * 0.5:
		_tap_speed_delta(1)
	else:
		_tap_speed_delta(-1)

## Tilt steering: gravity vector when the device reports one, arrow keys as
## the desktop fallback. Landscape phone: roll (x) yaws, pitch (y) climbs.
## All tilts are DELTAS from the calibrated neutral pose.
## Lifting/lowering for speed rocks the gravity estimate — ignore pitch (and
## mute the planetary-plane VO) while a clear lift/lower is active.
## (Unused in tap-only flight; kept for suite/helpers.)
func _steer(delta: float) -> void:
	var g := _gravity_filtered(delta)
	var tilt_x := 0.0
	var tilt_y := 0.0
	if g.length() > 0.5:
		var ang := _tilt_angles(_frame_adjust(g))
		if not _calibrated:
			# Neutral = the average pose over the first CAL_TIME_S of flight.
			_cal_sum += ang * delta
			_cal_t += delta
			if _cal_t >= CAL_TIME_S:
				_tilt_neutral = _cal_sum / _cal_t
				_calibrated = true
				_tel_event("calibrated neutral_ang=(%.3f,%.3f)" % [
					_tilt_neutral.x, _tilt_neutral.y])
		else:
			tilt_x = _tilt_axis(_sx * (ang.x - _tilt_neutral.x))
			tilt_y = _tilt_axis(_sy * (ang.y - _tilt_neutral.y))
	tilt_x += Input.get_axis("ui_left", "ui_right") * 0.7
	tilt_y += Input.get_axis("ui_down", "ui_up") * 0.6
	_raw_tilt_y = tilt_y
	# Tip vs lift: different sensors (gravity angle vs linear residual).
	# Only mute climb/dive for a short hold after a real surge fire — NEVER
	# for the whole 2s gear CD (that was freezing aim up/down after every gear).
	var pitching: bool = absf(_raw_tilt_y) > 0.28
	var surge_motion: bool = absf(_last_surge) >= SURGE_FIRE and not pitching
	if surge_motion:
		_surge_pitch_cd = SURGE_PITCH_HOLD_S
	var surge_busy: bool = (
		surge_motion
		or (_surge_pitch_cd > 0.0 and not pitching))
	if surge_busy:
		tilt_y = 0.0
	_last_tilt = Vector2(tilt_x, tilt_y)
	_yaw -= tilt_x * TURN_RATE * delta

	# Planetary-plane band: past the soft edge, ignore pitch that digs
	# further out (yaw always free), ease pitch back toward the plane, and
	# narrate at most once per BAND_COOLDOWN_S so edge-bouncing doesn't spam.
	var ay: float = absf(_ship_pos.y)
	if ay > Y_SOFT:
		var out_s: float = signf(_ship_pos.y)
		if tilt_y * out_s > 0.0:
			tilt_y = 0.0   # can't dig deeper; toward-plane pitch still works
		_pitch = clampf(_pitch + tilt_y * PITCH_RATE * delta, -0.7, 0.7)
		var back: float = -out_s * 0.35
		var u: float = clampf((ay - Y_SOFT) / (Y_MAX - Y_SOFT), 0.0, 1.0)
		_pitch = lerpf(_pitch, back, u * 2.2 * delta)
		if ay >= Y_MAX - 0.5:
			# Hard wall: level off so left/right steering feels alive again.
			_pitch = lerpf(_pitch, back, 4.0 * delta)
		if not _band_warned and _band_cd <= 0.0:
			if surge_busy:
				# Speed shove rocked us off-plane — quiet auto-correct only.
				_tel_event("band suppress y=%.1f surge=%.2f" % [
					_ship_pos.y, _last_surge])
			else:
				_band_warned = true
				_band_cd = BAND_COOLDOWN_S
				_tel_event("band y=%.1f" % _ship_pos.y)
				Narrator.speak(LINE_BAND)
	else:
		_pitch = clampf(_pitch + tilt_y * PITCH_RATE * delta, -0.7, 0.7)
		if ay < Y_CLEAR:
			_band_warned = false

## Vertical lift/lower accel, projected onto the (low-passed) up axis so a
## landscape phone reads correctly however it's rotated in the player's
## hand — raw lin.y would break on a sideways device. Filtered signal is
## kept raw; signed delta vs neutral drives speed (lift = + after _sz).
func _surge_sample(delta: float) -> float:
	var raw := Input.get_accelerometer()
	if raw.length() < 0.5:
		# Desktop: Up = lift (+), Down = lower (−).
		var key := 0.0
		if Input.is_key_pressed(KEY_SHIFT):
			key = Input.get_axis("ui_down", "ui_up") * 6.0
		_surge_filt = key
		_last_surge = _sz * (_surge_filt - _surge_neutral)
		_surge_update_disp(delta)
		return _last_surge
	_gravity_filtered(delta)
	var lin: Vector3 = raw - _g_filt
	var up := -_g_filt.normalized()
	var vert: float = lin.dot(up)  # lift +, lower −
	var alpha: float = 1.0 - exp(-delta / SURGE_LP_TAU_S)
	_surge_filt = lerpf(_surge_filt, vert, alpha)
	_last_surge = _sz * (_surge_filt - _surge_neutral)
	_surge_update_disp(delta)
	return _last_surge

## Telemetry only — integrates the surge signal into a rough displacement
## estimate so PGTEL can show gesture shape; nothing here drives ship speed.
func _surge_update_disp(delta: float) -> void:
	var a: float = _last_surge
	_surge_vel += a * delta
	_surge_vel *= exp(-delta / SURGE_VEL_TAU_S)
	_surge_disp += _surge_vel * delta
	var quiet: bool = absf(a) <= SURGE_ACCEL_QUIET and absf(_surge_vel) <= SURGE_VEL_QUIET
	if quiet and absf(_surge_disp) <= maxf(_surge_disp_band, 0.08):
		_surge_disp_quiet_t += delta
		if _surge_disp_quiet_t >= SURGE_QUIET_S:
			_surge_disp = 0.0
			_surge_vel = 0.0
	else:
		_surge_disp_quiet_t = 0.0

func _reset_surge_disp() -> void:
	_surge_vel = 0.0
	_surge_disp = 0.0
	_surge_disp_quiet_t = 0.0

func _recenter_surge_neutral() -> void:
	_surge_neutral = _surge_filt
	_surge_quiet_t = 0.0
	_surge_prev_filt = _surge_filt
	_surge_post_neutral = SURGE_POST_NEUTRAL_S
	_last_surge = 0.0
	_reset_surge_disp()
	_tel_event("surge neutral=%.2f" % _surge_neutral)

func _apply_surge_thresholds(_pull_peak: float = 0.0, _push_peak: float = 0.0) -> void:
	## Fixed floors — tutorial does not calibrate a gesture library.
	_surge_arm = SURGE_FIRE
	_surge_jerk = SURGE_FIRE
	_tel_event("surge thr fire=%.2f dead=%.2f sz=%.0f gears=%d" % [
		SURGE_FIRE, SURGE_DEAD, _sz, 1 if _speed_gears else 0])

func _surge_input_blocked() -> bool:
	return _speed_blending \
		or _surge_need_recenter \
		or _surge_post_neutral > 0.0 \
		or _jerk_cd > 0.0

## Gears: +surge (lower) → speed up; −surge (lift) → slow down.
## Cruise: +surge (lift) → cruise; −surge (lower) → stop.
## Rising-edge only: must return below DEAD (armed) before the next FIRE.
## No queued / held-level fires after "Joystick ready".
func _speed_from_surge(delta: float) -> void:
	_tick_speed_blend(delta)
	var s: float = _last_surge
	var a: float = absf(s)
	if _surge_input_blocked():
		_surge_await_rest = true
		_surge_armed = false
		if _surge_need_recenter:
			var dfilt: float = absf(_surge_filt - _surge_prev_filt)
			_surge_prev_filt = _surge_filt
			if dfilt <= SURGE_QUIET_EPS:
				_surge_quiet_t += delta
			else:
				_surge_quiet_t = 0.0
			if _surge_quiet_t >= SURGE_QUIET_S:
				_recenter_surge_neutral()
				_surge_need_recenter = false
		else:
			_surge_quiet_t = 0.0
		return
	if _surge_ready_grace > 0.0:
		# Re-arm only after a quiet moment during grace.
		if a <= SURGE_DEAD:
			_surge_armed = true
		return
	if a <= SURGE_DEAD:
		_surge_await_rest = false
		_surge_armed = true
		return
	if _surge_await_rest:
		return
	# Tip-up/down (gravity pitch) wins over soft vertical spikes from tipping.
	# A real lift/lower with little pitch can still fire.
	var tip: float = absf(_raw_tilt_y)
	if tip > SURGE_TIP_BLOCK:
		return
	# One fire per rest→motion edge. Never fire while still "high".
	if _surge_armed and a >= SURGE_FIRE:
		_surge_armed = false
		_surge_await_rest = true
		_fire_surge_jerk(signf(s))

func _begin_speed_backoff() -> void:
	_surge_pitch_cd = SURGE_PITCH_HOLD_S
	_surge_need_recenter = false
	_surge_await_rest = true
	_surge_armed = false
	_joy_ready_announced = false
	if _gear_joy != null and _speed_gears:
		_gear_joy.set_waiting()

func _fire_surge_jerk(dir: float) -> void:
	# Single shot — CD blocks until rest+edge again (no queue).
	if _jerk_cd > 0.0 or _speed_blending:
		_tel_event("surge ignored queued dir=%.0f cd=%.2f blend=%d" % [
			dir, _jerk_cd, 1 if _speed_blending else 0])
		return
	_jerk_cd = SURGE_JERK_CD_S
	if _speed_gears:
		_fire_gear_jerk(dir)
	else:
		_fire_cruise_jerk(dir)
	_update_speed_hint()

func _fire_cruise_jerk(dir: float) -> void:
	_begin_speed_backoff()
	if dir > 0.0:
		_apply_speed_step(SPEED_STEP_CRUISE, false)
		_tel_event("surge lift cruise step=%d" % _speed_step)
		Narrator.speak(LINE_RESUME)
	else:
		_apply_speed_step(SPEED_STEP_STOP, false)
		_tel_event("surge lower stop")
		Narrator.speak(LINE_STOP)

func _fire_gear_jerk(dir: float) -> void:
	# dir > 0 = speed up (phone lowered); dir < 0 = slow down (phone lifted).
	if dir > 0.0:
		if _speed_step >= SPEED_STEP_MAX:
			_surge_await_rest = true
			Narrator.speak(LINE_ALREADY_MAX)
			_tel_event("surge already_max step=%d" % _speed_step)
			return
		if _gear_joy != null:
			_gear_joy.throw_aft()  ## pull back → speed up
		_begin_speed_backoff()
		var prev_up: int = _speed_step
		_apply_speed_step(_speed_step + 1, true)
		_narrate_speed_change(prev_up, _speed_step)
		_tel_event("surge gear %d→%d lower/faster" % [prev_up, _speed_step])
		return
	if _speed_step <= SPEED_STEP_STOP:
		_surge_await_rest = true
		Narrator.speak(LINE_ALREADY_STOP)
		_tel_event("surge already_stop")
		return
	if _gear_joy != null:
		_gear_joy.throw_forward()  ## push forward → slow down
	_begin_speed_backoff()
	var prev_dn: int = _speed_step
	_apply_speed_step(_speed_step - 1, true)
	_narrate_speed_change(prev_dn, _speed_step)
	_tel_event("surge gear %d→%d lift/slower" % [prev_dn, _speed_step])

## Gears HUD: waiting (yellow) while blending/CD → ready (green) + VO.
## Entering ready recenters surge + grace so residual cannot auto-fire.
func _tick_gear_joystick(_delta: float) -> void:
	if _gear_joy == null or not _speed_gears:
		return
	_gear_joy.gear = _speed_step
	_gear_joy.visible = true
	var busy: bool = _surge_input_blocked() \
		or (_surge_await_rest and absf(_last_surge) > SURGE_DEAD)
	if busy:
		_gear_joy.set_waiting()
		_joy_ready_announced = false
		return
	if _gear_joy.phase != GearJoystick.Phase.READY:
		_gear_joy.set_ready()
	if not _joy_ready_announced:
		_joy_ready_announced = true
		# Snapshot rest at the ready moment — hanging lift must not count.
		_surge_neutral = _surge_filt
		_last_surge = 0.0
		_surge_armed = false
		_surge_await_rest = false
		_surge_ready_grace = SURGE_READY_GRACE_S
		Narrator.speak(LINE_JOY_READY)
		_tel_event("joystick ready grace=%.2f" % SURGE_READY_GRACE_S)

func _speed_for_step(step: int) -> float:
	if step <= SPEED_STEP_STOP:
		return 0.0
	var i: int = clampi(step, SPEED_STEP_MIN, SPEED_STEP_MAX) - 1
	return SPEED * float(SPEED_STEP_MULT[i])

func _apply_speed_step(step: int, smooth: bool) -> void:
	_speed_step = clampi(step, SPEED_STEP_STOP, SPEED_STEP_MAX)
	var target: float = _speed_for_step(_speed_step)
	if smooth and absf(target - _speed) > 0.05:
		_speed_from = _speed
		_speed_to = target
		_speed_blend_t = 0.0
		_speed_blending = true
	else:
		_speed = target
		_speed_to = target
		_speed_from = target
		_speed_blending = false
		_speed_blend_t = SPEED_BLEND_S

func _tick_speed_blend(delta: float) -> void:
	if not _speed_blending:
		return
	_speed_blend_t += delta
	var u: float = clampf(_speed_blend_t / SPEED_BLEND_S, 0.0, 1.0)
	u = u * u * (3.0 - 2.0 * u)
	_speed = lerpf(_speed_from, _speed_to, u)
	if _speed_blend_t >= SPEED_BLEND_S:
		_speed = _speed_to
		_speed_blending = false
	_update_speed_hint()

func _narrate_speed_change(prev: int, step: int) -> void:
	if step <= SPEED_STEP_STOP:
		Narrator.speak(LINE_STOP)
	elif step > prev:
		Narrator.speak(LINE_SPEEDING)
	else:
		Narrator.speak(LINE_SLOWING)

static func _gravity_sample() -> Vector3:
	var g := Input.get_gravity()
	if g.length() < 0.5:
		g = Input.get_accelerometer()
	return g

## Exponential low-pass over the raw sensor — a stable gravity estimate on
## devices whose only source is the noisy accelerometer.
func _gravity_filtered(delta: float) -> Vector3:
	var raw := _gravity_sample()
	if raw.length() < 0.5:
		return raw   # desktop / no sensor
	if _g_filt.length() < 0.5:
		_g_filt = raw
	else:
		_g_filt = _g_filt.lerp(raw, 1.0 - exp(-delta / TILT_LP_TAU_S))
	return _g_filt

## Gravity → (roll, pitch) tilt angles in the SCREEN frame.
##   roll  — steering-wheel twist about the screen's vertical axis
##   pitch — top edge tipped toward/away from the player
static func _tilt_angles(g: Vector3) -> Vector2:
	var gn := g.normalized()
	var roll := atan2(gn.x, sqrt(maxf(gn.y * gn.y + gn.z * gn.z, 1.0e-6)))
	var pitch := atan2(-gn.z, -gn.y)
	return Vector2(roll, pitch)

## Deadzoned, smoothstep-shaped response on an angle delta (radians):
## a resting hand flies straight, small tilts steer gently, TILT_FULL_RAD
## (~17°) is full deflection.
static func _tilt_axis(d: float) -> float:
	var a: float = absf(d)
	if a <= TILT_DEAD_RAD:
		return 0.0
	var u: float = clampf(
		(a - TILT_DEAD_RAD) / (TILT_FULL_RAD - TILT_DEAD_RAD), 0.0, 1.0)
	return signf(d) * u * u * (3.0 - 2.0 * u)

## Down-side detection: locked-landscape phones can deliver the sensor frame
## either way up. When the decisive vertical gravity component says "up is
## +y", the whole screen frame is rotated 180°: negate x and y (z, out of
## the screen, is unchanged by that rotation).
func _frame_adjust(g: Vector3) -> Vector3:
	if absf(g.y) > 6.0:
		var f: float = -1.0 if g.y > 0.0 else 1.0
		if f != _flip:
			_flip = f
			_tel_event("downside flip=%.0f" % _flip)
	return Vector3(g.x * _flip, g.y * _flip, g.z)

## ── Every-launch tutorial (no persisted mapping) ────────────────────
func _enter_tutorial() -> void:
	_state = State.TUTORIAL
	_tut_i = 0
	_tut_hold = 0.0
	_tut_ref_sum = Vector2.ZERO
	_tut_ref_t = 0.0
	_no_sensor_frames = 0
	_sx = 1.0
	_sy = 1.0
	_sz = -1.0 if _speed_gears else 1.0
	_tut_surge_phase = "pose"
	_tut_surge_phase_t = 0.0
	if _speed_gears:
		_tut_steps = TUT_STEPS_GEARS
	else:
		_tut_steps = TUT_STEPS_CRUISE
	_reticle.visible = false
	_tut_arrow.visible = true
	_tut_phone.visible = true
	if _speed_bar != null:
		_speed_bar.visible = false
	if _gear_joy != null:
		_gear_joy.visible = false
	_reset_level_look()
	_show_tut_step(0)
	_tel_event("tutorial enter gears=%d" % [1 if _speed_gears else 0])
	_speak_tut_step(0)

func _show_tut_step(i: int) -> void:
	var step: Dictionary = _tut_steps[i]
	_hint.text = str(step["hint"])
	if str(step.get("kind", "tilt")) == "surge":
		# Phone outline + chevron carry the cue; big centered glyph was a
		# stray bar over the device.
		_tut_arrow.visible = false
		_begin_surge_step(step)
	else:
		_tut_arrow.visible = true
		_tut_arrow.text = str(step["arrow"])
		_tut_phone.set_step(int(step["axis"]), float(step["dir"]))
		_tut_phone.set_status("yellow")
		_tut_phone.set_animate(true)

func _speak_tut_step(i: int) -> void:
	var step: Dictionary = _tut_steps[i]
	Narrator.speak(str(step["line"]))

func _begin_surge_step(step: Dictionary) -> void:
	# motion = physical lift(+)/lower(−) for the phone graphic; dir = signed surge.
	var motion: float = float(step.get("motion", step["dir"]))
	_tut_phone.set_surge(motion)
	_tut_phone.set_status("yellow")
	_tut_phone.set_animate(true)
	_tut_surge_phase = "pose"
	_tut_surge_phase_t = 0.0
	_tut_hold = 0.0
	_hint.text = str(step["hint"])
	_tel_event("tut_surge begin dir=%.0f motion=%.0f" % [
		float(step["dir"]), motion])

func _reset_level_look() -> void:
	## Snap the camera back to a level look at the home world so a phone
	## that started pointed down never leaves the player staring into void.
	_look_at_body(_start_at)
	_look_yaw = _yaw
	_apply_cam()

func _look_at_body(id: String) -> void:
	var body := SolarData.flyer_body_by_id(id, _cfg)
	var target := _body_playground_pos(body, _clock)
	var to := target - _ship_pos
	if to.length() < 0.01:
		_yaw = 0.0
	else:
		var flat := Vector3(to.x, 0.0, to.z)
		if flat.length() < 0.01:
			flat = Vector3(0.0, 0.0, -1.0)
		flat = flat.normalized()
		# _heading flat: (-sin yaw, 0, -cos yaw) == flat
		_yaw = atan2(-flat.x, -flat.z)
	_pitch = 0.0

func _tut_tick(delta: float) -> void:
	var step: Dictionary = _tut_steps[_tut_i]
	if str(step.get("kind", "tilt")) == "surge":
		_tut_surge_tick(delta, step)
		return
	var raw := _gravity_filtered(delta)
	if raw.length() < 0.5:
		_no_sensor_frames += 1
		if _no_sensor_frames >= NO_SENSOR_SKIP_FRAMES:
			_tel_event("tutorial skipped (no sensor)")
			_apply_surge_thresholds()
			_enter_gate()
		return
	_no_sensor_frames = 0
	var ang := _tilt_angles(_frame_adjust(raw))
	# Each step opens with a short settle that reads the CURRENT pose, so
	# tilts are judged from wherever the hand actually rests.
	if _tut_ref_t < TUT_SETTLE_S:
		_tut_ref_sum += ang * delta
		_tut_ref_t += delta
		if _tut_ref_t >= TUT_SETTLE_S:
			_tut_ref = _tut_ref_sum / _tut_ref_t
			_reset_level_look()
		return
	var d := ang - _tut_ref
	var axis: int = int(step["axis"])
	# ONLY the active control moves the view — other axis is locked level.
	if axis == 0:
		_yaw = _look_yaw - _tilt_axis(_sx * d.x) * 0.85
		_pitch = 0.0
	else:
		_yaw = _look_yaw
		_pitch = clampf(_tilt_axis(_sy * d.y) * 0.55, -0.55, 0.55)
	_apply_cam()
	var raw_v: float = d.x if axis == 0 else d.y
	var want: float = float(step["dir"])
	var ok: bool
	if bool(step["learn"]):
		# The learn steps DEFINE the mapping: whichever way the sensor angle
		# moved when the player was asked to tilt right / point up IS
		# right / up on this device.
		ok = absf(raw_v) > TUT_ANGLE_RAD
		if ok:
			var sgn: float = signf(raw_v) * want
			if axis == 0 and sgn != _sx:
				_sx = sgn
				_tel_event("learned sx=%.0f" % _sx)
			elif axis == 1 and sgn != _sy:
				_sy = sgn
				_tel_event("learned sy=%.0f" % _sy)
	else:
		var sign_now: float = _sx if axis == 0 else _sy
		ok = sign_now * raw_v * want > TUT_ANGLE_RAD
	if ok:
		_tut_hold += delta
		if _tut_hold >= TUT_HOLD_S:
			_tut_advance()
	else:
		_tut_hold = 0.0

## Lift/lower tutorial: same shape as tilt — short VO, settle, hold, Got it.
func _tut_surge_tick(delta: float, step: Dictionary) -> void:
	var raw := _gravity_filtered(delta)
	if raw.length() < 0.5 and Input.get_accelerometer().length() < 0.5:
		_no_sensor_frames += 1
		if _no_sensor_frames >= NO_SENSOR_SKIP_FRAMES:
			_tel_event("tutorial surge skipped (no sensor)")
			_tut_advance()
		return
	_no_sensor_frames = 0
	_surge_sample(delta)
	var want: float = float(step["dir"])
	var learn: bool = bool(step.get("learn", false))

	if _tut_surge_phase == "pose":
		_tut_phone.set_status("yellow")
		_tut_phone.set_animate(true)
		_hint.text = str(step["hint"])
		if Narrator.is_playing():
			return
		# Brief settle so the VO-end wobble isn't the "lift" sample.
		_tut_surge_phase_t += delta
		_surge_neutral = _surge_filt
		_last_surge = 0.0
		if _tut_surge_phase_t < TUT_SURGE_SETTLE_S:
			return
		_reset_surge_disp()
		_tut_hold = 0.0
		_tut_surge_phase = "go"
		_tut_surge_phase_t = 0.0
		_tut_phone.set_status("green")
		_tel_event("tut_surge go neutral=%.2f" % _surge_neutral)
		return

	if _tut_surge_phase == "success":
		# Kept for telem compatibility — accept advances immediately.
		_tut_advance()
		return

	# Listen: first clear motion → next step (no hold window).
	_tut_phone.set_status("green")
	_tut_phone.set_animate(true)
	_hint.text = str(step["hint"])
	var axis_delta: float = _surge_filt - _surge_neutral
	var ok: bool = false
	if _speed_gears:
		# Gears: lift → slow (−surge), lower → faster (+surge).
		if learn:
			ok = absf(axis_delta) >= TUT_SURGE_MIN
			if ok and signf(axis_delta) != 0.0:
				_sz = -signf(axis_delta)
				_tel_event("learned sz=%.0f lift_raw=%.2f" % [_sz, axis_delta])
		else:
			ok = _last_surge >= TUT_SURGE_MIN
	elif learn:
		ok = absf(axis_delta) >= TUT_SURGE_MIN
		if ok:
			var sgn: float = signf(axis_delta) * want
			if sgn != 0.0 and sgn != _sz:
				_sz = sgn
				_tel_event("learned sz=%.0f raw=%.2f" % [_sz, axis_delta])
	else:
		ok = _last_surge * want >= TUT_SURGE_MIN
	if ok:
		_tut_surge_accept()

func _tut_surge_accept() -> void:
	_tut_phone.set_status("green")
	_tut_phone.set_animate(false)
	_hint.text = "Got it!"
	_tel_event("tut_surge success")
	# Same pace as a completed tilt step — next VO immediately.
	_tut_advance()

func _tut_advance() -> void:
	_tel_event("tutorial step %d done" % _tut_i)
	_tut_i += 1
	_tut_hold = 0.0
	_tut_ref_sum = Vector2.ZERO
	_tut_ref_t = 0.0
	_tut_surge_phase = "pose"
	_tut_surge_phase_t = 0.0
	_reset_level_look()
	if _tut_i >= _tut_steps.size():
		_tut_phone.visible = false
		_tut_arrow.visible = false
		_apply_surge_thresholds()
		_tel_event("tutorial done sz=%.0f" % _sz)
		_enter_gate()
		return
	_show_tut_step(_tut_i)
	_speak_tut_step(_tut_i)

func _update_speed_hint() -> void:
	var flying: bool = _state == State.FLYING or _state == State.SEEKING
	_show_tap_hud(flying)
	if _speed_step <= SPEED_STEP_STOP:
		_hint.text = "STOPPED — tap green to cruise · tap a planet to go"
	elif _state == State.SEEKING:
		pass  ## seek sets its own hint
	else:
		_hint.text = "Gear %d / %d · tap stick · tap planets" % [
			_speed_step, SPEED_STEP_MAX]

## ── Every-play aim gate ─────────────────────────────────────────────
func _enter_gate() -> void:
	_state = State.AIM_GATE
	_gate_hold = 0.0
	_gate_sum = Vector2.ZERO
	_no_sensor_frames = 0
	_tut_arrow.visible = false
	_tut_phone.visible = false
	if _speed_pick != null:
		_speed_pick.visible = false
	# Clean start: level camera pointed at the home world while the player
	# centers the phone. Tilt during the gate only moves the reticle.
	_reset_level_look()
	_reticle.visible = true
	_reticle.hold_frac = 0.0
	_reticle.queue_redraw()
	_hint.text = "Aim straight ahead and hold steady"
	_tel_event("gate enter")
	Narrator.speak(LINE_AIM)

func _gate_tick(delta: float) -> void:
	var raw := _gravity_filtered(delta)
	if raw.length() < 0.5:
		_no_sensor_frames += 1
		if _no_sensor_frames >= NO_SENSOR_SKIP_FRAMES:
			_tel_event("gate skipped (no sensor)")
			_launch(Vector2.ZERO)
		return
	_no_sensor_frames = 0
	var ang := _tilt_angles(_frame_adjust(raw))
	var inside: bool = ang.length() <= GATE_RADIUS_RAD
	if inside:
		_gate_hold += delta
		_gate_sum += ang * delta
		if _gate_hold >= GATE_HOLD_S:
			# The held pose becomes the steering neutral — dead ahead is
			# exactly where the player just aimed.
			_launch(_gate_sum / _gate_hold)
			return
	else:
		_gate_hold = 0.0
		_gate_sum = Vector2.ZERO
	# Keep the world view level/forward during the gate — only the reticle
	# shows how far the phone is from dead-on.
	_yaw = _look_yaw
	_pitch = 0.0
	_apply_cam()
	_reticle.off = Vector2(_sx * ang.x, _sy * ang.y)
	_reticle.inside = inside
	_reticle.hold_frac = _gate_hold / GATE_HOLD_S
	_reticle.queue_redraw()

func _launch(neutral: Vector2) -> void:
	## Suite / legacy entry — same tap HUD as _launch_tap.
	_tilt_neutral = neutral
	_tel_event("launch→tap neutral=(%.3f,%.3f)" % [neutral.x, neutral.y])
	_launch_tap()
func _fly(delta: float) -> void:
	var fwd := _heading()
	_ship_pos += fwd * _speed * delta
	_ship_pos.y = clampf(_ship_pos.y, -Y_MAX, Y_MAX)
	_apply_cam()

func _apply_cam() -> void:
	_cam.global_position = _ship_pos
	_cam.look_at(_ship_pos + _heading(), Vector3.UP)

func _heading() -> Vector3:
	return Vector3(
		-sin(_yaw) * cos(_pitch), sin(_pitch), -cos(_yaw) * cos(_pitch)).normalized()

func _check_capture() -> void:
	if _capture_grace > 0.0:
		return
	var fwd := _heading()
	for id in _bodies:
		var info: Dictionary = _bodies[id]
		var hero: float = float(info["hero"])
		var center: Vector3 = (info["root"] as Node3D).global_position
		var d: float = _ship_pos.distance_to(center)
		if d > hero * CAPTURE_HERO_X:
			continue
		var aim: float = fwd.dot((center - _ship_pos) / maxf(d, 0.001))
		# Head-on only: capture needs the ship flying AT the world. An
		# actual surface hit captures at any angle (you can't fly through).
		if d < hero * 1.05 or aim > CAPTURE_AIM_DOT:
			_tel_event("capture id=%s d=%.1f x_hero=%.2f aim=%.2f" % [
				id, d, d / maxf(hero, 0.001), aim])
			_enter_orbit(id)
			return

## One compact PGTEL line every TEL_PERIOD_S while flying: raw sensors,
## neutral, shaped tilts, attitude, and the nearest world's capture numbers.
func _telemetry(delta: float) -> void:
	if not TELEMETRY:
		return
	_tel_t += delta
	if _tel_t < TEL_PERIOD_S:
		return
	_tel_t = 0.0
	var g := Input.get_gravity()
	var acc := Input.get_accelerometer()
	var near_id := ""
	var near_x := 1.0e18
	var near_d := 0.0
	for id in _bodies:
		var info: Dictionary = _bodies[id]
		var d: float = _ship_pos.distance_to(
			(info["root"] as Node3D).global_position)
		var x: float = d / maxf(float(info["hero"]), 0.001)
		if x < near_x:
			near_x = x
			near_id = id
			near_d = d
	var aim := 0.0
	if not near_id.is_empty():
		var c: Vector3 = (_bodies[near_id]["root"] as Node3D).global_position
		aim = _heading().dot((c - _ship_pos).normalized())
	var ang := _tilt_angles(Vector3(_g_filt.x * _flip, _g_filt.y * _flip, _g_filt.z)) \
		if _g_filt.length() > 0.5 else Vector2.ZERO
	print("PGTEL g=(%.2f,%.2f,%.2f) acc=(%.2f,%.2f,%.2f) ang=(%.3f,%.3f) na=(%.3f,%.3f) s=(%.0f,%.0f,%.0f) cal=%d tilt=(%.2f,%.2f) yaw=%.2f pitch=%.2f y=%.1f near=%s d=%.1f x=%.2f aim=%.2f spd=%.0f step=%d blend=%d surge=%.2f fire=%.2f jerk_cd=%.1f rest=%d disp=%.3f vel=%.3f" % [
		g.x, g.y, g.z, acc.x, acc.y, acc.z,
		ang.x, ang.y, _tilt_neutral.x, _tilt_neutral.y,
		_sx, _sy, _sz,
		1 if _calibrated else 0, _last_tilt.x, _last_tilt.y,
		_yaw, _pitch, _ship_pos.y, near_id, near_d, near_x, aim,
		_speed, _speed_step, 1 if _speed_blending else 0, _last_surge,
		SURGE_FIRE, _jerk_cd, 1 if _surge_await_rest else 0,
		_surge_disp, _surge_vel])

func _tel_event(msg: String) -> void:
	if TELEMETRY:
		print("PGTEL EV ", msg)

func _recalibrate() -> void:
	_calibrated = false
	_cal_sum = Vector2.ZERO
	_cal_t = 0.0
	_g_filt = Vector3.ZERO

func _enter_orbit(id: String) -> void:
	_tel_event("orbit id=%s" % id)
	_state = State.ORBITING
	_orbit_id = id
	_seek_id = ""
	_tap_yaw_rate = 0.0
	_tap_pitch_rate = 0.0
	_show_tap_hud(false)
	var center: Vector3 = (_bodies[id]["root"] as Node3D).global_position
	# Park ~90° off the sun-planet line so the lit face fills the glass.
	if center.length() > 0.01:
		var sun_dir := -center.normalized()
		_orbit_ang = atan2(sun_dir.z, sun_dir.x) + PI * 0.5
	else:
		var rel := _ship_pos - center
		_orbit_ang = atan2(rel.z, rel.x) if rel.length() > 0.01 else 0.0
	_cine.play(id)

func _on_cinematic_done() -> void:
	if _state != State.ORBITING:
		return
	_place_orbit_cam()
	var b := SolarData.flyer_body_by_id(_orbit_id, _cfg)
	_show_arrival(str(b.get("name", _orbit_id)))
	arrived.emit(_orbit_id)

func _place_orbit_cam() -> void:
	if _orbit_id.is_empty() or not _bodies.has(_orbit_id):
		return
	var info: Dictionary = _bodies[_orbit_id]
	var center: Vector3 = (info["root"] as Node3D).global_position
	var hero: float = float(info["hero"])
	var standoff: float = OrbitMath.sun_approach_standoff(_cfg) \
		if bool(info["data"].get("is_star", false)) else OrbitMath.orbit_standoff(hero)
	_ship_pos = center + OrbitMath.orbit_offset(_orbit_ang, standoff, 0.2)
	_cam.global_position = _ship_pos
	var tangent := OrbitMath.orbit_tangent(_orbit_ang, 1.0)
	# Yaw toward the planet's side so it looms abeam, not behind us.
	var to_planet := (center - _ship_pos).normalized()
	var side: float = signf(tangent.cross(to_planet).y)
	if side == 0.0:
		side = 1.0
	var fwd := tangent.rotated(Vector3.UP, side * deg_to_rad(42.0))
	_cam.look_at(_ship_pos + fwd, Vector3.UP)

## ── Tap handling ────────────────────────────────────────────────────
func _gui_input(event: InputEvent) -> void:
	var tap := false
	var pos := Vector2.ZERO
	if event is InputEventScreenTouch and event.pressed:
		tap = true
		pos = event.position
		_tap_guard_t = TAP_GUARD_S
	elif event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# Android often synthesizes a mouse click after a touch — that was
		# immediately cancelling seek ("keep exploring!") before travel.
		if _tap_guard_t > 0.0:
			return
		tap = true
		pos = event.position
	if not tap:
		return
	var vp_pos: Vector2 = _map_to_viewport(pos)
	match _state:
		State.FLYING:
			_resolve_flying_tap(pos, vp_pos)
		State.SEEKING:
			# Planet under finger retargets (even mid-turn); empty cancels.
			var id2 := _body_at_screen(vp_pos)
			if id2.is_empty():
				_cancel_seek()
			elif id2 != _seek_id:
				_begin_seek(id2)
			# same body: ignore (do not cancel)

## Planet under finger always wins (even while turning). Otherwise steer.
func _resolve_flying_tap(local: Vector2, vp_pos: Vector2) -> void:
	var id := _body_at_screen(vp_pos)
	if not id.is_empty():
		_begin_seek(id)
		return
	_on_empty_flight_tap(local)

## Control / stretch coords → SubViewport pixel space for unproject.
func _map_to_viewport(local: Vector2) -> Vector2:
	if _host == null or _viewport == null:
		return local
	var hs: Vector2 = _host.size
	if hs.x < 1.0 or hs.y < 1.0:
		return local
	var vs: Vector2 = Vector2(_viewport.size)
	return Vector2(local.x / hs.x * vs.x, local.y / hs.y * vs.y)

func _body_at_screen(vp_pos: Vector2, radius_px: float = -1.0) -> String:
	## Hit-test worlds by screen distance; large/near bodies get a bigger target.
	var best := ""
	var best_score := INF
	for id in _bodies:
		var info: Dictionary = _bodies[id]
		var wp: Vector3 = (info["root"] as Node3D).global_position
		if _cam.is_position_behind(wp):
			continue
		var sp: Vector2 = _cam.unproject_position(wp)
		var d: float = sp.distance_to(vp_pos)
		var hit_r: float = radius_px if radius_px > 0.0 else TAP_RADIUS_PX
		if radius_px < 0.0:
			var hero: float = float(info["hero"])
			var dist3: float = maxf(_cam.global_position.distance_to(wp), 0.5)
			# Rough projected radius in viewport px (FOV ~70°).
			var proj: float = (hero / dist3) * float(_viewport.size.y) * 0.85
			hit_r = clampf(maxf(TAP_RADIUS_PX, proj * 1.15), 40.0, 160.0)
		if d < hit_r and d < best_score:
			best_score = d
			best = id
	return best

func _begin_seek(id: String) -> void:
	if not _bodies.has(id):
		return
	_seek_id = id
	_state = State.SEEKING
	_tap_yaw_rate = 0.0
	_tap_pitch_rate = 0.0
	_surge_await_rest = true
	_capture_grace = 0.0
	var b := SolarData.flyer_body_by_id(id, _cfg)
	var place: String = str(b.get("name", id))
	_hint.text = "→ %s  (tap empty to cancel)" % place
	_show_tap_hud(true)
	_tel_event("seek start id=%s" % id)
	Narrator.speak(LINE_SEEK % place)

func _cancel_seek() -> void:
	_tel_event("seek cancel id=%s" % _seek_id)
	_seek_id = ""
	_state = State.FLYING
	_update_speed_hint()
	Narrator.speak(LINE_SEEK_CANCEL)

## Controls locked: auto-aim + cruise toward the tapped world until capture.
func _seek_tick(delta: float) -> void:
	if _seek_id.is_empty() or not _bodies.has(_seek_id):
		_cancel_seek()
		return
	var info: Dictionary = _bodies[_seek_id]
	var center: Vector3 = (info["root"] as Node3D).global_position
	var hero: float = float(info["hero"])
	var to: Vector3 = center - _ship_pos
	var dist: float = to.length()
	if dist < 0.05:
		_enter_orbit(_seek_id)
		return
	var desired: Vector3 = to / dist
	var want_pitch: float = asin(clampf(desired.y, -0.99, 0.99))
	var want_yaw: float = atan2(-desired.x, -desired.z)
	var u: float = minf(1.0, SEEK_TURN * delta)
	_yaw = lerp_angle(_yaw, want_yaw, u)
	_pitch = clampf(lerpf(_pitch, want_pitch, u), -0.7, 0.7)
	var spd: float = maxf(_speed, SEEK_SPEED_MIN)
	if _speed < SEEK_SPEED_MIN:
		_speed = SEEK_SPEED_MIN
		if _speed_gears:
			_speed_step = maxi(_speed_step, SPEED_STEP_MIN)
	_ship_pos += _heading() * spd * delta
	_ship_pos.y = clampf(_ship_pos.y, -Y_MAX, Y_MAX)
	_apply_cam()
	# Arrive when close enough — head-on is guaranteed by auto-aim.
	if dist <= hero * CAPTURE_HERO_X:
		_tel_event("seek capture id=%s d=%.1f" % [_seek_id, dist])
		_enter_orbit(_seek_id)

func _show_arrival(place: String) -> void:
	_arrival_title.text = "Welcome to %s!" % place
	_refresh_arrival_planet_tile()
	_arrival.visible = true

func _refresh_arrival_planet_tile() -> void:
	if _arrival_planet_pic == null:
		return
	var id := _orbit_id
	var b := SolarData.flyer_body_by_id(id, _cfg) if not id.is_empty() else {}
	var name := str(b.get("name", id if not id.is_empty() else "Planet"))
	if _arrival_planet_lbl != null:
		_arrival_planet_lbl.text = name
	var fallback: Color = b.get("color", Color(0.55, 0.7, 1.0)) as Color
	var hero: float = float(b.get("hero_r", 2.0))
	# Relative size in the tile: tiny worlds stay small; gas giants / Sun fill.
	var u: float = clampf((hero - 1.0) / 12.0, 0.0, 1.0)
	var diam: int = int(lerpf(72.0, 200.0, u))
	if bool(b.get("is_star", false)):
		diam = 210
	_arrival_planet_pic.texture = PlanetSkins.make_disc_texture(id, fallback, diam)
	# Center the disc; KEEP_ASPECT_CENTERED so size reads as relative.
	_arrival_planet_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

## ── World ───────────────────────────────────────────────────────────
func _body_playground_pos(b: Dictionary, t: float) -> Vector3:
	var p := OrbitMath.body_pos(b, t)
	return p * SPACING

func _place_bodies() -> void:
	for id in _bodies:
		var info: Dictionary = _bodies[id]
		(info["root"] as Node3D).position = _body_playground_pos(info["data"], _clock)
		(info["mesh"] as Node3D).rotate_y(0.002)

## Meshes are always real; a constant-size marker halo helps find far worlds
## and fades once the mesh itself reads bigger.
func _update_markers() -> void:
	for id in _bodies:
		var info: Dictionary = _bodies[id]
		var root: Node3D = info["root"]
		var icon: Sprite3D = info["icon"]
		var hero: float = float(info["hero"])
		var dist: float = maxf(_cam.global_position.distance_to(root.global_position), 0.001)
		var marker: float = OrbitMath.marker_world_size(dist, float(info["tier"]), _cfg)
		var fade: float = clampf(hero * 3.0 / marker, 0.0, 1.0)
		icon.visible = fade < 0.95
		icon.modulate = Color(1, 1, 1, 1.0 - fade)
		icon.pixel_size = marker / float(PlanetSkins.MARKER_CANVAS_PX)

func _build_viewport() -> void:
	_host = SubViewportContainer.new()
	_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_host.stretch = true
	_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_host)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1280, 600)
	# Isolated world (see FlyScene): shared root World3D let scenes film
	# each other's planets.
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
	e.glow_intensity = 0.14
	env.environment = e
	_world.add_child(env)

	_sun_light = OmniLight3D.new()
	_sun_light.light_energy = 2.0
	_sun_light.omni_attenuation = 0.0
	_sun_light.omni_range = 1400.0
	_world.add_child(_sun_light)

	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	for i in 90:
		var s := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = rng.randf_range(0.5, 1.2)
		sm.height = sm.radius * 2.0
		sm.radial_segments = 4
		sm.rings = 2
		s.mesh = sm
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.emission_enabled = true
		m.emission = Color(0.9, 0.95, 1.0)
		m.emission_energy_multiplier = 1.1
		s.material_override = m
		s.position = Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.35, 0.35),
			rng.randf_range(-1, 1)).normalized() * rng.randf_range(800.0, 1300.0)
		_world.add_child(s)

	for b in SolarData.flyer_bodies(_cfg):
		if bool(b.get("belt", false)):
			continue
		var root := Node3D.new()
		root.name = str(b["id"])
		_world.add_child(root)
		var mesh := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 1.0
		sphere.height = 2.0
		sphere.radial_segments = 24
		sphere.rings = 16
		mesh.mesh = sphere
		mesh.material_override = PlanetSkins.make_skinned_material(b)
		var hero: float = float(b.get("hero_r", 2.0))
		mesh.scale = Vector3.ONE * hero
		root.add_child(mesh)
		if bool(b.get("ring", false)):
			var torus := TorusMesh.new()
			torus.inner_radius = 1.35
			torus.outer_radius = 2.1
			var ring := MeshInstance3D.new()
			ring.mesh = torus
			var rm := StandardMaterial3D.new()
			rm.albedo_color = Color(0.86, 0.78, 0.55, 0.75)
			rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			ring.material_override = rm
			ring.rotation_degrees = Vector3(78, 0, 0)
			mesh.add_child(ring)
		var icon := Sprite3D.new()
		icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		icon.shaded = false
		icon.texture = PlanetSkins.make_icon_texture(b, PlanetSkins.MARKER_CANVAS_PX)
		root.add_child(icon)
		_bodies[str(b["id"])] = {
			"root": root, "mesh": mesh, "icon": icon, "data": b,
			"hero": hero, "tier": SolarData.icon_tier_for(b),
		}

	_build_belt_decor()

	_cam = Camera3D.new()
	_cam.fov = 70.0
	_cam.near = 0.15
	_cam.far = 3000.0
	_world.add_child(_cam)
	_cam.current = true

## Sparse rock ring between Mars and Jupiter — atmosphere only.
## Ceres / Vesta / Psyche stay the only interactive belt worlds.
func _build_belt_decor() -> void:
	_belt_decor = null
	var belt := SolarData.flyer_body_by_id("asteroid_belt", _cfg)
	if belt.is_empty():
		return
	var ring_r: float = float(belt.get("orbit_r", 0.0)) * SPACING
	if ring_r < 1.0:
		return
	var mm := MultiMeshInstance3D.new()
	mm.name = "BeltDecor"
	var multi := MultiMesh.new()
	var rock := SphereMesh.new()
	rock.radius = 0.45
	rock.height = 0.9
	rock.radial_segments = 6
	rock.rings = 4
	multi.mesh = rock
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.instance_count = BELT_DECOR_COUNT
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.32, 0.30, 0.28)
	mm.material_override = mat
	mm.multimesh = multi
	_world.add_child(mm)
	_belt_decor = mm
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	for i in BELT_DECOR_COUNT:
		var ang: float = (TAU * float(i) / float(BELT_DECOR_COUNT)) \
			+ rng.randf_range(-0.04, 0.04)
		var rr: float = ring_r * (1.0 + rng.randf_range(-BELT_DECOR_RADIAL, BELT_DECOR_RADIAL))
		var y: float = rng.randf_range(-BELT_DECOR_Y, BELT_DECOR_Y)
		var pos := Vector3(cos(ang) * rr, y, sin(ang) * rr)
		var s: float = rng.randf_range(0.4, 1.5)
		if i % 16 == 0:
			s = rng.randf_range(1.8, 2.8)
		var basis := Basis.from_euler(Vector3(
			rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU))
		basis = basis.scaled(Vector3(s, s * rng.randf_range(0.65, 1.25), s))
		multi.set_instance_transform(i, Transform3D(basis, pos))

func _build_ui() -> void:
	_hint = Label.new()
	_hint.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_hint.offset_top = 14
	_hint.offset_bottom = 52
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 24)
	_hint.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)

	_gear_joy = GearJoystick.new()
	_gear_joy.name = "GearJoystick"
	_gear_joy.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_gear_joy.offset_left = -236
	_gear_joy.offset_right = -18
	_gear_joy.offset_top = -270
	_gear_joy.offset_bottom = -22
	_gear_joy.mouse_filter = Control.MOUSE_FILTER_STOP
	_gear_joy.visible = false
	_gear_joy.gui_input.connect(_on_joy_gui_input)
	add_child(_gear_joy)

	# Horizontal speed bar just above the joystick.
	_speed_bar = SpeedBar.new()
	_speed_bar.name = "SpeedBar"
	_speed_bar.step_max = SPEED_STEP_MAX
	_speed_bar.cruise_step = SPEED_STEP_CRUISE
	_speed_bar.horizontal = true
	_speed_bar.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_speed_bar.offset_left = -236
	_speed_bar.offset_right = -18
	_speed_bar.offset_top = -318
	_speed_bar.offset_bottom = -274
	_speed_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_speed_bar.visible = false
	add_child(_speed_bar)

	_stop_btn = StopCruiseButton.new()
	_stop_btn.name = "StopCruise"
	_stop_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_stop_btn.offset_left = -340
	_stop_btn.offset_right = -250
	_stop_btn.offset_top = -140
	_stop_btn.offset_bottom = -50
	_stop_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_stop_btn.visible = false
	_stop_btn.pressed.connect(_on_stop_cruise_pressed)
	add_child(_stop_btn)

	_home_btn = Button.new()
	_home_btn.text = "\u25C0"
	_home_btn.size = Vector2(84, 66)
	_home_btn.position = Vector2(20, 20)
	_home_btn.focus_mode = Control.FOCUS_NONE
	_home_btn.add_theme_font_size_override("font_size", 28)
	var hsb := StyleBoxFlat.new()
	hsb.bg_color = Color(0.95, 0.86, 0.45, 0.98)
	hsb.set_corner_radius_all(16)
	_home_btn.add_theme_stylebox_override("normal", hsb)
	_home_btn.pressed.connect(func() -> void: go_home.emit())
	add_child(_home_btn)

	# Bottom-left Sun compass — arrow points toward the Sun; tap to fly there.
	_sun_tile = SunCompassTile.new()
	_sun_tile.name = "SunTile"
	_sun_tile.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_sun_tile.offset_left = 18
	_sun_tile.offset_right = 118
	_sun_tile.offset_top = -140
	_sun_tile.offset_bottom = -40
	_sun_tile.mouse_filter = Control.MOUSE_FILTER_STOP
	_sun_tile.visible = false
	_sun_tile.pressed.connect(_on_sun_tile_pressed)
	add_child(_sun_tile)

	_reticle = AimReticle.new()
	_reticle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reticle.radius_rad = GATE_RADIUS_RAD
	_reticle.visible = false
	add_child(_reticle)

	_aim_mark = FlyAimMarker.new()
	_aim_mark.name = "FlyAimMarker"
	_aim_mark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_aim_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_aim_mark.home_radius_px = TAP_HOME_RADIUS_PX
	_aim_mark.visible = false
	add_child(_aim_mark)

	_tut_arrow = Label.new()
	_tut_arrow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tut_arrow.offset_top = 70
	_tut_arrow.offset_bottom = -180
	_tut_arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tut_arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tut_arrow.add_theme_font_size_override("font_size", 120)
	_tut_arrow.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4, 0.85))
	_tut_arrow.add_theme_constant_override("outline_size", 10)
	_tut_arrow.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	_tut_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tut_arrow.visible = false
	add_child(_tut_arrow)

	_tut_phone = PhoneTiltHint.new()
	_tut_phone.position = Vector2(515, 380)
	_tut_phone.size = Vector2(250, 160)
	_tut_phone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tut_phone.visible = false
	add_child(_tut_phone)

	_speed_pick = SpeedModeChooser.new()
	_speed_pick.visible = false
	_speed_pick.gears_pressed.connect(_on_speed_gears)
	_speed_pick.cruise_stop_pressed.connect(_on_speed_cruise_stop)
	add_child(_speed_pick)

	# Arrival tiles while parked in playground orbit (kid-clear chooser).
	_arrival = Control.new()
	_arrival.visible = false
	_arrival.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_arrival.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.04, 0.1, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_arrival.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrival.add_child(center)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(vbox)
	_arrival_title = Label.new()
	_arrival_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_arrival_title.add_theme_font_size_override("font_size", 34)
	_arrival_title.add_theme_color_override("font_color", Color(1, 0.95, 0.6))
	_arrival_title.add_theme_constant_override("outline_size", 6)
	_arrival_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.65))
	vbox.add_child(_arrival_title)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 36)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(row)
	row.add_child(_make_arrival_tile(
		"Keep flying",
		"Back to the cockpit",
		"res://images/cockpit.png",
		Color(0.18, 0.42, 0.32),
		true,
		resume_flying))
	var planet_col := _make_arrival_tile(
		"Planet",
		"Learn more",
		"",
		Color(0.16, 0.28, 0.48),
		false,
		func() -> void: learn_more.emit(_orbit_id))
	_arrival_planet_pic = planet_col.get_node("TileButton/Pic") as TextureRect
	_arrival_planet_lbl = planet_col.get_node("NameLabel") as Label
	row.add_child(planet_col)
	add_child(_arrival)

func _make_arrival_tile(label: String, hint: String, tex_path: String,
		tint: Color, cover: bool, on_press: Callable) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.custom_minimum_size = Vector2(340, 320)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var btn := Button.new()
	btn.name = "TileButton"
	btn.custom_minimum_size = Vector2(340, 220)
	btn.focus_mode = Control.FOCUS_NONE
	btn.clip_contents = true
	btn.add_theme_color_override("font_color", Color(0, 0, 0, 0))
	btn.add_theme_color_override("font_hover_color", Color(0, 0, 0, 0))
	btn.add_theme_color_override("font_pressed_color", Color(0, 0, 0, 0))
	var sb := StyleBoxFlat.new()
	sb.bg_color = tint
	sb.set_corner_radius_all(22)
	sb.set_border_width_all(3)
	sb.border_color = Color(1, 1, 1, 0.55)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 10
	var hover := sb.duplicate() as StyleBoxFlat
	hover.border_color = Color(0.95, 0.82, 0.35)
	hover.bg_color = tint.lightened(0.08)
	var pressed := sb.duplicate() as StyleBoxFlat
	pressed.bg_color = tint.darkened(0.12)
	pressed.border_color = Color(0.95, 0.82, 0.35)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("focus", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.pressed.connect(on_press)
	col.add_child(btn)
	var pic := TextureRect.new()
	pic.name = "Pic"
	pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pic.offset_left = 10
	pic.offset_top = 10
	pic.offset_right = -10
	pic.offset_bottom = -10
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED if cover \
		else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if not tex_path.is_empty() and ResourceLoader.exists(tex_path):
		pic.texture = load(tex_path)
	btn.add_child(pic)
	var name_lbl := Label.new()
	name_lbl.name = "NameLabel"
	name_lbl.text = label
	name_lbl.add_theme_font_size_override("font_size", 26)
	name_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(name_lbl)
	var hint_lbl := Label.new()
	hint_lbl.text = hint
	hint_lbl.add_theme_font_size_override("font_size", 16)
	hint_lbl.add_theme_color_override("font_color", Color(0.75, 0.82, 0.98))
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(hint_lbl)
	return col

## Center cross — turn reference. Empty taps near it level the nose.
class FlyAimMarker:
	extends Control
	var home_radius_px: float = 70.0

	func _draw() -> void:
		var c := size * 0.5
		var r: float = home_radius_px
		draw_arc(c, r, 0.0, TAU, 48, Color(1.0, 0.95, 0.55, 0.35), 2.0, true)
		draw_circle(c, 5.0, Color(1.0, 0.92, 0.4, 0.85))
		var arm: float = 18.0
		var col := Color(1.0, 0.95, 0.6, 0.75)
		draw_line(c + Vector2(-arm, 0.0), c + Vector2(arm, 0.0), col, 2.0, true)
		draw_line(c + Vector2(0.0, -arm), c + Vector2(0.0, arm), col, 2.0, true)

## Bottom-left Sun tile: disc + arrow that rotates toward the Sun (bearing).
class SunCompassTile:
	extends Control
	signal pressed
	var bearing: float = 0.0  ## rad; 0 = ahead, + = right

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventScreenTouch and event.pressed:
			accept_event()
			pressed.emit()
		elif event is InputEventMouseButton \
				and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			accept_event()
			pressed.emit()

	func _draw() -> void:
		var c := size * 0.5
		var r: float = minf(size.x, size.y) * 0.42
		draw_circle(c, r, Color(0.12, 0.10, 0.08, 0.82))
		draw_arc(c, r, 0.0, TAU, 40, Color(1.0, 0.75, 0.25, 0.85), 2.5, true)
		draw_circle(c, r * 0.38, Color(1.0, 0.85, 0.25, 0.95))
		draw_circle(c + Vector2(-r * 0.12, -r * 0.10), r * 0.12,
			Color(1.0, 0.95, 0.55, 0.55))
		# Arrow: up = sun ahead; rotates by bearing (screen y-down).
		var ang: float = bearing - PI * 0.5
		var tip := c + Vector2(cos(ang), sin(ang)) * (r * 0.88)
		var left := c + Vector2(cos(ang + 2.5), sin(ang + 2.5)) * (r * 0.42)
		var right := c + Vector2(cos(ang - 2.5), sin(ang - 2.5)) * (r * 0.42)
		draw_colored_polygon(PackedVector2Array([tip, left, right]),
			Color(1.0, 0.55, 0.15, 0.95))
		var font := ThemeDB.fallback_font
		var lab := "SUN"
		var fs := 16
		var tw := font.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, Vector2(c.x - tw * 0.5, size.y - 4.0), lab,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.92, 0.55, 0.95))

## Red octagon (stop) ↔ green circle (cruise).
class StopCruiseButton:
	extends Control
	signal pressed
	var stopped: bool = false

	func set_stopped(on: bool) -> void:
		if stopped == on:
			return
		stopped = on
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventScreenTouch and event.pressed:
			accept_event()
			pressed.emit()
		elif event is InputEventMouseButton \
				and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			accept_event()
			pressed.emit()

	func _draw() -> void:
		var c := size * 0.5
		var r: float = minf(size.x, size.y) * 0.42
		var font := ThemeDB.fallback_font
		if stopped:
			draw_circle(c, r, Color(0.25, 0.82, 0.42, 0.95))
			draw_arc(c, r, 0.0, TAU, 40, Color(0.85, 1.0, 0.9, 0.9), 3.0, true)
			var lab := "GO"
			var fs := 22
			var tw := font.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string(font, Vector2(c.x - tw * 0.5, c.y + 8.0), lab,
				HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.05, 0.2, 0.1))
		else:
			_draw_octagon(c, r, Color(0.9, 0.18, 0.16, 0.95))
			_draw_octagon_outline(c, r, Color(1.0, 0.85, 0.8, 0.9))
			var lab2 := "STOP"
			var fs2 := 18
			var tw2 := font.get_string_size(lab2, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
			draw_string(font, Vector2(c.x - tw2 * 0.5, c.y + 7.0), lab2,
				HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, Color(1.0, 0.95, 0.95))

	func _draw_octagon(c: Vector2, r: float, col: Color) -> void:
		var pts := PackedVector2Array()
		for i in 8:
			var a: float = -PI * 0.5 + float(i) * TAU / 8.0 + PI / 8.0
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		draw_colored_polygon(pts, col)

	func _draw_octagon_outline(c: Vector2, r: float, col: Color) -> void:
		var prev := Vector2.ZERO
		for i in 9:
			var a: float = -PI * 0.5 + float(i % 8) * TAU / 8.0 + PI / 8.0
			var p: Vector2 = c + Vector2(cos(a), sin(a)) * r
			if i > 0:
				draw_line(prev, p, col, 3.0, true)
			prev = p

## Interactive stick (lower right): top-down art with green/yellow chevrons.
## Tap forward (top) = faster; aft (bottom) = slower.
class GearJoystick:
	extends Control
	const NEUTRAL_TEX: Texture2D = preload("res://assets/joystick/neutral.png")
	const FASTER_TEX: Texture2D = preload("res://assets/joystick/faster.png")
	const SLOWER_TEX: Texture2D = preload("res://assets/joystick/slower.png")
	enum Phase { WAITING, READY, THROW }
	var phase: int = Phase.WAITING
	var gear: int = 3
	var stick: float = 0.0       ## −1 forward, +1 aft
	var _stick_tgt: float = 0.0
	var _throw_hold: float = 0.0
	var _t: float = 0.0

	func set_waiting() -> void:
		if phase == Phase.THROW and _throw_hold > 0.0:
			return
		phase = Phase.WAITING
		_stick_tgt = 0.0
		queue_redraw()

	func set_ready() -> void:
		phase = Phase.READY
		_stick_tgt = 0.0
		queue_redraw()

	func throw_forward() -> void:
		phase = Phase.THROW
		_stick_tgt = -1.0
		_throw_hold = 0.85
		queue_redraw()

	func throw_aft() -> void:
		phase = Phase.THROW
		_stick_tgt = 1.0
		_throw_hold = 0.85
		queue_redraw()

	func _process(delta: float) -> void:
		if not visible:
			return
		_t += delta
		if phase == Phase.THROW:
			_throw_hold -= delta
			if _throw_hold <= 0.0:
				_stick_tgt = 0.0
				phase = Phase.READY
		var k: float = 1.0 - exp(-delta * 12.0)
		stick = lerpf(stick, _stick_tgt, k)
		queue_redraw()

	func _draw() -> void:
		var tex: Texture2D = NEUTRAL_TEX
		if phase == Phase.THROW:
			tex = FASTER_TEX if _stick_tgt < 0.0 else SLOWER_TEX
		var art_size: float = minf(size.x, size.y - 22.0)
		var art_rect := Rect2(
			Vector2((size.x - art_size) * 0.5, 0.0),
			Vector2(art_size, art_size))
		draw_texture_rect(tex, art_rect, false)
		var font := ThemeDB.fallback_font
		var g_lab: String = "STOP" if gear <= 0 else "GEAR %d" % gear
		var fs := 18
		var tw := font.get_string_size(g_lab, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, Vector2((size.x - tw) * 0.5, size.y - 6.0), g_lab,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.92, 0.95, 1.0, 0.95))

## Speed meter: STOP + five gears. Horizontal sits above the joystick.
class SpeedBar:
	extends Control
	var speed: float = 26.0
	var step: int = 3
	var step_max: int = 5
	var cruise_step: int = 3
	var blending: bool = false
	var horizontal: bool = false

	func _draw() -> void:
		if horizontal:
			_draw_horizontal()
		else:
			_draw_vertical()

	func _step_color() -> Color:
		var col := Color(0.35, 0.85, 1.0, 0.9) if step > 0 \
			else Color(0.55, 0.55, 0.65, 0.85)
		if step >= step_max:
			col = Color(1.0, 0.78, 0.30, 0.95)
		elif step == cruise_step:
			col = Color(0.45, 0.95, 0.55, 0.92)
		if blending:
			col = col.lightened(0.12)
		return col

	func _draw_horizontal() -> void:
		var w := size.x
		var h := size.y
		var track := Rect2(10.0, h * 0.28, w - 20.0, h * 0.44)
		draw_rect(track, Color(0.05, 0.08, 0.16, 0.82), true)
		draw_rect(track, Color(1.0, 1.0, 1.0, 0.35), false, 2.0)
		var t: float = float(clampi(step, 0, step_max)) / float(step_max)
		var fill_w: float = track.size.x * t
		draw_rect(Rect2(track.position.x, track.position.y, fill_w, track.size.y),
			_step_color(), true)
		var labels: Array = ["0", "1", "2", "3", "4", "5"]
		var font := ThemeDB.fallback_font
		for g in range(0, step_max + 1):
			var u: float = float(g) / float(step_max)
			var x: float = track.position.x + track.size.x * u
			var thick: float = 3.0 if g == cruise_step else 1.5
			var tc := Color(1.0, 0.9, 0.4, 0.95) if g == cruise_step \
				else Color(1.0, 1.0, 1.0, 0.35)
			draw_line(Vector2(x, track.position.y - 2.0),
				Vector2(x, track.end.y + 2.0), tc, thick)
			var lab: String = str(labels[g]) if g < labels.size() else str(g)
			var tw := font.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
			draw_string(font, Vector2(x - tw * 0.5, track.position.y - 4.0), lab,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.9, 0.92, 1.0, 0.9))
		var nx: float = track.position.x + track.size.x * t
		draw_colored_polygon(PackedVector2Array([
			Vector2(nx, track.end.y + 3.0),
			Vector2(nx - 6.0, track.end.y + 11.0),
			Vector2(nx + 6.0, track.end.y + 11.0),
		]), Color(1.0, 0.92, 0.45, 0.95))

	func _draw_vertical() -> void:
		var w := size.x
		var h := size.y
		var track := Rect2(w * 0.30, 10.0, w * 0.40, h - 36.0)
		draw_rect(track, Color(0.05, 0.08, 0.16, 0.75), true)
		draw_rect(track, Color(1.0, 1.0, 1.0, 0.35), false, 2.0)
		var t: float = float(clampi(step, 0, step_max)) / float(step_max)
		var fill_h: float = track.size.y * t
		var fill := Rect2(track.position.x, track.end.y - fill_h,
			track.size.x, fill_h)
		draw_rect(fill, _step_color(), true)
		var labels: Array = ["STOP", "1", "2", "3", "4", "5"]
		for g in range(0, step_max + 1):
			var u: float = float(g) / float(step_max)
			var y: float = track.end.y - track.size.y * u
			var thick: float = 3.0 if g == cruise_step else 1.5
			var tc := Color(1.0, 0.9, 0.4, 0.95) if g == cruise_step \
				else Color(1.0, 1.0, 1.0, 0.35)
			if g == 0:
				tc = Color(0.75, 0.75, 0.85, 0.55)
			draw_line(Vector2(track.position.x - 3.0, y),
				Vector2(track.end.x + 3.0, y), tc, thick)
			var font := ThemeDB.fallback_font
			var fs := 11
			var lab: String = str(labels[g]) if g < labels.size() else str(g)
			draw_string(font, Vector2(track.end.x + 5.0, y + 4.0), lab,
				HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.9, 0.92, 1.0, 0.85))
		var ny: float = track.end.y - track.size.y * t
		draw_colored_polygon(PackedVector2Array([
			Vector2(track.position.x - 10.0, ny),
			Vector2(track.position.x - 2.0, ny - 6.0),
			Vector2(track.position.x - 2.0, ny + 6.0),
		]), Color(1.0, 0.92, 0.45, 0.95))
		var font2 := ThemeDB.fallback_font
		var fs2 := 14
		var labels2: Array = ["STOP", "1", "2", "3", "4", "5"]
		var label: String = str(labels2[clampi(step, 0, mini(step_max, labels2.size() - 1))])
		var tw := font2.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
		draw_string(font2, Vector2((w - tw) * 0.5, h - 4.0), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, Color(0.95, 0.95, 1.0, 0.95))

class AimReticle:
	extends Control
	const PX_PER_RAD := 420.0
	var off := Vector2.ZERO       ## current (roll, pitch) aim, radians
	var radius_rad := 0.26
	var inside := false
	var hold_frac := 0.0

	func _draw() -> void:
		var c := size * 0.5
		var r := radius_rad * PX_PER_RAD
		draw_circle(c, r, Color(0.05, 0.09, 0.18, 0.35))
		draw_arc(c, r, 0.0, TAU, 64, Color(0.55, 0.75, 1.0, 0.8), 3.0)
		draw_line(c - Vector2(r * 0.5, 0), c + Vector2(r * 0.5, 0),
			Color(0.55, 0.75, 1.0, 0.5), 2.0)
		draw_line(c - Vector2(0, r * 0.5), c + Vector2(0, r * 0.5),
			Color(0.55, 0.75, 1.0, 0.5), 2.0)
		if hold_frac > 0.0:
			draw_arc(c, r + 12.0, -PI * 0.5,
				-PI * 0.5 + TAU * clampf(hold_frac, 0.0, 1.0),
				48, Color(0.4, 1.0, 0.55, 0.95), 6.0)
		var dot := c + Vector2(off.x, -off.y) * PX_PER_RAD
		dot = c + (dot - c).limit_length(r * 1.35)
		draw_circle(dot, 12.0,
			Color(0.4, 1.0, 0.55) if inside else Color(1.0, 0.75, 0.3))

## Animated landscape phone outline for the tilt/surge tutorial — shows the
## player which way to tip or lift/lower the device for the current step.
## Outline: yellow (coach) → green (listening / got it).
class PhoneTiltHint:
	extends Control
	var axis: int = 0       ## 0 = roll, 1 = pitch, 2 = surge (lift/lower)
	var dir: float = 1.0    ## +1 right/up/lift, −1 left/down/lower
	var status: String = "yellow"    ## yellow | green (red unused)
	var animate_motion: bool = true
	var _t: float = 0.0

	func set_step(a: int, d: float) -> void:
		axis = a
		dir = d
		status = "yellow"
		animate_motion = true
		_t = 0.0
		queue_redraw()

	func set_surge(d: float, _mode: String = "hold") -> void:
		axis = 2
		dir = d
		_t = 0.0
		queue_redraw()

	func set_status(s: String) -> void:
		if status == s:
			return
		status = s
		queue_redraw()

	func set_animate(on: bool) -> void:
		if animate_motion == on:
			return
		animate_motion = on
		if on:
			_t = 0.0
		queue_redraw()

	func _process(delta: float) -> void:
		if not visible:
			return
		if animate_motion:
			_t += delta
		queue_redraw()

	func _outline_color() -> Color:
		match status:
			"red":
				return Color(1.0, 0.28, 0.28, 0.98)
			"green":
				return Color(0.32, 0.95, 0.42, 0.98)
			_:
				return Color(0.95, 0.88, 0.45, 0.95)

	## Pulse out and back — same coaching feel as tilt (not a capture pose).
	func _motion_amount() -> float:
		var pulse: float = 0.0
		if animate_motion:
			pulse = 0.5 + 0.5 * sin(_t * 2.6)
		return pulse * dir

	func _draw() -> void:
		var c := size * 0.5
		var amount: float = _motion_amount()
		var roll: float = amount * deg_to_rad(32.0) if axis == 0 else 0.0
		var pitch: float = amount * 0.55 if axis == 1 else 0.0
		var depth: float = amount * 0.85 if axis == 2 else 0.0
		var pulse_vis: float = absf(amount)

		# Phone body in local space (landscape).
		var pw := 150.0
		var ph := 88.0
		var pts := PackedVector2Array([
			Vector2(-pw * 0.5, -ph * 0.5),
			Vector2(pw * 0.5, -ph * 0.5),
			Vector2(pw * 0.5, ph * 0.5),
			Vector2(-pw * 0.5, ph * 0.5),
		])
		# Pitch / surge: foreshorten + scale so lift grows; screen-Y up for lift.
		var top_s: float = 1.0 - 0.35 * pitch - 0.18 * depth
		var bot_s: float = 1.0 + 0.20 * pitch + 0.12 * depth
		var y_shift: float = -22.0 * pitch - 20.0 * depth
		var scale: float = 1.0 + 0.22 * depth
		for i in 4:
			var p: Vector2 = pts[i]
			var sx: float = top_s if p.y < 0.0 else bot_s
			p = Vector2(p.x * sx * scale, (p.y + y_shift) * scale)
			var ca := cos(roll)
			var sa := sin(roll)
			pts[i] = c + Vector2(p.x * ca - p.y * sa, p.x * sa + p.y * ca)

		var fill := Color(0.12, 0.18, 0.32, 0.92)
		var edge := _outline_color()
		draw_colored_polygon(pts, fill)
		for i in 4:
			draw_line(pts[i], pts[(i + 1) % 4], edge, 4.0, true)
		var inset := 0.78
		var mid := (pts[0] + pts[1] + pts[2] + pts[3]) * 0.25
		var screen := PackedVector2Array()
		for i in 4:
			screen.append(mid + (pts[i] - mid) * inset)
		draw_colored_polygon(screen, Color(0.35, 0.55, 0.85, 0.55))
		var top_m: Vector2 = (pts[0] + pts[1]) * 0.5
		draw_circle(top_m + (mid - top_m).normalized() * 10.0, 5.0,
			Color(0.2, 0.25, 0.35, 0.9))
		# Chevron while coaching motion is animating.
		if not animate_motion and axis == 2:
			return
		var tip: Vector2
		if axis == 0:
			tip = c + Vector2(dir * 105.0, 0.0)
		elif axis == 1:
			tip = c + Vector2(0.0, -dir * 70.0)
		else:
			# Match pitch: +dir (lift) = screen up (−Y).
			tip = c + Vector2(0.0, -dir * 78.0)
		var col := Color(edge.r, edge.g, edge.b, 0.55 + 0.45 * clampf(pulse_vis, 0.35, 1.0))
		if axis == 0:
			var base := tip - Vector2(dir * 28.0, 0.0)
			draw_line(base, tip, col, 4.0, true)
			draw_line(tip, tip + Vector2(-dir * 14.0, -10.0), col, 4.0, true)
			draw_line(tip, tip + Vector2(-dir * 14.0, 10.0), col, 4.0, true)
		elif axis == 1:
			var base2 := tip + Vector2(0.0, dir * 28.0)
			draw_line(base2, tip, col, 4.0, true)
			draw_line(tip, tip + Vector2(-10.0, dir * 14.0), col, 4.0, true)
			draw_line(tip, tip + Vector2(10.0, dir * 14.0), col, 4.0, true)
		else:
			var base3 := tip + Vector2(0.0, dir * 28.0)
			draw_line(base3, tip, col, 4.0, true)
			draw_line(tip, tip + Vector2(-10.0, dir * 14.0), col, 4.0, true)
			draw_line(tip, tip + Vector2(10.0, dir * 14.0), col, 4.0, true)

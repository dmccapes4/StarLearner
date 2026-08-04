class_name PlaygroundScene
extends Control
## Mode 3 — 3D FLIGHT PLAYGROUND. A fun mini solar system with relative-sized
## planets and simplified dynamics. The player IS the pilot:
##   · EVERY LAUNCH: pick speed mode (7 gears vs cruise/stop), full tilt+surge
##     tutorial (no saved controls), aim gate, then fly
##   · tilt to steer; optional gentle pull/push (slow / cruise / fast);
##     jerk-push stops, jerk-pull resumes cruise — no microphone
##   · the ship stays near the planetary plane — drift too high or low and
##     it gently steers back (with a cooldown so the nudge isn't spammy)
##   · fly right AT a world (head-on, close) → orbit cinematic
##   · tap a planet → pause tile; tap tile to travel, elsewhere to resume


const OrbitCinematic := preload("res://scripts/OrbitCinematic.gd")
const SpeedModeChooser := preload("res://scripts/SpeedModeChooser.gd")

signal arrived(dest_id: String)
signal go_home()
signal learn_more(dest_id: String)

const SPACING := 1.6           ## orbit_r multiplier — roomy, not adjacent
const SPEED := 26.0            ## cruise / step 4 / jerk-pull resume
const SPEED_MIN := 0.0
const TURN_RATE := 1.4         ## rad/s at full tilt
const PITCH_RATE := 0.9
const Y_MAX := 34.0            ## hard band above/below the planetary plane
const Y_SOFT := 24.0           ## start steering back past this height
const Y_CLEAR := 16.0          ## must return inside here to clear band warn
const BAND_COOLDOWN_S := 10.0  ## don't re-narrate the band every bounce
const ORBIT_SPEED := 0.3
const TAP_RADIUS_PX := 52.0
const TIME_SCALE := 0.22       ## planets drift slowly — easy targets

## ── Tilt steering (calibrated, angle-based) ────────────────────────
const CAL_TIME_S := 0.6
const TILT_FULL_RAD := 0.30
const TILT_DEAD_RAD := 0.035
const TILT_LP_TAU_S := 0.12

## ── Surge speed: calibrated jerks ──────────────────────────────────
## Speed gears (5): jerk pull +1 / jerk push −1 (incl. stop at 0).
## Cruise/stop: jerk pull → cruise, jerk push → stop.
## No mic — LE keeps RECORD_AUDIO.
const SURGE_DEAD := 0.30
const SURGE_ARM_DEFAULT := 0.70
const SURGE_JERK_DEFAULT := 3.8
const SURGE_ARM_MIN := 0.45
const SURGE_ARM_MAX := 1.40
const SURGE_JERK_MIN := 1.35
const SURGE_JERK_MIN_CRUISE := 1.35
const SURGE_JERK_CD_S := 0.55
const SURGE_LP_TAU_S := 0.05
const SURGE_PITCH_HOLD_S := 0.35
const SURGE_QUIET_S := 0.35
const SURGE_QUIET_EPS := 0.18
const SURGE_POST_NEUTRAL_S := 0.35
const SURGE_CAL_FRAC := 0.34
const SURGE_JERK_FRAC := 0.42
const TUT_SURGE_MIN := 0.50
const TUT_SURGE_JERK_MIN := 1.25
const TUT_SURGE_WIN_S := 2.0
const TUT_SURGE_POSE_S := 0.55
const TUT_SURGE_OK_S := 0.45
## 0 = stop; 1..5 = five flying gears (3 = cruise / launch default)
const SPEED_STEP_STOP := 0
const SPEED_STEP_MIN := 1
const SPEED_STEP_CRUISE := 3
const SPEED_STEP_MAX := 5
const SPEED_BLEND_S := 1.2
## Multipliers vs SPEED for gears 1..5.
const SPEED_STEP_MULT: Array = [0.40, 0.65, 1.0, 1.35, 1.75]
const SPEED_MAX_JOY := SPEED * 1.75

## ── Joystick latch: pull→fixed accel, push→fixed decel ─────────────
## Onset latches a fixed rate. Settle spikes never flip the command.
## After one quiet sample in-drive, a return spike = backoff; steady
## quiet then clears to neutral. Quiet alone while "holding" keeps latch.
const JOY_ACCEL_QUIET := 0.40
const JOY_NEUTRAL_HOLD_S := 0.45   ## steady rest after return (cal + flight)
const JOY_PEAK_SETTLE_S := 0.22    ## brief quiet after shove onset
const JOY_RETURN_HOLD_S := 0.50    ## cal: hold still at rest after return
const JOY_RETURN_MIN := 0.45       ## must see opposite shove before rest counts
const JOY_EXTREME_MIN := 0.55
const JOY_BAND_FRAC := 0.12
const JOY_BAND_MIN := 0.22
const JOY_EXT_CAP := 2.8
const JOY_RATE := 12.0
const JOY_ENGAGE_FRAC := 0.38
const JOY_ENGAGE_MIN := 0.50
const JOY_SETTLE_IGN_S := 0.65    ## ignore settle brake after engage
const JOY_BACKOFF_FRAC := 0.55    ## fraction of cal return spike
const JOY_BACKOFF_MIN := 0.70     ## hold-noise must not cancel latch
const JOY_LAUNCH_GUARD_S := 0.55  ## ignore engage right after launch
const JOY_BACKOFF_HOLD_S := 0.08  ## opposite must persist briefly
const JOY_DESKTOP_SCALE := 0.55
const JOY_TEL_S := 0.40
const JOY_VEL_TAU_S := 0.45
const JOY_VEL_QUIET := 0.25

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
const LINE_TILE := "Tap the picture to travel there, or tap anywhere else to keep flying."
const LINE_TUT_RIGHT := "Let's learn to steer! Tilt the phone to the right, like turning a wheel."
const LINE_TUT_LEFT := "Great! Now tilt it to the left."
const LINE_TUT_UP := "Now point the phone up, to climb."
const LINE_TUT_DOWN := "And point it down, to dive."
const LINE_TUT_SURGE_INTRO := "Five speed gears. A quick pull goes one gear faster; a quick push goes one gear slower. Push again at the bottom to stop."
const LINE_TUT_SURGE_INTRO_CRUISE := "Speed is just jerks. A quick shove forward stops; a quick pull toward you resumes cruise."
const LINE_TUT_JERK_STOP := "Quick shove forward during the capture."
const LINE_TUT_JERK_GO := "Quick pull toward you during the capture."
const LINE_TUT_GO_PULL := "Pull."
const LINE_TUT_GO_PUSH := "Push."
const LINE_AIM := "Now aim the phone straight ahead and hold it steady. Get ready to launch!"
const LINE_STOP := "Holding position."
const LINE_RESUME := "Cruising!"
const LINE_MIN := "You are at minimum velocity."
const LINE_CRUISE_SPEED := "You are at cruising speed."
const LINE_MAX := "You are at maximum velocity."
const LINE_ALREADY_MAX := "You are already at maximum velocity."
const LINE_ALREADY_STOP := "You are already stopped."
const LINE_FASTER := "Faster."
const LINE_SLOWER := "Slower."
const LINE_READY := "Ready — jerk to change speed."
const LINE_TUT_SURGE_INTRO_JOY := "Speed joystick. Pull latches acceleration; push latches deceleration. Return to rest to cancel."
const LINE_TUT_JOY_NEUTRAL := "Hold still."
const LINE_TUT_JOY_PUSH := "Push forward."
const LINE_TUT_JOY_PULL := "Pull toward you."
const LINE_TUT_JOY_RETURN := "Now move back to rest, then hold still."
const LINE_TUT_GOT_IT := "Got it."
const LINE_JOY_READY := "Ready — pull holds acceleration, push holds deceleration. Return to rest to cancel."

## Both jerk modes + joystick distance experiment.
const TUT_STEPS_GEARS: Array = [
	{"kind": "tilt", "axis": 0, "dir": 1.0, "learn": true, "arrow": "→",
		"hint": "Tilt RIGHT", "line": LINE_TUT_RIGHT},
	{"kind": "tilt", "axis": 0, "dir": -1.0, "learn": false, "arrow": "←",
		"hint": "Tilt LEFT", "line": LINE_TUT_LEFT},
	{"kind": "tilt", "axis": 1, "dir": 1.0, "learn": true, "arrow": "↑",
		"hint": "Point UP", "line": LINE_TUT_UP},
	{"kind": "tilt", "axis": 1, "dir": -1.0, "learn": false, "arrow": "↓",
		"hint": "Point DOWN", "line": LINE_TUT_DOWN},
	{"kind": "surge", "dir": 1.0, "mode": "jerk", "learn": true, "arrow": "▶",
		"hint": "Quick PULL — faster", "line": LINE_TUT_JERK_GO,
		"go": LINE_TUT_GO_PULL},
	{"kind": "surge", "dir": -1.0, "mode": "jerk", "learn": false, "arrow": "⏹",
		"hint": "Quick PUSH — slower", "line": LINE_TUT_JERK_STOP,
		"go": LINE_TUT_GO_PUSH},
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
	{"kind": "surge", "dir": 1.0, "mode": "jerk", "learn": true, "arrow": "▶",
		"hint": "Quick PULL — cruise", "line": LINE_TUT_JERK_GO,
		"go": LINE_TUT_GO_PULL},
	{"kind": "surge", "dir": -1.0, "mode": "jerk", "learn": false, "arrow": "⏹",
		"hint": "Quick PUSH — stop", "line": LINE_TUT_JERK_STOP,
		"go": LINE_TUT_GO_PUSH},
]

const TUT_STEPS_JOY: Array = [
	{"kind": "tilt", "axis": 0, "dir": 1.0, "learn": true, "arrow": "→",
		"hint": "Tilt RIGHT", "line": LINE_TUT_RIGHT},
	{"kind": "tilt", "axis": 0, "dir": -1.0, "learn": false, "arrow": "←",
		"hint": "Tilt LEFT", "line": LINE_TUT_LEFT},
	{"kind": "tilt", "axis": 1, "dir": 1.0, "learn": true, "arrow": "↑",
		"hint": "Point UP", "line": LINE_TUT_UP},
	{"kind": "tilt", "axis": 1, "dir": -1.0, "learn": false, "arrow": "↓",
		"hint": "Point DOWN", "line": LINE_TUT_DOWN},
	{"kind": "surge", "dir": 0.0, "mode": "joy_neutral", "learn": false, "arrow": "•",
		"hint": "1 · Hold still", "line": LINE_TUT_JOY_NEUTRAL,
		"go": LINE_TUT_JOY_NEUTRAL},
	{"kind": "surge", "dir": -1.0, "mode": "joy_push", "learn": true, "arrow": "↪",
		"hint": "2 · Push, then back to rest", "line": LINE_TUT_JOY_PUSH,
		"go": LINE_TUT_JOY_PUSH},
	{"kind": "surge", "dir": 1.0, "mode": "joy_pull", "learn": false, "arrow": "↩",
		"hint": "4 · Pull, then back to rest", "line": LINE_TUT_JOY_PULL,
		"go": LINE_TUT_JOY_PULL},
]

enum State { SPEED_PICK, TUTORIAL, AIM_GATE, FLYING, PAUSED_TILE, ORBITING }

var _cfg: SolarFlyerConfig
var _viewport: SubViewport
var _host: SubViewportContainer
var _world: Node3D
var _cam: Camera3D
var _bodies: Dictionary = {}     ## id → {root, mesh, icon, data, hero}
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
var _sz: float = 1.0     ## surge sign: + = pull-toward-self is positive
var _flip: float = 1.0   ## −1 when the sensor frame is 180° from the screen
var _speed_gears: bool = true  ## false = cruise/stop jerks only
var _speed_joy: bool = false   ## experimental distance-from-neutral throttle
var _tut_steps: Array = []
var _tut_i: int = 0
var _tut_ref: Vector2 = Vector2.ZERO
var _tut_ref_sum: Vector2 = Vector2.ZERO
var _tut_ref_t: float = 0.0
var _tut_hold: float = 0.0
var _tut_onset_locked: bool = false
var _gate_hold: float = 0.0
var _gate_sum: Vector2 = Vector2.ZERO
var _no_sensor_frames: int = 0
var _capture_grace: float = 0.0
var _last_tilt: Vector2 = Vector2.ZERO
var _raw_tilt_y: float = 0.0   ## pitch before surge suppress — prioritizes climb/dive
var _last_surge: float = 0.0   ## signed delta vs neutral (pull = +)
var _surge_filt: float = 0.0   ## raw depth linear accel (pre-_sz)
var _surge_neutral: float = 0.0  ## rest baseline; reset after each capture CD
var _surge_pulse_peak: float = 0.0  ## legacy peak (cruise jerk path)
var _surge_pulse_dir: float = 0.0
var _surge_pulse_armed: bool = false
var _surge_hold_t: float = 0.0
var _surge_release_t: float = 0.0
var _surge_pitch_cd: float = 0.0
var _surge_capture_cd: float = 0.0  ## unused long backoff; kept for telem
var _surge_need_recenter: bool = true
var _surge_quiet_t: float = 0.0
var _surge_prev_filt: float = 0.0
var _surge_post_neutral: float = 0.0
var _surge_announce_ready: bool = false
var _surge_await_rest: bool = false
var _surge_win_active: bool = false  ## gears: capturing a 2s window
var _surge_win_t: float = 0.0
var _surge_win_pos: float = 0.0   ## max +surge in window
var _surge_win_neg: float = 0.0   ## max |−surge| in window
## Joystick distance estimate (integrated lin-Z, meters-ish).
var _surge_vel: float = 0.0
var _surge_disp: float = 0.0      ## signed: pull + after _sz
var _surge_stick: float = 0.0     ## −1..+1 after deadband / extents
var _joy_band: float = JOY_BAND_MIN
var _joy_push_ext: float = 1.2    ## |accel| at full push
var _joy_pull_ext: float = 1.2
var _joy_quiet_t: float = 0.0
var _joy_cal_sum: float = 0.0
var _joy_cal_sum2: float = 0.0
var _joy_cal_t: float = 0.0
var _joy_peak: float = 0.0        ## signed accel peak during joy throw
var _joy_phase: String = ""       ## throw|settle during joy push/pull
var _joy_tel_t: float = 0.0
var _joy_drive: float = 0.0       ## +1 accel latch, −1 decel, 0 neutral
var _joy_drive_t: float = 0.0
var _joy_backoff: bool = false
var _joy_seen_quiet: bool = false ## quiet once in-drive → arm backoff detect
var _joy_quiet_hold: float = 0.0
var _joy_engage: float = JOY_ENGAGE_MIN
var _joy_backoff_thr: float = JOY_BACKOFF_MIN
var _joy_launch_guard: float = 0.0
var _joy_opp_t: float = 0.0       ## time opposite surge above backoff thr
## QA / CI: when true, joy flight reads `_last_surge` only and skips the
## desktop Shift+arrow shim (no accelerometer in headless suites).
var _joy_use_surge_only: bool = false
var _tut_push_return: float = 0.0
var _tut_pull_return: float = 0.0
var _joy_return_peak: float = 0.0   ## opposite spike during cal return
var _surge_arm: float = SURGE_ARM_DEFAULT
var _surge_jerk: float = SURGE_JERK_DEFAULT
var _tut_surge_peak: float = 0.0
var _tut_pull_peak: float = 0.0
var _tut_push_peak: float = 0.0
var _tut_pull_raw: float = 0.0
var _tut_push_raw: float = 0.0
var _tut_jerk_peak: float = 0.0
## surge tutorial: pose → capture → success
var _tut_surge_phase: String = "pose"
var _tut_surge_phase_t: float = 0.0
var _tut_surge_idle_sum: float = 0.0
var _tut_surge_intro_done: bool = false
var _tut_win_pos: float = 0.0
var _tut_win_neg: float = 0.0
var _jerk_cd: float = 0.0
var _tel_t: float = 0.0
var _orbit_id: String = ""
var _orbit_ang: float = 0.0
var _tile_id: String = ""
var _active: bool = false
var _cine: OrbitCinematic
var _sun_light: OmniLight3D
var _hint: Label
var _speed_bar: SpeedBar
var _home_btn: Button
var _reticle: AimReticle
var _tut_arrow: Label
var _tut_phone: PhoneTiltHint
var _speed_pick: SpeedModeChooser
var _tile: Control
var _tile_pic: TextureRect
var _tile_name: Label
var _arrival_title: Label
var _arrival: Control

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
	_surge_pulse_peak = 0.0
	_surge_pulse_dir = 0.0
	_surge_pulse_armed = false
	_surge_hold_t = 0.0
	_surge_release_t = 0.0
	_surge_pitch_cd = 0.0
	_surge_capture_cd = 0.0
	_surge_need_recenter = true
	_surge_quiet_t = 0.0
	_surge_prev_filt = 0.0
	_surge_post_neutral = 0.0
	_surge_announce_ready = false
	_surge_await_rest = false
	_surge_win_active = false
	_surge_win_t = 0.0
	_surge_win_pos = 0.0
	_surge_win_neg = 0.0
	_surge_arm = SURGE_ARM_DEFAULT
	_surge_jerk = SURGE_JERK_DEFAULT
	_tut_surge_peak = 0.0
	_tut_pull_peak = 0.0
	_tut_push_peak = 0.0
	_tut_push_return = 0.0
	_tut_pull_return = 0.0
	_joy_return_peak = 0.0
	_tut_pull_raw = 0.0
	_tut_push_raw = 0.0
	_tut_jerk_peak = 0.0
	_tut_onset_locked = false
	_tut_surge_phase = "pose"
	_tut_surge_phase_t = 0.0
	_tut_surge_idle_sum = 0.0
	_tut_surge_intro_done = false
	_tut_win_pos = 0.0
	_tut_win_neg = 0.0
	_speed_gears = true
	_speed_joy = false
	_surge_vel = 0.0
	_surge_disp = 0.0
	_surge_stick = 0.0
	_joy_band = JOY_BAND_MIN
	_joy_push_ext = 0.25
	_joy_pull_ext = 0.25
	_joy_quiet_t = 0.0
	_joy_cal_sum = 0.0
	_joy_cal_sum2 = 0.0
	_joy_cal_t = 0.0
	_joy_peak = 0.0
	_joy_phase = ""
	_joy_drive = 0.0
	_joy_drive_t = 0.0
	_joy_backoff = false
	_joy_seen_quiet = false
	_joy_quiet_hold = 0.0
	_joy_engage = JOY_ENGAGE_MIN
	_joy_backoff_thr = JOY_BACKOFF_MIN
	_joy_launch_guard = 0.0
	_joy_opp_t = 0.0
	_joy_use_surge_only = false
	_tut_push_return = 0.0
	_tut_pull_return = 0.0
	_joy_return_peak = 0.0
	_tut_steps = []
	_tile.visible = false
	_arrival.visible = false
	if _speed_pick != null:
		_speed_pick.visible = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var body := SolarData.flyer_body_by_id(start_at, _cfg)
	var p := _body_playground_pos(body, 0.0)
	var hero: float = float(body.get("hero_r", 2.0))
	# Start well outside orbit capture, home world ahead but off center.
	_ship_pos = p + Vector3(0, 2.0, OrbitMath.orbit_standoff(hero) * 3.5)
	# Level look toward the home world — never into empty space below.
	_look_at_body(start_at)
	_recalibrate()
	_place_bodies()
	_apply_cam()
	_tel_event("begin at=%s pos=(%.1f,%.1f,%.1f)" % [
		start_at, _ship_pos.x, _ship_pos.y, _ship_pos.z])
	# No saved controls — every Free Flight launch picks mode + tutorials.
	_enter_speed_pick()

func _enter_speed_pick() -> void:
	_state = State.SPEED_PICK
	_reticle.visible = false
	_tut_arrow.visible = false
	_tut_phone.visible = false
	_hint.text = "Choose how to control speed"
	if _speed_bar != null:
		_speed_bar.visible = false
	_speed_pick.set_active(true)
	_tel_event("speed pick enter")

func _on_speed_gears() -> void:
	_speed_gears = true
	_speed_joy = false
	_speed_pick.set_active(false)
	_tel_event("speed mode=gears")
	_enter_tutorial()

func _on_speed_cruise_stop() -> void:
	_speed_gears = false
	_speed_joy = false
	_speed_pick.set_active(false)
	_tel_event("speed mode=cruise_stop")
	_enter_tutorial()

func _on_speed_joystick() -> void:
	_speed_gears = false
	_speed_joy = true
	_speed_pick.set_active(false)
	_tel_event("speed mode=joystick")
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
	## After a video or an orbit stay — back to the stick.
	_arrival.visible = false
	_tile.visible = false
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
	_enter_gate()
	_tel_event("resume pos=(%.1f,%.1f,%.1f)" % [
		_ship_pos.x, _ship_pos.y, _ship_pos.z])

func _process(delta: float) -> void:
	if not _active:
		return
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
			_jerk_cd = maxf(0.0, _jerk_cd - delta)
			_surge_pitch_cd = maxf(0.0, _surge_pitch_cd - delta)
			_surge_capture_cd = maxf(0.0, _surge_capture_cd - delta)
			_surge_post_neutral = maxf(0.0, _surge_post_neutral - delta)
			# Sample surge first so steering can ignore pitch during a shove.
			_surge_sample(delta)
			_steer(delta)
			_speed_from_surge(delta)
			_fly(delta)
			_check_capture()
			_telemetry(delta)
		State.ORBITING:
			_clock += delta * TIME_SCALE * 0.4
			_orbit_ang += delta * ORBIT_SPEED
			_place_orbit_cam()
		State.PAUSED_TILE:
			pass   # world frozen under the tile
	_place_bodies()
	_update_markers()

## Tilt steering: gravity vector when the device reports one, arrow keys as
## the desktop fallback. Landscape phone: roll (x) yaws, pitch (y) climbs.
## All tilts are DELTAS from the calibrated neutral pose.
## Push/pull for speed rocks the gravity estimate — ignore pitch (and mute
## the planetary-plane VO) while a surge gesture is active.
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
	# Tip up/down for climb/dive must win over soft Z spikes from the same tip.
	# Only freeze pitch when a real surge hold/jerk is active (or a strong
	# shove without much pitch).
	var pitching: bool = absf(_raw_tilt_y) > 0.28
	var surge_motion: bool = (
		_surge_pulse_armed
		or _jerk_cd > 0.0
		or (_speed_joy and absf(_joy_drive) > 0.5 and not pitching)
		or (absf(_last_surge) > _surge_arm and not pitching and not _speed_joy))
	if surge_motion:
		_surge_pitch_cd = SURGE_PITCH_HOLD_S
	var surge_busy: bool = surge_motion or (_surge_pitch_cd > 0.0 and not pitching)
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

## Linear accel along screen depth. Filtered Z is kept raw; signed delta vs
## neutral is jerk logic (pull = + after _sz). Joystick mode also integrates
## that accel into a displacement estimate (_surge_disp).
func _surge_sample(delta: float) -> float:
	var raw := Input.get_accelerometer()
	if raw.length() < 0.5:
		# Desktop: Shift+Up pull (faster), Shift+Down push (slower).
		var key := 0.0
		if Input.is_key_pressed(KEY_SHIFT):
			key = Input.get_axis("ui_down", "ui_up") * 6.0
		_surge_filt = key
		_last_surge = _sz * (_surge_filt - _surge_neutral)
		_surge_update_disp(delta)
		return _last_surge
	_gravity_filtered(delta)
	var lin: Vector3 = raw - _g_filt
	var z: float = lin.z
	var alpha: float = 1.0 - exp(-delta / SURGE_LP_TAU_S)
	_surge_filt = lerpf(_surge_filt, z, alpha)
	_last_surge = _sz * (_surge_filt - _surge_neutral)
	_surge_update_disp(delta)
	return _last_surge

## Disp telem only; stick mirrors latch drive for UI.
func _surge_update_disp(delta: float) -> void:
	var a: float = _last_surge
	_surge_vel += a * delta
	_surge_vel *= exp(-delta / JOY_VEL_TAU_S)
	_surge_disp += _surge_vel * delta
	var quiet: bool = absf(a) <= JOY_ACCEL_QUIET and absf(_surge_vel) <= JOY_VEL_QUIET
	if quiet and absf(_surge_disp) <= maxf(_joy_band, 0.08):
		_joy_quiet_t += delta
		if _joy_quiet_t >= SURGE_QUIET_S:
			_surge_disp = 0.0
			_surge_vel = 0.0
	else:
		_joy_quiet_t = 0.0
	if _speed_joy:
		_surge_stick = _joy_drive

func _joy_reset_disp() -> void:
	_surge_vel = 0.0
	_surge_disp = 0.0
	_surge_stick = 0.0
	_joy_quiet_t = 0.0

func _recenter_surge_neutral() -> void:
	_surge_neutral = _surge_filt
	_surge_pulse_peak = 0.0
	_surge_pulse_dir = 0.0
	_surge_pulse_armed = false
	_surge_release_t = 0.0
	_surge_quiet_t = 0.0
	_surge_prev_filt = _surge_filt
	_surge_post_neutral = SURGE_POST_NEUTRAL_S
	_last_surge = 0.0
	_joy_reset_disp()
	_tel_event("surge neutral=%.2f" % _surge_neutral)
	if _surge_announce_ready:
		_surge_announce_ready = false
		Narrator.speak(LINE_JOY_READY if _speed_joy else LINE_READY)

func _apply_surge_thresholds(pull_peak: float, push_peak: float) -> void:
	# Both modes: thresholds from tutorial jerks only.
	var pull_a: float = absf(pull_peak)
	var push_a: float = absf(push_peak)
	var soft_ref: float = 0.0
	if pull_a > 0.05 and push_a > 0.05:
		soft_ref = minf(pull_a, push_a)
	else:
		soft_ref = maxf(pull_a, push_a)
	var jpk: float = maxf(_tut_jerk_peak, soft_ref)
	if jpk < 0.05:
		jpk = SURGE_JERK_DEFAULT
	_surge_arm = clampf(jpk * 0.22, 0.40, 0.85)
	var jmin: float = SURGE_JERK_MIN if _speed_gears else SURGE_JERK_MIN_CRUISE
	_surge_jerk = clampf(
		maxf(jmin, jpk * SURGE_JERK_FRAC),
		_surge_arm + 0.45,
		3.8)
	_tel_event("surge cal arm=%.2f jerk=%.2f soft=%.2f pull=%.2f push=%.2f jerkpk=%.2f sz=%.0f gears=%d" % [
		_surge_arm, _surge_jerk, soft_ref, pull_peak, push_peak, _tut_jerk_peak, _sz,
		1 if _speed_gears else 0])

## Pull → faster (+1 gear or resume cruise); push → slower (−1 gear or stop).
## Peak jerks only — no soft gesture path.
func _surge_clear_pulse(await_rest: bool = false) -> void:
	_surge_pulse_peak = 0.0
	_surge_pulse_dir = 0.0
	_surge_pulse_armed = false
	_surge_hold_t = 0.0
	_surge_release_t = 0.0
	_surge_win_t = 0.0
	_surge_win_pos = 0.0
	_surge_win_neg = 0.0
	_surge_win_active = false
	if await_rest:
		_surge_await_rest = true

func _surge_input_blocked() -> bool:
	return _speed_blending \
		or _surge_need_recenter \
		or _surge_post_neutral > 0.0 \
		or _jerk_cd > 0.0

func _speed_from_surge(delta: float) -> void:
	_tick_speed_blend(delta)
	if _speed_joy:
		_speed_from_joy(delta)
		return
	var s: float = _last_surge
	var a: float = absf(s)
	if _surge_input_blocked():
		_surge_clear_pulse(true)
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
	if _surge_await_rest:
		_surge_clear_pulse(false)
		if a > SURGE_DEAD:
			return
		_surge_await_rest = false
	# Tip up/down: ignore weak Z while climbing/diving.
	if absf(_raw_tilt_y) > 0.42 and a < _surge_arm * 0.85 \
			and not _surge_pulse_armed:
		_surge_clear_pulse(false)
		return
	# Peak jerks for both modes. Lock onset direction — settle/brake must
	# not steal the gesture (that flipped gears the wrong way).
	if a >= _surge_arm:
		if not _surge_pulse_armed:
			_surge_pulse_armed = true
			_surge_pulse_dir = signf(s)
			_surge_pulse_peak = a
		elif signf(s) == _surge_pulse_dir:
			if a > _surge_pulse_peak:
				_surge_pulse_peak = a
		# opposite half ignored
		if _jerk_cd <= 0.0 and _surge_pulse_peak >= _surge_jerk:
			_fire_surge_jerk(_surge_pulse_dir)
		return
	if _surge_pulse_armed:
		if _jerk_cd <= 0.0 and _surge_pulse_peak >= _surge_jerk:
			var jd: float = _surge_pulse_dir
			_surge_clear_pulse(true)
			_fire_surge_jerk(jd)
		else:
			_surge_clear_pulse(true)

func _speed_from_joy(delta: float) -> void:
	## Pull onset → ACCEL latch (fixed rate) until deliberate return.
	## Push onset → DECEL latch until deliberate return.
	## Holding still keeps the latch. Quiet alone never clears to READY.
	## Return never flips to the opposite command.
	if _joy_launch_guard > 0.0:
		_joy_launch_guard = maxf(0.0, _joy_launch_guard - delta)
	if _surge_post_neutral > 0.0:
		_update_speed_hint()
		return
	var a: float = _last_surge
	var quiet: bool = absf(a) <= JOY_ACCEL_QUIET
	# Desktop: hold Shift+Up/Down; release = backoff.
	# Suites set `_joy_use_surge_only` to exercise the phone accel path.
	var raw := Input.get_accelerometer()
	if raw.length() < 0.5 and not _joy_use_surge_only:
		var key := 0.0
		if Input.is_key_pressed(KEY_SHIFT):
			key = Input.get_axis("ui_down", "ui_up")
		if key > 0.2:
			if _joy_drive <= 0.0:
				_joy_engage_drive(1.0)
			_joy_backoff = false
			_joy_opp_t = 0.0
			_joy_quiet_hold = 0.0
		elif key < -0.2:
			if _joy_drive >= 0.0:
				_joy_engage_drive(-1.0)
			_joy_backoff = false
			_joy_opp_t = 0.0
			_joy_quiet_hold = 0.0
		elif absf(_joy_drive) > 0.5:
			_joy_backoff = true
	if absf(_joy_drive) < 0.5:
		_joy_quiet_hold = 0.0
		_joy_opp_t = 0.0
		if _joy_launch_guard <= 0.0 and absf(a) >= _joy_engage:
			_joy_engage_drive(signf(a))
	else:
		_joy_drive_t += delta
		# Constant rate while latched; freeze only after backoff registered.
		if not _joy_backoff:
			if _joy_drive > 0.0:
				_speed = minf(_speed + JOY_RATE * delta, SPEED_MAX_JOY)
			else:
				_speed = maxf(_speed - JOY_RATE * delta, SPEED_MIN)
			# Deliberate return: strong opposite after settle window (not hold noise).
			if _joy_drive_t >= JOY_SETTLE_IGN_S \
					and a * _joy_drive < 0.0 and absf(a) >= _joy_backoff_thr:
				_joy_opp_t += delta
			else:
				_joy_opp_t = 0.0
			if _joy_opp_t >= JOY_BACKOFF_HOLD_S:
				_joy_backoff = true
				_joy_quiet_hold = 0.0
				_tel_event("joy backoff drive=%.0f a=%.2f thr=%.2f" % [
					_joy_drive, a, _joy_backoff_thr])
		else:
			# Backoff seen — freeze speed; steady quiet → READY.
			if quiet:
				_joy_quiet_hold += delta
			else:
				_joy_quiet_hold = maxf(0.0, _joy_quiet_hold - delta * 0.35)
			if _joy_quiet_hold >= JOY_NEUTRAL_HOLD_S:
				_tel_event("joy neutral was_drive=%.0f spd=%.1f" % [
					_joy_drive, _speed])
				_joy_clear_drive()
	_surge_stick = _joy_drive
	_update_speed_hint()

func _joy_engage_drive(dir: float) -> void:
	_joy_drive = signf(dir)
	_joy_drive_t = 0.0
	_joy_backoff = false
	_joy_seen_quiet = false
	_joy_quiet_hold = 0.0
	_joy_opp_t = 0.0
	_surge_stick = _joy_drive
	_tel_event("joy engage drive=%.0f a=%.2f eng=%.2f" % [
		_joy_drive, _last_surge, _joy_engage])

func _joy_clear_drive() -> void:
	_joy_drive = 0.0
	_joy_drive_t = 0.0
	_joy_backoff = false
	_joy_seen_quiet = false
	_joy_quiet_hold = 0.0
	_joy_opp_t = 0.0
	_surge_stick = 0.0

func _joy_sync_step_from_speed() -> void:
	## Gear modes only — joy uses continuous speed (no step jumps).
	if _speed_joy:
		return
	if _speed <= 0.05:
		_speed_step = SPEED_STEP_STOP
		return
	var best: int = SPEED_STEP_MIN
	var best_d: float = absf(_speed - _speed_for_step(SPEED_STEP_MIN))
	for s in range(SPEED_STEP_MIN, SPEED_STEP_MAX + 1):
		var d: float = absf(_speed - _speed_for_step(s))
		if d < best_d:
			best_d = d
			best = s
	_speed_step = best

func _apply_joy_extents(push_ext: float, pull_ext: float, band: float) -> void:
	_joy_push_ext = clampf(absf(push_ext), 0.70, JOY_EXT_CAP)
	_joy_pull_ext = clampf(absf(pull_ext), 0.70, JOY_EXT_CAP)
	if _joy_pull_ext < 0.70:
		_joy_pull_ext = _joy_push_ext
	if _joy_push_ext < 0.70:
		_joy_push_ext = _joy_pull_ext
	var soft: float = minf(_joy_push_ext, _joy_pull_ext)
	_joy_band = clampf(maxf(band * 0.85, soft * JOY_BAND_FRAC), JOY_BAND_MIN,
		minf(0.45, soft * 0.28))
	_joy_engage = clampf(soft * JOY_ENGAGE_FRAC, JOY_ENGAGE_MIN, soft * 0.55)
	var ret: float = 0.0
	if _tut_push_return > 0.05 and _tut_pull_return > 0.05:
		ret = minf(_tut_push_return, _tut_pull_return)
	else:
		ret = maxf(_tut_push_return, _tut_pull_return)
	if ret > 0.05:
		_joy_backoff_thr = clampf(ret * JOY_BACKOFF_FRAC, JOY_BACKOFF_MIN, soft * 0.85)
	else:
		_joy_backoff_thr = clampf(soft * 0.55, JOY_BACKOFF_MIN, soft * 0.85)
	_joy_clear_drive()
	_tel_event("joy cal push=%.3f pull=%.3f retP=%.2f retL=%.2f band=%.3f eng=%.2f back=%.2f sz=%.0f" % [
		_joy_push_ext, _joy_pull_ext, _tut_push_return, _tut_pull_return,
		_joy_band, _joy_engage, _joy_backoff_thr, _sz])

func _begin_speed_backoff() -> void:
	_surge_pitch_cd = SURGE_PITCH_HOLD_S
	_surge_capture_cd = 0.0
	_surge_need_recenter = false
	_surge_announce_ready = false
	_surge_clear_pulse(true)

func _fire_surge_jerk(dir: float) -> void:
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
		_tel_event("surge jerk_pull cruise step=%d" % _speed_step)
		Narrator.speak(LINE_RESUME)
	else:
		_apply_speed_step(SPEED_STEP_STOP, false)
		_tel_event("surge jerk_push stop")
		Narrator.speak(LINE_STOP)

func _fire_gear_jerk(dir: float) -> void:
	# Pull = +1 gear; push = −1 gear (0 = stop).
	if dir > 0.0:
		if _speed_step >= SPEED_STEP_MAX:
			_surge_await_rest = true
			Narrator.speak(LINE_ALREADY_MAX)
			_tel_event("surge already_max step=%d" % _speed_step)
			return
		_begin_speed_backoff()
		var prev_up: int = _speed_step
		_apply_speed_step(_speed_step + 1, true)
		_narrate_speed_change(prev_up, _speed_step)
		_tel_event("surge gear %d→%d pull" % [prev_up, _speed_step])
		return
	if _speed_step <= SPEED_STEP_STOP:
		_surge_await_rest = true
		Narrator.speak(LINE_ALREADY_STOP)
		_tel_event("surge already_stop")
		return
	_begin_speed_backoff()
	var prev_dn: int = _speed_step
	_apply_speed_step(_speed_step - 1, true)
	_narrate_speed_change(prev_dn, _speed_step)
	_tel_event("surge gear %d→%d push" % [prev_dn, _speed_step])

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
	elif step >= SPEED_STEP_MAX:
		Narrator.speak(LINE_MAX)
	elif step == SPEED_STEP_MIN:
		Narrator.speak(LINE_MIN)
	elif step == SPEED_STEP_CRUISE:
		Narrator.speak(LINE_CRUISE_SPEED)
	elif step > prev:
		Narrator.speak(LINE_FASTER)
	else:
		Narrator.speak(LINE_SLOWER)

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
	_tut_onset_locked = false
	_no_sensor_frames = 0
	_sx = 1.0
	_sy = 1.0
	_sz = 1.0
	_tut_pull_peak = 0.0
	_tut_push_peak = 0.0
	_tut_push_return = 0.0
	_tut_pull_return = 0.0
	_joy_return_peak = 0.0
	_tut_pull_raw = 0.0
	_tut_push_raw = 0.0
	_tut_jerk_peak = 0.0
	_tut_surge_peak = 0.0
	_tut_surge_phase = "pose"
	_tut_surge_phase_t = 0.0
	_tut_surge_idle_sum = 0.0
	_tut_surge_intro_done = false
	_tut_win_pos = 0.0
	_tut_win_neg = 0.0
	if _speed_joy:
		_tut_steps = TUT_STEPS_JOY
	elif _speed_gears:
		_tut_steps = TUT_STEPS_GEARS
	else:
		_tut_steps = TUT_STEPS_CRUISE
	_reticle.visible = false
	_tut_arrow.visible = true
	_tut_phone.visible = true
	if _speed_bar != null:
		_speed_bar.visible = false
	_reset_level_look()
	_show_tut_step(0)
	_tel_event("tutorial enter gears=%d joy=%d" % [
		1 if _speed_gears else 0, 1 if _speed_joy else 0])
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
	if str(step.get("kind", "tilt")) == "surge":
		var pose: String = str(step["line"])
		if not _tut_surge_intro_done:
			_tut_surge_intro_done = true
			var intro: String = LINE_TUT_SURGE_INTRO
			if _speed_joy:
				intro = LINE_TUT_SURGE_INTRO_JOY
			elif not _speed_gears:
				intro = LINE_TUT_SURGE_INTRO_CRUISE
			Narrator.speak(intro + " " + pose)
		else:
			Narrator.speak(pose)
		return
	Narrator.speak(str(step["line"]))

func _begin_surge_step(step: Dictionary) -> void:
	_tut_phone.set_surge(float(step["dir"]), str(step.get("mode", "hold")))
	_tut_phone.set_status("red")
	_tut_phone.set_animate(false)
	_tut_surge_phase = "pose"
	_tut_surge_phase_t = 0.0
	_tut_surge_idle_sum = 0.0
	_tut_surge_peak = 0.0
	_tut_win_pos = 0.0
	_tut_win_neg = 0.0
	_tut_onset_locked = false
	_surge_release_t = 0.0
	_tut_ref_t = 0.0
	_tut_hold = 0.0
	_hint.text = str(step["hint"])
	_tel_event("tut_surge pose dir=%.0f mode=%s" % [float(step["dir"]),
		str(step.get("mode", "hold"))])

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
			_apply_surge_thresholds(SURGE_ARM_DEFAULT / SURGE_CAL_FRAC,
				SURGE_ARM_DEFAULT / SURGE_CAL_FRAC)
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
	var mode: String = str(step.get("mode", "hold"))
	var learn: bool = bool(step.get("learn", false))

	# ── RED: brief ready while VO finishes ──────────────────────────
	if _tut_surge_phase == "pose":
		_tut_phone.set_status("red")
		_tut_phone.set_animate(false)
		_tut_surge_phase_t += delta
		_last_surge = 0.0
		if Narrator.is_playing():
			return
		var pose_s: float = TUT_SURGE_POSE_S
		if _tut_surge_phase_t < pose_s:
			return
		_surge_neutral = _surge_filt
		_last_surge = 0.0
		_tut_surge_peak = 0.0
		_tut_win_pos = 0.0
		_tut_win_neg = 0.0
		_tut_onset_locked = false
		_joy_reset_disp()
		_joy_cal_sum = 0.0
		_joy_cal_sum2 = 0.0
		_joy_cal_t = 0.0
		_joy_peak = 0.0
		_joy_tel_t = 0.0
		_tut_surge_phase_t = 0.0
		_tut_phone.set_status("green")
		_tut_phone.set_animate(true)
		if mode.begins_with("joy_"):
			_tut_surge_phase = "measure"
			_joy_phase = "hold" if mode == "joy_neutral" else "throw"
			_hint.text = "Measuring…"
			_tel_event("tut_joy start mode=%s neutral=%.2f" % [mode, _surge_neutral])
		else:
			_tut_surge_phase = "capture"
			_hint.text = "Capturing…"
			_tel_event("tut_surge capture start=%.2f mode=%s" % [_surge_neutral, mode])
		Narrator.speak(str(step["go"]))
		return

	if _tut_surge_phase == "success":
		_tut_phone.set_status("green")
		_tut_phone.set_animate(false)
		if Narrator.is_playing():
			return
		_tut_surge_phase_t += delta
		if _tut_surge_phase_t < TUT_SURGE_OK_S:
			return
		_tut_advance()
		return

	if mode.begins_with("joy_"):
		_tut_joy_measure(delta, mode, want, learn)
		return

	# ── GREEN: fixed 2s window; lock first onset (ignore settle brake) ─
	_tut_phone.set_status("green")
	_tut_phone.set_animate(true)
	_hint.text = "Capturing…"
	var axis_delta: float = _surge_filt - _surge_neutral
	var arm_on: float = TUT_SURGE_MIN
	if not _tut_onset_locked:
		if absf(axis_delta) >= arm_on:
			_tut_onset_locked = true
			_tut_surge_peak = axis_delta
			_tut_win_pos = maxf(0.0, axis_delta)
			_tut_win_neg = maxf(0.0, -axis_delta)
			_tel_event("tut_surge onset=%.2f want=%.0f" % [axis_delta, want])
	elif signf(axis_delta) == signf(_tut_surge_peak):
		if absf(axis_delta) > absf(_tut_surge_peak):
			_tut_surge_peak = axis_delta
		if axis_delta > _tut_win_pos:
			_tut_win_pos = axis_delta
		if -axis_delta > _tut_win_neg:
			_tut_win_neg = -axis_delta
	_tut_surge_phase_t += delta
	if _tut_surge_phase_t < TUT_SURGE_WIN_S:
		return
	_tut_analyze_capture(want, mode, learn)

func _tut_joy_measure(delta: float, mode: String, want: float, learn: bool) -> void:
	## Cal on peak ACCEL shove (not integrated displacement — that can't
	## see push-and-hold; stop cancels the shove).
	_tut_phone.set_status("green")
	_tut_phone.set_animate(mode != "joy_neutral")
	_tut_surge_phase_t += delta
	var a: float = _last_surge
	var quiet: bool = absf(a) <= JOY_ACCEL_QUIET
	_joy_tel_t += delta
	if _joy_tel_t >= JOY_TEL_S:
		_joy_tel_t = 0.0
		_tel_event("tut_joy tick mode=%s phase=%s a=%.2f peak=%.2f q=%d" % [
			mode, _joy_phase, a, _joy_peak, 1 if quiet else 0])

	if mode == "joy_neutral":
		_hint.text = "1 · Hold still"
		_joy_cal_sum += _surge_filt * delta
		_joy_cal_sum2 += _surge_filt * _surge_filt * delta
		_joy_cal_t += delta
		if not quiet:
			_joy_cal_t = minf(_joy_cal_t, JOY_NEUTRAL_HOLD_S * 0.35)
		if _joy_cal_t < 1.0:
			return
		var mean: float = _joy_cal_sum / maxf(_joy_cal_t, 0.001)
		var mean2: float = _joy_cal_sum2 / maxf(_joy_cal_t, 0.001)
		var var_: float = maxf(0.0, mean2 - mean * mean)
		var std: float = sqrt(var_)
		_surge_neutral = mean
		_joy_band = clampf(std * 3.5, JOY_BAND_MIN, 0.45)
		_joy_reset_disp()
		_tel_event("tut_joy neutral mean=%.3f std=%.3f band=%.3f" % [
			mean, std, _joy_band])
		_tut_joy_confirm()
		return

	# ── Capture onset peak, then require return-to-rest ──────────────
	if _joy_phase == "throw" or _joy_phase == "settle":
		if a > _tut_win_pos:
			_tut_win_pos = a
		if -a > _tut_win_neg:
			_tut_win_neg = -a
		var cand: float = a
		if not _tut_onset_locked:
			if absf(cand) >= JOY_EXTREME_MIN:
				if learn or cand * want > 0.0:
					_tut_onset_locked = true
					_joy_peak = cand
					_tel_event("tut_joy onset=%.2f want=%.0f" % [cand, want])
		elif signf(cand) == signf(_joy_peak):
			if absf(cand) > absf(_joy_peak):
				_joy_peak = cand
		_hint.text = ("%s · shove  a=%.2f peak=%.2f" % [
			"2 · Push" if want < 0.0 else "4 · Pull", a, _joy_peak])
		if not _tut_onset_locked or absf(_joy_peak) < JOY_EXTREME_MIN:
			_surge_release_t = 0.0
			_joy_phase = "throw"
			return
		_joy_phase = "settle"
		if quiet:
			_surge_release_t += delta
		else:
			_surge_release_t = 0.0
		if _surge_release_t < JOY_PEAK_SETTLE_S:
			return
		var pk: float = clampf(absf(_joy_peak), JOY_EXTREME_MIN, JOY_EXT_CAP)
		if learn:
			_sz = signf(_joy_peak) * want
			_tut_push_peak = pk
			_tel_event("learned sz=%.0f joy_push_ext=%.2f" % [_sz, _tut_push_peak])
		elif want < 0.0:
			_tut_push_peak = pk
		else:
			_tut_pull_peak = pk
		_joy_phase = "return"
		_joy_return_peak = 0.0
		_surge_release_t = 0.0
		_joy_tel_t = 0.0
		_tut_surge_phase_t = 0.0  ## reused as time-in-return
		_hint.text = "3 · Back to rest" if want < 0.0 else "5 · Back to rest"
		_tel_event("tut_joy peak_locked=%.2f → return" % _joy_peak)
		Narrator.speak(LINE_TUT_JOY_RETURN)
		return

	# ── Return to rest: REQUIRE opposite shove, then steady quiet ───
	## Holding still after the push looks identical to rest on accel —
	## quiet alone must not pass. Wait for a real return motion first.
	if _joy_phase == "return":
		# Skip leftover settle brake from the shove (~0.3s).
		if _tut_surge_phase_t < 0.30:
			_surge_release_t = 0.0
			_hint.text = "3 · Move back to rest" if want < 0.0 else "5 · Move back to rest"
			return
		var need_ret: float = maxf(JOY_RETURN_MIN, absf(_joy_peak) * 0.35)
		if a * _joy_peak < 0.0 and absf(a) > _joy_return_peak:
			_joy_return_peak = absf(a)
		if _joy_return_peak < need_ret:
			_surge_release_t = 0.0
			_hint.text = ("%s · move back  ret=%.2f need=%.2f" % [
				"3" if want < 0.0 else "5", _joy_return_peak, need_ret])
			return
		_hint.text = "3 · Hold still at rest" if want < 0.0 else "5 · Hold still at rest"
		var near_rest: bool = absf(_surge_filt - _surge_neutral) <= maxf(_joy_band, 0.15)
		if near_rest and quiet:
			_surge_release_t += delta
		else:
			_surge_release_t = 0.0
		if _surge_release_t < JOY_RETURN_HOLD_S:
			return
		if want < 0.0 or learn:
			_tut_push_return = maxf(_tut_push_return, _joy_return_peak)
		else:
			_tut_pull_return = maxf(_tut_pull_return, _joy_return_peak)
		_tel_event("tut_joy done mode=%s peak=%.2f return=%.2f" % [
			mode, _joy_peak, _joy_return_peak])
		_joy_reset_disp()
		_tut_joy_confirm()
		return

func _tut_joy_confirm() -> void:
	_tut_surge_phase = "success"
	_tut_surge_phase_t = 0.0
	_tut_onset_locked = false
	_surge_release_t = 0.0
	_joy_phase = ""
	_tut_phone.set_status("green")
	_tut_phone.set_animate(false)
	_hint.text = "Got it!"
	_tel_event("tut_joy success")
	Narrator.speak(LINE_TUT_GOT_IT)

func _tut_analyze_capture(want: float, mode: String, learn: bool) -> void:
	var accept_thr: float = TUT_SURGE_JERK_MIN
	# Prefer onset-locked peak so settle/brake cannot invert polarity.
	var raw_peak: float = _tut_surge_peak
	if absf(raw_peak) < 0.01:
		var pos_pk: float = _tut_win_pos
		var neg_pk: float = _tut_win_neg
		raw_peak = pos_pk if pos_pk >= neg_pk else -neg_pk
	_tel_event("tut_surge analyze peak=%.2f pos=%.2f neg=%.2f want=%.0f mode=%s" % [
		raw_peak, _tut_win_pos, _tut_win_neg, want, mode])
	if absf(raw_peak) < accept_thr:
		_tel_event("tut_surge reject weak peak=%.2f thr=%.2f" % [
			raw_peak, accept_thr])
		_tut_retry_capture()
		return
	if learn:
		_sz = signf(raw_peak) * want
		_tut_pull_raw = raw_peak
		_tut_pull_peak = absf(raw_peak)
		_tut_push_peak = absf(raw_peak)
		_tut_jerk_peak = maxf(_tut_jerk_peak, absf(raw_peak))
		_tut_surge_peak = raw_peak
		_tel_event("learned sz=%.0f pull_raw=%.2f" % [_sz, _tut_pull_raw])
		_tut_surge_accept()
		return
	var signed: float = _sz * raw_peak
	if signed * want < accept_thr:
		_tel_event("tut_surge reject dir peak_raw=%.2f signed=%.2f want=%.0f" % [
			raw_peak, signed, want])
		_tut_retry_capture()
		return
	_tut_jerk_peak = maxf(_tut_jerk_peak, absf(signed))
	if want < 0.0:
		_tut_push_raw = raw_peak
		_tut_push_peak = maxf(_tut_push_peak, absf(signed))
	else:
		_tut_pull_raw = raw_peak
		_tut_pull_peak = maxf(_tut_pull_peak, absf(signed))
	_tut_surge_peak = raw_peak
	_tel_event("tut_surge hit peak_raw=%.2f signed=%.2f mode=%s" % [
		raw_peak, signed, mode])
	_tut_surge_accept()

func _tut_retry_capture() -> void:
	_surge_neutral = _surge_filt
	_tut_win_pos = 0.0
	_tut_win_neg = 0.0
	_tut_surge_peak = 0.0
	_tut_onset_locked = false
	_tut_surge_phase = "capture"
	_tut_surge_phase_t = 0.0
	_hint.text = "Capturing…"
	_tel_event("tut_surge retry")

func _tut_surge_accept() -> void:
	_tut_surge_phase = "success"
	_tut_surge_phase_t = 0.0
	_tut_onset_locked = false
	_surge_release_t = 0.0
	_tut_phone.set_status("green")
	_tut_phone.set_animate(false)
	_hint.text = "Got it!"
	_tel_event("tut_surge success")

func _tut_advance() -> void:
	_tel_event("tutorial step %d done" % _tut_i)
	_tut_i += 1
	_tut_hold = 0.0
	_tut_ref_sum = Vector2.ZERO
	_tut_ref_t = 0.0
	_tut_surge_peak = 0.0
	_tut_win_pos = 0.0
	_tut_win_neg = 0.0
	_tut_onset_locked = false
	_surge_release_t = 0.0
	_tut_surge_phase = "pose"
	_tut_surge_phase_t = 0.0
	_tut_surge_idle_sum = 0.0
	_reset_level_look()
	if _tut_i >= _tut_steps.size():
		_tut_phone.visible = false
		_tut_arrow.visible = false
		if _speed_joy:
			_apply_joy_extents(_tut_push_peak, _tut_pull_peak, _joy_band)
		elif _tut_pull_peak > 0.0 and _tut_push_peak > 0.0:
			_apply_surge_thresholds(_tut_pull_peak, _tut_push_peak)
		elif _tut_jerk_peak > 0.0:
			_apply_surge_thresholds(_tut_jerk_peak, _tut_jerk_peak)
		elif _tut_pull_peak > 0.0:
			_apply_surge_thresholds(_tut_pull_peak, _tut_pull_peak)
		_tel_event("tutorial done pull=%.2f push=%.2f jerkpk=%.2f sz=%.0f joy=%d" % [
			_tut_pull_peak, _tut_push_peak, _tut_jerk_peak, _sz, 1 if _speed_joy else 0])
		_enter_gate()
		return
	_show_tut_step(_tut_i)
	_speak_tut_step(_tut_i)

func _update_speed_hint() -> void:
	if _speed_bar != null:
		_speed_bar.visible = _speed_gears or _speed_joy
		_speed_bar.speed = _speed
		_speed_bar.step = _speed_step
		_speed_bar.continuous = _speed_joy
		_speed_bar.blending = _speed_blending
		_speed_bar.queue_redraw()
	if _speed_joy:
		var st: String = "READY"
		if absf(_joy_drive) > 0.5:
			if _joy_backoff:
				st = "BACKOFF"
			elif _joy_drive > 0.0:
				st = "ACCEL"
			else:
				st = "DECEL"
		_hint.text = "spd %.0f · %s" % [_speed, st]
	elif _speed_step <= SPEED_STEP_STOP:
		_hint.text = "HOLDING — quick pull to speed up"
	elif _speed_gears:
		_hint.text = "Gear %d / %d · jerk push/pull" % [_speed_step, SPEED_STEP_MAX]
	else:
		_hint.text = "Cruising · quick push to stop · tilt to steer"

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
	_tilt_neutral = neutral
	_calibrated = true
	_state = State.FLYING
	_capture_grace = CAPTURE_GRACE_S
	_apply_speed_step(SPEED_STEP_CRUISE, false)
	# Joy stick needs live accel immediately; gears still wait for quiet recenter.
	if _speed_joy:
		_surge_need_recenter = false
		_recenter_surge_neutral()
		_surge_announce_ready = false
		_joy_clear_drive()
		_joy_launch_guard = JOY_LAUNCH_GUARD_S
	else:
		_surge_need_recenter = true
	_surge_capture_cd = 0.0
	_band_warned = false
	_reticle.visible = false
	_tut_arrow.visible = false
	_tut_phone.visible = false
	# Launch looking straight ahead at the home world — never the leftover
	# pitch from a tutorial dive.
	_reset_level_look()
	_update_speed_hint()
	_tel_event("launch neutral=(%.3f,%.3f) sx=%.0f sy=%.0f sz=%.0f gears=%d joy=%d flip=%.0f" % [
		neutral.x, neutral.y, _sx, _sy, _sz, 1 if _speed_gears else 0,
		1 if _speed_joy else 0, _flip])
	Narrator.speak(LINE_WELCOME)
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
	print("PGTEL g=(%.2f,%.2f,%.2f) acc=(%.2f,%.2f,%.2f) ang=(%.3f,%.3f) na=(%.3f,%.3f) s=(%.0f,%.0f,%.0f) cal=%d tilt=(%.2f,%.2f) yaw=%.2f pitch=%.2f y=%.1f near=%s d=%.1f x=%.2f aim=%.2f spd=%.0f step=%d blend=%d surge=%.2f peak=%.2f arm=%.2f jerk_cd=%.1f cap_cd=%.1f disp=%.3f vel=%.3f stick=%.2f band=%.3f pext=%.3f lext=%.3f joy=%d drive=%.0f back=%d" % [
		g.x, g.y, g.z, acc.x, acc.y, acc.z,
		ang.x, ang.y, _tilt_neutral.x, _tilt_neutral.y,
		_sx, _sy, _sz,
		1 if _calibrated else 0, _last_tilt.x, _last_tilt.y,
		_yaw, _pitch, _ship_pos.y, near_id, near_d, near_x, aim,
		_speed, _speed_step, 1 if _speed_blending else 0, _last_surge,
		_surge_pulse_peak, _surge_arm, _jerk_cd, _surge_capture_cd,
		_surge_disp, _surge_vel, _surge_stick, _joy_band,
		_joy_push_ext, _joy_pull_ext, 1 if _speed_joy else 0, _joy_drive,
		1 if _joy_backoff else 0])

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
	_tile.visible = false
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
	elif event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		tap = true
		pos = event.position
	if not tap:
		return
	match _state:
		State.PAUSED_TILE:
			if _tile.get_global_rect().has_point(get_global_transform() * pos):
				_enter_orbit(_tile_id)
			else:
				_state = State.FLYING
				_tile.visible = false
				_update_speed_hint()
		State.FLYING:
			var id := _body_at_screen(pos)
			if not id.is_empty():
				_show_tile(id)

func _body_at_screen(screen: Vector2) -> String:
	var best := ""
	var best_d := TAP_RADIUS_PX
	for id in _bodies:
		var wp: Vector3 = (_bodies[id]["root"] as Node3D).global_position
		if _cam.is_position_behind(wp):
			continue
		var d: float = _cam.unproject_position(wp).distance_to(screen)
		if d < best_d:
			best_d = d
			best = id
	return best

func _show_tile(id: String) -> void:
	_tel_event("tile id=%s" % id)
	_state = State.PAUSED_TILE
	_tile_id = id
	var b := SolarData.flyer_body_by_id(id, _cfg)
	_tile_pic.texture = OrbitCinematic.texture_for(id)
	if _tile_pic.texture == null:
		_tile_pic.texture = CockpitHud.make_planet_thumb(
			b.get("color", Color(0.7, 0.7, 0.8)), 200)
	_tile_name.text = str(b.get("name", id))
	_tile.visible = true
	Narrator.speak(LINE_TILE)

func _show_arrival(place: String) -> void:
	_arrival_title.text = "Welcome to %s!" % place
	_arrival.visible = true

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
		icon.pixel_size = marker / 48.0

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
		icon.texture = PlanetSkins.make_icon_texture(b, 48)
		root.add_child(icon)
		_bodies[str(b["id"])] = {
			"root": root, "mesh": mesh, "icon": icon, "data": b,
			"hero": hero, "tier": SolarData.icon_tier_for(b),
		}

	_cam = Camera3D.new()
	_cam.fov = 70.0
	_cam.near = 0.15
	_cam.far = 3000.0
	_world.add_child(_cam)
	_cam.current = true

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

	_speed_bar = SpeedBar.new()
	_speed_bar.name = "SpeedBar"
	_speed_bar.cruise = SPEED
	_speed_bar.vmax = SPEED * float(SPEED_STEP_MULT[SPEED_STEP_MAX - 1])
	_speed_bar.step_max = SPEED_STEP_MAX
	_speed_bar.cruise_step = SPEED_STEP_CRUISE
	_speed_bar.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_speed_bar.offset_left = -64
	_speed_bar.offset_right = -14
	_speed_bar.offset_top = -150
	_speed_bar.offset_bottom = 150
	_speed_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_speed_bar)

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

	_reticle = AimReticle.new()
	_reticle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reticle.radius_rad = GATE_RADIUS_RAD
	_reticle.visible = false
	add_child(_reticle)

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
	_speed_pick.joystick_pressed.connect(_on_speed_joystick)
	add_child(_speed_pick)

	# Planet picture tile shown when a world is tapped mid-flight.
	_tile = PanelContainer.new()
	_tile.name = "PlanetTile"
	_tile.visible = false
	_tile.position = Vector2(440, 100)
	_tile.custom_minimum_size = Vector2(400, 340)
	var tsb := StyleBoxFlat.new()
	tsb.bg_color = Color(0.06, 0.10, 0.20, 0.97)
	tsb.set_corner_radius_all(24)
	tsb.set_border_width_all(3)
	tsb.border_color = Color(1.0, 0.86, 0.36, 0.95)
	_tile.add_theme_stylebox_override("panel", tsb)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 8)
	_tile.add_child(tv)
	_tile_pic = TextureRect.new()
	_tile_pic.custom_minimum_size = Vector2(376, 250)
	_tile_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tile_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_tile_pic.clip_contents = true
	_tile_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tv.add_child(_tile_pic)
	_tile_name = Label.new()
	_tile_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tile_name.add_theme_font_size_override("font_size", 30)
	_tile_name.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
	tv.add_child(_tile_name)
	var tap := Label.new()
	tap.text = "Tap to travel here"
	tap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tap.add_theme_font_size_override("font_size", 18)
	tap.add_theme_color_override("font_color", Color(0.8, 0.88, 1.0, 0.9))
	tv.add_child(tap)
	add_child(_tile)

	# Arrival choices while parked in playground orbit.
	_arrival = Control.new()
	_arrival.visible = false
	_arrival.position = Vector2(280, 420)
	_arrival.size = Vector2(720, 150)
	_arrival_title = Label.new()
	_arrival_title.size = Vector2(720, 40)
	_arrival_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_arrival_title.add_theme_font_size_override("font_size", 30)
	_arrival_title.add_theme_color_override("font_color", Color(1, 0.95, 0.6))
	_arrival.add_child(_arrival_title)
	var keep := Button.new()
	keep.text = "Keep flying  ▶"
	keep.position = Vector2(90, 60)
	keep.size = Vector2(250, 68)
	keep.focus_mode = Control.FOCUS_NONE
	keep.add_theme_font_size_override("font_size", 24)
	var ksb := StyleBoxFlat.new()
	ksb.bg_color = Color(0.3, 0.75, 0.45, 0.96)
	ksb.set_corner_radius_all(18)
	keep.add_theme_stylebox_override("normal", ksb)
	keep.pressed.connect(resume_flying)
	_arrival.add_child(keep)
	var learn := Button.new()
	learn.text = "Learn more  ★"
	learn.position = Vector2(390, 60)
	learn.size = Vector2(250, 68)
	learn.focus_mode = Control.FOCUS_NONE
	learn.add_theme_font_size_override("font_size", 24)
	var lsb := StyleBoxFlat.new()
	lsb.bg_color = Color(0.35, 0.7, 0.95, 0.96)
	lsb.set_corner_radius_all(18)
	learn.add_theme_stylebox_override("normal", lsb)
	learn.pressed.connect(func() -> void: learn_more.emit(_orbit_id))
	_arrival.add_child(learn)
	add_child(_arrival)

## Launch-gate reticle: a dead-ahead crosshair circle, a dot showing the
## current aim, and a ring that fills while the aim is held near dead-on.
## Vertical speed meter: STOP + five gears, or continuous fill in joy mode.
class SpeedBar:
	extends Control
	var speed: float = 26.0
	var step: int = 3
	var cruise: float = 26.0
	var vmax: float = 45.5
	var step_max: int = 5
	var cruise_step: int = 3
	var blending: bool = false
	var continuous: bool = false

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var track := Rect2(w * 0.30, 10.0, w * 0.40, h - 36.0)
		draw_rect(track, Color(0.05, 0.08, 0.16, 0.75), true)
		draw_rect(track, Color(1.0, 1.0, 1.0, 0.35), false, 2.0)
		var t: float
		if continuous:
			t = clampf(speed / maxf(vmax, 0.01), 0.0, 1.0)
		else:
			t = float(clampi(step, 0, step_max)) / float(step_max)
		var fill_h: float = track.size.y * t
		var fill := Rect2(track.position.x, track.end.y - fill_h,
			track.size.x, fill_h)
		var col := Color(0.35, 0.85, 1.0, 0.9)
		if continuous:
			if speed <= 0.05:
				col = Color(0.55, 0.55, 0.65, 0.85)
			elif speed >= vmax - 0.5:
				col = Color(1.0, 0.78, 0.30, 0.95)
			elif absf(speed - cruise) < 1.5:
				col = Color(0.45, 0.95, 0.55, 0.92)
		else:
			col = Color(0.35, 0.85, 1.0, 0.9) if step > 0 \
				else Color(0.55, 0.55, 0.65, 0.85)
			if step >= step_max:
				col = Color(1.0, 0.78, 0.30, 0.95)
			elif step == cruise_step:
				col = Color(0.45, 0.95, 0.55, 0.92)
		if blending:
			col = col.lightened(0.12)
		draw_rect(fill, col, true)
		if not continuous:
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
		var label: String
		if continuous:
			label = "STOP" if speed <= 0.05 else ("%.0f" % speed)
		else:
			var labels2: Array = ["STOP", "1", "2", "3", "4", "5"]
			label = str(labels2[clampi(step, 0, mini(step_max, labels2.size() - 1))])
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
## player which way to tip or shove the device for the current step.
## Surge cal: start offset (red/yellow) → animate into rest (green).
## Outline: red (start pose) → yellow (capturing start) → green (go / done).
class PhoneTiltHint:
	extends Control
	var axis: int = 0       ## 0 = roll, 1 = pitch, 2 = surge (toward/away)
	var dir: float = 1.0    ## +1 right/up/pull, −1 left/down/push
	var surge_mode: String = "hold"  ## hold | jerk
	var status: String = "yellow"    ## red | yellow | green
	var animate_motion: bool = true
	var inbound_cal: bool = false    ## surge: start offset → rest
	var _t: float = 0.0

	func set_step(a: int, d: float) -> void:
		axis = a
		dir = d
		surge_mode = "hold"
		inbound_cal = false
		status = "yellow"
		animate_motion = true
		_t = 0.0
		queue_redraw()

	func set_surge(d: float, mode: String = "hold") -> void:
		axis = 2
		dir = d
		surge_mode = mode
		inbound_cal = true
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

	## Surge cal amount: −dir at start pose, 0 at rest. Gesture animates
	## start→rest (no out-and-back), matching "land in neutral and stay".
	func _motion_amount() -> float:
		if axis == 2 and inbound_cal:
			var start: float = -dir
			if status == "green" and not animate_motion:
				return 0.0  ## landed / success
			if not animate_motion:
				return start  ## frozen at start pose
			var cycle: float = 0.65 if surge_mode == "jerk" else 1.35
			var u: float = clampf(_t / cycle, 0.0, 1.0)
			# Ease into rest, then hold.
			var eased: float = u * u * (3.0 - 2.0 * u)
			return start * (1.0 - eased)
		# Tilt (and legacy surge): pulse out and back.
		var pulse: float = 0.0
		if animate_motion:
			pulse = 0.5 + 0.5 * sin(_t * (5.0 if surge_mode == "jerk" else 2.6))
			if surge_mode == "jerk":
				pulse = clampf(sin(_t * 5.5), 0.0, 1.0)
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
		# Pitch / surge: foreshorten + scale so pull grows, push shrinks.
		var top_s: float = 1.0 - 0.35 * pitch - 0.18 * depth
		var bot_s: float = 1.0 + 0.20 * pitch + 0.12 * depth
		var y_shift: float = -22.0 * pitch
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
		# Chevron: show during green go, or always for tilt.
		var show_chev: bool = animate_motion or (axis != 2)
		if axis == 2 and inbound_cal and status != "green":
			show_chev = true  ## point the way they'll move into rest
		if not show_chev:
			return
		var tip: Vector2
		if axis == 0:
			tip = c + Vector2(dir * 105.0, 0.0)
		elif axis == 1:
			tip = c + Vector2(0.0, -dir * 70.0)
		else:
			tip = c + Vector2(0.0, dir * 78.0)
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
			var base3 := tip - Vector2(0.0, dir * 28.0)
			draw_line(base3, tip, col, 4.0, true)
			draw_line(tip, tip + Vector2(-10.0, -dir * 14.0), col, 4.0, true)
			draw_line(tip, tip + Vector2(10.0, -dir * 14.0), col, 4.0, true)

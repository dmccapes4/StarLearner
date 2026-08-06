extends SceneTree
## Flight mechanics suite — mission burn profile + Free Flight (tap controls).
##
##   ./qa/run_flight_mechanics_suite.sh
##   godot --path game -s res://tools/flight_mechanics_suite.gd
##
## Writes PNGs + report.json under:
##   qa/out/flight_mechanics/<timestamp>/
##
## Exit 0 = all checks passed. Exit 1 = any FAIL (or fatal setup).

const VIEW := Vector2i(1280, 720)
const PlaygroundScene := preload("res://scripts/PlaygroundScene.gd")
const SpeedModeChooser := preload("res://scripts/SpeedModeChooser.gd")

var _shot_i: int = 0
var _out_abs: String = ""
var _manifest: Dictionary = {}
var _checks: Array = []

func _init() -> void:
	call_deferred("_run")

func _qa_out_root() -> String:
	var game_dir := ProjectSettings.globalize_path("res://").rstrip("/")
	return game_dir.get_base_dir().path_join("qa/out/flight_mechanics")

func _run() -> void:
	print("======== Solar System Explorer FLIGHT MECHANICS suite ========")
	root.get_viewport().size = VIEW
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	_out_abs = _qa_out_root().path_join(stamp)
	DirAccess.make_dir_recursive_absolute(_out_abs)
	_manifest = {
		"suite": "flight_mechanics",
		"stamp": stamp,
		"viewport": {"w": VIEW.x, "h": VIEW.y},
		"shots": [],
		"checks": [],
		"research": "docs/RESEARCH_MOTO_G_PLAY_2024_SENSORS_AND_KID_MOTION.md",
		"agent_brief": _agent_brief(),
	}

	_check_mission_burn()
	_check_course_arc()
	_check_speed_chooser_copy()
	_check_playground_constants()
	_check_tilt_helpers()
	await _check_playground_runtime()

	_manifest["checks"] = _checks
	var report_path := _out_abs.path_join("report.json")
	FileAccess.open(report_path, FileAccess.WRITE).store_string(JSON.stringify(_manifest, "\t"))
	print("FLIGHT suite done → %s (%d shots, %d checks)" % [
		_out_abs, _shot_i, _checks.size()])
	var fails := 0
	for c in _checks:
		if not c.get("ok", false):
			fails += 1
			print(" FAIL ", c.get("name"), " — ", c.get("detail"))
	quit(1 if fails > 0 else 0)

## ── Mission path: chart burn profile (OrbitMath + SolarFlyerConfig) ──

func _check_mission_burn() -> void:
	var cfg := SolarFlyerConfig.load_default()
	_check("mission_burn_accel", is_equal_approx(cfg.burn_accel, 1.1),
		"burn_accel=%s" % cfg.burn_accel)
	_check("mission_v_max", is_equal_approx(cfg.v_max, 17.0),
		"v_max=%s" % cfg.v_max)
	_check("mission_cruise_seed", cfg.cruise_speed > 0.0,
		"cruise_speed=%s" % cfg.cruise_speed)

	# Triangular hop: d <= v²/a → never reaches v_max
	var a: float = cfg.burn_accel
	var v: float = cfg.v_max
	var d_tri: float = (v * v / a) * 0.25
	var t_tri: float = OrbitMath.burn_travel_time(d_tri, cfg)
	var peak_tri: float = OrbitMath.burn_peak_speed(d_tri, cfg)
	_check("burn_tri_peak_below_vmax", peak_tri < v - 0.01,
		"peak=%.3f v_max=%.3f d=%.3f" % [peak_tri, v, d_tri])
	_check("burn_tri_time_formula",
		is_equal_approx(t_tri, 2.0 * sqrt(d_tri / a)),
		"t=%.4f expect=%.4f" % [t_tri, 2.0 * sqrt(d_tri / a)])
	_check("burn_tri_mid_is_apex",
		OrbitMath.burn_phase(0.5, d_tri, cfg) != OrbitMath.PHASE_COAST,
		"mid_phase=%d (tri has no coast)" % OrbitMath.burn_phase(0.5, d_tri, cfg))

	# Trapezoid hop: long enough to coast
	var d_trap: float = (v * v / a) * 4.0
	var t_trap: float = OrbitMath.burn_travel_time(d_trap, cfg)
	var expect_trap: float = d_trap / v + v / a
	_check("burn_trap_time_formula", is_equal_approx(t_trap, expect_trap),
		"t=%.4f expect=%.4f" % [t_trap, expect_trap])
	_check("burn_trap_peak_is_vmax",
		is_equal_approx(OrbitMath.burn_peak_speed(d_trap, cfg), v),
		"peak=%s" % OrbitMath.burn_peak_speed(d_trap, cfg))
	_check("burn_trap_early_burn",
		OrbitMath.burn_phase(0.05, d_trap, cfg) == OrbitMath.PHASE_BURN,
		"phase=%d" % OrbitMath.burn_phase(0.05, d_trap, cfg))
	_check("burn_trap_mid_coast",
		OrbitMath.burn_phase(0.5, d_trap, cfg) == OrbitMath.PHASE_COAST,
		"phase=%d" % OrbitMath.burn_phase(0.5, d_trap, cfg))
	_check("burn_trap_late_brake",
		OrbitMath.burn_phase(0.95, d_trap, cfg) == OrbitMath.PHASE_BRAKE,
		"phase=%d" % OrbitMath.burn_phase(0.95, d_trap, cfg))

	# Progress endpoints + monotonic mid
	_check("burn_progress_0", is_equal_approx(OrbitMath.burn_progress(0.0, d_trap, cfg), 0.0),
		"p0=%s" % OrbitMath.burn_progress(0.0, d_trap, cfg))
	_check("burn_progress_1", is_equal_approx(OrbitMath.burn_progress(1.0, d_trap, cfg), 1.0),
		"p1=%s" % OrbitMath.burn_progress(1.0, d_trap, cfg))
	var p25: float = OrbitMath.burn_progress(0.25, d_trap, cfg)
	var p75: float = OrbitMath.burn_progress(0.75, d_trap, cfg)
	_check("burn_progress_monotonic", p25 < p75,
		"p25=%.3f p75=%.3f" % [p25, p75])

	# PlotBoard beat scaling (course chart readability)
	var near := PlotBoard.plot_beat_seconds(12.0)
	var far := PlotBoard.plot_beat_seconds(40.0)
	_check("plot_beat_has_keys",
		near.has("chart") and near.has("lead") and near.has("preview"),
		"keys=%s" % str(near.keys()))
	_check("plot_beat_far_not_shorter",
		float(far.get("chart", 0.0)) >= float(near.get("chart", 0.0)) - 0.001,
		"near_chart=%s far_chart=%s" % [near.get("chart"), far.get("chart")])

func _check_course_arc() -> void:
	var ship := Vector3(20.0, 0.0, 0.0)
	var arrival := Vector3(0.0, 0.0, 40.0)
	var curve := OrbitMath.build_course(ship, arrival, 48, 2.0)
	_check("course_point_count", curve.get_point_count() >= 3,
		"n=%d" % curve.get_point_count())
	var end_pt: Vector3 = curve.get_point_position(curve.get_point_count() - 1)
	_check("course_ends_at_arrival", end_pt.distance_to(arrival) < 0.05,
		"end=%s arrival=%s" % [end_pt, arrival])
	# Arc radii stay between endpoint orbit radii (no sun dive)
	var r0: float = ship.length()
	var r1: float = arrival.length()
	var r_lo: float = minf(r0, r1) - 0.5
	var r_hi: float = maxf(r0, r1) + 0.5
	var ok_r := true
	var worst := 0.0
	for i in curve.get_point_count():
		var r: float = curve.get_point_position(i).length()
		worst = maxf(worst, absf(r - clampf(r, r_lo, r_hi)))
		if r < r_lo or r > r_hi:
			ok_r = false
	_check("course_radius_bounded", ok_r, "worst_out=%.3f" % worst)

func _check_speed_chooser_copy() -> void:
	_check("chooser_gears_line",
		SpeedModeChooser.LINE_GEARS.contains("lift") \
		and (SpeedModeChooser.LINE_GEARS.contains("five gears") \
			or SpeedModeChooser.LINE_GEARS.contains("Five gears")),
		SpeedModeChooser.LINE_GEARS)
	_check("chooser_cruise_line",
		SpeedModeChooser.LINE_CRUISE.contains("Cruise") \
		and SpeedModeChooser.LINE_CRUISE.contains("lift"),
		SpeedModeChooser.LINE_CRUISE)
	# Chooser may mention the gears joystick HUD (not a separate speed mode).
	_check("chooser_gears_mentions_joy",
		SpeedModeChooser.LINE_GEARS.find("joystick") >= 0 \
		or SpeedModeChooser.LINE_GEARS.find("Joystick") >= 0,
		SpeedModeChooser.LINE_GEARS)

## ── Free Flight constants (kid + Moto G Play research) ───────────────

func _check_playground_constants() -> void:
	_check("speed_cruise_base", is_equal_approx(PlaygroundScene.SPEED, 26.0),
		"SPEED=%s" % PlaygroundScene.SPEED)
	_check("playground_spacing",
		PlaygroundScene.SPACING >= 1.75 and PlaygroundScene.SPACING <= 2.0,
		"SPACING=%s" % PlaygroundScene.SPACING)
	_check("belt_decor_count",
		PlaygroundScene.BELT_DECOR_COUNT >= 40 \
		and PlaygroundScene.BELT_DECOR_COUNT <= 100,
		"n=%d" % PlaygroundScene.BELT_DECOR_COUNT)
	_check("gear_mult_count", PlaygroundScene.SPEED_STEP_MULT.size() == 5,
		"n=%d" % PlaygroundScene.SPEED_STEP_MULT.size())
	_check("gear_max_step", PlaygroundScene.SPEED_STEP_MAX == 5,
		"max=%d" % PlaygroundScene.SPEED_STEP_MAX)
	_check("band_soft_lt_hard",
		PlaygroundScene.Y_SOFT < PlaygroundScene.Y_MAX \
		and PlaygroundScene.Y_CLEAR < PlaygroundScene.Y_SOFT,
		"clear=%s soft=%s max=%s" % [
			PlaygroundScene.Y_CLEAR, PlaygroundScene.Y_SOFT, PlaygroundScene.Y_MAX])
	_check("band_allows_sightseeing",
		PlaygroundScene.Y_MAX >= 150.0,
		"Y_MAX=%s" % PlaygroundScene.Y_MAX)
	_check("capture_grace",
		PlaygroundScene.CAPTURE_GRACE_S >= 1.0,
		"CAPTURE_GRACE_S=%s" % PlaygroundScene.CAPTURE_GRACE_S)
	_check("tap_rate_min_max",
		PlaygroundScene.TAP_RATE_MIN < PlaygroundScene.TAP_RATE_MAX \
		and PlaygroundScene.TAP_RATE_MIN > 0.1,
		"min=%s max=%s" % [
			PlaygroundScene.TAP_RATE_MIN, PlaygroundScene.TAP_RATE_MAX])
	_check("tap_decay_slow",
		PlaygroundScene.TAP_RATE_DECAY > 0.15 \
		and PlaygroundScene.TAP_RATE_DECAY < 0.55,
		"decay=%s" % PlaygroundScene.TAP_RATE_DECAY)
	_check("tap_home_radius",
		PlaygroundScene.TAP_HOME_RADIUS_PX >= 48.0,
		"home_r=%s" % PlaygroundScene.TAP_HOME_RADIUS_PX)
	_check("welcome_tap_line",
		PlaygroundScene.LINE_WELCOME_TAP.contains("planet") \
		and PlaygroundScene.LINE_WELCOME_TAP.to_lower().contains("sun"),
		PlaygroundScene.LINE_WELCOME_TAP)
	_check("capture_aim_or_surface",
		PlaygroundScene.CAPTURE_AIM_DOT < 0.5 \
		and PlaygroundScene.CAPTURE_HERO_X > 1.2,
		"aim=%s x=%s" % [
			PlaygroundScene.CAPTURE_AIM_DOT, PlaygroundScene.CAPTURE_HERO_X])

func _check_tilt_helpers() -> void:
	# Resting landscape-ish gravity → near-zero tilt after normalize
	var g_rest := Vector3(0.0, -9.8, 0.2)
	var ang := PlaygroundScene._tilt_angles(g_rest)
	_check("tilt_rest_small_roll", absf(ang.x) < 0.05, "roll=%s" % ang.x)
	_check("tilt_deadzone_zero",
		is_equal_approx(PlaygroundScene._tilt_axis(0.0), 0.0), "0")
	_check("tilt_deadzone_inside",
		is_equal_approx(PlaygroundScene._tilt_axis(PlaygroundScene.TILT_DEAD_RAD * 0.5), 0.0),
		"half_dead")
	var full := PlaygroundScene._tilt_axis(PlaygroundScene.TILT_FULL_RAD)
	_check("tilt_full_saturates", absf(full) > 0.98, "full=%s" % full)
	var mid := PlaygroundScene._tilt_axis(
		lerpf(PlaygroundScene.TILT_DEAD_RAD, PlaygroundScene.TILT_FULL_RAD, 0.5))
	_check("tilt_mid_gentle", absf(mid) > 0.1 and absf(mid) < 0.9,
		"mid=%s" % mid)
	_check("tilt_sign_preserved",
		PlaygroundScene._tilt_axis(-PlaygroundScene.TILT_FULL_RAD) < 0.0,
		"neg")

## ── Runtime playground: tap flight + HUD, screenshots ────────────────

func _check_playground_runtime() -> void:
	var pg: PlaygroundScene = PlaygroundScene.new()
	pg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(pg)
	await _settle(4)
	pg.begin("earth")
	await _settle(8)

	_check("pg_state_flying",
		pg._state == PlaygroundScene.State.FLYING,
		"state=%s" % pg._state)
	# Spawn: behind Earth (further from Sun) and slightly above the ecliptic
	var earth_p0: Vector3 = (pg._bodies["earth"]["root"] as Node3D).global_position \
		if pg._bodies.has("earth") else Vector3.ZERO
	var sun_p0: Vector3 = pg._sun_world_pos()
	var d_ship0: float = Vector3(pg._ship_pos.x, 0.0, pg._ship_pos.z) \
		.distance_to(Vector3(sun_p0.x, 0.0, sun_p0.z))
	var d_earth0: float = Vector3(earth_p0.x, 0.0, earth_p0.z) \
		.distance_to(Vector3(sun_p0.x, 0.0, sun_p0.z))
	_check("spawn_behind_earth",
		d_ship0 > d_earth0 and pg._ship_pos.y > 8.0,
		"ship_sun=%s earth_sun=%s y=%s" % [d_ship0, d_earth0, pg._ship_pos.y])
	_check("pg_belt_decor",
		pg._belt_decor != null \
		and pg._belt_decor.multimesh != null \
		and pg._belt_decor.multimesh.instance_count == PlaygroundScene.BELT_DECOR_COUNT \
		and not pg._bodies.has("asteroid_belt"),
		"mm=%s n=%s bodies_has_belt=%s" % [
			pg._belt_decor != null,
			pg._belt_decor.multimesh.instance_count if pg._belt_decor != null \
				and pg._belt_decor.multimesh != null else -1,
			pg._bodies.has("asteroid_belt")])
	_check("pg_aim_mark",
		pg._aim_mark != null and pg._aim_mark.visible,
		"mark=%s vis=%s" % [
			pg._aim_mark != null,
			pg._aim_mark.visible if pg._aim_mark != null else false])
	_check("pg_stop_btn",
		pg._stop_btn != null and pg._stop_btn.visible,
		"stop=%s vis=%s" % [
			pg._stop_btn != null,
			pg._stop_btn.visible if pg._stop_btn != null else false])
	_check("pg_gear_joystick",
		pg._gear_joy != null and pg._gear_joy.visible,
		"joy=%s vis=%s" % [
			pg._gear_joy != null,
			pg._gear_joy.visible if pg._gear_joy != null else false])
	_check("pg_sun_tile",
		pg._sun_tile != null and pg._sun_tile.visible,
		"sun=%s vis=%s" % [
			pg._sun_tile != null,
			pg._sun_tile.visible if pg._sun_tile != null else false])
	_check("pg_zodiac_sky_built",
		pg._zodiac_root != null and pg._signs.size() == 12,
		"n=%d" % pg._signs.size())
	_check("pg_zodiac_btn",
		pg._zodiac_btn != null and pg._zodiac_btn.visible,
		"btn=%s" % (pg._zodiac_btn != null))
	pg._set_zodiac_sky(true)
	_check("pg_zodiac_toggle_on",
		pg._zodiac_on and pg._zodiac_root.visible, "on")
	pg._set_zodiac_sky(false)
	_check("pg_zodiac_toggle_off",
		(not pg._zodiac_on) and (not pg._zodiac_root.visible), "off")
	_check("pg_launch_cruise_speed",
		is_equal_approx(pg._speed, PlaygroundScene.SPEED),
		"speed=%s" % pg._speed)
	await _shot(pg, "01_tap_flight",
		"Tap Free Flight — center cross, stop, interactive stick")

	# Gear speeds
	_check("gear_stop_0", is_equal_approx(pg._speed_for_step(0), 0.0), "0")
	_check("gear_1", is_equal_approx(pg._speed_for_step(1), PlaygroundScene.SPEED * 0.40),
		"s=%s" % pg._speed_for_step(1))
	_check("gear_cruise_3", is_equal_approx(pg._speed_for_step(3), PlaygroundScene.SPEED),
		"s=%s" % pg._speed_for_step(3))
	_check("gear_5_max", is_equal_approx(pg._speed_for_step(5), PlaygroundScene.SPEED * 1.75),
		"s=%s" % pg._speed_for_step(5))
	_check("gear_monotonic",
		pg._speed_for_step(1) < pg._speed_for_step(2) \
		and pg._speed_for_step(2) < pg._speed_for_step(3) \
		and pg._speed_for_step(4) < pg._speed_for_step(5),
		"steps ok")

	pg._apply_speed_step(PlaygroundScene.SPEED_STEP_CRUISE, false)
	_check("apply_cruise_immediate",
		is_equal_approx(pg._speed, PlaygroundScene.SPEED),
		"speed=%s" % pg._speed)
	pg._apply_speed_step(PlaygroundScene.SPEED_STEP_MAX, true)
	_check("blend_starts", pg._speed_blending, "blending")
	pg._tick_speed_blend(PlaygroundScene.SPEED_BLEND_S)
	_check("blend_finishes_at_max",
		is_equal_approx(pg._speed, pg._speed_for_step(PlaygroundScene.SPEED_STEP_MAX)) \
		and not pg._speed_blending,
		"speed=%s" % pg._speed)

	# Tap stick: mash forward to max; aft toward stop; decay to cruise
	pg._apply_speed_step(PlaygroundScene.SPEED_STEP_CRUISE, false)
	pg._tap_speed_cd = 0.0
	pg._held_stopped = false
	var step0: int = pg._speed_step
	pg._tap_speed_delta(1)
	_check("tap_faster_up",
		pg._speed_step == step0 + 1,
		"step %d→%d" % [step0, pg._speed_step])
	_check("joy_throw_faster_art",
		pg._gear_joy != null \
		and pg._gear_joy.phase == PlaygroundScene.GearJoystick.Phase.THROW \
		and pg._gear_joy._stick_tgt < 0.0,
		"phase=%s tgt=%s" % [
			pg._gear_joy.phase if pg._gear_joy != null else -1,
			pg._gear_joy._stick_tgt if pg._gear_joy != null else 0.0])
	_check("speed_bar_above_joy",
		pg._speed_bar != null and pg._speed_bar.visible \
		and pg._speed_bar.horizontal,
		"bar=%s vis=%s horiz=%s" % [
			pg._speed_bar != null,
			pg._speed_bar.visible if pg._speed_bar != null else false,
			pg._speed_bar.horizontal if pg._speed_bar != null else false])
	_check("tap_cruise_decay_armed",
		pg._cruise_decay_t > 0.0,
		"decay_t=%s" % pg._cruise_decay_t)
	# Mash through blend
	pg._tap_speed_cd = 0.0
	pg._tap_speed_delta(1)
	pg._tap_speed_cd = 0.0
	pg._tap_speed_delta(1)
	_check("tap_mash_to_max",
		pg._speed_step == PlaygroundScene.SPEED_STEP_MAX,
		"step=%d" % pg._speed_step)
	pg._tick_speed_blend(PlaygroundScene.SPEED_BLEND_S)
	# Decay steps back toward cruise
	pg._cruise_decay_t = 0.0
	pg._tick_cruise_decay(0.01)
	_check("cruise_decay_step",
		pg._speed_step == PlaygroundScene.SPEED_STEP_MAX - 1,
		"step=%d" % pg._speed_step)
	await _shot(pg, "02_tap_speed",
		"Stick mash faster + cruise-decay step")

	# Distance-based yaw: farther tap → higher rate; slow coast; no mash-stack
	pg._refresh_tap_screen_signs()
	pg._tap_yaw_rate = 0.0
	var yaw0: float = pg._yaw
	pg._nudge_yaw(pg._tap_x_sign, 0.55)
	_check("tap_yaw_nudge_left",
		pg._tap_yaw_rate > 0.0,
		"rate=%s sign=%s" % [pg._tap_yaw_rate, pg._tap_x_sign])
	pg._tap_steer_tick(0.2)
	_check("tap_left_increases_yaw",
		pg._yaw > yaw0,
		"yaw0=%s yaw=%s" % [yaw0, pg._yaw])
	pg._nudge_yaw(pg._tap_x_sign, 0.25)
	var near_rate: float = pg._tap_yaw_rate
	pg._nudge_yaw(pg._tap_x_sign, 0.95)
	var far_rate: float = pg._tap_yaw_rate
	_check("tap_yaw_distance_scales",
		far_rate > near_rate + 0.15,
		"near=%s far=%s" % [near_rate, far_rate])
	_check("tap_yaw_replaces_not_stacks",
		is_equal_approx(far_rate, pg._rate_from_strength(0.95)),
		"rate=%s expect=%s" % [far_rate, pg._rate_from_strength(0.95)])
	var before_decay: float = pg._tap_yaw_rate
	pg._tap_steer_tick(0.5)
	_check("tap_yaw_decays_slowly",
		pg._tap_yaw_rate < before_decay \
		and pg._tap_yaw_rate > before_decay - 0.4,
		"after=%s before=%s" % [pg._tap_yaw_rate, before_decay])
	_check("tap_is_turning",
		pg._is_turning(),
		"yaw_rate=%s" % pg._tap_yaw_rate)
	pg._tap_yaw_rate = 0.0
	pg._tap_pitch_rate = 0.0
	# Climb taps must move pitch
	pg._pitch = 0.0
	pg._ship_pos.y = 0.0
	pg._nudge_pitch(1.0, 0.7)
	var pitch_rate0: float = pg._tap_pitch_rate
	pg._tap_steer_tick(0.25)
	_check("tap_pitch_climbs",
		pg._pitch > 0.04 and pitch_rate0 > 0.2,
		"pitch=%s rate0=%s" % [pg._pitch, pitch_rate0])
	# Pitch must hold after coast — no idle auto-level
	var held_pitch: float = pg._pitch
	pg._tap_pitch_rate = 0.0
	pg._ship_pos.y = 120.0
	for _i in 12:
		pg._tap_steer_tick(0.25)
	_check("pitch_holds_no_auto_level",
		absf(pg._pitch - held_pitch) < 0.02,
		"pitch=%s held=%s y=%s" % [pg._pitch, held_pitch, pg._ship_pos.y])
	# Outer turn (empty-flight path) → distance steer
	pg._seek_id = ""
	pg._state = PlaygroundScene.State.FLYING
	var c: Vector2 = pg.size * 0.5
	var turn_pos: Vector2 = c + Vector2(-200.0, 0.0)
	pg._tap_yaw_rate = 0.0
	pg._on_empty_flight_tap(turn_pos)
	_check("outer_tap_steers_not_seek",
		pg._state == PlaygroundScene.State.FLYING \
		and pg._seek_id.is_empty() \
		and absf(pg._tap_yaw_rate) > 0.0,
		"state=%s seek=%s yaw_rate=%s" % [
			pg._state, pg._seek_id, pg._tap_yaw_rate])
	# Planet tap while turning still seeks
	pg._nudge_yaw(pg._tap_x_sign, 0.9)
	_check("turning_before_planet_tap", pg._is_turning(),
		"rate=%s" % pg._tap_yaw_rate)
	pg._begin_seek("mars")
	_check("seek_while_turning_ok",
		pg._state == PlaygroundScene.State.SEEKING and pg._seek_id == "mars",
		"state=%s seek=%s" % [pg._state, pg._seek_id])
	pg._cancel_seek()
	# Sun tile seeks the Sun
	pg._state = PlaygroundScene.State.FLYING
	pg._on_sun_tile_pressed()
	_check("sun_tile_seeks",
		pg._state == PlaygroundScene.State.SEEKING and pg._seek_id == "sun",
		"state=%s seek=%s" % [pg._state, pg._seek_id])
	pg._cancel_seek()
	# Collision capture still enters orbit
	pg._state = PlaygroundScene.State.FLYING
	pg._capture_grace = 0.0
	pg._seek_id = ""
	if pg._bodies.has("uranus"):
		var uroot: Node3D = pg._bodies["uranus"]["root"]
		var uhero: float = float(pg._bodies["uranus"]["hero"])
		pg._ship_pos = uroot.global_position + Vector3(uhero * 0.5, 0.0, 0.0)
		pg._yaw = 0.0
		pg._pitch = 0.0
		pg._check_capture()
		_check("collision_captures_orbit",
			pg._state == PlaygroundScene.State.ORBITING \
			and pg._orbit_id == "uranus",
			"state=%s orbit=%s" % [pg._state, pg._orbit_id])
		# Leave orbit + clear body so settle frames don't re-capture
		if pg._cine != null and pg._cine.has_method("stop"):
			pg._cine.stop()
		pg._state = PlaygroundScene.State.FLYING
		pg._orbit_id = ""
		pg._capture_grace = PlaygroundScene.CAPTURE_GRACE_S
		pg._ship_pos = Vector3(0.0, 14.0, 220.0)
		pg._arrival.visible = false
		pg._show_tap_hud(true)
	await _shot(pg, "03_tap_turn",
		"Distance turn + planet-while-turning + sun tile")

	# Stop holds — no cruise decay; GO resumes cruise
	pg._state = PlaygroundScene.State.FLYING
	pg._tap_speed_cd = 0.0
	pg._apply_speed_step(PlaygroundScene.SPEED_STEP_CRUISE, false)
	pg._held_stopped = false
	pg._on_stop_cruise_pressed()
	_check("tap_stop",
		pg._speed_step == PlaygroundScene.SPEED_STEP_STOP \
		and is_equal_approx(pg._speed, 0.0) and pg._held_stopped,
		"step=%d speed=%s held=%s" % [
			pg._speed_step, pg._speed, pg._held_stopped])
	_check("stop_btn_green",
		pg._stop_btn != null and pg._stop_btn.stopped,
		"stopped=%s" % (pg._stop_btn.stopped if pg._stop_btn != null else false))
	pg._cruise_decay_t = 0.0
	pg._tick_cruise_decay(0.01)
	_check("stop_no_decay",
		pg._speed_step == PlaygroundScene.SPEED_STEP_STOP,
		"step=%d" % pg._speed_step)
	pg._tap_speed_cd = 0.0
	pg._on_stop_cruise_pressed()
	_check("tap_cruise",
		pg._speed_step == PlaygroundScene.SPEED_STEP_CRUISE \
		and not pg._held_stopped,
		"step=%d held=%s" % [pg._speed_step, pg._held_stopped])
	await _shot(pg, "04_stop_cruise",
		"Stop holds; green GO → cruise")

	# Seek + STOP cancels target and holds
	pg._begin_seek("mars")
	await _settle(2)
	_check("seek_started",
		pg._state == PlaygroundScene.State.SEEKING,
		"state=%s" % pg._state)
	pg._tap_speed_cd = 0.0
	pg._apply_speed_step(PlaygroundScene.SPEED_STEP_CRUISE, false)
	pg._held_stopped = false
	pg._on_stop_cruise_pressed()
	_check("stop_cancels_seek",
		pg._state == PlaygroundScene.State.FLYING \
		and pg._seek_id.is_empty() \
		and pg._speed_step == PlaygroundScene.SPEED_STEP_STOP,
		"state=%s seek=%s step=%d" % [
			pg._state, pg._seek_id, pg._speed_step])

	pg.queue_free()
	await _settle(2)

func _shot(pg: PlaygroundScene, id: String, note: String) -> void:
	await _settle(2)
	var file := "%02d_%s.png" % [_shot_i, id]
	await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	if img == null:
		print("WARN no image for ", file)
		_manifest["shots"].append({"file": file, "id": id, "note": note, "missing": true})
		return
	img.save_png(_out_abs.path_join(file))
	_manifest["shots"].append({
		"file": file,
		"id": id,
		"note": note,
		"state": int(pg._state) if pg != null else -1,
	})
	_shot_i += 1
	print(" shot ", file)

func _settle(frames: int) -> void:
	for _i in frames:
		await process_frame

func _check(name: String, ok: bool, detail: String) -> void:
	_checks.append({"name": name, "ok": ok, "detail": detail})
	print(("OK  " if ok else "FAIL"), " ", name, " — ", detail)

func _agent_brief() -> String:
	return """Flight mechanics regression suite. (1) Free Flight is tap-only: planet seek, directional taps with rate decay, interactive stick (forward=faster), stop/cruise button. (2) Open every PNG: tap HUD, speed taps, turn/straighten, stop/cruise. (3) Any FAIL in report.json is a production regression. Mission burn remains accel→coast→brake."""

extends SceneTree
## Flight mechanics suite — mission burn profile + Free Flight (tilt/surge/joy).
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
	# Joystick / constant-accel mode retired — chooser must not advertise it.
	_check("chooser_no_joy_line",
		SpeedModeChooser.NARRATION.find("Joystick") < 0 \
		and SpeedModeChooser.NARRATION.find("joystick") < 0,
		SpeedModeChooser.NARRATION)

## ── Free Flight constants (kid + Moto G Play research) ───────────────

func _check_playground_constants() -> void:
	_check("tilt_full_~17deg",
		is_equal_approx(PlaygroundScene.TILT_FULL_RAD, 0.30),
		"TILT_FULL_RAD=%s" % PlaygroundScene.TILT_FULL_RAD)
	_check("tilt_dead_small",
		PlaygroundScene.TILT_DEAD_RAD > 0.0 \
		and PlaygroundScene.TILT_DEAD_RAD < PlaygroundScene.TILT_FULL_RAD * 0.25,
		"dead=%s full=%s" % [PlaygroundScene.TILT_DEAD_RAD, PlaygroundScene.TILT_FULL_RAD])
	_check("speed_cruise_base", is_equal_approx(PlaygroundScene.SPEED, 26.0),
		"SPEED=%s" % PlaygroundScene.SPEED)
	_check("gear_mult_count", PlaygroundScene.SPEED_STEP_MULT.size() == 5,
		"n=%d" % PlaygroundScene.SPEED_STEP_MULT.size())
	_check("gear_max_step", PlaygroundScene.SPEED_STEP_MAX == 5,
		"max=%d" % PlaygroundScene.SPEED_STEP_MAX)
	_check("surge_jerk_cd_2s",
		is_equal_approx(PlaygroundScene.SURGE_JERK_CD_S, 2.0),
		"SURGE_JERK_CD_S=%s" % PlaygroundScene.SURGE_JERK_CD_S)
	_check("band_soft_lt_hard",
		PlaygroundScene.Y_SOFT < PlaygroundScene.Y_MAX \
		and PlaygroundScene.Y_CLEAR < PlaygroundScene.Y_SOFT,
		"clear=%s soft=%s max=%s" % [
			PlaygroundScene.Y_CLEAR, PlaygroundScene.Y_SOFT, PlaygroundScene.Y_MAX])
	_check("gate_hold_kid",
		PlaygroundScene.GATE_HOLD_S >= 0.5 and PlaygroundScene.GATE_HOLD_S <= 1.5,
		"GATE_HOLD_S=%s" % PlaygroundScene.GATE_HOLD_S)
	_check("capture_grace",
		PlaygroundScene.CAPTURE_GRACE_S >= 1.0,
		"CAPTURE_GRACE_S=%s" % PlaygroundScene.CAPTURE_GRACE_S)
	_check("tut_gears_steps", PlaygroundScene.TUT_STEPS_GEARS.size() == 6,
		"n=%d" % PlaygroundScene.TUT_STEPS_GEARS.size())
	_check("tut_cruise_steps", PlaygroundScene.TUT_STEPS_CRUISE.size() == 6,
		"n=%d" % PlaygroundScene.TUT_STEPS_CRUISE.size())
	var gear_hints: Array = []
	for s in PlaygroundScene.TUT_STEPS_GEARS:
		if str(s.get("kind", "")) == "surge":
			gear_hints.append(str(s.get("hint", "")))
	_check("tut_gears_lift_lower",
		gear_hints.size() == 2 \
		and str(gear_hints[0]).contains("LIFT") \
		and str(gear_hints[1]).contains("LOWER"),
		"hints=%s" % str(gear_hints))
	_check("tut_lift_line",
		PlaygroundScene.LINE_TUT_LIFT.contains("Lift") \
		and PlaygroundScene.LINE_TUT_LOWER.contains("Lower"),
		"%s | %s" % [PlaygroundScene.LINE_TUT_LIFT, PlaygroundScene.LINE_TUT_LOWER])

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

## ── Runtime playground: gears + lift jerks, screenshots ─────────────

func _check_playground_runtime() -> void:
	var pg: PlaygroundScene = PlaygroundScene.new()
	pg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(pg)
	await _settle(4)
	pg.begin("earth")
	await _settle(8)

	_check("pg_state_speed_pick",
		pg._state == PlaygroundScene.State.SPEED_PICK,
		"state=%s" % pg._state)
	await _shot(pg, "01_speed_pick",
		"Free Flight speed chooser — gears + cruise tiles (no joystick)")

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

	# Gears path → tutorial
	pg._on_speed_gears()
	await _settle(6)
	_check("pg_gears_tutorial",
		pg._state == PlaygroundScene.State.TUTORIAL and pg._speed_gears,
		"state=%s gears=%s steps=%d" % [
			pg._state, pg._speed_gears, pg._tut_steps.size()])
	_check("pg_gears_tut_len", pg._tut_steps.size() == 6, "n=%d" % pg._tut_steps.size())
	await _shot(pg, "02_tutorial_gears",
		"Gears tutorial — tilt + lift/lower coaching")

	# Gear step apply + blend
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

	# Skip to flying (gears)
	pg._launch(Vector2.ZERO)
	await _settle(6)
	_check("pg_flying_gears",
		pg._state == PlaygroundScene.State.FLYING,
		"state=%s" % pg._state)
	_check("pg_launch_cruise_speed",
		is_equal_approx(pg._speed, PlaygroundScene.SPEED),
		"speed=%s" % pg._speed)
	await _shot(pg, "03_flying_gears",
		"Flying after launch — planetary playground, cruise gear")

	# Lift = +1 gear, lower = −1; 2s cooldown after fire
	pg._surge_post_neutral = 0.0
	pg._jerk_cd = 0.0
	pg._speed_gears = true
	pg._apply_speed_step(PlaygroundScene.SPEED_STEP_CRUISE, false)
	var step0: int = pg._speed_step
	pg._fire_surge_jerk(1.0)  ## lift → +1 gear + 2s CD
	_check("gear_lift_up",
		pg._speed_step == step0 + 1,
		"step %d→%d" % [step0, pg._speed_step])
	_check("gear_cd_after_up",
		pg._jerk_cd >= PlaygroundScene.SURGE_JERK_CD_S - 0.05,
		"cd=%s" % pg._jerk_cd)
	pg._jerk_cd = 0.0
	step0 = pg._speed_step
	pg._fire_surge_jerk(-1.0)
	_check("gear_lower_down",
		pg._speed_step == step0 - 1,
		"step %d→%d" % [step0, pg._speed_step])
	await _shot(pg, "04_flying_gears_shift",
		"Flying after simulated lift/lower gear shifts")

	# Cruise/stop mode selects correct tutorial table
	pg.begin("earth")
	await _settle(3)
	pg._on_speed_cruise_stop()
	await _settle(3)
	_check("pg_cruise_mode",
		not pg._speed_gears and pg._tut_steps.size() == 6,
		"gears=%s steps=%d" % [pg._speed_gears, pg._tut_steps.size()])
	await _shot(pg, "05_tutorial_cruise",
		"Cruise & Stop tutorial — lift cruise / lower stop coaching")

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
	return """Flight mechanics regression suite. (1) Read docs/RESEARCH_MOTO_G_PLAY_2024_SENSORS_AND_KID_MOTION.md for lift/lower gear jerks. (2) Open every PNG: speed pick shows gears+cruise (no joystick); tutorials coach lift/lower; flying shots show playground worlds. (3) Any FAIL in report.json is a production regression — fix PlaygroundScene / OrbitMath / SolarFlyerConfig, do not soften asserts. Key invariants: SURGE_JERK_CD_S=2s; lift=+gear lower=−gear; mission burn is accel→coast→brake (triangular short hops)."""

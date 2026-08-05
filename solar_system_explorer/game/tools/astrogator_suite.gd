extends SceneTree
## Astrogator Phase B suite — ledger math for every destination + PlotBoard /
## FlyScene UI smoke (fuel bar, calendar coast wipe).
##
##   ./qa/run_astrogator_suite.sh
##
## Exit 0 = all checks passed. FAIL = production regression (do not soften).

const VIEW := Vector2i(1280, 600)
const PlotBoardScript := preload("res://scripts/PlotBoard.gd")
const FlySceneScript := preload("res://scripts/FlyScene.gd")
const Starfield := preload("res://scripts/Starfield.gd")
const NavModes := preload("res://scripts/NavModes.gd")

var _shot_i: int = 0
var _out_abs: String = ""
var _manifest: Dictionary = {}
var _checks: Array = []

func _init() -> void:
	call_deferred("_run")

func _qa_out_root() -> String:
	var game_dir := ProjectSettings.globalize_path("res://").rstrip("/")
	return game_dir.get_base_dir().path_join("qa/out/astrogator")

func _run() -> void:
	print("======== Solar ASTROGATOR suite ========")
	root.get_viewport().size = VIEW
	# Headless fixed-fps burns IdleGuard's wall timers in seconds — disable.
	var idle := root.get_node_or_null("/root/IdleGuard")
	if idle == null:
		idle = root.get_node_or_null("IdleGuard")
	if idle != null and idle.has_method("set_active"):
		idle.call("set_active", false)
		print("IdleGuard disabled for suite")
	else:
		print("WARN: IdleGuard not found")
	paused = false
	Narrator.stop()
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	_out_abs = _qa_out_root().path_join(stamp)
	DirAccess.make_dir_recursive_absolute(_out_abs)
	_manifest = {
		"suite": "astrogator",
		"stamp": stamp,
		"viewport": {"w": VIEW.x, "h": VIEW.y},
		"shots": [],
		"checks": [],
		"agent_brief": _agent_brief(),
	}

	var cfg := SolarFlyerConfig.load_default()
	_check_every_destination_math(cfg)
	await _check_plotboard_ui(cfg)
	await _check_window_epoch_chart(cfg)
	await _check_flyscene_calendar(cfg)
	await _check_sim_view_cockpit(cfg)

	_manifest["checks"] = _checks
	FileAccess.open(_out_abs.path_join("report.json"), FileAccess.WRITE) \
		.store_string(JSON.stringify(_manifest, "\t"))
	var fails := 0
	for c in _checks:
		if not c.get("ok", false):
			fails += 1
	print("ASTROGATOR done → %s (%d shots, %d fails)" % [_out_abs, _shot_i, fails])
	quit(1 if fails > 0 else 0)

func _check_every_destination_math(cfg: SolarFlyerConfig) -> void:
	var earth := SolarData.flyer_body_by_id("earth", cfg)
	_check("earth_origin", not earth.is_empty(), "earth body")
	for b in SolarData.flyer_bodies(cfg):
		var id := str(b["id"])
		if id == "earth" or bool(b.get("belt", false)):
			continue
		if float(b.get("a_au", 0.0)) <= 0.0:
			# Sun / non-orbiting — budget must report not ok.
			var bad: Dictionary = RealismBudget.hop_budget(earth, b, 0.0)
			_check("%s_nearby_or_invalid" % id, not bool(bad.get("ok", true)),
				str(bad.get("error", "ok=%s" % bad.get("ok"))))
			continue
		var budget: Dictionary = RealismBudget.hop_budget(earth, b, 0.0)
		_check("%s_budget_ok" % id, bool(budget.get("ok", false)),
			"coast_yr=%.2f" % float(budget.get("coast_yr", -1)))
		if not bool(budget.get("ok", false)):
			continue
		var syn: float = float(budget.get("synodic_yr", 0.0))
		_check("%s_synodic_lt_12yr" % id, syn > 0.2 and syn < 12.0,
			"syn=%.2f yr (never a decade+ single-target lock)" % syn)
		var fuels: Dictionary = budget.get("fuels", {})
		var f_chem: float = float(fuels.get("chemical", {}).get("propellant_frac_mission", 1))
		var f_ntp: float = float(fuels.get("ntp", {}).get("propellant_frac_mission", 1))
		var f_orion: float = float(fuels.get("orion", {}).get("propellant_frac_mission", 1))
		_check("%s_fuel_order" % id, f_orion < f_ntp and f_ntp < f_chem,
			"chem=%.1f%% ntp=%.1f%% orion=%.1f%%" % [
				f_chem * 100.0, f_ntp * 100.0, f_orion * 100.0])
		if id in ["jupiter", "saturn", "uranus", "neptune"]:
			_check("%s_chemical_mostly_fuel" % id, f_chem >= 0.55,
				"chem=%.1f%% (STRATEGY mostly-fuel band)" % (f_chem * 100.0))

	var mars_b: Dictionary = RealismBudget.hop_budget(
		earth, SolarData.flyer_body_by_id("mars", cfg), 0.0)
	var jup_b: Dictionary = RealismBudget.hop_budget(
		earth, SolarData.flyer_body_by_id("jupiter", cfg), 0.0)
	_check("mars_synodic_~2.1",
		float(mars_b.get("synodic_yr", 0)) > 2.0
		and float(mars_b.get("synodic_yr", 0)) < 2.3,
		"syn=%.3f" % float(mars_b.get("synodic_yr", 0)))
	_check("jupiter_synodic_~1.1",
		float(jup_b.get("synodic_yr", 0)) > 0.95
		and float(jup_b.get("synodic_yr", 0)) < 1.25,
		"syn=%.3f" % float(jup_b.get("synodic_yr", 0)))

func _check_plotboard_ui(cfg: SolarFlyerConfig) -> void:
	var bg := Starfield.new()
	root.add_child(bg)
	var board: PlotBoard = PlotBoardScript.new()
	root.add_child(board)
	board.set_ship_at("earth")

	# Quick Course — ledger hidden.
	board.set_mission_mode(AstrogatorPanel.PACE_KID, AstrogatorPanel.PROP_CHEMICAL)
	board.begin_plot("mars")
	board.set_process(false)
	board._phase = PlotBoard.Phase.READY
	board._show_astrogator()
	board._go_btn.visible = true
	await _settle(2)
	_check("plot_kid_ledger_hidden", not board._astro.visible,
		"Quick Course hides rocket ledger")
	await _shot("mars_kid_pace", "PlotBoard Mars — Quick Course (no ledger)")

	# Rocket Science chemical — read-only ledger from pre-chart choice.
	board.set_mission_mode(AstrogatorPanel.PACE_ASTROGATOR, AstrogatorPanel.PROP_CHEMICAL)
	board.begin_plot("mars")
	board.finish_window_now()
	board.set_process(false)
	board._phase = PlotBoard.Phase.READY
	board._show_astrogator()
	board._go_btn.visible = true
	await _settle(2)
	_check("plot_astro_visible", board._astro.visible, "Rocket Science ledger shown")
	_check("plot_astro_locked", board._astro.locked, "engines locked before chart")
	_check("plot_ledger_has_coast", board._astro._ledger.text.contains("Coast"),
		board._astro._ledger.text)
	var chem_frac := AstrogatorPanel.fuel_frac_for(
		board._astro.budget, AstrogatorPanel.PROP_CHEMICAL)
	_check("plot_mars_chem_fuel", chem_frac > 0.4 and chem_frac < 0.85,
		"frac=%.2f" % chem_frac)
	await _shot("mars_chemical", "PlotBoard Mars Rocket Science — Chemical")

	board.set_mission_mode(AstrogatorPanel.PACE_ASTROGATOR, AstrogatorPanel.PROP_NTP)
	board.begin_plot("mars")
	board.finish_window_now()
	board.set_process(false)
	board._phase = PlotBoard.Phase.READY
	board._show_astrogator()
	await _settle(1)
	await _shot("mars_ntp", "PlotBoard Mars — Nuclear thermal")

	board.set_mission_mode(AstrogatorPanel.PACE_ASTROGATOR, AstrogatorPanel.PROP_ORION)
	board.begin_plot("mars")
	board.finish_window_now()
	board.set_process(false)
	board._phase = PlotBoard.Phase.READY
	board._show_astrogator()
	await _settle(1)
	var orion_frac := AstrogatorPanel.fuel_frac_for(
		board._astro.budget, AstrogatorPanel.PROP_ORION)
	_check("plot_mars_orion_less_fuel", orion_frac < chem_frac * 0.5,
		"orion=%.2f chem=%.2f" % [orion_frac, chem_frac])
	await _shot("mars_orion", "PlotBoard Mars — Nuclear pulse (less fuel)")

	board.set_mission_mode(AstrogatorPanel.PACE_ASTROGATOR, AstrogatorPanel.PROP_CHEMICAL)
	board.begin_plot("jupiter")
	board.finish_window_now()
	board.set_process(false)
	board._phase = PlotBoard.Phase.READY
	board._show_astrogator()
	board._go_btn.visible = true
	await _settle(2)
	_check("plot_jupiter_mostly_fuel",
		board._astro._ledger.text.contains("Most of this rocket is fuel"),
		board._astro._ledger.text)
	await _shot("jupiter_chemical", "PlotBoard Jupiter Chemical — mostly fuel")

	board.set_mission_mode(AstrogatorPanel.PACE_ASTROGATOR, AstrogatorPanel.PROP_ORION)
	board.begin_plot("jupiter")
	board.finish_window_now()
	board.set_process(false)
	board._phase = PlotBoard.Phase.READY
	board._show_astrogator()
	await _settle(1)
	await _shot("jupiter_orion", "PlotBoard Jupiter Nuclear pulse — ship-heavy")

	board._astro.stamp_route(board._route)
	_check("route_pace_stamped",
		str(board._route.get("pace_mode")) == AstrogatorPanel.PACE_ASTROGATOR,
		str(board._route.get("pace_mode")))
	_check("route_prop_stamped",
		str(board._route.get("propulsion_id")) == AstrogatorPanel.PROP_ORION,
		str(board._route.get("propulsion_id")))
	_check("route_realism_ok", bool(board._route.get("realism", {}).get("ok", false)),
		"realism stamped")

	board.queue_free()
	bg.queue_free()
	await _settle(2)

func _check_flyscene_calendar(cfg: SolarFlyerConfig) -> void:
	var bg := Starfield.new()
	root.add_child(bg)
	var fly: FlyScene = FlySceneScript.new()
	root.add_child(fly)
	fly.render_mode = NavModes.MODE_MARKERS
	fly.cinematic_enabled = false

	var origin := SolarData.flyer_body_by_id("earth", cfg)
	var dest := SolarData.flyer_body_by_id("mars", cfg)
	var depart := OrbitMath.orbit_standoff(float(origin.get("hero_r", 2.0)))
	var route := OrbitMath.plot_route(
		OrbitMath.body_pos(origin, 0.0), dest, 0.0, cfg, depart)
	var budget: Dictionary = RealismBudget.hop_budget(origin, dest, 0.0)
	route["pace_mode"] = AstrogatorPanel.PACE_ASTROGATOR
	route["propulsion_id"] = AstrogatorPanel.PROP_ORION
	route["realism"] = budget

	fly.set_active(true)
	fly.begin_flight("mars", route, 0.0)
	await _settle(4)
	# Freeze playback so coast probe is not raced by ASTRO_COAST_WALL_S skip.
	fly.set_process(false)
	fly.set_physics_process(false)
	fly._flying = true
	fly._orbiting = false
	_check("fly_astro_flag", fly._astro_coast, "astro_coast enabled")
	_check("fly_coast_bounds", fly._coast_path_u1 > fly._coast_path_u0 + 0.05,
		"u0=%.2f u1=%.2f" % [fly._coast_path_u0, fly._coast_path_u1])

	# Coast without BOOST — no calendar auto-skip.
	fly._play_u = (fly._coast_path_u0 + fly._coast_path_u1) * 0.5
	fly._place_ship_at_path(fly._play_u)
	fly._burn_phase = OrbitMath.PHASE_COAST
	fly._coast_skip_active = false
	fly._hud.set_burn_phase(OrbitMath.PHASE_COAST)
	fly._hud.pulse_boost_gold(2.0)
	fly._update_astro_calendar()
	await process_frame
	_check("fly_coast_no_auto_calendar", not fly._hud.calendar_visible(),
		"calendar hidden until BOOST")
	_check("fly_coast_skip_off", not fly._coast_skip_active, "skip not armed")
	await _shot("mars_coast_boost_invite",
		"Rocket Science coast — BOOST gold invite, no auto skip")

	# BOOST opts into calendar skip.
	fly._on_boost()
	fly._update_astro_calendar()
	await _settle(2)
	_check("fly_coast_skip_on", fly._coast_skip_active, "BOOST enabled skip")
	_check("fly_calendar_visible", fly._hud.calendar_visible(),
		"calendar after BOOST")
	_check("fly_calendar_text", fly._hud._calendar.text.contains("Coast calendar"),
		fly._hud._calendar.text)
	await _shot("mars_coast_calendar",
		"FlyScene coast after BOOST — calendar wipe")

	# Kid pace must NOT show calendar.
	fly.set_process(true)
	var route_kid := route.duplicate(true)
	route_kid["pace_mode"] = AstrogatorPanel.PACE_KID
	fly.begin_flight("mars", route_kid, 0.0)
	fly.set_process(false)
	fly.set_physics_process(false)
	fly._flying = true
	fly._orbiting = false
	fly._play_u = 0.5
	fly._place_ship_at_path(fly._play_u)
	fly._burn_phase = OrbitMath.PHASE_COAST
	fly._update_astro_calendar()
	await process_frame
	_check("fly_kid_no_calendar", not fly._hud.calendar_visible(),
		"Kid pace hides calendar")

	fly.queue_free()
	bg.queue_free()
	await _settle(2)

## Rocket Science charts at Hohmann t_depart after orrery wait; Quick Course stays now.
func _check_window_epoch_chart(cfg: SolarFlyerConfig) -> void:
	var bg := Starfield.new()
	root.add_child(bg)
	var board: PlotBoard = PlotBoardScript.new()
	root.add_child(board)
	board.set_ship_at("earth")

	# Quick Course — no window wait; chart at current epoch.
	board.set_mission_mode(AstrogatorPanel.PACE_KID, AstrogatorPanel.PROP_CHEMICAL)
	board.begin_plot("saturn")
	await _settle(2)
	_check("kid_no_window_phase", board._phase != PlotBoard.Phase.WINDOW,
		"phase=%s" % board._phase)
	_check("kid_window_wait_zero",
		is_equal_approx(float(board._route.get("window_wait_yr", -1.0)), 0.0),
		"wait=%s" % board._route.get("window_wait_yr"))
	await _shot("saturn_kid_now_chart", "Quick Course Saturn — chart at now (no window)")

	# Rocket Science Uranus — wait → chart at t_depart with bodies moved.
	board.set_mission_mode(AstrogatorPanel.PACE_ASTROGATOR, AstrogatorPanel.PROP_CHEMICAL)
	var earth := SolarData.flyer_body_by_id("earth", cfg)
	var uranus := SolarData.flyer_body_by_id("uranus", cfg)
	var t_before: float = board._bodies.t
	var pos_before: Vector3 = OrbitMath.body_pos(uranus, t_before)
	var phase0 := AstrogatorPanel.phase_now_rad(earth, uranus, t_before)
	var bud0: Dictionary = RealismBudget.hop_budget(earth, uranus, phase0)
	var expect_wait: float = float(bud0.get("window_wait_yr", 0.0))
	board.begin_plot("uranus")
	_check("astro_enters_window_or_charts",
		board._phase == PlotBoard.Phase.WINDOW or board._phase == PlotBoard.Phase.CHART,
		"phase=%s wait=%.3f" % [board._phase, expect_wait])
	if board._phase == PlotBoard.Phase.WINDOW:
		_check("window_guide_on", board._bodies.window_guide, "orrery WINDOW guide")
		_check("window_callout_on", board._window_callout.visible, "years callout")
		await _shot("uranus_window_wait", "Rocket Science — orrery wait-to-window")
		board.finish_window_now()
	await _settle(2)
	var t_depart: float = float(board._route.get("t_depart", -1.0))
	var wait_stamped: float = float(board._route.get("window_wait_yr", -1.0))
	_check("uranus_t_depart_stamped", t_depart >= 0.0, "t_depart=%s" % t_depart)
	_check("uranus_route_t0_is_depart",
		is_equal_approx(board._t0, t_depart),
		"t0=%.3f t_depart=%.3f" % [board._t0, t_depart])
	_check("uranus_wait_stamped",
		wait_stamped >= 0.0 and absf(wait_stamped - expect_wait) < 0.05,
		"stamped=%.3f expect=%.3f" % [wait_stamped, expect_wait])
	if expect_wait >= PlotBoard.WINDOW_MIN_YR:
		var pos_after: Vector3 = OrbitMath.body_pos(uranus, t_depart)
		_check("uranus_body_moved_for_window",
			pos_before.distance_to(pos_after) > 1.0,
			"d=%.2f (bodies at window epoch)" % pos_before.distance_to(pos_after))
	board.set_process(false)
	board._phase = PlotBoard.Phase.READY
	board._show_astrogator()
	await _settle(1)
	await _shot("uranus_window_charted", "Rocket Science Uranus — charted at window epoch")

	# Saturn window epoch similarly.
	board.set_mission_mode(AstrogatorPanel.PACE_ASTROGATOR, AstrogatorPanel.PROP_NTP)
	board.begin_plot("saturn")
	board.finish_window_now()
	_check("saturn_t_depart_stamped",
		float(board._route.get("t_depart", -1.0)) >= 0.0,
		"t_depart=%s" % board._route.get("t_depart"))
	_check("saturn_crossings_include_jupiter",
		board._bodies.crossing_ids.has("jupiter"),
		"crossings=%s" % ",".join(board._bodies.crossing_ids))
	_check("saturn_crossings_include_mars",
		board._bodies.crossing_ids.has("mars"),
		"crossings=%s" % ",".join(board._bodies.crossing_ids))
	# All planets advance with trip clock during preview (not dest-only).
	board._bodies.ship_preview_u = 0.55
	board._bodies.ff_u = 1.0
	var mars := SolarData.flyer_body_by_id("mars", cfg)
	var jup := SolarData.flyer_body_by_id("jupiter", cfg)
	var mars_t0 := OrbitMath.body_pos(mars, board._bodies.t0)
	var mars_mid := OrbitMath.body_pos(mars, board._bodies._body_time(mars))
	var jup_t0 := OrbitMath.body_pos(jup, board._bodies.t0)
	var jup_mid := OrbitMath.body_pos(jup, board._bodies._body_time(jup))
	_check("plot_mars_moves_with_trip",
		mars_t0.distance_to(mars_mid) > 0.5,
		"d=%.2f" % mars_t0.distance_to(mars_mid))
	_check("plot_jupiter_moves_with_trip",
		jup_t0.distance_to(jup_mid) > 0.5,
		"d=%.2f" % jup_t0.distance_to(jup_mid))
	var cross_u: float = board._bodies._course_orbit_cross_u(
		board._route["curve"],
		maxf(float(board._route.get("path_len", 1.0)), 0.001),
		float(jup.get("orbit_r", 0.0)))
	_check("saturn_course_crosses_jupiter_orbit",
		cross_u > 0.05 and cross_u < 0.95,
		"cross_u=%.2f" % cross_u)
	board._bodies.course_draw_u = 1.0
	await _shot("saturn_window_charted", "Rocket Science Saturn — charted at window")

	board.queue_free()
	bg.queue_free()
	await _settle(2)

## SIM_VIEW cockpit: peer Jupiter stays small; Neptune looms; kid stays MARKERS.
func _check_sim_view_cockpit(cfg: SolarFlyerConfig) -> void:
	var bg := Starfield.new()
	root.add_child(bg)
	var fly: FlyScene = FlySceneScript.new()
	root.add_child(fly)
	fly.cinematic_enabled = false

	# Earth→Saturn Rocket Science SIM_VIEW mid-cruise: Jupiter peer << glass fill.
	var origin := SolarData.flyer_body_by_id("earth", cfg)
	var saturn := SolarData.flyer_body_by_id("saturn", cfg)
	var depart := OrbitMath.orbit_standoff(float(origin.get("hero_r", 2.0)))
	var t_depart: float = 0.0
	var phase_s := AstrogatorPanel.phase_now_rad(origin, saturn, 0.0)
	var bud_s: Dictionary = RealismBudget.hop_budget(origin, saturn, phase_s)
	if bool(bud_s.get("ok", false)):
		t_depart = float(bud_s.get("window_wait_yr", 0.0)) * cfg.game_year_seconds
	var route_sat := OrbitMath.plot_route(
		OrbitMath.park_pos(origin, t_depart, cfg, OrbitMath.body_pos(saturn, t_depart)),
		saturn, t_depart, cfg, depart)
	route_sat["pace_mode"] = AstrogatorPanel.PACE_ASTROGATOR
	route_sat["propulsion_id"] = AstrogatorPanel.PROP_CHEMICAL
	route_sat["realism"] = bud_s
	route_sat["t_depart"] = t_depart
	fly.render_mode = NavModes.MODE_SIM_VIEW
	fly.set_active(true)
	fly.begin_flight("saturn", route_sat, t_depart)
	fly.set_process(false)
	fly.set_physics_process(false)
	fly._flying = true
	fly._orbiting = false
	fly._play_u = 0.45
	fly._place_ship_at_path(fly._play_u)
	fly._clock = t_depart + float(route_sat.get("duration", 20.0)) * 0.45
	fly._place_bodies_at(fly._clock)
	fly._render_bodies()
	await _settle(2)
	var jup_px: float = fly.debug_sim_angular_radius_px("jupiter")
	_check("peer_jupiter_not_collision",
		jup_px < FlyScene.SIM_PEER_MAX_PX + 0.01 and jup_px < 40.0,
		"jupiter_px=%.2f (must stay << glass fill)" % jup_px)
	await _shot("saturn_mid_peer_jupiter",
		"SIM_VIEW mid-cruise — Jupiter peer angular size")

	# Neptune approach / orbit loom.
	var neptune := SolarData.flyer_body_by_id("neptune", cfg)
	var bud_n: Dictionary = RealismBudget.hop_budget(
		origin, neptune, AstrogatorPanel.phase_now_rad(origin, neptune, 0.0))
	var t_n: float = 0.0
	if bool(bud_n.get("ok", false)):
		t_n = float(bud_n.get("window_wait_yr", 0.0)) * cfg.game_year_seconds
	var route_n := OrbitMath.plot_route(
		OrbitMath.park_pos(origin, t_n, cfg, OrbitMath.body_pos(neptune, t_n)),
		neptune, t_n, cfg, depart)
	route_n["pace_mode"] = AstrogatorPanel.PACE_ASTROGATOR
	route_n["propulsion_id"] = AstrogatorPanel.PROP_ORION
	route_n["realism"] = bud_n
	fly.begin_flight("neptune", route_n, t_n)
	fly.set_process(false)
	fly.set_physics_process(false)
	fly._flying = true
	fly._orbiting = false
	fly._play_u = 0.97
	fly._place_ship_at_path(fly._play_u)
	fly._clock = t_n + float(route_n.get("duration", 20.0)) * 0.97
	fly._place_bodies_at(fly._clock)
	fly._render_bodies()
	await process_frame
	var nep_approach_px: float = fly.debug_sim_angular_radius_px("neptune")
	_check("neptune_approach_not_pin",
		nep_approach_px > 8.0,
		"neptune_approach_px=%.2f (must loom, not stuck pin)" % nep_approach_px)
	await _shot("neptune_approach_loom", "SIM_VIEW Neptune late approach loom")

	fly._enter_orbit_from_timeline()
	fly._render_bodies()
	await _settle(2)
	var nep_orbit_px: float = fly.debug_sim_angular_radius_px("neptune")
	_check("neptune_orbit_looms",
		nep_orbit_px > 40.0,
		"neptune_orbit_px=%.2f (park disc must dominate glass)" % nep_orbit_px)
	await _shot("neptune_orbit_loom", "SIM_VIEW Neptune orbit — large true-angle disc")

	# Quick Course regression — MARKERS path (not forced SIM_VIEW).
	var route_kid := OrbitMath.plot_route(
		OrbitMath.body_pos(origin, 0.0), saturn, 0.0, cfg, depart)
	route_kid["pace_mode"] = AstrogatorPanel.PACE_KID
	fly.render_mode = NavModes.MODE_MARKERS
	fly.begin_flight("saturn", route_kid, 0.0)
	fly.set_process(false)
	fly._flying = true
	fly._orbiting = false
	fly._play_u = 0.5
	fly._place_ship_at_path(fly._play_u)
	fly._render_bodies()
	await process_frame
	_check("kid_markers_mode", fly.render_mode == NavModes.MODE_MARKERS,
		"mode=%s" % fly.render_mode)
	# Destination still uses marker/icon path (sphere only on flyby handoff).
	var dest_info: Dictionary = fly._body_nodes.get("saturn", {})
	_check("kid_markers_icons_exist", not dest_info.is_empty(), "saturn node")
	await _shot("saturn_kid_markers", "Quick Course MARKERS mid-cruise regression")

	fly.queue_free()
	bg.queue_free()
	await _settle(2)

func _shot(id: String, note: String) -> void:
	paused = false
	print(" shot… ", id)
	await _settle(4)
	var file := "%02d_%s.png" % [_shot_i, id]
	var tex: ViewportTexture = root.get_viewport().get_texture()
	var img: Image = tex.get_image() if tex != null else null
	if img:
		img.save_png(_out_abs.path_join(file))
	_manifest["shots"].append({"file": file, "id": id, "note": note})
	_shot_i += 1
	print(" shot ", file)

func _settle(n: int) -> void:
	for _i in n:
		await process_frame

func _check(name: String, ok: bool, detail: String) -> void:
	_checks.append({"name": name, "ok": ok, "detail": detail})
	print(("OK  " if ok else "FAIL"), " ", name, " — ", detail)

func _agent_brief() -> String:
	return ("Astrogator cockpit POV. Math: synodic <12 yr, orion<ntp<chemical. "
		+ "Window chart at t_depart; SIM_VIEW peer Jupiter << fill; Neptune looms; "
		+ "Quick Course MARKERS unchanged. FAIL = fix PlotBoard / FlyScene / RealismBudget.")

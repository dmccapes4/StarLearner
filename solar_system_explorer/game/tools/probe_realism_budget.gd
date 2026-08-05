extends SceneTree
## Phase A realism budget probe — Hohmann Δv, fuel fractions, synodic windows.
##
##   godot --headless --path game -s res://tools/probe_realism_budget.gd
##   ./tools/run_realism_budget.sh
##
## Writes qa/out/realism_budget/<stamp>/report.json and exits 1 on assert fail.
## See docs/STRATEGY_REAL_ROCKET_SCIENCE.md §5 Phase A.

const HOPS := [
	{"from": "earth", "to": "mercury"},
	{"from": "earth", "to": "venus"},
	{"from": "earth", "to": "mars"},
	{"from": "earth", "to": "asteroid_belt"},
	{"from": "earth", "to": "jupiter"},
	{"from": "earth", "to": "saturn"},
	{"from": "earth", "to": "uranus"},
	{"from": "earth", "to": "neptune"},
	{"from": "jupiter", "to": "mars"},
]

func _init() -> void:
	call_deferred("_run")

func _qa_out_root() -> String:
	var game_dir := ProjectSettings.globalize_path("res://").rstrip("/")
	return game_dir.get_base_dir().path_join("qa/out/realism_budget")

func _run() -> void:
	print("======== RealismBudget Phase A ========")
	var cfg := SolarFlyerConfig.load_default()
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	var out_abs := _qa_out_root().path_join(stamp)
	DirAccess.make_dir_recursive_absolute(out_abs)

	var hops: Array = []
	print("")
	print("%-10s → %-14s  syn_yr  wait_yr  coast_yr  dv_helio  dv_dep   dv_msn   chem%%  ntp%%  orion%%" % [
		"from", "to"])
	for trip in HOPS:
		var origin := SolarData.flyer_body_by_id(str(trip["from"]), cfg)
		var dest := SolarData.flyer_body_by_id(str(trip["to"]), cfg)
		var b: Dictionary = RealismBudget.hop_budget(origin, dest, 0.0)
		hops.append(b)
		if not bool(b.get("ok", false)):
			print("%-10s → %-14s  SKIP %s" % [trip["from"], trip["to"], b.get("error", "?")])
			continue
		var fuels: Dictionary = b["fuels"]
		print("%-10s → %-14s  %6.2f  %7.2f  %7.2f  %7.2f  %6.2f  %6.2f  %5.1f  %5.1f  %6.1f" % [
			b["from"], b["to"],
			float(b["synodic_yr"]),
			float(b["window_wait_yr"]),
			float(b["coast_yr"]),
			float(b["dv_heliocentric_total_km_s"]),
			float(b["dv_depart_burn_km_s"]),
			float(b["dv_mission_km_s"]),
			float(fuels["chemical"]["propellant_frac_mission"]) * 100.0,
			float(fuels["ntp"]["propellant_frac_mission"]) * 100.0,
			float(fuels["orion"]["propellant_frac_mission"]) * 100.0,
		])

	print("")
	print("-- Phase A asserts --")
	var checks: Array = RealismBudget.phase_a_checks()
	# Also assert SolarData periods feed the same Mars/Jupiter windows.
	var earth := SolarData.flyer_body_by_id("earth", cfg)
	var mars := SolarData.flyer_body_by_id("mars", cfg)
	var jupiter := SolarData.flyer_body_by_id("jupiter", cfg)
	var mars_syn := RealismBudget.synodic_years(
		float(earth["period_yr"]), float(mars["period_yr"]))
	var jup_syn := RealismBudget.synodic_years(
		float(earth["period_yr"]), float(jupiter["period_yr"]))
	checks.append({
		"name": "solardata_mars_synodic",
		"ok": mars_syn > 2.0 and mars_syn < 2.3,
		"detail": "SolarData earth/mars syn=%.3f" % mars_syn,
	})
	checks.append({
		"name": "solardata_jupiter_synodic",
		"ok": jup_syn > 1.0 and jup_syn < 1.2,
		"detail": "SolarData earth/jupiter syn=%.3f" % jup_syn,
	})

	var fails := 0
	for c in checks:
		var ok: bool = bool(c.get("ok", false))
		if not ok:
			fails += 1
		print("%s %s — %s" % [("OK  " if ok else "FAIL"), c.get("name"), c.get("detail")])

	var report := {
		"suite": "realism_budget",
		"phase": "A",
		"stamp": stamp,
		"isp_s": RealismBudget.PROPULSION,
		"hops": hops,
		"checks": checks,
		"agent_brief": "Phase A discovery math only — no kid UI. FAIL means synodic/Δv/fuel math drifted from STRATEGY_REAL_ROCKET_SCIENCE.md. Jupiter synodic must stay ~1.1 yr (never a 12+ yr single-target lock).",
	}
	var report_path := out_abs.path_join("report.json")
	FileAccess.open(report_path, FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("")
	print("report → %s" % report_path)
	print("======== %s (%d fails) ========" % [
		"PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)

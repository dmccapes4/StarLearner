extends SceneTree
## One-shot probe: for each capture trip, print path length, flown duration
## (clamped) vs orbital-clock t_arr, and how far the destination sweeps during
## the hop — the numbers behind the speed/honesty tuning pass.
##   godot --headless --path . -s res://tools/probe_trip_timing.gd

const TRIPS := [
	{"from": "earth", "to": "mercury"},
	{"from": "earth", "to": "mars"},
	{"from": "earth", "to": "asteroid_belt"},
	{"from": "earth", "to": "jupiter"},
	{"from": "earth", "to": "saturn"},
	{"from": "earth", "to": "neptune"},
	{"from": "jupiter", "to": "mars"},
]

func _init() -> void:
	var cfg := SolarFlyerConfig.load_default()
	print("burn_accel=%.2f u/s²  v_max=%.1f u/s  band=[%.0f, %.0f] s  game_year=%.0f s" % [
		cfg.burn_accel, cfg.v_max, cfg.hop_min_s, cfg.hop_max_s, cfg.game_year_seconds])
	for trip in TRIPS:
		var origin := SolarData.flyer_body_by_id(trip["from"], cfg)
		var dest := SolarData.flyer_body_by_id(trip["to"], cfg)
		var ship := OrbitMath.body_pos(origin, 0.0)
		var standoff := OrbitMath.orbit_standoff(float(origin.get("hero_r", 2.0)))
		var route := OrbitMath.plot_route(ship, dest, 0.0, cfg, standoff)
		var dur: float = float(route["duration"])
		var t_arr: float = float(route["t_arr"])
		var omega: float = float(dest.get("omega", 0.0))
		var sweep_deg: float = rad_to_deg(omega * t_arr)
		print("%-10s -> %-14s len=%6.1f  duration=%5.1fs  t_arr=%5.1fs  clamp_gap=%5.1fs  dest_sweep=%5.1f deg" % [
			trip["from"], trip["to"], float(route["path_len"]), dur, t_arr,
			dur - t_arr, sweep_deg])
	quit(0)

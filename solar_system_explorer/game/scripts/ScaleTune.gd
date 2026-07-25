class_name ScaleTune
extends RefCounted
## Phase 4 — happy-medium checks for SolarFlyerConfig (§3.4 / §23).
## Pure functions over OrbitMath; unit-tested headlessly.

## Evaluate the shipped (or candidate) knobs. Returns:
##   ok: bool
##   issues: PackedStringArray
##   hops: Array of per-destination metric dicts
static func evaluate(cfg: SolarFlyerConfig) -> Dictionary:
	var issues: PackedStringArray = []
	if cfg == null:
		return {"ok": false, "issues": PackedStringArray(["cfg is null"]), "hops": []}

	if cfg.mesh_in >= cfg.mesh_out:
		issues.append("mesh_in must be < mesh_out (LOD hysteresis)")
	if cfg.focus_dist <= 0.0:
		issues.append("focus_dist must be > 0")
	if cfg.cruise_speed <= 0.0:
		issues.append("cruise_speed must be > 0")
	if cfg.burn_accel <= 0.0:
		issues.append("burn_accel must be > 0")
	if cfg.v_max <= 0.0:
		issues.append("v_max must be > 0")
	if cfg.hop_min_s >= cfg.hop_max_s:
		issues.append("hop_min_s must be < hop_max_s")
	if cfg.compression_exp <= 0.0 or cfg.compression_exp > 1.0:
		issues.append("compression_exp should be in (0, 1]")
	if cfg.belt_fade_near >= cfg.belt_fade_far:
		issues.append("belt_fade_near must be < belt_fade_far (rock reveal band)")
	if cfg.belt_cull_dist <= cfg.belt_fade_far:
		issues.append("belt_cull_dist must exceed belt_fade_far or rocks pop")
	# Focus bubble should engage before mesh turns off.
	if cfg.focus_dist > cfg.mesh_out:
		issues.append("focus_dist > mesh_out — bloom finishes after mesh hides")

	var by_id := {}
	for b in SolarData.flyer_bodies(cfg):
		by_id[str(b["id"])] = b

	# Ordering preserved under compression (major asteroids straddle the ring).
	var order := ["mercury", "venus", "earth", "mars", "vesta", "asteroid_belt",
		"ceres", "psyche", "jupiter", "saturn", "uranus", "neptune", "pluto"]
	for i in order.size() - 1:
		var a: float = float(by_id[order[i]]["orbit_r"])
		var c: float = float(by_id[order[i + 1]]["orbit_r"])
		if a >= c:
			issues.append("orbit order broken: %s >= %s" % [order[i], order[i + 1]])

	# Plot board auto-zooms (OrreryBodies._refit_board_scale, floor 0.72) — the
	# farthest orbit must fit the fit budget at that minimum zoom.
	var nep_r: float = float(by_id["neptune"]["orbit_r"])
	if nep_r * 0.72 > 280.0:
		issues.append("Neptune orbit too wide even at min plot zoom (%.0f px)" % (nep_r * 0.72))
	if float(by_id["jupiter"]["hero_r"]) <= float(by_id["mercury"]["hero_r"]):
		issues.append("Jupiter hero_r must beat Mercury")

	var earth: Dictionary = by_id["earth"]
	var ship := OrbitMath.body_pos(earth, 0.0)
	var hops: Array = []
	var dur_min := INF
	var dur_max := 0.0
	var outer_bloom_ok := 0
	var outer_total := 0

	for b in SolarData.flyer_destinations(cfg):
		if str(b["id"]) == "earth" or bool(b.get("is_star", false)):
			continue
		var sweep := OrbitMath.sweep_bodies_for("earth", str(b["id"]), cfg)
		var route := OrbitMath.plot_route(ship, b, 0.0, cfg, 0.0, sweep)
		var dur: float = float(route["duration"])
		var plen: float = float(route["path_len"])
		# Collision contract: the refined course clears every swept world.
		for s in route.get("sweeps", []):
			if str(s["class"]) == "conflict":
				issues.append("%s hop conflicts with %s (sep %.1f < clear %.1f)" % [
					b["id"], s["id"], float(s["min_sep"]), float(s["clearance"])])
		dur_min = minf(dur_min, dur)
		dur_max = maxf(dur_max, dur)
		if dur < cfg.hop_min_s - 0.05 or dur > cfg.hop_max_s + 0.05:
			issues.append("%s hop duration %.1fs outside [%s,%s] — tune burn_accel/v_max" % [
				b["id"], dur, cfg.hop_min_s, cfg.hop_max_s])
		# Honesty invariant: the flown wall-clock and the orbital clock agree.
		if absf(dur - float(route["t_arr"])) > 0.01:
			issues.append("%s duration != t_arr (clock mismatch)" % b["id"])

		var bloom_u := bloom_progress(route["curve"], b, 0.0, float(route["t_arr"]), cfg, 0.55)
		var d_mid := OrbitMath.ship_to_dest_dist(
			route["curve"], 0.45, b, 0.0, float(route["t_arr"]))
		var app_mid := OrbitMath.apparent_size(d_mid, float(b["hero_r"]), cfg)
		var d_end := OrbitMath.ship_to_dest_dist(
			route["curve"], 1.0, b, 0.0, float(route["t_arr"]))
		var app_end := OrbitMath.apparent_size(maxf(d_end, 0.01), float(b["hero_r"]), cfg)

		var hop := {
			"id": str(b["id"]),
			"path_len": plen,
			"duration": dur,
			"bloom_u": bloom_u,
			"app_mid": app_mid,
			"app_end": app_end,
			"hero_r": float(b["hero_r"]),
		}
		hops.append(hop)

		# Outer worlds should stay "dotty" mid-cruise then bloom late.
		if str(b["id"]) in ["jupiter", "saturn", "uranus", "neptune", "pluto"]:
			outer_total += 1
			if bloom_u >= 0.50:
				outer_bloom_ok += 1
			if app_end < float(b["hero_r"]) * 0.8:
				issues.append("%s does not reach hero bloom at arrival" % b["id"])

	if outer_total > 0 and outer_bloom_ok < 3:
		issues.append("fewer than 3 outer hops bloom after mid-cruise (got %d)" % outer_bloom_ok)

	# Duration variety: burn-profile times must spread with distance.
	if dur_max - dur_min < 5.0 and hops.size() >= 6:
		issues.append("hop durations lack variety (span %.1fs)" % (dur_max - dur_min))

	return {"ok": issues.is_empty(), "issues": issues, "hops": hops}


## Progress ratio where apparent size first reaches `frac` of hero_r (1.0 if never).
static func bloom_progress(curve: Curve3D, dest: Dictionary, t0: float, t_arr: float,
		cfg: SolarFlyerConfig, frac: float = 0.55) -> float:
	var hero: float = float(dest.get("hero_r", 1.0))
	var target: float = hero * frac
	var steps := 40
	for i in steps + 1:
		var u := float(i) / float(steps)
		var d := OrbitMath.ship_to_dest_dist(curve, u, dest, t0, t_arr)
		var app := OrbitMath.apparent_size(maxf(d, 0.001), hero, cfg)
		if app >= target:
			return u
	return 1.0


## Apply a flat Dictionary of overrides onto a config (JSON overlay).
static func apply_overrides(cfg: SolarFlyerConfig, data: Dictionary) -> void:
	if cfg == null or data.is_empty():
		return
	for k in SolarFlyerConfig.OVERRIDE_KEYS:
		if not data.has(k):
			continue
		var v = data[k]
		if typeof(v) == TYPE_BOOL:
			cfg.set(k, v)
		else:
			cfg.set(k, float(v))

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

	if cfg.icon_scale <= 0.0:
		issues.append("icon_scale must be > 0 (far-visibility angular floor)")
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

	for b in SolarData.flyer_destinations(cfg):
		if str(b["id"]) == "earth" or bool(b.get("is_star", false)):
			continue
		var route := OrbitMath.plot_route(ship, b, 0.0, cfg, 0.0)
		var dur: float = float(route["duration"])
		var plen: float = float(route["path_len"])
		dur_min = minf(dur_min, dur)
		dur_max = maxf(dur_max, dur)
		if dur < cfg.hop_min_s - 0.05 or dur > cfg.hop_max_s + 0.05:
			issues.append("%s hop duration %.1fs outside [%s,%s] — tune burn_accel/v_max" % [
				b["id"], dur, cfg.hop_min_s, cfg.hop_max_s])
		# Honesty invariant: the flown wall-clock and the orbital clock agree.
		if absf(dur - float(route["t_arr"])) > 0.01:
			issues.append("%s duration != t_arr (clock mismatch)" % b["id"])

		var d_end := OrbitMath.ship_to_dest_dist(
			route["curve"], 1.0, b, 0.0, float(route["t_arr"]))

		var hop := {
			"id": str(b["id"]),
			"path_len": plen,
			"duration": dur,
			"d_end": d_end,
			"hero_r": float(b["hero_r"]),
		}
		hops.append(hop)

		# Parking honesty: the course must END on the destination's parking
		# sphere (orbit entry is the timeline's last frame, never a dive).
		var park := OrbitMath.orbit_standoff(float(b["hero_r"]))
		if absf(d_end - park) > 1.5:
			issues.append("%s course does not end at the parking standoff (%.1f vs %.1f)" % [
				b["id"], d_end, park])

	# Duration variety: burn-profile times must spread with distance.
	if dur_max - dur_min < 5.0 and hops.size() >= 6:
		issues.append("hop durations lack variety (span %.1fs)" % (dur_max - dur_min))

	return {"ok": issues.is_empty(), "issues": issues, "hops": hops}


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

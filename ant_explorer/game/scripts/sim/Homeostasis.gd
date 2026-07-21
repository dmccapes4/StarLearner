class_name Homeostasis
extends RefCounted
## Colony pressure controller — the feedback nerve of the sim.
##
## Every tick it takes a census of the colony (adult caste counts, brood, garden,
## invaders) and turns shortages/surpluses into signals that actually bend
## behaviour:
##   • food / care / defense / waste demand  → task urgency (bias_forager / bias_nurse)
##   • per-caste pressure vs. steady-state targets → caste destiny at pupation
##     and how much juvenile hormone nurses dose (the caste-mix loop).
##
## The loop the whole larval-space thesis rests on — "the shortage feeds back
## through delivery" — is closed here: e.g. a soldier SURPLUS raises the soldier
## caste threshold and lowers JH dosing, so fewer of the next larvae become
## soldiers, and the colony self-corrects toward its target mix.
##
## Pressure convention: +1 = deep DEFICIT (want more of this caste),
##                       -1 = big SURPLUS (want fewer). 0 = at target.

enum Demand { FOOD, CARE, DEFENSE, WASTE, NONE }

## Runtime gate. Synced from Config.data.homeo_enabled each tick so a single
## config flag is the product kill-switch (false → fixed-ratio colony).
var enabled: bool = true

# Scalar demands (0..1).
var food_demand: float = 0.0
var care_demand: float = 0.0
var defense_demand: float = 0.0
var waste_demand: float = 0.0

# Live census (adults).
var soldiers: int = 0
var foragers: int = 0
var gardeners: int = 0
var nurses: int = 0
var minors: int = 0  ## gardeners + nurses (the "minor worker" pool)
var brood_count: int = 0

# Per-caste pressure (−1 surplus .. +1 deficit) vs. Config targets.
var soldier_pressure: float = 0.0
var forager_pressure: float = 0.0
var minor_pressure: float = 0.0

func tick(colony: Colony) -> void:
	# Product kill-switch lives in config.tres — re-read so a mid-session flip works.
	if Config != null and Config.data != null:
		enabled = Config.data.homeo_enabled
	if not enabled or colony == null:
		return
	_census(colony)

	var g: float = colony.garden.health if colony.garden else 0.75
	food_demand = clampf((0.65 - g) * 2.0, 0.0, 1.0)

	brood_count = colony.brood.living_brood() if colony.brood else 0
	var care_need := float(brood_count) / maxf(1.0, float(nurses) * 3.0)
	care_demand = clampf(care_need - 0.5, 0.0, 1.0)

	defense_demand = 1.0 if colony.invaders != null and colony.invaders.active_count() > 0 else 0.0
	waste_demand = clampf((colony.garden.waste if colony.garden else 0.0) * 2.0, 0.0, 1.0)

	soldier_pressure = _pressure(soldiers, Config.data.target_soldiers)
	forager_pressure = _pressure(foragers, Config.data.target_foragers)
	minor_pressure = _pressure(minors, Config.data.target_minors)

func _census(colony: Colony) -> void:
	soldiers = 0
	foragers = 0
	gardeners = 0
	nurses = 0
	for a in colony.ants:
		if a == null or not a.alive:
			continue
		match a.caste:
			AntEnums.Caste.SOLDIER:
				soldiers += 1
			AntEnums.Caste.FORAGER:
				foragers += 1
			AntEnums.Caste.GARDENER:
				gardeners += 1
			AntEnums.Caste.NURSE:
				nurses += 1
	minors = gardeners + nurses

## Signed, normalised gap between a target headcount and the live count.
## +1 = wholly absent (max deficit); −1 = at/above double the target (max surplus).
static func _pressure(count: int, target: int) -> float:
	if target <= 0:
		return 0.0
	return clampf(float(target - count) / float(target), -1.0, 1.0)

func primary_demand() -> int:
	var best := Demand.NONE
	var score := 0.15
	if food_demand > score:
		score = food_demand
		best = Demand.FOOD
	if care_demand > score:
		score = care_demand
		best = Demand.CARE
	if defense_demand > score:
		score = defense_demand
		best = Demand.DEFENSE
	if waste_demand > score:
		score = waste_demand
		best = Demand.WASTE
	return best

func bias_forager() -> bool:
	return primary_demand() == Demand.FOOD or food_demand > 0.4

func bias_nurse() -> bool:
	return primary_demand() == Demand.CARE or care_demand > 0.4

# --- caste-mix feedback (consumed by Brood.decide_caste + the nurse JH dose) ---

## How oversupplied soldiers are, 0 (none) .. 1 (max surplus).
func soldier_surplus() -> float:
	return clampf(-soldier_pressure, 0.0, 1.0)

## Score thresholds for `decide_caste`, shifted by current colony pressure.
## Deficit (pressure > 0) LOWERS a caste's threshold (make more of it); surplus
## RAISES it (make fewer). Returns {"high": float, "mid": float} with high > mid.
func caste_thresholds() -> Dictionary:
	var strength: float = Config.data.homeo_caste_bias_strength
	var base_high: float = Config.data.caste_destiny_high
	var base_mid: float = Config.data.caste_destiny_mid
	var high := base_high - soldier_pressure * strength
	var mid := base_mid - forager_pressure * strength
	# Keep the ordering + a sane spread no matter how extreme the pressures are.
	high = clampf(high, base_mid + 1.0, base_high + strength + 4.0)
	mid = clampf(mid, base_mid - strength, high - 2.0)
	return {"high": high, "mid": mid}

## Multiplier on juvenile-hormone dosing. Soldier surplus → dose less JH (JH
## pushes larvae toward soldier); soldier deficit → dose more. Range is
## symmetric around 1.0 by `homeo_jh_bias_strength`.
func jh_dose_scale() -> float:
	var s: float = Config.data.homeo_jh_bias_strength
	return clampf(1.0 + soldier_pressure * s, 1.0 - s, 1.0 + s)

## Extra idle-tick reduction for an idling worker whose caste is in demand, so a
## shortage visibly speeds that caste back to work. Returns ticks to shave off.
func idle_urgency(caste: int) -> int:
	match caste:
		AntEnums.Caste.FORAGER:
			if bias_forager():
				return int(round(6.0 * clampf(maxf(food_demand, forager_pressure), 0.0, 1.0)))
		AntEnums.Caste.NURSE:
			if bias_nurse():
				return int(round(6.0 * clampf(maxf(care_demand, minor_pressure), 0.0, 1.0)))
		AntEnums.Caste.GARDENER:
			if food_demand > 0.4:
				return int(round(4.0 * food_demand))
	return 0

func snapshot() -> Dictionary:
	return {
		"food": food_demand, "care": care_demand,
		"defense": defense_demand, "waste": waste_demand,
		"soldiers": soldiers, "foragers": foragers, "minors": minors,
		"soldier_pressure": soldier_pressure,
		"forager_pressure": forager_pressure,
		"minor_pressure": minor_pressure,
	}

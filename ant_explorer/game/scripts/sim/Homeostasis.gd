class_name Homeostasis
extends RefCounted
## Nudges task demand when the colony is short on food, nurses, or defense.

enum Demand { FOOD, CARE, DEFENSE, WASTE, NONE }

var enabled: bool = true
var food_demand: float = 0.0
var care_demand: float = 0.0
var defense_demand: float = 0.0
var waste_demand: float = 0.0

func tick(colony: Colony) -> void:
	if not enabled or colony == null:
		return
	var g: float = colony.garden.health if colony.garden else 0.75
	food_demand = clampf((0.65 - g) * 2.0, 0.0, 1.0)
	var brood_n := colony.brood.living_brood() if colony.brood else 0
	var nurses := 0
	var foragers := 0
	var soldiers := 0
	for a in colony.ants:
		if a == null or not a.alive:
			continue
		match a.caste:
			AntEnums.Caste.NURSE:
				nurses += 1
			AntEnums.Caste.FORAGER:
				foragers += 1
			AntEnums.Caste.SOLDIER:
				soldiers += 1
	var care_need := float(brood_n) / maxf(1.0, float(nurses) * 3.0)
	care_demand = clampf(care_need - 0.5, 0.0, 1.0)
	defense_demand = 1.0 if colony.invaders != null and colony.invaders.active_count() > 0 else 0.0
	waste_demand = clampf((colony.garden.waste if colony.garden else 0.0) * 2.0, 0.0, 1.0)

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
		best = Demand.WASTE
	return best

func bias_forager() -> bool:
	return primary_demand() == Demand.FOOD or food_demand > 0.4

func bias_nurse() -> bool:
	return primary_demand() == Demand.CARE or care_demand > 0.4

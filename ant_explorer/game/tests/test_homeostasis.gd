extends RefCounted
## Homeostasis: census, pressures, and the caste-mix feedback loop actually
## bending decide_caste + JH dosing. This is the wire the review flagged as
## unterminated — these tests assert it is now connected.

var _tree: Node

func _init(tree: Node) -> void:
	_tree = tree

func run() -> TestAssert:
	var t := TestAssert.new("Homeostasis")
	t.ok(Config.data.homeo_enabled, "shipped config: homeo_enabled=true (real algorithm)")
	t.ok(Homeostasis.new().enabled, "Homeostasis defaults enabled")
	_test_pressure_math(t)
	_test_thresholds_shift(t)
	_test_jh_scale(t)
	_test_idle_urgency(t)
	_test_census_and_demand(t)
	_test_surplus_lowers_soldier_rate(t)
	return t

func _test_pressure_math(t: TestAssert) -> void:
	# +1 = wholly absent (deficit); −1 = at/above double the target (surplus).
	t.approx(Homeostasis._pressure(0, 14), 1.0, 0.001, "empty caste = max deficit")
	t.approx(Homeostasis._pressure(14, 14), 0.0, 0.001, "at target = no pressure")
	t.approx(Homeostasis._pressure(28, 14), -1.0, 0.001, "double target = max surplus")
	t.lt(Homeostasis._pressure(20, 14), 0.0, "over target → surplus (negative)")
	t.gt(Homeostasis._pressure(5, 14), 0.0, "under target → deficit (positive)")

func _test_thresholds_shift(t: TestAssert) -> void:
	var base_high: float = Config.data.caste_destiny_high
	var h := Homeostasis.new()

	h.soldier_pressure = 0.0
	h.forager_pressure = 0.0
	var neutral: Dictionary = h.caste_thresholds()
	t.approx(neutral["high"], base_high, 0.001, "neutral soldier pressure keeps base high threshold")

	h.soldier_pressure = -1.0  # big soldier surplus
	var surplus: Dictionary = h.caste_thresholds()
	t.gt(surplus["high"], neutral["high"], "soldier surplus RAISES soldier threshold (fewer soldiers)")

	h.soldier_pressure = 1.0  # soldier deficit
	var deficit: Dictionary = h.caste_thresholds()
	t.lt(deficit["high"], neutral["high"], "soldier deficit LOWERS soldier threshold (more soldiers)")

	t.gt(neutral["high"], neutral["mid"], "high threshold stays above mid")
	t.gt(surplus["high"], surplus["mid"], "ordering preserved under extreme surplus")

func _test_jh_scale(t: TestAssert) -> void:
	var h := Homeostasis.new()
	h.soldier_pressure = 0.0
	t.approx(h.jh_dose_scale(), 1.0, 0.001, "no pressure → neutral JH dosing")
	h.soldier_pressure = -1.0
	t.lt(h.jh_dose_scale(), 1.0, "soldier surplus damps JH dosing")
	t.approx(h.soldier_surplus(), 1.0, 0.001, "soldier_surplus reports full surplus")
	h.soldier_pressure = 1.0
	t.gt(h.jh_dose_scale(), 1.0, "soldier deficit boosts JH dosing")
	t.approx(h.soldier_surplus(), 0.0, 0.001, "no surplus when in deficit")

func _test_idle_urgency(t: TestAssert) -> void:
	var h := Homeostasis.new()
	# Force a food shortage → foragers should be urged back to work.
	h.food_demand = 1.0
	h.forager_pressure = 1.0
	t.gt(h.idle_urgency(AntEnums.Caste.FORAGER), 0, "food shortage urges foragers")
	h.care_demand = 1.0
	h.minor_pressure = 1.0
	t.gt(h.idle_urgency(AntEnums.Caste.NURSE), 0, "care shortage urges nurses")
	# Well-supplied colony: no extra urgency.
	var calm := Homeostasis.new()
	t.eq(calm.idle_urgency(AntEnums.Caste.FORAGER), 0, "no urgency when demand is low")
	t.eq(calm.idle_urgency(AntEnums.Caste.SOLDIER), 0, "soldiers never idle-urged by this controller")

func _test_census_and_demand(t: TestAssert) -> void:
	var colony: Colony = TestHarness.make_colony_phase2(_tree)
	colony.homeostasis.tick(colony)
	var h: Homeostasis = colony.homeostasis
	t.gt(h.soldiers + h.foragers + h.nurses + h.gardeners, 0, "census counts adults")
	t.eq(h.minors, h.nurses + h.gardeners, "minors = nurses + gardeners")
	t.ge(h.food_demand, 0.0, "food demand computed")
	t.ge(h.care_demand, 0.0, "care demand computed")
	var snap: Dictionary = h.snapshot()
	t.ok(snap.has("soldier_pressure"), "snapshot exposes pressures")
	colony.queue_free()

## The review's headline ask: a forced soldier surplus must lower the soldier
## eclosion rate. We push a batch of identically-scored larvae through the live
## decide_caste path (Brood → Homeostasis → Config) under surplus vs. deficit and
## count how many are destined to be soldiers.
func _test_surplus_lowers_soldier_rate(t: TestAssert) -> void:
	var colony: Colony = TestHarness.make_colony_phase2(_tree)
	var h: Homeostasis = colony.homeostasis
	h.enabled = true

	# Neutral baseline.
	h.soldier_pressure = 0.0
	h.forager_pressure = 0.0
	var neutral_soldiers := _count_soldier_destinies(colony)

	# Big soldier surplus → threshold rises → fewer soldiers.
	h.soldier_pressure = -1.0
	var surplus_soldiers := _count_soldier_destinies(colony)

	# Soldier deficit → threshold falls → more soldiers.
	h.soldier_pressure = 1.0
	var deficit_soldiers := _count_soldier_destinies(colony)

	t.lt(surplus_soldiers, neutral_soldiers, "soldier surplus lowers soldier eclosion rate")
	t.gt(deficit_soldiers, neutral_soldiers, "soldier deficit raises soldier eclosion rate")

	# And the loop is truly OFF when disabled → back to fixed base thresholds.
	h.soldier_pressure = -1.0
	h.enabled = false
	var disabled_soldiers := _count_soldier_destinies(colony)
	t.eq(disabled_soldiers, neutral_soldiers, "disabling homeostasis restores base caste split")

	colony.queue_free()

## Count how many of a fixed spread of larva scores decide_caste sends to SOLDIER.
func _count_soldier_destinies(colony: Colony) -> int:
	var n := 0
	for score in range(48, 65):  # 48..64, straddles the base mid/high cutoffs
		var larva := AntState.new()
		larva.nutrition = float(score)
		larva.jh_dose = 0.0
		if colony.brood.decide_caste(larva) == AntEnums.Caste.SOLDIER:
			n += 1
	return n

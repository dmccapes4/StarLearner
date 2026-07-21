extends RefCounted
## Tests for Brood: feed, stages, pupate, eclose, caste destiny, eggs.

var _tree: Node

func _init(tree: Node) -> void:
	_tree = tree

func run() -> TestAssert:
	var t := TestAssert.new("Brood")
	var colony: Colony = TestHarness.make_colony(_tree, false)
	var brood: Brood = colony.brood
	t.ok(brood != null, "brood attached")
	t.ge(brood.living_brood(), Config.get_brood_min(), "initial brood ≥ brood_min")
	t.in_range(brood.target_larvae(), Config.get_brood_min(), Config.get_brood_max(), "target in band")
	t.ge(brood.living_adults(), 2, "has adults (player+queen+workers)")

	_test_feed_and_stages(t, colony, brood)
	_test_caste_destiny(t, brood)
	_test_pupate_and_eclose(t, colony, brood)
	_test_garden_health_gates_feed(t, colony, brood)
	_test_egg_signal_when_under_target(t, colony, brood)
	_test_ignore_feed_on_non_larva(t, colony, brood)

	colony.queue_free()
	return t

func _test_feed_and_stages(t: TestAssert, colony: Colony, brood: Brood) -> void:
	var larva := TestHarness.first_larva(colony)
	t.ok(larva != null, "has a larva to feed")
	if larva == null:
		return
	larva.nutrition = 0.0
	larva.jh_dose = 0.0
	larva.larva_stage = 0
	var before := larva.nutrition
	brood.feed(larva, 3.0, 1.0)
	t.gt(larva.nutrition, before, "feed increases nutrition")
	t.approx(larva.jh_dose, 1.0, 0.001, "feed applies JH")
	# Push through stages via nutrition thresholds [6,12,18].
	# feed() scales by garden_health — compensate so asserted thresholds are exact.
	var gh_scale := 1.0 / clampf(Config.get_garden_health(), 0.25, 1.0)
	larva.nutrition = 0.0
	larva.larva_stage = 0
	larva.caste = AntEnums.Caste.LARVA
	brood.feed(larva, 6.0 * gh_scale, 0.0)
	t.ge(larva.larva_stage, 1, "stage advances at first threshold")
	brood.feed(larva, 6.0 * gh_scale, 0.0)
	t.ge(larva.larva_stage, 2, "stage advances at second threshold")
	brood.feed(larva, 6.0 * gh_scale, 0.0)
	t.eq(larva.caste, AntEnums.Caste.PUPA, "third threshold pupates")

func _test_caste_destiny(t: TestAssert, brood: Brood) -> void:
	var hi := AntState.new()
	hi.nutrition = 30.0
	hi.jh_dose = 8.0
	t.eq(brood.decide_caste(hi), AntEnums.Caste.SOLDIER, "high score → soldier")
	var mid := AntState.new()
	mid.nutrition = 16.0
	mid.jh_dose = 2.0  # score = 20 (in [mid, high))
	t.eq(brood.decide_caste(mid), AntEnums.Caste.FORAGER, "mid score → forager")
	var lo := AntState.new()
	lo.nutrition = 10.0
	lo.jh_dose = 0.5  # score = 11
	t.eq(brood.decide_caste(lo), AntEnums.Caste.NURSE, "low score → nurse")
	# force_feed_for_test contracts
	var a := AntState.new()
	a.alive = true
	a.caste = AntEnums.Caste.LARVA
	a.id = 99
	brood.force_feed_for_test(a, true)
	t.eq(a.caste, AntEnums.Caste.PUPA, "force high → pupa")
	t.eq(a.caste_destiny, AntEnums.Caste.SOLDIER, "force high destiny soldier")
	var b := AntState.new()
	b.alive = true
	b.caste = AntEnums.Caste.LARVA
	b.id = 98
	brood.force_feed_for_test(b, false)
	t.eq(b.caste_destiny, AntEnums.Caste.NURSE, "force low destiny nurse")

func _test_pupate_and_eclose(t: TestAssert, colony: Colony, brood: Brood) -> void:
	var larva := TestHarness.make_larva(colony, colony.nest_center)
	t.ok(larva != null, "spawn larva for eclosion test")
	if larva == null:
		return
	brood.force_feed_for_test(larva, true)
	t.eq(larva.caste, AntEnums.Caste.PUPA, "pupated")
	t.eq(larva.pupa_ticks_left, Config.get_pupa_ticks(), "pupa timer set")
	var ticks := Config.get_pupa_ticks()
	for i in ticks:
		brood.tick(100 + i)
	t.eq(larva.caste, AntEnums.Caste.SOLDIER, "eclosed as soldier")
	t.ge(brood.eclosions, 1, "eclosion counter incremented")
	t.eq(brood.last_eclosion_caste, AntEnums.Caste.SOLDIER, "last caste recorded")
	t.ok(not larva.path.is_empty() or larva.state == AntEnums.State.WALK or larva.state == AntEnums.State.IDLE,
		"new adult has walk-off path or idle")

func _test_garden_health_gates_feed(t: TestAssert, colony: Colony, brood: Brood) -> void:
	var larva := TestHarness.make_larva(colony, Vector2(10, 10))
	if larva == null:
		t.ok(false, "larva for garden gate")
		return
	larva.nutrition = 0.0
	var saved_cfg: float = Config.data.garden_health
	var saved_garden: float = colony.garden.health if colony.garden != null else saved_cfg
	Config.data.garden_health = 0.5
	if colony.garden != null:
		colony.garden.health = 0.5
	brood.feed(larva, 4.0, 0.0)
	t.approx(larva.nutrition, 2.0, 0.01, "nutrition scaled by garden_health 0.5")
	Config.data.garden_health = saved_cfg
	if colony.garden != null:
		colony.garden.health = saved_garden

func _test_egg_signal_when_under_target(t: TestAssert, colony: Colony, brood: Brood) -> void:
	# Kill brood down below target so eggs can fire.
	for a in colony.ants:
		if a != null and a.alive and AntEnums.is_brood(a.caste):
			a.alive = false
	brood.egg_cooldown = 0
	var laid := [false]
	var cb := func() -> void: laid[0] = true
	Events.egg_laid.connect(cb, CONNECT_ONE_SHOT)
	brood.tick(1)
	t.ok(laid[0], "egg_laid emitted when under target")
	var queen := colony.get_ant(colony.queen_id)
	t.ok(queen != null and queen.intent == AntEnums.State.LAY_EGG, "queen marked LAY_EGG")

func _test_ignore_feed_on_non_larva(t: TestAssert, colony: Colony, brood: Brood) -> void:
	var nurse := colony.ants[2] as AntState
	var before := nurse.nutrition
	brood.feed(nurse, 99.0, 99.0)
	t.eq(nurse.nutrition, before, "feed ignores non-larva")

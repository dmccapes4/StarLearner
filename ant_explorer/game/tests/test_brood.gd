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
	t.ge(brood.living_brood(), Config.get_brood_min() - 3, "initial brood near target")
	t.in_range(brood.target_larvae(), Config.get_brood_min(), Config.get_brood_max(), "target in band")
	t.ge(brood.living_adults(), 2, "has adults (player+queen+workers)")
	t.ge(TestHarness.count_caste(colony, AntEnums.Caste.PUPA), 6, "seeded pupae")
	t.ge(brood.eggs_waiting, 3, "seeded egg pile")

	_test_feed_and_stages(t, colony, brood)
	_test_caste_destiny(t, brood)
	_test_pupate_and_eclose(t, colony, brood)
	_test_garden_health_gates_feed(t, colony, brood)
	_test_egg_signal_when_under_target(t, colony, brood)
	_test_ignore_feed_on_non_larva(t, colony, brood)
	_test_retire_frees_slot(t, colony)
	_test_pupation_is_staggered(t, colony, brood)
	colony.queue_free()

	_test_nurse_ferries_pupa_to_pupa_room(t)
	return t


func _test_pupation_is_staggered(t: TestAssert, colony: Colony, brood: Brood) -> void:
	## Many larvae ready at once must trickle out — not burst on one tick.
	var ready: Array[AntState] = []
	var pupate_at := brood.pupate_threshold()
	for i in 5:
		var larva := TestHarness.make_larva(colony, colony.nest_center + Vector2(8 * i, 0))
		if larva == null:
			break
		larva.nutrition = pupate_at
		larva.larva_stage = 2
		larva.jh_dose = 0.0
		ready.append(larva)
	t.ge(ready.size(), 5, "enough larvae to force a cohort")
	if ready.size() < 5:
		return
	brood.last_pupate_tick = -999
	var pupated_ticks: Array[int] = []
	for tick in 80:
		var before := 0
		for a in ready:
			if a.caste == AntEnums.Caste.PUPA:
				before += 1
		brood.tick(tick)
		var after := 0
		for a in ready:
			if a.caste == AntEnums.Caste.PUPA:
				after += 1
		if after > before:
			pupated_ticks.append(tick)
	t.ge(pupated_ticks.size(), 3, "several pupations over time")
	# No two passive pupations closer than the configured gap.
	var gap := Config.get_pupate_gap_ticks()
	for i in range(1, pupated_ticks.size()):
		t.ge(pupated_ticks[i] - pupated_ticks[i - 1], gap, "pupations respect gap")


func _test_retire_frees_slot(t: TestAssert, colony: Colony) -> void:
	var worker: AntState = null
	for a in colony.ants:
		if a != null and a.alive and a.caste == AntEnums.Caste.FORAGER:
			worker = a
			break
	t.ok(worker != null, "forager available to retire")
	if worker == null:
		return
	var before_adults := colony.brood.living_adults()
	worker.age_ticks = Config.get_max_age() * 3
	# Phase-1 fixtures sit under the forager floor; exercise the soft exit path.
	colony._retire_ant(worker)
	t.ok(not worker.alive, "aged worker retires")
	t.lt(colony.brood.living_adults(), before_adults, "retirement frees an adult slot")
	var nurse: AntState = null
	for a in colony.ants:
		if a != null and a.alive and a.caste == AntEnums.Caste.NURSE:
			nurse = a
			break
	if nurse != null and colony._count_caste(AntEnums.Caste.NURSE) <= colony._retire_floor(AntEnums.Caste.NURSE):
		nurse.age_ticks = Config.get_max_age() * 3
		colony._maybe_retire(nurse)
		t.ok(nurse.alive, "retire floor keeps thin castes alive")


func _test_nurse_ferries_pupa_to_pupa_room(t: TestAssert) -> void:
	var colony: Colony = TestHarness.make_colony_phase2(_tree)
	var pupae_ch := colony.graph.get_chamber_by_name("pupae")
	var nursery := colony.graph.get_chamber_by_name("nursery")
	t.ok(pupae_ch != null and nursery != null, "phase2 map has nursery + pupae")
	var larva := TestHarness.make_larva(colony, nursery.center)
	t.ok(larva != null, "larva in nursery")
	if larva == null or pupae_ch == null or nursery == null:
		colony.queue_free()
		return
	colony.brood.force_feed_for_test(larva, false)
	t.eq(larva.caste, AntEnums.Caste.PUPA, "pupated in place")
	t.ok(nursery.contains_point(larva.cell), "new pupa stays in nursery (no teleport)")
	t.ok(colony.brood.pupa_needs_ferry(larva), "pupa needs nursery→pupa-room ferry")

	var nurse: AntState = null
	for a in colony.ants:
		if a != null and a.alive and a.caste == AntEnums.Caste.NURSE:
			nurse = a
			break
	t.ok(nurse != null, "nurse for ferry")
	if nurse == null:
		colony.queue_free()
		return
	colony.brood.eggs_waiting = 0
	# Isolate this pupa so the picker can't choose a seeded nursery pupa.
	for a in colony.ants:
		if a != null and a.alive and a.caste == AntEnums.Caste.PUPA and a.id != larva.id:
			if colony.brood.pupa_needs_ferry(a):
				a.cell = pupae_ch.center
				a.prev_cell = pupae_ch.center
	nurse.carry = AntEnums.Carry.NONE
	nurse.idle_ticks_left = 0
	nurse.intent = AntEnums.State.IDLE
	nurse.clear_path()
	colony._nurse_pick_job(nurse)
	t.eq(nurse.intent, AntEnums.State.CARRY_PUPA, "nurse picks pupa ferry")
	t.eq(nurse.target_ant_id, larva.id, "targets the nursery pupa")

	nurse.cell = larva.cell
	nurse.clear_path(true)
	colony._finish_carry_pupa(nurse)
	t.eq(nurse.carry, AntEnums.Carry.LARVA, "picked up pupa")
	t.eq(larva.carried_by, nurse.id, "pupa.carried_by set")
	t.ok(not nurse.path.is_empty(), "paths toward pupa room")

	nurse.cell = pupae_ch.center
	nurse.clear_path(true)
	colony._finish_carry_pupa(nurse)
	t.eq(nurse.carry, AntEnums.Carry.NONE, "dropped pupa")
	t.eq(larva.carried_by, -1, "pupa free")
	t.ok(pupae_ch.contains_point(larva.cell), "pupa tucked in pupa room")
	t.ok(not colony.brood.pupa_needs_ferry(larva), "ferry complete")
	colony.queue_free()

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
	# Push through stages via Config nutrition thresholds.
	# feed() scales by garden_health — compensate so asserted thresholds are exact.
	var stages: PackedFloat32Array = Config.data.larva_nutrition_stage
	var gh_scale := 1.0 / clampf(Config.get_garden_health(), 0.25, 1.0)
	larva.nutrition = 0.0
	larva.larva_stage = 0
	larva.caste = AntEnums.Caste.LARVA
	brood.feed(larva, stages[0] * gh_scale, 0.0)
	t.ge(larva.larva_stage, 1, "stage advances at first threshold")
	brood.feed(larva, (stages[1] - stages[0]) * gh_scale, 0.0)
	t.ge(larva.larva_stage, 2, "stage advances at second threshold")
	brood.feed(larva, (stages[2] - stages[1]) * gh_scale, 0.0)
	t.eq(larva.caste, AntEnums.Caste.PUPA, "third threshold pupates")

func _test_caste_destiny(t: TestAssert, brood: Brood) -> void:
	var hi := AntState.new()
	hi.nutrition = 60.0
	hi.jh_dose = 8.0
	t.eq(brood.decide_caste(hi), AntEnums.Caste.SOLDIER, "high score → soldier")
	var mid := AntState.new()
	mid.nutrition = 52.0
	mid.jh_dose = 1.0  # score = 54 (in [mid, high))
	t.eq(brood.decide_caste(mid), AntEnums.Caste.FORAGER, "mid score → forager")
	var lo := AntState.new()
	lo.nutrition = 48.0
	lo.jh_dose = 0.5  # score = 49
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
	brood.eggs_waiting = 0
	brood.egg_cooldown = 0
	var queen := colony.get_ant(colony.queen_id)
	t.ok(queen != null, "queen present for laying")
	if queen != null:
		# Queen lays only when she is at the pile.
		queen.cell = brood.egg_pile_pos
		queen.prev_cell = brood.egg_pile_pos
		queen.clear_path()
	var laid := [false]
	var cb := func() -> void: laid[0] = true
	Events.egg_laid.connect(cb, CONNECT_ONE_SHOT)
	brood.tick(1)
	t.ok(laid[0], "egg_laid emitted when under target")
	t.eq(brood.eggs_waiting, 1, "egg added to chamber pile")
	t.ok(brood.take_egg_from_pile(), "take_egg_from_pile succeeds")
	t.eq(brood.eggs_waiting, 0, "waiting pile decremented")

func _test_ignore_feed_on_non_larva(t: TestAssert, colony: Colony, brood: Brood) -> void:
	var nurse := colony.ants[2] as AntState
	var before := nurse.nutrition
	brood.feed(nurse, 99.0, 99.0)
	t.eq(nurse.nutrition, before, "feed ignores non-larva")

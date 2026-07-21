extends RefCounted
## Tests for NPC nurse job picking, feed/dose/move/egg delivery.

var _tree: Node

func _init(tree: Node) -> void:
	_tree = tree

func run() -> TestAssert:
	var t := TestAssert.new("NurseFSM")
	var colony: Colony = TestHarness.make_colony(_tree, false)

	var nurse: AntState = null
	for a in colony.ants:
		if a != null and a.alive and a.caste == AntEnums.Caste.NURSE:
			nurse = a
			break
	t.ok(nurse != null, "found NPC nurse")
	if nurse == null:
		colony.queue_free()
		return t

	_test_picks_feed_job(t, colony, nurse)
	_test_completes_feed(t, colony)
	_test_dose_jh(t, colony)
	_test_move_larva_pickup_drop(t, colony)
	_test_carry_egg_cycle(t, colony)
	_test_auto_nurse_over_ticks(t, colony)

	colony.queue_free()
	return t

func _test_picks_feed_job(t: TestAssert, colony: Colony, nurse: AntState) -> void:
	nurse.idle_ticks_left = 0
	nurse.intent = AntEnums.State.IDLE
	nurse.carry = AntEnums.Carry.NONE
	nurse.clear_path()
	# Ensure queen not demanding egg so feed path is chosen often.
	var queen := colony.get_ant(colony.queen_id)
	if queen:
		queen.intent = AntEnums.State.IDLE
	if colony.brood != null:
		colony.brood.eggs_waiting = 0
	# Phase-1 map has no pupa room, but clear any stray ferry targets.
	for a in colony.ants:
		if a != null and a.alive and a.caste == AntEnums.Caste.PUPA:
			a.alive = false
	colony._nurse_pick_job(nurse)
	t.ok(
		nurse.intent == AntEnums.State.FETCH_FOOD
		or nurse.intent == AntEnums.State.FEED_LARVA
		or nurse.intent == AntEnums.State.DOSE_JH
		or nurse.intent == AntEnums.State.MOVE_LARVA
		or nurse.intent == AntEnums.State.IDLE,
		"nurse picks a care job or nest wander"
	)
	if nurse.intent == AntEnums.State.FETCH_FOOD:
		t.eq(nurse.carry, AntEnums.Carry.NONE, "fetch job gathers food at garden")
		t.ge(nurse.target_ant_id, 0, "fetch job remembers larva")
	elif nurse.intent == AntEnums.State.FEED_LARVA:
		t.eq(nurse.carry, AntEnums.Carry.FOOD, "feed job carries food")
		t.ge(nurse.target_ant_id, 0, "feed job has target")

func _test_completes_feed(t: TestAssert, colony: Colony) -> void:
	var nurse := _any_nurse(colony)
	var larva := TestHarness.first_larva(colony)
	if nurse == null or larva == null:
		t.ok(false, "nurse+larva for complete feed")
		return
	var before := larva.nutrition
	nurse.intent = AntEnums.State.FEED_LARVA
	nurse.target_ant_id = larva.id
	nurse.carry = AntEnums.Carry.FOOD
	nurse.cell = larva.cell
	colony._finish_intent(nurse, false)
	t.gt(larva.nutrition, before, "NPC feed increases nutrition")
	t.eq(nurse.carry, AntEnums.Carry.NONE, "NPC consumed food")
	t.eq(nurse.intent, AntEnums.State.IDLE, "NPC intent cleared")

func _test_dose_jh(t: TestAssert, colony: Colony) -> void:
	var nurse := _any_nurse(colony)
	var larva := TestHarness.first_larva(colony)
	if nurse == null or larva == null:
		t.ok(false, "nurse+larva for JH")
		return
	larva.jh_dose = 0.0
	nurse.intent = AntEnums.State.DOSE_JH
	nurse.target_ant_id = larva.id
	nurse.cell = larva.cell
	colony._finish_intent(nurse, false)
	t.gt(larva.jh_dose, 0.0, "dose JH increases jh_dose")

func _test_move_larva_pickup_drop(t: TestAssert, colony: Colony) -> void:
	var nurse := _any_nurse(colony)
	var larva := TestHarness.first_larva(colony)
	if nurse == null or larva == null:
		t.ok(false, "nurse+larva for move")
		return
	nurse.intent = AntEnums.State.MOVE_LARVA
	nurse.target_ant_id = larva.id
	nurse.carry = AntEnums.Carry.NONE
	nurse.cell = larva.cell
	colony._finish_move_larva(nurse)
	t.eq(nurse.carry, AntEnums.Carry.LARVA, "picked up larva")
	t.eq(larva.carried_by, nurse.id, "larva.carried_by set")
	t.ok(not nurse.path.is_empty(), "path to re-tuck spot")
	# Arrive at destination and drop
	nurse.cell = nurse.path[nurse.path.size() - 1] if nurse.path.size() > 0 else nurse.cell
	nurse.clear_path(true)
	colony._finish_move_larva(nurse)
	t.eq(nurse.carry, AntEnums.Carry.NONE, "dropped larva")
	t.eq(larva.carried_by, -1, "larva free")

func _test_carry_egg_cycle(t: TestAssert, colony: Colony) -> void:
	var nurse := _any_nurse(colony)
	if nurse == null or colony.brood == null:
		t.ok(false, "nurse+brood for egg")
		return
	var brood_before := colony.brood.living_brood()
	colony.brood.eggs_waiting = 1
	nurse.carry = AntEnums.Carry.NONE
	nurse.intent = AntEnums.State.CARRY_EGG
	# Pickup is from the pile, not the queen.
	nurse.cell = colony.brood.egg_pile_pos
	colony._finish_carry_egg(nurse)
	t.eq(nurse.carry, AntEnums.Carry.EGG, "picked egg from pile")
	t.eq(colony.brood.eggs_waiting, 0, "egg taken from waiting pile")
	t.ge(nurse.path.size(), 2, "nurse paths toward nursery with egg")
	nurse.cell = colony.nest_center
	nurse.clear_path(true)
	colony._finish_carry_egg(nurse)
	t.eq(nurse.carry, AntEnums.Carry.NONE, "delivered egg")
	t.gt(colony.brood.living_brood(), brood_before, "new larva spawned on delivery")

	# Job picker waits until the pile hits egg_ferry_min (so a heap can form).
	colony.brood.eggs_waiting = Config.get_egg_ferry_min() - 1
	nurse.carry = AntEnums.Carry.NONE
	nurse.intent = AntEnums.State.IDLE
	nurse.clear_path(true)
	nurse.idle_ticks_left = 0
	colony._nurse_pick_job(nurse)
	t.neq(nurse.intent, AntEnums.State.CARRY_EGG, "below ferry min → no egg grab")

	colony.brood.eggs_waiting = Config.get_egg_ferry_min()
	nurse.intent = AntEnums.State.IDLE
	nurse.clear_path(true)
	nurse.idle_ticks_left = 0
	colony._nurse_pick_job(nurse)
	t.eq(nurse.intent, AntEnums.State.CARRY_EGG, "at ferry min → egg ferry")
	t.ok(not nurse.path.is_empty(), "pick_job paths to egg pile")
	var dest: Vector2 = nurse.path[nurse.path.size() - 1]
	t.lt(dest.distance_to(colony.brood.egg_pile_pos), 8.0, "path ends at egg pile")

func _test_auto_nurse_over_ticks(t: TestAssert, colony: Colony) -> void:
	## Over many ticks, some larva should gain nutrition from NPC nurses.
	var totals_before := 0.0
	for a in colony.ants:
		if a != null and a.alive and a.caste == AntEnums.Caste.LARVA:
			totals_before += a.nutrition
	TestHarness.tick_colony(colony, 120)
	var totals_after := 0.0
	var pupae := 0
	for a in colony.ants:
		if a == null or not a.alive:
			continue
		if a.caste == AntEnums.Caste.LARVA:
			totals_after += a.nutrition
		elif a.caste == AntEnums.Caste.PUPA:
			pupae += 1
		elif a.age_ticks > 0 and AntEnums.is_adult_worker(a.caste) and a.caste != AntEnums.Caste.QUEEN and a.caste != AntEnums.Caste.PLAYER:
			pass
	t.ok(totals_after > totals_before or pupae > 0 or colony.brood.eclosions > 0,
		"nurses advance brood over 120 ticks (nutrition/pupae/eclosions)")

func _any_nurse(colony: Colony) -> AntState:
	for a in colony.ants:
		if a != null and a.alive and a.caste == AntEnums.Caste.NURSE:
			return a
	return null

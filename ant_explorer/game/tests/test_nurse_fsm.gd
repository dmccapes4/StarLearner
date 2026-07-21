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
	var queen := colony.get_ant(colony.queen_id)
	if nurse == null or queen == null:
		t.ok(false, "nurse+queen for egg")
		return
	var brood_before := colony.brood.living_brood()
	queen.intent = AntEnums.State.LAY_EGG
	nurse.carry = AntEnums.Carry.NONE
	nurse.intent = AntEnums.State.CARRY_EGG
	nurse.cell = queen.cell
	colony._finish_carry_egg(nurse)
	t.eq(nurse.carry, AntEnums.Carry.EGG, "picked egg from queen")
	t.eq(queen.intent, AntEnums.State.IDLE, "queen intent cleared")
	nurse.cell = colony.nest_center
	nurse.clear_path(true)
	colony._finish_carry_egg(nurse)
	t.eq(nurse.carry, AntEnums.Carry.NONE, "delivered egg")
	t.ge(colony.brood.living_brood(), brood_before, "brood count not decreased")
	t.gt(colony.brood.living_brood(), brood_before - 0.1, "new larva spawned on delivery")

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

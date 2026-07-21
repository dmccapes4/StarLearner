extends RefCounted
## Forager cut→haul→deposit loop + soldier patrol.

var _tree: Node

func _init(tree: Node) -> void:
	_tree = tree

func run() -> TestAssert:
	var t := TestAssert.new("ForagerFSM")
	var colony: Colony = TestHarness.make_colony_phase2(_tree)
	var forager: AntState = null
	for a in colony.ants:
		if a != null and a.alive and a.caste == AntEnums.Caste.FORAGER:
			forager = a
			break
	t.ok(forager != null, "forager exists")
	if forager:
		colony._forager_pick_job(forager)
		t.eq(forager.intent, AntEnums.State.GO_TO_LEAF, "picks GO_TO_LEAF")
		t.ok(not forager.path.is_empty(), "paths to leaf")
		# Arrive at leaf
		forager.cell = forager.path[forager.path.size() - 1]
		forager.clear_path(true)
		colony._finish_forager(forager)
		t.eq(forager.intent, AntEnums.State.CUT, "starts CUT")
		forager.action_ticks_left = 1
		colony._step_forager(forager, 64.0)
		t.eq(forager.carry, AntEnums.Carry.LEAF, "holds leaf after cut")
		t.eq(forager.intent, AntEnums.State.HAUL, "hauls after cut")

	var soldier: AntState = null
	for a in colony.ants:
		if a != null and a.alive and a.caste == AntEnums.Caste.SOLDIER:
			soldier = a
			break
	if soldier:
		colony._soldier_pick_job(soldier)
		t.eq(soldier.intent, AntEnums.State.PATROL, "soldier patrols")
		t.ok(not soldier.path.is_empty(), "soldier has patrol path")

	# Population ballpark
	t.ge(colony.living_count(), 30, "phase2 headless spawn has solid population")
	t.ge(TestHarness.count_caste(colony, AntEnums.Caste.FORAGER), 4, "foragers present")
	t.ge(TestHarness.count_caste(colony, AntEnums.Caste.SOLDIER), 4, "soldiers present")

	colony.queue_free()
	return t

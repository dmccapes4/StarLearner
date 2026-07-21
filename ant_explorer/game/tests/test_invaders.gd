extends RefCounted
## Invader events: spawn → swarm → shake → flee. No death of colony ants.

var _tree: Node

func _init(tree: Node) -> void:
	_tree = tree

func run() -> TestAssert:
	var t := TestAssert.new("Invaders")
	var colony: Colony = TestHarness.make_colony_phase2(_tree)
	var inv: Invaders = colony.invaders
	t.ok(inv != null, "invaders system present")
	inv.cooldown = 0
	inv.shake_ticks_default = 5

	var living_before := colony.living_count()
	inv.tick(1)  ## start event
	t.eq(inv._phase, "swarm", "event enters swarm")
	t.gt(inv.active_count(), 0, "invaders spawned")
	t.ge(TestHarness.count_caste(colony, AntEnums.Caste.INVADER), 1, "INVADER caste present")

	# Soldiers should be responding
	var responding := 0
	for a in colony.ants:
		if a != null and a.alive and a.caste == AntEnums.Caste.SOLDIER:
			if a.intent == AntEnums.State.RESPOND_INVADER or not a.path.is_empty():
				responding += 1
	t.gt(responding, 0, "soldiers rally")

	# Force engagement → shake
	var primary := inv._primary_invader()
	t.ok(primary != null, "primary invader")
	if primary:
		for a in colony.ants:
			if a != null and a.alive and a.caste == AntEnums.Caste.SOLDIER:
				a.cell = primary.cell
				a.prev_cell = primary.cell
				a.clear_path(true)
				a.intent = AntEnums.State.RESPOND_INVADER
	inv.tick(2)
	t.eq(inv._phase, "shake", "standoff shake phase")
	t.gt(primary.shake_ticks, 0, "invader shaking")

	# Advance shake to flee
	for i in 20:
		inv.tick(10 + i)
		if inv._phase == "flee" or inv._phase == "idle":
			break
	t.ok(inv._phase == "flee" or inv._phase == "idle", "resolves to flee/idle")

	# Colony ants still alive (no combat deaths)
	t.eq(colony.living_count(), living_before, "no colony deaths from skirmish")

	# Finish flee despawn
	for id in inv._active_ids:
		var a := colony.get_ant(id)
		if a:
			a.cell = Vector2(0, -800)
			a.clear_path()
	for i in 10:
		inv.tick(100 + i)
	t.eq(inv.active_count(), 0, "invaders cleared after flee")
	t.eq(inv._phase, "idle", "back to idle")
	t.eq(colony.living_count(), living_before, "colony count unchanged after resolve")

	colony.queue_free()
	return t

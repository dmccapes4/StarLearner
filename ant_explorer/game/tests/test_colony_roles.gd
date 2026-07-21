extends RefCounted
## Tests for player role, larva targeting, nurse tend path.

var _tree: Node

func _init(tree: Node) -> void:
	_tree = tree

func run() -> TestAssert:
	var t := TestAssert.new("ColonyRoles")
	var colony: Colony = TestHarness.make_colony(_tree, false)

	t.eq(colony.living_count() > 0, true, "colony has living ants")
	t.ge(TestHarness.count_caste(colony, AntEnums.Caste.NURSE), Config.get_phase1_nurse_count(), "nurse count")
	var brood_n := TestHarness.count_caste(colony, AntEnums.Caste.LARVA) \
		+ TestHarness.count_caste(colony, AntEnums.Caste.PUPA)
	t.ge(brood_n, Config.get_brood_min() - 3, "larva+pupa brood seeded densely")
	t.ge(TestHarness.count_caste(colony, AntEnums.Caste.PUPA), 6, "pupa room seeded")
	t.ge(colony.brood.eggs_waiting, 5, "egg pile seeded")

	var player := colony.get_player()
	t.ok(player != null and player.is_player, "player exists")
	t.eq(player.role, AntEnums.Role.NONE, "player starts with no role")

	var role_seen := [-1]
	Events.role_changed.connect(func(r: int) -> void: role_seen[0] = r, CONNECT_ONE_SHOT)
	colony.set_player_role(AntEnums.Role.NURSE)
	t.eq(player.role, AntEnums.Role.NURSE, "set_player_role NURSE")
	t.eq(role_seen[0], AntEnums.Role.NURSE, "role_changed emitted")
	t.ok(colony.player_is_nurse(), "player_is_nurse true")

	colony.set_player_role(AntEnums.Role.NONE)
	t.ok(not colony.player_is_nurse(), "role cleared")
	t.eq(player.carry, AntEnums.Carry.NONE, "carry cleared on drop role")

	var larva := TestHarness.first_larva(colony)
	t.ok(larva != null, "larva available")
	if larva:
		var found := colony.find_larva_near(larva.cell, 5.0)
		t.ok(found != null and found.id == larva.id, "find_larva_near hits")
		var miss := colony.find_larva_near(Vector2(9000, 9000), 10.0)
		t.ok(miss == null, "find_larva_near miss")

		colony.player_tend_larva(larva.id)
		t.eq(player.role, AntEnums.Role.NURSE, "tend auto-joins nurse")
		t.eq(player.intent, AntEnums.State.FEED_LARVA, "tend sets FEED_LARVA intent")
		t.eq(player.target_ant_id, larva.id, "tend targets larva id")
		t.eq(player.carry, AntEnums.Carry.FOOD, "tend carries food")
		t.ok(not player.path.is_empty() or player.state == AntEnums.State.WALK or player.cell.distance_to(larva.cell) < 1.0,
			"tend paths toward larva")

		# Arrive and finish feed
		player.cell = larva.cell
		player.clear_path(true)
		player.path = PackedVector2Array()
		colony._finish_intent(player, true)
		t.gt(larva.nutrition, 0.0, "player feed applied nutrition")
		t.eq(player.intent, AntEnums.State.IDLE, "intent cleared after feed")
		t.eq(player.carry, AntEnums.Carry.NONE, "food consumed")

	colony.request_player_path(Vector2(50, 50))
	t.eq(player.intent, AntEnums.State.IDLE, "open-ground path clears intent")
	t.ok(player.state == AntEnums.State.WALK or not player.path.is_empty(), "player walking after path request")

	colony.queue_free()
	return t

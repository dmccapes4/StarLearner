extends RefCounted
## Integration: feed → pupate → eclose destinies + 2-minute budget.

var _tree: Node

func _init(tree: Node) -> void:
	_tree = tree

func run() -> TestAssert:
	var t := TestAssert.new("Lifecycle")
	var colony: Colony = TestHarness.make_colony(_tree, false)
	var brood: Brood = colony.brood
	var stages: PackedFloat32Array = Config.data.larva_nutrition_stage
	var pupate_need: float = stages[stages.size() - 1]

	# High-care → soldier
	var hi := TestHarness.make_larva(colony, colony.nest_center)
	t.ok(hi != null, "hi larva spawned")
	if hi:
		var guard := 0
		while hi.caste == AntEnums.Caste.LARVA and guard < 80:
			brood.feed(hi, Config.data.player_feed_nutrition, Config.data.player_jh_step)
			guard += 1
		t.eq(hi.caste, AntEnums.Caste.PUPA, "high-care pupates")
		t.eq(hi.caste_destiny, AntEnums.Caste.SOLDIER, "high-care destiny soldier")
		for i in hi.pupa_ticks_left:
			brood.tick(1000 + i)
		t.eq(hi.caste, AntEnums.Caste.SOLDIER, "high-care ecloses soldier")

	# Low-care (nutrition only, no JH) → nurse
	var lo := TestHarness.make_larva(colony, colony.nest_center + Vector2(20, 0))
	t.ok(lo != null, "lo larva spawned")
	if lo:
		lo.nutrition = 0.0
		lo.jh_dose = 0.0
		lo.larva_stage = 0
		var guard2 := 0
		while lo.caste == AntEnums.Caste.LARVA and guard2 < 100:
			brood.feed(lo, 2.0, 0.0)
			guard2 += 1
		t.eq(lo.caste, AntEnums.Caste.PUPA, "low-care pupates")
		t.eq(lo.caste_destiny, AntEnums.Caste.NURSE, "low-care destiny nurse")
		for i in lo.pupa_ticks_left:
			brood.tick(2000 + i)
		t.eq(lo.caste, AntEnums.Caste.NURSE, "low-care ecloses nurse")

	# Mid-care → forager (score = nutrition + jh*2 in [mid, high))
	var mid := TestHarness.make_larva(colony, colony.nest_center + Vector2(-20, 0))
	t.ok(mid != null, "mid larva spawned")
	if mid:
		mid.nutrition = pupate_need - 0.2
		mid.jh_dose = 1.0
		mid.larva_stage = 2
		brood.feed(mid, 0.5, 0.0)
		t.eq(mid.caste, AntEnums.Caste.PUPA, "mid-care pupates")
		t.eq(mid.caste_destiny, AntEnums.Caste.FORAGER, "mid-care destiny forager")

	# Player in nurse role auto-picks care work
	var player := colony.get_player()
	colony.set_player_role(AntEnums.Role.NURSE)
	player.idle_ticks_left = 0
	player.intent = AntEnums.State.IDLE
	player.clear_path()
	var queen := colony.get_ant(colony.queen_id)
	if queen:
		queen.intent = AntEnums.State.IDLE
	colony._nurse_pick_job(player)
	t.ok(
		player.intent == AntEnums.State.FETCH_FOOD
		or player.intent == AntEnums.State.FEED_LARVA
		or player.intent == AntEnums.State.DOSE_JH
		or player.intent == AntEnums.State.MOVE_LARVA
		or player.intent == AntEnums.State.CARRY_EGG
		or not player.path.is_empty(),
		"nurse-role player auto-picks a nursery job"
	)

	# Budget: pupa duration + player-boosted feeds << 120s
	var seconds_pupa: float = float(Config.get_pupa_ticks()) / Config.get_sim_hz()
	t.lt(seconds_pupa, 30.0, "pupa phase under 30s real-time")
	var feeds_needed: float = pupate_need / Config.data.player_feed_nutrition
	var seconds_feed: float = feeds_needed / Config.get_sim_hz()
	t.lt(seconds_feed + seconds_pupa, 120.0, "player-boosted cycle under 2 min")

	colony.queue_free()
	return t

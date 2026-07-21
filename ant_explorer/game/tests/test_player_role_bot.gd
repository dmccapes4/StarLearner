extends RefCounted
## Player-as-bot role loops: forager cut→haul, nurse fetch→feed, stale walk kick.

var _tree: Node

func _init(tree: Node) -> void:
	_tree = tree

func run() -> TestAssert:
	var t := TestAssert.new("PlayerRoleBot")
	var colony: Colony = TestHarness.make_colony_phase2(_tree)
	var player := colony.get_player()
	t.ok(player != null, "player exists")

	_test_player_forager_loop(t, colony, player)
	_test_player_nurse_fetch_feed(t, colony, player)
	_test_stale_walk_kicks_job(t, colony, player)

	colony.queue_free()
	return t

func _test_player_forager_loop(t: TestAssert, colony: Colony, player: AntState) -> void:
	colony.set_player_role(AntEnums.Role.FORAGER)
	player.state = AntEnums.State.IDLE
	player.intent = AntEnums.State.IDLE
	player.carry = AntEnums.Carry.NONE
	player.clear_path()
	player.idle_ticks_left = 0

	colony._forager_pick_job(player)
	t.eq(player.intent, AntEnums.State.GO_TO_LEAF, "forager pick → GO_TO_LEAF")
	t.ok(not player.path.is_empty(), "forager paths to leaf")

	player.cell = player.path[player.path.size() - 1]
	player.clear_path(true)
	colony._finish_forager(player)
	t.eq(player.intent, AntEnums.State.CUT, "arrive leaf → CUT")

	player.action_ticks_left = 1
	colony._step_forager(player, 64.0)
	t.eq(player.carry, AntEnums.Carry.LEAF, "cut complete → LEAF")
	t.eq(player.intent, AntEnums.State.HAUL, "cut complete → HAUL")
	t.ok(not player.path.is_empty(), "haul path to garden")

func _test_player_nurse_fetch_feed(t: TestAssert, colony: Colony, player: AntState) -> void:
	colony.set_player_role(AntEnums.Role.NURSE)
	player.state = AntEnums.State.IDLE
	player.intent = AntEnums.State.IDLE
	player.carry = AntEnums.Carry.NONE
	player.clear_path()
	player.idle_ticks_left = 0

	var queen := colony.get_ant(colony.queen_id)
	if queen:
		queen.intent = AntEnums.State.IDLE

	colony._nurse_pick_job(player)
	t.eq(player.intent, AntEnums.State.FETCH_FOOD, "nurse pick → FETCH_FOOD")
	t.ge(player.target_ant_id, 0, "nurse remembers larva target")
	t.ok(not player.path.is_empty(), "nurse paths to garden")

	var garden_ch := colony.graph.get_chamber_by_name("garden_a")
	if garden_ch:
		player.cell = garden_ch.center
	player.clear_path(true)
	colony._finish_intent(player, true)
	t.eq(player.carry, AntEnums.Carry.FOOD, "garden arrive → FOOD")
	t.eq(player.intent, AntEnums.State.FEED_LARVA, "garden arrive → FEED_LARVA")
	t.ok(not player.path.is_empty(), "path to larva after fetch")

func _test_stale_walk_kicks_job(t: TestAssert, colony: Colony, player: AntState) -> void:
	colony.set_player_role(AntEnums.Role.FORAGER)
	player.state = AntEnums.State.WALK
	player.intent = AntEnums.State.IDLE
	player.carry = AntEnums.Carry.NONE
	player.clear_path(true)
	t.eq(player.state, AntEnums.State.IDLE, "clear_path fixes stale WALK")

	player.state = AntEnums.State.WALK
	player.intent = AntEnums.State.IDLE
	player.path = PackedVector2Array()
	player.path_index = 0

	colony._step_player(player, 64.0)
	t.eq(player.intent, AntEnums.State.GO_TO_LEAF, "stale walk kick → forager job")

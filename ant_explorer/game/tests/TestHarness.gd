class_name TestHarness
extends RefCounted
## Builds Colony / NavGraph fixtures for logic tests.

static func make_chamber(id: int = 0, half: Vector2 = Vector2(400, 220), name: String = "nursery") -> NavGraph.ChamberNode:
	var ch := NavGraph.ChamberNode.new()
	ch.id = id
	ch.name = name
	ch.center = Vector2.ZERO
	ch.world_rect = Rect2(-half, half * 2.0)
	ch.walkable = PackedVector2Array([
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y),
	])
	return ch

static func make_graph() -> NavGraph:
	var g := NavGraph.new()
	g.add_chamber(make_chamber())
	return g

static func make_phase2_graph() -> NavGraph:
	var builder := MapBuilder.new()
	var host := Node2D.new()
	var g := builder.build(host)
	host.free()
	return g

static func make_colony(parent: Node, with_views: bool = false) -> Colony:
	var graph := make_graph()
	var pathing := Pathing.new(graph)
	var colony := Colony.new()
	colony.name = "TestColony"
	parent.add_child(colony)
	colony.setup(graph, pathing)
	colony.rng.seed = 42
	colony.garden = Garden.new()
	colony.garden.setup(0.9)
	if with_views:
		var root := Node2D.new()
		root.name = "Ants"
		parent.add_child(root)
		colony.spawn_phase1(root, preload("res://scenes/Ant.tscn"))
	else:
		_spawn_phase1_headless(colony)
	return colony

static func make_colony_phase2(parent: Node) -> Colony:
	var builder := MapBuilder.new()
	var map_host := Node2D.new()
	parent.add_child(map_host)
	var graph := builder.build(map_host)
	var pathing := Pathing.new(graph)
	var colony := Colony.new()
	parent.add_child(colony)
	colony.setup(graph, pathing)
	colony.rng.seed = 7
	colony.views_parent = null
	colony.ant_scene = null
	colony.leaf_spots = builder.leaf_spots.duplicate()
	_spawn_phase2_headless(colony)
	return colony

static func _spawn_phase1_headless(colony: Colony) -> void:
	colony.views_parent = null
	colony.ant_scene = null
	colony._ensure_pool()
	var chamber := colony.graph.default_chamber()
	colony.nest_center = chamber.world_rect.get_center() + Vector2(0, 20)
	_activate(colony, colony.ants[0], 0, true, AntEnums.Caste.PLAYER, colony.nest_center + Vector2(-120, 40))
	colony.player_id = 0
	_activate(colony, colony.ants[1], 1, false, AntEnums.Caste.QUEEN, colony.nest_center + Vector2(-200, -60))
	colony.queen_id = 1
	colony.ants[1].state = AntEnums.State.LAY_EGG
	var next_id := 2
	for i in Config.get_phase1_nurse_count():
		_activate(colony, colony.ants[next_id], next_id, false, AntEnums.Caste.NURSE, chamber.random_point(colony.rng))
		colony.ants[next_id].idle_ticks_left = 1
		next_id += 1
	for i in Config.get_phase1_other_count():
		var caste := AntEnums.Caste.FORAGER if i % 2 == 0 else AntEnums.Caste.SOLDIER
		_activate(colony, colony.ants[next_id], next_id, false, caste, chamber.random_point(colony.rng))
		next_id += 1
	colony.brood = Brood.new()
	colony.brood.setup(colony, colony.nest_center, colony.queen_id)
	_seed_dense_brood(colony)
	colony.homeostasis = Homeostasis.new()
	colony.homeostasis.enabled = Config.data.homeo_enabled
	colony.invaders = Invaders.new()
	colony.invaders.setup(colony)
	colony.invaders.cooldown = 99999  ## keep idle in Phase-1-style tests

static func _spawn_phase2_headless(colony: Colony) -> void:
	colony._ensure_pool()
	var nursery := colony.graph.get_chamber_by_name("nursery")
	colony.nest_center = nursery.center if nursery else Vector2.ZERO
	colony.garden = Garden.new()
	colony.garden.setup(0.75)
	colony.homeostasis = Homeostasis.new()
	colony.homeostasis.enabled = Config.data.homeo_enabled
	var next_id := 0
	var entrance := colony.graph.get_chamber_by_name("entrance")
	_activate(colony, colony.ants[next_id], next_id, true, AntEnums.Caste.PLAYER, entrance.center if entrance else colony.nest_center)
	colony.player_id = next_id
	next_id += 1
	var queen_ch := colony.graph.get_chamber_by_name("queen")
	_activate(colony, colony.ants[next_id], next_id, false, AntEnums.Caste.QUEEN, queen_ch.center if queen_ch else colony.nest_center)
	colony.queen_id = next_id
	next_id += 1
	next_id = _group(colony, next_id, AntEnums.Caste.FORAGER, 8, "surface")
	next_id = _group(colony, next_id, AntEnums.Caste.GARDENER, 4, "garden_a")
	next_id = _group(colony, next_id, AntEnums.Caste.NURSE, 6, "nursery")
	next_id = _group(colony, next_id, AntEnums.Caste.SOLDIER, 6, "outpost")
	colony.brood = Brood.new()
	colony.brood.setup(colony, colony.nest_center, colony.queen_id)
	_seed_dense_brood(colony)
	colony.invaders = Invaders.new()
	colony.invaders.setup(colony)

static func _seed_dense_brood(colony: Colony) -> void:
	## Mirror Colony.spawn_phase2: larvae + pupae + waiting eggs.
	var want: int = maxi(0, colony.brood.target_larvae() - 3)
	var n_pupae: int = maxi(6, int(round(float(want) * 0.22)))
	var n_larvae: int = maxi(0, want - n_pupae)
	var pupate_at: float = colony.brood.pupate_threshold()
	var stages: PackedFloat32Array = Config.data.larva_nutrition_stage
	for i in n_larvae:
		var larva := colony.brood.spawn_larva(colony.brood.nest_spot(colony.rng))
		if larva == null:
			break
		var t: float = 0.0 if n_larvae <= 1 else float(i) / float(n_larvae - 1)
		larva.nutrition = lerpf(2.0, pupate_at * 0.92, t)
		larva.larva_stage = 0
		if stages.size() >= 2 and larva.nutrition >= stages[0]:
			larva.larva_stage = 1
		if stages.size() >= 3 and larva.nutrition >= stages[1]:
			larva.larva_stage = 2
	var destinies: Array[int] = [
		AntEnums.Caste.NURSE,
		AntEnums.Caste.FORAGER,
		AntEnums.Caste.NURSE,
		AntEnums.Caste.FORAGER,
		AntEnums.Caste.SOLDIER,
	]
	for i in n_pupae:
		var zone := "nursery" if i < 1 else "pupae"
		var pupa := colony.brood.spawn_pupa(
			colony.brood.chamber_spot(zone, colony.rng),
			destinies[i % destinies.size()],
		)
		if pupa == null:
			break
	colony.brood.eggs_waiting = 5

static func _group(colony: Colony, start: int, caste: int, count: int, zone: String) -> int:
	var ch := colony.graph.get_chamber_by_name(zone)
	var id := start
	for i in count:
		if id >= colony.ants.size():
			break
		_activate(colony, colony.ants[id], id, false, caste, ch.random_point(colony.rng) if ch else Vector2.ZERO)
		id += 1
	return id

static func _activate(colony: Colony, a: AntState, id: int, is_player: bool, caste: int, pos: Vector2) -> void:
	a.reset()
	a.id = id
	a.alive = true
	a.is_player = is_player
	a.caste = caste
	a.cell = pos
	a.prev_cell = pos
	var ch := colony.graph.chamber_for_point(pos)
	a.node_id = ch.id if ch else 0
	a.state = AntEnums.State.IDLE
	if not is_player and AntEnums.is_adult_worker(caste) \
			and caste != AntEnums.Caste.QUEEN and caste != AntEnums.Caste.PLAYER:
		var span: int = maxi(30, Config.get_max_age())
		a.age_ticks = colony.rng.randi_range(0, int(span * 0.75))

static func make_larva(colony: Colony, pos: Vector2 = Vector2.ZERO) -> AntState:
	return colony.brood.spawn_larva(pos)

static func count_caste(colony: Colony, caste: int) -> int:
	var n := 0
	for a in colony.ants:
		if a != null and a.alive and a.caste == caste:
			n += 1
	return n

static func first_larva(colony: Colony) -> AntState:
	for a in colony.ants:
		if a != null and a.alive and a.caste == AntEnums.Caste.LARVA:
			return a
	return null

static func tick_colony(colony: Colony, n: int, start_tick: int = 1) -> void:
	for i in n:
		colony.on_sim_tick(start_tick + i)

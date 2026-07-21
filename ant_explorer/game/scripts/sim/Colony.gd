class_name Colony
extends Node
## Pre-allocated ant pool. Phase 2: full nest graph + caste FSMs + invaders.

signal colony_ready()

const ANT_SCENE_DEFAULT := preload("res://scenes/Ant.tscn")
## Preload (not typed class_name) so headless CLI runs without editor global-class cache.
const _TunnelTransit := preload("res://scripts/nav/TunnelTransit.gd")

var graph: NavGraph
var pathing: Pathing
var tunnel_transit: RefCounted
var brood: Brood
var garden: Garden
var homeostasis: Homeostasis
var invaders: Invaders
var leaf_spots: Array = []
var ants: Array = []
var player_id: int = 0
var queen_id: int = -1
var nest_center: Vector2 = Vector2.ZERO
var rng := RandomNumberGenerator.new()
var views_parent: Node2D
var ant_scene: PackedScene = ANT_SCENE_DEFAULT
var _views: Dictionary = {}
var _tick: int = 0

func setup(nav: NavGraph, path: Pathing) -> void:
	graph = nav
	pathing = path
	tunnel_transit = _TunnelTransit.new(nav)
	rng.randomize()
	_ensure_pool()

func _ensure_pool() -> void:
	var cap: int = Config.get_agent_cap()
	ants.resize(cap)
	for i in cap:
		if ants[i] == null:
			var s := AntState.new()
			s.id = i
			s.reset()
			s.id = i
			ants[i] = s

func get_ant(id: int) -> AntState:
	if id < 0 or id >= ants.size():
		return null
	return ants[id] as AntState

func alloc_slot() -> AntState:
	for a in ants:
		if a != null and not a.alive:
			return a
	return null

func ensure_view(state: AntState) -> void:
	if views_parent == null or ant_scene == null:
		return
	if _views.has(state.id) and is_instance_valid(_views[state.id]):
		var existing: Node = _views[state.id]
		if existing.has_method("bind"):
			existing.call("bind", state)
		return
	_spawn_view(state, views_parent, ant_scene)

func spawn_phase2(parent: Node2D, scene: PackedScene, leaves: Array = []) -> void:
	views_parent = parent
	ant_scene = scene
	leaf_spots = leaves.duplicate()
	_ensure_pool()
	_clear_views()
	var nursery := graph.get_chamber_by_name("nursery")
	if nursery == null:
		nursery = graph.default_chamber()
	if nursery == null:
		push_error("Colony: no nursery chamber")
		return
	nest_center = nursery.center

	garden = Garden.new()
	garden.setup(Config.data.garden_health)
	garden.health_changed.connect(func(h: float) -> void: Events.garden_health_changed.emit(h))
	homeostasis = Homeostasis.new()
	invaders = Invaders.new()

	var next_id := 0
	# Player at entrance (exploration start)
	var entrance := graph.get_chamber_by_name("entrance")
	var ppos := entrance.center if entrance else nest_center
	_activate(ants[next_id], next_id, true, AntEnums.Caste.PLAYER, ppos)
	player_id = next_id
	next_id += 1

	# Queen
	var queen_ch := graph.get_chamber_by_name("queen")
	_activate(ants[next_id], next_id, false, AntEnums.Caste.QUEEN, queen_ch.center if queen_ch else nest_center)
	queen_id = next_id
	ants[next_id].state = AntEnums.State.LAY_EGG
	next_id += 1

	next_id = _spawn_caste_group(next_id, AntEnums.Caste.FORAGER, Config.data.phase2_foragers, "surface")
	next_id = _spawn_caste_group(next_id, AntEnums.Caste.GARDENER, Config.data.phase2_gardeners, "garden_a")
	next_id = _spawn_caste_group(next_id, AntEnums.Caste.NURSE, Config.data.phase2_nurses, "nursery")
	next_id = _spawn_caste_group(next_id, AntEnums.Caste.SOLDIER, Config.data.phase2_soldiers, "outpost")

	brood = Brood.new()
	brood.setup(self, nest_center, queen_id)
	var want: int = brood.target_larvae()
	for i in want:
		var larva := brood.spawn_larva(brood.nest_spot(rng))
		if larva == null:
			break
		if i % 5 == 1:
			larva.nutrition = 8.0
			larva.larva_stage = 1

	invaders.setup(self)
	colony_ready.emit()

func spawn_phase1(parent: Node2D, scene: PackedScene) -> void:
	spawn_phase2(parent, scene, [])

func spawn_phase0(parent: Node2D, scene: PackedScene) -> void:
	spawn_phase2(parent, scene, [])

func _spawn_caste_group(start_id: int, caste: int, count: int, zone: String) -> int:
	var ch := graph.get_chamber_by_name(zone)
	if ch == null:
		ch = graph.default_chamber()
	var id := start_id
	for i in count:
		if id >= ants.size():
			break
		var pos := ch.random_point(rng) if ch else Vector2.ZERO
		_activate(ants[id], id, false, caste, pos)
		ants[id].idle_ticks_left = rng.randi_range(1, 20)
		id += 1
	return id

func _activate(a: AntState, id: int, is_player: bool, caste: int, pos: Vector2) -> void:
	a.reset()
	a.id = id
	a.alive = true
	a.is_player = is_player
	a.caste = caste
	a.cell = pos
	a.prev_cell = pos
	var ch := graph.chamber_for_point(pos)
	a.node_id = ch.id if ch else 0
	a.state = AntEnums.State.IDLE
	_spawn_view(a, views_parent, ant_scene)

func _spawn_view(state: AntState, parent: Node2D, scene: PackedScene) -> void:
	if parent == null or scene == null:
		return
	var view: Node2D = scene.instantiate()
	parent.add_child(view)
	if view.has_method("bind"):
		view.call("bind", state)
	_views[state.id] = view

func _clear_views() -> void:
	for id in _views:
		var v: Node = _views[id]
		if is_instance_valid(v):
			v.queue_free()
	_views.clear()

func get_player() -> AntState:
	return ants[player_id] as AntState

func get_view(id: int) -> Node2D:
	return _views.get(id) as Node2D

func living_count() -> int:
	var n := 0
	for a in ants:
		if a != null and a.alive and a.caste != AntEnums.Caste.INVADER:
			n += 1
	return n

func player_is_nurse() -> bool:
	var p := get_player()
	return p != null and p.role == AntEnums.Role.NURSE

func player_has_role() -> bool:
	var p := get_player()
	return p != null and p.role != AntEnums.Role.NONE

func set_player_role(role: int) -> void:
	var p := get_player()
	if p == null:
		return
	p.role = role
	if role == AntEnums.Role.NONE:
		p.intent = AntEnums.State.IDLE
		p.target_ant_id = -1
		p.carry = AntEnums.Carry.NONE
	else:
		p.idle_ticks_left = 0
	Events.role_changed.emit(role)

func kick_player_role_job() -> void:
	var p := get_player()
	if p != null:
		_kick_player_role_job(p)

func request_player_path(world_pos: Vector2) -> void:
	var player := get_player()
	if player == null or not player.alive:
		return
	if tunnel_transit:
		tunnel_transit.notify_manual_path()
	player.intent = AntEnums.State.IDLE
	player.target_ant_id = -1
	player.set_path(pathing.find_path(player.cell, world_pos))

func player_tend_larva(larva_id: int) -> void:
	var player := get_player()
	var larva := get_ant(larva_id)
	if player == null or larva == null or not larva.alive:
		return
	if larva.caste != AntEnums.Caste.LARVA:
		return
	if not player_is_nurse():
		set_player_role(AntEnums.Role.NURSE)
	player.intent = AntEnums.State.FEED_LARVA
	player.target_ant_id = larva_id
	player.carry = AntEnums.Carry.FOOD
	player.set_path(pathing.find_path(player.cell, larva.cell))

func find_larva_near(world_pos: Vector2, radius: float) -> AntState:
	var best: AntState = null
	var best_d := radius * radius
	for a in ants:
		if a == null or not a.alive or a.caste != AntEnums.Caste.LARVA:
			continue
		if a.carried_by >= 0:
			continue
		var d: float = a.cell.distance_squared_to(world_pos)
		if d <= best_d:
			best_d = d
			best = a
	return best

func on_sim_tick(tick: int) -> void:
	_tick = tick
	var speed: float = Config.get_walk_speed()
	if homeostasis:
		homeostasis.tick(self)
	for a in ants:
		if a == null or not a.alive:
			continue
		if a.carried_by >= 0:
			var carrier := get_ant(a.carried_by)
			if carrier != null and carrier.alive:
				a.prev_cell = a.cell
				a.cell = carrier.cell + Vector2(0, -6)
				continue
		a.prev_cell = a.cell
		_sync_node(a)
		if a.shake_ticks > 0:
			a.shake_ticks -= 1
			a.state = AntEnums.State.SHAKE
			continue
		match a.caste:
			AntEnums.Caste.LARVA, AntEnums.Caste.PUPA:
				pass
			AntEnums.Caste.QUEEN:
				_step_queen(a)
			AntEnums.Caste.INVADER:
				_step_invader(a, speed)
			_:
				if a.is_player:
					_step_player(a, speed)
				else:
					match a.caste:
						AntEnums.Caste.NURSE:
							_step_nurse(a, speed)
						AntEnums.Caste.FORAGER:
							_step_forager(a, speed)
						AntEnums.Caste.GARDENER:
							_step_gardener(a, speed)
						AntEnums.Caste.SOLDIER:
							_step_soldier(a, speed)
						_:
							_step_wanderer(a, speed)
		a.age_ticks += 1
	if brood:
		brood.tick(tick)
	if garden and tick % 5 == 0:
		garden.tick_decay()
	if invaders:
		invaders.tick(tick)

func _sync_node(a: AntState) -> void:
	var ch := graph.chamber_for_point(a.cell)
	if ch:
		a.node_id = ch.id

func _step_queen(a: AntState) -> void:
	a.state = AntEnums.State.LAY_EGG

func _step_invader(a: AntState, speed: float) -> void:
	if a.intent == AntEnums.State.SHAKE:
		return
	if not a.path.is_empty():
		_step_walker(a, speed * 1.1)

func _maybe_tunnel_transit(a: AntState) -> void:
	if tunnel_transit == null or pathing == null:
		return
	if not a.path.is_empty() and tunnel_transit.is_committed():
		return
	var goal: Variant = tunnel_transit.try_trigger(a.cell)
	if goal == null:
		return
	a.set_path(pathing.find_path(a.cell, goal as Vector2))

func _step_player(a: AntState, speed: float) -> void:
	# Exploration: pads beside a tunnel mouth auto-walk through to past the exit.
	if a.role == AntEnums.Role.NONE and a.intent == AntEnums.State.IDLE:
		_maybe_tunnel_transit(a)
	# Tap-to-move / walk-to-trail / tunnel transit: IDLE intent means locomotion.
	if a.intent == AntEnums.State.IDLE and (a.state == AntEnums.State.WALK or not a.path.is_empty()):
		_step_walker(a, speed)
		if a.path.is_empty():
			a.state = AntEnums.State.IDLE
			if tunnel_transit:
				tunnel_transit.on_path_settled(a.cell)
			if a.role != AntEnums.Role.NONE:
				_kick_player_role_job(a)
		return
	match a.role:
		AntEnums.Role.FORAGER:
			_step_forager(a, speed)
		AntEnums.Role.GARDENER:
			_step_gardener(a, speed)
		AntEnums.Role.NURSE:
			_step_nurse(a, speed)
		AntEnums.Role.SOLDIER:
			_step_soldier(a, speed)
		AntEnums.Role.WASTE:
			_step_waste(a, speed)
		AntEnums.Role.SCOUT:
			_step_scout(a, speed)
		_:
			if a.state == AntEnums.State.WALK or not a.path.is_empty():
				_step_walker(a, speed)

func _kick_player_role_job(a: AntState) -> void:
	a.idle_ticks_left = 0
	match a.role:
		AntEnums.Role.FORAGER:
			_forager_pick_job(a)
		AntEnums.Role.GARDENER:
			_gardener_pick_job(a)
		AntEnums.Role.NURSE:
			_nurse_pick_job(a)
		AntEnums.Role.SOLDIER:
			_soldier_pick_job(a)
		AntEnums.Role.WASTE:
			_waste_pick_job(a)
		AntEnums.Role.SCOUT:
			_scout_pick_job(a)

func _step_nurse(a: AntState, speed: float) -> void:
	if a.action_ticks_left > 0:
		a.action_ticks_left -= 1
		return
	if a.state == AntEnums.State.WALK or not a.path.is_empty():
		_step_walker(a, speed)
		if a.path.is_empty() and a.intent != AntEnums.State.IDLE:
			_finish_intent(a, a.is_player)
		return
	a.idle_ticks_left -= 1
	if a.idle_ticks_left <= 0:
		_nurse_pick_job(a)

func _step_forager(a: AntState, speed: float) -> void:
	if a.action_ticks_left > 0:
		a.action_ticks_left -= 1
		if a.action_ticks_left <= 0 and a.intent == AntEnums.State.CUT:
			a.carry = AntEnums.Carry.LEAF
			a.intent = AntEnums.State.HAUL
			var garden_ch := _pick_garden()
			if garden_ch:
				a.set_path(pathing.find_path(a.cell, garden_ch.random_point(rng)))
		return
	if a.state == AntEnums.State.WALK or not a.path.is_empty():
		_step_walker(a, speed)
		if a.path.is_empty() and a.intent != AntEnums.State.IDLE:
			_finish_forager(a)
		return
	a.idle_ticks_left -= 1
	if a.idle_ticks_left <= 0:
		_forager_pick_job(a)

func _step_gardener(a: AntState, speed: float) -> void:
	if a.action_ticks_left > 0:
		a.action_ticks_left -= 1
		if a.action_ticks_left <= 0 and a.intent == AntEnums.State.TEND_GARDEN:
			if garden:
				garden.tend()
			a.intent = AntEnums.State.IDLE
			a.idle_ticks_left = rng.randi_range(8, 24)
		return
	if a.state == AntEnums.State.WALK or not a.path.is_empty():
		_step_walker(a, speed)
		if a.path.is_empty() and a.intent != AntEnums.State.IDLE:
			_finish_gardener(a)
		return
	a.idle_ticks_left -= 1
	if a.idle_ticks_left <= 0:
		_gardener_pick_job(a)

func _step_soldier(a: AntState, speed: float) -> void:
	if a.intent == AntEnums.State.RESPOND_INVADER or a.intent == AntEnums.State.SHAKE:
		if not a.path.is_empty():
			_step_walker(a, speed * 1.15)
		return
	if a.state == AntEnums.State.WALK or not a.path.is_empty():
		_step_walker(a, speed)
		if a.path.is_empty():
			a.intent = AntEnums.State.IDLE
			a.idle_ticks_left = rng.randi_range(10, 40)
		return
	a.idle_ticks_left -= 1
	if a.idle_ticks_left <= 0:
		_soldier_pick_job(a)

func _step_waste(a: AntState, speed: float) -> void:
	if a.action_ticks_left > 0:
		a.action_ticks_left -= 1
		return
	if a.state == AntEnums.State.WALK or not a.path.is_empty():
		_step_walker(a, speed)
		if a.path.is_empty() and a.intent != AntEnums.State.IDLE:
			_finish_gardener(a)
		return
	a.idle_ticks_left -= 1
	if a.idle_ticks_left <= 0:
		_waste_pick_job(a)

func _step_scout(a: AntState, speed: float) -> void:
	if a.state == AntEnums.State.WALK or not a.path.is_empty():
		_step_walker(a, speed)
		if a.path.is_empty():
			a.intent = AntEnums.State.IDLE
			a.idle_ticks_left = rng.randi_range(15, 40)
		return
	a.idle_ticks_left -= 1
	if a.idle_ticks_left <= 0:
		_scout_pick_job(a)

func _forager_pick_job(a: AntState) -> void:
	if a.carry == AntEnums.Carry.LEAF:
		a.intent = AntEnums.State.HAUL
		var gch := _pick_garden()
		if gch:
			a.set_path(pathing.find_path(a.cell, gch.random_point(rng)))
		return
	a.intent = AntEnums.State.GO_TO_LEAF
	var leaf := _pick_leaf_spot()
	a.set_path(pathing.find_path(a.cell, leaf))

func _gardener_pick_job(a: AntState) -> void:
	if garden and garden.waste > 0.35 and rng.randf() < 0.35:
		a.intent = AntEnums.State.CARRY_WASTE
		a.carry = AntEnums.Carry.WASTE
		var dump := graph.get_chamber_by_name("dump")
		if dump:
			a.set_path(pathing.find_path(a.cell, dump.center))
		return
	a.intent = AntEnums.State.TEND_GARDEN
	var gch := _pick_garden()
	if gch:
		a.set_path(pathing.find_path(a.cell, gch.random_point(rng)))

func _soldier_pick_job(a: AntState) -> void:
	a.intent = AntEnums.State.PATROL
	var zone := "outpost"
	if rng.randf() < 0.35:
		zone = "entrance"
	elif rng.randf() < 0.2:
		zone = "invasion"
	var ch := graph.get_chamber_by_name(zone)
	if ch:
		a.set_path(pathing.find_path(a.cell, ch.random_point(rng)))

func _waste_pick_job(a: AntState) -> void:
	if a.carry == AntEnums.Carry.WASTE:
		a.intent = AntEnums.State.CARRY_WASTE
		var dump := graph.get_chamber_by_name("dump")
		if dump:
			a.set_path(pathing.find_path(a.cell, dump.center))
		return
	if garden and garden.waste > 0.15:
		a.intent = AntEnums.State.CARRY_WASTE
		a.carry = AntEnums.Carry.WASTE
		var gch := _pick_garden()
		if gch:
			a.set_path(pathing.find_path(a.cell, gch.random_point(rng)))
		return
	a.intent = AntEnums.State.IDLE
	var dump_ch := graph.get_chamber_by_name("dump")
	if dump_ch:
		a.set_path(pathing.find_path(a.cell, dump_ch.random_point(rng)))
	a.idle_ticks_left = rng.randi_range(10, 30)

func _scout_pick_job(a: AntState) -> void:
	var zones := ["deep", "nursery", "entrance"]
	var zone: String = zones[rng.randi() % zones.size()]
	var ch := graph.get_chamber_by_name(zone)
	if ch:
		a.set_path(pathing.find_path(a.cell, ch.random_point(rng)))
	a.idle_ticks_left = rng.randi_range(15, 40)

func _nurse_pick_job(a: AntState) -> void:
	var queen := get_ant(queen_id)
	if not a.is_player and queen != null and queen.intent == AntEnums.State.LAY_EGG and a.carry == AntEnums.Carry.NONE:
		a.intent = AntEnums.State.CARRY_EGG
		a.target_ant_id = queen_id
		a.set_path(pathing.find_path(a.cell, queen.cell))
		return
	if a.carry == AntEnums.Carry.FOOD:
		var feed_larva := get_ant(a.target_ant_id)
		if feed_larva == null or not feed_larva.alive or feed_larva.caste != AntEnums.Caste.LARVA:
			feed_larva = _pick_needy_larva()
		if feed_larva != null:
			a.intent = AntEnums.State.FEED_LARVA
			a.target_ant_id = feed_larva.id
			a.set_path(pathing.find_path(a.cell, feed_larva.cell))
			return
	var larva := _pick_needy_larva()
	if larva == null:
		a.intent = AntEnums.State.IDLE
		a.set_path(pathing.find_path(a.cell, brood.nest_spot(rng)))
		a.idle_ticks_left = rng.randi_range(10, 30)
		return
	if a.is_player:
		a.intent = AntEnums.State.FETCH_FOOD
		a.target_ant_id = larva.id
		var gch := _pick_garden()
		if gch:
			a.set_path(pathing.find_path(a.cell, gch.random_point(rng)))
		return
	var roll := rng.randi() % 10
	if roll < 6:
		a.intent = AntEnums.State.FETCH_FOOD
		a.target_ant_id = larva.id
		var gch2 := _pick_garden()
		if gch2:
			a.set_path(pathing.find_path(a.cell, gch2.random_point(rng)))
	elif roll < 9:
		a.intent = AntEnums.State.DOSE_JH
		a.target_ant_id = larva.id
		a.set_path(pathing.find_path(a.cell, larva.cell))
	else:
		a.intent = AntEnums.State.MOVE_LARVA
		a.target_ant_id = larva.id
		a.set_path(pathing.find_path(a.cell, larva.cell))

func _pick_needy_larva() -> AntState:
	var best: AntState = null
	var best_score := -1.0
	for a in ants:
		if a == null or not a.alive or a.caste != AntEnums.Caste.LARVA:
			continue
		if a.carried_by >= 0:
			continue
		var score: float = 100.0 - a.nutrition + (2 - a.larva_stage) * 5.0
		if score > best_score:
			best_score = score
			best = a
	return best

func _pick_leaf_spot() -> Vector2:
	if leaf_spots.size() > 0:
		return leaf_spots[rng.randi() % leaf_spots.size()]
	var surface := graph.get_chamber_by_name("surface")
	if surface:
		return surface.random_point(rng)
	return nest_center

func _pick_garden() -> NavGraph.ChamberNode:
	var names := ["garden_a", "garden_b"]
	if rng.randf() < 0.2:
		names.append("hygiene")
	var name: String = names[rng.randi() % names.size()]
	return graph.get_chamber_by_name(name)

func _finish_forager(a: AntState) -> void:
	match a.intent:
		AntEnums.State.GO_TO_LEAF:
			a.intent = AntEnums.State.CUT
			a.action_ticks_left = Config.data.cut_ticks
			a.state = AntEnums.State.CUT
		AntEnums.State.HAUL, AntEnums.State.DEPOSIT:
			if garden:
				garden.deposit_leaf()
			a.carry = AntEnums.Carry.NONE
			a.intent = AntEnums.State.IDLE
			a.state = AntEnums.State.IDLE
			a.action_ticks_left = Config.data.deposit_ticks
			a.idle_ticks_left = rng.randi_range(4, 14)
		_:
			a.intent = AntEnums.State.IDLE
			a.idle_ticks_left = 8

func _finish_gardener(a: AntState) -> void:
	match a.intent:
		AntEnums.State.TEND_GARDEN:
			a.action_ticks_left = Config.data.nurse_action_pause + 2
			a.state = AntEnums.State.TEND_GARDEN
		AntEnums.State.CARRY_WASTE:
			if garden:
				garden.clear_waste(0.05)
			a.carry = AntEnums.Carry.NONE
			a.intent = AntEnums.State.IDLE
			a.idle_ticks_left = rng.randi_range(8, 20)
		_:
			a.intent = AntEnums.State.IDLE
			a.idle_ticks_left = 10

func _finish_intent(a: AntState, is_player_feed: bool) -> void:
	match a.intent:
		AntEnums.State.FETCH_FOOD:
			a.carry = AntEnums.Carry.FOOD
			var larva_food := get_ant(a.target_ant_id)
			if larva_food == null or not larva_food.alive or larva_food.caste != AntEnums.Caste.LARVA:
				larva_food = _pick_needy_larva()
			if larva_food != null:
				a.target_ant_id = larva_food.id
				a.intent = AntEnums.State.FEED_LARVA
				a.set_path(pathing.find_path(a.cell, larva_food.cell))
			return
		AntEnums.State.FEED_LARVA:
			var larva := get_ant(a.target_ant_id)
			if larva != null and larva.alive and larva.caste == AntEnums.Caste.LARVA:
				var n_amt: float = Config.data.player_feed_nutrition if is_player_feed else Config.data.feed_nutrition
				var j_amt: float = Config.data.player_jh_step if is_player_feed else Config.data.jh_step * 0.35
				brood.feed(larva, n_amt, j_amt)
			a.carry = AntEnums.Carry.NONE
			a.action_ticks_left = Config.data.nurse_action_pause
			a.state = AntEnums.State.FEED_LARVA
		AntEnums.State.DOSE_JH:
			var larva2 := get_ant(a.target_ant_id)
			if larva2 != null and larva2.alive and larva2.caste == AntEnums.Caste.LARVA:
				brood.feed(larva2, 0.15, Config.data.jh_step)
			a.action_ticks_left = Config.data.nurse_action_pause + 2
			a.state = AntEnums.State.DOSE_JH
		AntEnums.State.MOVE_LARVA:
			_finish_move_larva(a)
			return
		AntEnums.State.CARRY_EGG:
			_finish_carry_egg(a)
			return
		AntEnums.State.GO_TO_LEAF, AntEnums.State.HAUL, AntEnums.State.DEPOSIT, AntEnums.State.CUT:
			_finish_forager(a)
			return
		AntEnums.State.TEND_GARDEN, AntEnums.State.CARRY_WASTE:
			_finish_gardener(a)
			return
		_:
			pass
	a.intent = AntEnums.State.IDLE
	a.target_ant_id = -1
	a.idle_ticks_left = rng.randi_range(4, 16)

func _finish_move_larva(a: AntState) -> void:
	var larva := get_ant(a.target_ant_id)
	if larva == null or not larva.alive or larva.caste != AntEnums.Caste.LARVA:
		a.intent = AntEnums.State.IDLE
		a.idle_ticks_left = 8
		return
	if a.carry != AntEnums.Carry.LARVA:
		larva.carried_by = a.id
		a.carry = AntEnums.Carry.LARVA
		a.intent = AntEnums.State.MOVE_LARVA
		a.set_path(pathing.find_path(a.cell, brood.nest_spot(rng)))
		return
	larva.carried_by = -1
	larva.cell = a.cell + Vector2(8, 4)
	larva.prev_cell = larva.cell
	a.carry = AntEnums.Carry.NONE
	a.intent = AntEnums.State.IDLE
	a.target_ant_id = -1
	a.action_ticks_left = 3
	a.idle_ticks_left = rng.randi_range(6, 18)

func _finish_carry_egg(a: AntState) -> void:
	var queen := get_ant(queen_id)
	if a.carry != AntEnums.Carry.EGG:
		if queen != null and queen.intent == AntEnums.State.LAY_EGG:
			queen.intent = AntEnums.State.IDLE
			a.carry = AntEnums.Carry.EGG
			a.intent = AntEnums.State.CARRY_EGG
			a.set_path(pathing.find_path(a.cell, brood.nest_spot(rng)))
			return
		a.intent = AntEnums.State.IDLE
		a.idle_ticks_left = 10
		return
	brood.spawn_larva(a.cell)
	a.carry = AntEnums.Carry.NONE
	a.intent = AntEnums.State.IDLE
	a.target_ant_id = -1
	a.idle_ticks_left = rng.randi_range(8, 20)

func _step_wanderer(a: AntState, speed: float) -> void:
	if a.state == AntEnums.State.WALK or not a.path.is_empty():
		_step_walker(a, speed)
		if a.path.is_empty():
			a.idle_ticks_left = rng.randi_range(10, 50)
		return
	a.idle_ticks_left -= 1
	if a.idle_ticks_left <= 0:
		var ch := graph.get_chamber(a.node_id)
		if ch == null:
			ch = graph.default_chamber()
		if ch:
			a.set_path(pathing.find_path(a.cell, ch.random_point(rng)))

func _step_walker(a: AntState, speed: float) -> void:
	if a.path.is_empty() or a.path_index >= a.path.size():
		a.clear_path(true)
		if a.is_player and a.intent == AntEnums.State.IDLE:
			Events.player_arrived.emit()
		return
	var goal: Vector2 = a.path[a.path_index]
	var delta: Vector2 = goal - a.cell
	var dist := delta.length()
	if dist <= speed or dist < 0.5:
		a.cell = goal
		a.path_index += 1
		if a.path_index >= a.path.size():
			a.clear_path(true)
			if a.is_player and a.intent == AntEnums.State.IDLE:
				Events.player_arrived.emit()
		else:
			var next_delta: Vector2 = a.path[a.path_index] - a.cell
			if next_delta.length_squared() > 0.01:
				a.facing = next_delta.normalized()
		return
	a.cell += delta.normalized() * speed
	a.facing = delta.normalized()
	a.state = AntEnums.State.WALK

func on_ant_eclosed(ant: AntState) -> void:
	ensure_view(ant)
	var view := get_view(ant.id)
	if view and view.has_method("play_eclosion"):
		view.call("play_eclosion")

func interpolate_views(alpha: float) -> void:
	for id in _views:
		var view: Node = _views[id]
		var a: AntState = ants[id]
		if view == null or a == null or not a.alive:
			if view and a != null and not a.alive:
				(view as CanvasItem).visible = false
			continue
		(view as CanvasItem).visible = a.carried_by < 0
		var pos: Vector2 = a.prev_cell.lerp(a.cell, clampf(alpha, 0.0, 1.0))
		if view.has_method("sync_visual"):
			view.call("sync_visual", pos, a)
		else:
			(view as Node2D).global_position = pos

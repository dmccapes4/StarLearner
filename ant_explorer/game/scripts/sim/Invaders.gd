class_name Invaders
extends RefCounted
## Gentle invader events: spawn → soldiers swarm → shake → invaders flee. No death.

enum EnemyKind { ANT, BEETLE, SPIDER }

signal event_started(kind: int, count: int)
signal event_resolved()

var colony: Colony
var cooldown: int = 80
var shake_ticks_default: int = 18
var flee_target: Vector2 = Vector2(700, -900)
var _active_ids: PackedInt32Array = PackedInt32Array()
var _phase: String = "idle"  ## idle | swarm | shake | flee
var _shake_left: int = 0
var _kind: int = EnemyKind.ANT

func setup(c: Colony) -> void:
	colony = c
	cooldown = _next_cooldown()

func active_count() -> int:
	var n := 0
	for id in _active_ids:
		var a := colony.get_ant(id)
		if a != null and a.alive and a.caste == AntEnums.Caste.INVADER:
			n += 1
	return n

func tick(sim_tick: int) -> void:
	_prune()
	match _phase:
		"idle":
			cooldown -= 1
			if cooldown <= 0:
				_start_event(sim_tick)
		"swarm":
			if _soldiers_engaged():
				_phase = "shake"
				_shake_left = shake_ticks_default + colony.rng.randi_range(-4, 6)
				_set_shake_on_participants(true)
		"shake":
			_shake_left -= 1
			if _shake_left <= 0:
				_begin_flee()
		"flee":
			if active_count() == 0:
				_finish()

func _start_event(_sim_tick: int) -> void:
	var invasion := colony.graph.get_chamber_by_name("invasion")
	var entrance := colony.graph.get_chamber_by_name("entrance")
	var spawn_ch = invasion if invasion != null else entrance
	if spawn_ch == null:
		cooldown = _next_cooldown()
		return
	_kind = colony.rng.randi() % 3
	var count := 1 + colony.rng.randi() % 3  ## 1–3
	_active_ids = PackedInt32Array()
	for i in count:
		var slot := colony.alloc_slot()
		if slot == null:
			break
		var id := slot.id
		slot.reset()
		slot.id = id
		slot.alive = true
		slot.caste = AntEnums.Caste.INVADER
		slot.enemy_kind = _kind
		slot.node_id = spawn_ch.id
		slot.cell = spawn_ch.random_point(colony.rng)
		slot.prev_cell = slot.cell
		slot.state = AntEnums.State.IDLE
		slot.intent = AntEnums.State.IDLE
		colony.ensure_view(slot)
		_active_ids.append(id)
	if _active_ids.is_empty():
		cooldown = _next_cooldown()
		return
	_phase = "swarm"
	_rally_soldiers()
	event_started.emit(_kind, _active_ids.size())
	Events.invader_event_started.emit(_kind, _active_ids.size())

func _rally_soldiers() -> void:
	var target := _primary_invader()
	if target == null:
		return
	for a in colony.ants:
		if a == null or not a.alive or a.caste != AntEnums.Caste.SOLDIER:
			continue
		a.intent = AntEnums.State.RESPOND_INVADER
		a.target_ant_id = target.id
		a.set_path(colony.pathing.find_path(a.cell, target.cell))

func _soldiers_engaged() -> bool:
	var inv := _primary_invader()
	if inv == null:
		return true
	var near := 0
	for a in colony.ants:
		if a == null or not a.alive or a.caste != AntEnums.Caste.SOLDIER:
			continue
		if a.cell.distance_to(inv.cell) < 55.0:
			near += 1
		elif a.intent == AntEnums.State.RESPOND_INVADER and a.path.is_empty():
			a.set_path(colony.pathing.find_path(a.cell, inv.cell))
	# Also pull invaders toward soldiers a bit (they "meet" at entrance/invasion).
	for id in _active_ids:
		var invader := colony.get_ant(id)
		if invader == null or not invader.alive:
			continue
		if invader.path.is_empty() and invader.intent != AntEnums.State.SHAKE:
			var entrance := colony.graph.get_chamber_by_name("entrance")
			if entrance:
				invader.set_path(colony.pathing.find_path(invader.cell, entrance.center))
	return near >= mini(2, _count_soldiers())

func _begin_flee() -> void:
	_set_shake_on_participants(false)
	_phase = "flee"
	var flee_ch := colony.graph.get_chamber_by_name("invasion")
	var flee_pos := flee_target
	if flee_ch:
		flee_pos = flee_ch.center + Vector2(180, -80)
	for id in _active_ids:
		var inv := colony.get_ant(id)
		if inv == null or not inv.alive:
			continue
		inv.shake_ticks = 0
		inv.intent = AntEnums.State.IDLE
		inv.set_path(colony.pathing.find_path(inv.cell, flee_pos))
	# Soldiers hold briefly then return home.
	for a in colony.ants:
		if a == null or not a.alive or a.caste != AntEnums.Caste.SOLDIER:
			continue
		a.shake_ticks = 0
		a.intent = AntEnums.State.PATROL
		a.target_ant_id = -1
		var outpost := colony.graph.get_chamber_by_name("outpost")
		if outpost:
			a.set_path(colony.pathing.find_path(a.cell, outpost.random_point(colony.rng)))

func _finish() -> void:
	for id in _active_ids:
		var inv := colony.get_ant(id)
		if inv != null:
			inv.alive = false
			var view := colony.get_view(id)
			if view:
				view.visible = false
	_active_ids = PackedInt32Array()
	_phase = "idle"
	cooldown = _next_cooldown()
	event_resolved.emit()
	Events.invader_event_resolved.emit()

func _set_shake_on_participants(on: bool) -> void:
	for id in _active_ids:
		var inv := colony.get_ant(id)
		if inv != null and inv.alive:
			inv.shake_ticks = shake_ticks_default if on else 0
			inv.intent = AntEnums.State.SHAKE if on else AntEnums.State.IDLE
			inv.clear_path(true)
	for a in colony.ants:
		if a == null or not a.alive or a.caste != AntEnums.Caste.SOLDIER:
			continue
		if a.intent == AntEnums.State.RESPOND_INVADER or a.intent == AntEnums.State.SHAKE:
			a.shake_ticks = shake_ticks_default if on else 0
			if on:
				a.intent = AntEnums.State.SHAKE
				a.clear_path(true)

func _primary_invader() -> AntState:
	for id in _active_ids:
		var a := colony.get_ant(id)
		if a != null and a.alive:
			return a
	return null

func _count_soldiers() -> int:
	var n := 0
	for a in colony.ants:
		if a != null and a.alive and a.caste == AntEnums.Caste.SOLDIER:
			n += 1
	return n

func _prune() -> void:
	var keep := PackedInt32Array()
	for id in _active_ids:
		var a := colony.get_ant(id)
		if a != null and a.alive and a.caste == AntEnums.Caste.INVADER:
			# Despawn once they reach flee area far enough
			if _phase == "flee" and a.path.is_empty() and a.cell.y < -650.0:
				a.alive = false
				var view := colony.get_view(id)
				if view:
					view.visible = false
			else:
				keep.append(id)
	_active_ids = keep

func _next_cooldown() -> int:
	## Regular with variation: ~50–110s at 2.5 Hz → 125–275 ticks.
	var base: int = Config.data.invader_cooldown_min
	var span: int = maxi(1, Config.data.invader_cooldown_max - base)
	return base + colony.rng.randi() % span

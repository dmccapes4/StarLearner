class_name Brood
extends RefCounted
## Larval-space engine: nutrition → stages → pupa → eclose with caste destiny.

signal larva_fed(larva_id: int, nutrition: float, jh: float)
signal larva_pupated(larva_id: int)
signal ant_eclosed(ant_id: int, caste: int)

var colony: Colony
var nest_center: Vector2 = Vector2.ZERO
var queen_id: int = -1
var egg_cooldown: int = 0
## Eggs in a chamber pile. Queen walks there to lay; nurses pick from the pile.
var eggs_waiting: int = 0
var egg_pile_pos: Vector2 = Vector2.ZERO
var last_eclosion_tick: int = -1
var last_eclosion_caste: int = -1
var eclosions: int = 0
var last_pupate_tick: int = -999
var _sim_tick: int = 0

func setup(c: Colony, nest: Vector2, queen: int) -> void:
	colony = c
	nest_center = nest
	queen_id = queen
	egg_cooldown = Config.get_egg_interval()
	eggs_waiting = 0
	egg_pile_pos = _default_egg_pile_pos()
	last_pupate_tick = -999
	_sim_tick = 0


func _default_egg_pile_pos() -> Vector2:
	if colony != null and colony.graph != null:
		var qch = colony.graph.get_chamber_by_name("queen")
		if qch != null:
			# Offset from queen-chamber center so the pile is a distinct spot.
			return qch.clamp_point(qch.center + Vector2(90, 40))
	return nest_center + Vector2(80, 30)

func living_adults() -> int:
	var n := 0
	for a in colony.ants:
		if a != null and a.alive and AntEnums.is_adult_worker(a.caste):
			n += 1
	return n

func living_brood() -> int:
	var n := 0
	for a in colony.ants:
		if a != null and a.alive and AntEnums.is_brood(a.caste):
			n += 1
	return n

func target_larvae() -> int:
	var raw: int = int(round(Config.get_brood_k() * float(living_adults())))
	return clampi(raw, Config.get_brood_min(), Config.get_brood_max())

func nest_spot(rng: RandomNumberGenerator) -> Vector2:
	return chamber_spot("", rng)


func chamber_spot(chamber_name: String, rng: RandomNumberGenerator) -> Vector2:
	var r: float = Config.data.nest_cluster_radius
	var ang := rng.randf() * TAU
	var dist := rng.randf() * r * 0.85
	var ch = null
	if colony != null and colony.graph != null:
		if not chamber_name.is_empty():
			ch = colony.graph.get_chamber_by_name(chamber_name)
		if ch == null:
			ch = colony.graph.default_chamber()
	var center: Vector2 = nest_center
	if ch != null:
		center = ch.center
	var p := center + Vector2(cos(ang), sin(ang)) * dist
	if ch != null:
		return ch.clamp_point(p)
	return p

func garden_health() -> float:
	if colony != null and colony.garden != null:
		return colony.garden.health
	return Config.get_garden_health()

func feed(larva: AntState, nutrition_amt: float, jh_amt: float) -> void:
	if larva == null or not larva.alive or larva.caste != AntEnums.Caste.LARVA:
		return
	var gh: float = garden_health()
	larva.nutrition += nutrition_amt * clampf(gh, 0.25, 1.0)
	larva.jh_dose += jh_amt
	_advance_stages(larva)
	larva_fed.emit(larva.id, larva.nutrition, larva.jh_dose)
	Events.larva_fed.emit(larva.id, larva.nutrition, larva.jh_dose)

func pupate_threshold() -> float:
	var stages: PackedFloat32Array = Config.data.larva_nutrition_stage
	if stages.is_empty():
		return 18.0
	return stages[mini(2, stages.size() - 1)]


func is_ready_to_pupate(larva: AntState) -> bool:
	if larva == null or not larva.alive or larva.caste != AntEnums.Caste.LARVA:
		return false
	return larva.larva_stage >= 2 and larva.nutrition >= pupate_threshold()


func _advance_stages(larva: AntState, immediate_pupate: bool = true) -> void:
	var stages: PackedFloat32Array = Config.data.larva_nutrition_stage
	if stages.is_empty():
		stages = PackedFloat32Array([6.0, 12.0, 18.0])
	while larva.larva_stage < 2 and larva.larva_stage < stages.size() \
			and larva.nutrition >= stages[larva.larva_stage]:
		larva.larva_stage += 1
	# Pupate when stage 2 and nutrition crosses final threshold.
	# Passive growth uses a rate-limited queue so cohorts don't burst together;
	# nurse/player feed still pupates immediately (one larva at a time).
	if is_ready_to_pupate(larva) and immediate_pupate:
		_pupate(larva)

func _pupate(larva: AntState) -> void:
	## Pupate in place (usually the nursery). Nurses ferry pupae to the pupa
	## room — they must not teleport there.
	larva.caste_destiny = decide_caste(larva)
	larva.caste = AntEnums.Caste.PUPA
	larva.pupa_ticks_left = Config.get_pupa_ticks()
	larva.state = AntEnums.State.IDLE
	larva.carried_by = -1
	larva.clear_path()
	last_pupate_tick = _sim_tick
	larva_pupated.emit(larva.id)
	Events.larva_pupated.emit(larva.id)

func decide_caste(larva: AntState) -> int:
	## High nutrition + JH → soldier; mid → forager; modest → nurse/minor.
	## Thresholds are bent by colony pressure (Homeostasis): a soldier surplus
	## raises the soldier bar so fewer new larvae become soldiers, and vice versa
	## — this is the caste-mix feedback loop that self-corrects the colony.
	var score: float = larva.nutrition + larva.jh_dose * 2.0
	var high: float = Config.data.caste_destiny_high
	var mid: float = Config.data.caste_destiny_mid
	if colony != null and colony.homeostasis != null and colony.homeostasis.enabled:
		var th: Dictionary = colony.homeostasis.caste_thresholds()
		high = th["high"]
		mid = th["mid"]
	if score >= high:
		return AntEnums.Caste.SOLDIER
	if score >= mid:
		return AntEnums.Caste.FORAGER
	return AntEnums.Caste.NURSE

func tick(sim_tick: int) -> void:
	_sim_tick = sim_tick
	_tick_larva_growth()
	_tick_pupation_queue()
	_tick_pupae(sim_tick)
	_tick_eggs(sim_tick)


func _tick_larva_growth() -> void:
	## Slow background growth so the egg→larva→pupa pipeline keeps moving
	## even when nurses are busy ferrying eggs. Per-larva growth_rate keeps
	## cohorts from locking step; ready larvae stop dripping so destiny scores
	## don't inflate while waiting for a pupation slot.
	var drip: float = Config.get_larva_passive_nutrition()
	if drip <= 0.0:
		return
	var pupate_at := pupate_threshold()
	for a in colony.ants:
		if a == null or not a.alive or a.caste != AntEnums.Caste.LARVA:
			continue
		if is_ready_to_pupate(a):
			a.nutrition = minf(a.nutrition, pupate_at)
			continue
		var rate: float = a.growth_rate if a.growth_rate > 0.0 else 1.0
		a.nutrition += drip * rate
		_advance_stages(a, false)


func _tick_pupation_queue() -> void:
	## At most one pupation every pupate_gap_ticks — a steady trickle, not a burst.
	var gap: int = Config.get_pupate_gap_ticks()
	if gap > 0 and _sim_tick - last_pupate_tick < gap:
		return
	var best: AntState = null
	var best_n := -INF
	for a in colony.ants:
		if a == null or not is_ready_to_pupate(a):
			continue
		# Prefer the most "done" larva so the queue drains fairly.
		if a.nutrition > best_n:
			best_n = a.nutrition
			best = a
	if best != null:
		_pupate(best)

func _tick_pupae(sim_tick: int) -> void:
	for a in colony.ants:
		if a == null or not a.alive or a.caste != AntEnums.Caste.PUPA:
			continue
		# Timer only runs once a nurse has tucked the pupa into the pupa room
		# (or there is no separate pupa chamber on this map).
		if a.carried_by >= 0 or not pupa_in_pupa_room(a):
			continue
		a.pupa_ticks_left -= 1
		if a.pupa_ticks_left <= 0:
			_eclose(a, sim_tick)


func pupa_in_pupa_room(pupa: AntState) -> bool:
	if pupa == null or colony == null or colony.graph == null:
		return true
	var ch = colony.graph.get_chamber_by_name("pupae")
	if ch == null:
		return true  # single-chamber / test maps — mature in place
	return ch.contains_point(pupa.cell)


func pupa_needs_ferry(pupa: AntState) -> bool:
	if pupa == null or not pupa.alive or pupa.caste != AntEnums.Caste.PUPA:
		return false
	if pupa.carried_by >= 0:
		return false
	return not pupa_in_pupa_room(pupa)

func _eclose(pupa: AntState, sim_tick: int) -> void:
	var destiny: int = pupa.caste_destiny
	pupa.caste = destiny
	pupa.larva_stage = 0
	pupa.nutrition = 0.0
	pupa.jh_dose = 0.0
	pupa.pupa_ticks_left = 0
	pupa.carried_by = -1
	pupa.state = AntEnums.State.IDLE
	pupa.intent = AntEnums.State.IDLE
	pupa.idle_ticks_left = 8
	pupa.role = AntEnums.Role.NONE
	pupa.age_ticks = 0
	# Walk out of the pupa room toward that caste's workplace.
	var zone := "nursery"
	match destiny:
		AntEnums.Caste.SOLDIER:
			zone = "outpost"
		AntEnums.Caste.FORAGER:
			zone = "surface"
		AntEnums.Caste.GARDENER:
			zone = "garden_a"
		AntEnums.Caste.NURSE:
			zone = "nursery"
	var away := chamber_spot(zone, colony.rng)
	pupa.set_path(colony.pathing.find_path(pupa.cell, away))
	eclosions += 1
	last_eclosion_tick = sim_tick
	last_eclosion_caste = destiny
	ant_eclosed.emit(pupa.id, destiny)
	Events.ant_eclosed.emit(pupa.id, destiny)
	colony.on_ant_eclosed(pupa)

func can_accept_egg() -> bool:
	return living_brood() < target_larvae() \
		and living_adults() < Config.get_agent_cap() \
		and garden_health() >= 0.35

func _tick_eggs(_sim_tick: int) -> void:
	if egg_cooldown > 0:
		egg_cooldown -= 1
		return
	if not can_accept_egg():
		return
	if eggs_waiting >= 10:
		return
	var queen: AntState = colony.get_ant(queen_id)
	if queen == null or not queen.alive:
		egg_cooldown = Config.get_egg_interval()
		spawn_larva(nest_spot(colony.rng))
		Events.egg_laid.emit()
		return
	# Queen must walk to the pile and lay there — eggs appear on the heap,
	# not "pulled out of" her body when a nurse arrives.
	if queen.cell.distance_to(egg_pile_pos) > 36.0:
		queen.intent = AntEnums.State.LAY_EGG
		queen.state = AntEnums.State.WALK
		if queen.path.is_empty() or queen.path[queen.path.size() - 1].distance_to(egg_pile_pos) > 24.0:
			queen.set_path(colony.pathing.find_path(queen.cell, egg_pile_pos))
		return
	egg_cooldown = Config.get_egg_interval()
	eggs_waiting += 1
	queen.intent = AntEnums.State.LAY_EGG
	queen.state = AntEnums.State.LAY_EGG
	queen.clear_path()
	Events.egg_laid.emit()


func take_egg_from_pile() -> bool:
	if eggs_waiting <= 0:
		return false
	eggs_waiting -= 1
	return true


func take_egg_from_queen() -> bool:
	## Back-compat alias — pickup is from the pile, not the queen.
	return take_egg_from_pile()

func spawn_larva(pos: Vector2) -> AntState:
	var slot: AntState = colony.alloc_slot()
	if slot == null:
		return null
	var id := slot.id
	slot.reset()
	slot.id = id
	slot.alive = true
	slot.caste = AntEnums.Caste.LARVA
	slot.larva_stage = 0
	slot.nutrition = 0.0
	slot.jh_dose = 0.0
	# Slight growth variance so same-age hatchlings don't lock-step to pupae.
	if colony != null and colony.rng != null:
		slot.growth_rate = colony.rng.randf_range(0.55, 1.45)
	else:
		slot.growth_rate = 1.0
	slot.cell = pos
	slot.prev_cell = pos
	var ch := colony.graph.chamber_containing(pos)
	if ch == null:
		ch = colony.graph.default_chamber()
	slot.node_id = ch.id if ch != null else 0
	slot.state = AntEnums.State.IDLE
	colony.ensure_view(slot)
	return slot


func spawn_pupa(pos: Vector2, destiny: int = -1) -> AntState:
	## Seed a visible pupa for the pupa chamber (and denser starting brood).
	var pupa := spawn_larva(pos)
	if pupa == null:
		return null
	pupa.nutrition = 20.0
	pupa.jh_dose = 2.0
	pupa.larva_stage = 2
	if destiny < 0:
		destiny = decide_caste(pupa)
	pupa.caste_destiny = destiny
	pupa.caste = AntEnums.Caste.PUPA
	pupa.pupa_ticks_left = Config.get_pupa_ticks()
	pupa.state = AntEnums.State.IDLE
	pupa.clear_path()
	return pupa

func force_feed_for_test(larva: AntState, high: bool) -> void:
	## Headless acceptance helper: push a larva to pupation with known destiny.
	if high:
		larva.nutrition = 62.0
		larva.jh_dose = 8.0
		larva.larva_stage = 2
	else:
		# score = nutrition + jh*2 must stay below caste_destiny_mid → nurse
		larva.nutrition = 48.0
		larva.jh_dose = 0.5
		larva.larva_stage = 2
	_pupate(larva)

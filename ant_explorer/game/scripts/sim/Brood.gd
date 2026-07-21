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
var last_eclosion_tick: int = -1
var last_eclosion_caste: int = -1
var eclosions: int = 0

func setup(c: Colony, nest: Vector2, queen: int) -> void:
	colony = c
	nest_center = nest
	queen_id = queen
	egg_cooldown = Config.get_egg_interval()

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
	var r: float = Config.data.nest_cluster_radius
	var ang := rng.randf() * TAU
	var dist := rng.randf() * r * 0.85
	var p := nest_center + Vector2(cos(ang), sin(ang)) * dist
	var ch := colony.graph.default_chamber()
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

func _advance_stages(larva: AntState) -> void:
	var stages: PackedFloat32Array = Config.data.larva_nutrition_stage
	if stages.is_empty():
		stages = PackedFloat32Array([6.0, 12.0, 18.0])
	while larva.larva_stage < 2 and larva.larva_stage < stages.size() \
			and larva.nutrition >= stages[larva.larva_stage]:
		larva.larva_stage += 1
	# Pupate when stage 2 and nutrition crosses final threshold.
	var pupate_at: float = stages[mini(2, stages.size() - 1)]
	if larva.larva_stage >= 2 and larva.nutrition >= pupate_at and larva.caste == AntEnums.Caste.LARVA:
		_pupate(larva)

func _pupate(larva: AntState) -> void:
	larva.caste_destiny = decide_caste(larva)
	larva.caste = AntEnums.Caste.PUPA
	larva.pupa_ticks_left = Config.get_pupa_ticks()
	larva.state = AntEnums.State.IDLE
	larva.clear_path()
	larva_pupated.emit(larva.id)
	Events.larva_pupated.emit(larva.id)

func decide_caste(larva: AntState) -> int:
	## High nutrition + JH → soldier; mid → forager; modest → nurse/minor.
	var score: float = larva.nutrition + larva.jh_dose * 2.0
	if score >= Config.data.caste_destiny_high:
		return AntEnums.Caste.SOLDIER
	if score >= Config.data.caste_destiny_mid:
		return AntEnums.Caste.FORAGER
	return AntEnums.Caste.NURSE

func tick(sim_tick: int) -> void:
	_tick_pupae(sim_tick)
	_tick_eggs(sim_tick)

func _tick_pupae(sim_tick: int) -> void:
	for a in colony.ants:
		if a == null or not a.alive or a.caste != AntEnums.Caste.PUPA:
			continue
		a.pupa_ticks_left -= 1
		if a.pupa_ticks_left <= 0:
			_eclose(a, sim_tick)

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
	# Walk off toward a job spot (edge of nest cluster).
	var dest := nest_spot(colony.rng)
	var away := nest_center + (dest - nest_center).normalized() * (Config.data.nest_cluster_radius + 40.0)
	var ch := colony.graph.default_chamber()
	if ch != null:
		away = ch.clamp_point(away)
	pupa.set_path(colony.pathing.find_path(pupa.cell, away))
	eclosions += 1
	last_eclosion_tick = sim_tick
	last_eclosion_caste = destiny
	ant_eclosed.emit(pupa.id, destiny)
	Events.ant_eclosed.emit(pupa.id, destiny)
	colony.on_ant_eclosed(pupa)

func _tick_eggs(_sim_tick: int) -> void:
	if egg_cooldown > 0:
		egg_cooldown -= 1
		return
	if living_brood() >= target_larvae():
		return
	if living_adults() >= Config.get_agent_cap():
		return
	if garden_health() < 0.35:
		return
	# Mark queen ready; Colony nurse FSM will pick up and deliver.
	var queen: AntState = colony.get_ant(queen_id)
	if queen == null or not queen.alive:
		# Fallback: spawn larva directly in nest.
		spawn_larva(nest_spot(colony.rng))
		egg_cooldown = Config.get_egg_interval()
		Events.egg_laid.emit()
		return
	queen.intent = AntEnums.State.LAY_EGG
	egg_cooldown = Config.get_egg_interval()
	Events.egg_laid.emit()

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
	slot.cell = pos
	slot.prev_cell = pos
	var ch := colony.graph.default_chamber()
	slot.node_id = ch.id if ch != null else 0
	slot.state = AntEnums.State.IDLE
	colony.ensure_view(slot)
	return slot

func force_feed_for_test(larva: AntState, high: bool) -> void:
	## Headless acceptance helper: push a larva to pupation with known destiny.
	if high:
		larva.nutrition = 30.0
		larva.jh_dose = 8.0
		larva.larva_stage = 2
	else:
		# score = nutrition + jh*2 must stay below caste_destiny_mid → nurse
		larva.nutrition = 10.0
		larva.jh_dose = 0.5
		larva.larva_stage = 2
	_pupate(larva)

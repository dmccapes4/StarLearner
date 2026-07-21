class_name AntState
extends RefCounted
## Compact pooled agent record. Logic advances on sim ticks only.

var id: int = -1
var alive: bool = false
var is_player: bool = false
var caste: int = AntEnums.Caste.FORAGER
var role: int = AntEnums.Role.NONE
var node_id: int = 0
var cell: Vector2 = Vector2.ZERO
var prev_cell: Vector2 = Vector2.ZERO
var facing: Vector2 = Vector2.RIGHT
var state: int = AntEnums.State.IDLE
var intent: int = AntEnums.State.IDLE
var target: Variant = null
var target_ant_id: int = -1
var path: PackedVector2Array = PackedVector2Array()
var path_index: int = 0
var carry: int = AntEnums.Carry.NONE
var age_ticks: int = 0
var action_ticks_left: int = 0
var shake_ticks: int = 0
var enemy_kind: int = 0
# brood-only
var larva_stage: int = 0
var nutrition: float = 0.0
var jh_dose: float = 0.0
var growth_rate: float = 1.0  ## per-larva drip multiplier — desyncs cohorts
var caste_destiny: int = AntEnums.Caste.FORAGER
var pupa_ticks_left: int = 0
var carried_by: int = -1
var idle_ticks_left: int = 0

func reset() -> void:
	alive = false
	is_player = false
	caste = AntEnums.Caste.FORAGER
	role = AntEnums.Role.NONE
	node_id = 0
	cell = Vector2.ZERO
	prev_cell = Vector2.ZERO
	facing = Vector2.RIGHT
	state = AntEnums.State.IDLE
	intent = AntEnums.State.IDLE
	target = null
	target_ant_id = -1
	path = PackedVector2Array()
	path_index = 0
	carry = AntEnums.Carry.NONE
	age_ticks = 0
	action_ticks_left = 0
	shake_ticks = 0
	enemy_kind = 0
	larva_stage = 0
	nutrition = 0.0
	jh_dose = 0.0
	growth_rate = 1.0
	caste_destiny = AntEnums.Caste.FORAGER
	pupa_ticks_left = 0
	carried_by = -1
	idle_ticks_left = 0
	id = -1

func set_path(new_path: PackedVector2Array) -> void:
	path = new_path
	path_index = 0
	if path.size() > 1:
		path_index = 1
		state = AntEnums.State.WALK
		target = path[path_index]
	elif path.size() == 1:
		state = AntEnums.State.IDLE
		target = path[0]
	else:
		state = AntEnums.State.IDLE
		target = null

func clear_path(keep_intent: bool = false) -> void:
	path = PackedVector2Array()
	path_index = 0
	target = null
	if not keep_intent or state == AntEnums.State.WALK:
		state = AntEnums.State.IDLE

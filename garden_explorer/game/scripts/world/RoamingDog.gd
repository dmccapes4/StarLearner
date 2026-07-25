class_name RoamingDog
extends Node2D
## Friendly dog that wanders the farm yard and barks when tapped.

const WALK_FRAME_SEC := 0.12
const IDLE_PAUSE_MIN := 1.2
const IDLE_PAUSE_MAX := 3.2

var farm_map: FarmMap
var _target: Vector2 = Vector2.ZERO
var _pause_left: float = 0.8
var _anim_t: float = 0.0
var _frame: int = 0
var _dir_col: int = 2 ## 0 up, 1 right, 2 down, 3 left
var _spr: Sprite2D
var _speed: float = 55.0

func setup(map: FarmMap, art: FarmSprites, spawn: Vector2) -> void:
	farm_map = map
	position = spawn
	_spr = Sprite2D.new()
	_spr.name = "Sprite"
	_spr.centered = true
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var walk: Texture2D = null
	if art and art.has_method("dog_walk_sheet"):
		walk = art.dog_walk_sheet()
	if walk:
		_spr.texture = walk
		_spr.hframes = 4
		_spr.vframes = 4
		_spr.frame = 2 ## down idle
		_spr.scale = Vector2(2.4, 2.4)
		_spr.position = Vector2(0, -10)
	else:
		var idle := art.dog_texture() if art and art.has_method("dog_texture") else null
		if idle:
			_spr.texture = idle
			_spr.scale = Vector2(2.4, 2.4)
			_spr.position = Vector2(0, -10)
	add_child(_spr)
	z_index = IsoUtil.depth_from_y(position.y) + 55
	_pick_new_target()

func _process(delta: float) -> void:
	if farm_map == null:
		return
	if _pause_left > 0.0:
		_pause_left -= delta
		if _spr and _spr.hframes > 1:
			_spr.frame = _dir_col ## idle = first row of that dir column in our sheet layout
			## Our sheet is cols=dirs, rows=frames → frame = row*hframes + col
			_spr.frame = 0 * 4 + _dir_col
		if _pause_left <= 0.0:
			_pick_new_target()
		z_index = IsoUtil.depth_from_y(position.y) + 55
		return
	var to := _target - position
	var dist := to.length()
	if dist <= 6.0:
		_pause_left = randf_range(IDLE_PAUSE_MIN, IDLE_PAUSE_MAX)
		return
	var step := to.normalized() * _speed * delta
	var next := position + step
	if farm_map.is_blocked(next):
		_pause_left = randf_range(0.4, 1.0)
		_pick_new_target()
		return
	position = next
	if farm_map:
		farm_map.animal_positions["dog"] = position
	## Facing
	if absf(to.x) >= absf(to.y):
		_dir_col = 1 if to.x > 0.0 else 3
	else:
		_dir_col = 2 if to.y > 0.0 else 0
	_anim_t += delta
	if _anim_t >= WALK_FRAME_SEC:
		_anim_t = fmod(_anim_t, WALK_FRAME_SEC)
		_frame = (_frame + 1) % 4
	if _spr and _spr.hframes > 1:
		_spr.frame = _frame * 4 + _dir_col
	z_index = IsoUtil.depth_from_y(position.y) + 55

func _pick_new_target() -> void:
	if farm_map == null:
		return
	## Wander near the yard center / path, stay walkable.
	var base: Vector2 = farm_map.spawn_world
	for _i in 12:
		var cand := base + Vector2(randf_range(-220, 280), randf_range(-120, 160))
		cand = farm_map.nearest_walkable(cand)
		if not farm_map.is_blocked(cand):
			_target = cand
			return
	_target = farm_map.spawn_world

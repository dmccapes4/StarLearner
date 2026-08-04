class_name RoamingBug
extends Node2D
## A small tappable bug that wanders near its spawn for a while, then despawns.
## Pauses during interaction; removed (caught) after the interaction ends.
## Stays off garden-bed solids so it isn't painted under the raised wood.

signal despawned(bug_id: String)

const WANDER_RADIUS := 42.0
const LIFETIME_SEC := 60.0

var bug_id: String = ""
var farm_map: FarmMap
var _spr: Sprite2D
var _home: Vector2 = Vector2.ZERO
var _target: Vector2 = Vector2.ZERO
var _speed: float = 16.0
var _pause_left: float = 0.4
var _life_left: float = LIFETIME_SEC
var _interacting: bool = false

func setup(id: String, tex: Texture2D, spawn: Vector2, px_size: float = 14.0, map: FarmMap = null) -> void:
	bug_id = id
	farm_map = map
	position = spawn
	_home = spawn
	_spr = Sprite2D.new()
	_spr.name = "Sprite"
	_spr.centered = true
	_spr.texture = tex
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if tex:
		var sc := px_size / maxf(float(maxi(tex.get_width(), tex.get_height())), 1.0)
		_spr.scale = Vector2(sc, sc)
	add_child(_spr)
	IsoUtil.apply_depth(self, position.y, IsoUtil.BIAS_ANIMAL)
	_pick_target()

func set_interacting(on: bool) -> void:
	_interacting = on
	if on:
		_life_left = maxf(_life_left, 20.0) ## never despawn mid-interaction

func catch_and_free() -> void:
	despawned.emit(bug_id)
	queue_free()

func _process(delta: float) -> void:
	if _interacting:
		return
	_life_left -= delta
	if _life_left <= 0.0:
		despawned.emit(bug_id)
		queue_free()
		return
	## Eject if we somehow landed on / under a bed lip.
	if farm_map and _bug_blocked(position):
		position = _bug_clear(position)
		_home = position
		_pick_target()
		IsoUtil.apply_depth(self, position.y, IsoUtil.BIAS_ANIMAL)
		return
	if _pause_left > 0.0:
		_pause_left -= delta
		if _pause_left <= 0.0:
			_pick_target()
		return
	var to := _target - position
	if to.length() <= 2.0:
		_pause_left = randf_range(0.5, 1.6)
		return
	var next := position + to.normalized() * _speed * delta
	if farm_map and _bug_blocked(next):
		_pause_left = randf_range(0.3, 0.9)
		_pick_target()
		return
	position = next
	if _spr:
		_spr.flip_h = to.x < 0.0
	IsoUtil.apply_depth(self, position.y, IsoUtil.BIAS_ANIMAL)

func _bug_blocked(p: Vector2) -> bool:
	if farm_map == null:
		return false
	if farm_map.has_method("is_blocked_for_bug"):
		return farm_map.is_blocked_for_bug(p)
	return farm_map.is_blocked(p)

func _bug_clear(p: Vector2) -> Vector2:
	if farm_map.has_method("nearest_bug_walkable"):
		return farm_map.nearest_bug_walkable(p)
	return farm_map.nearest_walkable(p)

func _pick_target() -> void:
	for _i in 10:
		var cand := _home + Vector2(
			randf_range(-WANDER_RADIUS, WANDER_RADIUS),
			randf_range(-WANDER_RADIUS * 0.7, WANDER_RADIUS * 0.7))
		if not _bug_blocked(cand):
			_target = cand
			return
	_target = _bug_clear(_home) if farm_map else _home

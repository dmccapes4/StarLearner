class_name RoamingBug
extends Node2D
## A small tappable bug that wanders near its spawn for a while, then despawns.
## Pauses during interaction; removed (caught) after the interaction ends.

signal despawned(bug_id: String)

const WANDER_RADIUS := 42.0
const LIFETIME_SEC := 60.0

var bug_id: String = ""
var _spr: Sprite2D
var _home: Vector2 = Vector2.ZERO
var _target: Vector2 = Vector2.ZERO
var _speed: float = 16.0
var _pause_left: float = 0.4
var _life_left: float = LIFETIME_SEC
var _interacting: bool = false

func setup(id: String, tex: Texture2D, spawn: Vector2, px_size: float = 14.0) -> void:
	bug_id = id
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
	z_index = IsoUtil.depth_from_y(position.y) + 52
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
	if _pause_left > 0.0:
		_pause_left -= delta
		if _pause_left <= 0.0:
			_pick_target()
		return
	var to := _target - position
	if to.length() <= 2.0:
		_pause_left = randf_range(0.5, 1.6)
		return
	position += to.normalized() * _speed * delta
	if _spr:
		_spr.flip_h = to.x < 0.0
	z_index = IsoUtil.depth_from_y(position.y) + 52

func _pick_target() -> void:
	_target = _home + Vector2(randf_range(-WANDER_RADIUS, WANDER_RADIUS), randf_range(-WANDER_RADIUS * 0.7, WANDER_RADIUS * 0.7))

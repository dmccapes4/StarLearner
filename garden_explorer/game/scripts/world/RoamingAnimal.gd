class_name RoamingAnimal
extends Node2D
## Farm animal (or yard dog) that wanders inside a polygon bound.

signal arrived_near_player()

const WALK_FRAME_SEC := 0.14
const IDLE_PAUSE_MIN := 1.0
const IDLE_PAUSE_MAX := 2.8

var animal_id: String = ""
var farm_map: FarmMap
var bound_poly: PackedVector2Array = PackedVector2Array()
var _target: Vector2 = Vector2.ZERO
var _pause_left: float = 0.6
var _anim_t: float = 0.0
var _frame: int = 0
var _dir_col: int = 2
var _spr: Sprite2D
var _speed: float = 42.0
var _has_walk_sheet: bool = false
var follow_locked: bool = false ## when player is chasing this animal
## Interaction: animal pauses in a happy stance facing the player.
var _interacting: bool = false
var _heart: Sprite2D
var _hop_tween: Tween

func setup(id: String, map: FarmMap, art: FarmSprites, spawn: Vector2, bound: PackedVector2Array, scale_mul: float = 3.5, kind: String = "", color: String = "default") -> void:
	animal_id = id
	farm_map = map
	bound_poly = bound
	position = spawn
	_spr = Sprite2D.new()
	_spr.name = "Sprite"
	_spr.centered = true
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var tex: Texture2D = null
	var walk: Texture2D = null
	match kind:
		"dog":
			walk = art.dog_walk_sheet() if art else null
			tex = art.dog_texture() if art else null
			_speed = 52.0
		"chicken":
			tex = art.chicken_texture(color) if art else null
			_speed = 38.0
		"cow":
			tex = art.cow_texture() if art else null
			_speed = 28.0
		"pig":
			tex = art.pig_texture() if art else null
			_speed = 34.0
		"rabbit":
			tex = art.rabbit_texture() if art else null
			_speed = 46.0
		_:
			tex = null
	if walk:
		_spr.texture = walk
		_spr.hframes = 4
		_spr.vframes = 4
		_spr.frame = 2
		_has_walk_sheet = true
	elif tex:
		_spr.texture = tex
	_spr.scale = Vector2(scale_mul, scale_mul)
	_spr.position = Vector2(0, -6)
	add_child(_spr)
	z_index = IsoUtil.depth_from_y(position.y) + 55
	_sync_map_pos()
	_pick_new_target()

func global_feet() -> Vector2:
	return global_position

func set_interacting(on: bool, face_world: Vector2 = Vector2.ZERO) -> void:
	## Happy greeting: freeze in place, face the player, hop with a heart.
	_interacting = on
	if on:
		var to := face_world - global_position
		if _spr:
			if _has_walk_sheet:
				if absf(to.x) >= absf(to.y):
					_dir_col = 1 if to.x > 0.0 else 3
				else:
					_dir_col = 2 if to.y > 0.0 else 0
				_spr.frame = _dir_col
			else:
				_spr.flip_h = to.x < 0.0
		_show_heart(true)
		_start_hop()
	else:
		_show_heart(false)
		if _hop_tween and _hop_tween.is_valid():
			_hop_tween.kill()
		if _spr:
			_spr.position = Vector2(0, -6)
		_pause_left = randf_range(0.4, 1.2)

func _show_heart(on: bool) -> void:
	if _heart == null:
		_heart = Sprite2D.new()
		_heart.name = "HeartEmote"
		var tex: Texture2D = null
		if ResourceLoader.exists("res://assets/ui/emote_heart.png"):
			tex = load("res://assets/ui/emote_heart.png")
		_heart.texture = tex
		_heart.scale = Vector2(1.4, 1.4)
		_heart.position = Vector2(0, -34)
		_heart.z_index = 20
		add_child(_heart)
	_heart.visible = on and _heart.texture != null

func _start_hop() -> void:
	if _spr == null:
		return
	if _hop_tween and _hop_tween.is_valid():
		_hop_tween.kill()
	_hop_tween = create_tween().set_loops(3)
	_hop_tween.tween_property(_spr, "position:y", -14.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hop_tween.tween_property(_spr, "position:y", -6.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _process(delta: float) -> void:
	if farm_map == null:
		return
	if _interacting:
		z_index = IsoUtil.depth_from_y(position.y) + 55
		_sync_map_pos()
		return
	if _pause_left > 0.0:
		_pause_left -= delta
		if _has_walk_sheet and _spr:
			_spr.frame = _dir_col
		if _pause_left <= 0.0:
			_pick_new_target()
		z_index = IsoUtil.depth_from_y(position.y) + 55
		_sync_map_pos()
		return
	var to := _target - position
	var dist := to.length()
	if dist <= 5.0:
		_pause_left = randf_range(IDLE_PAUSE_MIN, IDLE_PAUSE_MAX)
		_sync_map_pos()
		return
	var step := to.normalized() * _speed * delta
	var next := position + step
	if not _inside(next) or (farm_map and _blocked_for_animal(next)):
		_pause_left = randf_range(0.3, 0.9)
		_pick_new_target()
		return
	position = next
	if absf(to.x) >= absf(to.y):
		_dir_col = 1 if to.x > 0.0 else 3
		if _spr and not _has_walk_sheet:
			_spr.flip_h = to.x < 0.0
	else:
		_dir_col = 2 if to.y > 0.0 else 0
	_anim_t += delta
	if _anim_t >= WALK_FRAME_SEC:
		_anim_t = fmod(_anim_t, WALK_FRAME_SEC)
		_frame = (_frame + 1) % 4
	if _has_walk_sheet and _spr:
		_spr.frame = _frame * 4 + _dir_col
	z_index = IsoUtil.depth_from_y(position.y) + 55
	_sync_map_pos()

func _sync_map_pos() -> void:
	if farm_map:
		farm_map.animal_positions[animal_id] = position

func _inside(p: Vector2) -> bool:
	if bound_poly.size() < 3:
		return true
	return IsoUtil.point_in_polygon(p, bound_poly)

func _blocked_for_animal(p: Vector2) -> bool:
	## Pen animals: bound_poly only. Yard dog: stay out of pen + solids.
	if bound_poly.size() >= 3:
		return false
	if farm_map == null:
		return false
	if farm_map.has_method("in_pen") and farm_map.in_pen(p):
		return true
	return farm_map.is_blocked(p)

func _pick_new_target() -> void:
	if bound_poly.size() >= 3:
		var c := _poly_center()
		for _i in 16:
			var cand := c + Vector2(randf_range(-90, 90), randf_range(-70, 70))
			if _inside(cand):
				_target = cand
				return
		_target = c
		return
	## Yard dog: walkable farm, never into the animal pen.
	var base: Vector2 = farm_map.spawn_world if farm_map else position
	for _i in 12:
		var cand2 := base + Vector2(randf_range(-220, 260), randf_range(-120, 150))
		if farm_map:
			cand2 = farm_map.nearest_walkable(cand2)
			if farm_map.has_method("in_pen") and farm_map.in_pen(cand2):
				continue
			if not farm_map.is_blocked(cand2):
				_target = cand2
				return
	_target = base

func _poly_center() -> Vector2:
	var s := Vector2.ZERO
	for p in bound_poly:
		s += p
	return s / float(bound_poly.size())

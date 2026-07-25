class_name Player
extends Node2D
## Gardener avatar — tap-to-walk with A* routing around shed / beds / pen.

var target: Vector2 = Vector2.ZERO
var moving: bool = false
var _waypoints: PackedVector2Array = PackedVector2Array()
var _wp_i: int = 0

## Walk-sheet animation (3 rows x 6 cols; row 0 down, 1 right, 2 up).
const WALK_FRAME_SEC := 0.135
const IDLE_COL := 1
var _anim_mode: bool = false
var _anim_t: float = 0.0
var _anim_col: int = IDLE_COL
var _dir_row: int = 0
var _face_left: bool = false

@onready var _body: Polygon2D = $Body
@onready var _hat: Polygon2D = $Hat

func _ready() -> void:
	_wire_events()
	_wire_seed_carry()
	_ensure_placeholder()

func apply_sprites(art: FarmSprites) -> void:
	if art == null:
		return
	var spr := get_node_or_null("Sprite") as Sprite2D
	if spr == null:
		spr = Sprite2D.new()
		spr.name = "Sprite"
		add_child(spr)
	var walk := art.character_walk_sheet() if art.has_method("character_walk_sheet") else null
	if walk != null:
		## Animated Mana Seed gardener: ~32px girl in 64px cells, feet at y≈44.
		spr.texture = walk
		spr.hframes = 6
		spr.vframes = 3
		spr.frame = IDLE_COL
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.centered = true
		var sc := 2.3
		spr.scale = Vector2(sc, sc)
		spr.position = Vector2(0, -12.0 * sc)
		_anim_mode = true
	else:
		var tex := art.character_idle()
		if tex == null:
			return
		spr.texture = tex
		## Tall billboard girl — feet near origin.
		var target_h := 72.0
		var th := float(tex.get_height())
		var sc2 := target_h / maxf(th, 1.0)
		spr.scale = Vector2(sc2, sc2)
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		spr.centered = true
		spr.position = Vector2(0, -target_h * 0.42)
		_anim_mode = false
	if _body:
		_body.visible = false
	if _hat:
		_hat.visible = false

func place_at(world_pos: Vector2) -> void:
	_wire_events()
	_ensure_placeholder()
	var farm := _farm()
	global_position = farm.nearest_walkable(world_pos) if farm else world_pos
	target = global_position
	moving = false
	_waypoints = PackedVector2Array()
	_wp_i = 0
	z_index = IsoUtil.depth_from_y(global_position.y) + 50
	_wire_seed_carry()

func _wire_seed_carry() -> void:
	if not Events.seed_selected.is_connected(_on_seed_carry):
		Events.seed_selected.connect(_on_seed_carry)
	if not Events.seed_cleared.is_connected(_on_seed_cleared):
		Events.seed_cleared.connect(_on_seed_cleared)

func _on_seed_carry(plant_id: String) -> void:
	var art := _sprites()
	var spr := get_node_or_null("HeldSeed") as Sprite2D
	if spr == null:
		spr = Sprite2D.new()
		spr.name = "HeldSeed"
		spr.centered = true
		spr.z_index = 5
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(spr)
	if art:
		spr.texture = art.seed_icon(plant_id)
	spr.scale = Vector2(2.4, 2.4)
	spr.position = Vector2(22, -28)
	spr.visible = spr.texture != null

func _on_seed_cleared() -> void:
	var spr := get_node_or_null("HeldSeed") as Sprite2D
	if spr:
		spr.visible = false
		spr.texture = null

func _sprites() -> FarmSprites:
	var world := get_parent()
	if world and world.get("sprites") != null:
		return world.sprites as FarmSprites
	return null

func _wire_events() -> void:
	if not Events.player_path_requested.is_connected(_on_path_requested):
		Events.player_path_requested.connect(_on_path_requested)

func _farm() -> FarmMap:
	return get_parent().get_node_or_null("FarmMap") as FarmMap

func _on_path_requested(world_pos: Vector2) -> void:
	var NarratorScript := preload("res://scripts/audio/Narrator.gd")
	if NarratorScript.blocks_movement():
		return
	var farm := _farm()
	if farm:
		_waypoints = farm.find_path(global_position, world_pos)
		if _waypoints.is_empty():
			target = farm.nearest_walkable(world_pos)
			_wp_i = 0
		else:
			_wp_i = 0
			target = _waypoints[0]
	else:
		_waypoints = PackedVector2Array()
		target = world_pos
		_wp_i = 0
	moving = true

func _process(delta: float) -> void:
	var NarratorScript := preload("res://scripts/audio/Narrator.gd")
	if NarratorScript.blocks_movement():
		moving = false
		_update_anim(Vector2.ZERO, delta)
		return
	if not moving:
		_update_anim(Vector2.ZERO, delta)
		return
	var to := target - global_position
	var dist := to.length()
	var speed := Config.get_walk_speed()
	if dist <= Config.get_arrive_eps() or dist <= speed * delta:
		global_position = target
		## Advance along the routed path.
		if _wp_i + 1 < _waypoints.size():
			_wp_i += 1
			target = _waypoints[_wp_i]
			z_index = IsoUtil.depth_from_y(global_position.y) + 50
			return
		moving = false
		_waypoints = PackedVector2Array()
		_wp_i = 0
		## Nudge out if we somehow ended inside a collider.
		var farm := _farm()
		if farm and farm.is_blocked(global_position):
			global_position = farm.nearest_walkable(global_position)
		z_index = IsoUtil.depth_from_y(global_position.y) + 50
		Events.player_arrived.emit()
		return
	var step := to.normalized() * speed * delta
	var next := global_position + step
	## Soft collision: don't stride into solid tiles mid-segment.
	var farm2 := _farm()
	if farm2 and farm2.is_blocked(next):
		## Skip toward next waypoint / repath remainder.
		if _wp_i + 1 < _waypoints.size():
			_wp_i += 1
			target = _waypoints[_wp_i]
			return
		global_position = farm2.nearest_walkable(global_position)
		moving = false
		Events.player_arrived.emit()
		return
	global_position = next
	z_index = IsoUtil.depth_from_y(global_position.y) + 50
	_update_anim(to, delta)

func _update_anim(move_dir: Vector2, delta: float) -> void:
	var spr := get_node_or_null("Sprite") as Sprite2D
	if spr == null:
		if _body and absf(move_dir.x) > 2.0:
			_body.scale.x = -1.0 if move_dir.x < 0.0 else 1.0
			if _hat:
				_hat.scale.x = _body.scale.x
		return
	if not _anim_mode:
		if absf(move_dir.x) > 2.0:
			spr.flip_h = move_dir.x < 0.0
		return
	var walking := move_dir.length_squared() > 0.01
	if walking:
		## Iso movement is mostly diagonal — prefer the side view.
		if absf(move_dir.x) >= absf(move_dir.y) * 0.85:
			_dir_row = 1
			_face_left = move_dir.x < 0.0
		else:
			_dir_row = 0 if move_dir.y > 0.0 else 2
		_anim_t += delta
		if _anim_t >= WALK_FRAME_SEC:
			_anim_t = fmod(_anim_t, WALK_FRAME_SEC)
			_anim_col = (_anim_col + 1) % 6
	else:
		_anim_t = 0.0
		_anim_col = IDLE_COL
	spr.frame = _dir_row * 6 + _anim_col
	spr.flip_h = _dir_row == 1 and _face_left

func _ensure_placeholder() -> void:
	if _body == null:
		_body = Polygon2D.new()
		_body.name = "Body"
		add_child(_body)
	_body.color = Color(0.30, 0.55, 0.85, 1.0)
	_body.polygon = PackedVector2Array([
		Vector2(-12, 8), Vector2(-10, -10), Vector2(0, -18),
		Vector2(10, -10), Vector2(12, 8), Vector2(0, 14),
	])
	if _hat == null:
		_hat = Polygon2D.new()
		_hat.name = "Hat"
		add_child(_hat)
	_hat.color = Color(0.85, 0.55, 0.20, 1.0)
	_hat.polygon = PackedVector2Array([
		Vector2(-14, -14), Vector2(14, -14), Vector2(10, -22), Vector2(-10, -22),
	])

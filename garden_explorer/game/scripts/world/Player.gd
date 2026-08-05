class_name Player
extends Node2D
## Gardener avatar — tap-to-walk with A* routing around shed / beds / pen.

var target: Vector2 = Vector2.ZERO
var moving: bool = false
var _waypoints: PackedVector2Array = PackedVector2Array()
var _wp_i: int = 0
var _held_goal: Vector2 = Vector2.INF ## Tap taken during VO — walked once unlocked.

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
	_apply_player_depth()
	_wire_seed_carry()

func _apply_player_depth() -> void:
	var feet_y := global_position.y
	var farm := _farm()
	if farm and farm.has_method("player_depth_y"):
		feet_y = farm.player_depth_y(global_position)
	IsoUtil.apply_depth(self, feet_y, IsoUtil.BIAS_PLAYER)

func face_toward(world_pos: Vector2) -> void:
	## Idle pose looking at a target (bed / pet / door) after arrive.
	var d := world_pos - global_position
	if d.length_squared() < 0.25:
		return
	if absf(d.x) >= absf(d.y) * 0.85:
		_dir_row = 1
		_face_left = d.x < 0.0
	else:
		## Row 0 = toward camera (+y), row 2 = away (-y).
		_dir_row = 0 if d.y > 0.0 else 2
	_anim_col = IDLE_COL
	_anim_t = 0.0
	var spr := get_node_or_null("Sprite") as Sprite2D
	if spr and _anim_mode:
		spr.frame = _dir_row * 6 + _anim_col
		spr.flip_h = _dir_row == 1 and _face_left
	elif spr:
		spr.flip_h = d.x < 0.0
	elif _body:
		_body.scale.x = -1.0 if d.x < 0.0 else 1.0
		if _hat:
			_hat.scale.x = _body.scale.x

func _wire_seed_carry() -> void:
	if not Events.seed_selected.is_connected(_on_seed_carry):
		Events.seed_selected.connect(_on_seed_carry)
	if not Events.seed_cleared.is_connected(_on_seed_cleared):
		Events.seed_cleared.connect(_on_seed_cleared)
	if not Events.tool_changed.is_connected(_on_tool_carry):
		Events.tool_changed.connect(_on_tool_carry)

func _held_sprite() -> Sprite2D:
	var spr := get_node_or_null("HeldSeed") as Sprite2D
	if spr == null:
		spr = Sprite2D.new()
		spr.name = "HeldSeed"
		spr.centered = true
		spr.z_index = 5
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(spr)
	return spr

func _on_seed_carry(plant_id: String) -> void:
	var art := _sprites()
	var spr := _held_sprite()
	if art:
		spr.texture = art.seed_icon(plant_id)
	spr.scale = Vector2(2.4, 2.4)
	spr.position = Vector2(22, -28)
	spr.rotation_degrees = 0.0
	spr.visible = spr.texture != null

func _on_tool_carry(tool_id: String) -> void:
	if tool_id == "seed":
		return ## seed_selected handles the icon
	var spr := _held_sprite()
	match tool_id:
		## Carry art is 160×160; keep tools a bit larger than the held seed
		## chip but still natural beside the ~2.3× gardener (~64px cells).
		"water":
			spr.texture = _load_tex("res://assets/ui/carry_watering_can.png")
			spr.scale = Vector2(0.32, 0.32)
			spr.position = Vector2(22, -28)
		"uproot":
			spr.texture = _load_tex("res://assets/ui/carry_spade.png")
			spr.scale = Vector2(0.32, 0.32)
			spr.position = Vector2(20, -30)
		_:
			spr.texture = null
			spr.visible = false
			return
	spr.rotation_degrees = 0.0
	spr.visible = spr.texture != null

func _on_seed_cleared() -> void:
	var spr := get_node_or_null("HeldSeed") as Sprite2D
	if spr:
		spr.visible = false
		spr.texture = null
		spr.rotation_degrees = 0.0

func _load_tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	if FileAccess.file_exists(path):
		var img := Image.load_from_file(path)
		if img:
			return ImageTexture.create_from_image(img)
	return null

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
		## Hold the goal instead of dropping it — the walk starts when VO ends.
		_held_goal = world_pos
		return
	_held_goal = Vector2.INF
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

func stop() -> void:
	## Suites / demos teleport with global_position — re-sort so we never keep
	## a stale spawn z_index under a bed lip.
	_held_goal = Vector2.INF
	moving = false
	_waypoints = PackedVector2Array()
	_wp_i = 0
	target = global_position
	_apply_player_depth()

func _process(delta: float) -> void:
	var NarratorScript := preload("res://scripts/audio/Narrator.gd")
	if NarratorScript.blocks_movement():
		## Stand still while VO plays, but keep the route: cancelling here left the
		## avatar parked short of the bed, unfacing, with the tap's action pending.
		_apply_player_depth()
		_update_anim(Vector2.ZERO, delta)
		return
	if _held_goal != Vector2.INF:
		var goal := _held_goal
		_held_goal = Vector2.INF
		_on_path_requested(goal)
	if not moving:
		## Idle: keep depth fresh after teleports / camera demos.
		_apply_player_depth()
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
			_apply_player_depth()
			return
		moving = false
		_waypoints = PackedVector2Array()
		_wp_i = 0
		## Nudge out if we somehow ended inside a collider.
		var farm := _farm()
		if farm and farm.is_blocked(global_position):
			global_position = farm.nearest_walkable(global_position)
		_apply_player_depth()
		Events.player_arrived.emit()
		return
	var step := to.normalized() * speed * delta
	var next := global_position + step
	## Soft collision: don't stride into solid tiles mid-segment,
	## and never cut through the pen fence away from the gate.
	var farm2 := _farm()
	if farm2 and farm2.has_method("crossing_allowed") and not farm2.crossing_allowed(global_position, next):
		if _wp_i + 1 < _waypoints.size():
			_wp_i += 1
			target = _waypoints[_wp_i]
			return
		## Soft-block at end of path — snap to last goal if possible, then arrive.
		global_position = farm2.nearest_walkable(target)
		moving = false
		_waypoints = PackedVector2Array()
		_wp_i = 0
		_apply_player_depth()
		Events.player_arrived.emit()
		return
	if farm2 and farm2.is_blocked(next):
		## Skip toward next waypoint / repath remainder.
		if _wp_i + 1 < _waypoints.size():
			_wp_i += 1
			target = _waypoints[_wp_i]
			return
		global_position = farm2.nearest_walkable(target)
		moving = false
		_waypoints = PackedVector2Array()
		_wp_i = 0
		_apply_player_depth()
		Events.player_arrived.emit()
		return
	## Soft-avoid pen pets only. Buddy (yard dog) yields on his own — player
	## soft-push toward/around him was forcing face-toward-dog walk glitches.
	if farm2 and farm2.has_method("near_roaming_animal"):
		var aid := str(farm2.near_roaming_animal(next))
		if not aid.is_empty() and not aid.begins_with("dog"):
			var apos: Vector2 = farm2.animal_positions.get(aid, next)
			var away := next - apos
			if away.length_squared() < 1.0:
				away = to if to.length_squared() >= 1.0 else Vector2(1.0, 0.0)
			var soft_r := FarmMap.ANIMAL_SOFT_R + 2.0
			var cand: Vector2 = apos + away.normalized() * soft_r
			cand = cand.lerp(next, 0.35)
			if farm2.is_blocked(cand) \
					or (farm2.has_method("crossing_allowed") \
					and not farm2.crossing_allowed(global_position, cand)):
				if _wp_i + 1 < _waypoints.size():
					_wp_i += 1
					target = _waypoints[_wp_i]
					return
				moving = false
				_waypoints = PackedVector2Array()
				_wp_i = 0
				Events.player_arrived.emit()
				return
			next = cand
	var step_dir := next - global_position
	global_position = next
	## Depth: when south of a nearby bed lip, sort slightly past the bed so the
	## head is never painted under the wood/plants at the same Y band.
	var feet_y := global_position.y
	if farm2 and farm2.has_method("player_depth_y"):
		feet_y = farm2.player_depth_y(global_position)
	IsoUtil.apply_depth(self, feet_y, IsoUtil.BIAS_PLAYER)
	## Face the way we actually stepped (not the raw waypoint through a pet).
	_update_anim(step_dir if step_dir.length_squared() > 0.01 else to, delta)

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

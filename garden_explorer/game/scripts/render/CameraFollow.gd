class_name CameraFollow
extends Camera2D
## Soft-follow the player. Zoomed in; clamped so meadow never leaves the frame.

signal pan_arrived()

@export var target_path: NodePath
@export var lerp_override: float = -1.0
@export var snap_distance: float = 280.0

const MODE_FOLLOW := 0
const MODE_PAN := 1

var _target: Node2D
var _mode: int = MODE_FOLLOW
var _pan_dest: Vector2 = Vector2.ZERO
var _pan_speed: float = 520.0
var _pan_arrive_eps: float = 18.0
var _pan_emitted: bool = false
var _limits: Rect2 = Rect2() ## world-space AABB the camera center may sit in
var _limits_ready: bool = false

func _ready() -> void:
	position_smoothing_enabled = false
	make_current()
	zoom = Vector2(Config.get_camera_zoom(), Config.get_camera_zoom())
	if target_path != NodePath():
		_target = get_node_or_null(target_path) as Node2D

func set_follow_target(t: Node2D) -> void:
	_target = t
	_mode = MODE_FOLLOW
	if _target != null and is_instance_valid(_target):
		global_position = _clamp_cam(_target.global_position)

func set_world_limits(meadow_aabb: Rect2) -> void:
	## Keep the full viewport inside the meadow AABB (no empty sky past the grass).
	var vp := get_viewport().get_visible_rect().size
	var z := zoom.x if zoom.x > 0.01 else 1.0
	var half := vp / (z * 2.0)
	var lim := meadow_aabb.grow_individual(-half.x, -half.y, -half.x, -half.y)
	if lim.size.x < 8.0 or lim.size.y < 8.0:
		## Meadow smaller than view — pin to center.
		_limits = Rect2(meadow_aabb.get_center() - Vector2(4, 4), Vector2(8, 8))
	else:
		_limits = lim
	_limits_ready = true
	global_position = _clamp_cam(global_position)

func snap_to_target() -> void:
	if _target != null and is_instance_valid(_target):
		global_position = _clamp_cam(_target.global_position)

func is_panning() -> bool:
	return _mode == MODE_PAN

func begin_pan_to(world_pos: Vector2, duration_sec: float = 1.4) -> void:
	_mode = MODE_PAN
	_pan_dest = _clamp_cam(world_pos)
	_pan_emitted = false
	var dist := global_position.distance_to(_pan_dest)
	var dur := maxf(duration_sec, 0.35)
	_pan_speed = maxf(dist / dur, 180.0)

func resume_follow(t: Node2D = null, snap: bool = false) -> void:
	if t != null:
		_target = t
	_mode = MODE_FOLLOW
	_pan_emitted = false
	if snap:
		snap_to_target()

func _clamp_cam(pos: Vector2) -> Vector2:
	if not _limits_ready:
		return pos
	return Vector2(
		clampf(pos.x, _limits.position.x, _limits.end.x),
		clampf(pos.y, _limits.position.y, _limits.end.y)
	)

func _process(delta: float) -> void:
	## Keep zoom locked to config (kid play: always close-in).
	var z := Config.get_camera_zoom()
	if absf(zoom.x - z) > 0.001:
		zoom = Vector2(z, z)
	if _mode == MODE_PAN:
		_process_pan(delta)
		return
	if _target == null or not is_instance_valid(_target):
		return
	var dest := _clamp_cam(_target.global_position)
	if global_position.distance_to(dest) > snap_distance:
		global_position = dest
		return
	var rate: float = lerp_override if lerp_override >= 0.0 else Config.get_camera_lerp()
	global_position = global_position.lerp(dest, rate)

func _process_pan(delta: float) -> void:
	var to := _pan_dest - global_position
	var dist := to.length()
	if dist <= _pan_arrive_eps or dist <= _pan_speed * delta:
		global_position = _pan_dest
		if not _pan_emitted:
			_pan_emitted = true
			pan_arrived.emit()
		return
	global_position += to.normalized() * _pan_speed * delta

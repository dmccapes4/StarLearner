class_name CameraFollow
extends Camera2D
## Soft-follow the player ant. Snaps when far so the nest is never off-screen at boot.
## Also supports a one-shot pan (star reveal tour) that abandons the follow target.

signal pan_arrived()

@export var target_path: NodePath
@export var lerp_override: float = -1.0  ## <0 → use Config
@export var snap_distance: float = 240.0

const MODE_FOLLOW := 0
const MODE_PAN := 1

var _target: Node2D
var _mode: int = MODE_FOLLOW
var _pan_dest: Vector2 = Vector2.ZERO
var _pan_speed: float = 520.0
var _pan_arrive_eps: float = 18.0
var _pan_emitted: bool = false

func _ready() -> void:
	position_smoothing_enabled = false
	make_current()
	if target_path != NodePath():
		_target = get_node_or_null(target_path) as Node2D

func set_follow_target(t: Node2D) -> void:
	_target = t
	_mode = MODE_FOLLOW
	if _target != null and is_instance_valid(_target):
		global_position = _target.global_position

func snap_to_target() -> void:
	if _target != null and is_instance_valid(_target):
		global_position = _target.global_position

func is_panning() -> bool:
	return _mode == MODE_PAN

## Abandon the follow target and glide toward a world point (star reveal).
## Prefer `duration_sec` so far-away stars still arrive in a kid-friendly beat.
func begin_pan_to(world_pos: Vector2, speed_or_duration: float = 1.8, as_duration: bool = true) -> void:
	_mode = MODE_PAN
	_pan_dest = world_pos
	_pan_emitted = false
	var dist := global_position.distance_to(world_pos)
	if as_duration:
		var dur := maxf(speed_or_duration, 0.35)
		_pan_speed = maxf(dist / dur, 180.0)
	else:
		_pan_speed = maxf(speed_or_duration, 80.0)

## Resume soft-follow. If `snap`, jump to the target immediately.
func resume_follow(t: Node2D = null, snap: bool = false) -> void:
	if t != null:
		_target = t
	_mode = MODE_FOLLOW
	_pan_emitted = false
	if snap:
		snap_to_target()

func _process(delta: float) -> void:
	if _mode == MODE_PAN:
		_process_pan(delta)
		return
	if _target == null or not is_instance_valid(_target):
		return
	var dest := _target.global_position
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

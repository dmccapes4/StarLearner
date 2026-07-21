class_name CameraFollow
extends Camera2D
## Soft-follow the player ant. Snaps when far so the nest is never off-screen at boot.

@export var target_path: NodePath
@export var lerp_override: float = -1.0  ## <0 → use Config
@export var snap_distance: float = 240.0

var _target: Node2D

func _ready() -> void:
	position_smoothing_enabled = false
	make_current()
	if target_path != NodePath():
		_target = get_node_or_null(target_path) as Node2D

func set_follow_target(t: Node2D) -> void:
	_target = t
	if _target != null and is_instance_valid(_target):
		global_position = _target.global_position

func snap_to_target() -> void:
	if _target != null and is_instance_valid(_target):
		global_position = _target.global_position

func _process(_delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		return
	var dest := _target.global_position
	if global_position.distance_to(dest) > snap_distance:
		global_position = dest
		return
	var rate: float = lerp_override if lerp_override >= 0.0 else Config.get_camera_lerp()
	global_position = global_position.lerp(dest, rate)

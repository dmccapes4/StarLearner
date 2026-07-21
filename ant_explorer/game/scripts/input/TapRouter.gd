class_name TapRouter
extends Node
## Converts screen taps to world positions and emits path requests.

@export var camera_path: NodePath

var _camera: Camera2D
var _enabled: bool = true

func _ready() -> void:
	if camera_path != NodePath():
		_camera = get_node_or_null(camera_path) as Camera2D

func set_camera(cam: Camera2D) -> void:
	_camera = cam

func _unhandled_input(event: InputEvent) -> void:
	if not _enabled:
		return
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_emit_tap(st.position)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_emit_tap(mb.position)
			get_viewport().set_input_as_handled()

func _emit_tap(screen_pos: Vector2) -> void:
	var world := _screen_to_world(screen_pos)
	Events.world_tapped.emit(world)
	Events.player_path_requested.emit(world)

func _screen_to_world(screen_pos: Vector2) -> Vector2:
	var xform := get_viewport().get_canvas_transform()
	return xform.affine_inverse() * screen_pos

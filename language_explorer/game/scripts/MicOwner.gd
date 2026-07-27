extends Node
## Autoload: Language Explorer keeps exclusive mic ownership for the process life.
## Recording is only active during Voice clips; the input stream stays held.

const MicCaptureS := preload("res://scripts/voice/MicCapture.gd")

var _cap: Node

func _ready() -> void:
	_cap = MicCaptureS.new()
	_cap.name = "MicCapture"
	add_child(_cap)
	call_deferred("_boot_hold")

func _boot_hold() -> void:
	await MicCaptureS.ensure_permission(get_tree())
	if _cap != null:
		_cap.hold()

func _notification(what: int) -> void:
	# Re-claim after Android focus thrash / returning from another title.
	if what == NOTIFICATION_APPLICATION_FOCUS_IN \
			or what == NOTIFICATION_APPLICATION_RESUMED \
			or what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		if _cap != null:
			_cap.hold()

func capture() -> Node:
	return _cap

func hold() -> bool:
	if _cap == null:
		return false
	return bool(_cap.hold())

func release() -> void:
	if _cap != null:
		_cap.release()

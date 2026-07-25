class_name DoubleTapArm
extends RefCounted
## Kid-thumb arm + timeout (not OS double-click). Second tap on same key within window confirms.

const RESULT_ARMED := "armed"
const RESULT_TRIGGER := "trigger"

var window: float = 5.0
var armed_key: String = ""
var _armed_at: float = -1.0

func _init(window_seconds: float = 5.0) -> void:
	window = window_seconds

func is_armed() -> bool:
	return not armed_key.is_empty()

func is_armed_for(key: String) -> bool:
	return not key.is_empty() and armed_key == key

func press(key: String, now: float) -> String:
	if is_armed_for(key) and (now - _armed_at) <= window:
		clear()
		return RESULT_TRIGGER
	armed_key = key
	_armed_at = now
	return RESULT_ARMED

func poll(now: float) -> bool:
	if is_armed() and (now - _armed_at) > window:
		clear()
		return true
	return false

func rearm(key: String, now: float) -> void:
	armed_key = key
	_armed_at = now

func clear() -> void:
	armed_key = ""
	_armed_at = -1.0

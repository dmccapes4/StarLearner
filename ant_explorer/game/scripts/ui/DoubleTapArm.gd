class_name DoubleTapArm
extends RefCounted
## Kid-thumb "double tap" as arm + timeout — NOT an OS double-click.
##
## First tap on a key arms it. A second tap on the SAME key within `window`
## seconds confirms (TRIGGER). Tapping a different key re-arms to that key
## (only one key armed at a time). If the window lapses with no confirming tap,
## the arm clears and the next tap is a fresh first tap.
##
## Used twice, independently: collected-tile "tap again to watch" and the
## chrome "double-tap to hide/show rails" gestures (separate instances).

const RESULT_ARMED := "armed"
const RESULT_TRIGGER := "trigger"

var window: float = 1.0
var armed_key: String = ""
var _armed_at: float = -1.0

func _init(window_seconds: float = 1.0) -> void:
	window = window_seconds

func is_armed() -> bool:
	return not armed_key.is_empty()

func is_armed_for(key: String) -> bool:
	return not key.is_empty() and armed_key == key

## Register a tap on `key` at absolute time `now` (seconds).
## Returns RESULT_TRIGGER on the confirming second tap, else RESULT_ARMED.
func press(key: String, now: float) -> String:
	if is_armed_for(key) and (now - _armed_at) <= window:
		clear()
		return RESULT_TRIGGER
	armed_key = key
	_armed_at = now
	return RESULT_ARMED

## Clear the arm if the window has elapsed. Returns true if it expired on this call.
func poll(now: float) -> bool:
	if is_armed() and (now - _armed_at) > window:
		clear()
		return true
	return false

func clear() -> void:
	armed_key = ""
	_armed_at = -1.0

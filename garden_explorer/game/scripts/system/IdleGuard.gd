extends Node
## Pause audio when backgrounded; after long idle, soft VO then exit to home.

const WARN_SEC := 180.0
const EXIT_SEC := 300.0

var _idle_sec: float = 0.0
var _warned: bool = false
var _app_bg: bool = false
var _active: bool = true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_input(true)
	if OS.has_feature("movie"):
		set_active(false)

func set_active(on: bool) -> void:
	_active = on
	set_process(on)
	set_process_input(on)
	if not on:
		_idle_sec = 0.0
		_warned = false
		_app_bg = false
		AudioServer.set_bus_mute(0, false)

func _notification(what: int) -> void:
	if not _active:
		return
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			_app_bg = true
			Save.save_if_dirty()
			AudioServer.set_bus_mute(0, true)
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN:
			_app_bg = false
			AudioServer.set_bus_mute(0, false)
			bump()

func _process(delta: float) -> void:
	if not _active or _app_bg:
		return
	_idle_sec += delta
	if not _warned and _idle_sec >= WARN_SEC:
		_warned = true
		_speak("Still there? Tap the garden to keep playing.")
	if _idle_sec >= EXIT_SEC:
		_exit_home()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		bump()
	elif event is InputEventScreenTouch and event.pressed:
		bump()

func bump() -> void:
	_idle_sec = 0.0
	_warned = false

func _speak(line: String) -> void:
	var N := preload("res://scripts/audio/Narrator.gd")
	N.speak(line)

func _exit_home() -> void:
	Save.save_if_dirty()
	print("IdleGuard: returning to Star Learner")
	get_tree().quit()

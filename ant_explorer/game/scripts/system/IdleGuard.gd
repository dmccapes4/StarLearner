extends Node
## Autoload: pause sim when backgrounded; after 5 min idle, save and return home.
##
## Power-button / app-switch must not keep the colony ticking (even slowly).
## Six-year-olds walk away — quietly park the game under Star Learner.

const IdlePolicy := preload("res://scripts/system/IdlePolicy.gd")

var _idle_sec: float = 0.0
var _warned: bool = false
var _app_bg: bool = false
var _exiting: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_input(true)
	set_process_unhandled_input(true)

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			_enter_background()
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN:
			_leave_background()

func _enter_background() -> void:
	if _app_bg:
		return
	_app_bg = true
	# Freeze sim immediately — do not let ticks crawl while the screen is black.
	SimClock.set_enabled(false)
	Save.save_if_dirty()
	AudioServer.set_bus_mute(0, true)
	# Idle clock pauses in background; resume will bump activity.

func _leave_background() -> void:
	if not _app_bg:
		return
	_app_bg = false
	_exiting = false
	AudioServer.set_bus_mute(0, false)
	SimClock.set_enabled(true)
	bump()

func _process(delta: float) -> void:
	if _app_bg or _exiting:
		return
	# Wall-clock idle only while the game is actually in front.
	_idle_sec += delta
	if IdlePolicy.should_warn(_idle_sec, _warned):
		_warned = true
		_speak_still_there()
	if IdlePolicy.should_exit(_idle_sec):
		_exit_to_home()

func _input(event: InputEvent) -> void:
	if _is_activity(event):
		bump()

func _unhandled_input(event: InputEvent) -> void:
	if _is_activity(event):
		bump()

func bump() -> void:
	_idle_sec = 0.0
	_warned = false

func _is_activity(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	if event is InputEventScreenDrag:
		return true
	if event is InputEventMouseButton:
		return (event as InputEventMouseButton).pressed
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		return mm.button_mask != 0
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("tap"):
		return true
	return false

func _speak_still_there() -> void:
	var line := "Still exploring? Tap the screen to keep playing."
	if DisplayServer.tts_get_voices().size() > 0:
		DisplayServer.tts_stop()
		DisplayServer.tts_speak(line, "", 1.0, 1.0, 0.95)
	else:
		print("IdleGuard: %s" % line)

func _exit_to_home() -> void:
	if _exiting:
		return
	_exiting = true
	# Capture last pose, then leave without killing the process (warm resume later).
	var world := get_tree().get_first_node_in_group("world")
	if world != null and world.get("colony") != null:
		var player = world.colony.get_player()
		if player != null:
			Save.set_player_pos(player.cell)
	Save.save_if_dirty()
	SimClock.set_enabled(false)
	if not _go_home_android():
		# Desktop / editor: just quit cleanly.
		get_tree().quit()

func _go_home_android() -> bool:
	if not OS.has_feature("android"):
		return false
	var runtime: Object = Engine.get_singleton("AndroidRuntime")
	if runtime == null:
		return false
	var activity: Variant = runtime.getActivity()
	if activity == null:
		return false
	# Same path as the hardware Back button — Star Learner comes forward.
	activity.call("moveTaskToBack", true)
	return true

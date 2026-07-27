extends Node
## Android Back: keep the task warm (same contract as GodotApp.moveTaskToBack).
## Stock Godot quits on Back unless application/config/quit_on_go_back=false and
## we handle NOTIFICATION_WM_GO_BACK_REQUEST — otherwise Solar dies and whatever
## was underneath (often Language Explorer) flashes to the foreground with the mic.

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_go_home()

func _go_home() -> void:
	if not OS.has_feature("android"):
		return
	var runtime: Object = Engine.get_singleton("AndroidRuntime")
	if runtime == null:
		return
	var activity: Variant = runtime.getActivity()
	if activity == null:
		return
	activity.call("moveTaskToBack", true)

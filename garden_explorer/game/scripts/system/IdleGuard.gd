extends Node
## Kiosk idle + Back hijack (Godot 4.3 — no AndroidRuntime singleton):
##   Splash: Java Back → Star Learner
##   After arm: Back → PAUSED (◀ chip → launcher, warm)
##   1 min idle → PAUSED; 5 min → stash to launcher still on PAUSED

const PAUSE_SEC := 60.0
const EXIT_SEC := 300.0
const MOTION_EPS := 0.85

var _idle_sec: float = 0.0
var _paused_ui: bool = false
var _app_bg: bool = false
var _stashing: bool = false
var _active: bool = true
var _accel_ready: bool = false
var _last_accel: Vector3 = Vector3.ZERO
var _android_app: Variant = null

var _overlay: CanvasLayer
var _dim: ColorRect
var _label: Label
var _back: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)
	set_process_input(true)
	set_process_unhandled_input(true)
	_build_overlay()
	if OS.has_feature("movie"):
		set_active(false)
	else:
		call_deferred("_arm_back_hijack")


func set_active(on: bool) -> void:
	_active = on
	set_process(on)
	set_process_input(on)
	set_process_unhandled_input(on)
	if not on:
		_force_resume_visual()
		_idle_sec = 0.0
		_app_bg = false
		_stashing = false
		AudioServer.set_bus_mute(0, false)


func is_active() -> bool:
	return _active


func is_paused_ui() -> bool:
	return _paused_ui


func _arm_back_hijack() -> void:
	var deadline := Time.get_ticks_msec() + 20_000
	while is_inside_tree() and get_tree().current_scene == null and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	if not is_inside_tree():
		return
	await get_tree().process_frame
	_set_android_back_hijack(true)
	print("IdleGuard: Android Back hijack armed (pause)")


func _android() -> Variant:
	if _android_app != null:
		return _android_app
	if not OS.has_feature("android"):
		return null
	# Godot 4.3: JavaClassWrapper (AndroidRuntime is 4.4+ only).
	var cls: Variant = JavaClassWrapper.wrap("com.godot.game.GodotApp")
	if cls == null:
		return null
	_android_app = cls.call("getInstance")
	return _android_app


func _set_android_back_hijack(on: bool) -> void:
	var activity: Variant = _android()
	if activity == null:
		push_warning("IdleGuard: GodotApp.getInstance() unavailable")
		return
	activity.call("setBackHijackEnabled", on)


func _poll_android_back_pause() -> bool:
	var activity: Variant = _android()
	if activity == null:
		return false
	return bool(activity.call("consumeBackPause"))


func _build_overlay() -> void:
	_overlay = CanvasLayer.new()
	_overlay.layer = 128
	_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay.visible = false
	add_child(_overlay)

	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.55)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.gui_input.connect(_on_overlay_input)
	_overlay.add_child(_dim)

	_label = Label.new()
	_label.text = "PAUSED"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label.add_theme_font_size_override("font_size", 72)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(_label)

	_back = Button.new()
	_back.process_mode = Node.PROCESS_MODE_ALWAYS
	_back.pressed.connect(_on_back_to_launcher)
	_style_back_button(_back)
	_overlay.add_child(_back)


func _style_back_button(btn: Button) -> void:
	btn.text = "◀"
	btn.focus_mode = Control.FOCUS_NONE
	btn.anchor_left = 0.0
	btn.anchor_right = 0.0
	btn.anchor_top = 0.0
	btn.anchor_bottom = 0.0
	btn.offset_left = 28.0
	btn.offset_top = 28.0
	btn.offset_right = 140.0
	btn.offset_bottom = 116.0
	btn.custom_minimum_size = Vector2(112, 88)
	btn.add_theme_font_size_override("font_size", 48)
	btn.add_theme_color_override("font_color", Color(0.15, 0.1, 0.05))
	btn.add_theme_color_override("font_hover_color", Color(0.15, 0.1, 0.05))
	btn.add_theme_color_override("font_pressed_color", Color(0.1, 0.07, 0.03))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.95, 0.86, 0.45, 0.98)
	sb.set_corner_radius_all(18)
	sb.set_border_width_all(4)
	sb.border_color = Color(1, 1, 1, 0.9)
	sb.content_margin_left = 18.0
	sb.content_margin_right = 18.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 10.0
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 8
	var sb_pressed := sb.duplicate() as StyleBoxFlat
	sb_pressed.bg_color = Color(0.86, 0.74, 0.32, 1.0)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.add_theme_stylebox_override("focus", sb)
	btn.add_theme_stylebox_override("pressed", sb_pressed)


func _notification(what: int) -> void:
	if not _active:
		return
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			_enter_background()
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN:
			_leave_background()


func _enter_background() -> void:
	if _app_bg:
		return
	_app_bg = true
	_save_soft()
	_set_sim_enabled(false)
	AudioServer.set_bus_mute(0, true)


func _leave_background() -> void:
	if not _app_bg:
		return
	_app_bg = false
	_stashing = false
	if _paused_ui:
		AudioServer.set_bus_mute(0, true)
		_set_sim_enabled(false)
		if is_instance_valid(_overlay):
			_overlay.visible = true
		get_tree().paused = true
		_idle_sec = PAUSE_SEC
		return
	AudioServer.set_bus_mute(0, false)
	_set_sim_enabled(true)
	bump()


func _process(delta: float) -> void:
	if not _active or _app_bg or _stashing:
		return
	if _poll_android_back_pause():
		_handle_back()
		return
	# Java overlay may already be up — keep sim paused.
	var act: Variant = _android()
	if act != null and bool(act.call("isPauseOverlayShowing")) and not _paused_ui:
		_show_paused()
		return
	if _motion_activity():
		bump()
		return
	_idle_sec += delta
	if _idle_sec >= PAUSE_SEC and not _paused_ui:
		_show_paused()
	if _idle_sec >= EXIT_SEC:
		_stash_to_launcher()


func _input(event: InputEvent) -> void:
	if not _active:
		return
	if _is_back_event(event):
		_handle_back()
		return
	if _is_touch_activity(event):
		bump()


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if _is_back_event(event):
		_handle_back()
		return
	if _is_touch_activity(event):
		bump()


func _on_overlay_input(event: InputEvent) -> void:
	if _is_touch_activity(event):
		bump()


func _is_back_event(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_cancel"):
		return true
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		if k.keycode == KEY_ESCAPE or k.keycode == KEY_BACK:
			return true
	return false


func _handle_back() -> void:
	if _video_panel_open():
		return
	get_viewport().set_input_as_handled()
	if _paused_ui:
		return
	_show_paused()


func _video_panel_open() -> bool:
	for n in get_tree().get_nodes_in_group("video_panel"):
		if n != null and n.has_method("is_open") and bool(n.call("is_open")):
			return true
	return false


func bump() -> void:
	if _paused_ui:
		_hide_paused()
	_idle_sec = 0.0


func _is_touch_activity(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	if event is InputEventScreenDrag:
		return true
	if event is InputEventMouseButton:
		return (event as InputEventMouseButton).pressed
	if event is InputEventMouseMotion:
		return (event as InputEventMouseMotion).button_mask != 0
	if event.is_action_pressed("tap"):
		return true
	return false


func _motion_activity() -> bool:
	var a: Vector3 = Input.get_accelerometer()
	if a == Vector3.ZERO:
		return false
	if not _accel_ready:
		_last_accel = a
		_accel_ready = true
		return false
	var moved := a.distance_to(_last_accel) >= MOTION_EPS
	_last_accel = a
	return moved


func _show_paused() -> void:
	_paused_ui = true
	# Prefer Godot overlay; clear any Java splash-pause shell.
	var act: Variant = _android()
	if act != null:
		act.call("hidePauseOverlay")
	_set_sim_enabled(false)
	_save_soft()
	AudioServer.set_bus_mute(0, true)
	if is_instance_valid(_overlay):
		_overlay.visible = true
	get_tree().paused = true


func _hide_paused() -> void:
	_paused_ui = false
	get_tree().paused = false
	var act: Variant = _android()
	if act != null:
		act.call("hidePauseOverlay")
	if is_instance_valid(_overlay):
		_overlay.visible = false
	AudioServer.set_bus_mute(0, false)
	_set_sim_enabled(true)


func _force_resume_visual() -> void:
	if _paused_ui:
		_hide_paused()


func _on_back_to_launcher() -> void:
	_stash_to_launcher()


func _set_sim_enabled(on: bool) -> void:
	## Legacy SimClock hook (unused) + pause the live SeasonClock on World.
	var clock := get_node_or_null("/root/SimClock")
	if clock != null and clock.has_method("set_enabled"):
		clock.call("set_enabled", on)
	var season := _find_season_clock()
	if season != null:
		season.set("paused", not on)

func _find_season_clock() -> Node:
	var scene := get_tree().current_scene if is_inside_tree() else null
	if scene == null:
		return null
	var world: Node = scene.get_node_or_null("World")
	if world == null:
		return null
	var sc: Variant = world.get("season_clock")
	return sc as Node if sc != null else world.get_node_or_null("SeasonClock")


func _save_soft() -> void:
	var save := get_node_or_null("/root/Save")
	if save != null and save.has_method("save_if_dirty"):
		save.call("save_if_dirty")


func _stash_to_launcher() -> void:
	if _stashing:
		return
	_stashing = true
	if not _paused_ui:
		_show_paused()
	_save_soft()
	_set_sim_enabled(false)
	print("IdleGuard: stashing to Star Learner (warm PAUSED)")
	if not _go_home_android():
		_stashing = false


func _go_home_android() -> bool:
	var activity: Variant = _android()
	if activity == null:
		return false
	activity.call("moveTaskToBack", true)
	return true

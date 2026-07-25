class_name IntroPanel
extends CanvasLayer
## First-launch welcome. Plays intro clip (or VO fallback) once via Save.

signal finished()

var star_db
var _started: bool = false
var _finished: bool = false
var _panel: PanelContainer
var _label: Label
var _start_btn: Button
var _dim: ColorRect

func _ready() -> void:
	add_to_group("intro_panel")
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 60
	_build()
	call_deferred("_boot")

func setup(db) -> void:
	star_db = db

func _boot() -> void:
	var save := _save()
	if save != null and bool(save.intro_completed):
		_started = true
		_finished = true
		visible = false
		finished.emit()
		Events.intro_done.emit()
		return
	visible = true
	_panel.visible = true
	get_tree().paused = true

func _build() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(root)

	_dim = ColorRect.new()
	_dim.color = Color(0.08, 0.14, 0.08, 0.92)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.process_mode = Node.PROCESS_MODE_ALWAYS
	_dim.gui_input.connect(_on_dim_input)
	root.add_child(_dim)

	_panel = PanelContainer.new()
	## Center on whatever aspect the phone uses (Moto landscape ≈ 1600×720).
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.offset_left = -300
	_panel.offset_right = 300
	_panel.offset_top = -160
	_panel.offset_bottom = 160
	_panel.custom_minimum_size = Vector2(600, 320)
	_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(_panel)

	var v := VBoxContainer.new()
	_panel.add_child(v)
	_label = Label.new()
	_label.text = "Welcome to Garden Explorer!\n\nPlant seeds, water them, harvest food,\nand collect knowledge stars."
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_size_override("font_size", 24)
	_label.custom_minimum_size = Vector2(560, 180)
	v.add_child(_label)

	_start_btn = Button.new()
	_start_btn.text = "START"
	_start_btn.custom_minimum_size = Vector2(200, 72)
	_start_btn.add_theme_font_size_override("font_size", 32)
	_start_btn.pressed.connect(_on_start)
	_start_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	v.add_child(_start_btn)

func _on_dim_input(event: InputEvent) -> void:
	## Kid-friendly: tap anywhere on the welcome veil to start.
	if _started or not visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_start()

func _on_start() -> void:
	if _started:
		return
	_started = true
	## CRITICAL: hide the whole intro layer (green dim included) BEFORE opening
	## VideoPanel. Intro is layer 60; video is layer 50 — leaving the dim up
	## occludes the clip + Back button and traps the paused tree forever.
	visible = false
	if _dim:
		_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	## The explainer clip carries its own narration — don't talk over it.
	var video := get_tree().get_first_node_in_group("video_panel")
	var file: String = star_db.intro_file() if star_db else "intro.ogv"
	var topic: String = "Welcome to the garden"
	if star_db and not star_db.intro.is_empty():
		topic = str(star_db.intro.get("topic", topic))
	var played := false
	if video and video.has_method("play_intro"):
		played = bool(video.call("play_intro", file, topic))
	if played and video.has_signal("closed"):
		if not video.closed.is_connected(_finish):
			video.closed.connect(_finish, CONNECT_ONE_SHOT)
	else:
		## No video panel — finish after a short beat.
		await get_tree().create_timer(2.5, true, false, true).timeout
		_finish()

func _finish() -> void:
	if _finished:
		return
	_finished = true
	var save := _save()
	if save and save.has_method("set_intro_completed"):
		save.set_intro_completed(true)
	visible = false
	get_tree().paused = false
	finished.emit()
	Events.intro_done.emit()
	print("Garden Explorer: intro done")

func _save() -> Node:
	return get_tree().root.get_node_or_null("/root/Save")

func _speak(line: String) -> void:
	var SpeakScript := preload("res://scripts/audio/Speak.gd")
	SpeakScript.line(line)

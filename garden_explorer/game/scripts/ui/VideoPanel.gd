class_name VideoPanel
extends CanvasLayer
## Full-screen documentary player — one decoder; pauses tree while open.
## If .ogv is missing, shows a topic card + TTS so offline builds still collect.

const StarDBScript := preload("res://scripts/content/StarDB.gd")

signal closed()
signal clip_started(star_id: String)

var _open: bool = false
var _current_id: String = ""
var _dim: ColorRect
var _player: VideoStreamPlayer
var _back: Button
var _fallback: Label
var _title: Label

func _ready() -> void:
	add_to_group("video_panel")
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 50
	_build()
	visible = false

func is_open() -> bool:
	return _open

func play_star(star_id: String, file_name: String, topic: String = "") -> bool:
	return _open_clip(star_id, file_name, topic if not topic.is_empty() else star_id)

func play_intro(file_name: String, topic: String = "Welcome to the garden") -> bool:
	return _open_clip("intro", file_name, topic)

func _open_clip(id: String, file_name: String, topic: String) -> bool:
	if _open:
		return false
	_stop_stage_media()
	_current_id = id
	_open = true
	visible = true
	_title.text = topic
	_fallback.visible = false
	_player.visible = false
	_player.stop()
	_player.stream = null

	var path := StarDBScript.resolve_video_path(file_name)
	var played := false
	if not path.is_empty():
		var stream = load(path)
		if stream is VideoStream:
			_player.stream = stream
			_player.visible = true
			_player.play()
			played = true
	if not played:
		_fallback.visible = true
		_fallback.text = "%s\n\n(Video coming soon — tap ◀ when ready)" % topic
		_speak(topic)

	_dim.modulate.a = 0.85
	get_tree().paused = true
	clip_started.emit(id)
	return true

func _build() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(root)

	_dim = ColorRect.new()
	_dim.color = Color(0.05, 0.08, 0.05, 1)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.gui_input.connect(_on_dim_input)
	_dim.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(_dim)

	_player = VideoStreamPlayer.new()
	_player.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_player.expand = true
	_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_player.finished.connect(_close)
	root.add_child(_player)

	_title = Label.new()
	_title.position = Vector2(160, 24)
	_title.size = Vector2(960, 40)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 26)
	_title.add_theme_color_override("font_color", Color(1, 0.95, 0.75, 1))
	_title.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(_title)

	_fallback = Label.new()
	_fallback.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_fallback.position = Vector2(340, 200)
	_fallback.size = Vector2(600, 200)
	_fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_fallback.add_theme_font_size_override("font_size", 28)
	_fallback.add_theme_color_override("font_color", Color(1, 0.98, 0.9, 1))
	_fallback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_fallback.process_mode = Node.PROCESS_MODE_ALWAYS
	_fallback.visible = false
	root.add_child(_fallback)

	_back = Button.new()
	_back.text = "◀"
	_back.position = Vector2(28, 28)
	_back.custom_minimum_size = Vector2(112, 88)
	_back.add_theme_font_size_override("font_size", 48)
	_back.process_mode = Node.PROCESS_MODE_ALWAYS
	_back.pressed.connect(_close)
	_style_back(_back)
	root.add_child(_back)

func _style_back(btn: Button) -> void:
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_color_override("font_color", Color(0.15, 0.1, 0.05))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.95, 0.86, 0.45, 0.98)
	sb.set_corner_radius_all(18)
	sb.set_border_width_all(4)
	sb.border_color = Color(1, 1, 1, 0.9)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.add_theme_stylebox_override("pressed", sb)

func _on_dim_input(event: InputEvent) -> void:
	if not _open:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		## While a real clip plays, only ◀ closes (avoids accidental skip).
		## Fallback / "video coming soon" card: tap anywhere to dismiss.
		if _fallback.visible:
			_close()

func _close() -> void:
	if not _open:
		return
	_open = false
	_player.stop()
	_player.stream = null
	visible = false
	get_tree().paused = false
	closed.emit()
	_current_id = ""

func _stop_stage_media() -> void:
	var stage := get_tree().get_first_node_in_group("stage_media")
	if stage and stage.has_method("_stop_video"):
		stage.call("_stop_video")
		stage.visible = false

func _speak(line: String) -> void:
	var SpeakScript := preload("res://scripts/audio/Speak.gd")
	SpeakScript.line(line)

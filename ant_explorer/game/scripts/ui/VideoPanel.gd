extends CanvasLayer
## Full-screen documentary player — one decoder at a time; pauses sim while open.

const STAR_TRIGGER := preload("res://scripts/content/StarTrigger.gd")

signal closed()

@onready var _dim: ColorRect = $Dim
@onready var _player: VideoStreamPlayer = $Player
@onready var _back: Button = $Back

var _open: bool = false
var _current_star_id: String = ""

func _ready() -> void:
	add_to_group("video_panel")
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	visible = false
	_dim.modulate.a = 0.0
	_dim.gui_input.connect(_on_dim_input)
	_back.process_mode = Node.PROCESS_MODE_ALWAYS
	_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_player.finished.connect(_on_player_finished)
	_back.pressed.connect(_close)
	_style_back_button()

## Big, obvious, high-contrast back chevron for a six-year-old (styled in code
## so the .tscn stays simple). Top-left warm chip — arrow only, no word.
func _style_back_button() -> void:
	_back.text = "◀"
	_back.focus_mode = Control.FOCUS_NONE
	_back.anchor_left = 0.0
	_back.anchor_right = 0.0
	_back.anchor_top = 0.0
	_back.anchor_bottom = 0.0
	_back.offset_left = 28.0
	_back.offset_top = 28.0
	_back.offset_right = 140.0
	_back.offset_bottom = 116.0
	_back.custom_minimum_size = Vector2(112, 88)
	_back.add_theme_font_size_override("font_size", 48)
	_back.add_theme_color_override("font_color", Color(0.15, 0.1, 0.05))
	_back.add_theme_color_override("font_hover_color", Color(0.15, 0.1, 0.05))
	_back.add_theme_color_override("font_pressed_color", Color(0.1, 0.07, 0.03))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.95, 0.86, 0.45, 0.98)  # warm honey, reads on any video
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
	_back.add_theme_stylebox_override("normal", sb)
	_back.add_theme_stylebox_override("hover", sb)
	_back.add_theme_stylebox_override("focus", sb)
	_back.add_theme_stylebox_override("pressed", sb_pressed)


func is_open() -> bool:
	return _open


func play_star(star_id: String, file_name: String) -> bool:
	if _open:
		return false
	var path := STAR_TRIGGER.resolve_video_path(file_name)
	if path.is_empty():
		push_warning("VideoPanel: no Theora clip for star %s (%s)" % [star_id, file_name])
		return false
	var stream: VideoStream = ResourceLoader.load(path, "VideoStream") as VideoStream
	if stream == null:
		stream = load(path) as VideoStream
	if stream == null:
		push_warning("VideoPanel: could not load stream %s" % path)
		return false
	_current_star_id = star_id
	_open = true
	visible = true
	_player.stream = stream
	_dim.modulate.a = 0.0
	# Tree is paused during discovery — tween must keep processing.
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_dim, "modulate:a", 1.0, 0.25)
	get_tree().paused = true
	_player.play()
	return true


func _input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()


func _on_dim_input(event: InputEvent) -> void:
	if not _open:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close()


func _on_player_finished() -> void:
	_close()


func _close() -> void:
	if not _open:
		return
	_open = false
	_player.stop()
	_player.stream = null
	get_tree().paused = false
	visible = false
	_dim.modulate.a = 0.0
	_current_star_id = ""
	closed.emit()

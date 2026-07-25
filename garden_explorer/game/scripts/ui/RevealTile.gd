class_name RevealTile
extends CanvasLayer
## Large center portrait tile for animals / bugs.
## Flow: narration plays first (taps ignored, player frozen by Narrator lock),
## THEN a 5s window opens — tap tile confirms (launch video), tap outside or
## timeout closes.

signal confirmed(payload: Dictionary)
signal cancelled()

const SpeakScript := preload("res://scripts/audio/Speak.gd")

var _open: bool = false
var _payload: Dictionary = {}
var _narrating_left: float = 0.0
var _window_left: float = 0.0
var _root: Control
var _dim: ColorRect
var _tile: Button
var _icon: TextureRect
var _title: Label
var _hint: Label

func _ready() -> void:
	add_to_group("reveal_tile")
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false
	set_process(false)

func is_open() -> bool:
	return _open

func is_narrating() -> bool:
	return _open and _narrating_left > 0.0

func window_sec() -> float:
	return Config.get_reveal_window_sec() if Config.has_method("get_reveal_window_sec") else 5.0

func show_reveal(payload: Dictionary) -> void:
	_payload = payload.duplicate(true)
	_open = true
	visible = true
	_title.text = str(_payload.get("title", ""))
	_hint.text = str(_payload.get("hint", "Tap to learn more"))
	_icon.texture = _payload.get("texture", null) as Texture2D
	## Narration first — countdown starts only after it finishes.
	_narrating_left = 0.0
	_window_left = window_sec()
	var line := str(_payload.get("narration", ""))
	if not line.is_empty() and not bool(_payload.get("silent", false)):
		_narrating_left = SpeakScript.line(line)
	set_process(true)

func close_reveal(emit_cancel: bool = true) -> void:
	if not _open:
		return
	_open = false
	visible = false
	set_process(false)
	_payload.clear()
	if emit_cancel:
		cancelled.emit()

func _process(delta: float) -> void:
	if not _open:
		return
	if _narrating_left > 0.0:
		_narrating_left -= delta
		return
	_window_left -= delta
	if _window_left <= 0.0:
		close_reveal(true)

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_root)

	_dim = ColorRect.new()
	_dim.color = Color(0.05, 0.08, 0.05, 0.55)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.gui_input.connect(_on_dim_input)
	_dim.process_mode = Node.PROCESS_MODE_ALWAYS
	_root.add_child(_dim)

	var center := Control.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	center.offset_left = -200
	center.offset_top = -240
	center.offset_right = 200
	center.offset_bottom = 240
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)

	_tile = Button.new()
	_tile.focus_mode = Control.FOCUS_NONE
	_tile.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tile.process_mode = Node.PROCESS_MODE_ALWAYS
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.22, 0.14, 0.96)
	sb.set_corner_radius_all(28)
	sb.set_border_width_all(6)
	sb.border_color = Color(1.0, 0.84, 0.25, 1.0)
	_tile.add_theme_stylebox_override("normal", sb)
	_tile.add_theme_stylebox_override("hover", sb)
	_tile.add_theme_stylebox_override("pressed", sb)
	_tile.pressed.connect(_on_tile_pressed)
	center.add_child(_tile)

	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 20
	v.offset_top = 20
	v.offset_right = -20
	v.offset_bottom = -20
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 10)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tile.add_child(v)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 32)
	_title.add_theme_color_override("font_color", Color(1, 0.96, 0.85, 1))
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_title)

	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(280, 280)
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_icon)

	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_font_size_override("font_size", 20)
	_hint.add_theme_color_override("font_color", Color(0.92, 0.88, 0.72, 1))
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_hint)

func _on_dim_input(event: InputEvent) -> void:
	if not _open:
		return
	## During narration taps are ignored — no accidental dismiss.
	if _narrating_left > 0.0:
		return
	if event is InputEventScreenTouch and event.pressed:
		close_reveal(true)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close_reveal(true)

func _on_tile_pressed() -> void:
	if not _open:
		return
	if _narrating_left > 0.0:
		return
	var p := _payload.duplicate(true)
	close_reveal(false)
	confirmed.emit(p)

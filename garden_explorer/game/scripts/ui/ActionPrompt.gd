class_name ActionPrompt
extends CanvasLayer
## Center-screen confirm tile after the gardener arrives at an interactable.
## Tap the tile to apply; tap outside (dim) to cancel.

signal confirmed(action: Dictionary)
signal cancelled()

var _open: bool = false
var _action: Dictionary = {}
var _dim: ColorRect
var _tile: Button
var _icon: TextureRect
var _label: Label
var sprites: FarmSprites

func _ready() -> void:
	layer = 35
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false

func setup(art: FarmSprites) -> void:
	sprites = art

func is_open() -> bool:
	return _open

func show_action(action: Dictionary) -> void:
	_action = action.duplicate(true)
	_open = true
	visible = true
	_dim.visible = true
	_tile.visible = true
	var title := str(action.get("label", "Do it?"))
	_label.text = title
	_icon.texture = null
	var tex = action.get("texture", null)
	if tex is Texture2D:
		_icon.texture = tex
	elif sprites and str(action.get("plant_id", "")) != "":
		var pid := str(action.plant_id)
		match str(action.get("kind", "")):
			"plant":
				_icon.texture = sprites.seed_icon(pid)
			"harvest":
				_icon.texture = sprites.harvest_icon(pid)
			_:
				_icon.texture = sprites.seed_icon(pid)
	var SpeakScript := preload("res://scripts/audio/Speak.gd")
	var line := str(action.get("narration", title))
	if not line.is_empty():
		SpeakScript.line(line)

func close_prompt() -> void:
	_open = false
	visible = false
	_dim.visible = false
	_tile.visible = false
	_action = {}

func confirm_current() -> void:
	## Test / automation hook — same as tapping the center tile.
	_on_confirm()

func _build() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(root)

	_dim = ColorRect.new()
	_dim.color = Color(0.04, 0.08, 0.05, 0.45)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.gui_input.connect(_on_dim)
	_dim.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(_dim)

	_tile = Button.new()
	_tile.focus_mode = Control.FOCUS_NONE
	_tile.custom_minimum_size = Vector2(200, 200)
	_tile.set_anchors_preset(Control.PRESET_CENTER)
	_tile.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_tile.grow_vertical = Control.GROW_DIRECTION_BOTH
	_tile.offset_left = -100
	_tile.offset_right = 100
	_tile.offset_top = -100
	_tile.offset_bottom = 100
	_tile.pressed.connect(_on_confirm)
	_tile.process_mode = Node.PROCESS_MODE_ALWAYS
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.26, 0.14, 0.96)
	sb.set_corner_radius_all(22)
	sb.set_border_width_all(6)
	sb.border_color = Color(1.0, 0.82, 0.2, 1.0)
	_tile.add_theme_stylebox_override("normal", sb)
	_tile.add_theme_stylebox_override("hover", sb)
	_tile.add_theme_stylebox_override("pressed", sb)
	root.add_child(_tile)

	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tile.add_child(v)

	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(96, 96)
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_icon)

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_size_override("font_size", 22)
	_label.add_theme_color_override("font_color", Color(1, 0.96, 0.85, 1))
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_label)

func _on_dim(event: InputEvent) -> void:
	if not _open:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close_prompt()
		cancelled.emit()

func _on_confirm() -> void:
	if not _open:
		return
	var act := _action.duplicate(true)
	close_prompt()
	confirmed.emit(act)

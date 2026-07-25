class_name ActionPrompt
extends CanvasLayer
## Context action tiles that appear after arriving at an interactable.
## Player has no carried tool intent — choose from available actions.
## Tap a tile to apply; tap elsewhere cancels and lets TapRouter navigate.

signal confirmed(action: Dictionary)
signal cancelled()

var _open: bool = false
var _actions: Array = []
var _root: Control
var _row: HBoxContainer
var _hint: Label
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
	## Back-compat: single action.
	show_actions([action])

func show_actions(actions: Array) -> void:
	_actions.clear()
	for a in actions:
		if typeof(a) == TYPE_DICTIONARY and not a.is_empty():
			_actions.append((a as Dictionary).duplicate(true))
	if _actions.is_empty():
		close_prompt()
		return
	_open = true
	visible = true
	_rebuild_tiles()
	## Narrate the choice once (first action's line, or a short chooser line).
	var SpeakScript := preload("res://scripts/audio/Speak.gd")
	if _actions.size() == 1:
		var line := str(_actions[0].get("narration", _actions[0].get("label", "")))
		if not line.is_empty() and not bool(_actions[0].get("silent", false)):
			SpeakScript.line(line)
	else:
		SpeakScript.line("What do you want to do?")

func close_prompt() -> void:
	_open = false
	visible = false
	_actions.clear()
	_clear_tiles()

func confirm_current() -> void:
	## Test hook — confirms the first available action.
	if _actions.is_empty():
		return
	_pick(_actions[0])

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_root)

	var panel := VBoxContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_left = -320
	panel.offset_right = 320
	panel.offset_top = -240
	panel.offset_bottom = -28
	panel.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_theme_constant_override("separation", 10)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(panel)

	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 22)
	_hint.add_theme_color_override("font_color", Color(1, 0.96, 0.85, 1))
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.text = "Choose"
	panel.add_child(_hint)

	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", 16)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_row)

func _clear_tiles() -> void:
	if _row == null:
		return
	for c in _row.get_children():
		c.queue_free()

func _rebuild_tiles() -> void:
	_clear_tiles()
	_hint.text = "Choose" if _actions.size() > 1 else str(_actions[0].get("label", "Do it?"))
	for a in _actions:
		_row.add_child(_mk_tile(a as Dictionary))

func _mk_tile(action: Dictionary) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(148, 148)
	b.process_mode = Node.PROCESS_MODE_ALWAYS
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.20, 0.12, 0.94)
	sb.set_corner_radius_all(20)
	sb.set_border_width_all(5)
	sb.border_color = Color(1.0, 0.84, 0.25, 1.0)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	var act := action.duplicate(true)
	b.pressed.connect(func() -> void: _pick(act))

	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 4)
	b.add_child(v)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(80, 80)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = _resolve_icon(action)
	v.add_child(icon)

	var lab := Label.new()
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.add_theme_font_size_override("font_size", 18)
	lab.add_theme_color_override("font_color", Color(1, 0.96, 0.85, 1))
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lab.text = str(action.get("label", "?"))
	v.add_child(lab)
	return b

func _resolve_icon(action: Dictionary) -> Texture2D:
	var tex = action.get("texture", null)
	if tex is Texture2D:
		return tex
	if sprites == null:
		return null
	if sprites.has_method("action_icon"):
		return sprites.action_icon(str(action.get("kind", "")), str(action.get("plant_id", "")))
	return null

func _pick(action: Dictionary) -> void:
	if not _open:
		return
	var act := action.duplicate(true)
	close_prompt()
	confirmed.emit(act)

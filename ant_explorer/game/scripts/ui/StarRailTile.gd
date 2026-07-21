class_name StarRailTile
extends Control
## One rail slot. Shows a Sprout-Lands topic icon on a soft soil well.
## Undiscovered: greyed + slightly smaller. Collected: full colour, pops in.
## Emits `tapped(star_id)` on tap/touch — the shell owns the double-tap logic.

signal tapped(star_id: String)

const _Model := preload("res://scripts/ui/StarRailModel.gd")

const UNDISCOVERED_SCALE := 0.86
const UNDISCOVERED_MODULATE := Color(0.55, 0.55, 0.6, 0.92)
const COLLECTED_MODULATE := Color(1, 1, 1, 1)
const WELL_COLOR := Color(0.44, 0.31, 0.19, 0.55)
const WELL_COLOR_COLLECTED := Color(0.52, 0.37, 0.22, 0.85)

var star_id: String = ""
var state: int = _Model.TILE_UNDISCOVERED

var _visual: Control
var _well: ColorRect
var _icon: TextureRect
var _glyph: Label

func setup(id: String, icon_texture: Texture2D) -> void:
	star_id = id
	name = "Tile_%s" % id
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Only a min WIDTH — forcing a min height makes 6 tiles + gaps exceed the
	# 600 px design height and clip the bottom tile. EXPAND_FILL divides the
	# column height evenly instead (≈90 px design → ≈108 px on the 720 px panel).
	custom_minimum_size = Vector2(96, 0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	clip_contents = false

	_visual = Control.new()
	_visual.name = "Visual"
	_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_visual.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_visual)

	_well = ColorRect.new()
	_well.name = "Well"
	_well.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_well.color = WELL_COLOR
	_well.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Small inset so wells read as separate rounded pads, not one solid column.
	_well.offset_left = 6.0
	_well.offset_top = 6.0
	_well.offset_right = -6.0
	_well.offset_bottom = -6.0
	_visual.add_child(_well)

	_glyph = Label.new()
	_glyph.name = "Glyph"
	_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glyph.text = "★"
	_glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_glyph.add_theme_font_size_override("font_size", 40)
	_glyph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_visual.add_child(_glyph)

	_icon = TextureRect.new()
	_icon.name = "Icon"
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_icon.offset_left = 8.0
	_icon.offset_top = 8.0
	_icon.offset_right = -8.0
	_icon.offset_bottom = -8.0
	if icon_texture != null:
		_icon.texture = icon_texture
		_glyph.visible = false
	else:
		_icon.visible = false
	_visual.add_child(_icon)

	resized.connect(_recenter_pivot)
	_recenter_pivot()

func set_state(new_state: int, animate: bool = false) -> void:
	var was := state
	state = new_state
	_apply_state()
	if animate and was == _Model.TILE_UNDISCOVERED and state == _Model.TILE_COLLECTED:
		pop()

func _apply_state() -> void:
	if _visual == null:
		return
	if state == _Model.TILE_COLLECTED:
		_visual.modulate = COLLECTED_MODULATE
		_visual.scale = Vector2.ONE
		if _well:
			_well.color = WELL_COLOR_COLLECTED
	else:
		_visual.modulate = UNDISCOVERED_MODULATE
		_visual.scale = Vector2(UNDISCOVERED_SCALE, UNDISCOVERED_SCALE)
		if _well:
			_well.color = WELL_COLOR

## Short scale punch when a star is freshly collected.
func pop() -> void:
	if _visual == null:
		return
	if not is_inside_tree():
		return
	_recenter_pivot()
	_visual.scale = Vector2(0.6, 0.6)
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_BACK)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(_visual, "scale", Vector2(1.12, 1.12), 0.18)
	tw.tween_property(_visual, "scale", Vector2.ONE, 0.12)

func _recenter_pivot() -> void:
	if _visual:
		_visual.pivot_offset = size * 0.5

func _gui_input(event: InputEvent) -> void:
	var hit := false
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		hit = mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventScreenTouch:
		hit = (event as InputEventScreenTouch).pressed
	if hit:
		accept_event()
		tapped.emit(star_id)

class_name SpriteChip
extends Control
## Tappable / draggable sentence sprite with gold outline when selected.
## Children are mouse-transparent; the parent SentenceMatch hit-tests.

signal selected(chip: SpriteChip)

const CHIP := 88.0
const SELECT_SCALE := 1.28
const DRAG_THRESHOLD := 12.0

var sprite_id: String = ""
var token: String = ""  # word this sprite matches (normalized later)
var home_pos: Vector2 = Vector2.ZERO
var matched: bool = false
var locked: bool = false

var _tex: TextureRect
var _ring: Panel
var _selected: bool = false

func setup(p_id: String, p_token: String, image_path: String = "") -> void:
	sprite_id = p_id
	token = p_token
	custom_minimum_size = Vector2(CHIP, CHIP)
	size = Vector2(CHIP, CHIP)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _tex == null:
		_ring = Panel.new()
		_ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_ring.offset_left = -6
		_ring.offset_top = -6
		_ring.offset_right = 6
		_ring.offset_bottom = 6
		_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ring.visible = false
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0)
		sb.set_corner_radius_all(16)
		sb.set_border_width_all(5)
		sb.border_color = LangTheme.GOLD
		_ring.add_theme_stylebox_override("panel", sb)
		add_child(_ring)

		_tex = TextureRect.new()
		_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_tex)
	_tex.texture = SpriteArt.texture_for(sprite_id, image_path)

func set_home(pos: Vector2) -> void:
	home_pos = pos
	position = pos

func set_selected(on: bool) -> void:
	if matched or locked:
		return
	_selected = on
	_ring.visible = on
	scale = Vector2.ONE * (SELECT_SCALE if on else 1.0)
	pivot_offset = size * 0.5

func is_selected() -> bool:
	return _selected

func mark_matched() -> void:
	matched = true
	locked = true
	_selected = false
	_ring.visible = false
	scale = Vector2.ONE * 0.55
	pivot_offset = size * 0.5

func return_home(animate: bool = true) -> void:
	set_selected(false)
	if animate and is_inside_tree():
		var tw := create_tween()
		tw.tween_property(self, "position", home_pos, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		position = home_pos

func contains_point(global_pt: Vector2) -> bool:
	return get_global_rect().has_point(global_pt)

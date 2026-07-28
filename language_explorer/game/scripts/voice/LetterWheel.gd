class_name LetterWheel
extends Control
const LangFontsS := preload("res://scripts/LangFonts.gd")
## Five-letter carousel: current letter centered and largest, neighbors shrink outward.

const SLOT_WIDTH := 88.0
const SLOT_HEIGHT := 120.0
const SLOT_OFFSETS := [-2, -1, 0, 1, 2]
const FONT_SIZES := [44, 58, 96, 58, 44]
const SLIDE_SECS := 0.16

var _track: Control
var _labels: Array[Label] = []
var _letters: Array = []
var _index: int = 0
var _slide_tween: Tween

func _ready() -> void:
	custom_minimum_size = Vector2(SLOT_WIDTH * 5.0, SLOT_HEIGHT)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_track = Control.new()
	_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_track)
	for i in SLOT_OFFSETS.size():
		var lbl := Label.new()
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.custom_minimum_size = Vector2(SLOT_WIDTH, SLOT_HEIGHT)
		lbl.size = Vector2(SLOT_WIDTH, SLOT_HEIGHT)
		lbl.position = Vector2(i * SLOT_WIDTH, 0.0)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		LangFontsS.apply_label(lbl, FONT_SIZES[i], i == 2)
		_labels.append(lbl)
		_track.add_child(lbl)
	_center_track()

func set_context(letters: Array, index: int, animate: bool = false, direction: int = 0) -> void:
	_letters = letters
	_index = clampi(index, 0, maxi(0, letters.size() - 1))
	_paint_slots()
	if animate and direction != 0 and is_inside_tree():
		await _slide(direction)

func _center_track() -> void:
	if _track == null:
		return
	_track.position = Vector2(0.0, 0.0)

func _slide(direction: int) -> void:
	if _slide_tween != null and _slide_tween.is_running():
		_slide_tween.kill()
	var start_x := _track.position.x
	var end_x := start_x - float(direction) * SLOT_WIDTH
	_slide_tween = create_tween()
	_slide_tween.tween_property(_track, "position:x", end_x, SLIDE_SECS)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await _slide_tween.finished
	_center_track()

func _paint_slots() -> void:
	for i in SLOT_OFFSETS.size():
		var lbl := _labels[i]
		var offset: int = SLOT_OFFSETS[i]
		var li := _index + offset
		var ch := ""
		if li >= 0 and li < _letters.size():
			ch = str(_letters[li])
		lbl.text = ch
		var center := offset == 0
		LangFontsS.apply_label(lbl, FONT_SIZES[i], center)
		if center and not ch.is_empty():
			lbl.add_theme_color_override("font_color", LangTheme.GOLD)
		elif ch.is_empty():
			lbl.add_theme_color_override("font_color", Color(LangTheme.TEXT_DIM, 0.35))
		else:
			lbl.add_theme_color_override("font_color", LangTheme.TEXT_DIM)

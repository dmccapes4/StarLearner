class_name TraceCanvas
extends Control
const ChromeIcons := preload("res://scripts/ChromeIcons.gd")
## Grey letter outlines. Finger traces the current letter; enough stroke length
## inside that letter's bounds completes it (finger-first, no stylus API).

signal letter_traced(index: int, letter: String)
signal ask_replay()

const COMPLETE_LEN := 55.0

var _letters: PackedStringArray = PackedStringArray()
var _index: int = 0
var _labels: Array = []
var _zones: Array = []  # Control hit zones
var _stroke_len: float = 0.0
var _drawing: bool = false
var _last: Vector2 = Vector2.ZERO
var _done: bool = false
var _replay: Button

func setup(letters: PackedStringArray) -> void:
	_letters = letters
	_index = 0
	_done = letters.is_empty()
	_stroke_len = 0.0
	_rebuild()

func set_index(i: int) -> void:
	_index = clampi(i, 0, maxi(0, _letters.size() - 1))
	_stroke_len = 0.0
	_refresh_styles()

func mark_complete() -> void:
	_done = true
	_refresh_styles()

func _ready() -> void:
	custom_minimum_size = Vector2(1000, 220)
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)

func _rebuild() -> void:
	for c in get_children():
		c.queue_free()
	_labels.clear()
	_zones.clear()

	_replay = Button.new()
	_replay.position = Vector2(20, 8)
	_replay.size = Vector2(64, 56)
	_replay.focus_mode = Control.FOCUS_NONE
	LangTheme.style_secondary(_replay)
	ChromeIcons.apply_button(_replay, "hear", 36)
	_replay.pressed.connect(func() -> void: ask_replay.emit())
	add_child(_replay)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	row.position = Vector2(80, 40)
	row.size = Vector2(900, 160)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)

	for i in _letters.size():
		var zone := Control.new()
		zone.custom_minimum_size = Vector2(88, 140)
		zone.size = Vector2(88, 140)
		zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var lbl := Label.new()
		lbl.text = str(_letters[i])
		lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 96)
		lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.35))
		lbl.add_theme_constant_override("outline_size", 4)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		zone.add_child(lbl)
		row.add_child(zone)
		_labels.append(lbl)
		_zones.append(zone)
	_refresh_styles()

func _refresh_styles() -> void:
	for i in _labels.size():
		var lbl: Label = _labels[i]
		if i < _index or _done:
			lbl.add_theme_color_override("font_color", LangTheme.GREEN)
		elif i == _index:
			lbl.add_theme_color_override("font_color", Color(LangTheme.GREY.r, LangTheme.GREY.g, LangTheme.GREY.b, 0.85))
		else:
			lbl.add_theme_color_override("font_color", Color(LangTheme.GREY.r, LangTheme.GREY.g, LangTheme.GREY.b, 0.35))

func _on_gui_input(ev: InputEvent) -> void:
	if _done or _index >= _letters.size():
		return
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_begin(mb.position)
		else:
			_end()
	elif ev is InputEventScreenTouch:
		var st := ev as InputEventScreenTouch
		if st.pressed:
			_begin(st.position)
		else:
			_end()
	elif ev is InputEventMouseMotion and _drawing:
		_move((ev as InputEventMouseMotion).position)
	elif ev is InputEventScreenDrag and _drawing:
		_move((ev as InputEventScreenDrag).position)

func _begin(local_pos: Vector2) -> void:
	if not _in_current(local_pos):
		return
	_drawing = true
	_last = local_pos
	_stroke_len = 0.0

func _move(local_pos: Vector2) -> void:
	if not _drawing:
		return
	if _in_current(local_pos):
		_stroke_len += local_pos.distance_to(_last)
		_last = local_pos
		if _stroke_len >= COMPLETE_LEN:
			_finish_letter()
	else:
		# Left the zone — soft reset stroke so she must stay on the letter.
		_stroke_len *= 0.5
		_last = local_pos

func _end() -> void:
	_drawing = false

func _finish_letter() -> void:
	_drawing = false
	var ch := str(_letters[_index])
	var idx := _index
	letter_traced.emit(idx, ch)

func _in_current(local_pos: Vector2) -> bool:
	if _index < 0 or _index >= _zones.size():
		return false
	var z: Control = _zones[_index]
	var g := get_global_transform() * local_pos
	return z.get_global_rect().grow(12).has_point(g)

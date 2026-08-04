class_name SpeedModeChooser
extends Control
## Free Flight start: gears, cruise/stop, or experimental joystick distance.

signal gears_pressed()
signal cruise_stop_pressed()
signal joystick_pressed()

const LINE_GEARS := "Speed Control has five gears — a quick pull goes one gear faster, a quick push one gear slower."
const LINE_CRUISE := "Cruise and Stop keeps it simple — a quick pull to cruise, a quick push to stop."
const LINE_JOY := "Joystick test: hold still, push and hold, back to rest, pull and hold, back to rest."
const NARRATION := LINE_GEARS + " " + LINE_CRUISE + " " + LINE_JOY

const GEARS_TEX := "res://images/tile_speed_gears.png"
const CRUISE_TEX := "res://images/tile_cruise_stop.png"
const JOY_TEX := "res://images/tile_free_flight.png"
const GOLD := Color(1.0, 0.86, 0.28, 1.0)

var _gears_btn: Button
var _cruise_btn: Button
var _joy_btn: Button
var _gears_tint: Color = Color(0.12, 0.38, 0.48)
var _cruise_tint: Color = Color(0.42, 0.22, 0.14)
var _joy_tint: Color = Color(0.22, 0.36, 0.18)
var _narr_gen: int = 0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.04, 0.10, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var center_wrap := CenterContainer.new()
	center_wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center_wrap)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	box.custom_minimum_size = Vector2(1180, 540)
	center_wrap.add_child(box)

	var title := Label.new()
	title.text = "How do you want to control speed?"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)
	box.add_child(row)

	var gears_col := _make_tile(
		"Speed Control",
		"Five gears — jerk ±1",
		GEARS_TEX,
		_gears_tint,
		func() -> void:
			_narr_gen += 1
			Narrator.stop()
			gears_pressed.emit())
	_gears_btn = gears_col.get_node("TileButton") as Button
	row.add_child(gears_col)

	var cruise_col := _make_tile(
		"Cruise & Stop",
		"Jerk pull cruise / push stop",
		CRUISE_TEX,
		_cruise_tint,
		func() -> void:
			_narr_gen += 1
			Narrator.stop()
			cruise_stop_pressed.emit())
	_cruise_btn = cruise_col.get_node("TileButton") as Button
	row.add_child(cruise_col)

	var joy_col := _make_tile(
		"Joystick (test)",
		"Distance from rest → accel",
		JOY_TEX,
		_joy_tint,
		func() -> void:
			_narr_gen += 1
			Narrator.stop()
			joystick_pressed.emit())
	_joy_btn = joy_col.get_node("TileButton") as Button
	row.add_child(joy_col)

func set_active(on: bool) -> void:
	visible = on
	mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE
	_narr_gen += 1
	if on:
		_narrate(_narr_gen)
	else:
		Narrator.stop()
		_set_outline(_gears_btn, _gears_tint, false)
		_set_outline(_cruise_btn, _cruise_tint, false)
		_set_outline(_joy_btn, _joy_tint, false)

func _narrate(gen: int) -> void:
	await get_tree().create_timer(0.25).timeout
	if gen != _narr_gen or not visible:
		return
	_set_outline(_gears_btn, _gears_tint, true)
	_set_outline(_cruise_btn, _cruise_tint, false)
	_set_outline(_joy_btn, _joy_tint, false)
	Narrator.speak(LINE_GEARS)
	await _await_vo(gen)
	if gen != _narr_gen or not visible:
		return
	_set_outline(_gears_btn, _gears_tint, false)
	_set_outline(_cruise_btn, _cruise_tint, true)
	Narrator.speak(LINE_CRUISE)
	await _await_vo(gen)
	if gen != _narr_gen or not visible:
		return
	_set_outline(_cruise_btn, _cruise_tint, false)
	_set_outline(_joy_btn, _joy_tint, true)
	Narrator.speak(LINE_JOY)
	await _await_vo(gen)
	if gen != _narr_gen or not visible:
		return
	await get_tree().create_timer(0.35).timeout
	if gen != _narr_gen:
		return
	_set_outline(_joy_btn, _joy_tint, false)

func _await_vo(gen: int) -> void:
	await get_tree().process_frame
	var t := 0.0
	while Narrator.is_playing() and t < 16.0:
		if gen != _narr_gen:
			return
		await get_tree().create_timer(0.05).timeout
		t += 0.05
	if gen == _narr_gen:
		await get_tree().create_timer(0.2).timeout

func _make_tile(label: String, hint: String, tex_path: String, tint: Color,
		on_press: Callable) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.custom_minimum_size = Vector2(360, 360)

	var btn := Button.new()
	btn.name = "TileButton"
	btn.custom_minimum_size = Vector2(360, 240)
	btn.focus_mode = Control.FOCUS_NONE
	btn.clip_contents = true
	_set_outline(btn, tint, false)
	btn.pressed.connect(on_press)
	col.add_child(btn)

	var pic := TextureRect.new()
	pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pic.offset_left = 6
	pic.offset_top = 6
	pic.offset_right = -6
	pic.offset_bottom = -6
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if ResourceLoader.exists(tex_path):
		pic.texture = load(tex_path)
	btn.add_child(pic)

	var name_lbl := Label.new()
	name_lbl.text = label
	name_lbl.add_theme_font_size_override("font_size", 24)
	name_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(name_lbl)

	var hint_lbl := Label.new()
	hint_lbl.text = hint
	hint_lbl.add_theme_font_size_override("font_size", 15)
	hint_lbl.add_theme_color_override("font_color", Color(0.72, 0.78, 0.95))
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_lbl.custom_minimum_size = Vector2(340, 0)
	hint_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(hint_lbl)

	return col

func _set_outline(b: Button, tint: Color, gold: bool) -> void:
	if b == null:
		return
	b.add_theme_color_override("font_color", Color(0, 0, 0, 0))
	b.add_theme_color_override("font_hover_color", Color(0, 0, 0, 0))
	b.add_theme_color_override("font_pressed_color", Color(0, 0, 0, 0))
	var sb := StyleBoxFlat.new()
	sb.bg_color = tint.lightened(0.06) if gold else tint
	sb.set_corner_radius_all(22)
	sb.set_border_width_all(6 if gold else 3)
	sb.border_color = GOLD if gold else Color(1, 1, 1, 0.55)
	sb.shadow_color = Color(0.95, 0.75, 0.2, 0.55) if gold else Color(0, 0, 0, 0.45)
	sb.shadow_size = 14 if gold else 10
	var hover := sb.duplicate() as StyleBoxFlat
	hover.border_color = GOLD
	hover.bg_color = tint.lightened(0.08)
	var pressed := sb.duplicate() as StyleBoxFlat
	pressed.bg_color = tint.darkened(0.12)
	pressed.border_color = GOLD
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("focus", hover)
	b.add_theme_stylebox_override("pressed", pressed)

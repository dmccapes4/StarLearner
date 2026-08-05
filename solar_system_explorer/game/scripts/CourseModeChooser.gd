class_name CourseModeChooser
extends Control
## After picking a destination: Kid course sim vs Rocket science.
## Mirrors FlightChooser / SpeedModeChooser tile + narration pattern.
## Choices are made BEFORE PlotBoard charts the course.

signal kid_pressed()
signal rocket_pressed()
signal go_home()

const LINE_KID := "Quick Course is the short trip — we plot, burn, coast, and brake."
const LINE_ROCKET := "Rocket Science uses real fuel math and engines — pick how you want to fly!"
const NARRATION := LINE_KID + " " + LINE_ROCKET

const KID_TEX := "res://images/tile_mission.png"
const ROCKET_TEX := "res://images/tile_speed_gears.png"
const GOLD := Color(1.0, 0.86, 0.28, 1.0)

var _kid_btn: Button
var _rocket_btn: Button
var _kid_tint: Color = Color(0.14, 0.36, 0.48)
var _rocket_tint: Color = Color(0.42, 0.22, 0.14)
var _narr_gen: int = 0
var _title: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

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
	box.add_theme_constant_override("separation", 14)
	box.custom_minimum_size = Vector2(1100, 520)
	center_wrap.add_child(box)

	_title = Label.new()
	_title.text = "How should we fly there?"
	_title.add_theme_font_size_override("font_size", 40)
	_title.add_theme_color_override("font_color", Color(1, 1, 1))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 36)
	box.add_child(row)

	var kid_col := _make_tile(
		"Quick Course",
		"Short burn · coast · brake",
		KID_TEX,
		_kid_tint,
		func() -> void:
			_narr_gen += 1
			Narrator.stop()
			kid_pressed.emit())
	_kid_btn = kid_col.get_node("TileButton") as Button
	row.add_child(kid_col)

	var rocket_col := _make_tile(
		"Rocket Science",
		"Real fuel · engines · windows",
		ROCKET_TEX,
		_rocket_tint,
		func() -> void:
			_narr_gen += 1
			Narrator.stop()
			rocket_pressed.emit())
	_rocket_btn = rocket_col.get_node("TileButton") as Button
	row.add_child(rocket_col)

	var back := Button.new()
	back.text = "\u25C0"
	back.size = Vector2(84, 66)
	back.position = Vector2(20, 20)
	back.focus_mode = Control.FOCUS_NONE
	back.add_theme_font_size_override("font_size", 28)
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color(0.95, 0.86, 0.45, 0.98)
	bsb.set_corner_radius_all(16)
	back.add_theme_stylebox_override("normal", bsb)
	back.pressed.connect(func() -> void:
		_narr_gen += 1
		Narrator.stop()
		go_home.emit())
	add_child(back)

func begin_for(dest_name: String) -> void:
	_title.text = "How should we fly to %s?" % (
		dest_name if not dest_name.is_empty() else "there")
	set_active(true)

func set_active(on: bool) -> void:
	visible = on
	mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE
	_narr_gen += 1
	if on:
		_narrate(_narr_gen)
	else:
		Narrator.stop()
		_set_outline(_kid_btn, _kid_tint, false)
		_set_outline(_rocket_btn, _rocket_tint, false)

func _narrate(gen: int) -> void:
	await get_tree().create_timer(0.35).timeout
	if gen != _narr_gen or not visible:
		return
	_set_outline(_kid_btn, _kid_tint, true)
	_set_outline(_rocket_btn, _rocket_tint, false)
	var d1 := Narrator.speak(LINE_KID)
	await _await_vo(gen, d1)
	if gen != _narr_gen or not visible:
		return
	_set_outline(_kid_btn, _kid_tint, false)
	_set_outline(_rocket_btn, _rocket_tint, true)
	var d2 := Narrator.speak(LINE_ROCKET)
	await _await_vo(gen, d2)
	if gen != _narr_gen or not visible:
		return
	await get_tree().create_timer(0.5).timeout
	if gen != _narr_gen:
		return
	_set_outline(_rocket_btn, _rocket_tint, false)

## Hold gold outline for the spoken line (baked VO, TTS, or a floor).
func _await_vo(gen: int, spoken_s: float = 0.0) -> void:
	await get_tree().process_frame
	var target: float = maxf(spoken_s, 3.2)
	var t := 0.0
	while t < target:
		if gen != _narr_gen:
			return
		if Narrator.is_playing():
			while Narrator.is_playing() and t < 22.0:
				if gen != _narr_gen:
					return
				await get_tree().create_timer(0.05).timeout
				t += 0.05
			if gen == _narr_gen:
				await get_tree().create_timer(0.35).timeout
			return
		await get_tree().create_timer(0.05).timeout
		t += 0.05

func _make_tile(label: String, hint: String, tex_path: String, tint: Color,
		on_press: Callable) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.custom_minimum_size = Vector2(480, 380)
	var btn := Button.new()
	btn.name = "TileButton"
	btn.custom_minimum_size = Vector2(480, 300)
	btn.focus_mode = Control.FOCUS_NONE
	btn.clip_contents = true
	_set_outline(btn, tint, false)
	btn.pressed.connect(on_press)
	col.add_child(btn)
	var pic := TextureRect.new()
	pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pic.offset_left = 8
	pic.offset_top = 8
	pic.offset_right = -8
	pic.offset_bottom = -8
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if ResourceLoader.exists(tex_path):
		pic.texture = load(tex_path)
	btn.add_child(pic)
	var name_lbl := Label.new()
	name_lbl.text = label
	name_lbl.add_theme_font_size_override("font_size", 32)
	name_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(name_lbl)
	var hint_lbl := Label.new()
	hint_lbl.text = hint
	hint_lbl.add_theme_font_size_override("font_size", 18)
	hint_lbl.add_theme_color_override("font_color", Color(0.72, 0.78, 0.95))
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(hint_lbl)
	return col

func _set_outline(b: Button, tint: Color, gold: bool) -> void:
	if b == null:
		return
	b.add_theme_color_override("font_color", Color(0, 0, 0, 0))
	var sb := StyleBoxFlat.new()
	sb.bg_color = tint.lightened(0.06) if gold else tint
	sb.set_corner_radius_all(22)
	sb.set_border_width_all(6 if gold else 3)
	sb.border_color = GOLD if gold else Color(1, 1, 1, 0.55)
	sb.shadow_color = Color(0.95, 0.75, 0.2, 0.55) if gold else Color(0, 0, 0, 0.45)
	sb.shadow_size = 14 if gold else 10
	var hover := sb.duplicate() as StyleBoxFlat
	hover.border_color = GOLD
	var pressed := sb.duplicate() as StyleBoxFlat
	pressed.bg_color = tint.darkened(0.12)
	pressed.border_color = GOLD
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("focus", hover)
	b.add_theme_stylebox_override("pressed", pressed)

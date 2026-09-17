class_name FlightChooser
extends Control
## Three-tile screen shown after tapping Spaceship, BEFORE the horizontal
## scroll view: pick MISSION FLIGHT (realistic plotted courses), FREE FLIGHT
## (fun phone-joystick playground) or EARTH SHIP (stand on Earth and watch the
## real sky move). Gold-outline narration on entry.

signal mission_pressed()
signal free_flight_pressed()
signal earth_ship_pressed()
signal night_sky_pressed()
signal go_home()

const LINE_MISSION := "Mission Flight is realistic — we plot a course and fly you there."
const LINE_FREE := "Free Flight is for fun — tilt your phone and steer anywhere you like!"
const LINE_EARTH := "Earth Ship keeps your feet on the ground — you watch the real sky from a real place on Earth."
const LINE_NIGHT := "Night Sky is a constellation viewer — explore the zodiac and the great star figures."
const NARRATION := LINE_MISSION + " " + LINE_FREE + " " + LINE_EARTH + " " + LINE_NIGHT

const MISSION_TEX := "res://images/tile_mission.png"
const FREE_TEX := "res://images/tile_free_flight.png"
const EARTH_TEX := "res://images/tile_earth_ship.png"
const NIGHT_TEX := "res://images/tile_night_sky.png"
const GOLD := Color(1.0, 0.86, 0.28, 1.0)

## Four across at 1280 wide: 4*270 + 3*26 = 1158, with margin to spare.
const TILE_SIZE := Vector2(270, 250)

var _mission_btn: Button
var _free_btn: Button
var _earth_btn: Button
var _night_btn: Button
var _mission_tint: Color = Color(0.16, 0.30, 0.52)
var _free_tint: Color = Color(0.34, 0.20, 0.46)
var _earth_tint: Color = Color(0.12, 0.34, 0.30)
var _night_tint: Color = Color(0.18, 0.18, 0.42)
var _narr_gen: int = 0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var center_wrap := CenterContainer.new()
	center_wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center_wrap)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	box.custom_minimum_size = Vector2(1180, 400)
	center_wrap.add_child(box)

	var title := Label.new()
	title.text = "How do you want to fly?"
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	box.add_child(row)

	var mission_col := _make_tile(
		"Mission Flight",
		"Realistic plotted courses",
		MISSION_TEX,
		_mission_tint,
		func() -> void:
			_narr_gen += 1
			Narrator.stop()
			mission_pressed.emit())
	_mission_btn = mission_col.get_node("TileButton") as Button
	row.add_child(mission_col)

	var free_col := _make_tile(
		"Free Flight",
		"Fun — you're the pilot!",
		FREE_TEX,
		_free_tint,
		func() -> void:
			_narr_gen += 1
			Narrator.stop()
			free_flight_pressed.emit())
	_free_btn = free_col.get_node("TileButton") as Button
	row.add_child(free_col)

	var earth_col := _make_tile(
		"Earth Ship",
		"Watch the real sky from Earth",
		EARTH_TEX,
		_earth_tint,
		func() -> void:
			_narr_gen += 1
			Narrator.stop()
			earth_ship_pressed.emit())
	_earth_btn = earth_col.get_node("TileButton") as Button
	row.add_child(earth_col)

	var night_col := _make_tile(
		"Night Sky",
		"Constellations from Earth",
		NIGHT_TEX,
		_night_tint,
		func() -> void:
			_narr_gen += 1
			Narrator.stop()
			night_sky_pressed.emit())
	_night_btn = night_col.get_node("TileButton") as Button
	row.add_child(night_col)

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

func set_active(on: bool) -> void:
	_narr_gen += 1
	if on:
		_narrate(_narr_gen)
	else:
		Narrator.stop()
		_clear_outlines()

func _clear_outlines() -> void:
	_set_outline(_mission_btn, _mission_tint, false)
	_set_outline(_free_btn, _free_tint, false)
	_set_outline(_earth_btn, _earth_tint, false)
	_set_outline(_night_btn, _night_tint, false)

## Walk the gold outline across the four tiles, one narration line each.
func _narrate(gen: int) -> void:
	await get_tree().create_timer(0.25).timeout
	if gen != _narr_gen or not visible:
		return
	var walk: Array = [
		[_mission_btn, _mission_tint, LINE_MISSION],
		[_free_btn, _free_tint, LINE_FREE],
		[_earth_btn, _earth_tint, LINE_EARTH],
		[_night_btn, _night_tint, LINE_NIGHT],
	]
	for step in walk:
		_clear_outlines()
		_set_outline(step[0] as Button, step[1] as Color, true)
		Narrator.speak(str(step[2]))
		await _await_vo(gen)
		if gen != _narr_gen or not visible:
			return
	await get_tree().create_timer(0.5).timeout
	if gen != _narr_gen:
		return
	_clear_outlines()

func _await_vo(gen: int) -> void:
	await get_tree().process_frame
	var t := 0.0
	while Narrator.is_playing() and t < 14.0:
		if gen != _narr_gen:
			return
		await get_tree().create_timer(0.05).timeout
		t += 0.05
	if gen == _narr_gen:
		await get_tree().create_timer(0.3).timeout

func _make_tile(label: String, hint: String, tex_path: String, tint: Color,
		on_press: Callable) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.custom_minimum_size = Vector2(TILE_SIZE.x, TILE_SIZE.y + 80.0)

	var btn := Button.new()
	btn.name = "TileButton"
	btn.custom_minimum_size = TILE_SIZE
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
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(name_lbl)

	var hint_lbl := Label.new()
	hint_lbl.text = hint
	hint_lbl.add_theme_font_size_override("font_size", 18)
	hint_lbl.add_theme_color_override("font_color", Color(0.72, 0.78, 0.95))
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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
	sb.set_corner_radius_all(28)
	sb.set_border_width_all(6 if gold else 3)
	sb.border_color = GOLD if gold else Color(1, 1, 1, 0.55)
	sb.shadow_color = Color(0.95, 0.75, 0.2, 0.55) if gold else Color(0, 0, 0, 0.45)
	sb.shadow_size = 18 if gold else 12
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

class_name TitleView
extends Control
## Launch hub: two large tiles — Spaceship (3D flyer) and Solar System (orrery tour).
## Narration highlights each tile with a gold outline as it is named.

const NavModes := preload("res://scripts/NavModes.gd")

signal flight_pressed()
signal explainer_pressed()

## Spoken after the boot orrery cinematic. Two beats — Spaceship, then Solar System.
const LINE_SHIP := "Explore the solar system in a spaceship."
const LINE_SOLAR := "Or get a narrated overview of the planets."
const WELCOME := LINE_SHIP + " " + LINE_SOLAR

const SHIP_TEX := "res://images/spaceship.png"
const SOLAR_TEX := "res://images/launch_solar.png"
const GOLD := Color(1.0, 0.86, 0.28, 1.0)

var _ship_btn: Button
var _solar_btn: Button
var _ship_tint: Color = Color(0.18, 0.32, 0.55)
var _solar_tint: Color = Color(0.35, 0.22, 0.12)
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
	box.add_theme_constant_override("separation", 16)
	box.custom_minimum_size = Vector2(1100, 520)
	center_wrap.add_child(box)

	var title := Label.new()
	title.text = "Solar System Explorer"
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var sub := Label.new()
	sub.text = "Pick how you want to explore"
	sub.add_theme_font_size_override("font_size", 22)
	sub.add_theme_color_override("font_color", Color(0.75, 0.82, 1.0))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	box.add_child(spacer)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 36)
	box.add_child(row)

	var ship_col := _make_tile(
		"Spaceship",
		"Fly through the solar system",
		SHIP_TEX,
		_ship_tint,
		func() -> void:
			_narr_gen += 1
			Narrator.stop()
			flight_pressed.emit())
	_ship_btn = ship_col.get_node("TileButton") as Button
	row.add_child(ship_col)

	var solar_col := _make_tile(
		"Solar System",
		"Watch the planets circle the Sun",
		SOLAR_TEX,
		_solar_tint,
		func() -> void:
			_narr_gen += 1
			Narrator.stop()
			explainer_pressed.emit())
	_solar_btn = solar_col.get_node("TileButton") as Button
	row.add_child(solar_col)

	# Nav-mode toggle: how the Spaceship trip is rendered/played.
	var mode_btn := Button.new()
	mode_btn.name = "ModeButton"
	mode_btn.text = "Flight style:  %s" % NavModes.label()
	mode_btn.focus_mode = Control.FOCUS_NONE
	mode_btn.custom_minimum_size = Vector2(360, 54)
	mode_btn.add_theme_font_size_override("font_size", 20)
	var msb := StyleBoxFlat.new()
	msb.bg_color = Color(0.10, 0.16, 0.30, 0.95)
	msb.set_corner_radius_all(14)
	msb.set_border_width_all(2)
	msb.border_color = Color(0.5, 0.7, 1.0, 0.6)
	mode_btn.add_theme_stylebox_override("normal", msb)
	mode_btn.add_theme_stylebox_override("pressed", msb)
	mode_btn.add_theme_stylebox_override("hover", msb)
	mode_btn.pressed.connect(func() -> void:
		NavModes.cycle()
		mode_btn.text = "Flight style:  %s" % NavModes.label())
	var mode_wrap := HBoxContainer.new()
	mode_wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	mode_wrap.add_child(mode_btn)
	box.add_child(mode_wrap)

func set_active(on: bool) -> void:
	_narr_gen += 1
	if on:
		_narrate_welcome(_narr_gen)
	else:
		Narrator.stop()
		_set_outline(_ship_btn, _ship_tint, false)
		_set_outline(_solar_btn, _solar_tint, false)

func _narrate_welcome(gen: int) -> void:
	# Let the boot cinematic's Narrator.stop() settle so the first line isn't clipped.
	await get_tree().create_timer(0.4).timeout
	if gen != _narr_gen or not visible:
		return
	_set_outline(_ship_btn, _ship_tint, true)
	_set_outline(_solar_btn, _solar_tint, false)
	Narrator.speak(LINE_SHIP)
	await _await_vo(gen)
	if gen != _narr_gen or not visible:
		return
	_set_outline(_ship_btn, _ship_tint, false)
	_set_outline(_solar_btn, _solar_tint, true)
	Narrator.speak(LINE_SOLAR)
	await _await_vo(gen)
	if gen != _narr_gen or not visible:
		return
	await get_tree().create_timer(0.5).timeout
	if gen != _narr_gen:
		return
	_set_outline(_solar_btn, _solar_tint, false)

func _await_vo(gen: int) -> void:
	await get_tree().process_frame
	var t := 0.0
	while Narrator.is_playing() and t < 14.0:
		if gen != _narr_gen:
			return
		await get_tree().create_timer(0.05).timeout
		t += 0.05
	# Small gap so the next outline/line doesn't stomp the tail.
	if gen == _narr_gen:
		await get_tree().create_timer(0.3).timeout

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
	pic.offset_left = 18
	pic.offset_top = 18
	pic.offset_right = -18
	pic.offset_bottom = -18
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var tex: Texture2D = load(tex_path)
	if tex != null:
		pic.texture = tex
	if tex_path.ends_with("spaceship.png"):
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	else:
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
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

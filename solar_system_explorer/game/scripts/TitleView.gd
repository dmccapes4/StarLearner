class_name TitleView
extends Control
## Launch hub: two large tiles — Spaceship (3D flyer) and Solar System (orrery tour).

signal flight_pressed()
signal explainer_pressed()

const WELCOME := "Welcome to Solar System Explorer. Tap Spaceship to fly, or Solar System for a tour of the planets."

const SHIP_TEX := "res://images/spaceship.png"
const SOLAR_TEX := "res://images/launch_solar.png"

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

	row.add_child(_make_tile(
		"Spaceship",
		"Fly through the solar system",
		SHIP_TEX,
		Color(0.18, 0.32, 0.55),
		func() -> void: flight_pressed.emit()))
	row.add_child(_make_tile(
		"Solar System",
		"Watch the planets circle the Sun",
		SOLAR_TEX,
		Color(0.35, 0.22, 0.12),
		func() -> void: explainer_pressed.emit()))

func set_active(on: bool) -> void:
	if on:
		Narrator.speak(WELCOME)
	else:
		Narrator.stop()

func _make_tile(label: String, hint: String, tex_path: String, tint: Color, on_press: Callable) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.custom_minimum_size = Vector2(480, 380)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(480, 300)
	btn.focus_mode = Control.FOCUS_NONE
	btn.clip_contents = true
	_style_tile(btn, tint)
	btn.pressed.connect(on_press)
	col.add_child(btn)

	# Image fills the button; KEEP_ASPECT_COVERED for the solar art,
	# KEEP_ASPECT_CENTERED for the ship so the rocket stays whole.
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

func _style_tile(b: Button, tint: Color) -> void:
	b.add_theme_color_override("font_color", Color(0, 0, 0, 0))
	b.add_theme_color_override("font_hover_color", Color(0, 0, 0, 0))
	b.add_theme_color_override("font_pressed_color", Color(0, 0, 0, 0))
	var sb := StyleBoxFlat.new()
	sb.bg_color = tint
	sb.set_corner_radius_all(28)
	sb.set_border_width_all(3)
	sb.border_color = Color(1, 1, 1, 0.55)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 12
	var hover := sb.duplicate() as StyleBoxFlat
	hover.border_color = Color(1.0, 0.86, 0.36, 0.95)
	hover.bg_color = tint.lightened(0.08)
	var pressed := sb.duplicate() as StyleBoxFlat
	pressed.bg_color = tint.darkened(0.12)
	pressed.border_color = Color(1.0, 0.82, 0.28, 1.0)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("focus", hover)
	b.add_theme_stylebox_override("pressed", pressed)

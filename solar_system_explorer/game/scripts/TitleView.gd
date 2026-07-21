class_name TitleView
extends Control
## Landing screen: title + big START button.

signal start_pressed()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var center_wrap := CenterContainer.new()
	center_wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center_wrap)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	box.custom_minimum_size = Vector2(640, 340)
	center_wrap.add_child(box)

	var title := Label.new()
	title.text = "Solar System Explorer"
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var sub := Label.new()
	sub.text = "A little tour of the Sun and its planets"
	sub.add_theme_font_size_override("font_size", 22)
	sub.add_theme_color_override("font_color", Color(0.75, 0.82, 1.0))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	box.add_child(spacer)

	var start := Button.new()
	start.text = "START"
	start.custom_minimum_size = Vector2(280, 110)
	start.add_theme_font_size_override("font_size", 44)
	_style_start(start)
	start.pressed.connect(func() -> void: start_pressed.emit())
	var center := CenterContainer.new()
	center.custom_minimum_size = Vector2(640, 120)
	center.add_child(start)
	box.add_child(center)

const WELCOME := "Welcome to Solar System Explorer. Press start to begin the tour."

func set_active(on: bool) -> void:
	if on:
		Narrator.speak(WELCOME)
	else:
		Narrator.stop()

func _style_start(b: Button) -> void:
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_color_override("font_color", Color(0.05, 0.06, 0.12))
	b.add_theme_color_override("font_hover_color", Color(0.05, 0.06, 0.12))
	b.add_theme_color_override("font_pressed_color", Color(0.05, 0.06, 0.12))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1.0, 0.82, 0.28)
	sb.set_corner_radius_all(28)
	sb.shadow_color = Color(0, 0, 0, 0.4)
	sb.shadow_size = 10
	var pressed := sb.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.9, 0.72, 0.22)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("focus", sb)
	b.add_theme_stylebox_override("pressed", pressed)

class_name OrreryView
extends Control
## Narrated top-down tour. The planets rotate while a voice names each one, then
## the view hands off to the horizontal scroll strip.

signal tour_finished()
signal go_home()

const OrreryBodies := preload("res://scripts/OrreryBodies.gd")

var _bodies: OrreryBodies
var _caption: Label
var _tour_gen: int = 0   ## bumped to cancel an in-flight tour

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_bodies = OrreryBodies.new()
	add_child(_bodies)

	var header := Label.new()
	header.text = "Watch the planets circle the Sun"
	header.add_theme_font_size_override("font_size", 24)
	header.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	header.set_anchors_preset(Control.PRESET_TOP_WIDE)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.position = Vector2(0, 18)
	add_child(header)

	_caption = Label.new()
	_caption.add_theme_font_size_override("font_size", 22)
	_caption.add_theme_color_override("font_color", Color(1, 1, 1))
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_caption.position = Vector2(160, -78)
	_caption.size = Vector2(960, 70)
	_caption.custom_minimum_size = Vector2(960, 70)
	add_child(_caption)

	add_child(_make_home_button())
	add_child(_make_skip_button())

func set_active(on: bool) -> void:
	_bodies.running = on
	if not on:
		stop_tour()

func begin_tour() -> void:
	_bodies.running = true
	_tour_gen += 1
	_run_tour(_tour_gen)

func stop_tour() -> void:
	_tour_gen += 1
	Narrator.stop()
	_bodies.set_highlight("")

func _run_tour(gen: int) -> void:
	for b in SolarData.tour_sequence():
		if gen != _tour_gen:
			return
		_bodies.set_highlight(str(b["id"]))
		_caption.text = b["name"]
		var dur := Narrator.speak(b["blurb"])
		await get_tree().create_timer(dur).timeout
	if gen != _tour_gen:
		return
	_bodies.set_highlight("")
	_caption.text = "Now let's look at them up close…"
	var closing := "That is the whole family of planets. Next you can scroll across the Sun and every planet, and tap one to learn more."
	var d := Narrator.speak(closing)
	await get_tree().create_timer(d).timeout
	if gen == _tour_gen:
		tour_finished.emit()

func _make_home_button() -> Button:
	var b := Button.new()
	b.text = "\u25C0"
	b.custom_minimum_size = Vector2(84, 66)
	b.size = Vector2(84, 66)
	b.position = Vector2(20, 20)
	_chip(b)
	b.pressed.connect(func() -> void: go_home.emit())
	return b

func _make_skip_button() -> Button:
	var b := Button.new()
	b.text = "Skip \u25B6"
	b.custom_minimum_size = Vector2(150, 66)
	b.size = Vector2(150, 66)
	b.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	b.position = Vector2(-170, 62)
	_chip(b)
	b.pressed.connect(func() -> void:
		stop_tour()
		tour_finished.emit())
	return b

func _chip(b: Button) -> void:
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 28)
	b.add_theme_color_override("font_color", Color(0.06, 0.05, 0.02))
	b.add_theme_color_override("font_hover_color", Color(0.06, 0.05, 0.02))
	b.add_theme_color_override("font_pressed_color", Color(0.06, 0.05, 0.02))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.95, 0.86, 0.45, 0.98)
	sb.set_corner_radius_all(16)
	sb.set_border_width_all(3)
	sb.border_color = Color(1, 1, 1, 0.9)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("focus", sb)
	b.add_theme_stylebox_override("pressed", sb)

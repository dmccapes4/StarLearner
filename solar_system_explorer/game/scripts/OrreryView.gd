class_name OrreryView
extends Control
## Narrated top-down tour. The planets rotate while a voice names each one, then
## the view hands off to the horizontal scroll strip.

signal tour_finished()
signal go_home()

const OrreryBodies := preload("res://scripts/OrreryBodies.gd")
const CLOSING := "That is the whole family of planets. Tap the arrow when you want to go home — or pick Spaceship to fly there yourself!"
const BOOT_LINE := "Welcome to Solar System Explorer!"
const BOOT_DURATION_S := 3.0

var _bodies: OrreryBodies
var _caption: Label
var _header: Label
var _home_btn: Button
var _skip_btn: Button
var _tour_gen: int = 0   ## bumped to cancel an in-flight tour
var _boot_busy: bool = false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_bodies = OrreryBodies.new()
	add_child(_bodies)

	_header = Label.new()
	_header.text = "Watch the planets circle the Sun"
	_header.add_theme_font_size_override("font_size", 24)
	_header.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	_header.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header.position = Vector2(0, 18)
	add_child(_header)

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

	_home_btn = _make_home_button()
	_skip_btn = _make_skip_button()
	add_child(_home_btn)
	add_child(_skip_btn)

func set_active(on: bool) -> void:
	_bodies.running = on
	if not on and not _boot_busy:
		stop_tour()

## Short launch cinematic: orrery spins while the welcome line plays.
func play_boot_intro() -> void:
	_boot_busy = true
	_tour_gen += 1   # cancel any leftover tour
	_header.visible = false
	_caption.text = ""
	_home_btn.visible = false
	_skip_btn.visible = false
	_bodies.set_highlight("")
	_bodies.running = true
	visible = true
	Narrator.speak(BOOT_LINE)
	await get_tree().create_timer(BOOT_DURATION_S).timeout
	# Don't hard-stop mid-clip — title waits briefly before speaking.
	_bodies.running = false
	_header.visible = true
	_home_btn.visible = true
	_skip_btn.visible = true
	visible = false
	_boot_busy = false

func begin_tour() -> void:
	_bodies.running = true
	_header.visible = true
	_home_btn.visible = true
	_skip_btn.visible = true
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
	_caption.text = "That's the whole solar system!"
	var d := Narrator.speak(CLOSING)
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

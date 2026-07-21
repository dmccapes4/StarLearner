class_name ComingSoon
extends CanvasLayer
## First thing on launch: a teaser splash for the planned 3D flyer. A concept
## frame (over-the-shoulder view of the astronaut girl piloting a cockpit toward
## the planets) with a spoken "coming soon" line, tuned for a six-year-old. Fades
## out to the title. Tap to skip. The girl is only in this teaser, never the game.

signal finished()

const IMG_PATH := "res://images/coming_soon.png"
const HEADING := "Coming soon!"
const NARRATION := "Coming soon! Soon you'll fly your very own spaceship, and steer it on a path through space, all the way to the planets. Get ready to be a space pilot!"

var _root: Control
var _built: bool = false
var _done: bool = false

func _ready() -> void:
	layer = 20
	visible = false

func begin() -> void:
	_build()
	visible = true
	_done = false
	_root.modulate = Color(1, 1, 1, 0)
	var fade_in := create_tween()
	fade_in.tween_property(_root, "modulate:a", 1.0, 0.5)
	var dur := Narrator.speak(NARRATION)
	await get_tree().create_timer(maxf(dur, 4.0)).timeout
	_advance()

func _advance() -> void:
	if _done:
		return
	_done = true
	Narrator.stop()
	var out := create_tween()
	out.tween_property(_root, "modulate:a", 0.0, 0.9)
	out.tween_callback(func() -> void:
		visible = false
		finished.emit())

func _build() -> void:
	if _built:
		return
	_built = true

	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.gui_input.connect(_on_input)
	add_child(_root)

	var pic := TextureRect.new()
	pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex := load(IMG_PATH)
	if tex != null:
		pic.texture = tex
	_root.add_child(pic)

	var heading := Label.new()
	heading.text = HEADING
	heading.add_theme_font_size_override("font_size", 56)
	heading.add_theme_color_override("font_color", Color(1.0, 0.86, 0.36))
	heading.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.92))
	heading.add_theme_constant_override("outline_size", 8)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.set_anchors_preset(Control.PRESET_TOP_WIDE)
	heading.position = Vector2(0, 26)
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(heading)

	# Voice-only: no caption (the child can't read it yet). Just a small skip hint.
	var hint := Label.new()
	hint.text = "tap to continue \u25B6"
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	hint.add_theme_constant_override("outline_size", 4)
	hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.position = Vector2(-210, -40)
	hint.size = Vector2(190, 24)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(hint)

func _on_input(event: InputEvent) -> void:
	var tap := false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tap = true
	elif event is InputEventScreenTouch and event.pressed:
		tap = true
	if tap:
		_advance()

class_name AstronautIntro
extends CanvasLayer
## Cinematic hand-off between the orrery tour and the scroll strip: a cartoon
## astronaut girl (helmet under one arm, waving) in front of her spaceship, with
## a spoken "you are an astronaut" briefing. Fades out to reveal the scroll view
## underneath, so it reads as changing into the piloting screen. Tap to skip.

signal finished()

const IMG_PATH := "res://images/astronaut_girl.png"
const BRIEFING := "You are an astronaut, about to blast off in your very own spaceship to explore the solar system! Pilot your ship to new places out in space. Tap on a planet or the Sun to learn more about it. Ready? Let's go!"

var _root: Control
var _built: bool = false
var _done: bool = false

func _ready() -> void:
	layer = 15
	visible = false

func begin() -> void:
	_build()
	visible = true
	_done = false
	_root.modulate = Color(1, 1, 1, 0)
	var fade_in := create_tween()
	fade_in.tween_property(_root, "modulate:a", 1.0, 0.4)
	var dur := Narrator.speak(BRIEFING)
	await get_tree().create_timer(maxf(dur, 3.5)).timeout
	_advance()

func _advance() -> void:
	if _done:
		return
	_done = true
	Narrator.stop()
	var out := create_tween()
	out.tween_property(_root, "modulate:a", 0.0, 1.1)
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

	# Voice-only briefing — no on-screen script. Small skip hint only.
	var hint := Label.new()
	hint.text = "tap to continue \u25B6"
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	hint.add_theme_constant_override("outline_size", 4)
	hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.position = Vector2(-210, -40)
	hint.size = Vector2(190, 28)
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

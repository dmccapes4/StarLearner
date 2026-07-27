class_name AstronautIntro
extends CanvasLayer
## Mode-specific briefing before Mission Flight or Free Flight: cartoon astronaut
## girl (helmet under one arm, waving) in front of her spaceship, with baked VO.
## Fades out to reveal the scroll strip or playground underneath. Tap to skip.

signal finished()

const IMG_PATH := "res://images/astronaut_girl.png"

const BRIEFING_MISSION := "Welcome aboard, astronaut! In Mission Flight, you'll travel on simulated courses — paths we plot between the planets, the Sun, and even worlds in the asteroid belt. Swipe to pick a destination, watch your route appear on the map, and your ship will follow that charted path through space. Tap a world when you're ready to plot your course!"

const BRIEFING_FREE_FLIGHT := "You're the pilot now! In Free Flight, your phone is the joystick — tilt to steer anywhere in the solar system. Pull the phone toward you to go faster, push it away to slow down. A quick shove stops you; a quick pull starts you cruising again. We'll practice in just a moment. Ready? Let's fly!"

## Back-compat alias — Mission briefing.
const BRIEFING := BRIEFING_MISSION

var _root: Control
var _built: bool = false
var _done: bool = false

func _ready() -> void:
	layer = 15
	visible = false

func begin(briefing: String = BRIEFING_MISSION) -> void:
	_build()
	visible = true
	_done = false
	_root.modulate = Color(1, 1, 1, 0)
	var fade_in := create_tween()
	fade_in.tween_property(_root, "modulate:a", 1.0, 0.4)
	var dur := Narrator.speak(briefing)
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

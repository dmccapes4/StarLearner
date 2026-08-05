class_name BriefingSlideshow
extends CanvasLayer
## Rocket Science pre-chart briefing: stills + light motion synced to VO parts.
## Parts come from AstrogatorPanel.mission_briefing_parts(). Tap skips the rest.

signal finished()

const SLIDE_DIR := "res://images/briefing/"
const KEN_BURNS_S := 8.0

var _root: Control
var _pic: TextureRect
var _fx: _BriefingFx
var _caption: Label
var _hint: Label
var _built: bool = false
var _gen: int = 0
var _playing: bool = false

func _ready() -> void:
	layer = 16
	visible = false

## parts: Array of { "slide": String, "text": String }
func play(parts: Array) -> void:
	_build()
	_gen += 1
	var gen := _gen
	_playing = true
	visible = true
	_root.modulate = Color(1, 1, 1, 0)
	var fade := create_tween()
	fade.tween_property(_root, "modulate:a", 1.0, 0.35)
	for part in parts:
		if gen != _gen or not _playing:
			break
		var slide_id := str(part.get("slide", ""))
		var text := str(part.get("text", ""))
		_show_slide(slide_id)
		_caption.text = text
		var dur := Narrator.speak(text)
		await _await_vo(gen, dur)
		if gen != _gen or not _playing:
			break
		await get_tree().create_timer(0.25).timeout
	if gen != _gen:
		# Tap-skip already fading; wait so PlotBoard doesn't pop under it.
		await get_tree().create_timer(0.4).timeout
		return
	await _close()

func stop() -> void:
	_gen += 1
	_playing = false
	Narrator.stop()
	visible = false
	finished.emit()

func _await_vo(gen: int, spoken_s: float) -> void:
	await get_tree().process_frame
	var target: float = maxf(spoken_s, 2.8)
	var t := 0.0
	while t < target:
		if gen != _gen or not _playing:
			return
		if Narrator.is_playing():
			while Narrator.is_playing() and t < 40.0:
				if gen != _gen or not _playing:
					return
				await get_tree().create_timer(0.05).timeout
				t += 0.05
			if gen == _gen and _playing:
				await get_tree().create_timer(0.3).timeout
			return
		await get_tree().create_timer(0.05).timeout
		t += 0.05

func _close() -> void:
	_playing = false
	Narrator.stop()
	var out := create_tween()
	out.tween_property(_root, "modulate:a", 0.0, 0.45)
	await out.finished
	visible = false
	finished.emit()

func _show_slide(slide_id: String) -> void:
	var path := SLIDE_DIR + slide_id + ".png"
	if ResourceLoader.exists(path):
		_pic.texture = load(path)
	else:
		_pic.texture = null
	_pic.scale = Vector2(1.08, 1.08)
	_pic.position = Vector2(-40, -20)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_pic, "scale", Vector2(1.0, 1.0), KEN_BURNS_S) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(_pic, "position", Vector2(0, 0), KEN_BURNS_S) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if _fx != null:
		_fx.set_mode(slide_id)

func _build() -> void:
	if _built:
		return
	_built = true
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.clip_contents = true
	_root.gui_input.connect(_on_input)
	add_child(_root)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.03, 0.08, 0.92)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)

	_pic = TextureRect.new()
	_pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_pic)

	_fx = _BriefingFx.new()
	_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_fx)

	var cap_bg := Panel.new()
	cap_bg.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	cap_bg.offset_top = -132
	cap_bg.offset_bottom = -8
	cap_bg.offset_left = 24
	cap_bg.offset_right = -24
	cap_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.07, 0.14, 0.88)
	sb.set_corner_radius_all(14)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.45, 0.65, 1.0, 0.4)
	cap_bg.add_theme_stylebox_override("panel", sb)
	_root.add_child(cap_bg)

	_caption = Label.new()
	_caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_caption.offset_left = 18
	_caption.offset_top = 12
	_caption.offset_right = -18
	_caption.offset_bottom = -12
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.add_theme_font_size_override("font_size", 20)
	_caption.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0))
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap_bg.add_child(_caption)

	_hint = Label.new()
	_hint.text = "tap to skip \u25B6"
	_hint.add_theme_font_size_override("font_size", 16)
	_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_hint.add_theme_constant_override("outline_size", 3)
	_hint.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_hint.position = Vector2(-170, 16)
	_hint.size = Vector2(150, 24)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_hint)

func _on_input(event: InputEvent) -> void:
	var tap := false
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		tap = true
	elif event is InputEventScreenTouch and event.pressed:
		tap = true
	if tap and _playing:
		_gen += 1
		_playing = false
		Narrator.stop()
		var out := create_tween()
		out.tween_property(_root, "modulate:a", 0.0, 0.35)
		out.tween_callback(func() -> void:
			visible = false
			finished.emit())


## Light procedural motion on top of the still (flame flicker, year ticks…).
class _BriefingFx extends Control:
	var mode: String = ""
	var _t: float = 0.0

	func set_mode(m: String) -> void:
		mode = m
		_t = 0.0
		queue_redraw()

	func _process(delta: float) -> void:
		if mode.is_empty() or not visible:
			return
		_t += delta
		queue_redraw()

	func _draw() -> void:
		if mode.is_empty():
			return
		var c := size * 0.5
		match mode:
			"engine_chemical":
				var flick: float = 0.7 + 0.3 * sin(_t * 16.0)
				draw_circle(c + Vector2(80, 40), 18.0 * flick,
					Color(1.0, 0.55, 0.15, 0.35))
			"engine_ntp":
				var p: float = 0.5 + 0.5 * sin(_t * 4.0)
				draw_circle(c, 36.0, Color(0.2, 0.85, 0.9, 0.12 * p))
			"engine_orion":
				var flash: float = maxf(0.0, sin(_t * 3.2))
				draw_circle(c + Vector2(0, 50), 50.0 + flash * 20.0,
					Color(1.0, 0.5, 0.2, 0.15 * flash))
			"coast":
				# Soft year-pulse ticks on the right
				var a: float = 0.25 + 0.2 * sin(_t * 2.0)
				draw_rect(Rect2(size.x - 220, size.y * 0.55, 160, 8),
					Color(1.0, 0.9, 0.4, a))
			"fuel":
				var fill: float = 0.55 + 0.08 * sin(_t * 1.4)
				draw_rect(Rect2(c.x - 40, c.y - 100, 80, 200.0 * fill),
					Color(0.85, 0.35, 0.25, 0.18))
			_:
				pass

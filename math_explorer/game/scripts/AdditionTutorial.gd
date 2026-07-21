class_name AdditionTutorial
extends Control
## The showcase tutorial: "7 + 4 =" brought to life.
##   1. The equation builds up as it's spoken.
##   2. Seven red cubes appear and are counted (gold ring: bright = current,
##      dull = already counted).
##   3. Four blue cubes appear and are counted (grey ring).
##   4. "+" appears; we keep counting ON from seven — 8, 9, 10, 11 — over the
##      blue cubes with the gold ring, which is the whole idea of addition.
##   5. "7 + 4 = 11"; every cube turns gold and the two groups slide together.
## Fully narrated. Tap to skip to the end; a Replay button restarts it.

signal finished()

const CountBeat := 0.72   # seconds per counted cube
const NUMBER_WORDS := ["zero", "one", "two", "three", "four", "five", "six",
	"seven", "eight", "nine", "ten", "eleven", "twelve"]

var _a: int = 7
var _b: int = 4
var _gen: int = 0
var _skipping: bool = false

var _eq: Label
var _plus: Label
var _red: CubeGroup
var _blue: CubeGroup
var _hint: Label
var _built: bool = false

func start(a: int = 7, b: int = 4) -> void:
	_a = a
	_b = b
	_build()
	_gen += 1
	_skipping = false
	_run(_gen)

## Every narration line this tutorial can speak for `a + b` — enumerated by
## tools/dump_vo_lines.gd so each sentence gets a baked ElevenLabs clip.
static func vo_lines(a: int, b: int) -> Array:
	var out := [
		"Let's add %s plus %s." % [a, b],
		"Here are %s red squares. Let's count them." % a,
		"Plus",
		"And here are %s blue squares." % b,
		"Now we keep counting. We already have %s, so we count on." % a,
		"%s plus %s equals %s! Great counting." % [a, b, a + b],
	]
	for v in range(1, a + b + 1):
		out.append(NUMBER_WORDS[v] if v < NUMBER_WORDS.size() else str(v))
	return out

func _build() -> void:
	if _built:
		return
	_built = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_input)

	_eq = _make_label(72, MathTheme.TEXT)
	_eq.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_eq.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_eq.position = Vector2(0, 24)
	add_child(_eq)

	_plus = _make_label(60, MathTheme.GOLD)
	_plus.size = Vector2(80, 80)
	_plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_plus.visible = false
	add_child(_plus)

	_red = CubeGroup.new()
	_red.cell = 52.0
	_red.gap = 10.0
	_red.columns = 12
	add_child(_red)

	_blue = CubeGroup.new()
	_blue.cell = 52.0
	_blue.gap = 10.0
	_blue.columns = 12
	add_child(_blue)

	_hint = _make_label(18, Color(1, 1, 1, 0.7))
	_hint.text = "tap to skip \u25B6"
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_hint.position = Vector2(-190, -40)
	_hint.size = Vector2(170, 26)
	add_child(_hint)

func _make_label(font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

# ---- choreography -----------------------------------------------------------

func _run(gen: int) -> void:
	_eq.text = ""
	_plus.visible = false
	_red.setup(0, MathTheme.RED)
	_blue.setup(0, MathTheme.BLUE)

	# 1) The first number.
	Narrator.speak("Let's add %s plus %s." % [_a, _b])
	if not await _wait(gen, 1.4): return
	_eq.text = str(_a)
	_red.setup(_a, MathTheme.RED, CubeGroup.HUE.GOLD)
	_layout_groups()
	Narrator.speak("Here are %s red squares. Let's count them." % _a)
	if not await _wait(gen, 1.9): return
	if not await _count(gen, _red, 0, _a, 1, CubeGroup.HUE.GOLD): return

	# 2) The plus and the second number.
	_eq.text = "%s  +" % _a
	_plus.visible = true
	Narrator.speak("Plus")
	if not await _wait(gen, 0.9): return
	_eq.text = "%s  +  %s" % [_a, _b]
	_blue.setup(_b, MathTheme.BLUE, CubeGroup.HUE.GREY)
	_layout_groups()
	Narrator.speak("And here are %s blue squares." % _b)
	if not await _wait(gen, 1.7): return
	if not await _count(gen, _blue, 0, _b, 1, CubeGroup.HUE.GREY): return

	# 3) Count ON from A across the blue cubes — this is addition.
	_eq.text = "%s  +  %s  =" % [_a, _b]
	Narrator.speak("Now we keep counting. We already have %s, so we count on." % _a)
	if not await _wait(gen, 2.6): return
	_red.set_all_state(CubeGroup.HL.DONE)
	if not await _count(gen, _blue, 0, _b, _a + 1, CubeGroup.HUE.GOLD): return

	# 4) The answer.
	var total := _a + _b
	_eq.text = "%s  +  %s  =  %s" % [_a, _b, total]
	_red.set_all_color(MathTheme.GOLD)
	_blue.set_all_color(MathTheme.GOLD)
	_red.set_all_state(CubeGroup.HL.DONE)
	_blue.set_all_state(CubeGroup.HL.DONE)
	_join_groups()
	Narrator.speak("%s plus %s equals %s! Great counting." % [_a, _b, total])
	if not await _wait(gen, 2.6): return
	_hint.text = "\u2713 done"
	finished.emit()

## Highlight-count `n` cubes in `grp`, speaking a running label that starts at
## `start_num` (so we can "count on": 8, 9, 10, 11).
func _count(gen: int, grp: CubeGroup, from_i: int, n: int, start_num: int, hue: int) -> bool:
	for k in n:
		var i := from_i + k
		grp.set_state(i, CubeGroup.HL.CURRENT, hue)
		_say_number(start_num + k)
		if not await _wait(gen, CountBeat): return false
		grp.set_state(i, CubeGroup.HL.DONE, hue)
	return true

func _say_number(v: int) -> void:
	if v >= 0 and v < NUMBER_WORDS.size():
		Narrator.speak(NUMBER_WORDS[v])
	else:
		Narrator.speak(str(v))

# ---- layout -----------------------------------------------------------------

func _layout_groups() -> void:
	var cy := 250.0
	_center_group(_red, Vector2(400.0, cy))
	_center_group(_blue, Vector2(880.0, cy))
	_plus.position = Vector2(600.0, cy - 40.0)

func _join_groups() -> void:
	var cy := 250.0
	# Slide the two blocks next to each other, centred on screen.
	var rw := _red.size.x
	var bw := _blue.size.x
	var total_w := rw + 24.0 + bw
	var left := 640.0 - total_w * 0.5
	var tw := create_tween()
	tw.set_parallel(true)
	tw.set_trans(Tween.TRANS_CUBIC)
	tw.set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_red, "position", Vector2(left, cy - _red.size.y * 0.5), 0.7)
	tw.tween_property(_blue, "position",
		Vector2(left + rw + 24.0, cy - _blue.size.y * 0.5), 0.7)
	_plus.visible = false

func _center_group(grp: CubeGroup, at: Vector2) -> void:
	grp.position = at - grp.size * 0.5

# ---- input ------------------------------------------------------------------

func _on_input(event: InputEvent) -> void:
	var tap := false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tap = true
	elif event is InputEventScreenTouch and event.pressed:
		tap = true
	if tap and not _skipping:
		_skip_to_end()

func _skip_to_end() -> void:
	_skipping = true
	_gen += 1  # cancel the running sequence
	Narrator.stop()
	var total := _a + _b
	_eq.text = "%s  +  %s  =  %s" % [_a, _b, total]
	_plus.visible = false
	_red.setup(_a, MathTheme.GOLD, CubeGroup.HUE.GOLD)
	_blue.setup(_b, MathTheme.GOLD, CubeGroup.HUE.GOLD)
	_red.set_all_state(CubeGroup.HL.DONE)
	_blue.set_all_state(CubeGroup.HL.DONE)
	_layout_groups()
	_join_groups()
	_hint.text = "\u2713 done"
	finished.emit()

## Await a timer but bail out if a newer run (or skip) superseded us.
func _wait(gen: int, secs: float) -> bool:
	await get_tree().create_timer(secs).timeout
	return gen == _gen and is_inside_tree()

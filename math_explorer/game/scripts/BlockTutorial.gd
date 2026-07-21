class_name BlockTutorial
extends Control
## Block tutorials for subtraction, multiplication, and division — the same
## cube language as AdditionTutorial (gold ring = counting now, dull = counted):
##   sub  7 − 4 : count seven red cubes; four turn grey and slide away, counted
##                out loud; count what's left — that's take-away.
##   mul  3 × 4 : three groups of four green cubes; count each group, then count
##                straight across all of them — groups make multiplication.
##   div  9 ÷ 3 : nine gold cubes deal one at a time into three coloured
##                buckets; count one bucket — sharing is division.
## Numbers are FIXED per op so every narrated sentence has a baked ElevenLabs
## clip (see vo_lines / tools/dump_vo_lines.gd). Tap to skip.

signal finished()

const CountBeat := 0.72
const NUMBER_WORDS := ["zero", "one", "two", "three", "four", "five", "six",
	"seven", "eight", "nine", "ten", "eleven", "twelve"]

## Fixed tutorial numbers per op (mirrors MathData examples).
const SPECS := {
	"sub": {"a": 7, "b": 4},
	"mul": {"g": 3, "n": 4},
	"div": {"total": 9, "buckets": 3},
}

var _op: String = "sub"
var _gen: int = 0
var _skipping: bool = false

var _eq: Label
var _hint: Label
var _groups: Array = []      # CubeGroup nodes
var _bucket_panels: Array = []
var _built := false

func start(op: String) -> void:
	_op = op if SPECS.has(op) else "sub"
	_build()
	_gen += 1
	_skipping = false
	_clear()
	_run(_gen)

## Every narration line per op — enumerated by tools/dump_vo_lines.gd.
static func vo_lines(op: String) -> Array:
	match op:
		"sub":
			return [
				"Let's take away. We start with seven red squares.",
				"Now we take four away. Watch them go.",
				"Count what is left.",
				"Seven take away four leaves three!",
			]
		"mul":
			return [
				"Let's multiply. Here are three groups, with four squares in each group.",
				"Count a group: one, two, three, four.",
				"Every group has four. Now count them all.",
				"Three groups of four makes twelve!",
			]
		"div":
			return [
				"Let's divide. Nine squares, and three buckets to share them into.",
				"One for each bucket, around and around, until they are all gone.",
				"Count one bucket.",
				"Nine shared into three buckets is three each!",
			]
	return []

func _build() -> void:
	if _built:
		return
	_built = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_input)

	_eq = Label.new()
	_eq.add_theme_font_size_override("font_size", 72)
	_eq.add_theme_color_override("font_color", MathTheme.TEXT)
	_eq.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_eq.add_theme_constant_override("outline_size", 5)
	_eq.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_eq.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_eq.position = Vector2(0, 24)
	_eq.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_eq)

	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 18)
	_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	_hint.text = "tap to skip \u25B6"
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_hint.position = Vector2(-190, -40)
	_hint.size = Vector2(170, 26)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)

func _clear() -> void:
	for g in _groups: g.queue_free()
	for p in _bucket_panels: p.queue_free()
	_groups.clear()
	_bucket_panels.clear()
	_eq.text = ""
	_hint.text = "tap to skip \u25B6"

# ---- choreography -------------------------------------------------------------

func _run(gen: int) -> void:
	match _op:
		"sub": await _run_sub(gen)
		"mul": await _run_mul(gen)
		"div": await _run_div(gen)

func _run_sub(gen: int) -> void:
	var a: int = SPECS["sub"]["a"]
	var b: int = SPECS["sub"]["b"]
	_eq.text = str(a)
	var grp := _add_group(a, MathTheme.RED, 12)
	_center(grp, Vector2(640, 280))
	var d := Narrator.speak("Let's take away. We start with seven red squares.")
	if not await _wait(gen, maxf(2.0, d)): return
	if not await _count(gen, grp, 0, a, 1, CubeGroup.HUE.GOLD): return

	_eq.text = "%d  \u2212  %d" % [a, b]
	d = Narrator.speak("Now we take four away. Watch them go.")
	if not await _wait(gen, maxf(2.0, d)): return
	for k in b:
		var i := a - 1 - k
		grp.set_state(i, CubeGroup.HL.CURRENT, CubeGroup.HUE.GREY)
		var dn := _say_number(k + 1)
		if not await _wait(gen, maxf(CountBeat, dn - 0.5)): return
		grp.set_color(i, Color(MathTheme.GREY, 0.12))
		grp.set_state(i, CubeGroup.HL.NONE)

	_eq.text = "%d  \u2212  %d  =" % [a, b]
	d = Narrator.speak("Count what is left.")
	if not await _wait(gen, maxf(1.6, d)): return
	if not await _count(gen, grp, 0, a - b, 1, CubeGroup.HUE.GOLD): return

	_eq.text = "%d  \u2212  %d  =  %d" % [a, b, a - b]
	for i in range(0, a - b):
		grp.set_color(i, MathTheme.GOLD)
	d = Narrator.speak("Seven take away four leaves three!")
	if not await _wait(gen, maxf(2.2, d)): return
	_finish()

func _run_mul(gen: int) -> void:
	var g: int = SPECS["mul"]["g"]
	var n: int = SPECS["mul"]["n"]
	_eq.text = "%d  \u00D7  %d" % [g, n]
	var groups: Array = []
	for gi in g:
		var grp := _add_group(n, MathTheme.GREEN, n)
		groups.append(grp)
	_row(groups, 280.0, 60.0)
	var d := Narrator.speak("Let's multiply. Here are three groups, with four squares in each group.")
	if not await _wait(gen, maxf(2.6, d)): return

	d = Narrator.speak("Count a group: one, two, three, four.")
	if not await _wait(gen, maxf(1.2, d)): return
	if not await _count(gen, groups[0], 0, n, 1, CubeGroup.HUE.GOLD): return

	_eq.text = "%d  \u00D7  %d  =" % [g, n]
	d = Narrator.speak("Every group has four. Now count them all.")
	if not await _wait(gen, maxf(2.0, d)): return
	var num := 1
	for grp in groups:
		(grp as CubeGroup).set_all_state(CubeGroup.HL.NONE)
	for grp in groups:
		var cg := grp as CubeGroup
		for i in cg.count():
			cg.set_state(i, CubeGroup.HL.CURRENT, CubeGroup.HUE.GOLD)
			var dn := _say_number(num)
			if not await _wait(gen, maxf(CountBeat, dn - 0.5)): return
			cg.set_state(i, CubeGroup.HL.DONE, CubeGroup.HUE.GOLD)
			num += 1

	_eq.text = "%d  \u00D7  %d  =  %d" % [g, n, g * n]
	for grp in groups:
		(grp as CubeGroup).set_all_color(MathTheme.GOLD)
	d = Narrator.speak("Three groups of four makes twelve!")
	if not await _wait(gen, maxf(2.2, d)): return
	_finish()

func _run_div(gen: int) -> void:
	var total: int = SPECS["div"]["total"]
	var buckets: int = SPECS["div"]["buckets"]
	var colors := [MathTheme.RED, MathTheme.BLUE, MathTheme.GREEN]
	_eq.text = "%d  \u00F7  %d" % [total, buckets]

	var pool := _add_group(total, MathTheme.GOLD, total)
	_center(pool, Vector2(640, 210))
	# Three bucket groups (empty), drawn as outlined panels the cubes "land" in.
	var bgroups: Array = []
	for bi in buckets:
		var panel := Panel.new()
		panel.size = Vector2(200, 96)
		panel.position = Vector2(640 - 330 + bi * 230, 330)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(colors[bi], 0.14)
		sb.set_corner_radius_all(16)
		sb.set_border_width_all(3)
		sb.border_color = Color(colors[bi], 0.8)
		panel.add_theme_stylebox_override("panel", sb)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(panel)
		_bucket_panels.append(panel)
		var grp := _add_group(0, colors[bi], total)
		grp.position = panel.position + Vector2(22, 24)
		bgroups.append(grp)

	var d := Narrator.speak("Let's divide. Nine squares, and three buckets to share them into.")
	if not await _wait(gen, maxf(2.6, d)): return

	d = Narrator.speak("One for each bucket, around and around, until they are all gone.")
	if not await _wait(gen, maxf(2.2, d)): return
	for i in total:
		var bi := i % buckets
		pool.set_color(i, Color(MathTheme.GOLD, 0.10))
		var bg := bgroups[bi] as CubeGroup
		bg.setup(bg.count() + 1, colors[bi])
		bg.position = (_bucket_panels[bi] as Panel).position + Vector2(22, 24)
		if not await _wait(gen, 0.42): return

	_eq.text = "%d  \u00F7  %d  =" % [total, buckets]
	d = Narrator.speak("Count one bucket.")
	if not await _wait(gen, maxf(1.4, d)): return
	if not await _count(gen, bgroups[0], 0, total / buckets, 1, CubeGroup.HUE.GOLD): return

	_eq.text = "%d  \u00F7  %d  =  %d" % [total, buckets, total / buckets]
	for bg in bgroups:
		(bg as CubeGroup).set_all_color(MathTheme.GOLD)
	d = Narrator.speak("Nine shared into three buckets is three each!")
	if not await _wait(gen, maxf(2.2, d)): return
	_finish()

func _finish() -> void:
	_hint.text = "\u2713 done"
	finished.emit()

# ---- helpers -------------------------------------------------------------------

func _add_group(n: int, color: Color, cols: int) -> CubeGroup:
	var g := CubeGroup.new()
	g.cell = 52.0
	g.gap = 10.0
	g.columns = cols
	g.setup(n, color)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(g)
	_groups.append(g)
	return g

func _center(grp: CubeGroup, at: Vector2) -> void:
	grp.position = at - grp.size * 0.5

func _row(groups: Array, cy: float, gap: float) -> void:
	var total := 0.0
	for g in groups:
		total += (g as CubeGroup).size.x
	total += gap * float(groups.size() - 1)
	var x := 640.0 - total * 0.5
	for g in groups:
		var cg := g as CubeGroup
		cg.position = Vector2(x, cy - cg.size.y * 0.5)
		x += cg.size.x + gap

func _count(gen: int, grp: CubeGroup, from_i: int, n: int, start_num: int, hue: int) -> bool:
	for k in n:
		var i := from_i + k
		grp.set_state(i, CubeGroup.HL.CURRENT, hue)
		var d := _say_number(start_num + k)
		if not await _wait(gen, maxf(CountBeat, d - 0.5)): return false
		grp.set_state(i, CubeGroup.HL.DONE, hue)
	return true

func _say_number(v: int) -> float:
	if v >= 0 and v < NUMBER_WORDS.size():
		return Narrator.speak(NUMBER_WORDS[v])
	return Narrator.speak(str(v))

func _on_input(event: InputEvent) -> void:
	var tap: bool = (event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventScreenTouch and event.pressed)
	if tap and not _skipping:
		_skip()

func _skip() -> void:
	_skipping = true
	_gen += 1
	Narrator.stop()
	_clear()
	match _op:
		"sub":
			_eq.text = "7  \u2212  4  =  3"
			var grp := _add_group(3, MathTheme.GOLD, 12)
			_center(grp, Vector2(640, 280))
			grp.set_all_state(CubeGroup.HL.DONE)
		"mul":
			_eq.text = "3  \u00D7  4  =  12"
			var groups: Array = []
			for gi in 3:
				var g2 := _add_group(4, MathTheme.GOLD, 4)
				g2.set_all_state(CubeGroup.HL.DONE)
				groups.append(g2)
			_row(groups, 280.0, 60.0)
		"div":
			_eq.text = "9  \u00F7  3  =  3"
			var groups2: Array = []
			for bi in 3:
				var g3 := _add_group(3, MathTheme.GOLD, 3)
				g3.set_all_state(CubeGroup.HL.DONE)
				groups2.append(g3)
			_row(groups2, 300.0, 80.0)
	_hint.text = "\u2713 done"
	finished.emit()

## Await a timer but bail out if a newer run (or skip) superseded us.
func _wait(gen: int, secs: float) -> bool:
	await get_tree().create_timer(secs).timeout
	return gen == _gen and is_inside_tree() and visible

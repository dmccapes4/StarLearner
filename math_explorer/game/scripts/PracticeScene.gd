class_name PracticeScene
extends Control
## Practice & repetition — procedurally generated equations with counting cubes.
## One round:
##   1. Cubes + equation with "?"; three answer buttons.
##   2. Right → gold flash + praise. Wrong → cubes re-count the answer slowly.
##   3. A gold **Practice ▶** button appears under the cubes for the next
##      problem — Back is the only way out of the practice tile.
##
## Numbers are unbounded (fresh every round), so dynamic narration uses the OS
## TTS fallback; the fixed praise/coaching lines are baked ElevenLabs clips
## (see VO_FIXED + tools/dump_vo_lines.gd).

signal finished()

const CountBeat := 0.55
const NUMBER_WORDS := ["zero", "one", "two", "three", "four", "five", "six",
	"seven", "eight", "nine", "ten", "eleven", "twelve"]

## Fixed lines (baked ElevenLabs). Dynamic equation text falls back to OS TTS.
const VO_FIXED := [
	"Great job!",
	"You got it!",
	"Not quite. Let's count it together.",
	"Watch closely.",
	"Here is the answer.",
	"Let's practice!",
]
const PRAISE := ["Great job!", "You got it!"]

## op id -> generator template
const TEMPLATES := {
	"add": "count_add", "sub": "take_sub", "mul": "groups_mul", "div": "share_div"}

var _op: String = "add"
var _p: Dictionary = {}
var _gen: int = 0
var _busy: bool = false
var _streak: int = 0

var _eq: Label
var _streak_lbl: Label
var _groups: Array = []      # CubeGroup nodes for this round
var _buttons: Array = []     # 3 answer Buttons
var _again: Button           # Practice ▶ under the cubes after each round
var _built := false

func start(op: String) -> void:
	_build()
	_op = op if TEMPLATES.has(op) else "add"
	_streak = 0
	_update_streak()
	visible = true
	_again.visible = false
	_gen += 1
	var gen := _gen
	# Let the opener finish — otherwise the equation speech cuts it off.
	var d := Narrator.speak("Let's practice!")
	if not await _wait(gen, maxf(1.8, d)):
		return
	_deal_round()

func _next_round() -> void:
	_gen += 1
	_again.visible = false
	_deal_round()

func _build() -> void:
	if _built:
		return
	_built = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	_eq = Label.new()
	_eq.add_theme_font_size_override("font_size", 64)
	_eq.add_theme_color_override("font_color", MathTheme.TEXT)
	_eq.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_eq.add_theme_constant_override("outline_size", 6)
	_eq.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_eq.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_eq.offset_top = 26
	_eq.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_eq)

	_streak_lbl = Label.new()
	_streak_lbl.add_theme_font_size_override("font_size", 26)
	_streak_lbl.add_theme_color_override("font_color", MathTheme.GOLD)
	_streak_lbl.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_streak_lbl.position = Vector2(-250, 22)
	_streak_lbl.size = Vector2(230, 34)
	_streak_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_streak_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_streak_lbl)

	for i in 3:
		var b := Button.new()
		b.custom_minimum_size = Vector2(180, 92)
		b.size = Vector2(180, 92)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 44)
		var idx := i
		b.pressed.connect(func() -> void: _on_answer(idx))
		add_child(b)
		_buttons.append(b)
	_layout_buttons()

	_again = Button.new()
	_again.text = "Practice  \u25B6"
	_again.custom_minimum_size = Vector2(340, 72)
	_again.size = Vector2(340, 72)
	_again.position = Vector2(640 - 170, 420)
	_again.focus_mode = Control.FOCUS_NONE
	_again.add_theme_font_size_override("font_size", 30)
	_again.visible = false
	_style_practice_btn(_again)
	_again.pressed.connect(_on_practice_again)
	add_child(_again)

func _layout_buttons() -> void:
	var w := 180.0
	var gap := 40.0
	var total := 3 * w + 2 * gap
	var x0 := 640.0 - total * 0.5
	for i in 3:
		(_buttons[i] as Button).position = Vector2(x0 + i * (w + gap), 478.0)

# ---- rounds ------------------------------------------------------------------

func _deal_round() -> void:
	_busy = false
	_again.visible = false
	_clear_groups()
	_p = MathProblemGen.generate(TEMPLATES[_op], -1)
	# Practice division stays exact — remainders belong to the tutorial, where
	# they are explained, not to a three-button quiz.
	while _op == "div" and int(_p["params"]["total"]) % int(_p["params"]["buckets"]) != 0:
		_p = MathProblemGen.generate(TEMPLATES[_op], -1)
	_show_problem()
	_show_answers()
	Narrator.speak(_equation_speech(false))

func _clear_groups() -> void:
	for g in _groups:
		g.queue_free()
	_groups.clear()

## The visible cube layout per operation. Returns after adding CubeGroups.
func _show_problem() -> void:
	var q: Dictionary = _p["params"]
	_eq.text = _equation_text(false)
	match _op:
		"add":
			var a := _add_group(int(q["a"]), MathTheme.RED)
			var b := _add_group(int(q["b"]), MathTheme.BLUE)
			_place_row([a, b], 300.0)
		"sub":
			var a := _add_group(int(q["a"]), MathTheme.RED)
			# The taken-away cubes are marked grey up front so "take away b" is visible.
			for i in range(int(q["a"]) - int(q["b"]), int(q["a"])):
				a.set_color(i, MathTheme.GREY)
			_place_row([a], 300.0)
		"mul":
			var groups: Array = []
			for g in int(q["g"]):
				groups.append(_add_group(int(q["n"]), MathTheme.GREEN))
			_place_row(groups, 300.0)
		"div":
			var t := _add_group(int(q["total"]), MathTheme.GOLD.lerp(MathTheme.GREEN, 0.4))
			_place_row([t], 280.0)

func _add_group(n: int, color: Color) -> CubeGroup:
	var g := CubeGroup.new()
	g.cell = 46.0
	g.gap = 8.0
	g.columns = 6
	g.setup(n, color)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(g)
	_groups.append(g)
	return g

func _place_row(groups: Array, cy: float) -> void:
	var gap := 70.0
	var total := 0.0
	for g in groups:
		total += (g as CubeGroup).size.x
	total += gap * float(groups.size() - 1)
	var x := 640.0 - total * 0.5
	for g in groups:
		var cg := g as CubeGroup
		cg.position = Vector2(x, cy - cg.size.y * 0.5)
		x += cg.size.x + gap

func _show_answers() -> void:
	var answer: int = _p["answer"]
	var opts := [answer]
	while opts.size() < 3:
		var d: int = answer + [-3, -2, -1, 1, 2, 3][randi() % 6]
		if d >= 0 and not opts.has(d):
			opts.append(d)
	opts.shuffle()
	for i in 3:
		var b := _buttons[i] as Button
		b.text = str(opts[i])
		b.visible = true
		b.disabled = false
		_style_answer(b, false)

# ---- answering ---------------------------------------------------------------

func _on_answer(idx: int) -> void:
	if _busy or not visible:
		return
	var b := _buttons[idx] as Button
	var picked := int(b.text)
	var answer: int = _p["answer"]
	_busy = true
	for btn in _buttons:
		(btn as Button).disabled = true
	if picked == answer:
		_streak += 1
		_update_streak()
		Save.record_practice_answer(_op, true, _streak)
		_style_answer(b, true)
		_celebrate()
	else:
		Save.record_practice_answer(_op, false, _streak)
		_streak = 0
		_update_streak()
		_explain(_gen)

func _celebrate() -> void:
	var gen := _gen
	_eq.text = _equation_text(true)
	for g in _groups:
		(g as CubeGroup).set_all_color(MathTheme.GOLD)
		(g as CubeGroup).set_all_state(CubeGroup.HL.DONE)
	Narrator.speak(PRAISE[randi() % PRAISE.size()])
	if not await _wait(gen, 1.8): return
	_show_practice_again()

## Wrong answer → the cubes SHOW the truth, slowly, with the count spoken.
func _explain(gen: int) -> void:
	Narrator.speak("Not quite. Let's count it together.")
	if not await _wait(gen, 2.0): return
	var q: Dictionary = _p["params"]
	match _op:
		"add":
			# Count straight across both groups — count-on made visible.
			var n := 0
			for g in _groups:
				var cg := g as CubeGroup
				for i in cg.count():
					n += 1
					cg.set_state(i, CubeGroup.HL.CURRENT, CubeGroup.HUE.GOLD)
					var d := _say_number(n)
					# Pace by the spoken length so each number is never cut off
					# mid-word by the next one.
					if not await _wait(gen, maxf(CountBeat, d - 0.3)): return
					cg.set_state(i, CubeGroup.HL.DONE, CubeGroup.HUE.GOLD)
		"sub":
			# Grey cubes leave one by one, then count what's left.
			var a := _groups[0] as CubeGroup
			var total := int(q["a"])
			var take := int(q["b"])
			for i in range(total - 1, total - take - 1, -1):
				a.set_color(i, Color(MathTheme.GREY, 0.15))
				if not await _wait(gen, 0.35): return
			var n2 := 0
			for i in range(0, total - take):
				n2 += 1
				a.set_state(i, CubeGroup.HL.CURRENT, CubeGroup.HUE.GOLD)
				var d := _say_number(n2)
				if not await _wait(gen, maxf(CountBeat, d - 0.3)): return
				a.set_state(i, CubeGroup.HL.DONE, CubeGroup.HUE.GOLD)
		"mul":
			# Count group by group so "g groups of n" is felt.
			var n3 := 0
			for g in _groups:
				var cg := g as CubeGroup
				for i in cg.count():
					n3 += 1
					cg.set_state(i, CubeGroup.HL.CURRENT, CubeGroup.HUE.GOLD)
					var say := n3 % maxi(1, int(q["n"])) == 0 or n3 == 1
					if say:
						var d := _say_number(n3)
						if not await _wait(gen, maxf(CountBeat, d - 0.3)): return
					else:
						if not await _wait(gen, CountBeat * 0.6): return
					cg.set_state(i, CubeGroup.HL.DONE, CubeGroup.HUE.GOLD)
		"div":
			# Deal into buckets: recolour cube i by which bucket it lands in.
			var t := _groups[0] as CubeGroup
			var buckets := int(q["buckets"])
			var colors := [MathTheme.RED, MathTheme.BLUE, MathTheme.GREEN, MathTheme.GOLD]
			for i in t.count():
				t.set_color(i, colors[i % buckets])
				t.set_state(i, CubeGroup.HL.CURRENT, CubeGroup.HUE.GOLD)
				if not await _wait(gen, 0.3): return
				t.set_state(i, CubeGroup.HL.DONE, CubeGroup.HUE.GOLD)
	Narrator.speak("Here is the answer.")
	_eq.text = _equation_text(true)
	Narrator.speak(_equation_speech(true))
	if not await _wait(gen, 2.6): return
	_show_practice_again()

## Hide the three answers; offer Practice ▶ under the cubes for another go.
func _show_practice_again() -> void:
	for b in _buttons:
		(b as Button).visible = false
	_again.visible = true
	_busy = false

func _on_practice_again() -> void:
	if not visible or _again.visible == false:
		return
	_again.visible = false
	_next_round()

# ---- text --------------------------------------------------------------------

func _equation_text(with_answer: bool) -> String:
	var q: Dictionary = _p["params"]
	var ans := str(_p["answer"]) if with_answer else "?"
	match _op:
		"add": return "%d  +  %d  =  %s" % [q["a"], q["b"], ans]
		"sub": return "%d  \u2212  %d  =  %s" % [q["a"], q["b"], ans]
		"mul": return "%d  \u00D7  %d  =  %s" % [q["g"], q["n"], ans]
		"div": return "%d  \u00F7  %d  =  %s" % [q["total"], q["buckets"], ans]
	return ""

func _equation_speech(with_answer: bool) -> String:
	var q: Dictionary = _p["params"]
	var ans: int = _p["answer"]
	match _op:
		"add":
			return "%d plus %d equals %d." % [q["a"], q["b"], ans] if with_answer \
				else "What is %d plus %d?" % [q["a"], q["b"]]
		"sub":
			return "%d take away %d equals %d." % [q["a"], q["b"], ans] if with_answer \
				else "What is %d take away %d?" % [q["a"], q["b"]]
		"mul":
			return "%d groups of %d makes %d." % [q["g"], q["n"], ans] if with_answer \
				else "What is %d groups of %d?" % [q["g"], q["n"]]
		"div":
			return "%d shared into %d buckets is %d each." % [q["total"], q["buckets"], ans] if with_answer \
				else "Share %d cubes into %d buckets. How many in each?" % [q["total"], q["buckets"]]
	return ""

# ---- helpers -----------------------------------------------------------------

## Speak a count as a word ("one".."twelve") so it matches the baked tutorial
## clips; larger counts fall back to the digit (OS TTS). Returns the spoken
## duration so the caller can pace the count and never clip a number mid-word.
func _say_number(v: int) -> float:
	if v >= 0 and v < NUMBER_WORDS.size():
		return Narrator.speak(NUMBER_WORDS[v])
	return Narrator.speak(str(v))

func _update_streak() -> void:
	if _streak <= 0:
		_streak_lbl.text = ""
	else:
		_streak_lbl.text = "\u2605".repeat(mini(_streak, 8)) + (" %d" % _streak if _streak > 8 else "")

func _style_answer(b: Button, correct: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = MathTheme.GOLD if correct else MathTheme.PANEL
	sb.set_corner_radius_all(22)
	sb.set_border_width_all(3)
	sb.border_color = Color(1, 1, 1, 0.9) if correct else Color(1, 1, 1, 0.3)
	var fg := Color(0.06, 0.06, 0.12) if correct else MathTheme.TEXT
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", fg)
	b.add_theme_color_override("font_pressed_color", fg)
	b.add_theme_color_override("font_disabled_color", fg)
	for state in ["normal", "hover", "focus", "pressed", "disabled"]:
		b.add_theme_stylebox_override(state, sb)

func _style_practice_btn(b: Button) -> void:
	b.add_theme_color_override("font_color", Color(0.06, 0.06, 0.12))
	b.add_theme_color_override("font_hover_color", Color(0.06, 0.06, 0.12))
	b.add_theme_color_override("font_pressed_color", Color(0.06, 0.06, 0.12))
	var sb := StyleBoxFlat.new()
	sb.bg_color = MathTheme.GOLD
	sb.set_corner_radius_all(22)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 6
	var pressed := sb.duplicate() as StyleBoxFlat
	pressed.bg_color = MathTheme.GOLD.darkened(0.12)
	for state in ["normal", "hover", "focus"]:
		b.add_theme_stylebox_override(state, sb)
	b.add_theme_stylebox_override("pressed", pressed)

## Await a timer but bail out if a newer round (or exit) superseded us.
func _wait(gen: int, secs: float) -> bool:
	await get_tree().create_timer(secs).timeout
	return gen == _gen and is_inside_tree() and visible

func stop() -> void:
	_gen += 1
	_busy = false

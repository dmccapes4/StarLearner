class_name PracticeScene
extends Control
## Practice & repetition — procedurally generated equations with counting cubes.
## Tap a square group to count it (gold outline). Operations:
##   add  — tap left, then right (count-on); tap again recounts left→right
##   sub  — first tap counts all squares L→R; second tap counts take-away R→L;
##          − and = appear like addition
##   mul  — vertical coloured columns; tap a column to skip-count by its size
##          into a centred product pile (2, 4, 6… — never square-by-square)
##   div  — tap the pile to deal cubes into coloured buckets
## Answer still via the three number buttons.

signal finished()

const CountBeat := 0.55
const NUMBER_WORDS := ["zero", "one", "two", "three", "four", "five", "six",
	"seven", "eight", "nine", "ten", "eleven", "twelve"]
const GROUP_COLORS := [
	Color(0.90, 0.30, 0.28), Color(0.30, 0.55, 0.95),
	Color(0.36, 0.78, 0.45), Color(1.00, 0.72, 0.28),
	Color(0.75, 0.40, 0.90), Color(0.20, 0.78, 0.78),
]

const VO_FIXED := [
	"Great job!",
	"You got it!",
	"Not quite. Let's count it together.",
	"Watch closely.",
	"Here is the answer.",
	"Let's practice!",
	"Practice again!",
]
const PRAISE := ["Great job!", "You got it!"]

const TEMPLATES := {
	"add": "count_add", "sub": "take_sub", "mul": "groups_mul", "div": "share_div"}

var _op: String = "add"
var _p: Dictionary = {}
var _gen: int = 0
var _busy: bool = false
var _streak: int = 0
var _count_busy: bool = false

var _eq: Label
var _streak_lbl: Label
var _groups: Array = []          # CubeGroup nodes
var _group_labels: Array = []    # Label under each group
var _op_labels: Array = []       # "+" / "=" spacers between groups
var _pile: CubeGroup = null      # mul growing pile
var _pile_lbl: Label = null
var _mul_added: Dictionary = {}  # group index → already added to pile
var _mul_order: Array = []       # group indices in the order they joined the pile
var _add_progress: int = 0       # 0 = none, 1 = left counted, 2 = both
var _buttons: Array = []
var _again: Button
var _built := false

func start(op: String) -> void:
	_build()
	# Clear previous round IMMEDIATELY so a different op never flashes old cubes.
	_clear_board()
	_op = op if TEMPLATES.has(op) else "add"
	_streak = 0
	_update_streak()
	visible = true
	_again.visible = false
	_gen += 1
	var gen := _gen
	var d := Narrator.speak("Let's practice!")
	if not await _wait(gen, maxf(1.8, d)):
		return
	_deal_round()

func stop() -> void:
	_gen += 1
	_busy = false
	_count_busy = false
	_clear_board()

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
	_again.focus_mode = Control.FOCUS_NONE
	ChromeIcons.apply_icon_button(_again, "practice", 112.0)
	_again.position = Vector2(640 - 56, 400)
	_again.visible = false
	_again.pressed.connect(_on_practice_again)
	add_child(_again)

func _layout_buttons() -> void:
	var w := 180.0
	var gap := 40.0
	var total := 3 * w + 2 * gap
	var x0 := 640.0 - total * 0.5
	for i in 3:
		(_buttons[i] as Button).position = Vector2(x0 + i * (w + gap), 478.0)

func _deal_round() -> void:
	_busy = false
	_count_busy = false
	_again.visible = false
	_clear_board()
	_p = MathProblemGen.generate(TEMPLATES[_op], -1)
	while _op == "div" and int(_p["params"]["total"]) % int(_p["params"]["buckets"]) != 0:
		_p = MathProblemGen.generate(TEMPLATES[_op], -1)
	_show_problem()
	_show_answers()
	Narrator.speak(_equation_speech(false))

func _clear_board() -> void:
	_clear_groups()
	for l in _group_labels:
		if is_instance_valid(l):
			l.queue_free()
	_group_labels.clear()
	for l in _op_labels:
		if is_instance_valid(l):
			l.queue_free()
	_op_labels.clear()
	if _pile != null and is_instance_valid(_pile):
		_pile.queue_free()
	_pile = null
	if _pile_lbl != null and is_instance_valid(_pile_lbl):
		_pile_lbl.queue_free()
	_pile_lbl = null
	_mul_added.clear()
	_mul_order.clear()
	_add_progress = 0
	if _eq != null:
		_eq.text = ""
	for b in _buttons:
		if is_instance_valid(b):
			(b as Button).visible = false

func _clear_groups() -> void:
	for g in _groups:
		if is_instance_valid(g):
			g.queue_free()
	_groups.clear()

func _show_problem() -> void:
	var q: Dictionary = _p["params"]
	_eq.text = _equation_text(false)
	match _op:
		"add":
			# Start with groups only; + / = fill in as she counts.
			_eq.text = "?"
			var a := _add_group(int(q["a"]), MathTheme.RED, 0)
			var plus := _spacer_label("+")
			var b := _add_group(int(q["b"]), MathTheme.BLUE, 1)
			var eq := _spacer_label("=")
			_place_row_with_ops([a, plus, b, eq], 280.0)
			_add_group_label(a, "")
			_add_group_label(b, "")
			plus.modulate.a = 0.25
			eq.modulate.a = 0.25
		"sub":
			# One row of `a` cubes (all red). First tap counts the total L→R;
			# second tap counts the take-away `b` cubes R→L. − / = fade in like +.
			_eq.text = "?"
			var a := _add_group(int(q["a"]), MathTheme.RED, 0)
			var minus := _spacer_label("\u2212")
			var eq := _spacer_label("=")
			_place_row_with_ops([a, minus, eq], 280.0)
			_add_group_label(a, "")
			# Label for the take-away count, parked under the minus.
			var bl := _make_count_label()
			bl.text = ""
			add_child(bl)
			_group_labels.append(bl)
			bl.position = Vector2(
				minus.position.x + minus.size.x * 0.5 - 40.0,
				a.position.y + a.size.y + 8.0)
			minus.modulate.a = 0.25
			eq.modulate.a = 0.25
		"mul":
			# Vertical columns of `n` (one colour each). Tap a column to
			# skip-count by `n` into a product pile — no square-by-square count,
			# no gold outlines. Layout stacks sources above the pile when there
			# is room; otherwise sources left / pile right so nothing clips the
			# answer buttons.
			_eq.text = _equation_text(false)
			var n_each := int(q["n"])
			var groups: Array = []
			for gi in int(q["g"]):
				var col: Color = GROUP_COLORS[gi % GROUP_COLORS.size()]
				groups.append(_add_mul_column(n_each, col, gi))
			_pile = CubeGroup.new()
			_pile.cell = 36.0
			_pile.gap = 5.0
			_pile.columns = 1
			_pile.setup(0, MathTheme.GOLD)
			_pile.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_pile.visible = false
			add_child(_pile)
			_pile_lbl = _make_count_label()
			_pile_lbl.text = ""
			_pile_lbl.visible = false
			add_child(_pile_lbl)
			_layout_mul(groups)
		"div":
			var t := _add_group(int(q["total"]), MathTheme.GOLD.lerp(MathTheme.GREEN, 0.4), 0)
			_place_row([t], 280.0)
			_add_group_label(t, "")

func _add_group(n: int, color: Color, idx: int) -> CubeGroup:
	var g := CubeGroup.new()
	g.cell = 46.0
	g.gap = 8.0
	g.columns = 6
	g.setup(n, color)
	g.mouse_filter = Control.MOUSE_FILTER_STOP
	g.gui_input.connect(func(ev: InputEvent) -> void: _on_group_input(idx, ev))
	add_child(g)
	_groups.append(g)
	return g

## One vertical column of `n` cubes — the visual unit of a multiplication group.
func _add_mul_column(n: int, color: Color, idx: int) -> CubeGroup:
	var g := CubeGroup.new()
	g.cell = 36.0
	g.gap = 5.0
	g.columns = 1
	g.setup(n, color)
	g.mouse_filter = Control.MOUSE_FILTER_STOP
	g.gui_input.connect(func(ev: InputEvent) -> void: _on_group_input(idx, ev))
	add_child(g)
	_groups.append(g)
	return g

## Place source columns. Prefer sources-above / pile-below when height fits the
## band above the answer buttons; otherwise sources-left / pile-right.
func _layout_mul(groups: Array) -> void:
	var gap := 28.0
	var total_w := 0.0
	var col_h := 0.0
	for g in groups:
		var cg := g as CubeGroup
		total_w += cg.size.x
		col_h = maxf(col_h, cg.size.y)
	total_w += gap * float(maxi(0, groups.size() - 1))
	# Answer buttons sit at y≈478; keep a label + margin above them.
	var band_bottom := 455.0
	var band_top := 130.0
	var stack_need := col_h + 28.0 + col_h + 36.0  # sources + gap + pile + label
	var stacked := (band_top + stack_need) <= band_bottom
	if stacked:
		var x := 640.0 - total_w * 0.5
		for g in groups:
			var cg := g as CubeGroup
			cg.position = Vector2(x, band_top)
			x += cg.size.x + gap
		# Pile slot reserved below; _center_pile fills it when cubes arrive.
		_pile.set_meta("mul_mode", "stack")
		_pile.set_meta("mul_top", band_top + col_h + 28.0)
	else:
		# Side-by-side: sources on the left half, pile on the right half.
		var left_x := 640.0 - total_w - 40.0
		if left_x < 40.0:
			left_x = 40.0
		var mid_y := (band_top + band_bottom) * 0.5
		var x := left_x
		for g in groups:
			var cg := g as CubeGroup
			cg.position = Vector2(x, mid_y - cg.size.y * 0.5)
			x += cg.size.x + gap
		_pile.set_meta("mul_mode", "side")
		_pile.set_meta("mul_left", x + 48.0)
		_pile.set_meta("mul_mid_y", mid_y)

## Keep the product pile centred in its reserved slot (below or beside sources).
func _center_pile() -> void:
	if _pile == null or not is_instance_valid(_pile):
		return
	_pile.visible = true
	var mode := str(_pile.get_meta("mul_mode", "stack"))
	if mode == "side":
		var left: float = float(_pile.get_meta("mul_left", 700.0))
		var mid_y: float = float(_pile.get_meta("mul_mid_y", 280.0))
		# Centre the pile in the remaining right half.
		var right_center := (left + 1240.0) * 0.5
		_pile.position = Vector2(right_center - _pile.size.x * 0.5, mid_y - _pile.size.y * 0.5)
		# Nudge left if it would clip the right edge.
		if _pile.position.x + _pile.size.x > 1240.0:
			_pile.position.x = 1240.0 - _pile.size.x
		if _pile.position.x < left:
			_pile.position.x = left
	else:
		var top: float = float(_pile.get_meta("mul_top", 360.0))
		_pile.position = Vector2(640.0 - _pile.size.x * 0.5, top)
	if _pile_lbl != null and is_instance_valid(_pile_lbl):
		_pile_lbl.visible = true
		_pile_lbl.position = Vector2(
			_pile.position.x + _pile.size.x * 0.5 - 40.0,
			_pile.position.y + _pile.size.y + 8.0)

func _spacer_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 56)
	l.add_theme_color_override("font_color", MathTheme.GOLD)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.custom_minimum_size = Vector2(48, 56)
	l.size = Vector2(48, 56)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(l)
	_op_labels.append(l)
	return l

func _make_count_label() -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", 32)
	l.add_theme_color_override("font_color", MathTheme.GOLD)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 4)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.size = Vector2(80, 36)
	return l

func _add_group_label(g: CubeGroup, text: String) -> void:
	var l := _make_count_label()
	l.text = text
	add_child(l)
	_group_labels.append(l)
	_position_group_label(g, l)

func _position_group_label(g: CubeGroup, l: Label) -> void:
	l.position = Vector2(g.position.x + g.size.x * 0.5 - 40, g.position.y + g.size.y + 8)

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

func _place_row_with_ops(items: Array, cy: float) -> void:
	var gap := 28.0
	var total := 0.0
	for it in items:
		if it is CubeGroup:
			total += (it as CubeGroup).size.x
		else:
			total += (it as Control).size.x
	total += gap * float(items.size() - 1)
	var x := 640.0 - total * 0.5
	for it in items:
		if it is CubeGroup:
			var cg := it as CubeGroup
			cg.position = Vector2(x, cy - cg.size.y * 0.5)
			x += cg.size.x + gap
		else:
			var c := it as Control
			c.position = Vector2(x, cy - c.size.y * 0.5)
			x += c.size.x + gap

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

# ---- tap-to-count ------------------------------------------------------------

func _on_group_input(idx: int, event: InputEvent) -> void:
	var tap := false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tap = true
	elif event is InputEventScreenTouch and event.pressed:
		tap = true
	if not tap or _busy or _count_busy or not visible:
		return
	_tap_group(idx)

func _tap_group(idx: int) -> void:
	_count_busy = true
	var gen := _gen
	match _op:
		"add":
			await _tap_add(idx, gen)
		"sub":
			await _tap_sub(gen)
		"mul":
			await _tap_mul(idx, gen)
		"div":
			await _tap_div(gen)
	if gen == _gen:
		_count_busy = false

func _tap_add(idx: int, gen: int) -> void:
	var q: Dictionary = _p["params"]
	# Tap either group after both counted → full recount left→right.
	if _add_progress >= 2:
		_add_progress = 0
		for l in _group_labels:
			(l as Label).text = ""
		for l in _op_labels:
			(l as Label).modulate.a = 0.25
		_eq.text = "?"
		await _count_group_from(0, 0, gen)
		if gen != _gen: return
		if _group_labels.size() > 0:
			(_group_labels[0] as Label).text = str(q["a"])
		if _op_labels.size() > 0:
			(_op_labels[0] as Label).modulate.a = 1.0
		await _count_group_from(1, int(q["a"]), gen)
		if gen != _gen: return
		if _group_labels.size() > 1:
			(_group_labels[1] as Label).text = str(q["b"])
		if _op_labels.size() > 1:
			(_op_labels[1] as Label).modulate.a = 1.0
		_eq.text = "%d  +  %d  =  ?" % [q["a"], q["b"]]
		_add_progress = 2
		return
	if idx == 0:
		# Count left group from 1.
		for i in (_groups[0] as CubeGroup).count():
			(_groups[0] as CubeGroup).set_state(i, CubeGroup.HL.NONE)
		await _count_group_from(0, 0, gen)
		if gen != _gen: return
		(_group_labels[0] as Label).text = str(q["a"])
		if _op_labels.size() > 0:
			(_op_labels[0] as Label).modulate.a = 1.0
		_eq.text = "%d  +  ?" % q["a"]
		_add_progress = maxi(_add_progress, 1)
	else:
		# Count right group continuing from left total (or from 0 if left unread).
		var start := int(q["a"]) if _add_progress >= 1 else 0
		if _add_progress < 1:
			# She tapped right first — still count just that group as 1..b.
			await _count_group_from(1, 0, gen)
			if gen != _gen: return
			(_group_labels[1] as Label).text = str(q["b"])
		else:
			await _count_group_from(1, start, gen)
			if gen != _gen: return
			(_group_labels[1] as Label).text = str(q["b"])
			if _op_labels.size() > 1:
				(_op_labels[1] as Label).modulate.a = 1.0
			_eq.text = "%d  +  %d  =  ?" % [q["a"], q["b"]]
			_add_progress = 2

func _count_group_from(gidx: int, start: int, gen: int) -> void:
	if gidx >= _groups.size():
		return
	var cg := _groups[gidx] as CubeGroup
	var n := start
	for i in cg.count():
		n += 1
		cg.set_state(i, CubeGroup.HL.CURRENT, CubeGroup.HUE.GOLD)
		var d := _say_number(n)
		if not await _wait(gen, maxf(CountBeat, d - 0.3)): return
		cg.set_state(i, CubeGroup.HL.DONE, CubeGroup.HUE.GOLD)
	# Return to normal (no outline) after the count finishes.
	cg.set_all_state(CubeGroup.HL.NONE)

func _tap_sub(gen: int) -> void:
	var q: Dictionary = _p["params"]
	var total := int(q["a"])
	var take := int(q["b"])
	var cg := _groups[0] as CubeGroup

	# After both phases, a further tap restarts the full count (like addition).
	if _add_progress >= 2:
		_add_progress = 0
		for l in _group_labels:
			(l as Label).text = ""
		for l in _op_labels:
			(l as Label).modulate.a = 0.25
		_eq.text = "?"
		cg.set_all_color(MathTheme.RED)
		cg.set_all_state(CubeGroup.HL.NONE)

	if _add_progress == 0:
		# First tap: count every square left→right.
		await _count_group_from(0, 0, gen)
		if gen != _gen:
			return
		if _group_labels.size() > 0:
			(_group_labels[0] as Label).text = str(total)
		if _op_labels.size() > 0:
			(_op_labels[0] as Label).modulate.a = 1.0
		_eq.text = "%d  \u2212  ?" % total
		_add_progress = 1
		return

	# Second tap: count the take-away squares right→left.
	var n := 0
	for i in range(total - 1, total - take - 1, -1):
		n += 1
		cg.set_state(i, CubeGroup.HL.CURRENT, CubeGroup.HUE.GOLD)
		var d := _say_number(n)
		if not await _wait(gen, maxf(CountBeat, d - 0.3)):
			return
		cg.set_state(i, CubeGroup.HL.DONE, CubeGroup.HUE.GOLD)
		cg.set_color(i, MathTheme.GREY)
	cg.set_all_state(CubeGroup.HL.NONE)
	# Keep take-away cubes grey so "take away b" stays visible.
	for i in range(total - take, total):
		cg.set_color(i, MathTheme.GREY)
	if _group_labels.size() > 1:
		(_group_labels[1] as Label).text = str(take)
	if _op_labels.size() > 1:
		(_op_labels[1] as Label).modulate.a = 1.0
	_eq.text = "%d  \u2212  %d  =  ?" % [total, take]
	_add_progress = 2


func _tap_mul(idx: int, gen: int) -> void:
	var q: Dictionary = _p["params"]
	var n_each := int(q["n"])
	if _mul_added.get(idx, false):
		# Already in the pile — just re-speak the running total.
		var cur := _pile.count() if _pile else 0
		var d := _say_number(cur)
		await _wait(gen, maxf(CountBeat, d))
		return
	var src := _groups[idx] as CubeGroup
	# Soft pulse on the column (no gold outlines, no square-by-square count).
	var tw := create_tween()
	tw.tween_property(src, "scale", Vector2(1.1, 1.1), 0.1)
	tw.tween_property(src, "scale", Vector2.ONE, 0.12)
	await tw.finished
	if gen != _gen:
		return
	src.modulate = Color(1, 1, 1, 0.32)
	_mul_added[idx] = true
	_mul_order.append(idx)
	_rebuild_mul_pile()
	var total_now := _mul_order.size() * n_each
	# Skip-count by group size only: 2, 4, 6… / 3, 6, 9… / 4, 8, 12…
	var d2 := _say_number(total_now)
	if _pile_lbl:
		_pile_lbl.text = str(total_now)
	if not await _wait(gen, maxf(0.75, d2)):
		return

## Rebuild the product pile as an array: each tapped group becomes one column
## of `n` cubes, coloured to match its source. Pile stays centred as it grows.
func _rebuild_mul_pile() -> void:
	if _pile == null:
		return
	var n_each := int(_p["params"]["n"])
	var g_added := _mul_order.size()
	if g_added <= 0:
		_pile.setup(0, MathTheme.GOLD)
		_pile.visible = false
		if _pile_lbl:
			_pile_lbl.visible = false
		return
	_pile.columns = g_added
	_pile.setup(g_added * n_each, MathTheme.GOLD)
	# Row-major fill with `columns = g_added` makes each column a vertical group.
	for i in g_added * n_each:
		var col_idx: int = i % g_added
		var gi: int = int(_mul_order[col_idx])
		_pile.set_color(i, GROUP_COLORS[gi % GROUP_COLORS.size()])
	_center_pile()

func _tap_div(gen: int) -> void:
	var q: Dictionary = _p["params"]
	var t := _groups[0] as CubeGroup
	var buckets := int(q["buckets"])
	var colors := [MathTheme.RED, MathTheme.BLUE, MathTheme.GREEN, MathTheme.GOLD,
		Color(0.75, 0.40, 0.90), Color(0.20, 0.78, 0.78)]
	for i in t.count():
		var bucket := i % buckets
		t.set_color(i, colors[bucket % colors.size()])
		t.set_state(i, CubeGroup.HL.CURRENT, CubeGroup.HUE.GOLD)
		if not await _wait(gen, 0.28): return
		t.set_state(i, CubeGroup.HL.DONE, CubeGroup.HUE.GOLD)
	t.set_all_state(CubeGroup.HL.NONE)
	var each := int(q["total"]) / buckets
	if _group_labels.size() > 0:
		(_group_labels[0] as Label).text = str(each)

# ---- answering ---------------------------------------------------------------

func _on_answer(idx: int) -> void:
	if _busy or _count_busy or not visible:
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

func _explain(gen: int) -> void:
	Narrator.speak("Not quite. Let's count it together.")
	if not await _wait(gen, 2.0): return
	var q: Dictionary = _p["params"]
	match _op:
		"add":
			_add_progress = 0
			await _count_group_from(0, 0, gen)
			if gen != _gen: return
			await _count_group_from(1, int(q["a"]), gen)
		"sub":
			# Walk both phases: total L→R, then take-away R→L.
			_add_progress = 0
			var cg0 := _groups[0] as CubeGroup
			cg0.set_all_color(MathTheme.RED)
			cg0.set_all_state(CubeGroup.HL.NONE)
			for l in _group_labels:
				(l as Label).text = ""
			for l in _op_labels:
				(l as Label).modulate.a = 0.25
			_eq.text = "?"
			await _tap_sub(gen)
			if gen != _gen: return
			await _tap_sub(gen)
		"mul":
			# Chunk skip-count through every group into the pile (no per-square).
			_mul_added.clear()
			_mul_order.clear()
			for g in _groups:
				(g as CubeGroup).modulate = Color.WHITE
				(g as CubeGroup).set_all_state(CubeGroup.HL.NONE)
			if _pile:
				_pile.setup(0, MathTheme.GOLD)
				_pile.visible = false
			if _pile_lbl:
				_pile_lbl.text = ""
				_pile_lbl.visible = false
			for gi in _groups.size():
				await _tap_mul(gi, gen)
				if gen != _gen: return
		"div":
			await _tap_div(gen)
	if gen != _gen: return
	Narrator.speak("Here is the answer.")
	_eq.text = _equation_text(true)
	Narrator.speak(_equation_speech(true))
	if not await _wait(gen, 2.6): return
	_show_practice_again()

func _show_practice_again() -> void:
	for b in _buttons:
		(b as Button).visible = false
	_again.visible = true
	_busy = false
	_count_busy = false
	# Mention the practice tile with a gold outline so she knows what to tap.
	ChromeIcons.set_tour_outline(_again, true)
	Narrator.speak("Practice again!")
	await get_tree().create_timer(1.6).timeout
	if is_inside_tree() and _again.visible:
		ChromeIcons.set_tour_outline(_again, false)

func _on_practice_again() -> void:
	if not visible or _again.visible == false:
		return
	_again.visible = false
	_next_round()

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

func _wait(gen: int, secs: float) -> bool:
	await get_tree().create_timer(secs).timeout
	return gen == _gen and is_inside_tree() and visible

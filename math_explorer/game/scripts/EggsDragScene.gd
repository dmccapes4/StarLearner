class_name EggsDragScene
extends Control
## Interactive chickens & eggs.
##   Phase 1 LAY: tap a hen to lay an egg into its hatch bed. When a hatch is
##            full, eggs are counted (gold outline + grow), then the hatch locks
##            gold. When every hatch is locked, hatch counts are added aloud
##            (1, 2, 3, 5, 7…) before packing.
##   Phase 2 PACK: tap/drag eggs into 6-egg cartons (fill sprites + snap shut).
##   Then the worked equations appear, narrated.

signal finished()

enum Phase { LAY, PACK, COUNTING, DONE }

const EGG := 34.0
const CARTON := 6
const CARTON_W := 150.0
const HATCH_SIZE := 108.0
const SELECT_SCALE := 1.34
const DRAG_THRESHOLD := 12.0
const NUMBER_WORDS := ["zero", "one", "two", "three", "four", "five", "six",
	"seven", "eight", "nine", "ten", "eleven", "twelve", "thirteen", "fourteen",
	"fifteen", "sixteen", "seventeen", "eighteen", "nineteen", "twenty"]

const SEED_POOL: Array = [0, 4, 9, 17, 26, 38, 49, 61, 77, 90]

var _p: Dictionary = {}
var _phase: int = Phase.LAY
var _eggs: Array = []        # TextureRect (pack phase / loose eggs)
var _zones: Array = []       # cartons in pack phase
var _hatches: Array = []     # {chicken, bed, eggs, cap, count, complete, slots, rect_chick, rect_bed}
var _dragging: TextureRect = null
var _drag_off: Vector2 = Vector2.ZERO
var _selected: TextureRect = null
var _sel_ring: Panel = null
var _drag_start: Vector2 = Vector2.ZERO
var _moved: bool = false
var _busy: bool = false      # counting / summing — ignore taps
var _gen: int = 0
var _instr: Label
var _eq0: Label
var _eq1: Label
var _eq2: Label
var _hint: Label
var _built := false

func start(seed: int = -1) -> void:
	_build()
	var s: int = seed if seed >= 0 else int(SEED_POOL[randi() % SEED_POOL.size()])
	_p = _pick(s)
	_gen += 1
	_reset()
	visible = true
	_start_lay()

func _build() -> void:
	if _built:
		return
	_built = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)
	_instr = _wide_label(26, MathTheme.GOLD, 16)
	_eq0 = _wide_label(26, MathTheme.TEXT, 54)
	_eq1 = _wide_label(26, MathTheme.TEXT, 90)
	_eq2 = _wide_label(30, MathTheme.GOLD, 126)
	for l in [_instr, _eq0, _eq1, _eq2]:
		add_child(l)
	_hint = _label(18, Color(1, 1, 1, 0.7))
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_hint.position = Vector2(-280, -34)
	_hint.size = Vector2(190, 26)
	add_child(_hint)

	_sel_ring = Panel.new()
	_sel_ring.visible = false
	_sel_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ring := StyleBoxFlat.new()
	ring.bg_color = Color(1, 1, 1, 0)
	ring.set_corner_radius_all(12)
	ring.set_border_width_all(5)
	ring.border_color = MathTheme.GOLD
	_sel_ring.add_theme_stylebox_override("panel", ring)
	add_child(_sel_ring)

func _reset() -> void:
	_busy = false
	for e in _eggs:
		e.queue_free()
	for z in _zones:
		z["node"].queue_free()
	for h in _hatches:
		if is_instance_valid(h["chicken"]):
			h["chicken"].queue_free()
		if is_instance_valid(h["bed"]):
			h["bed"].queue_free()
		for e in h["eggs"]:
			if is_instance_valid(e):
				e.queue_free()
		if h.has("ring") and is_instance_valid(h["ring"]):
			h["ring"].queue_free()
	_eggs.clear()
	_zones.clear()
	_hatches.clear()
	_dragging = null
	_deselect()
	_eq0.text = ""
	_eq1.text = ""
	_eq2.text = ""
	_hint.text = ""

static func _pick(seed: int) -> Dictionary:
	for s in range(maxi(0, seed), maxi(0, seed) + 400):
		var p := MathProblemGen.generate("eggs_rate", s)
		var q: Dictionary = p["params"]
		var chickens: int = int(q["white"]) + int(q["yellow"])
		var total: int = int(p["answer"])
		if chickens >= 2 and chickens <= 6 and int(q["days"]) <= 3 \
				and total >= 6 and total <= 24 and int(q["w_eggs"]) != int(q["y_eggs"]):
			return p
	return MathProblemGen.generate("eggs_rate", 0)

static func vo_lines(seed: int) -> Array:
	var p := _pick(seed)
	var q: Dictionary = p["params"]
	var total: int = p["answer"]
	var per_day := int(q["white"]) * int(q["w_eggs"]) + int(q["yellow"]) * int(q["y_eggs"])
	var lines: Array = [
		"Tap a chicken to lay an egg. White hens lay %d, yellow hens lay %d." % [q["w_eggs"], q["y_eggs"]],
		"Bawk!",
		"That hatch is full!",
		"Great! Over %d days that is %d eggs. Now fill the cartons. Each holds %d." % [q["days"], total, CARTON],
		_result_line(total),
	]
	# Hatch-sum counts for this seed (running totals spoken after all hatches lock).
	var caps: Array = []
	for _i in int(q["white"]):
		caps.append(int(q["w_eggs"]))
	for _j in int(q["yellow"]):
		caps.append(int(q["y_eggs"]))
	var running := 0
	for c in caps:
		running += int(c)
		lines.append(_number_word(running))
	lines.append("That is %d eggs for the day." % per_day)
	return lines

static func _result_line(total: int) -> String:
	var cartons := int(ceil(float(total) / CARTON))
	var rem := total % CARTON
	if rem == 0:
		return "You did it! %d eggs make %d full cartons." % [total, cartons]
	var filled := (cartons - 1) * CARTON
	return "You did it! It takes %d cartons, because %d is more than %d, leaving %d %s in the last carton." % [
		cartons, total, filled, rem, "egg" if rem == 1 else "eggs"]

static func _number_word(v: int) -> String:
	if v >= 0 and v < NUMBER_WORDS.size():
		return NUMBER_WORDS[v]
	return str(v)

# ---- Phase 1: tap chickens to lay into hatch beds ---------------------------

func _start_lay() -> void:
	_phase = Phase.LAY
	var q: Dictionary = _p["params"]
	var white: int = q["white"]
	var yellow: int = q["yellow"]
	var w_eggs: int = q["w_eggs"]
	var y_eggs: int = q["y_eggs"]
	_instr.text = "Tap a chicken to lay an egg  (white %d, yellow %d)" % [w_eggs, y_eggs]
	Narrator.speak("Tap a chicken to lay an egg. White hens lay %d, yellow hens lay %d." % [w_eggs, y_eggs])

	var n := white + yellow
	var gap := 28.0
	var cw := 100.0
	var total_w := n * cw + (n - 1) * gap
	var x0 := 640.0 - total_w * 0.5
	for i in n:
		var is_white := i < white
		var cx := x0 + i * (cw + gap) + cw * 0.5
		var chick := _sprite("chicken_white" if is_white else "chicken_yellow", 96.0)
		if chick == null:
			continue
		chick.position = Vector2(cx - chick.size.x * 0.5, 168.0)
		chick.pivot_offset = chick.size * 0.5
		add_child(chick)
		var cap := w_eggs if is_white else y_eggs
		var bed := _sprite("hatch_bed", HATCH_SIZE)
		if bed == null:
			# Procedural fallback if art missing.
			bed = _fallback_bed(HATCH_SIZE)
		bed.position = Vector2(cx - bed.size.x * 0.5, 300.0)
		add_child(bed)
		var ring := _hatch_ring(bed)
		add_child(ring)
		var slots: Array = []
		for s in cap:
			# Nest eggs in a small arc inside the bed.
			var t := (float(s) + 0.5) / float(maxi(1, cap))
			var ox := (t - 0.5) * (bed.size.x * 0.55)
			var oy := 8.0 + (s % 2) * 10.0
			slots.append(bed.position + Vector2(bed.size.x * 0.5 + ox - EGG * 0.5, bed.size.y * 0.42 + oy))
		_hatches.append({
			"chicken": chick,
			"bed": bed,
			"ring": ring,
			"eggs": [],
			"cap": cap,
			"count": 0,
			"complete": false,
			"slots": slots,
			"rect_chick": Rect2(chick.position, chick.size).grow(8.0),
			"white": is_white,
		})

func _fallback_bed(side: float) -> TextureRect:
	# Invisible TextureRect sized like a bed; ring + panel drawn via StyleBox on a Panel sibling.
	var p := Panel.new()
	p.size = Vector2(side, side)
	p.custom_minimum_size = Vector2(side, side)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.72, 0.55, 0.28)
	sb.set_corner_radius_all(16)
	sb.set_border_width_all(4)
	sb.border_color = Color(0.35, 0.22, 0.10)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Wrap in a fake TextureRect API via a Control we treat like bed — use Panel directly.
	# Callers expect TextureRect; return a TextureRect with empty texture but sized.
	var tr := TextureRect.new()
	tr.custom_minimum_size = Vector2(side, side)
	tr.size = Vector2(side, side)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.add_child(p)
	p.position = Vector2.ZERO
	return tr

func _hatch_ring(bed: Control) -> Panel:
	var ring := Panel.new()
	ring.visible = false
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.position = bed.position - Vector2(6, 6)
	ring.size = bed.size + Vector2(12, 12)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0)
	sb.set_corner_radius_all(18)
	sb.set_border_width_all(5)
	sb.border_color = MathTheme.GOLD
	ring.add_theme_stylebox_override("panel", sb)
	return ring

func _hatch_at(pos: Vector2) -> int:
	for i in _hatches.size():
		var h: Dictionary = _hatches[i]
		if (h["rect_chick"] as Rect2).has_point(pos):
			return i
		var bed: Control = h["bed"]
		if Rect2(bed.position, bed.size).has_point(pos):
			return i
	return -1

func _on_tap_chicken(idx: int) -> void:
	if _busy or _phase != Phase.LAY:
		return
	var h: Dictionary = _hatches[idx]
	if h["complete"] or h["count"] >= h["cap"]:
		return
	_busy = true
	var chick: TextureRect = h["chicken"]
	# Quick bawk + shake.
	Narrator.speak("Bawk!")
	var base := chick.position
	var tw := create_tween()
	tw.tween_property(chick, "position", base + Vector2(6, 0), 0.05)
	tw.tween_property(chick, "position", base + Vector2(-6, 0), 0.05)
	tw.tween_property(chick, "position", base + Vector2(4, 0), 0.05)
	tw.tween_property(chick, "position", base, 0.05)
	await tw.finished

	var e := _egg_sprite()
	if e == null:
		_busy = false
		return
	var slot: Vector2 = h["slots"][h["count"]]
	e.position = chick.position + Vector2(chick.size.x * 0.5 - EGG * 0.5, chick.size.y - 8.0)
	e.scale = Vector2.ZERO
	add_child(e)
	h["eggs"].append(e)
	h["count"] += 1
	var land := create_tween()
	land.set_parallel(true)
	land.tween_property(e, "position", slot, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	land.tween_property(e, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await land.finished

	if h["count"] >= h["cap"]:
		await _count_hatch(idx)
	_busy = false
	_check_lay_done()

func _count_hatch(idx: int) -> void:
	_phase = Phase.COUNTING
	var h: Dictionary = _hatches[idx]
	Narrator.speak("That hatch is full!")
	await get_tree().create_timer(0.7).timeout
	var n := 0
	for e in h["eggs"]:
		n += 1
		var egg: TextureRect = e
		egg.scale = Vector2(1.28, 1.28)
		_draw_egg_gold(egg, true)
		var d := _say_number(n)
		await get_tree().create_timer(maxf(0.45, d - 0.25)).timeout
		egg.scale = Vector2.ONE
		_draw_egg_gold(egg, false)
	# Eggs normal; hatch gold-outlined.
	(h["ring"] as Panel).visible = true
	h["complete"] = true
	_phase = Phase.LAY

func _draw_egg_gold(egg: TextureRect, on: bool) -> void:
	# Modulate toward gold when counting; clear when done.
	egg.modulate = Color(1.15, 1.05, 0.55) if on else Color.WHITE
	# Soft outer glow via scale already; keep simple for TextureRect.

func _check_lay_done() -> void:
	for h in _hatches:
		if not h["complete"]:
			return
	_busy = true
	_phase = Phase.COUNTING
	await _sum_hatches()
	await get_tree().create_timer(0.5).timeout
	_start_pack()

## After every hatch is gold, add hatch counts aloud: 1, 2, 3, 5, 7…
func _sum_hatches() -> void:
	var running := 0
	for h in _hatches:
		running += int(h["cap"])
		# Pulse this hatch while speaking the running total.
		var ring: Panel = h["ring"]
		var tw := create_tween()
		tw.tween_property(ring, "scale", Vector2(1.08, 1.08), 0.12)
		tw.tween_property(ring, "scale", Vector2.ONE, 0.12)
		var d := _say_number(running)
		await get_tree().create_timer(maxf(0.55, d - 0.2)).timeout
	var per_day := running
	_eq0.text = "(%d\u00D7%d) + (%d\u00D7%d) = %d eggs a day" % [
		_p["params"]["white"], _p["params"]["w_eggs"],
		_p["params"]["yellow"], _p["params"]["y_eggs"], per_day]
	var d2 := Narrator.speak("That is %d eggs for the day." % per_day)
	await get_tree().create_timer(maxf(1.6, d2)).timeout

func _say_number(v: int) -> float:
	return Narrator.speak(_number_word(v))

# ---- Phase 2: pack cartons --------------------------------------------------

func _start_pack() -> void:
	_phase = Phase.PACK
	_busy = false
	var q: Dictionary = _p["params"]
	var per_day := int(q["white"]) * int(q["w_eggs"]) + int(q["yellow"]) * int(q["y_eggs"])
	var days: int = q["days"]
	var total: int = _p["answer"]
	var cartons := int(ceil(float(total) / CARTON))
	_eq0.text = "(%d\u00D7%d) + (%d\u00D7%d) = %d eggs a day" % [q["white"], q["w_eggs"], q["yellow"], q["y_eggs"], per_day]
	_eq1.text = "%d \u00D7 %d days = %d eggs" % [per_day, days, total]
	_instr.text = "Tap an egg, then tap a carton of %d" % CARTON
	Narrator.speak("Great! Over %d days that is %d eggs. Now fill the cartons. Each holds %d." % [days, total, CARTON])

	_deselect()
	for h in _hatches:
		if is_instance_valid(h["chicken"]):
			h["chicken"].queue_free()
		if is_instance_valid(h["bed"]):
			h["bed"].queue_free()
		if h.has("ring") and is_instance_valid(h["ring"]):
			h["ring"].queue_free()
		for e in h["eggs"]:
			if is_instance_valid(e):
				e.queue_free()
	_hatches.clear()
	for e in _eggs:
		e.queue_free()
	_eggs.clear()
	for z in _zones:
		z["node"].queue_free()
	_zones.clear()

	var cols := mini(12, total)
	var gapx := EGG + 8.0
	var tw := cols * gapx
	var x0 := 640.0 - tw * 0.5
	for i in total:
		var e := _egg_sprite()
		if e == null:
			continue
		var home := Vector2(x0 + (i % cols) * gapx, 250.0 + (i / cols) * (EGG + 8.0))
		e.position = home
		e.set_meta("home", home)
		e.set_meta("placed", false)
		add_child(e)
		_eggs.append(e)

	var cgap := 24.0
	var ctot := cartons * CARTON_W + (cartons - 1) * cgap
	var cx0 := 640.0 - ctot * 0.5
	var cy := 430.0
	for i in cartons:
		var tr := _sprite("carton_open", 130.0)
		if tr == null:
			continue
		tr.position = Vector2(cx0 + i * (CARTON_W + cgap), cy)
		add_child(tr)
		var slots := []
		for s in CARTON:
			slots.append(tr.position + Vector2(24 + (s % 3) * 40, 44 + (s / 3) * 44))
		var remaining := total - i * CARTON
		var cap: int = mini(CARTON, remaining)
		_zones.append({"node": tr, "kind": "carton", "cap": cap, "count": 0,
			"slots": slots, "complete": false, "idx": i,
			"rect": Rect2(tr.position, tr.size)})

# ---- input ------------------------------------------------------------------

func _on_gui_input(event: InputEvent) -> void:
	if _busy and _phase != Phase.PACK:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_press(event.position)
		else:
			_end_press(event.position)
	elif event is InputEventScreenTouch:
		if event.pressed:
			_begin_press(event.position)
		else:
			_end_press(event.position)
	elif event is InputEventMouseMotion and _dragging:
		_move_drag(event.position)
	elif event is InputEventScreenDrag and _dragging:
		_move_drag(event.position)

func _begin_press(pos: Vector2) -> void:
	if _phase == Phase.LAY:
		var hi := _hatch_at(pos)
		if hi >= 0:
			_on_tap_chicken(hi)
		return
	if _phase != Phase.PACK:
		return
	var e := _egg_at(pos)
	if e != null:
		_dragging = e
		_drag_off = pos - e.position
		_drag_start = pos
		_moved = false
		move_child(e, get_child_count() - 1)
		return
	if _selected != null:
		var z := _zone_at(pos)
		if not z.is_empty() and not z["complete"] and z["count"] < z["cap"]:
			_send_selected_to(z)
		else:
			_deselect()

func _move_drag(pos: Vector2) -> void:
	if _dragging == null:
		return
	if not _moved and (pos - _drag_start).length() > DRAG_THRESHOLD:
		_moved = true
		if _selected == _dragging:
			_deselect()
		_dragging.scale = Vector2(1.1, 1.1)
	if _moved:
		_dragging.position = pos - _drag_off

func _end_press(pos: Vector2) -> void:
	if _dragging == null:
		return
	var e := _dragging
	_dragging = null
	if not _moved:
		if _selected == e:
			_deselect()
		else:
			_select(e)
		return
	e.scale = Vector2.ONE
	var center := e.position + e.size * 0.5
	for z in _zones:
		if z["complete"] or z["count"] >= z["cap"]:
			continue
		if (z["rect"] as Rect2).has_point(center):
			_place_in_zone(e, z, false)
			return
	var tw := create_tween()
	tw.tween_property(e, "position", e.get_meta("home"), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _egg_at(pos: Vector2) -> TextureRect:
	for i in range(_eggs.size() - 1, -1, -1):
		var e: TextureRect = _eggs[i]
		if e.get_meta("placed") or not e.visible:
			continue
		if Rect2(e.position, e.size).has_point(pos):
			return e
	return null

func _zone_at(pos: Vector2) -> Dictionary:
	for z in _zones:
		if (z["rect"] as Rect2).has_point(pos):
			return z
	return {}

func _select(e: TextureRect) -> void:
	_deselect()
	_selected = e
	e.scale = Vector2(SELECT_SCALE, SELECT_SCALE)
	_sel_ring.size = e.size * SELECT_SCALE + Vector2(16, 16)
	_sel_ring.position = e.position + e.size * 0.5 - _sel_ring.size * 0.5
	_sel_ring.visible = true
	move_child(e, get_child_count() - 1)
	move_child(_sel_ring, get_child_count() - 1)
	move_child(e, get_child_count() - 1)

func _deselect() -> void:
	if _selected != null and is_instance_valid(_selected):
		_selected.scale = Vector2.ONE
	_selected = null
	if _sel_ring != null:
		_sel_ring.visible = false

func _send_selected_to(z: Dictionary) -> void:
	var e := _selected
	_deselect()
	_place_in_zone(e, z, true)

func _place_in_zone(e: TextureRect, z: Dictionary, fly: bool) -> void:
	var slot: Vector2 = z["slots"][z["count"]]
	e.set_meta("placed", true)
	z["count"] += 1
	var count_now: int = z["count"]
	var dur := 0.34 if fly else 0.18
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(e, "position", slot - e.size * 0.5, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(e, "scale", Vector2.ONE, dur)
	tw.chain().tween_callback(func() -> void: _egg_landed_in_carton(e, z, count_now))
	if z["count"] >= z["cap"]:
		_complete_zone(z)

func _egg_landed_in_carton(e: TextureRect, z: Dictionary, count_now: int) -> void:
	e.visible = false
	var node: TextureRect = z["node"]
	if count_now >= CARTON:
		node.texture = StorySprites.texture("carton_closed")
		var t := create_tween()
		t.tween_property(node, "scale", Vector2(1.12, 1.12), 0.1)
		t.tween_property(node, "scale", Vector2.ONE, 0.1)
	else:
		var tex := StorySprites.texture("carton_open_%d" % count_now)
		if tex:
			node.texture = tex

func _complete_zone(z: Dictionary) -> void:
	z["complete"] = true
	_check_pack_done()

func _check_pack_done() -> void:
	for z in _zones:
		if not z["complete"]:
			return
	var total: int = _p["answer"]
	var cartons := int(ceil(float(total) / CARTON))
	_eq2.text = "%d \u00F7 %d = %d cartons" % [total, CARTON, cartons]
	_instr.text = "You packed them all!"
	_hint.visible = false
	# Done state — no text chrome; Back tile returns home.
	_phase = Phase.DONE
	Narrator.speak(_result_line(total))
	finished.emit()

# ---- helpers ----------------------------------------------------------------

func _wide_label(font_size: int, color: Color, y: float) -> Label:
	var l := _label(font_size, color)
	l.set_anchors_preset(Control.PRESET_TOP_WIDE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.offset_left = 0
	l.offset_right = 0
	l.offset_top = y
	return l

func _label(font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _sprite(tag: String, height: float) -> TextureRect:
	var tex := StorySprites.texture(tag)
	if tex == null:
		return null
	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var w := height * tex.get_width() / float(tex.get_height())
	tr.custom_minimum_size = Vector2(w, height)
	tr.size = Vector2(w, height)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr

func _egg_sprite() -> TextureRect:
	var tr := _sprite("egg", EGG)
	if tr:
		tr.pivot_offset = tr.size * 0.5
	return tr

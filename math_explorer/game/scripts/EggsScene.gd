class_name EggsScene
extends Control
## Watch walkthrough: hens lay into hatch beds (tap-to-lay mirrored as auto-play),
## hatches are counted and summed, then eggs pack into cartons of 6.

signal finished()

const CARTON := 6
const EGG := 30.0
const HATCH_SIZE := 100.0
const TRAY_Y := 250.0
const CARTON_W := 150.0
const NUMBER_WORDS := ["zero", "one", "two", "three", "four", "five", "six",
	"seven", "eight", "nine", "ten", "eleven", "twelve", "thirteen", "fourteen",
	"fifteen", "sixteen", "seventeen", "eighteen", "nineteen", "twenty"]

const SEED_POOL: Array = [0, 5, 12, 21, 33, 47, 58, 66, 81, 94]

var _p: Dictionary = {}
var _gen: int = 0
var _done: bool = false

var _eq0: Label
var _eq1: Label
var _eq2: Label
var _skip_btn: Button
var _hatches: Array = []       # {chicken, bed, ring, eggs, cap, white}
var _tray_eggs: Array = []
var _cartons: Array = []
var _built := false

func start(seed: int = -1) -> void:
	_build()
	var s: int = seed if seed >= 0 else int(SEED_POOL[randi() % SEED_POOL.size()])
	_p = _pick(s)
	_gen += 1
	_done = false
	_reset()
	visible = true
	_run(_gen)

func _build() -> void:
	if _built:
		return
	_built = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_input)
	_eq0 = _eq_label(30, MathTheme.TEXT, 18)
	_eq1 = _eq_label(30, MathTheme.TEXT, 58)
	_eq2 = _eq_label(34, MathTheme.GOLD, 98)
	add_child(_eq0); add_child(_eq1); add_child(_eq2)
	_skip_btn = ChromeIcons.make_skip_button(self, _skip)

func _reset() -> void:
	for h in _hatches:
		for k in ["chicken", "bed", "ring"]:
			if h.has(k) and is_instance_valid(h[k]):
				h[k].queue_free()
		for e in h.get("eggs", []):
			if is_instance_valid(e):
				e.queue_free()
	for e in _tray_eggs: e.queue_free()
	for c in _cartons: c["node"].queue_free()
	_hatches.clear(); _tray_eggs.clear(); _cartons.clear()
	_eq0.text = ""; _eq1.text = ""; _eq2.text = ""
	_skip_btn.visible = true

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
	var per_day: int = int(q["white"]) * int(q["w_eggs"]) + int(q["yellow"]) * int(q["y_eggs"])
	var total: int = p["answer"]
	var lines: Array = [
		"%d white chickens each lay %d eggs a day. %d yellow chickens each lay %d." % [q["white"], q["w_eggs"], q["yellow"], q["y_eggs"]],
		"Bawk!",
		"That hatch is full!",
		"That is %d eggs every day." % per_day,
		"For %d days, that is %d eggs in all." % [q["days"], total],
		"Now pack them into cartons of %d." % CARTON,
		_cartons_line(total),
	]
	var caps: Array = []
	for _i in int(q["white"]):
		caps.append(int(q["w_eggs"]))
	for _j in int(q["yellow"]):
		caps.append(int(q["y_eggs"]))
	var running := 0
	for c in caps:
		running += int(c)
		lines.append(_number_word(running))
	return lines

static func _cartons_line(total: int) -> String:
	var cartons := int(ceil(float(total) / CARTON))
	var rem := total % CARTON
	if rem == 0:
		return "%d eggs make %d full cartons. Great job!" % [total, cartons]
	var filled := (cartons - 1) * CARTON
	return "It takes %d cartons, because %d is more than %d, leaving %d %s in the last carton." % [
		cartons, total, filled, rem, "egg" if rem == 1 else "eggs"]

static func _number_word(v: int) -> String:
	if v >= 0 and v < NUMBER_WORDS.size():
		return NUMBER_WORDS[v]
	return str(v)

func _run(gen: int) -> void:
	var q: Dictionary = _p["params"]
	var white: int = q["white"]
	var yellow: int = q["yellow"]
	var w_eggs: int = q["w_eggs"]
	var y_eggs: int = q["y_eggs"]
	var days: int = q["days"]
	var per_day := white * w_eggs + yellow * y_eggs
	var total: int = _p["answer"]
	var cartons := int(ceil(float(total) / CARTON))

	var d := Narrator.speak("%d white chickens each lay %d eggs a day. %d yellow chickens each lay %d." % [white, w_eggs, yellow, y_eggs])
	_lay_out_hatches(white, yellow, w_eggs, y_eggs)
	if not await _wait(gen, maxf(2.4, d)): return

	# Auto-lay into each hatch, count when full.
	for hi in _hatches.size():
		var h: Dictionary = _hatches[hi]
		var cap: int = h["cap"]
		for k in cap:
			if not await _lay_one(gen, hi): return
		if not await _count_hatch(gen, hi): return

	# Sum hatch counts: 1, 2, 3, 5, 7…
	var running := 0
	for h2 in _hatches:
		running += int(h2["cap"])
		d = Narrator.speak(_number_word(running))
		if not await _wait(gen, maxf(0.55, d)): return

	_eq0.text = "(%d\u00D7%d) + (%d\u00D7%d) = %d eggs a day" % [white, w_eggs, yellow, y_eggs, per_day]
	d = Narrator.speak("That is %d eggs every day." % per_day)
	if not await _wait(gen, maxf(2.2, d)): return

	Narrator.speak("For %d days, that is %d eggs in all." % [days, total])
	_clear_hatches()
	_eq1.text = "%d \u00D7 %d days = %d eggs" % [per_day, days, total]
	for i in total:
		_spawn_tray_egg(i, total)
		if not await _wait(gen, 0.08): return
	if not await _wait(gen, 0.8): return

	Narrator.speak("Now pack them into cartons of %d." % CARTON)
	_lay_out_cartons(cartons)
	if not await _wait(gen, 1.0): return
	for i in _tray_eggs.size():
		var carton_idx := i / CARTON
		var slot := i % CARTON
		await _fly_egg_to_carton(gen, _tray_eggs[i], carton_idx, slot)
		_tray_eggs[i].visible = false
		var count_in := slot + 1
		if count_in >= CARTON:
			_close_carton(carton_idx)
			if not await _wait(gen, 0.5): return
		else:
			_set_carton_fill(carton_idx, count_in)
			if not await _wait(gen, 0.12): return

	_eq2.text = "%d \u00F7 %d = %d cartons" % [total, CARTON, cartons]
	Narrator.speak(_cartons_line(total))
	_skip_btn.visible = false
	_done = true
	finished.emit()

func _lay_out_hatches(white: int, yellow: int, w_eggs: int, y_eggs: int) -> void:
	var n := white + yellow
	var gap := 28.0
	var cw := 100.0
	var total_w := n * cw + (n - 1) * gap
	var x0 := 640.0 - total_w * 0.5
	for i in n:
		var is_white := i < white
		var cx := x0 + i * (cw + gap) + cw * 0.5
		var chick := _sprite("chicken_white" if is_white else "chicken_yellow", 90.0)
		if chick == null:
			continue
		chick.position = Vector2(cx - chick.size.x * 0.5, 150.0)
		chick.pivot_offset = chick.size * 0.5
		add_child(chick)
		var cap := w_eggs if is_white else y_eggs
		var bed := _sprite("hatch_bed", HATCH_SIZE)
		if bed == null:
			continue
		bed.position = Vector2(cx - bed.size.x * 0.5, 275.0)
		add_child(bed)
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
		add_child(ring)
		var slots: Array = []
		for s in cap:
			var t := (float(s) + 0.5) / float(maxi(1, cap))
			var ox := (t - 0.5) * (bed.size.x * 0.55)
			var oy := 6.0 + (s % 2) * 8.0
			slots.append(bed.position + Vector2(bed.size.x * 0.5 + ox - EGG * 0.5, bed.size.y * 0.42 + oy))
		_hatches.append({"chicken": chick, "bed": bed, "ring": ring, "eggs": [],
			"cap": cap, "slots": slots, "white": is_white})

func _lay_one(gen: int, hi: int) -> bool:
	var h: Dictionary = _hatches[hi]
	var chick: TextureRect = h["chicken"]
	Narrator.speak("Bawk!")
	var base := chick.position
	var tw := create_tween()
	tw.tween_property(chick, "position", base + Vector2(5, 0), 0.04)
	tw.tween_property(chick, "position", base + Vector2(-5, 0), 0.04)
	tw.tween_property(chick, "position", base, 0.04)
	await tw.finished
	if gen != _gen: return false
	var e := _egg_sprite()
	if e == null:
		return gen == _gen
	var slot: Vector2 = h["slots"][h["eggs"].size()]
	e.position = chick.position + Vector2(chick.size.x * 0.5 - EGG * 0.5, chick.size.y - 6.0)
	e.scale = Vector2.ZERO
	add_child(e)
	h["eggs"].append(e)
	var land := create_tween()
	land.set_parallel(true)
	land.tween_property(e, "position", slot, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	land.tween_property(e, "scale", Vector2.ONE, 0.22)
	await land.finished
	return gen == _gen and is_inside_tree()

func _count_hatch(gen: int, hi: int) -> bool:
	var h: Dictionary = _hatches[hi]
	var d := Narrator.speak("That hatch is full!")
	if not await _wait(gen, maxf(0.6, d * 0.4)): return false
	var n := 0
	for e in h["eggs"]:
		n += 1
		var egg: TextureRect = e
		egg.scale = Vector2(1.28, 1.28)
		egg.modulate = Color(1.15, 1.05, 0.55)
		d = Narrator.speak(_number_word(n))
		if not await _wait(gen, maxf(0.45, d - 0.25)): return false
		egg.scale = Vector2.ONE
		egg.modulate = Color.WHITE
	(h["ring"] as Panel).visible = true
	return gen == _gen

func _clear_hatches() -> void:
	for h in _hatches:
		for k in ["chicken", "bed", "ring"]:
			if h.has(k) and is_instance_valid(h[k]):
				h[k].queue_free()
		for e in h.get("eggs", []):
			if is_instance_valid(e):
				e.queue_free()
	_hatches.clear()

func _spawn_tray_egg(i: int, total: int) -> void:
	var e := _egg_sprite()
	if e == null:
		return
	var cols := mini(12, total)
	var col := i % cols
	var row := i / cols
	var tw_all := cols * (EGG + 6.0)
	var ox := 640.0 - tw_all * 0.5
	e.position = Vector2(ox + col * (EGG + 6.0), TRAY_Y + row * (EGG + 6.0))
	e.scale = Vector2.ZERO
	add_child(e)
	_tray_eggs.append(e)
	var tw := create_tween()
	tw.tween_property(e, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _lay_out_cartons(cartons: int) -> void:
	var gap := 24.0
	var total_w := cartons * CARTON_W + (cartons - 1) * gap
	var x := 640.0 - total_w * 0.5
	var y := 430.0
	for i in cartons:
		var tr := _sprite("carton_open", 130.0)
		if tr == null:
			continue
		tr.position = Vector2(x + i * (CARTON_W + gap), y)
		add_child(tr)
		var slots := []
		for s in CARTON:
			slots.append(tr.position + Vector2(24 + (s % 3) * 40, 44 + (s / 3) * 44))
		_cartons.append({"node": tr, "filled": 0, "slots": slots, "base": tr.position})

func _fly_egg_to_carton(_gen: int, egg: TextureRect, carton_idx: int, slot: int) -> void:
	if carton_idx >= _cartons.size():
		return
	var target: Vector2 = _cartons[carton_idx]["slots"][slot]
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(egg, "position", target, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(egg, "scale", Vector2(0.7, 0.7), 0.28)
	await tw.finished

func _set_carton_fill(carton_idx: int, n: int) -> void:
	if carton_idx >= _cartons.size():
		return
	var tex := StorySprites.texture("carton_open_%d" % n)
	if tex:
		(_cartons[carton_idx]["node"] as TextureRect).texture = tex

func _close_carton(carton_idx: int) -> void:
	if carton_idx >= _cartons.size():
		return
	var node: TextureRect = _cartons[carton_idx]["node"]
	var closed := StorySprites.texture("carton_closed")
	if closed:
		node.texture = closed
	var tw := create_tween()
	tw.tween_property(node, "scale", Vector2(1.12, 1.12), 0.12)
	tw.tween_property(node, "scale", Vector2.ONE, 0.12)

func _on_input(event: InputEvent) -> void:
	var tap: bool = (event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventScreenTouch and event.pressed)
	if tap and not _done:
		_skip()

func _skip() -> void:
	_gen += 1
	Narrator.stop()
	var q: Dictionary = _p["params"]
	var per_day := int(q["white"]) * int(q["w_eggs"]) + int(q["yellow"]) * int(q["y_eggs"])
	var total: int = _p["answer"]
	var cartons := int(ceil(float(total) / CARTON))
	_reset()
	_lay_out_cartons(cartons)
	var rem := total % CARTON
	for idx in _cartons.size():
		if rem > 0 and idx == cartons - 1:
			_set_carton_fill(idx, rem)
		else:
			(_cartons[idx]["node"] as TextureRect).texture = StorySprites.texture("carton_closed")
	_eq0.text = "(%d\u00D7%d) + (%d\u00D7%d) = %d eggs a day" % [q["white"], q["w_eggs"], q["yellow"], q["y_eggs"], per_day]
	_eq1.text = "%d \u00D7 %d days = %d eggs" % [per_day, q["days"], total]
	_eq2.text = "%d \u00F7 %d = %d cartons" % [total, CARTON, cartons]
	_skip_btn.visible = false
	_done = true
	finished.emit()

func _wait(gen: int, secs: float) -> bool:
	await get_tree().create_timer(secs).timeout
	return gen == _gen and is_inside_tree()

func _eq_label(font_size: int, color: Color, y: float) -> Label:
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

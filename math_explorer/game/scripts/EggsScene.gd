class_name EggsScene
extends Control
## The flagship word problem, animated: white + yellow chickens lay eggs, the
## rate equation builds, the eggs gather into a tray, then fly into 6-egg cartons
## that SNAP SHUT when full. Ends on the worked equations:
##   (white\u00D7w) + (yellow\u00D7y) = per-day  \u2192  \u00D7 days = total  \u2192  total \u00F7 6 = cartons
##
## Numbers come from MathProblemGen("eggs_rate"), clamped to stay countable on
## screen. Auto-animated with tap-to-skip. (Drag-to-place is a Practice-mode
## enhancement; here the goal is to make the whole idea legible.)

signal finished()

const CARTON := 6
const EGG := 30.0
const TRAY_Y := 250.0
const CARTON_W := 150.0

## Fixed seed pool so every narration line can be baked ahead of time with
## ElevenLabs (tools/dump_vo_lines.gd enumerates vo_lines() for each seed).
const SEED_POOL: Array = [0, 5, 12, 21, 33, 47, 58, 66, 81, 94]

var _p: Dictionary = {}
var _gen: int = 0
var _done: bool = false

var _eq0: Label
var _eq1: Label
var _eq2: Label
var _hint: Label
var _chickens: Array = []      # TextureRect
var _tray_eggs: Array = []     # TextureRect in the central tray
var _cartons: Array = []       # {node, filled, slots:[Vector2], base:Vector2}
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
	_hint = _label(18, Color(1, 1, 1, 0.7))
	_hint.text = "tap to skip \u25B6"
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_hint.position = Vector2(-190, -34)
	_hint.size = Vector2(170, 26)
	add_child(_hint)

func _reset() -> void:
	for c in _chickens: c.queue_free()
	for e in _tray_eggs: e.queue_free()
	for c in _cartons: c["node"].queue_free()
	_chickens.clear(); _tray_eggs.clear(); _cartons.clear()
	_eq0.text = ""; _eq1.text = ""; _eq2.text = ""
	_hint.text = "tap to skip \u25B6"

## Find a seed whose numbers stay small enough to draw (few chickens, <= 4
## cartons) and whose two rates DIFFER — same-rate hens hide the whole idea.
## Static + deterministic so the VO bake tool sees the exact same problem.
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

## Every narration line this scene can speak for `seed` — enumerated by
## tools/dump_vo_lines.gd so each sentence gets a baked ElevenLabs clip.
static func vo_lines(seed: int) -> Array:
	var p := _pick(seed)
	var q: Dictionary = p["params"]
	var per_day: int = int(q["white"]) * int(q["w_eggs"]) + int(q["yellow"]) * int(q["y_eggs"])
	var total: int = p["answer"]
	var cartons := int(ceil(float(total) / CARTON))
	return [
		"%d white chickens each lay %d eggs a day. %d yellow chickens each lay %d." % [q["white"], q["w_eggs"], q["yellow"], q["y_eggs"]],
		"That is %d eggs every day." % per_day,
		"For %d days, that is %d eggs in all." % [q["days"], total],
		"Now pack them into cartons of %d." % CARTON,
		"%d eggs make %d full cartons. Great job!" % [total, cartons],
		"%d eggs need %d cartons." % [total, cartons],
	]

# ---- choreography -----------------------------------------------------------

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

	# 1) Chickens appear.
	Narrator.speak("%d white chickens each lay %d eggs a day. %d yellow chickens each lay %d." % [white, w_eggs, yellow, y_eggs])
	_lay_out_chickens(white, yellow)
	if not await _wait(gen, 2.4): return

	# 2) Each chicken lays its eggs for the day (little pops under it).
	for i in _chickens.size():
		var meta = _chickens[i]
		var n: int = w_eggs if meta["white"] else y_eggs
		for k in n:
			_spawn_egg_under(meta["node"], k, n)
			if not await _wait(gen, 0.16): return
	_eq0.text = "(%d\u00D7%d) + (%d\u00D7%d) = %d eggs a day" % [white, w_eggs, yellow, y_eggs, per_day]
	Narrator.speak("That is %d eggs every day." % per_day)
	if not await _wait(gen, 2.2): return

	# 3) Over `days` days -> gather `total` eggs into a tray.
	Narrator.speak("For %d days, that is %d eggs in all." % [days, total])
	_clear_under_eggs()
	_eq1.text = "%d \u00D7 %d days = %d eggs" % [per_day, days, total]
	for i in total:
		_spawn_tray_egg(i, total)
		if not await _wait(gen, 0.08): return
	if not await _wait(gen, 0.8): return

	# 4) Cartons appear; eggs fly in; each snaps shut at 6.
	Narrator.speak("Now pack them into cartons of %d." % CARTON)
	_lay_out_cartons(cartons)
	if not await _wait(gen, 1.0): return
	for i in _tray_eggs.size():
		var carton_idx := i / CARTON
		var slot := i % CARTON
		await _fly_egg_to_carton(gen, _tray_eggs[i], carton_idx, slot)
		if slot == CARTON - 1 or i == _tray_eggs.size() - 1:
			_snap_carton(carton_idx)
			if not await _wait(gen, 0.5): return

	# 5) The answer.
	_eq2.text = "%d \u00F7 %d = %d cartons" % [total, CARTON, cartons]
	Narrator.speak("%d eggs make %d full cartons. Great job!" % [total, cartons]) if total % CARTON == 0 \
		else Narrator.speak("%d eggs need %d cartons." % [total, cartons])
	_hint.text = "\u2713 done"
	_done = true
	finished.emit()

# ---- layout / spawns --------------------------------------------------------

func _lay_out_chickens(white: int, yellow: int) -> void:
	var n := white + yellow
	var gap := 30.0
	var cw := 96.0 * 1.1
	var total_w := n * cw + (n - 1) * gap
	var x := 640.0 - total_w * 0.5
	for i in n:
		var is_white := i < white
		var tr := _sprite("chicken_white" if is_white else "chicken_yellow", 96.0)
		if tr == null:
			continue
		tr.position = Vector2(x + i * (cw + gap) + (cw - tr.size.x) * 0.5, 150.0)
		add_child(tr)
		_chickens.append({"node": tr, "white": is_white})

func _spawn_egg_under(chicken: TextureRect, k: int, n: int) -> void:
	var e := _egg_sprite()
	if e == null:
		return
	var cx := chicken.position.x + chicken.size.x * 0.5
	var row_w := n * (EGG + 4.0)
	e.position = Vector2(cx - row_w * 0.5 + k * (EGG + 4.0), 262.0)
	e.scale = Vector2.ZERO
	add_child(e)
	e.set_meta("under", true)
	var tw := create_tween()
	tw.tween_property(e, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _clear_under_eggs() -> void:
	for c in get_children():
		if c is TextureRect and c.has_meta("under"):
			c.queue_free()

func _spawn_tray_egg(i: int, total: int) -> void:
	var e := _egg_sprite()
	if e == null:
		return
	var cols := mini(12, total)
	var rows := int(ceil(float(total) / cols))
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
		# Six slots: 2 rows of 3 across the carton cups.
		var slots := []
		for s in CARTON:
			var sc := s % 3
			var sr := s / 3
			slots.append(tr.position + Vector2(24 + sc * 40, 44 + sr * 44))
		_cartons.append({"node": tr, "filled": 0, "slots": slots, "base": tr.position})

func _fly_egg_to_carton(gen: int, egg: TextureRect, carton_idx: int, slot: int) -> void:
	if carton_idx >= _cartons.size():
		return
	var target: Vector2 = _cartons[carton_idx]["slots"][slot]
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(egg, "position", target, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(egg, "scale", Vector2(0.7, 0.7), 0.28)
	await tw.finished

func _snap_carton(carton_idx: int) -> void:
	if carton_idx >= _cartons.size():
		return
	var c: Dictionary = _cartons[carton_idx]
	var closed := StorySprites.texture("carton_closed")
	if closed:
		(c["node"] as TextureRect).texture = closed
	# Eggs are now hidden under the lid.
	var start := carton_idx * CARTON
	for j in range(start, mini(start + CARTON, _tray_eggs.size())):
		_tray_eggs[j].visible = false
	var node: TextureRect = c["node"]
	var tw := create_tween()
	tw.tween_property(node, "scale", Vector2(1.12, 1.12), 0.12)
	tw.tween_property(node, "scale", Vector2.ONE, 0.12)

# ---- input / helpers --------------------------------------------------------

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
	_lay_out_chickens(q["white"], q["yellow"])
	_lay_out_cartons(cartons)
	for c in _cartons:
		(c["node"] as TextureRect).texture = StorySprites.texture("carton_closed")
	_eq0.text = "(%d\u00D7%d) + (%d\u00D7%d) = %d eggs a day" % [q["white"], q["w_eggs"], q["yellow"], q["y_eggs"], per_day]
	_eq1.text = "%d \u00D7 %d days = %d eggs" % [per_day, q["days"], total]
	_eq2.text = "%d \u00F7 %d = %d cartons" % [total, CARTON, cartons]
	_hint.text = "\u2713 done"
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

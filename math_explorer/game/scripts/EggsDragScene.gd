class_name EggsDragScene
extends Control
## The interactive chickens & eggs problem — she plays it.
##   Phase 1: drag eggs from the pile into each hen's nest. Each nest wants the
##            right number (white hens lay w, yellow hens lay y). A full, correct
##            nest gets a gold outline and locks.
##   Phase 2: the day's eggs multiply over the days; drag them into 6-egg cartons,
##            which SNAP SHUT (and gold-flash) when full.
##   Then the worked equations appear, narrated.
##
## Drag is handled at the scene level (eggs are mouse-transparent; the scene
## hit-tests), so it works with both mouse and touch.

signal finished()

enum Phase { LAY, PACK, DONE }

const EGG := 34.0
const CARTON := 6
const CARTON_W := 150.0

## Fixed seed pool so every narration line can be baked ahead of time with
## ElevenLabs (tools/dump_vo_lines.gd enumerates vo_lines() for each seed).
const SEED_POOL: Array = [0, 4, 9, 17, 26, 38, 49, 61, 77, 90]

var _p: Dictionary = {}
var _phase: int = Phase.LAY
var _eggs: Array = []        # TextureRect, draggable while not placed
var _zones: Array = []       # {node, kind, cap, count, slots, complete, idx}
var _chickens: Array = []
var _dragging: TextureRect = null
var _drag_off: Vector2 = Vector2.ZERO
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
	_hint.position = Vector2(-210, -34)
	_hint.size = Vector2(190, 26)
	add_child(_hint)

func _reset() -> void:
	for e in _eggs: e.queue_free()
	for z in _zones: z["node"].queue_free()
	for c in _chickens: c.queue_free()
	_eggs.clear(); _zones.clear(); _chickens.clear()
	_dragging = null
	_eq0.text = ""; _eq1.text = ""; _eq2.text = ""
	_hint.text = ""

## Rates must differ (white != yellow) — otherwise the two hen colours teach nothing.
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
	var total: int = p["answer"]
	var cartons := int(ceil(float(total) / CARTON))
	return [
		"Each white hen lays %d eggs. Each yellow hen lays %d. Drag the right number into every nest." % [q["w_eggs"], q["y_eggs"]],
		"Great! Over %d days that is %d eggs. Now fill the cartons. Each holds %d." % [q["days"], total, CARTON],
		"That nest is full!",
		"You did it! %d eggs make %d cartons." % [total, cartons],
	]

# ---- Phase 1: lay eggs into nests -------------------------------------------

func _start_lay() -> void:
	_phase = Phase.LAY
	var q: Dictionary = _p["params"]
	var white: int = q["white"]
	var yellow: int = q["yellow"]
	var w_eggs: int = q["w_eggs"]
	var y_eggs: int = q["y_eggs"]
	_instr.text = "Drag each hen's eggs into her nest  (white lay %d, yellow lay %d)" % [w_eggs, y_eggs]
	Narrator.speak("Each white hen lays %d eggs. Each yellow hen lays %d. Drag the right number into every nest." % [w_eggs, y_eggs])

	var n := white + yellow
	var gap := 34.0
	var cw := 96.0
	var total_w := n * cw + (n - 1) * gap
	var x0 := 640.0 - total_w * 0.5
	for i in n:
		var is_white := i < white
		var cx := x0 + i * (cw + gap) + cw * 0.5
		var chick := _sprite("chicken_white" if is_white else "chicken_yellow", 96.0)
		if chick:
			chick.position = Vector2(cx - chick.size.x * 0.5, 175.0)
			add_child(chick)
			_chickens.append(chick)
		var cap := w_eggs if is_white else y_eggs
		_add_nest(cx, 290.0, cap)

	# The pile of draggable eggs: exactly enough (white*w + yellow*y).
	var need := white * w_eggs + yellow * y_eggs
	_spawn_pile(need)

func _add_nest(cx: float, y: float, cap: int) -> void:
	var w := cap * (EGG + 6.0) + 18.0
	var h := EGG + 18.0
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.position = Vector2(cx - w * 0.5, y)
	panel.size = Vector2(w, h)
	panel.add_theme_stylebox_override("panel", _nest_box(false))
	add_child(panel)
	var slots := []
	for s in cap:
		slots.append(panel.position + Vector2(9 + s * (EGG + 6.0) + EGG * 0.5, h * 0.5))
	_zones.append({"node": panel, "kind": "nest", "cap": cap, "count": 0,
		"slots": slots, "complete": false,
		"rect": Rect2(panel.position, panel.size)})

func _spawn_pile(count: int) -> void:
	var cols := mini(10, count)
	var gapx := EGG + 10.0
	var total_w := cols * gapx
	var x0 := 640.0 - total_w * 0.5
	var y := 455.0
	for i in count:
		var e := _egg_sprite()
		if e == null:
			continue
		var home := Vector2(x0 + (i % cols) * gapx, y + (i / cols) * (EGG + 8.0))
		e.position = home
		e.set_meta("home", home)
		e.set_meta("placed", false)
		add_child(e)
		_eggs.append(e)

# ---- Phase 2: pack cartons --------------------------------------------------

func _start_pack() -> void:
	_phase = Phase.PACK
	var q: Dictionary = _p["params"]
	var per_day := int(q["white"]) * int(q["w_eggs"]) + int(q["yellow"]) * int(q["y_eggs"])
	var days: int = q["days"]
	var total: int = _p["answer"]
	var cartons := int(ceil(float(total) / CARTON))
	_eq0.text = "(%d\u00D7%d) + (%d\u00D7%d) = %d eggs a day" % [q["white"], q["w_eggs"], q["yellow"], q["y_eggs"], per_day]
	_eq1.text = "%d \u00D7 %d days = %d eggs" % [per_day, days, total]
	_instr.text = "Now drag the eggs into cartons of %d" % CARTON
	Narrator.speak("Great! Over %d days that is %d eggs. Now fill the cartons. Each holds %d." % [days, total, CARTON])

	# clear phase-1 nests + eggs
	for z in _zones: z["node"].queue_free()
	for e in _eggs: e.queue_free()
	for c in _chickens: c.queue_free()
	_zones.clear(); _eggs.clear(); _chickens.clear()

	# source tray of `total` eggs up top
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

	# cartons across the bottom
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
		# last carton may not need all 6
		var remaining := total - i * CARTON
		var cap: int = mini(CARTON, remaining)
		_zones.append({"node": tr, "kind": "carton", "cap": cap, "count": 0,
			"slots": slots, "complete": false, "idx": i,
			"rect": Rect2(tr.position, tr.size)})

# ---- drag handling ----------------------------------------------------------

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed: _begin_drag(event.position)
		else: _end_drag(event.position)
	elif event is InputEventScreenTouch:
		if event.pressed: _begin_drag(event.position)
		else: _end_drag(event.position)
	elif event is InputEventMouseMotion and _dragging:
		_move_drag(event.position)
	elif event is InputEventScreenDrag and _dragging:
		_move_drag(event.position)

func _begin_drag(pos: Vector2) -> void:
	if _phase == Phase.DONE:
		return
	# topmost free egg under the pointer
	for i in range(_eggs.size() - 1, -1, -1):
		var e: TextureRect = _eggs[i]
		if e.get_meta("placed"):
			continue
		if Rect2(e.position, e.size).has_point(pos):
			_dragging = e
			_drag_off = pos - e.position
			move_child(e, get_child_count() - 1)  # bring to front
			e.scale = Vector2(1.1, 1.1)
			return

func _move_drag(pos: Vector2) -> void:
	if _dragging:
		_dragging.position = pos - _drag_off

func _end_drag(pos: Vector2) -> void:
	if _dragging == null:
		return
	var e := _dragging
	_dragging = null
	e.scale = Vector2.ONE
	var center := e.position + e.size * 0.5
	for z in _zones:
		if z["complete"] or z["count"] >= z["cap"]:
			continue
		if (z["rect"] as Rect2).has_point(center):
			_place_in_zone(e, z)
			return
	# no valid drop -> snap home
	var tw := create_tween()
	tw.tween_property(e, "position", e.get_meta("home"), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _place_in_zone(e: TextureRect, z: Dictionary) -> void:
	var slot: Vector2 = z["slots"][z["count"]]
	e.set_meta("placed", true)
	z["count"] += 1
	var tw := create_tween()
	tw.tween_property(e, "position", slot - e.size * 0.5, 0.18).set_trans(Tween.TRANS_QUAD)
	if z["count"] >= z["cap"]:
		_complete_zone(z)

func _complete_zone(z: Dictionary) -> void:
	z["complete"] = true
	if z["kind"] == "nest":
		(z["node"] as Panel).add_theme_stylebox_override("panel", _nest_box(true))
		Narrator.speak("That nest is full!")
	else:
		var node: TextureRect = z["node"]
		node.texture = StorySprites.texture("carton_closed")
		# hide the eggs now under the lid
		for e in _eggs:
			if e.get_meta("placed") and (z["rect"] as Rect2).has_point(e.position + e.size * 0.5):
				e.visible = false
		var t := create_tween()
		t.tween_property(node, "scale", Vector2(1.12, 1.12), 0.1)
		t.tween_property(node, "scale", Vector2.ONE, 0.1)
	_check_phase_done()

func _check_phase_done() -> void:
	for z in _zones:
		if not z["complete"]:
			return
	if _phase == Phase.LAY:
		await get_tree().create_timer(0.6).timeout
		_start_pack()
	elif _phase == Phase.PACK:
		var total: int = _p["answer"]
		var cartons := int(ceil(float(total) / CARTON))
		_eq2.text = "%d \u00F7 %d = %d cartons" % [total, CARTON, cartons]
		_instr.text = "You packed them all!"
		_hint.text = "\u2713 done"
		_phase = Phase.DONE
		Narrator.speak("You did it! %d eggs make %d cartons." % [total, cartons])
		finished.emit()

# ---- helpers ----------------------------------------------------------------

func _nest_box(complete: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.30, 0.22, 0.16, 0.55)
	sb.set_corner_radius_all(14)
	sb.set_border_width_all(4 if complete else 2)
	sb.border_color = MathTheme.GOLD if complete else Color(1, 1, 1, 0.25)
	return sb

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

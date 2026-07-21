class_name TrainsScene
extends Control
## The two-trains problem, animated so the hard idea becomes obvious. A red steam
## train leaves the station first (slower); a blue bullet leaves later (faster),
## visibly eats the head start, CATCHES UP, and pulls ahead. We freeze at the
## asked hour and show: B_distance − A_distance = how far ahead.
##
## Numbers come from MathProblemGen("trains_gap"); the sim is a single clock in
## "A hours" (time since the red train left). B starts after the head start `h`
## and we stop when B has run `t` hours (so A has run t+h).

signal finished()

const RAIL_A_Y := 250.0
const RAIL_B_Y := 388.0
const X0 := 168.0
const X_RIGHT := 1240.0
const TARGET_SECS := 8.5   # whole run length regardless of the numbers

## Fixed seed pool so every narration line can be baked ahead of time with
## ElevenLabs (tools/dump_vo_lines.gd enumerates vo_lines() for each seed).
const SEED_POOL: Array = [0, 3, 7, 11, 19, 23, 31, 42, 57, 73]

var _p: Dictionary = {}
var _hps: float = 1.0       # A-hours per real second
var _a_hours: float = 0.0
var _total_a: float = 1.0
var _ppm: float = 1.0
var _running: bool = false
var _done: bool = false
var _caught: bool = false

var _eq: Label
var _hour: Label
var _station: TextureRect
var _train_a: TextureRect
var _train_b: TextureRect
var _lbl_a: Label
var _lbl_b: Label
var _catch: Label
var _end: Panel
var _end_lbl: Label
var _hint: Label
var _built := false

func start(seed: int = -1) -> void:
	_build()
	# Seeds come from the fixed pool so every narrated line has a baked VO clip.
	var s: int = seed if seed >= 0 else int(SEED_POOL[randi() % SEED_POOL.size()])
	_p = MathProblemGen.generate("trains_gap", s)
	var q: Dictionary = _p["params"]
	var s_a: int = q["s_a"]
	var s_b: int = q["s_b"]
	var h: int = q["h"]
	var t: int = q["t"]
	_total_a = float(t + h)
	_hps = _total_a / TARGET_SECS
	var d_b := t * s_b
	var max_train_w := maxf(_train_a.size.x, _train_b.size.x)
	_ppm = (X_RIGHT - X0 - max_train_w) / float(d_b)

	_a_hours = 0.0
	_running = true
	_done = false
	_caught = false
	_catch.visible = false
	_end.visible = false
	_eq.text = ""
	visible = true
	queue_redraw()
	_place_trains()
	Narrator.speak("Two trains leave the station. The red train goes first, but it is slower.")

## Every narration line this scene can speak for `seed` — the VO bake tool
## (tools/dump_vo_lines.gd) calls this for each SEED_POOL entry.
static func vo_lines(seed: int) -> Array:
	var p := MathProblemGen.generate("trains_gap", seed)
	var q: Dictionary = p["params"]
	var t: int = q["t"]
	var gap: int = p["answer"]
	return [
		"Two trains leave the station. The red train goes first, but it is slower.",
		"The blue train caught up! Now it speeds ahead.",
		"After %d hours, the blue train is %d miles ahead of the red train." % [t, gap],
	]

func _build() -> void:
	if _built:
		return
	_built = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_input)

	_eq = _label(40, MathTheme.TEXT)
	_eq.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_eq.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_eq.position = Vector2(0, 20)
	add_child(_eq)

	_hour = _label(26, MathTheme.GOLD)
	_hour.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_hour.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hour.position = Vector2(0, 74)
	add_child(_hour)

	_station = _sprite("station", 150.0)
	if _station:
		_station.position = Vector2(10, RAIL_B_Y - _station.size.y + 34)
		add_child(_station)

	_train_a = _sprite("train_a", 104.0)
	_train_b = _sprite("train_b", 88.0)
	if _train_a: add_child(_train_a)
	if _train_b: add_child(_train_b)

	_lbl_a = _label(22, Color(1, 0.7, 0.66))
	_lbl_b = _label(22, Color(0.7, 0.85, 1.0))
	add_child(_lbl_a)
	add_child(_lbl_b)

	# A centered headline in the clear band under the rails — anchoring it to
	# the trains always collides with a mile label at the moment of catch-up.
	_catch = _label(30, MathTheme.GOLD)
	_catch.text = "\u2605 Caught up!"
	_catch.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_catch.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_catch.offset_left = 0
	_catch.offset_right = 0
	_catch.offset_top = 424
	_catch.visible = false
	add_child(_catch)

	_end = Panel.new()
	_end.custom_minimum_size = Vector2(720, 120)
	_end.size = Vector2(720, 120)
	_end.position = Vector2(280, 470)
	var sb := MathTheme.rounded_box(MathTheme.PANEL, 18)
	sb.set_border_width_all(3)
	sb.border_color = MathTheme.GOLD
	_end.add_theme_stylebox_override("panel", sb)
	_end.visible = false
	add_child(_end)
	_end_lbl = _label(34, MathTheme.TEXT)
	_end_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_end_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_end.add_child(_end_lbl)

	_hint = _label(18, Color(1, 1, 1, 0.7))
	_hint.text = "tap to skip \u25B6"
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_hint.position = Vector2(-190, -34)
	_hint.size = Vector2(170, 26)
	add_child(_hint)

func _process(delta: float) -> void:
	if not _running or not visible:
		return
	_a_hours += delta * _hps
	if _a_hours >= _total_a:
		_a_hours = _total_a
		_finish_sim()
	_place_trains()

func _place_trains() -> void:
	if _train_a == null or _train_b == null:
		return
	var q: Dictionary = _p["params"]
	var s_a: int = q["s_a"]
	var s_b: int = q["s_b"]
	var h: int = q["h"]
	var a_miles := s_a * _a_hours
	var b_hours: float = maxf(0.0, _a_hours - float(h))
	var b_miles := s_b * b_hours

	var ax := X0 + a_miles * _ppm
	var bx := X0 + b_miles * _ppm
	_train_a.position = Vector2(ax, RAIL_A_Y - _train_a.size.y + 10)
	_train_b.position = Vector2(bx, RAIL_B_Y - _train_b.size.y + 10)

	_lbl_a.text = "%d mi" % roundi(a_miles)
	_lbl_a.position = Vector2(ax, RAIL_A_Y - _train_a.size.y - 20)
	_lbl_b.text = "%d mi" % roundi(b_miles)
	_lbl_b.position = Vector2(bx, RAIL_B_Y - _train_b.size.y - 20)

	_hour.text = "%d hour%s after the blue train left" % [
		roundi(b_hours), "" if roundi(b_hours) == 1 else "s"]

	if not _caught and b_miles >= a_miles and _a_hours > float(h) + 0.01:
		_caught = true
		_catch.visible = true
		Narrator.speak("The blue train caught up! Now it speeds ahead.")

func _finish_sim() -> void:
	_running = false
	_done = true
	_place_trains()
	var q: Dictionary = _p["params"]
	var s_a: int = q["s_a"]
	var s_b: int = q["s_b"]
	var h: int = q["h"]
	var t: int = q["t"]
	var d_a := (t + h) * s_a
	var d_b := t * s_b
	var gap := d_b - d_a
	_eq.text = "Blue %d  \u2212  Red %d  =  %d miles ahead" % [d_b, d_a, gap]
	_end_lbl.text = "Blue is %d miles ahead of Red!" % gap
	_end.visible = true
	_hint.text = "\u2713 done"
	Narrator.speak("After %d hours, the blue train is %d miles ahead of the red train." % [t, gap])
	finished.emit()

func _on_input(event: InputEvent) -> void:
	var tap: bool = (event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventScreenTouch and event.pressed)
	if tap and not _done:
		Narrator.stop()
		_a_hours = _total_a
		_finish_sim()

func _draw() -> void:
	# Two parallel rails from the station out to the right, with sleepers.
	for y in [RAIL_A_Y, RAIL_B_Y]:
		draw_line(Vector2(X0 - 30, y + 12), Vector2(X_RIGHT, y + 12), Color(0.5, 0.53, 0.6), 5.0)
		var x := X0 - 20
		while x < X_RIGHT:
			draw_line(Vector2(x, y + 4), Vector2(x, y + 22), Color(0.36, 0.28, 0.22), 4.0)
			x += 34.0
	# Faint mile gridlines.
	if _p.has("params"):
		var d_b: int = int(_p["params"]["t"]) * int(_p["params"]["s_b"])
		var step := 50
		var m := step
		while m <= d_b:
			var gx := X0 + m * _ppm
			draw_line(Vector2(gx, 120), Vector2(gx, 440), Color(1, 1, 1, 0.06), 1.0)
			m += step

# ---- helpers ----------------------------------------------------------------

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

class_name GalacticView
extends Control
## StarLearner v0.0.4 — Time As Receipts, made playable.
##
## Every "Next Step" is an iteration encountering the galactic gradient.
## The gradient resists (n_score = R). The resistance IS the receipt.
## Time proceeds through resistance.  maitter = m · a · it(t,e,r)
##
## v0.0.4 additions (FMP atonement run / Time as Receipts):
##   • Field gradient background: deep blue (distant) → warm gold (nearby)  [Stage 0]
##   • Receipt ripple rings radiate from each star after each step           [Stage 1]
##   • Echo Mode past step 150: cat appends, journey continues as echoes     [ls/cat]
##   • YourMove handoff when Andromeda activates                             [Death poem]
##
## Data source: res://data/galactic_journey.jsonl  (150 steps × 9 arc stars)

signal go_home()

const JOURNEY_PATH    := "res://data/galactic_journey.jsonl"
const TWEEN_DURATION  := 0.55   ## seconds per step transition
const PARSECS_TO_PX   := 3.2    ## base scale: 1 pc = 3.2 px → 10pc star ≈ 32px from Sol
const SOL_LABEL       := "☀ Sol"
const ARC_STARS       := ["procyon","gomeisa","pollux","castor",
                           "capella","aldebaran","rigel","sirius","m44"]

var _steps: Array = []
var _current_step: int = 0
var _star_nodes: Dictionary = {}
var _tweens: Array = []

## v0.0.4: echo mode — past last step, loop echoes
var _echo_mode: bool = false
var _echo_offset: int = 0      ## wraps back to step 0 for echo replay
## v0.0.4: running receipt accumulator (Maitter dS sum)
var _receipt_total: float = 0.0
## v0.0.4: gradient background color driven by mean field
var _bg_field: float = 0.0     ## smoothed toward mean field each step

## HUD elements
var _step_label: Label
var _dist_label: Label
var _field_label: Label   ## v0.0.3: live n_score / field mirror readout
var _name_label: Label
var _next_btn: Button
var _home_btn: Button
var _sol_node: Node2D
var _viewport_center: Vector2

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_load_journey()
	_build_ui()
	_build_stars()
	if _steps.size() > 0:
		_apply_step(0, false)

func set_active(on: bool) -> void:
	visible = on
	set_process(on)
	set_process_input(on)

## ─── Data loading ─────────────────────────────────────────────────────────────
func _load_journey() -> void:
	_steps.clear()
	var f := FileAccess.open(JOURNEY_PATH, FileAccess.READ)
	if f == null:
		push_error("GalacticView: cannot open " + JOURNEY_PATH)
		return
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line.is_empty():
			continue
		var parsed := JSON.parse_string(line)
		if parsed is Dictionary:
			_steps.append(parsed)
	f.close()

## ─── Scene construction ───────────────────────────────────────────────────────
func _build_ui() -> void:
	# v0.0.4: background is painted in _draw() as field gradient (Stage 0 visual)
	# No static ColorRect — the gradient reacts to the field state each step.

	# Sol glyph at center
	_sol_node = Node2D.new()
	add_child(_sol_node)

	# HUD — top bar
	var hud_top := HBoxContainer.new()
	hud_top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hud_top.position = Vector2(12, 10)
	hud_top.size = Vector2(get_viewport().size.x - 24, 40)
	hud_top.add_theme_constant_override("separation", 20)
	add_child(hud_top)

	_name_label = Label.new()
	_name_label.text = "Galactic Free Flight"
	_name_label.add_theme_font_size_override("font_size", 26)
	_name_label.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	hud_top.add_child(_name_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud_top.add_child(spacer)

	_step_label = Label.new()
	_step_label.add_theme_font_size_override("font_size", 20)
	_step_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	hud_top.add_child(_step_label)

	# HUD — bottom bar
	var hud_bot := HBoxContainer.new()
	hud_bot.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hud_bot.offset_top = -60
	hud_bot.position.x = 12
	hud_bot.size.x = get_viewport().size.x - 24
	hud_bot.add_theme_constant_override("separation", 16)
	add_child(hud_bot)

	_home_btn = Button.new()
	_home_btn.text = "← Home"
	_home_btn.add_theme_font_size_override("font_size", 22)
	_home_btn.pressed.connect(_on_home)
	hud_bot.add_child(_home_btn)

	_dist_label = Label.new()
	_dist_label.add_theme_font_size_override("font_size", 19)
	_dist_label.add_theme_color_override("font_color", Color(0.8, 0.9, 0.7))
	hud_bot.add_child(_dist_label)

	# v0.0.3: field mirror readout (n_score + mean field)
	_field_label = Label.new()
	_field_label.add_theme_font_size_override("font_size", 16)
	_field_label.add_theme_color_override("font_color", Color(0.5, 0.8, 0.6, 0.9))
	hud_bot.add_child(_field_label)

	var spacer2 := Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud_bot.add_child(spacer2)

	_next_btn = Button.new()
	_next_btn.text = "Next Step →"
	_next_btn.add_theme_font_size_override("font_size", 24)
	_next_btn.pressed.connect(_on_next)
	hud_bot.add_child(_next_btn)

func _build_stars() -> void:
	for star_name in ARC_STARS:
		var node := GalacticStarNode.new()
		node.star_name = star_name
		node.visible = false
		_star_nodes[star_name] = node
		add_child(node)

## ─── Step logic ───────────────────────────────────────────────────────────────
func _apply_step(idx: int, animated: bool) -> void:
	if _steps.is_empty():
		return
	idx = clampi(idx, 0, _steps.size() - 1)
	_current_step = idx
	var snap: Dictionary = _steps[idx]

	# Cancel active tweens
	for tw in _tweens:
		if is_instance_valid(tw):
			tw.kill()
	_tweens.clear()

	var vp_size := get_viewport().size
	_viewport_center = vp_size * 0.5

	# Update Sol glyph (drawn in _draw of sol_node)
	_sol_node.position = _viewport_center

	# Update each star
	for star_name in ARC_STARS:
		var s: Dictionary = snap.get("stars", {}).get(star_name, {})
		if s.is_empty():
			continue
		var xyz: Array = s.get("xyz_pc", [0.0, 0.0, 0.0])
		var field: float = float(s.get("field", 0.05))
		var n_score: float = float(s.get("n_score", 0.0))
		var target_px := _to_screen(xyz[0], xyz[2])

		var node: GalacticStarNode = _star_nodes[star_name]
		node.field_strength = field
		node.visible = true

		if animated:
			var tw := create_tween()
			tw.tween_property(node, "position", target_px, TWEEN_DURATION) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
			_tweens.append(tw)
			# v0.0.4: receipt flash — fires after tween completes
			if animated:
				tw.tween_callback(node.receipt_flash.bind(n_score))
		else:
			node.position = target_px

	_update_hud(snap)

func _to_screen(x_pc: float, z_pc: float) -> Vector2:
	## x-z plane, Sol at center. +x right, +z up (same as our ASCII map).
	return _viewport_center + Vector2(x_pc * PARSECS_TO_PX, -z_pc * PARSECS_TO_PX)

func _update_hud(snap: Dictionary) -> void:
	var step: int = int(snap.get("step", _current_step + 1))
	var total: int = _steps.size()
	var step_str := "Step %d / %d" % [step, total]
	if _echo_mode:
		step_str = "Echo %d / %d" % [step, total]
	_step_label.text = step_str

	var pxyz: Array = snap.get("player_xyz_pc", [0.0, 0.0, 0.0])
	var player_dist := sqrt(pxyz[0]*pxyz[0] + pxyz[1]*pxyz[1] + pxyz[2]*pxyz[2])
	var ly := player_dist * 3.262
	_dist_label.text = "Sol: %.2f pc (%.2f ly)" % [player_dist, ly]

	# v0.0.4: compute mean field + best n_score, accumulate receipt total
	var stars_snap: Dictionary = snap.get("stars", {})
	var total_field := 0.0
	var best_n := -999.0
	var best_star := ""
	var n_active := 0
	for sname in stars_snap:
		var sd: Dictionary = stars_snap[sname]
		var f := float(sd.get("field", 0.0))
		var ns := float(sd.get("n_score", -999.0))
		total_field += f
		n_active += 1
		if ns > best_n:
			best_n = ns
			best_star = sname
	var mean_field := total_field / max(1, n_active)
	_bg_field = lerpf(_bg_field, mean_field, 0.3)  # smooth toward target

	if best_star != "" and best_n > -10.0:
		_receipt_total += absf(best_n)
		_field_label.text = "R %.3f  |  dS %.1f" % [best_n, _receipt_total]
	else:
		_field_label.text = "field %.2f" % mean_field

	var andromeda: bool = bool(snap.get("andromeda_active", false))
	if andromeda:
		# v0.0.4: .YourMove handoff — Death poem
		_name_label.text = "(.YourMove)  🌀 Andromeda"
	elif _echo_mode:
		_name_label.text = "Echo Mode — cat appends"
	else:
		_name_label.text = "Galactic Free Flight"

	# v0.0.4: never fully disable Next — echo mode continues
	var at_end := (_current_step >= _steps.size() - 1) and not _echo_mode
	_next_btn.disabled = false  # always enabled
	if _current_step >= _steps.size() - 1 and not _echo_mode:
		_next_btn.text = "Echo →"
	elif _echo_mode:
		_next_btn.text = "Echo →"
	else:
		_next_btn.text = "Next Step →"

## ─── Input ────────────────────────────────────────────────────────────────────
func _on_next() -> void:
	if _current_step < _steps.size() - 1:
		_apply_step(_current_step + 1, true)
	else:
		# v0.0.4: Echo Mode — cat appends, journey loops as echoes
		_echo_mode = true
		_echo_offset = (_echo_offset + 1) % _steps.size()
		_apply_step(_echo_offset, true)

func _on_home() -> void:
	go_home.emit()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_RIGHT, KEY_SPACE, KEY_ENTER:
				_on_next()
			KEY_LEFT:
				if _current_step > 0:
					_apply_step(_current_step - 1, true)
			KEY_ESCAPE:
				_on_home()

## ─── Sol draw / field gradient background ────────────────────────────────────
func _draw() -> void:
	if not visible:
		return
	var cx := _viewport_center
	var vp := get_viewport().size

	# v0.0.4: Field gradient background (Stage 0 visual)
	# Deep blue (field≈0, distant stars) → warm gold (field≈1, nearby stars)
	# The gradient IS the theory: structure emerges from the field.
	var field_t := clampf(_bg_field, 0.0, 1.0)
	var col_deep  := Color(0.02, 0.02, 0.06)          # deep space blue (ungoverned)
	var col_near  := Color(0.12, 0.09, 0.02)          # warm gold-black (structure)
	var bg_col    := col_deep.lerp(col_near, field_t * field_t)  # quadratic for drama
	draw_rect(Rect2(Vector2.ZERO, vp), bg_col)

	# Sol glow rings
	draw_circle(cx, 22.0, Color(1.0, 0.95, 0.4, 0.08))
	draw_circle(cx, 14.0, Color(1.0, 0.92, 0.3, 0.18))
	draw_circle(cx, 8.0,  Color(1.0, 0.95, 0.5, 0.7))
	draw_circle(cx, 5.0,  Color(1.0, 1.0,  0.8, 1.0))
	draw_string(ThemeDB.fallback_font, cx + Vector2(10, -10), SOL_LABEL,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.95, 0.6))

	# Scale bar: 50 pc
	var bar_start := cx + Vector2(-120, vp.y * 0.5 - 90)
	var bar_end := bar_start + Vector2(50 * PARSECS_TO_PX, 0)
	draw_line(bar_start, bar_end, Color(0.6, 0.7, 0.8, 0.7), 2)
	draw_line(bar_start + Vector2(0,-4), bar_start + Vector2(0,4), Color(0.6,0.7,0.8,0.7), 2)
	draw_line(bar_end + Vector2(0,-4), bar_end + Vector2(0,4), Color(0.6,0.7,0.8,0.7), 2)
	draw_string(ThemeDB.fallback_font, bar_start + Vector2(0, 16), "50 pc",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.6, 0.7, 0.8, 0.7))

func _process(_delta: float) -> void:
	queue_redraw()

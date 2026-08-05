class_name PropulsionChooser
extends Control
## Rocket-science engine pick BEFORE the course is charted.
## Three tiles: Chemical · Nuclear thermal · Nuclear pulse.
## Procedural accompaniment panels (flame / reactor glow / pulse plate)
## play with each engine's VO — not a raytracer or image pipeline.

signal propulsion_picked(propulsion_id: String)
signal go_home()

const LINE_CHEM := "Chemical rockets burn cold fuel with oxygen — a carefully packed fire in a bottle. They push hard, but most of the rocket has to be fuel."
const LINE_NTP := "Nuclear thermal uses a reactor to make hydrogen scream out the nozzle — about twice as thrifty as chemical. Scientists have tested it on the ground; it hasn't flown yet."
const LINE_ORION := "Nuclear pulse is a future idea — little controlled bangs push a giant plate, so you get huge thrust and much less of the ship has to be fuel!"

const CHEM_TEX := "res://images/tile_mission.png"
const NTP_TEX := "res://images/tile_cruise_stop.png"
const ORION_TEX := "res://images/tile_free_flight.png"
const GOLD := Color(1.0, 0.86, 0.28, 1.0)

var _chem_btn: Button
var _ntp_btn: Button
var _orion_btn: Button
var _chem_tint: Color = Color(0.38, 0.22, 0.14)
var _ntp_tint: Color = Color(0.16, 0.34, 0.42)
var _orion_tint: Color = Color(0.28, 0.18, 0.42)
var _narr_gen: int = 0
var _title: Label
var _viz: _PropulsionViz

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.04, 0.10, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var center_wrap := CenterContainer.new()
	center_wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center_wrap)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	box.custom_minimum_size = Vector2(1180, 540)
	center_wrap.add_child(box)

	_title = Label.new()
	_title.text = "Pick your engines"
	_title.add_theme_font_size_override("font_size", 36)
	_title.add_theme_color_override("font_color", Color(1, 1, 1))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)

	_viz = _PropulsionViz.new()
	_viz.custom_minimum_size = Vector2(420, 72)
	_viz.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(_viz)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)
	box.add_child(row)

	var chem_col := _make_tile(
		"Chemical",
		"Today's rockets — mostly fuel",
		CHEM_TEX,
		_chem_tint,
		func() -> void:
			_narr_gen += 1
			Narrator.stop()
			propulsion_picked.emit(AstrogatorPanel.PROP_CHEMICAL))
	_chem_btn = chem_col.get_node("TileButton") as Button
	row.add_child(chem_col)

	var ntp_col := _make_tile(
		"Nuclear thermal",
		"Reactor heat — thriftier",
		NTP_TEX,
		_ntp_tint,
		func() -> void:
			_narr_gen += 1
			Narrator.stop()
			propulsion_picked.emit(AstrogatorPanel.PROP_NTP))
	_ntp_btn = ntp_col.get_node("TileButton") as Button
	row.add_child(ntp_col)

	var orion_col := _make_tile(
		"Nuclear pulse",
		"Future ship — more ship, less fuel",
		ORION_TEX,
		_orion_tint,
		func() -> void:
			_narr_gen += 1
			Narrator.stop()
			propulsion_picked.emit(AstrogatorPanel.PROP_ORION))
	_orion_btn = orion_col.get_node("TileButton") as Button
	row.add_child(orion_col)

	var back := Button.new()
	back.text = "\u25C0"
	back.size = Vector2(84, 66)
	back.position = Vector2(20, 20)
	back.focus_mode = Control.FOCUS_NONE
	back.add_theme_font_size_override("font_size", 28)
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color(0.95, 0.86, 0.45, 0.98)
	bsb.set_corner_radius_all(16)
	back.add_theme_stylebox_override("normal", bsb)
	back.pressed.connect(func() -> void:
		_narr_gen += 1
		Narrator.stop()
		go_home.emit())
	add_child(back)

func begin_for(dest_name: String) -> void:
	_title.text = "Engines for %s" % (
		dest_name if not dest_name.is_empty() else "this trip")
	set_active(true)

func set_active(on: bool) -> void:
	visible = on
	mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE
	_narr_gen += 1
	if on:
		_narrate(_narr_gen)
	else:
		Narrator.stop()
		if _viz != null:
			_viz.set_mode("")
		_set_outline(_chem_btn, _chem_tint, false)
		_set_outline(_ntp_btn, _ntp_tint, false)
		_set_outline(_orion_btn, _orion_tint, false)

func _narrate(gen: int) -> void:
	await get_tree().create_timer(0.35).timeout
	if gen != _narr_gen or not visible:
		return
	_set_outline(_chem_btn, _chem_tint, true)
	_set_outline(_ntp_btn, _ntp_tint, false)
	_set_outline(_orion_btn, _orion_tint, false)
	_viz.set_mode(AstrogatorPanel.PROP_CHEMICAL)
	var d1 := Narrator.speak(LINE_CHEM)
	await _await_vo(gen, d1)
	if gen != _narr_gen or not visible:
		return
	_set_outline(_chem_btn, _chem_tint, false)
	_set_outline(_ntp_btn, _ntp_tint, true)
	_viz.set_mode(AstrogatorPanel.PROP_NTP)
	var d2 := Narrator.speak(LINE_NTP)
	await _await_vo(gen, d2)
	if gen != _narr_gen or not visible:
		return
	_set_outline(_ntp_btn, _ntp_tint, false)
	_set_outline(_orion_btn, _orion_tint, true)
	_viz.set_mode(AstrogatorPanel.PROP_ORION)
	var d3 := Narrator.speak(LINE_ORION)
	await _await_vo(gen, d3)
	if gen != _narr_gen or not visible:
		return
	await get_tree().create_timer(0.45).timeout
	if gen != _narr_gen:
		return
	_set_outline(_orion_btn, _orion_tint, false)
	_viz.set_mode("")

func _await_vo(gen: int, spoken_s: float = 0.0) -> void:
	await get_tree().process_frame
	var target: float = maxf(spoken_s, 3.5)
	var t := 0.0
	while t < target:
		if gen != _narr_gen:
			return
		if Narrator.is_playing():
			while Narrator.is_playing() and t < 24.0:
				if gen != _narr_gen:
					return
				await get_tree().create_timer(0.05).timeout
				t += 0.05
			if gen == _narr_gen:
				await get_tree().create_timer(0.35).timeout
			return
		await get_tree().create_timer(0.05).timeout
		t += 0.05

func _make_tile(label: String, hint: String, tex_path: String, tint: Color,
		on_press: Callable) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.custom_minimum_size = Vector2(360, 360)
	var btn := Button.new()
	btn.name = "TileButton"
	btn.custom_minimum_size = Vector2(360, 240)
	btn.focus_mode = Control.FOCUS_NONE
	btn.clip_contents = true
	_set_outline(btn, tint, false)
	btn.pressed.connect(on_press)
	col.add_child(btn)
	var pic := TextureRect.new()
	pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pic.offset_left = 6
	pic.offset_top = 6
	pic.offset_right = -6
	pic.offset_bottom = -6
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if ResourceLoader.exists(tex_path):
		pic.texture = load(tex_path)
	btn.add_child(pic)
	var name_lbl := Label.new()
	name_lbl.text = label
	name_lbl.add_theme_font_size_override("font_size", 24)
	name_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(name_lbl)
	var hint_lbl := Label.new()
	hint_lbl.text = hint
	hint_lbl.add_theme_font_size_override("font_size", 15)
	hint_lbl.add_theme_color_override("font_color", Color(0.72, 0.78, 0.95))
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_lbl.custom_minimum_size = Vector2(340, 0)
	col.add_child(hint_lbl)
	return col

func _set_outline(b: Button, tint: Color, gold: bool) -> void:
	if b == null:
		return
	b.add_theme_color_override("font_color", Color(0, 0, 0, 0))
	var sb := StyleBoxFlat.new()
	sb.bg_color = tint.lightened(0.06) if gold else tint
	sb.set_corner_radius_all(22)
	sb.set_border_width_all(6 if gold else 3)
	sb.border_color = GOLD if gold else Color(1, 1, 1, 0.55)
	sb.shadow_color = Color(0.95, 0.75, 0.2, 0.55) if gold else Color(0, 0, 0, 0.45)
	sb.shadow_size = 14 if gold else 10
	var hover := sb.duplicate() as StyleBoxFlat
	hover.border_color = GOLD
	var pressed := sb.duplicate() as StyleBoxFlat
	pressed.bg_color = tint.darkened(0.12)
	pressed.border_color = GOLD
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("focus", hover)
	b.add_theme_stylebox_override("pressed", pressed)


## Procedural 2D accompaniment: chemical flame, NTP glow, pulse-plate flash.
class _PropulsionViz extends Control:
	var mode: String = ""
	var _t: float = 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(420, 72)

	func set_mode(m: String) -> void:
		mode = m
		_t = 0.0
		queue_redraw()

	func _process(delta: float) -> void:
		if mode.is_empty() or not visible:
			return
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0.04, 0.06, 0.12, 0.55))
		if mode.is_empty():
			return
		var c := r.get_center()
		match mode:
			AstrogatorPanel.PROP_CHEMICAL:
				_draw_flame(c)
			AstrogatorPanel.PROP_NTP:
				_draw_reactor(c)
			AstrogatorPanel.PROP_ORION:
				_draw_pulse(c)

	func _draw_flame(c: Vector2) -> void:
		var flick: float = 0.65 + 0.35 * sin(_t * 14.0)
		for i in 5:
			var w: float = 10.0 + float(i) * 7.0
			var h: float = (28.0 - float(i) * 4.0) * flick
			var col := Color(1.0, 0.55 - float(i) * 0.08, 0.12, 0.85 - float(i) * 0.12)
			draw_circle(c + Vector2(0, 8 - float(i) * 3.0), w * 0.45, col)
			draw_rect(Rect2(c.x - w * 0.35, c.y - h * 0.2, w * 0.7, h), col)

	func _draw_reactor(c: Vector2) -> void:
		var pulse: float = 0.55 + 0.45 * (0.5 + 0.5 * sin(_t * 5.0))
		draw_circle(c, 28.0, Color(0.15, 0.55, 0.75, 0.35 * pulse))
		draw_circle(c, 16.0, Color(0.35, 0.95, 1.0, 0.55 * pulse))
		draw_circle(c, 7.0, Color(0.85, 1.0, 1.0, 0.95))
		for i in 6:
			var a: float = _t * 1.8 + float(i) * TAU / 6.0
			var p := c + Vector2(cos(a), sin(a)) * 34.0
			draw_circle(p, 3.0, Color(0.4, 0.9, 1.0, 0.7))

	func _draw_pulse(c: Vector2) -> void:
		# Push plate + expanding flash rings timed to a slow beat.
		var beat: float = fmod(_t, 1.15) / 1.15
		draw_rect(Rect2(c.x - 70, c.y - 8, 140, 16), Color(0.55, 0.5, 0.7, 0.9))
		draw_rect(Rect2(c.x - 78, c.y - 14, 12, 28), Color(0.75, 0.7, 0.9, 0.95))
		var ring_r: float = 12.0 + beat * 55.0
		var a: float = 0.85 * (1.0 - beat)
		draw_arc(c + Vector2(-72, 0), ring_r, 0.0, TAU, 40, Color(1.0, 0.7, 0.35, a), 3.0)
		if beat < 0.18:
			draw_circle(c + Vector2(-72, 0), 10.0, Color(1.0, 0.9, 0.5, 0.9))

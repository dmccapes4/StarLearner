class_name PlaygroundOrreryHud
extends Control
## Opaque Free Flight map HUD: orrery, tap-to-travel, constellation atlas.

const ConstellationDataScript := preload("res://scripts/ConstellationData.gd")

signal closed
signal travel_requested(body_id: String)
signal lights_toggled(on: bool)

const GOLD := Color(1.0, 0.86, 0.28, 1.0)
const LINE_TRAVEL := "Tap again to fly to %s."

enum Pane { ORRERY, GRID, LEARN, SCOPE }

var lights_on: bool = false
var _cfg: SolarFlyerConfig
var _clock: float = 0.0
var _ship_pos: Vector3 = Vector3.ZERO
var _heading: Vector3 = Vector3.FORWARD
var _spacing: float = 1.8
var _bodies: Array = []  ## SolarData flyer bodies (no belt ring)
var _pane: int = Pane.ORRERY
var _pick_id: String = ""
var _learn_id: String = ""
var _narr_gen: int = 0

var _dim: ColorRect
var _main: Control
var _orrery: OrreryMap
var _grid: ScrollContainer
var _grid_box: GridContainer
var _learn_tile: Button
var _learn_pic: TextureRect
var _learn_lbl: Label
var _scope: TextureRect
var _scope_lbl: Label
var _lights_btn: Button
var _atlas_btn: Button
var _back_btn: Button
var _hint: Label
var _travel: Control
var _travel_pic: TextureRect
var _travel_lbl: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_dim = ColorRect.new()
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0.03, 0.05, 0.10, 0.94)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)

	_hint = Label.new()
	_hint.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_hint.offset_top = 12
	_hint.offset_bottom = 44
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 20)
	_hint.add_theme_color_override("font_color", Color(0.88, 0.92, 1.0))
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)

	_main = Control.new()
	_main.set_anchors_preset(Control.PRESET_FULL_RECT)
	_main.offset_left = 130
	_main.offset_right = -130
	_main.offset_top = 52
	_main.offset_bottom = -88
	_main.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_main)

	_orrery = OrreryMap.new()
	_orrery.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_orrery.mouse_filter = Control.MOUSE_FILTER_STOP
	_orrery.picked.connect(_on_orrery_pick)
	_main.add_child(_orrery)

	_grid = ScrollContainer.new()
	_grid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_grid.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_grid.visible = false
	_main.add_child(_grid)
	_grid_box = GridContainer.new()
	_grid_box.columns = 2
	_grid_box.add_theme_constant_override("h_separation", 16)
	_grid_box.add_theme_constant_override("v_separation", 16)
	_grid_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_child(_grid_box)

	_learn_tile = Button.new()
	_learn_tile.set_anchors_preset(Control.PRESET_CENTER)
	_learn_tile.offset_left = -210
	_learn_tile.offset_right = 210
	_learn_tile.offset_top = -230
	_learn_tile.offset_bottom = 190
	_learn_tile.visible = false
	_learn_tile.focus_mode = Control.FOCUS_NONE
	_style_gold(_learn_tile, false)
	_learn_tile.pressed.connect(_on_learn_tap)
	_main.add_child(_learn_tile)
	_learn_pic = TextureRect.new()
	_learn_pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_learn_pic.offset_left = 16
	_learn_pic.offset_top = 16
	_learn_pic.offset_right = -16
	_learn_pic.offset_bottom = -52
	_learn_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_learn_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_learn_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_learn_tile.add_child(_learn_pic)
	_learn_lbl = Label.new()
	_learn_lbl.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_learn_lbl.offset_top = -48
	_learn_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_learn_lbl.add_theme_font_size_override("font_size", 22)
	_learn_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	_learn_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_learn_tile.add_child(_learn_lbl)

	_scope = TextureRect.new()
	_scope.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scope.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_scope.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_scope.visible = false
	_scope.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_main.add_child(_scope)
	_scope_lbl = Label.new()
	_scope_lbl.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_scope_lbl.offset_top = -36
	_scope_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_scope_lbl.add_theme_font_size_override("font_size", 16)
	_scope_lbl.add_theme_color_override("font_color", Color(0.85, 0.88, 0.7))
	_scope_lbl.text = "Research-telescope view"
	_scope_lbl.visible = false
	_scope_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_main.add_child(_scope_lbl)

	_travel = Control.new()
	_travel.set_anchors_preset(Control.PRESET_CENTER)
	_travel.offset_left = -160
	_travel.offset_right = 160
	_travel.offset_top = -180
	_travel.offset_bottom = 160
	_travel.visible = false
	_travel.mouse_filter = Control.MOUSE_FILTER_STOP
	_travel.gui_input.connect(_on_travel_input)
	_main.add_child(_travel)
	_travel_pic = TextureRect.new()
	_travel_pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_travel_pic.offset_left = 36
	_travel_pic.offset_top = 28
	_travel_pic.offset_right = -36
	_travel_pic.offset_bottom = -48
	_travel_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_travel_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_travel_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_travel.add_child(_travel_pic)
	var bull := BullseyeOverlay.new()
	bull.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bull.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_travel.add_child(bull)
	_travel_lbl = Label.new()
	_travel_lbl.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_travel_lbl.offset_top = -40
	_travel_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_travel_lbl.add_theme_font_size_override("font_size", 22)
	_travel_lbl.add_theme_color_override("font_color", Color(1, 0.95, 0.75))
	_travel_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_travel.add_child(_travel_lbl)

	_lights_btn = _make_side_tile("Lights", ConstellationDataScript.make_orion_tile())
	_lights_btn.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_lights_btn.offset_left = 18
	_lights_btn.offset_right = 138
	_lights_btn.offset_top = -168
	_lights_btn.offset_bottom = -48
	_lights_btn.pressed.connect(_on_lights)
	add_child(_lights_btn)

	_atlas_btn = _make_side_tile("Atlas", ConstellationDataScript.make_grid_preview_tile())
	_atlas_btn.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_atlas_btn.offset_left = 148
	_atlas_btn.offset_right = 268
	_atlas_btn.offset_top = -168
	_atlas_btn.offset_bottom = -48
	_atlas_btn.pressed.connect(_on_atlas)
	add_child(_atlas_btn)

	_back_btn = Button.new()
	_back_btn.text = "Map"
	_back_btn.visible = false
	_back_btn.focus_mode = Control.FOCUS_NONE
	_back_btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_back_btn.offset_left = 18
	_back_btn.offset_right = 110
	_back_btn.offset_top = 52
	_back_btn.offset_bottom = 100
	_style_gold(_back_btn, false)
	_back_btn.pressed.connect(_show_orrery)
	add_child(_back_btn)

	_fill_grid()


func open_hud(cfg: SolarFlyerConfig, bodies: Dictionary, clock: float,
		ship_pos: Vector3, heading: Vector3, spacing: float) -> void:
	_cfg = cfg
	_spacing = spacing
	_bodies = []
	for id in bodies:
		_bodies.append(bodies[id])
	sync(clock, ship_pos, heading)
	_show_orrery()
	visible = true
	_refresh_lights_btn()


func sync(clock: float, ship_pos: Vector3, heading: Vector3) -> void:
	_clock = clock
	_ship_pos = ship_pos
	_heading = heading
	if _orrery != null:
		_orrery.clock = clock
		_orrery.ship_pos = ship_pos
		_orrery.heading = heading
		_orrery.spacing = _spacing
		_orrery.cfg = _cfg
		_orrery.entries = _bodies
		_orrery.queue_redraw()


func close_hud() -> void:
	_narr_gen += 1
	visible = false
	_pick_id = ""
	_travel.visible = false


func _fill_grid() -> void:
	for child in _grid_box.get_children():
		child.queue_free()
	for data in ConstellationDataScript.all_constellations():
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(240, 240)
		btn.focus_mode = Control.FOCUS_NONE
		btn.clip_contents = true
		_style_gold(btn, false)
		var pic := TextureRect.new()
		pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		pic.offset_left = 10
		pic.offset_top = 10
		pic.offset_right = -10
		pic.offset_bottom = -36
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.texture = ConstellationDataScript.make_asterism_tile(data, 200, 180, true)
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(pic)
		var lab := Label.new()
		lab.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		lab.offset_top = -32
		lab.text = str(data["name"])
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.add_theme_font_size_override("font_size", 16)
		lab.add_theme_color_override("font_color", Color(1, 1, 1))
		lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(lab)
		var cid := str(data["id"])
		btn.pressed.connect(func() -> void: _open_learn(cid))
		_grid_box.add_child(btn)


func _show_orrery() -> void:
	_pane = Pane.ORRERY
	_orrery.visible = true
	_grid.visible = false
	_learn_tile.visible = false
	_scope.visible = false
	_scope_lbl.visible = false
	_travel.visible = false
	_back_btn.visible = false
	_pick_id = ""
	_hint.text = "Tap a world to travel · Atlas for constellations"


func _on_atlas() -> void:
	_pane = Pane.GRID
	_orrery.visible = false
	_grid.visible = true
	_learn_tile.visible = false
	_scope.visible = false
	_scope_lbl.visible = false
	_travel.visible = false
	_back_btn.visible = true
	_back_btn.text = "Map"
	_hint.text = "Tap a constellation"


func _open_learn(id: String) -> void:
	var data: Dictionary = ConstellationDataScript.by_id(id)
	if data.is_empty():
		return
	_learn_id = id
	_pane = Pane.LEARN
	_orrery.visible = false
	_grid.visible = false
	_scope.visible = false
	_scope_lbl.visible = false
	_learn_tile.visible = true
	_back_btn.visible = true
	_learn_pic.texture = ConstellationDataScript.make_asterism_tile(data, 360, 300, true)
	_learn_lbl.text = str(data["name"])
	_hint.text = str(data["line_ask"])
	Narrator.speak(str(data["line_ask"]))


func _on_learn_tap() -> void:
	if _pane != Pane.LEARN:
		return
	_open_scope(_learn_id)


func _open_scope(id: String) -> void:
	var data: Dictionary = ConstellationDataScript.by_id(id)
	if data.is_empty():
		return
	_pane = Pane.SCOPE
	_learn_tile.visible = false
	_scope.visible = true
	_scope_lbl.visible = true
	_scope.texture = ConstellationDataScript.make_telescope_plate(data)
	_hint.text = str(data["name"])
	_narr_gen += 1
	var gen := _narr_gen
	Narrator.speak(str(data["line_learn"]))
	_await_learn(gen)


func _await_learn(gen: int) -> void:
	await get_tree().process_frame
	var t := 0.0
	while Narrator.is_playing() and t < 40.0:
		if gen != _narr_gen or not visible:
			return
		await get_tree().create_timer(0.08).timeout
		t += 0.08
	if gen != _narr_gen or not visible:
		return
	_on_atlas()


func _on_lights() -> void:
	lights_on = not lights_on
	_refresh_lights_btn()
	lights_toggled.emit(lights_on)


func _refresh_lights_btn() -> void:
	_style_gold(_lights_btn, lights_on)
	if lights_on:
		_lights_btn.modulate = Color(1.12, 1.08, 0.9)
	else:
		_lights_btn.modulate = Color.WHITE


func _on_orrery_pick(id: String) -> void:
	var b := SolarData.flyer_body_by_id(id, _cfg)
	if b.is_empty():
		return
	_pick_id = id
	_travel.visible = true
	_orrery.visible = true
	var name := str(b.get("name", id))
	_travel_lbl.text = name
	var fallback: Color = b.get("color", Color(0.6, 0.7, 1.0)) as Color
	_travel_pic.texture = PlanetSkins.make_disc_texture(id, fallback, 140)
	_hint.text = LINE_TRAVEL % name
	Narrator.speak(LINE_TRAVEL % name)


func _on_travel_input(event: InputEvent) -> void:
	if _pick_id.is_empty():
		return
	var tap := false
	if event is InputEventScreenTouch and event.pressed:
		tap = true
	elif event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		tap = true
	if not tap:
		return
	accept_event()
	var dest := _pick_id
	close_hud()
	travel_requested.emit(dest)
	closed.emit()


func _make_side_tile(label: String, tex: Texture2D) -> Button:
	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_NONE
	btn.clip_contents = true
	_style_gold(btn, false)
	var pic := TextureRect.new()
	pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pic.offset_left = 8
	pic.offset_top = 8
	pic.offset_right = -8
	pic.offset_bottom = -26
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pic.texture = tex
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(pic)
	var lab := Label.new()
	lab.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	lab.offset_top = -24
	lab.text = label
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.add_theme_font_size_override("font_size", 14)
	lab.add_theme_color_override("font_color", Color(0.95, 0.92, 0.75))
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(lab)
	return btn


func _style_gold(b: Button, gold: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.12, 0.20, 0.96) if not gold \
		else Color(0.22, 0.20, 0.10, 0.98)
	sb.set_corner_radius_all(14)
	sb.set_border_width_all(4 if gold else 2)
	sb.border_color = GOLD if gold else Color(1, 1, 1, 0.35)
	b.add_theme_stylebox_override("normal", sb)
	var hover := sb.duplicate() as StyleBoxFlat
	hover.border_color = GOLD
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)


class OrreryMap:
	extends Control
	signal picked(id: String)
	var cfg: SolarFlyerConfig
	var clock: float = 0.0
	var ship_pos: Vector3 = Vector3.ZERO
	var heading: Vector3 = Vector3.FORWARD
	var spacing: float = 1.8
	var entries: Array = []
	var _hit: Array = []  ## {id, p}

	func _gui_input(event: InputEvent) -> void:
		var pos := Vector2.ZERO
		var tap := false
		if event is InputEventScreenTouch and event.pressed:
			tap = true
			pos = event.position
		elif event is InputEventMouseButton \
				and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			tap = true
			pos = event.position
		if not tap:
			return
		var best := ""
		var best_d := 36.0
		for h in _hit:
			var d: float = (h["p"] as Vector2).distance_to(pos)
			if d < best_d:
				best_d = d
				best = str(h["id"])
		if not best.is_empty():
			accept_event()
			picked.emit(best)

	func _draw() -> void:
		_hit.clear()
		if cfg == null:
			return
		var c := size * 0.5
		var max_r := 40.0
		for info in entries:
			var b: Dictionary = info["data"]
			var p: Vector3 = OrbitMath.body_pos(b, clock) * spacing
			max_r = maxf(max_r, Vector2(p.x, p.z).length())
		max_r = maxf(max_r, Vector2(ship_pos.x, ship_pos.z).length() * 1.05)
		var scale: float = minf(size.x, size.y) * 0.42 / maxf(max_r, 1.0)
		draw_arc(c, 6.0, 0.0, TAU, 32, Color(1.0, 0.82, 0.25, 0.35), 1.0, true)
		for info in entries:
			var b: Dictionary = info["data"]
			var wp: Vector3 = OrbitMath.body_pos(b, clock) * spacing
			var p := c + Vector2(wp.x, wp.z) * scale
			var id := str(b.get("id", ""))
			_hit.append({"id": id, "p": p})
			var tex: Texture2D = PlanetSkins.make_plain_icon(b, 48)
			var icon_s := 28.0 if bool(b.get("is_star", false)) else 22.0
			if tex != null:
				draw_texture_rect(tex, Rect2(p - Vector2(icon_s, icon_s) * 0.5,
					Vector2(icon_s, icon_s)), false)
		# Arcade ship — heading in the map plane.
		var sp := c + Vector2(ship_pos.x, ship_pos.z) * scale
		var flat := Vector2(heading.x, heading.z)
		if flat.length() < 0.01:
			flat = Vector2(0, -1)
		flat = flat.normalized()
		var ang: float = atan2(flat.y, flat.x)
		var ship := PackedVector2Array()
		var nose := Vector2(11, 0).rotated(ang)
		var left := Vector2(-7, 6).rotated(ang)
		var right := Vector2(-7, -6).rotated(ang)
		var notch := Vector2(-3, 0).rotated(ang)
		ship.append(sp + nose)
		ship.append(sp + left)
		ship.append(sp + notch)
		ship.append(sp + right)
		draw_colored_polygon(ship, Color(0.25, 0.92, 0.38, 0.98))


class BullseyeOverlay:
	extends Control

	func _draw() -> void:
		var c := size * 0.5
		var r: float = minf(size.x, size.y) * 0.38
		var col := Color(0.92, 0.18, 0.16, 0.95)
		draw_arc(c, r, 0.0, TAU, 64, col, 3.0, true)
		var tick: float = r * 0.16
		draw_line(c + Vector2(0, -r), c + Vector2(0, -r + tick), col, 3.0, true)
		draw_line(c + Vector2(0, r), c + Vector2(0, r - tick), col, 3.0, true)
		draw_line(c + Vector2(-r, 0), c + Vector2(-r + tick, 0), col, 3.0, true)
		draw_line(c + Vector2(r, 0), c + Vector2(r - tick, 0), col, 3.0, true)

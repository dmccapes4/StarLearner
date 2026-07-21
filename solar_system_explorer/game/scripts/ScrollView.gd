class_name ScrollView
extends Control
## Horizontal "piloting" strip: the Sun, eight planets, the asteroid belt, and
## Pluto. Swipe anywhere to scroll (including over planets). Tap a body to fly
## the ship there; on arrival the explore video opens. Tap empty space flies to
## the nearest body without opening video. Scrolling never moves the ship; the
## ship does not auto-follow the frame edge.

signal body_selected(id: String)
signal go_home()

const BodyCell := preload("res://scripts/BodyCell.gd")
const SHIP_PATH := "res://images/spaceship.png"
const VIEW_W := 1280.0        ## design-space width (1280x600, canvas_items stretch)
const DISC_STRIP_Y := 240.0   ## disc centre in strip coords (cell y 20 + DISC_Y 220)
const SHIP_W := 132.0
const SHIP_H := 82.0
const TAP_SLOP_PX := 28.0

var _scroll: ScrollContainer
var _strip: Control
var _ship: TextureRect
var _cells: Array = []
var _xs: Array = []
var _radii: Array = []
var _ids: Array = []
var _selected: int = -1
var _ship_id: String = "earth"
var _flying: bool = false
var _flight: Tween
var _pressing: bool = false
var _press_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_scroll = ScrollContainer.new()
	_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.gui_input.connect(_on_scroll_input)
	add_child(_scroll)

	var layout := SolarData.scroll_layout()
	_strip = Control.new()
	_strip.custom_minimum_size = Vector2(float(layout["width"]), 560)
	_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll.add_child(_strip)

	_xs = layout["xs"]
	var list := SolarData.bodies()
	for i in list.size():
		var cell := BodyCell.new()
		_strip.add_child(cell)
		cell.setup(list[i])
		cell.position = Vector2(float(_xs[i]) - cell.size.x * 0.5, 20)
		_cells.append(cell)
		_radii.append(float(list[i]["draw_radius"]))
		_ids.append(str(list[i]["id"]))

	_ship = TextureRect.new()
	var tex := load(SHIP_PATH)
	if tex != null:
		_ship.texture = tex
	_ship.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ship.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_ship.custom_minimum_size = Vector2(SHIP_W, SHIP_H)
	_ship.size = Vector2(SHIP_W, SHIP_H)
	_ship.pivot_offset = Vector2(SHIP_W * 0.5, SHIP_H * 0.5)
	_ship.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_strip.add_child(_ship)

	var header := Label.new()
	header.text = "Swipe to look around  \u2192  tap a planet to plot a course and fly"
	header.add_theme_font_size_override("font_size", 22)
	header.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	header.set_anchors_preset(Control.PRESET_TOP_WIDE)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.position = Vector2(0, 14)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(header)

	add_child(_make_home_button())

func set_ship_at(id: String) -> void:
	_ship_id = id if not id.is_empty() else "earth"

## Called when entering the piloting screen (after the astronaut briefing):
## park the ship above the current world and centre the view on it.
func begin_exploration() -> void:
	var start := _index_of(_ship_id)
	if start < 0:
		start = _index_of("earth")
	if start < 0:
		start = 0
	_selected = start
	_flying = false
	_ship.flip_h = false
	_ship.position = _ship_pos(start)
	_settle_center(start)

## Wait for the ScrollContainer to finish laying out before centring, otherwise
## scroll_horizontal is clamped to 0 (max not computed yet).
func _settle_center(i: int) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if is_inside_tree():
		_center_on(i, false)

func set_active(on: bool) -> void:
	if not on:
		Narrator.stop()
		if _flight != null and _flight.is_valid():
			_flight.kill()
		_flying = false
		_pressing = false

func _on_scroll_input(event: InputEvent) -> void:
	## Distinguish tap vs swipe. Never accept_event on press so ScrollContainer
	## keeps ownership of the drag.
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_pressing = true
			_press_pos = st.position
		else:
			if _pressing and st.position.distance_to(_press_pos) <= TAP_SLOP_PX:
				_handle_tap(_press_pos)
			_pressing = false
		return
	if event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if _pressing and sd.position.distance_to(_press_pos) > TAP_SLOP_PX:
			_pressing = false
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			_pressing = true
			_press_pos = mb.position
		else:
			if _pressing and mb.position.distance_to(_press_pos) <= TAP_SLOP_PX:
				_handle_tap(_press_pos)
			_pressing = false
		return
	if event is InputEventMouseMotion and _pressing:
		var mm := event as InputEventMouseMotion
		if mm.button_mask & MOUSE_BUTTON_MASK_LEFT:
			if mm.position.distance_to(_press_pos) > TAP_SLOP_PX:
				_pressing = false

func _handle_tap(scroll_local: Vector2) -> void:
	if _flying:
		return
	var strip_pt := Vector2(
		scroll_local.x + float(_scroll.scroll_horizontal),
		scroll_local.y)
	for i in _cells.size():
		var cell: BodyCell = _cells[i]
		var local: Vector2 = strip_pt - cell.position
		if cell.contains_local_point(local):
			_on_body_tapped(i)
			return
	# Empty space / frame edge: fly to nearest body, never open video.
	var best := _nearest_index(strip_pt.x)
	if best >= 0 and best != _selected:
		_fly_to(best, false)

func _on_body_tapped(i: int) -> void:
	if _flying:
		return
	# Already parked here → open immediately. Otherwise fly, then open on arrival.
	if i == _selected:
		body_selected.emit(_ids[i])
		return
	_fly_to(i, true)

func _nearest_index(strip_x: float) -> int:
	var best := -1
	var best_d := INF
	for i in _xs.size():
		var d: float = absf(float(_xs[i]) - strip_x)
		if d < best_d:
			best_d = d
			best = i
	return best

func _fly_to(i: int, open_video: bool = false) -> void:
	_flying = true
	var from: Vector2 = _ship.position
	var to: Vector2 = _ship_pos(i)
	_ship.flip_h = to.x < from.x          # nose points the way it's going
	var dist: float = absf(to.x - from.x)
	var dur: float = clampf(0.75 + dist * 0.0006, 0.75, 1.7)
	var target_scroll: float = clampf(float(_xs[i]) - VIEW_W * 0.5, 0.0, 1.0e6)

	_flight = create_tween()
	_flight.set_parallel(true)
	_flight.set_trans(Tween.TRANS_CUBIC)   # ease in/out = speed up, then slow down
	_flight.set_ease(Tween.EASE_IN_OUT)
	_flight.tween_property(_ship, "position", to, dur)
	_flight.tween_property(_scroll, "scroll_horizontal", int(round(target_scroll)), dur)
	# A little lift-and-settle wobble so the launch feels playful.
	_flight.tween_property(_ship, "rotation", deg_to_rad(-6.0 if to.x >= from.x else 6.0), dur * 0.4)
	_flight.chain().tween_property(_ship, "rotation", 0.0, dur * 0.25)
	_flight.chain().tween_callback(func() -> void:
		_selected = i
		_flying = false
		if open_video:
			body_selected.emit(_ids[i]))

func _ship_pos(i: int) -> Vector2:
	var r: float = float(_radii[i])
	var cy: float = clampf(DISC_STRIP_Y - r - 52.0, 34.0, 210.0)
	return Vector2(float(_xs[i]) - SHIP_W * 0.5, cy - SHIP_H * 0.5)

func _center_on(i: int, animate: bool) -> void:
	var target: int = int(round(clampf(float(_xs[i]) - VIEW_W * 0.5, 0.0, 1.0e6)))
	if animate:
		var tw := create_tween()
		tw.set_trans(Tween.TRANS_CUBIC)
		tw.set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(_scroll, "scroll_horizontal", target, 0.6)
	else:
		_scroll.scroll_horizontal = target

func _index_of(id: String) -> int:
	return _ids.find(id)

func _make_home_button() -> Button:
	var b := Button.new()
	b.text = "\u25C0"
	b.custom_minimum_size = Vector2(84, 66)
	b.size = Vector2(84, 66)
	b.position = Vector2(20, 20)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 28)
	b.add_theme_color_override("font_color", Color(0.06, 0.05, 0.02))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.95, 0.86, 0.45, 0.98)
	sb.set_corner_radius_all(16)
	sb.set_border_width_all(3)
	sb.border_color = Color(1, 1, 1, 0.9)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("focus", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.pressed.connect(func() -> void: go_home.emit())
	return b

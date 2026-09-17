class_name EarthShipScene
extends Control
## EarthShip mode: the hub for looking OUT from Earth instead of flying around.
##
## Five tiles, and the choice decides which viewer opens:
##
##   Mercury, Venus, Jupiter -> RetrogradeViewer  (a planet that loops)
##   Moon, Sun               -> EclipseViewer     (the two that line up)
##
## Everything offered here is visible to the naked eye, which is the whole
## constraint of the mode: no telescope, no markers, nothing on screen that a
## person standing in a field could not see for themselves.
##
## Mars is deliberately absent from the tiles even though it is the classic
## retrograde: the ship starts at Earth, and Mars already has its own arrival
## content in Free Flight. Requirement 1a names these five.

const PlanetSkinsScript := preload("res://scripts/PlanetSkins.gd")
const EphemerisScript := preload("res://scripts/Ephemeris.gd")

signal target_picked(body_id: String)
signal go_home()

## Tile order, left to right: the two inner planets that loop, the giant, then
## the two that eclipse.
const TILES: Array = [
	["mercury", "Mercury", "Quickest looper \u2014 back and forth in 3 weeks"],
	["venus", "Venus", "Brightest of all \u2014 loops every 19 months"],
	# Mars belongs at the front of this list, not the end of it. Its loop is the
	# widest of any planet -- several degrees of latitude, so it opens into a real
	# loop instead of the near-straight line Jupiter traces -- and it was Mars's
	# retrograde that ancient astronomers argued over for centuries. It is the
	# clearest example of the whole phenomenon.
	["mars", "Mars", "The widest loop of all \u2014 every 26 months"],
	["jupiter", "Jupiter", "Loops for 4 months at a time"],
	["moon", "Moon", "Phases, and the shadow that makes eclipses"],
	["sun", "Sun", "The light everything else is reflecting"],
]

## Bodies that open EclipseViewer rather than RetrogradeViewer.
const ECLIPSE_TARGETS: Array = ["moon", "sun"]

## Width available to the tile row, and the gap between tiles.
const ROW_W := 1240.0
const TILE_GAP := 10
const TILE_H := 300.0
## Height of the tile's image button; the label and hint sit below it.
const TILE_BTN_H := 190.0

## Tile width, DERIVED from how many tiles there are rather than hard-coded.
## A fixed width is how Mars came to be missing: the row was sized for exactly
## five tiles, so adding a sixth would have silently overflowed the screen, and
## the easy thing to do was leave it out. Deriving the width means the list of
## bodies is the only thing anyone has to edit.
static func tile_width() -> float:
	var n: int = maxi(TILES.size(), 1)
	return floorf((ROW_W - float(TILE_GAP * (n - 1))) / float(n))

const LINE_OPEN := "Here you stay on Earth and look up, the way people did for thousands of years before anyone had a telescope."
const LINE_LOOPERS := "Mercury, Venus, Mars and Jupiter each stop, back up, and loop \u2014 pick one and watch it happen. Mars makes the widest loop of the four."
const LINE_ECLIPSERS := "The Moon and the Sun are the two that line up, so they get their own view."

var _narr_gen: int = 0
var _btns: Dictionary = {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	visible = false

## True when picking this body should open EclipseViewer.
static func launches_eclipse(body_id: String) -> bool:
	return body_id in ECLIPSE_TARGETS

func set_active(on: bool) -> void:
	_narr_gen += 1
	visible = on
	if on:
		_narrate(_narr_gen)
	else:
		Narrator.stop()
		_clear_outlines()

func begin() -> void:
	set_active(true)

func _clear_outlines() -> void:
	for id in _btns:
		_set_outline(_btns[id] as Button, _tint_for(str(id)), false)

## Say what the mode is, then light the three loopers together and the two
## eclipsers together, so the split between the two viewers is visible as well
## as spoken.
func _narrate(gen: int) -> void:
	await get_tree().create_timer(0.3).timeout
	if gen != _narr_gen or not visible:
		return
	Narrator.speak(LINE_OPEN)
	await _await_vo(gen)
	if gen != _narr_gen or not visible:
		return
	_highlight(["mercury", "venus", "mars", "jupiter"])
	Narrator.speak(LINE_LOOPERS)
	await _await_vo(gen)
	if gen != _narr_gen or not visible:
		return
	_highlight(ECLIPSE_TARGETS)
	Narrator.speak(LINE_ECLIPSERS)
	await _await_vo(gen)
	if gen != _narr_gen or not visible:
		return
	_clear_outlines()

func _highlight(ids: Array) -> void:
	for id in _btns:
		_set_outline(_btns[id] as Button, _tint_for(str(id)), str(id) in ids)

func _await_vo(gen: int) -> void:
	await get_tree().process_frame
	var t := 0.0
	while Narrator.is_playing() and t < 14.0:
		if gen != _narr_gen:
			return
		await get_tree().create_timer(0.05).timeout
		t += 0.05
	if gen == _narr_gen:
		await get_tree().create_timer(0.3).timeout

func _build() -> void:
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

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 10)
	center.add_child(col)

	var title := Label.new()
	title.text = "Stand on Earth and look up"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(0.94, 0.96, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	var sub := Label.new()
	sub.text = "Pick something to watch. Everything here is visible without a telescope."
	sub.add_theme_font_size_override("font_size", 17)
	sub.add_theme_color_override("font_color", Color(0.66, 0.74, 0.90))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", TILE_GAP)
	col.add_child(row)
	for t in TILES:
		var id: String = str(t[0])
		var tile := _make_tile(id, str(t[1]), str(t[2]),
			func() -> void:
				_narr_gen += 1
				Narrator.stop()
				target_picked.emit(id))
		_btns[id] = tile.get_node("TileButton") as Button
		row.add_child(tile)

func _make_tile(body_id: String, label: String, hint: String,
		on_press: Callable) -> Control:
	var w: float = tile_width()
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.custom_minimum_size = Vector2(w, TILE_H)
	var btn := Button.new()
	btn.name = "TileButton"
	btn.custom_minimum_size = Vector2(w, TILE_BTN_H)
	btn.focus_mode = Control.FOCUS_NONE
	btn.clip_contents = true
	_set_outline(btn, _tint_for(body_id), false)
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
	# PlanetSkins already prefers a cinematic map and falls back to the
	# procedural skin, so the Moon tile works off the generated moon.png.
	var tex: Texture2D = PlanetSkinsScript.texture_for(body_id)
	if tex != null:
		pic.texture = tex
	btn.add_child(pic)
	var name_lbl := Label.new()
	name_lbl.text = label
	name_lbl.add_theme_font_size_override("font_size", 23)
	name_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(name_lbl)
	var hint_lbl := Label.new()
	hint_lbl.text = hint
	hint_lbl.add_theme_font_size_override("font_size", 14)
	hint_lbl.add_theme_color_override("font_color", Color(0.72, 0.78, 0.95))
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_lbl.custom_minimum_size = Vector2(w - 10.0, 58)
	col.add_child(hint_lbl)
	var kind := Label.new()
	kind.text = "eclipses" if launches_eclipse(body_id) else "retrograde"
	kind.add_theme_font_size_override("font_size", 13)
	kind.add_theme_color_override("font_color", Color(0.55, 0.62, 0.78))
	kind.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(kind)
	return col

func _tint_for(body_id: String) -> Color:
	match body_id:
		"mercury":
			return Color(0.80, 0.78, 0.74)
		"venus":
			return Color(1.0, 0.92, 0.62)
		"mars":
			return Color(0.94, 0.48, 0.30)
		"jupiter":
			return Color(1.0, 0.82, 0.55)
		"moon":
			return Color(0.86, 0.88, 0.94)
		"sun":
			return Color(1.0, 0.78, 0.30)
		_:
			return Color(0.7, 0.8, 1.0)

## Gold outline is the project's "this tile is being talked about" cue. The
## button's own text is transparent so the sibling Label is the visible one.
func _set_outline(btn: Button, tint: Color, on: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.09, 0.16, 0.92)
	sb.set_corner_radius_all(20)
	sb.border_color = Color(0.95, 0.86, 0.45, 0.98) if on \
		else Color(tint.r, tint.g, tint.b, 0.55)
	sb.set_border_width_all(6 if on else 3)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_color_override("font_color", Color(0, 0, 0, 0))

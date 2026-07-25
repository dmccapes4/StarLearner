class_name ShedUI
extends CanvasLayer
## Kid-simple shed: big seed tiles → tap once → narrate → close → holding that seed.
## Opening again replaces the held seed.

var seed_db: SeedDB
var sprites: FarmSprites
var _open: bool = false
var _selected: String = ""
var _panel: PanelContainer
var _grid: GridContainer
var _title: Label
var _held_chip: Label
var _held_icon: TextureRect
var _dim: ColorRect

func _ready() -> void:
	layer = 30
	_build()
	visible = true
	_panel.visible = false
	if _dim:
		_dim.visible = false

func setup(db: SeedDB, art: FarmSprites) -> void:
	seed_db = db
	sprites = art
	if sprites and sprites.has_method("set_seed_db"):
		sprites.set_seed_db(db)
	refresh()
	_refresh_held_chip()

func is_open() -> bool:
	return _open

func selected_seed() -> String:
	return _selected

func clear_selection() -> void:
	_selected = ""
	_refresh_held_chip()
	Events.seed_cleared.emit()

func open_shed() -> void:
	_open = true
	_panel.visible = true
	if _dim:
		_dim.visible = true
	refresh()
	Events.shed_opened.emit()

func close_shed() -> void:
	_open = false
	_panel.visible = false
	if _dim:
		_dim.visible = false
	Events.shed_closed.emit()

func set_harvest_totals(_totals: Dictionary) -> void:
	## Basket totals live in season VO; keep API for World.
	pass

func refresh() -> void:
	if seed_db == null or _grid == null:
		return
	for c in _grid.get_children():
		c.queue_free()
	var season := seed_db.current_season
	_title.text = "Pick a seed — %s" % season.capitalize()
	for pid in seed_db.available_seed_ids():
		_grid.add_child(_make_seed_button(pid))

func _build() -> void:
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_dim = ColorRect.new()
	_dim.name = "Dim"
	_dim.color = Color(0.05, 0.1, 0.06, 0.55)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.visible = false
	_dim.gui_input.connect(_on_dim_input)
	root.add_child(_dim)

	## Always-visible held seed chip (top center-left).
	var held_row := HBoxContainer.new()
	held_row.position = Vector2(88, 12)
	held_row.add_theme_constant_override("separation", 8)
	root.add_child(held_row)
	_held_icon = TextureRect.new()
	_held_icon.custom_minimum_size = Vector2(40, 40)
	_held_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_held_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_held_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	held_row.add_child(_held_icon)
	_held_chip = Label.new()
	_held_chip.name = "HeldChip"
	_held_chip.add_theme_font_size_override("font_size", 20)
	_held_chip.add_theme_color_override("font_color", Color(1, 0.95, 0.8, 0.95))
	held_row.add_child(_held_chip)

	_panel = PanelContainer.new()
	_panel.name = "ShedPanel"
	_panel.visible = false
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.offset_left = -340
	_panel.offset_right = 340
	_panel.offset_top = -220
	_panel.offset_bottom = 220
	_panel.custom_minimum_size = Vector2(680, 440)
	root.add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 16)
	_panel.add_child(margin)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	margin.add_child(v)

	_title = Label.new()
	_title.text = "Pick a seed"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 28)
	v.add_child(_title)

	var hint := Label.new()
	hint.text = "Tap a seed to take it. Tap outside to close."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 16)
	v.add_child(hint)

	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 14)
	_grid.add_theme_constant_override("v_separation", 14)
	_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(_grid)

func _on_dim_input(event: InputEvent) -> void:
	if not _open:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close_shed()

func _make_seed_button(plant_id: String) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(140, 140)
	btn.focus_mode = Control.FOCUS_NONE
	_style_seed_btn(btn, _selected == plant_id)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(box)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(72, 72)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if sprites:
		icon.texture = sprites.seed_icon(plant_id)
	if icon.texture == null:
		var fallback := ColorRect.new()
		fallback.custom_minimum_size = Vector2(72, 72)
		fallback.color = _plant_color(plant_id)
		fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(fallback)
	else:
		box.add_child(icon)
	var lbl := Label.new()
	lbl.text = seed_db.display_name(plant_id) if seed_db else plant_id
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(lbl)
	btn.pressed.connect(_on_seed_pressed.bind(plant_id))
	return btn

func _style_seed_btn(btn: Button, selected: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.18, 0.28, 0.16, 0.95) if not selected else Color(0.28, 0.38, 0.18, 0.98)
	sb.set_corner_radius_all(16)
	sb.set_border_width_all(4 if selected else 2)
	sb.border_color = Color(1.0, 0.85, 0.25, 1.0) if selected else Color(1, 1, 1, 0.25)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.add_theme_stylebox_override("pressed", sb)

func _on_seed_pressed(plant_id: String) -> void:
	## One tap: take the seed, close shed, narrate. Replaces any previous seed.
	_selected = plant_id
	_refresh_held_chip()
	close_shed()
	var name := seed_db.display_name(plant_id) if seed_db else plant_id
	var SpeakScript := preload("res://scripts/audio/Speak.gd")
	SpeakScript.line("You picked %s!" % name)
	Events.seed_selected.emit(plant_id)

func _refresh_held_chip() -> void:
	if _held_chip == null:
		return
	if _selected.is_empty():
		_held_chip.text = "Tap the shed for a seed"
		_held_chip.modulate = Color(1, 1, 1, 0.75)
		if _held_icon:
			_held_icon.texture = null
		return
	var name := seed_db.display_name(_selected) if seed_db else _selected
	_held_chip.text = "Holding %s — tap a bed to plant" % name
	_held_chip.modulate = Color(0.85, 1.0, 0.7, 1.0)
	if _held_icon and sprites:
		_held_icon.texture = sprites.seed_icon(_selected)

func _plant_color(plant_id: String) -> Color:
	var h := float(absi(plant_id.hash()) % 1000) / 1000.0
	return Color.from_hsv(h, 0.55, 0.85)

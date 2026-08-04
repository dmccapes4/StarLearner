class_name ShedUI
extends CanvasLayer
## Shed supplies: seed pouch · watering can · spade · return item.
## First open narrates the three tools with a gold outline pulse, then unlocks
## the fourth "return" tile. Seed pouch opens the seasonal seed catalog.

const SpeakScript := preload("res://scripts/audio/Speak.gd")

const TOOL_NONE := ""
const TOOL_SEED := "seed"
const TOOL_WATER := "water"
const TOOL_UPROOT := "uproot"

const TILE_SUPPLIES := "res://assets/ui/tile_supplies.png"
const TILE_SEED := "res://assets/ui/tile_seed_pouch.png"
const TILE_WATER := "res://assets/ui/tile_watering_can.png"
const TILE_SPADE := "res://assets/ui/tile_spade.png"
const TILE_RETURN := "res://assets/ui/tile_return_item.png"

var seed_db: SeedDB
var sprites: FarmSprites
var _open: bool = false
var _view: String = "tools" ## tools | seeds
var _tool: String = TOOL_NONE
var _selected: String = "" ## plant id when tool == seed
var _harvest_totals: Dictionary = {}
var _panel: PanelContainer
var _grid: GridContainer
var _footer: HBoxContainer
var _title: Label
var _held_chip: Label
var _held_icon: TextureRect
var _dim: ColorRect
var _tool_btns: Dictionary = {} ## tool_id -> Button
var _intro_playing: bool = false

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
	_refresh_held_chip()

func is_open() -> bool:
	return _open

func selected_seed() -> String:
	return _selected if _tool == TOOL_SEED else ""

func selected_tool() -> String:
	return _tool

func clear_selection() -> void:
	_tool = TOOL_NONE
	_selected = ""
	_refresh_held_chip()
	Events.seed_cleared.emit()
	Events.tool_changed.emit(TOOL_NONE)
	_persist_tool()

func set_tool(tool_id: String, plant_id: String = "") -> void:
	_tool = tool_id
	_selected = plant_id if tool_id == TOOL_SEED else ""
	_refresh_held_chip()
	if tool_id == TOOL_SEED and not plant_id.is_empty():
		Events.seed_selected.emit(plant_id)
	elif tool_id == TOOL_NONE:
		Events.seed_cleared.emit()
	Events.tool_changed.emit(tool_id)
	_persist_tool()

func restore_tool(tool_id: String, plant_id: String = "") -> void:
	## Boot restore — no VO; World suppresses seed-media ceremony while restoring.
	_tool = tool_id
	_selected = plant_id if tool_id == TOOL_SEED else ""
	_refresh_held_chip()
	Events.tool_changed.emit(_tool)
	if _tool == TOOL_SEED and not _selected.is_empty():
		Events.seed_selected.emit(_selected)
	elif _tool == TOOL_NONE:
		Events.seed_cleared.emit()
	elif _tool == TOOL_WATER or _tool == TOOL_UPROOT:
		## tool_changed may have been ignored if a seed sprite was still up.
		Events.seed_cleared.emit()
		Events.tool_changed.emit(_tool)

func _persist_tool() -> void:
	var save := get_node_or_null("/root/Save")
	if save and save.has_method("set_tool"):
		save.set_tool(_tool, _selected if _tool == TOOL_SEED else "")

func open_shed() -> void:
	_open = true
	_view = "tools"
	_panel.visible = true
	if _dim:
		_dim.visible = true
	refresh()
	Events.shed_opened.emit()
	var save := get_node_or_null("/root/Save")
	var first: bool = save != null and save.has_method("has_flag") \
		and not save.has_flag("shed_tools_intro")
	if first:
		_play_tools_intro()
	else:
		SpeakScript.line("Pick your supplies — seeds, water, or the spade. Return them to search for bugs and examine plants.")

func close_shed() -> void:
	_open = false
	_intro_playing = false
	_panel.visible = false
	if _dim:
		_dim.visible = false
	Events.shed_closed.emit()

func set_harvest_totals(totals: Dictionary) -> void:
	_harvest_totals = totals.duplicate()
	if _open and _view == "seeds":
		refresh()

func refresh() -> void:
	if _grid == null:
		return
	for c in _grid.get_children():
		c.queue_free()
	if _footer:
		for c in _footer.get_children():
			c.queue_free()
	_tool_btns.clear()
	if _view == "seeds":
		_title.text = "Pick a seed — %s" % (seed_db.current_season.capitalize() if seed_db else "")
		## Exactly 8 seasonal seeds → fixed 4×2, no scroll.
		_grid.columns = 4
		if seed_db:
			for pid in seed_db.available_seed_ids():
				_grid.add_child(_make_seed_button(pid))
		var back := _make_tool_button("back", "Back", TILE_RETURN)
		back.custom_minimum_size = Vector2(200, 88)
		for child in back.get_children():
			if child is VBoxContainer:
				for sub in child.get_children():
					if sub is TextureRect:
						sub.custom_minimum_size = Vector2(48, 48)
					elif sub is Label:
						sub.add_theme_font_size_override("font_size", 18)
		back.pressed.connect(_show_tools)
		if _footer:
			_footer.add_child(back)
		return
	_title.text = "Garden supplies"
	_grid.columns = 2
	_add_tool_tile(TOOL_SEED, "Seeds", TILE_SEED)
	_add_tool_tile(TOOL_WATER, "Water", TILE_WATER)
	_add_tool_tile(TOOL_UPROOT, "Spade", TILE_SPADE)
	_add_tool_tile(TOOL_NONE, "Hands free", TILE_RETURN)

func _add_tool_tile(tool_id: String, label: String, tex_path: String) -> void:
	var b := _make_tool_button(tool_id, label, tex_path)
	b.pressed.connect(_on_tool_pressed.bind(tool_id))
	_grid.add_child(b)
	_tool_btns[tool_id] = b

func _show_tools() -> void:
	_view = "tools"
	refresh()

func _on_tool_pressed(tool_id: String) -> void:
	if _intro_playing:
		return
	match tool_id:
		TOOL_SEED:
			_view = "seeds"
			refresh()
			SpeakScript.line("Choose a seed to plant.")
		TOOL_WATER:
			set_tool(TOOL_WATER)
			SpeakScript.line("You picked up the watering can. Tap a garden bed to water it.", true)
			close_shed()
		TOOL_UPROOT:
			set_tool(TOOL_UPROOT)
			SpeakScript.line("You picked up the spade. Tap a garden bed to uproot the plants.", true)
			close_shed()
		TOOL_NONE:
			clear_selection()
			SpeakScript.line("Hands free! Now you can search for bugs and examine your plants.", true)
			close_shed()

func _on_seed_pressed(plant_id: String) -> void:
	if seed_db and not seed_db.is_seed_available(plant_id):
		SpeakScript.line("That seed is out of season.")
		return
	set_tool(TOOL_SEED, plant_id)
	var name := seed_db.display_name(plant_id) if seed_db else plant_id
	var save := get_node_or_null("/root/Save")
	if save and save.has_method("set_flag"):
		save.set_flag("seed_collected:%s" % plant_id, true)
	SpeakScript.line("You picked %s! Tap an empty garden bed to plant it." % name, true)
	close_shed()

func _play_tools_intro() -> void:
	_intro_playing = true
	var save := get_node_or_null("/root/Save")
	if save and save.has_method("set_flag"):
		save.set_flag("shed_tools_intro", true)
	## Narrate each tool with a gold outline pulse.
	await _pulse_tool(TOOL_SEED, "Choose to plant seeds,")
	await _pulse_tool(TOOL_WATER, "water garden beds,")
	await _pulse_tool(TOOL_UPROOT, "or uproot plants.")
	await _pulse_tool(TOOL_NONE, "Return your supplies to search for bugs and examine plants.")
	_clear_gold()
	_intro_playing = false

func _pulse_tool(tool_id: String, line: String) -> void:
	_clear_gold()
	var b: Button = _tool_btns.get(tool_id, null)
	if b:
		_set_gold(b, true)
	var dur := SpeakScript.line(line)
	await get_tree().create_timer(maxf(dur, 1.0)).timeout

func _clear_gold() -> void:
	for k in _tool_btns.keys():
		_set_gold(_tool_btns[k], false)

func _set_gold(b: Button, on: bool) -> void:
	if b == null:
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.18, 0.12, 0.95)
	sb.set_corner_radius_all(14)
	sb.set_border_width_all(5 if on else 2)
	sb.border_color = Color(1.0, 0.82, 0.2, 1.0) if on else Color(0.35, 0.45, 0.3, 1.0)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)

func _refresh_held_chip() -> void:
	if _held_chip == null:
		return
	match _tool:
		TOOL_SEED:
			_held_chip.text = seed_db.display_name(_selected) if seed_db and not _selected.is_empty() else "Seed"
			_held_icon.texture = sprites.seed_icon(_selected) if sprites and not _selected.is_empty() else _tex(TILE_SEED)
		TOOL_WATER:
			_held_chip.text = "Watering can"
			_held_icon.texture = _tex("res://assets/ui/carry_watering_can.png")
		TOOL_UPROOT:
			_held_chip.text = "Spade"
			_held_icon.texture = _tex("res://assets/ui/carry_spade.png")
		_:
			_held_chip.text = "Tap the shed for supplies"
			_held_icon.texture = null

func _tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	if FileAccess.file_exists(path):
		var img := Image.load_from_file(path)
		if img:
			return ImageTexture.create_from_image(img)
	return null

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
	_panel.offset_left = -420
	_panel.offset_right = 420
	_panel.offset_top = -280
	_panel.offset_bottom = 280
	_panel.custom_minimum_size = Vector2(840, 560)
	root.add_child(_panel)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.2, 0.12, 0.97)
	sb.set_corner_radius_all(18)
	sb.set_border_width_all(3)
	sb.border_color = Color(0.45, 0.55, 0.3, 1)
	_panel.add_theme_stylebox_override("panel", sb)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_panel.add_child(v)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	v.add_child(margin)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 10)
	margin.add_child(inner)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 26)
	_title.add_theme_color_override("font_color", Color(1, 0.95, 0.75))
	inner.add_child(_title)

	## No ScrollContainer — seasonal catalog is a fixed 4×2.
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	inner.add_child(_grid)

	_footer = HBoxContainer.new()
	_footer.alignment = BoxContainer.ALIGNMENT_CENTER
	_footer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_child(_footer)

func _make_tool_button(id: String, label: String, tex_path: String) -> Button:
	var b := Button.new()
	b.name = "Tool_%s" % id
	b.custom_minimum_size = Vector2(280, 160)
	b.clip_text = true
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.18, 0.12, 0.95)
	sb.set_corner_radius_all(14)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.35, 0.45, 0.3, 1.0)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 6)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	b.add_child(box)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(96, 96)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.texture = _tex(tex_path)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon)
	var lab := Label.new()
	lab.text = label
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.add_theme_font_size_override("font_size", 22)
	lab.add_theme_color_override("font_color", Color(0.95, 0.95, 0.85))
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(lab)
	return b

func _make_seed_button(plant_id: String) -> Button:
	var b := Button.new()
	## Compact enough for a fixed 4×2 on a phone panel.
	b.custom_minimum_size = Vector2(168, 178)
	b.flat = true
	var collected := false
	var harvested := int(_harvest_totals.get(plant_id, 0)) > 0
	var save := get_node_or_null("/root/Save")
	if save and save.has_method("has_flag"):
		collected = save.has_flag("seed_collected:%s" % plant_id)
	## Tile PNG already has the panel — keep button chrome as a thin outline only.
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.set_corner_radius_all(16)
	sb.set_border_width_all(3 if harvested or collected else 0)
	if harvested:
		sb.border_color = Color(1.0, 0.82, 0.2, 1.0)
	elif collected:
		sb.border_color = Color(0.75, 0.78, 0.85, 1.0)
	sb.content_margin_left = 0
	sb.content_margin_right = 0
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)

	var icon := TextureRect.new()
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_bottom = -26
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if sprites:
		icon.texture = sprites.shed_pick_icon(plant_id) if sprites.has_method("shed_pick_icon") \
			else sprites.seed_icon(plant_id)
	b.add_child(icon)

	var lab := Label.new()
	lab.text = seed_db.display_name(plant_id) if seed_db else plant_id
	lab.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	lab.offset_top = -26
	lab.offset_bottom = -1
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.add_theme_font_size_override("font_size", 16)
	lab.add_theme_color_override("font_color", Color(1, 0.98, 0.88))
	lab.add_theme_color_override("font_outline_color", Color(0.05, 0.08, 0.04, 1))
	lab.add_theme_constant_override("outline_size", 4)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(lab)
	b.pressed.connect(_on_seed_pressed.bind(plant_id))
	return b

func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and not _intro_playing:
		if _view == "seeds":
			_show_tools()
		else:
			close_shed()

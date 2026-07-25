class_name PlantGrid
extends CanvasLayer
## First-harvest celebration — plant collection grid. Harvested plants are
## bright with a gold outline; the rest are grey silhouettes. Auto-closes.

signal grid_closed()

const SpeakScript := preload("res://scripts/audio/Speak.gd")

var seed_db: SeedDB
var sprites: FarmSprites
var _open: bool = false
var _hold_left: float = 0.0
var _root: Control
var _grid: GridContainer
var _title: Label

func _ready() -> void:
	add_to_group("plant_grid")
	layer = 42
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false
	set_process(false)

func setup(db: SeedDB, art: FarmSprites) -> void:
	seed_db = db
	sprites = art

func is_open() -> bool:
	return _open

func show_unlock(new_plant_id: String, harvest_totals: Dictionary) -> void:
	## No tap-to-exit: fixed hold so the gold unlock lands, then close.
	if seed_db == null:
		return
	_open = true
	visible = true
	_title.text = "%s joins your harvest!" % seed_db.display_name(new_plant_id)
	_rebuild(new_plant_id, harvest_totals)
	_hold_left = 4.0
	set_process(true)

func _process(delta: float) -> void:
	if not _open:
		return
	_hold_left -= delta
	if _hold_left <= 0.0:
		_open = false
		visible = false
		set_process(false)
		grid_closed.emit()

func _rebuild(new_plant_id: String, totals: Dictionary) -> void:
	for c in _grid.get_children():
		c.queue_free()
	for pid in seed_db.plant_order:
		var harvested := int(totals.get(pid, 0)) > 0
		_grid.add_child(_mk_cell(str(pid), harvested, str(pid) == new_plant_id))

func _mk_cell(pid: String, harvested: bool, is_new: bool) -> Control:
	var cell := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.16, 0.10, 0.95)
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(4 if is_new else 2)
	sb.border_color = Color(1.0, 0.84, 0.25, 1.0) if harvested else Color(0.30, 0.34, 0.30, 1.0)
	cell.add_theme_stylebox_override("panel", sb)
	cell.custom_minimum_size = Vector2(96, 108)

	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 2)
	cell.add_child(v)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(64, 64)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if sprites:
		icon.texture = sprites.harvest_icon(pid)
		if icon.texture == null:
			icon.texture = sprites.seed_icon(pid)
	icon.modulate = Color(1, 1, 1, 1) if harvested else Color(0.22, 0.22, 0.22, 0.9)
	v.add_child(icon)

	var lab := Label.new()
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.add_theme_font_size_override("font_size", 13)
	lab.add_theme_color_override("font_color",
		Color(1, 0.96, 0.85, 1) if harvested else Color(0.5, 0.5, 0.5, 1))
	lab.text = seed_db.display_name(pid) if harvested else "???"
	v.add_child(lab)
	return cell

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.08, 0.05, 0.66)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.process_mode = Node.PROCESS_MODE_ALWAYS
	_root.add_child(dim)

	var panel := VBoxContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_theme_constant_override("separation", 12)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(panel)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 32)
	_title.add_theme_color_override("font_color", Color(1, 0.9, 0.4, 1))
	panel.add_child(_title)

	_grid = GridContainer.new()
	_grid.columns = 6
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	panel.add_child(_grid)

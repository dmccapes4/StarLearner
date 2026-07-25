class_name BugGrid
extends CanvasLayer
## "You caught a {bug}!" collection view — 12-slot grid, grey silhouettes
## until caught; caught bugs bright with gold outline. Auto-closes.

const SpeakScript := preload("res://scripts/audio/Speak.gd")

var _open: bool = false
var _window_left: float = 0.0
var _narrating_left: float = 0.0
var _root: Control
var _dim: ColorRect
var _grid: GridContainer
var _title: Label
var bug_db: RefCounted
var sprites: FarmSprites

func _ready() -> void:
	add_to_group("bug_grid")
	layer = 42
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false
	set_process(false)

func setup(bugs: RefCounted, art: FarmSprites) -> void:
	bug_db = bugs
	sprites = art

func is_open() -> bool:
	return _open

func show_catch(new_bug_id: String) -> void:
	if bug_db == null:
		return
	_open = true
	visible = true
	var bname := new_bug_id.capitalize()
	var d: Dictionary = bug_db.get_bug(new_bug_id)
	if not d.is_empty():
		bname = str(d.get("name", bname))
	_title.text = "You caught a %s!" % bname
	_rebuild(new_bug_id)
	_narrating_left = SpeakScript.line("You caught a %s!" % bname)
	_window_left = Config.get_reveal_window_sec() if Config.has_method("get_reveal_window_sec") else 5.0
	set_process(true)

func close_grid() -> void:
	_open = false
	visible = false
	set_process(false)

func _process(delta: float) -> void:
	if not _open:
		return
	if _narrating_left > 0.0:
		_narrating_left -= delta
		return
	_window_left -= delta
	if _window_left <= 0.0:
		close_grid()

func _rebuild(new_bug_id: String) -> void:
	for c in _grid.get_children():
		c.queue_free()
	var save := _save()
	for b in bug_db.bugs:
		var d: Dictionary = b
		var bid := str(d.get("id", ""))
		var caught: bool = save != null and save.has_bug(bid)
		var is_new := bid == new_bug_id
		_grid.add_child(_mk_cell(d, caught, is_new))

func _mk_cell(bug: Dictionary, caught: bool, is_new: bool) -> Control:
	var cell := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.16, 0.10, 0.95)
	sb.set_corner_radius_all(12)
	sb.set_border_width_all(4 if is_new else 2)
	sb.border_color = Color(1.0, 0.84, 0.25, 1.0) if caught else Color(0.30, 0.34, 0.30, 1.0)
	cell.add_theme_stylebox_override("panel", sb)
	cell.custom_minimum_size = Vector2(120, 132)

	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 2)
	cell.add_child(v)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(88, 88)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	if sprites:
		icon.texture = sprites.portrait_texture(str(bug.get("portrait", "")))
	## Grey silhouette until discovered.
	icon.modulate = Color(1, 1, 1, 1) if caught else Color(0.22, 0.22, 0.22, 0.9)
	v.add_child(icon)

	var lab := Label.new()
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.add_theme_font_size_override("font_size", 14)
	lab.add_theme_color_override("font_color",
		Color(1, 0.96, 0.85, 1) if caught else Color(0.5, 0.5, 0.5, 1))
	lab.text = str(bug.get("name", "?")) if caught else "???"
	v.add_child(lab)
	return cell

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_root)

	_dim = ColorRect.new()
	_dim.color = Color(0.05, 0.08, 0.05, 0.62)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.process_mode = Node.PROCESS_MODE_ALWAYS
	_dim.gui_input.connect(_on_dim_input)
	_root.add_child(_dim)

	var panel := VBoxContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_theme_constant_override("separation", 14)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(panel)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 34)
	_title.add_theme_color_override("font_color", Color(1, 0.9, 0.4, 1))
	panel.add_child(_title)

	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	panel.add_child(_grid)

func _on_dim_input(event: InputEvent) -> void:
	if not _open or _narrating_left > 0.0:
		return
	if (event is InputEventScreenTouch and event.pressed) \
			or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		close_grid()

func _save() -> Node:
	var loop := Engine.get_main_loop() as SceneTree
	if loop == null:
		return null
	return loop.root.get_node_or_null("Save")

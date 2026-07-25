extends CanvasLayer
## Hamburger → two tabs: gardening concepts | seed catalog.
## Tap → narration; confirm within 5s. Grey tiles stay undiscovered if watched via peek path.

const DoubleTapArmScript := preload("res://scripts/ui/DoubleTapArm.gd")
const SpeakScript := preload("res://scripts/audio/Speak.gd")
const ARM_WINDOW := 5.0

var star_db
var progress
var seed_db: SeedDB
var _open: bool = false
var _tab: String = "concepts" ## concepts | seeds
var _panel: PanelContainer
var _title: Label
var _grid: GridContainer
var _tab_concepts: Button
var _tab_seeds: Button
var _tiles: Dictionary = {} ## key -> Button
var _arm = DoubleTapArmScript.new(ARM_WINDOW)
var _arm_step: Dictionary = {} ## key -> int step for grey flow

func _ready() -> void:
	layer = 20
	add_to_group("star_menu")
	_build()
	if not Events.hamburger_pressed.is_connected(_toggle):
		Events.hamburger_pressed.connect(_toggle)
	if not Events.star_revealed.is_connected(_on_progress_changed):
		Events.star_revealed.connect(_on_progress_changed)
	if not Events.star_collected.is_connected(_on_progress_changed):
		Events.star_collected.connect(_on_progress_changed)

func setup(db, prog, seeds: SeedDB = null) -> void:
	star_db = db
	progress = prog
	seed_db = seeds
	_rebuild_tiles()

func refresh() -> void:
	_rebuild_tiles()

func is_open() -> bool:
	return _open

func _build() -> void:
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var btn := Button.new()
	btn.name = "Hamburger"
	btn.text = "☰"
	btn.custom_minimum_size = Vector2(72, 72)
	btn.position = Vector2(12, 12)
	btn.add_theme_font_size_override("font_size", 32)
	btn.pressed.connect(func() -> void: Events.hamburger_pressed.emit())
	root.add_child(btn)

	_panel = PanelContainer.new()
	_panel.name = "Library"
	_panel.visible = false
	_panel.position = Vector2(12, 92)
	_panel.custom_minimum_size = Vector2(560, 420)
	root.add_child(_panel)

	var vbox := VBoxContainer.new()
	_panel.add_child(vbox)

	_title = Label.new()
	_title.text = "Garden Library"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 22)
	vbox.add_child(_title)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	vbox.add_child(tabs)
	_tab_concepts = _mk_tab("🌿 Concepts", "concepts")
	_tab_seeds = _mk_tab("🌱 Seeds", "seeds")
	tabs.add_child(_tab_concepts)
	tabs.add_child(_tab_seeds)

	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	vbox.add_child(_grid)

func _mk_tab(label: String, id: String) -> Button:
	var b := Button.new()
	b.text = label
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(160, 44)
	b.pressed.connect(_set_tab.bind(id))
	return b

func _set_tab(id: String) -> void:
	_tab = id
	_arm.clear()
	_arm_step.clear()
	_rebuild_tiles()

func _rebuild_tiles() -> void:
	for c in _grid.get_children():
		c.queue_free()
	_tiles.clear()
	if _tab == "seeds":
		_build_seed_tiles()
	else:
		_build_concept_tiles()
	_style_tabs()

func _style_tabs() -> void:
	if _tab_concepts:
		_tab_concepts.disabled = _tab == "concepts"
	if _tab_seeds:
		_tab_seeds.disabled = _tab == "seeds"

func _build_concept_tiles() -> void:
	_title.text = "Gardening Concepts"
	_grid.columns = 4
	if star_db == null:
		return
	for id in star_db.star_ids():
		var sid := str(id)
		var tile := _make_tile_button()
		tile.text = "★"
		var tex := _load_tex("res://assets/tiles/concepts/%s.png" % sid)
		if tex:
			tile.icon = tex
			tile.text = ""
			tile.expand_icon = true
		tile.pressed.connect(_on_concept.bind(sid))
		_grid.add_child(tile)
		_tiles[sid] = tile
		_style_concept(sid, tile)

func _build_seed_tiles() -> void:
	_title.text = "Seed Catalog"
	_grid.columns = 3
	if seed_db == null:
		return
	for pid in seed_db.plant_order:
		var plant_id := str(pid)
		var wrap := VBoxContainer.new()
		wrap.custom_minimum_size = Vector2(160, 150)
		var name_l := Label.new()
		name_l.text = seed_db.display_name(plant_id)
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_l.add_theme_font_size_override("font_size", 16)
		wrap.add_child(name_l)
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 6)
		wrap.add_child(row)
		for kind in ["seed", "sprout", "grown"]:
			var key := "%s:%s" % [plant_id, kind]
			var tile := _make_tile_button()
			tile.custom_minimum_size = Vector2(48, 48)
			tile.text = _kind_glyph(kind)
			tile.add_theme_font_size_override("font_size", 20)
			var tex := _load_tex("res://assets/tiles/plants/%s_%s.png" % [plant_id, kind])
			if tex == null:
				tex = _load_tex("res://assets/tiles/plants/%s.png" % plant_id)
			if tex:
				tile.icon = tex
				tile.text = ""
				tile.expand_icon = true
			tile.pressed.connect(_on_seed_media.bind(plant_id, kind))
			row.add_child(tile)
			_tiles[key] = tile
			_style_seed_media(plant_id, kind, tile)
		_grid.add_child(wrap)

func _make_tile_button() -> Button:
	var tile := Button.new()
	tile.custom_minimum_size = Vector2(100, 100)
	tile.focus_mode = Control.FOCUS_NONE
	tile.add_theme_font_size_override("font_size", 28)
	return tile

func _kind_glyph(kind: String) -> String:
	match kind:
		"seed":
			return "🌱"
		"sprout":
			return "🌿"
		_:
			return "🍅"

func _style_concept(star_id: String, tile: Button) -> void:
	var discovered: bool = progress != null and (progress.is_collected(star_id) or progress.is_revealed(star_id))
	_apply_chrome(tile, discovered)
	tile.tooltip_text = star_db.topic(star_id) if star_db else star_id

func _style_seed_media(plant_id: String, kind: String, tile: Button) -> void:
	var discovered: bool = _media_seen(plant_id, kind)
	_apply_chrome(tile, discovered)
	tile.tooltip_text = "%s (%s)" % [seed_db.display_name(plant_id), kind]

func _apply_chrome(tile: Button, discovered: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(12)
	sb.set_border_width_all(3)
	if discovered:
		sb.bg_color = Color(0.42, 0.55, 0.28, 0.95)
		sb.border_color = Color(0.85, 0.9, 0.4, 1)
		tile.modulate = Color(1, 1, 1, 1)
	else:
		sb.bg_color = Color(0.22, 0.22, 0.24, 0.9)
		sb.border_color = Color(0.4, 0.4, 0.42, 0.7)
		tile.modulate = Color(0.55, 0.55, 0.58, 1)
	tile.add_theme_stylebox_override("normal", sb)
	tile.add_theme_stylebox_override("hover", sb)
	tile.add_theme_stylebox_override("pressed", sb)

func _media_seen(plant_id: String, kind: String) -> bool:
	var save := _save()
	return save != null and save.has_flag("media:%s:%s" % [kind, plant_id])

func _mark_media(plant_id: String, kind: String) -> void:
	var save := _save()
	if save:
		save.set_flag("media:%s:%s" % [kind, plant_id], true)

func _save() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.root.get_node_or_null("/root/Save")

func _toggle() -> void:
	_open = not _open
	_panel.visible = _open
	if _open:
		refresh()
	else:
		_arm.clear()
		_arm_step.clear()
	Events.star_menu_visibility_changed.emit(_open)

func _on_progress_changed(_id: String = "") -> void:
	if _open:
		refresh()

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

func _on_concept(star_id: String) -> void:
	if progress == null or star_db == null:
		return
	_arm.poll(_now())
	var discovered: bool = progress.is_revealed(star_id) or progress.is_collected(star_id)
	var topic: String = str(star_db.topic(star_id))
	var key := "c:%s" % star_id
	if discovered:
		var r: String = _arm.press(key, _now())
		if r == DoubleTapArmScript.RESULT_TRIGGER:
			_play_concept(star_id, true)
		else:
			SpeakScript.line("%s. Tap again to watch." % topic)
		return
	## Grey / undiscovered multi-step
	var step := int(_arm_step.get(key, 0))
	var r2: String = _arm.press(key, _now())
	if r2 == DoubleTapArmScript.RESULT_ARMED and step == 0:
		SpeakScript.line("Not discovered yet. Tap again to learn how to unlock %s." % topic)
		Events.star_reveal_requested.emit(star_id)
		_arm_step[key] = 1
		return
	if r2 == DoubleTapArmScript.RESULT_TRIGGER and step == 1:
		_play_unlock_demo(star_id)
		_arm_step[key] = 2
		_arm.press(key, _now()) ## re-arm for peek
		SpeakScript.line("Tap again if you want to see the video without discovering it.")
		return
	if r2 == DoubleTapArmScript.RESULT_TRIGGER and step >= 2:
		_play_concept(star_id, false)
		_arm_step.erase(key)
		return
	## Fresh arm after timeout
	SpeakScript.line("Not discovered yet. Tap again to learn how to unlock %s." % topic)
	Events.star_reveal_requested.emit(star_id)
	_arm_step[key] = 1

func _on_seed_media(plant_id: String, kind: String) -> void:
	if seed_db == null:
		return
	_arm.poll(_now())
	var key := "s:%s:%s" % [plant_id, kind]
	var name: String = str(seed_db.display_name(plant_id))
	var blurb: String = str(seed_db.get_plant(plant_id).get("blurb", name))
	var discovered: bool = _media_seen(plant_id, kind)
	if discovered:
		var r: String = _arm.press(key, _now())
		if r == DoubleTapArmScript.RESULT_TRIGGER:
			_play_plant(plant_id, kind, false)
		else:
			SpeakScript.line("%s. %s Tap again to view." % [name, blurb])
		return
	var step := int(_arm_step.get(key, 0))
	var r2: String = _arm.press(key, _now())
	if r2 == DoubleTapArmScript.RESULT_ARMED and step == 0:
		SpeakScript.line("Not discovered yet. Grow a %s to the %s stage. Tap again for a tip." % [name, kind])
		_arm_step[key] = 1
		return
	if r2 == DoubleTapArmScript.RESULT_TRIGGER and step == 1:
		_play_seed_unlock_demo(plant_id, kind)
		_arm_step[key] = 2
		_arm.press(key, _now())
		SpeakScript.line("Tap again to peek at the video without discovering it.")
		return
	if r2 == DoubleTapArmScript.RESULT_TRIGGER and step >= 2:
		_play_plant(plant_id, kind, false)
		_arm_step.erase(key)
		return
	SpeakScript.line("Not discovered yet. Grow a %s to the %s stage. Tap again for a tip." % [name, kind])
	_arm_step[key] = 1

func _play_concept(star_id: String, collect_after: bool) -> void:
	var video := get_tree().get_first_node_in_group("video_panel")
	var topic: String = str(star_db.topic(star_id))
	var ok := false
	if video and video.has_method("play_star"):
		ok = bool(video.call("play_star", star_id, star_db.file_name(star_id), topic))
	if not ok:
		var media := get_tree().get_first_node_in_group("media_panel")
		if media and media.has_method("play_file"):
			media.call("play_file", "concept:%s" % star_id, "", topic)
	if collect_after and progress and not progress.is_collected(star_id):
		if progress.collect(star_id):
			Events.star_collected.emit(star_id)
			print("Garden Explorer: collected star %s" % star_id)
	refresh()

func _play_plant(plant_id: String, kind: String, discover: bool) -> void:
	var media := get_tree().get_first_node_in_group("media_panel")
	if media and media.has_method("play_plant"):
		media.call("play_plant", plant_id, kind)
	if discover:
		_mark_media(plant_id, kind)
	refresh()

func _play_unlock_demo(star_id: String) -> void:
	var media := get_tree().get_first_node_in_group("media_panel")
	var hint: String = str(progress.unlock_hint(star_id) if progress else "Keep exploring the garden.")
	var guide: String = str(progress.guidance_line(star_id) if progress else "")
	var lines := PackedStringArray([
		hint,
		guide if not guide.is_empty() else "Follow the gold outline in the garden.",
		"Do that action in the garden to discover this video for real.",
	])
	if media and media.has_method("play_unlock_demo"):
		media.call("play_unlock_demo", "How to unlock", lines)
	Events.star_reveal_requested.emit(star_id)

func _play_seed_unlock_demo(plant_id: String, kind: String) -> void:
	var media := get_tree().get_first_node_in_group("media_panel")
	var name: String = str(seed_db.display_name(plant_id))
	var lines := PackedStringArray()
	match kind:
		"seed":
			lines = PackedStringArray([
				"Open the shed and pick up a %s seed." % name,
				"The first time you collect that seed, its seed video unlocks.",
			])
		"sprout":
			lines = PackedStringArray([
				"Plant a %s seed and water it when the blue drop appears." % name,
				"When it sprouts, tap the plant to watch the sprout video.",
			])
		_:
			lines = PackedStringArray([
				"Keep watering your %s when it is thirsty." % name,
				"When it is fully grown, tap the harvest icon to watch its grown video.",
			])
	if media and media.has_method("play_unlock_demo"):
		media.call("play_unlock_demo", "How to discover %s" % name, lines)

func _load_tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path) or FileAccess.file_exists(ProjectSettings.globalize_path(path)):
		var t = load(path)
		if t is Texture2D:
			return t
	return null

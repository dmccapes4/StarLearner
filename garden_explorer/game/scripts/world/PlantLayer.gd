class_name PlantLayer
extends Node2D
## Crop sprites per bed. Seed stage: one centered seed. Later stages: four
## synced plant sprites. One water / harvest-ready icon above the bed.

var farm_map: FarmMap
var garden: GardenState
var sprites: FarmSprites
var seed_db: SeedDB
var _nodes: Dictionary = {} ## "bed_id:slot" -> Node2D
var _bed_icons: Dictionary = {} ## bed_id -> Node2D

## Mana Seed 16×32 cells — sized to fit 4 slots per bed at close camera zoom.
const SPRITE_SCALE := 3.2

func setup(map: FarmMap, state: GardenState, art: FarmSprites, db: SeedDB = null) -> void:
	farm_map = map
	garden = state
	sprites = art
	seed_db = db
	if garden and not garden.changed.is_connected(_on_changed):
		garden.changed.connect(_on_changed)
	if garden and garden.has_signal("thirst_changed") and not garden.thirst_changed.is_connected(_on_thirst):
		garden.thirst_changed.connect(_on_thirst)
	if garden and garden.has_signal("bed_changed") and not garden.bed_changed.is_connected(_on_bed):
		garden.bed_changed.connect(_on_bed)
	rebuild_all()

func rebuild_all() -> void:
	for k in _nodes.keys():
		var n: Node = _nodes[k]
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()
	for k in _bed_icons.keys():
		var n2: Node = _bed_icons[k]
		if is_instance_valid(n2):
			n2.queue_free()
	_bed_icons.clear()
	if garden == null or farm_map == null:
		return
	for bed_id in garden.beds.keys():
		for slot in garden.slots_per_bed:
			_refresh_slot(str(bed_id), slot)
		_refresh_bed_icon(str(bed_id))

func _on_changed(bed_id: String, slot: int) -> void:
	_refresh_slot(bed_id, slot)
	_refresh_bed_icon(bed_id)

func _on_thirst(bed_id: String, slot: int, _thirsty: bool) -> void:
	_refresh_slot(bed_id, slot)
	_refresh_bed_icon(bed_id)

func _on_bed(bed_id: String) -> void:
	for slot in garden.slots_per_bed:
		_refresh_slot(bed_id, slot)
	_refresh_bed_icon(bed_id)

func _refresh_slot(bed_id: String, slot: int) -> void:
	var key := "%s:%d" % [bed_id, slot]
	if _nodes.has(key) and is_instance_valid(_nodes[key]):
		_nodes[key].queue_free()
		_nodes.erase(key)
	var data := garden.get_slot(bed_id, slot)
	var pid := str(data.get("plant_id", ""))
	var ground: Vector2 = farm_map.slot_world(bed_id, slot)
	var plant_pos: Vector2 = farm_map.slot_plant_world(bed_id, slot) if farm_map.has_method("slot_plant_world") \
		else ground + Vector2(0, -10)
	var node := Node2D.new()
	node.name = key
	node.z_index = IsoUtil.depth_from_y(ground.y) + 40

	if pid.is_empty():
		node.position = ground + Vector2(0, -FarmMap.BED_HEIGHT + 4)
		add_child(node)
		_nodes[key] = node
		return

	var stage := str(data.get("stage", GardenState.STAGE_SEED))
	## Seed stage: only the centered seed sprite (slot 0).
	if stage == GardenState.STAGE_SEED:
		if slot != 0:
			node.position = ground
			add_child(node)
			_nodes[key] = node
			return
		var center: Vector2 = farm_map.bed_centers.get(bed_id, plant_pos)
		node.position = center + Vector2(0, -FarmMap.BED_HEIGHT)
		var seed_tex: Texture2D = sprites.seed_icon(pid) if sprites else null
		if seed_tex:
			var sspr := Sprite2D.new()
			sspr.texture = seed_tex
			sspr.scale = Vector2(3.6, 3.6)
			sspr.centered = true
			sspr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			node.add_child(sspr)
		add_child(node)
		_nodes[key] = node
		return

	node.position = plant_pos
	var tex: Texture2D = null
	if sprites:
		tex = sprites.plant_stage_texture(pid, stage)
	var poly := Polygon2D.new()
	poly.color = _color(pid, stage)
	var s := 8.0
	match stage:
		"sprout":
			s = 10.0
		"growing":
			s = 13.0
		"grown":
			s = 16.0
	poly.polygon = PackedVector2Array([
		Vector2(0, -s * 1.6), Vector2(s, 0), Vector2(0, s * 0.5), Vector2(-s, 0),
	])
	node.add_child(poly)
	if tex != null:
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
		spr.centered = true
		spr.position = Vector2(0, -12)
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		## Grown: gold outline via modulate pulse (subtle).
		if stage == GardenState.STAGE_GROWN:
			spr.modulate = Color(1.15, 1.05, 0.75, 1.0)
		node.add_child(spr)
		poly.visible = false
	add_child(node)
	_nodes[key] = node

func _refresh_bed_icon(bed_id: String) -> void:
	if _bed_icons.has(bed_id) and is_instance_valid(_bed_icons[bed_id]):
		_bed_icons[bed_id].queue_free()
		_bed_icons.erase(bed_id)
	if garden.is_bed_empty(bed_id):
		return
	var center: Vector2 = farm_map.bed_centers.get(bed_id, Vector2.ZERO)
	var icon := Node2D.new()
	icon.name = "BedIcon_%s" % bed_id
	icon.position = center + Vector2(0, -FarmMap.BED_HEIGHT - 36)
	icon.z_index = IsoUtil.depth_from_y(center.y) + 55
	if garden.is_bed_harvestable(bed_id):
		var star := _load_tex("res://assets/ui/icon_harvest_ready.png")
		if star:
			var sspr := Sprite2D.new()
			sspr.texture = star
			sspr.centered = true
			sspr.scale = Vector2(0.7, 0.7)
			sspr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			icon.add_child(sspr)
		else:
			var harvest := Polygon2D.new()
			harvest.color = Color(1.0, 0.82, 0.2, 1.0)
			harvest.polygon = PackedVector2Array([
				Vector2(0, -12), Vector2(8, -2), Vector2(5, 10), Vector2(-5, 10), Vector2(-8, -2),
			])
			icon.add_child(harvest)
	elif garden.is_bed_thirsty(bed_id):
		var drop := Polygon2D.new()
		drop.color = Color(0.25, 0.55, 0.95, 1.0)
		drop.polygon = PackedVector2Array([
			Vector2(0, -14), Vector2(8, 0), Vector2(5, 10), Vector2(-5, 10), Vector2(-8, 0),
		])
		icon.add_child(drop)
	else:
		return
	add_child(icon)
	_bed_icons[bed_id] = icon

func _load_tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	if FileAccess.file_exists(path):
		var img := Image.load_from_file(path)
		if img:
			return ImageTexture.create_from_image(img)
	return null

func _color(plant_id: String, stage: String) -> Color:
	var h := float(absi(plant_id.hash()) % 1000) / 1000.0
	var v := 0.55
	match stage:
		"sprout":
			v = 0.7
		"growing":
			v = 0.85
		"grown":
			v = 1.0
	return Color.from_hsv(h, 0.65, v)

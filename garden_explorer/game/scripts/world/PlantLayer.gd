class_name PlantLayer
extends Node2D
## Crop sprites + empty-slot markers + thirst / harvest icons.
## Each garden box has 4 plant slots (2×2).

var farm_map: FarmMap
var garden: GardenState
var sprites: FarmSprites
var seed_db: SeedDB
var _nodes: Dictionary = {} ## "bed_id:slot" -> Node2D

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
	rebuild_all()

func rebuild_all() -> void:
	for k in _nodes.keys():
		var n: Node = _nodes[k]
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()
	if garden == null or farm_map == null:
		return
	for bed_id in garden.beds.keys():
		for slot in garden.slots_per_bed:
			_refresh_slot(str(bed_id), slot)

func _on_changed(bed_id: String, slot: int) -> void:
	_refresh_slot(bed_id, slot)

func _on_thirst(bed_id: String, slot: int, _thirsty: bool) -> void:
	_refresh_slot(bed_id, slot)

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
	node.position = plant_pos if not pid.is_empty() else ground + Vector2(0, -FarmMap.BED_HEIGHT + 4)
	node.z_index = IsoUtil.depth_from_y(ground.y) + 40

	## Empty slot: subtle iso grey square so kids see where to plant.
	if pid.is_empty():
		var pad := Polygon2D.new()
		pad.name = "EmptySlot"
		pad.color = Color(0.55, 0.58, 0.62, 0.55)
		pad.polygon = PackedVector2Array([
			Vector2(0, -12), Vector2(16, 0), Vector2(0, 12), Vector2(-16, 0),
		])
		node.add_child(pad)
		var lip := Polygon2D.new()
		lip.color = Color(0.78, 0.80, 0.84, 0.42)
		lip.polygon = PackedVector2Array([
			Vector2(0, -8), Vector2(11, 0), Vector2(0, 8), Vector2(-11, 0),
		])
		node.add_child(lip)
		add_child(node)
		_nodes[key] = node
		return

	var stage := str(data.get("stage", GardenState.STAGE_SEED))
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
		node.add_child(spr)
		poly.visible = false
	_add_status_icon(node, pid, stage, bool(data.get("thirsty", false)))
	add_child(node)
	_nodes[key] = node

func _add_status_icon(node: Node2D, plant_id: String, stage: String, thirsty: bool) -> void:
	var icon := Node2D.new()
	icon.name = "StatusIcon"
	icon.position = Vector2(0, -42)
	icon.z_index = 8
	if stage == GardenState.STAGE_GROWN:
		var harvest := Polygon2D.new()
		harvest.color = Color(0.95, 0.55, 0.2, 1.0)
		harvest.polygon = PackedVector2Array([
			Vector2(0, -10), Vector2(8, -2), Vector2(5, 8), Vector2(-5, 8), Vector2(-8, -2),
		])
		icon.add_child(harvest)
		if sprites:
			var htex := sprites.harvest_icon(plant_id)
			if htex:
				var hspr := Sprite2D.new()
				hspr.texture = htex
				hspr.scale = Vector2(2.0, 2.0)
				hspr.centered = true
				hspr.position = Vector2(0, -2)
				hspr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				icon.add_child(hspr)
	elif thirsty:
		var drop := Polygon2D.new()
		drop.color = Color(0.25, 0.55, 0.95, 1.0)
		drop.polygon = PackedVector2Array([
			Vector2(0, -12), Vector2(7, 0), Vector2(4, 8), Vector2(-4, 8), Vector2(-7, 0),
		])
		icon.add_child(drop)
	else:
		return
	node.add_child(icon)

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

class_name PlantLayer
extends Node2D
## Crops per bed:
##   seed  — four plot-sized seeds, true-centered on each plot (parent = bed cross)
##   later — one four-plant pack centered on the cross (children at plot offsets)
## Harvest / water icon floats above the pack (never covering the plants).

var farm_map: FarmMap
var garden: GardenState
var sprites: FarmSprites
var seed_db: SeedDB
var _beds: Dictionary = {} ## bed_id -> Node2D
var _bed_icons: Dictionary = {} ## bed_id -> Node2D

## Single-plant compose fallback (baked packs already include scale).
const SPRITE_SCALE := 2.0
const PLANT_CELL_H := 32.0
## Mana Seed opaque feet sit near the bottom of the 16×32 cell (~y 28 of 0..31).
## With centered sprites at scale 2: shift so landing lands on the plot point.
const FOOT_ANCHOR_Y := (16.0 - 28.0) * SPRITE_SCALE  ## ≈ -24
## Target long-edge (px) for a seed cluster inside one furrow plot.
const SEED_PLOT_FIT_PX := 16.0
## Fallback star hover (px above furrow cross) when offsets.json is unavailable.
const STAR_HOVER_Y := {
	"sprout": -43.0,
	"growing": -51.0,
	"grown": -58.0,
}

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
	for k in _beds.keys():
		_free_bed_node(str(k))
	_beds.clear()
	for k in _bed_icons.keys():
		_free_icon_node(str(k))
	_bed_icons.clear()
	if garden == null or farm_map == null:
		return
	for bed_id in garden.beds.keys():
		_refresh_bed(str(bed_id))
		_refresh_bed_icon(str(bed_id))

func _free_bed_node(bed_id: String) -> void:
	if not _beds.has(bed_id):
		return
	var n: Node = _beds[bed_id]
	_beds.erase(bed_id)
	if is_instance_valid(n):
		remove_child(n)
		n.free()

func _free_icon_node(bed_id: String) -> void:
	if not _bed_icons.has(bed_id):
		return
	var n: Node = _bed_icons[bed_id]
	_bed_icons.erase(bed_id)
	if is_instance_valid(n):
		remove_child(n)
		n.free()

func _on_changed(bed_id: String, _slot: int) -> void:
	_refresh_bed(bed_id)
	_refresh_bed_icon(bed_id)

func _on_thirst(bed_id: String, _slot: int, _thirsty: bool) -> void:
	_refresh_bed_icon(bed_id)

func _on_bed(bed_id: String) -> void:
	_refresh_bed(bed_id)
	_refresh_bed_icon(bed_id)

func _refresh_bed(bed_id: String) -> void:
	_free_bed_node(bed_id)
	if garden.is_bed_empty(bed_id):
		return
	var pid := garden.bed_plant_id(bed_id)
	var stage := garden.bed_stage(bed_id)
	if pid.is_empty():
		return
	var cross: Vector2 = farm_map.bed_plot_cross(bed_id)
	var sort_y: float = farm_map.bed_centers.get(bed_id, cross).y
	if farm_map.has_method("bed_sort_y"):
		sort_y = farm_map.bed_sort_y(bed_id)
	var node := Node2D.new()
	node.name = "BedPlants_%s" % bed_id
	node.position = cross
	var depth_bias := IsoUtil.BIAS_SEED if stage == GardenState.STAGE_SEED else IsoUtil.BIAS_PLANT
	IsoUtil.apply_depth(node, sort_y, depth_bias)

	if stage == GardenState.STAGE_SEED:
		_add_seed_pack(node, pid, bed_id)
	else:
		_add_four_plant_pack(node, pid, stage, bed_id)

	add_child(node)
	_beds[bed_id] = node

func _add_seed_pack(parent: Node2D, plant_id: String, bed_id: String) -> void:
	## Four seeds parented at the bed furrow cross; each true-centered on a plot.
	## (Plants use foot-anchored landings — seeds use geometric center.)
	var seed_tex: Texture2D = null
	if sprites and sprites.has_method("seed_plot_texture"):
		seed_tex = sprites.seed_plot_texture(plant_id)
	if seed_tex == null and sprites:
		seed_tex = sprites.plant_stage_texture(plant_id, GardenState.STAGE_SEED)
	if seed_tex == null:
		return
	var long_edge := float(maxi(seed_tex.get_width(), seed_tex.get_height()))
	var sc := SEED_PLOT_FIT_PX / maxf(1.0, long_edge)
	var offsets: Array = []
	if farm_map and farm_map.has_method("plot_seed_offsets_from_cross"):
		offsets = farm_map.plot_seed_offsets_from_cross(bed_id)
	elif farm_map and farm_map.has_method("plot_offsets_from_cross"):
		offsets = farm_map.plot_offsets_from_cross(bed_id)
	if offsets.is_empty():
		offsets = [
			Vector2(-3, -12), Vector2(24, 2),
			Vector2(3, 12), Vector2(-24, -2),
		]
	for i in mini(4, offsets.size()):
		var sspr := Sprite2D.new()
		sspr.texture = seed_tex
		sspr.scale = Vector2(sc, sc)
		sspr.centered = true
		sspr.position = offsets[i]
		sspr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		parent.add_child(sspr)

func _add_four_plant_pack(parent: Node2D, plant_id: String, stage: String, bed_id: String) -> void:
	## One logical pack: four sprites parented at the furrow cross, each offset to a plot center.
	## Baked pack PNGs (tools/gen_bed_plant_packs.py) are preferred when present.
	var pack: Texture2D = null
	if sprites and sprites.has_method("bed_plant_pack_texture"):
		pack = sprites.bed_plant_pack_texture(plant_id, stage)
	if pack:
		var spr := Sprite2D.new()
		spr.texture = pack
		spr.centered = true
		## Pack center = furrow cross; each plant's feet are baked onto plot centers.
		spr.position = Vector2.ZERO
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		if stage == GardenState.STAGE_GROWN:
			spr.modulate = Color(1.15, 1.05, 0.75, 1.0)
		parent.add_child(spr)
		return

	var offsets: Array = farm_map.plot_offsets_from_cross(bed_id) if farm_map.has_method("plot_offsets_from_cross") else []
	if offsets.is_empty():
		offsets = [
			Vector2(-24, -12), Vector2(24, -12),
			Vector2(-24, 12), Vector2(24, 12),
		]
	var tex: Texture2D = sprites.plant_stage_texture(plant_id, stage) if sprites else null
	for i in mini(4, offsets.size()):
		var off: Vector2 = offsets[i]
		if tex:
			var spr := Sprite2D.new()
			spr.texture = tex
			spr.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
			spr.centered = true
			## Feet on plot center (not foliage midpoint).
			spr.position = off + Vector2(0, FOOT_ANCHOR_Y)
			spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			if stage == GardenState.STAGE_GROWN:
				spr.modulate = Color(1.15, 1.05, 0.75, 1.0)
			parent.add_child(spr)
		else:
			var poly := Polygon2D.new()
			poly.color = _color(plant_id, stage)
			var s := 10.0
			match stage:
				"sprout":
					s = 10.0
				"growing":
					s = 13.0
				"grown":
					s = 16.0
			poly.position = off
			poly.polygon = PackedVector2Array([
				Vector2(0, -s * 1.6), Vector2(s, 0), Vector2(0, s * 0.5), Vector2(-s, 0),
			])
			parent.add_child(poly)

func _refresh_bed_icon(bed_id: String) -> void:
	_free_icon_node(bed_id)
	if garden.is_bed_empty(bed_id):
		return
	var cross: Vector2 = farm_map.bed_plot_cross(bed_id)
	var sort_y: float = farm_map.bed_centers.get(bed_id, cross).y
	if farm_map.has_method("bed_sort_y"):
		sort_y = farm_map.bed_sort_y(bed_id)
	var stage := garden.bed_stage(bed_id)
	var hover_y: float = float(STAR_HOVER_Y.get(stage, -48.0))
	if sprites and sprites.has_method("bed_pack_star_hover_y"):
		hover_y = sprites.bed_pack_star_hover_y(stage, hover_y)
	## Star only when harvest-ready — hover just above that plant pack.
	var icon := Node2D.new()
	icon.name = "BedIcon_%s" % bed_id
	icon.position = cross + Vector2(0, hover_y)
	IsoUtil.apply_depth(icon, sort_y, IsoUtil.BIAS_UI - 100)
	if garden.is_bed_harvestable(bed_id):
		var star := _load_tex("res://assets/ui/icon_harvest_ready.png")
		if star:
			var sspr := Sprite2D.new()
			sspr.texture = star
			sspr.centered = true
			sspr.scale = Vector2(0.5, 0.5)
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
		icon.free()
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

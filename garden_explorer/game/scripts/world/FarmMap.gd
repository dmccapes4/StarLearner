class_name FarmMap
extends Node2D
## Builds the wide farm: shed (left) · 2×3 beds (middle) · fence/animals (right).
## Beds + shed are extruded iso volumes (fake-3D). Animals stay inside the pen.
## Perimeter fence + meadows outside. Shed / beds / animal pen block walking;
## A* routes the gardener around them.

const MAP_PATH := "res://data/map.json"
const SLOT_OFFSETS := [
	Vector2(-0.35, -0.25), Vector2(0.35, -0.25),
	Vector2(-0.35, 0.25), Vector2(0.35, 0.25),
]
const BED_HEIGHT := 28.0
const SHED_WALL_H := 64.0
const SHED_ROOF_H := 42.0

var data: Dictionary = {}
var sprites: FarmSprites
var shed_poly: PackedVector2Array = PackedVector2Array()
var fence_poly: PackedVector2Array = PackedVector2Array()
var farm_yard_poly: PackedVector2Array = PackedVector2Array()
var bed_polys: Dictionary = {} ## id -> PackedVector2Array (footprint / hit)
var bed_centers: Dictionary = {} ## id -> Vector2
var bed_tiles: Dictionary = {} ## id -> Vector2
var bed_halves: Dictionary = {} ## id -> Vector2
var slot_positions: Dictionary = {} ## bed_id -> Array[Vector2]
var animal_positions: Dictionary = {} ## id -> Vector2
var shed_center: Vector2 = Vector2.ZERO
var fence_center: Vector2 = Vector2.ZERO
var spawn_world: Vector2 = Vector2.ZERO
var walk_bounds: Rect2 = Rect2()
var _built: bool = false
var _astar: AStar2D = AStar2D.new()
var _nav_cell_to_id: Dictionary = {} ## Vector2i -> int
var _yard_min: Vector2 = Vector2.ZERO
var _yard_max: Vector2 = Vector2.ZERO

func _ready() -> void:
	## World owns the authoritative build (with sprites). Skip auto-build to
	## avoid double-spawning animals via queue_free races.
	pass

func set_sprites(art: FarmSprites) -> void:
	sprites = art

func build_from_file(path: String = MAP_PATH) -> void:
	var raw := FileAccess.get_file_as_string(path)
	assert(not raw.is_empty(), "FarmMap: missing %s" % path)
	data = JSON.parse_string(raw)
	assert(typeof(data) == TYPE_DICTIONARY, "FarmMap: bad JSON")
	_clear_visuals()
	_build_meadows()
	_build_ground()
	_build_perimeter_fence()
	_build_shed()
	_build_beds()
	_build_fence()
	_build_animals()
	_compute_bounds()
	_rebuild_nav()
	var spawn: Dictionary = data.get("player_spawn_tile", {"x": 2, "y": 4})
	spawn_world = nearest_walkable(IsoUtil.tile_to_world(Vector2(float(spawn.x), float(spawn.y))))
	_built = true

func bed_ids() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for id in bed_polys.keys():
		out.append(str(id))
	out.sort()
	return out

func bed_count() -> int:
	return bed_polys.size()

func zone_at(world_pos: Vector2) -> Dictionary:
	## Returns {id, kind} or empty. Animals win only when near a critter *inside* the fence.
	if IsoUtil.point_in_polygon(world_pos, shed_poly):
		return {"id": "shed", "kind": "shed"}
	for id in bed_polys.keys():
		if IsoUtil.point_in_polygon(world_pos, bed_polys[id]):
			return {"id": str(id), "kind": "bed"}
	if IsoUtil.point_in_polygon(world_pos, fence_poly):
		## Keep fence_center as fence; animals need a near-direct tap.
		var animal_id := animal_at(world_pos, 34.0)
		if not animal_id.is_empty():
			return {"id": animal_id, "kind": "animal"}
		return {"id": "fence", "kind": "fence"}
	var loose := animal_at(world_pos, 30.0)
	if not loose.is_empty():
		return {"id": loose, "kind": "animal"}
	return {}

func animal_at(world_pos: Vector2, radius: float = 48.0) -> String:
	var best := ""
	var best_d := radius * radius
	for id in animal_positions.keys():
		var pos: Vector2 = animal_positions[id]
		var d := world_pos.distance_squared_to(pos)
		if d <= best_d:
			best_d = d
			best = str(id)
	return best

func apply_season_tint(season_id: String) -> void:
	var ground := get_node_or_null("Ground") as Polygon2D
	if ground == null:
		return
	match season_id:
		"summer":
			ground.modulate = Color(1.05, 1.0, 0.85, 1)
		"fall":
			ground.modulate = Color(1.1, 0.9, 0.7, 1)
		"winter":
			ground.modulate = Color(0.85, 0.95, 1.05, 1)
		_:
			ground.modulate = Color(1, 1, 1, 1)

func slot_world(bed_id: String, slot: int) -> Vector2:
	var arr: Array = slot_positions.get(bed_id, [])
	if slot < 0 or slot >= arr.size():
		return bed_centers.get(bed_id, Vector2.ZERO)
	return arr[slot]

func nearest_slot(bed_id: String, world_pos: Vector2) -> int:
	var arr: Array = slot_positions.get(bed_id, [])
	if arr.is_empty():
		return 0
	var best := 0
	var best_d := INF
	for i in arr.size():
		var d: float = world_pos.distance_squared_to(arr[i])
		if d < best_d:
			best_d = d
			best = i
	return best

func slot_at(world_pos: Vector2, max_dist: float = 36.0) -> Dictionary:
	var zone := zone_at(world_pos)
	if str(zone.get("kind", "")) != "bed":
		return {}
	var bed_id := str(zone.id)
	var slot := nearest_slot(bed_id, world_pos)
	return {"id": bed_id, "kind": "bed", "slot": slot}

func _clear_visuals() -> void:
	## Free immediately so a rebuild in the same frame cannot stack animals.
	while get_child_count() > 0:
		var c := get_child(0)
		remove_child(c)
		c.free()
	bed_polys.clear()
	bed_centers.clear()
	bed_tiles.clear()
	bed_halves.clear()
	slot_positions.clear()
	animal_positions.clear()

func _build_meadows() -> void:
	## Full AABB underlay first so zoomed camera never shows void past the grass diamond.
	var b: Dictionary = data.get("bounds_tiles", {})
	var pad := float(data.get("meadow_pad_tiles", 5))
	var min_t := Vector2(float(b.get("min_x", -10)) - pad, float(b.get("min_y", -4)) - pad)
	var max_t := Vector2(float(b.get("max_x", 16)) + pad, float(b.get("max_y", 10)) + pad)
	var aabb := meadow_aabb().grow(80.0)
	var fill := Polygon2D.new()
	fill.name = "MeadowFill"
	fill.z_index = -32
	fill.color = Color(0.34, 0.52, 0.26, 1.0)
	fill.polygon = PackedVector2Array([
		aabb.position,
		Vector2(aabb.end.x, aabb.position.y),
		aabb.end,
		Vector2(aabb.position.x, aabb.end.y),
	])
	add_child(fill)
	var poly := IsoUtil.diamond_polygon((min_t + max_t) * 0.5, (max_t - min_t) * 0.5)
	var meadow := Polygon2D.new()
	meadow.name = "Meadow"
	meadow.z_index = -30
	meadow.color = Color(0.36, 0.54, 0.28, 1.0)
	meadow.polygon = poly
	add_child(meadow)
	if sprites:
		var gtex := sprites.grass_texture()
		if gtex:
			meadow.texture = gtex
			meadow.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
			meadow.modulate = Color(0.88, 1.02, 0.82, 1.0)
	## Soft wildflower dots outside the yard (fixed seeds, no RNG).
	var accents := [
		Vector2(-12, -2), Vector2(17, 1), Vector2(-9, 9), Vector2(15, 8),
		Vector2(-3, -6), Vector2(8, -5), Vector2(18, 5), Vector2(-11, 5),
		Vector2(3, 11), Vector2(10, 11), Vector2(-6, -5), Vector2(14, -3),
	]
	var colors := [
		Color(0.92, 0.72, 0.28, 0.95), Color(0.85, 0.45, 0.55, 0.9),
		Color(0.95, 0.92, 0.55, 0.9), Color(0.70, 0.55, 0.90, 0.85),
	]
	for i in accents.size():
		var t: Vector2 = accents[i]
		var w := IsoUtil.tile_to_world(t)
		var yard := IsoUtil.diamond_polygon(
			(Vector2(float(b.get("min_x", -10)), float(b.get("min_y", -4)))
				+ Vector2(float(b.get("max_x", 16)), float(b.get("max_y", 10)))) * 0.5,
			(Vector2(float(b.get("max_x", 16)), float(b.get("max_y", 10)))
				- Vector2(float(b.get("min_x", -10)), float(b.get("min_y", -4)))) * 0.5
		)
		if IsoUtil.point_in_polygon(w, yard):
			continue
		var bloom := Polygon2D.new()
		bloom.name = "MeadowBloom_%d" % i
		bloom.z_index = -28
		bloom.color = colors[i % colors.size()]
		bloom.polygon = IsoUtil.diamond_polygon(t, Vector2(0.22, 0.18))
		add_child(bloom)

func meadow_aabb() -> Rect2:
	## World AABB covering the meadow diamond (for camera clamp).
	var b: Dictionary = data.get("bounds_tiles", {})
	var pad := float(data.get("meadow_pad_tiles", 5))
	var min_t := Vector2(float(b.get("min_x", -10)) - pad, float(b.get("min_y", -4)) - pad)
	var max_t := Vector2(float(b.get("max_x", 16)) + pad, float(b.get("max_y", 10)) + pad)
	var corners: Array[Vector2] = [
		IsoUtil.tile_to_world(min_t),
		IsoUtil.tile_to_world(Vector2(max_t.x, min_t.y)),
		IsoUtil.tile_to_world(max_t),
		IsoUtil.tile_to_world(Vector2(min_t.x, max_t.y)),
	]
	var min_p: Vector2 = corners[0]
	var max_p: Vector2 = corners[0]
	for p in corners:
		min_p.x = minf(min_p.x, p.x)
		min_p.y = minf(min_p.y, p.y)
		max_p.x = maxf(max_p.x, p.x)
		max_p.y = maxf(max_p.y, p.y)
	return Rect2(min_p, max_p - min_p)

func _build_ground() -> void:
	var b: Dictionary = data.get("bounds_tiles", {})
	_yard_min = Vector2(float(b.get("min_x", -10)), float(b.get("min_y", -4)))
	_yard_max = Vector2(float(b.get("max_x", 16)), float(b.get("max_y", 10)))
	farm_yard_poly = IsoUtil.diamond_polygon((_yard_min + _yard_max) * 0.5, (_yard_max - _yard_min) * 0.5)
	var ground := Polygon2D.new()
	ground.name = "Ground"
	ground.z_index = -20
	ground.color = Color(0.45, 0.62, 0.32, 1.0)
	ground.polygon = farm_yard_poly
	add_child(ground)
	if sprites:
		var gtex := sprites.grass_texture()
		if gtex:
			ground.texture = gtex
			ground.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	var path := Polygon2D.new()
	path.name = "Path"
	path.z_index = -15
	path.color = Color(0.72, 0.62, 0.42, 1.0)
	path.polygon = IsoUtil.diamond_polygon(Vector2(3.0, 4.2), Vector2(8.5, 0.7))
	add_child(path)
	if sprites:
		var ptex := sprites.path_texture()
		if ptex:
			path.texture = ptex
			path.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED

func _build_perimeter_fence() -> void:
	## Rails + posts around the farm yard so meadows read as "outside".
	var corners := [
		_yard_min,
		Vector2(_yard_max.x, _yard_min.y),
		_yard_max,
		Vector2(_yard_min.x, _yard_max.y),
	]
	_draw_fence_loop("Yard", corners, 5)

func _draw_fence_loop(prefix: String, corners: Array, posts_per_edge: int) -> void:
	for i in 4:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 4]
		var wa := IsoUtil.tile_to_world(a)
		var wb := IsoUtil.tile_to_world(b)
		for rail_y in [-18.0, -9.0]:
			var rail := Polygon2D.new()
			rail.name = "%sRail_%d_%d" % [prefix, i, int(rail_y)]
			rail.z_index = IsoUtil.depth_from_y(maxf(wa.y, wb.y)) + 2
			rail.color = Color(0.48, 0.32, 0.16, 1.0)
			var n := (wb - wa).normalized().orthogonal() * 2.2
			rail.polygon = PackedVector2Array([
				wa + Vector2(0, rail_y) - n,
				wb + Vector2(0, rail_y) - n,
				wb + Vector2(0, rail_y + 3.5) + n,
				wa + Vector2(0, rail_y + 3.5) + n,
			])
			add_child(rail)
		for step in posts_per_edge:
			var t: float = float(step) / float(maxi(posts_per_edge - 1, 1))
			var pt: Vector2 = a.lerp(b, t)
			var world := IsoUtil.tile_to_world(pt)
			var post := Polygon2D.new()
			post.name = "%sPost_%d_%d" % [prefix, i, step]
			post.z_index = IsoUtil.depth_from_y(world.y) + 3
			post.color = Color(0.42, 0.28, 0.14, 1.0)
			post.polygon = PackedVector2Array([
				world + Vector2(-3.5, -24), world + Vector2(3.5, -24),
				world + Vector2(3.5, 5), world + Vector2(-3.5, 5),
			])
			add_child(post)

func _build_shed() -> void:
	var shed: Dictionary = data.get("shed", {})
	var tile := _vec2(shed.get("tile", {"x": -7, "y": 2}))
	var half := _vec2(shed.get("half_tiles", {"x": 2.2, "y": 2.0}))
	var base := IsoUtil.diamond_polygon(tile, half)
	shed_poly = base
	shed_center = IsoUtil.tile_to_world(tile)
	var z := IsoUtil.depth_from_y(shed_center.y)

	## Ground pad under shed
	_add_poly("ShedPad", base, Color(0.42, 0.32, 0.20, 1.0), z - 1)

	## Extruded walls (fake-3D)
	var faces: Array = IsoUtil.extrusion_side_faces(base, SHED_WALL_H)
	_add_poly("ShedWallW", faces[0], Color(0.58, 0.38, 0.22, 1.0), z + 1)
	_add_poly("ShedWallE", faces[1], Color(0.48, 0.30, 0.16, 1.0), z + 2)

	## Wall top rim (eave line)
	var wall_top := IsoUtil.raise_poly(base, SHED_WALL_H)
	_add_poly("ShedEave", wall_top, Color(0.50, 0.32, 0.18, 1.0), z + 3)

	## Door on near face
	var door_c: Vector2 = base[2].lerp((base[1] + base[3]) * 0.5, 0.35)
	var door := Polygon2D.new()
	door.name = "ShedDoor"
	door.z_index = z + 4
	door.color = Color(0.28, 0.16, 0.08, 1.0)
	door.polygon = PackedVector2Array([
		door_c + Vector2(-14, -6),
		door_c + Vector2(14, -6),
		door_c + Vector2(12, -SHED_WALL_H * 0.72),
		door_c + Vector2(-12, -SHED_WALL_H * 0.72),
	])
	add_child(door)

	## Pitched roof (two faces meeting at a ridge)
	var ridge_h := SHED_WALL_H + SHED_ROOF_H
	var far := wall_top[0]
	var east := wall_top[1]
	var near := wall_top[2]
	var west := wall_top[3]
	var ridge := (far + near) * 0.5 + Vector2(0, -(SHED_ROOF_H * 0.15))
	ridge.y = minf(far.y, near.y) - SHED_ROOF_H
	_add_poly("ShedRoofW", PackedVector2Array([west, near, ridge]), Color(0.72, 0.32, 0.22, 1.0), z + 6)
	_add_poly("ShedRoofE", PackedVector2Array([near, east, ridge]), Color(0.58, 0.24, 0.16, 1.0), z + 7)
	_add_poly("ShedRoofBack", PackedVector2Array([west, far, ridge]), Color(0.65, 0.28, 0.18, 1.0), z + 5)

	_add_label("ShedLabel", shed_center + Vector2(0, 10), "SHED", Color(1, 0.95, 0.8, 0.9))

func _build_beds() -> void:
	var beds: Array = data.get("beds", [])
	assert(beds.size() == 6, "FarmMap: expected 6 beds")
	for i in beds.size():
		var bed: Dictionary = beds[i]
		var id := str(bed.get("id", "bed_%d" % i))
		var tile := _vec2(bed.get("tile", {"x": 0, "y": 0}))
		var half := _vec2(bed.get("half_tiles", {"x": 1.1, "y": 0.85}))
		var base := IsoUtil.diamond_polygon(tile, half)
		bed_polys[id] = base
		bed_tiles[id] = tile
		bed_halves[id] = half
		var center := IsoUtil.tile_to_world(tile)
		bed_centers[id] = center
		var z := IsoUtil.depth_from_y(center.y)

		## Shadow / dirt under the box
		_add_poly(id + "_shadow", IsoUtil.diamond_polygon(tile, half * 1.06),
			Color(0.22, 0.16, 0.08, 0.35), z - 1)

		## Wood side walls (extrusion)
		var faces: Array = IsoUtil.extrusion_side_faces(base, BED_HEIGHT)
		_add_poly(id + "_wall_w", faces[0], Color(0.62, 0.42, 0.22, 1.0), z + 1)
		_add_poly(id + "_wall_e", faces[1], Color(0.48, 0.30, 0.14, 1.0), z + 2)

		## Soil top (raised)
		var top := IsoUtil.raise_poly(base, BED_HEIGHT)
		var soil := _add_poly(id, top, Color(0.38, 0.24, 0.12, 1.0), z + 3)
		if sprites:
			var ttex := sprites.tilled_texture()
			if ttex:
				soil.texture = ttex
				soil.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED

		## Inner lip (rim of the planter)
		var lip := IsoUtil.raise_poly(IsoUtil.diamond_polygon(tile, half * 0.90), BED_HEIGHT - 2.0)
		_add_poly(id + "_lip", lip, Color(0.55, 0.36, 0.18, 0.85), z + 4)

		_add_slot_markers(id, tile, half, z + 5)

func _add_slot_markers(bed_id: String, tile: Vector2, half: Vector2, z: int) -> void:
	var positions: Array = []
	for i in SLOT_OFFSETS.size():
		var slot_tile: Vector2 = tile + SLOT_OFFSETS[i] * half
		## Hit/path targets stay on the ground footprint so zone_at still works.
		var ground: Vector2 = IsoUtil.tile_to_world(slot_tile)
		positions.append(ground)
		_add_poly(
			"%s_slot_%d" % [bed_id, i],
			IsoUtil.raise_poly(IsoUtil.diamond_polygon(slot_tile, Vector2(0.26, 0.20)), BED_HEIGHT - 1.0),
			Color(0.26, 0.16, 0.08, 0.9),
			z
		)
	slot_positions[bed_id] = positions

func slot_plant_world(bed_id: String, slot: int) -> Vector2:
	## Visual plant anchor on the raised soil top.
	return slot_world(bed_id, slot) + Vector2(0, -BED_HEIGHT)

func _build_fence() -> void:
	var fence: Dictionary = data.get("fence", {})
	var tile := _vec2(fence.get("tile", {"x": 12, "y": 2}))
	var half := _vec2(fence.get("half_tiles", {"x": 2.0, "y": 2.4}))
	fence_poly = IsoUtil.diamond_polygon(tile, half)
	fence_center = IsoUtil.tile_to_world(tile)
	var z := IsoUtil.depth_from_y(fence_center.y)
	_add_poly("FenceYard", fence_poly, Color(0.50, 0.68, 0.36, 1.0), z - 2)

	## Posts + rails around the animal pen — player stops at the rail for interaction.
	var corners := [
		tile + Vector2(-half.x, -half.y),
		tile + Vector2(half.x, -half.y),
		tile + Vector2(half.x, half.y),
		tile + Vector2(-half.x, half.y),
	]
	_draw_fence_loop("Pen", corners, 4)

	## Chicken coop at the *back* of the pen so animals stand in front, not on it.
	if sprites:
		var coop := sprites.chicken_coop_texture()
		if coop:
			var spr := Sprite2D.new()
			spr.name = "ChickenCoop"
			spr.texture = coop
			spr.centered = true
			## Far corner of yard (screen-up from fence center).
			spr.position = IsoUtil.tile_to_world(tile + Vector2(-0.35, -1.15)) + Vector2(0, -28)
			spr.z_index = z + 4
			spr.scale = Vector2(2.0, 2.0)
			spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			add_child(spr)

	_add_label("FenceLabel", fence_center + Vector2(0, -52), "ANIMALS", Color(1, 0.95, 0.8, 0.9))

func _build_animals() -> void:
	var animals: Array = data.get("animals", [])
	var colors := {"chicken_a": "default", "chicken_b": "brown", "chicken_c": "red"}
	for a in animals:
		var d: Dictionary = a
		var id := str(d.get("id", "animal"))
		var tile := _vec2(d.get("tile", {"x": 12, "y": 2}))
		var pos := IsoUtil.tile_to_world(tile)
		animal_positions[id] = pos
		var z := IsoUtil.depth_from_y(pos.y) + 5

		if id.begins_with("chicken") and sprites:
			var color := str(colors.get(id, "default"))
			var chicken_tex := sprites.chicken_texture(color)
			if chicken_tex:
				var spr := Sprite2D.new()
				spr.name = id
				spr.texture = chicken_tex
				spr.centered = true
				## 16×16 frame scaled up; sit feet on grass in front of the coop.
				spr.position = pos + Vector2(0, -6)
				spr.z_index = z + 6
				spr.scale = Vector2(3.5, 3.5)
				spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				add_child(spr)
				continue

		var body := Polygon2D.new()
		body.name = id
		body.z_index = z
		body.position = pos
		if id.begins_with("chicken"):
			body.color = Color(0.95, 0.85, 0.55, 1.0)
			body.polygon = PackedVector2Array([
				Vector2(-10, 0), Vector2(-4, -12), Vector2(8, -8),
				Vector2(12, 2), Vector2(0, 8), Vector2(-10, 4),
			])
		else:
			body.color = Color(0.85, 0.78, 0.70, 1.0)
			body.polygon = PackedVector2Array([
				Vector2(-12, 2), Vector2(-6, -10), Vector2(8, -8),
				Vector2(12, 2), Vector2(4, 10), Vector2(-8, 8),
			])
		add_child(body)

func _compute_bounds() -> void:
	var corners: Array[Vector2] = [
		IsoUtil.tile_to_world(_yard_min),
		IsoUtil.tile_to_world(Vector2(_yard_max.x, _yard_min.y)),
		IsoUtil.tile_to_world(_yard_max),
		IsoUtil.tile_to_world(Vector2(_yard_min.x, _yard_max.y)),
	]
	var min_p: Vector2 = corners[0]
	var max_p: Vector2 = corners[0]
	for p in corners:
		var pt: Vector2 = p
		min_p.x = minf(min_p.x, pt.x)
		min_p.y = minf(min_p.y, pt.y)
		max_p.x = maxf(max_p.x, pt.x)
		max_p.y = maxf(max_p.y, pt.y)
	walk_bounds = Rect2(min_p, max_p - min_p).grow(40.0)

func is_blocked(world_pos: Vector2) -> bool:
	## Solid: shed, garden beds, animal pen. Outside the farm yard is also blocked
	## (perimeter fence — meadows are scenery only).
	if farm_yard_poly.size() >= 3 and not IsoUtil.point_in_polygon(world_pos, farm_yard_poly):
		return true
	if shed_poly.size() >= 3 and IsoUtil.point_in_polygon(world_pos, shed_poly):
		return true
	if fence_poly.size() >= 3 and IsoUtil.point_in_polygon(world_pos, fence_poly):
		return true
	for id in bed_polys.keys():
		var poly: PackedVector2Array = bed_polys[id]
		if poly.size() >= 3 and IsoUtil.point_in_polygon(world_pos, poly):
			return true
	return false

func nearest_walkable(world_pos: Vector2, max_radius_tiles: int = 8) -> Vector2:
	## Snap a goal (often inside an obstacle) to the closest walkable nav cell.
	if not is_blocked(world_pos) and _nav_id_at_world(world_pos) >= 0:
		return world_pos
	var origin := IsoUtil.world_to_tile(world_pos)
	var best := world_pos
	var best_d := INF
	for r in range(0, max_radius_tiles + 1):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var cell := origin + Vector2i(dx, dy)
				var id: int = int(_nav_cell_to_id.get(cell, -1))
				if id < 0:
					continue
				var w: Vector2 = _astar.get_point_position(id)
				var d := world_pos.distance_squared_to(w)
				if d < best_d:
					best_d = d
					best = w
		if best_d < INF and r >= 1:
			break
	return best

func find_path(from_world: Vector2, to_world: Vector2) -> PackedVector2Array:
	## A* through walkable iso tiles. Goals inside obstacles snap to the rim.
	var start_w := nearest_walkable(from_world)
	var end_w := nearest_walkable(to_world)
	var sid := _nav_id_at_world(start_w)
	var eid := _nav_id_at_world(end_w)
	if sid < 0 or eid < 0:
		return PackedVector2Array([end_w])
	if sid == eid:
		return PackedVector2Array([end_w])
	var pts: PackedVector2Array = _astar.get_point_path(sid, eid)
	if pts.is_empty():
		return PackedVector2Array([end_w])
	## Ensure exact end (nav cell center → approach point).
	if pts[pts.size() - 1].distance_to(end_w) > 2.0:
		pts.append(end_w)
	return pts

func clamp_world(pos: Vector2) -> Vector2:
	var c := Vector2(
		clampf(pos.x, walk_bounds.position.x, walk_bounds.end.x),
		clampf(pos.y, walk_bounds.position.y, walk_bounds.end.y)
	)
	return nearest_walkable(c)

func _rebuild_nav() -> void:
	_astar.clear()
	_nav_cell_to_id.clear()
	var min_x := int(floor(_yard_min.x))
	var max_x := int(ceil(_yard_max.x))
	var min_y := int(floor(_yard_min.y))
	var max_y := int(ceil(_yard_max.y))
	var next_id := 1
	for x in range(min_x, max_x + 1):
		for y in range(min_y, max_y + 1):
			var cell := Vector2i(x, y)
			var w := IsoUtil.tile_to_world(Vector2(cell))
			if is_blocked(w):
				continue
			_astar.add_point(next_id, w)
			_nav_cell_to_id[cell] = next_id
			next_id += 1
	## 8-connected neighbors for smoother iso routing.
	var deltas := [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
	]
	for cell in _nav_cell_to_id.keys():
		var a: int = int(_nav_cell_to_id[cell])
		for d in deltas:
			var nb: Vector2i = cell + d
			if not _nav_cell_to_id.has(nb):
				continue
			var b: int = int(_nav_cell_to_id[nb])
			if not _astar.are_points_connected(a, b):
				var diag := absi(d.x) + absi(d.y) == 2
				_astar.connect_points(a, b, true)
				if diag:
					## Slightly prefer cardinal moves.
					_astar.set_point_weight_scale(b, 1.0)

func _nav_id_at_world(world_pos: Vector2) -> int:
	var cell := IsoUtil.world_to_tile(world_pos)
	if _nav_cell_to_id.has(cell):
		return int(_nav_cell_to_id[cell])
	## Search neighborhood if we're between cells.
	var best_id := -1
	var best_d := INF
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var c := cell + Vector2i(dx, dy)
			if not _nav_cell_to_id.has(c):
				continue
			var id: int = int(_nav_cell_to_id[c])
			var d := world_pos.distance_squared_to(_astar.get_point_position(id))
			if d < best_d:
				best_d = d
				best_id = id
	return best_id

func _add_poly(node_name: String, poly: PackedVector2Array, color: Color, z: int) -> Polygon2D:
	var p := Polygon2D.new()
	p.name = node_name
	p.z_index = z
	p.color = color
	p.polygon = poly
	add_child(p)
	return p

func _add_label(node_name: String, at: Vector2, text: String, color: Color) -> void:
	var lbl := Label.new()
	lbl.name = node_name
	lbl.text = text
	lbl.z_index = 500
	lbl.position = at + Vector2(-28, -8)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", 14)
	add_child(lbl)

func _vec2(d: Variant) -> Vector2:
	if typeof(d) != TYPE_DICTIONARY:
		return Vector2.ZERO
	var m: Dictionary = d
	return Vector2(float(m.get("x", 0)), float(m.get("y", 0)))

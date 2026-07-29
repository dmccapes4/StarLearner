class_name FarmMap
extends Node2D
## Builds the wide farm: shed (left) · 2×3 beds (middle) · full-end animal pen (right).
## Beds + shed are extruded iso volumes (fake-3D). Pen is walkable via a west gate
## (player only — roaming animals stay inside fence_poly). Shed / beds block walking.

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
var shed_door_world: Vector2 = Vector2.ZERO ## Walk-to point just outside the door (faces garden).
var coop_world: Vector2 = Vector2.ZERO ## Chicken coop anchor (inside pen).
var fence_center: Vector2 = Vector2.ZERO
var spawn_world: Vector2 = Vector2.ZERO
var dog_spawn_world: Vector2 = Vector2.ZERO
var gate_world: Vector2 = Vector2.ZERO ## West gate into the pen (player entrance).
var pen_roam_poly: PackedVector2Array = PackedVector2Array() ## Inset bound for animals.
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
	_register_animal_spawns()
	_compute_bounds()
	_rebuild_nav()
	var spawn: Dictionary = data.get("player_spawn_tile", {"x": 2, "y": 4})
	spawn_world = nearest_walkable(IsoUtil.tile_to_world(Vector2(float(spawn.x), float(spawn.y))))
	if shed_door_world != Vector2.ZERO:
		shed_door_world = nearest_walkable(shed_door_world)
	else:
		shed_door_world = nearest_walkable(shed_center + Vector2(36, 20))
	if dog_spawn_world != Vector2.ZERO:
		dog_spawn_world = nearest_dog_walkable(dog_spawn_world)
		animal_positions["dog"] = dog_spawn_world
	if gate_world != Vector2.ZERO:
		gate_world = nearest_walkable(gate_world)
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
			## Bright and clear.
			ground.modulate = Color(1.08, 1.03, 0.88, 1)
		"fall":
			## Warmer, a touch dimmer.
			ground.modulate = Color(1.0, 0.86, 0.66, 1)
		"winter":
			## Coolest and dimmest.
			ground.modulate = Color(0.78, 0.86, 0.98, 1)
		_:
			## Spring — lively green.
			ground.modulate = Color(0.98, 1.05, 0.95, 1)
	_apply_season_decor(season_id)

## Scatter decals + weather per season: fall leaves, spring flowers,
## winter snow/rain particles. Cheap Polygon2Ds — no assets required.
func _apply_season_decor(season_id: String) -> void:
	var old := get_node_or_null("SeasonDecor")
	if old:
		old.queue_free()
	var decor := Node2D.new()
	decor.name = "SeasonDecor"
	decor.z_index = 2
	add_child(decor)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260725
	match season_id:
		"fall":
			for i in 46:
				var p := _random_yard_point(rng)
				if p == Vector2.INF:
					continue
				var leaf := Polygon2D.new()
				var s := rng.randf_range(2.5, 4.5)
				leaf.polygon = PackedVector2Array([
					p + Vector2(-s, 0), p + Vector2(0, -s * 0.8),
					p + Vector2(s, 0), p + Vector2(0, s * 0.8),
				])
				leaf.color = [Color(0.80, 0.45, 0.15, 0.9), Color(0.72, 0.32, 0.10, 0.9),
					Color(0.85, 0.60, 0.20, 0.9)][i % 3]
				decor.add_child(leaf)
		"spring":
			for i in 36:
				var p2 := _random_yard_point(rng)
				if p2 == Vector2.INF:
					continue
				var stem := Polygon2D.new()
				stem.polygon = PackedVector2Array([
					p2 + Vector2(-1, 0), p2 + Vector2(1, 0),
					p2 + Vector2(1, -5), p2 + Vector2(-1, -5),
				])
				stem.color = Color(0.30, 0.60, 0.25, 0.95)
				decor.add_child(stem)
				var bloom := Polygon2D.new()
				var b := 2.6
				var c := p2 + Vector2(0, -6)
				bloom.polygon = PackedVector2Array([
					c + Vector2(-b, 0), c + Vector2(0, -b), c + Vector2(b, 0), c + Vector2(0, b),
				])
				bloom.color = [Color(0.95, 0.75, 0.85, 1), Color(0.98, 0.92, 0.55, 1),
					Color(0.85, 0.80, 0.98, 1)][i % 3]
				decor.add_child(bloom)
		"winter":
			var snow := CPUParticles2D.new()
			snow.name = "Snow"
			snow.amount = 90
			snow.lifetime = 6.0
			snow.preprocess = 3.0
			snow.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
			snow.emission_rect_extents = Vector2(absf(IsoUtil.tile_to_world(_yard_max).x - IsoUtil.tile_to_world(_yard_min).x) * 0.6, 8)
			snow.position = Vector2(0, IsoUtil.tile_to_world(_yard_min).y - 160.0)
			snow.direction = Vector2(0.15, 1.0)
			snow.spread = 12.0
			snow.gravity = Vector2(0, 14)
			snow.initial_velocity_min = 26.0
			snow.initial_velocity_max = 52.0
			snow.scale_amount_min = 1.2
			snow.scale_amount_max = 2.4
			snow.color = Color(1, 1, 1, 0.85)
			snow.z_index = 400
			decor.add_child(snow)
		_:
			pass

func _random_yard_point(rng: RandomNumberGenerator) -> Vector2:
	for attempt in 12:
		var tx := rng.randf_range(_yard_min.x + 0.5, _yard_max.x - 0.5)
		var ty := rng.randf_range(_yard_min.y + 0.5, _yard_max.y - 0.5)
		var w := IsoUtil.tile_to_world(Vector2(tx, ty))
		if not is_blocked(w) and not in_pen(w):
			return w
	return Vector2.INF

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

const SHED_SPRITE := "res://assets/buildings/shed_v2.png"
const SHED_SPRITE_SCALE := 2.2

func _build_shed() -> void:
	## Composed Sprout Lands shed (tools/build_shed_sprite.py): front-facing
	## with a CENTERED door — the walk path leads straight to it.
	var shed: Dictionary = data.get("shed", {})
	var tile := _vec2(shed.get("tile", {"x": -7, "y": 2}))
	var half := _vec2(shed.get("half_tiles", {"x": 2.0, "y": 1.7}))
	var base := IsoUtil.diamond_polygon(tile, half)
	shed_poly = base
	shed_center = IsoUtil.tile_to_world(tile)
	var z := IsoUtil.depth_from_y(shed_center.y)

	## Bottom of the facade sits on the south corner row of the footprint,
	## so the door lands at the footprint's near edge, centered.
	var south := IsoUtil.tile_to_world(tile + Vector2(half.x * 0.5, half.y * 0.5))
	shed_door_world = south + Vector2(0, 20)

	var tex: Texture2D = load(SHED_SPRITE) if ResourceLoader.exists(SHED_SPRITE) else null
	if tex:
		var spr := Sprite2D.new()
		spr.name = "ShedSprite"
		spr.texture = tex
		spr.centered = true
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.scale = Vector2(SHED_SPRITE_SCALE, SHED_SPRITE_SCALE)
		var h := float(tex.get_height()) * SHED_SPRITE_SCALE
		spr.position = south + Vector2(0, 8) - Vector2(0, h * 0.5)
		spr.z_index = z + 4
		add_child(spr)
	else:
		## Fallback: simple extruded box (headless tests without the asset).
		var faces: Array = IsoUtil.extrusion_side_faces(base, SHED_WALL_H)
		_add_poly("ShedWallW", faces[0], Color(0.62, 0.42, 0.24, 1.0), z + 1)
		_add_poly("ShedWallE", faces[1], Color(0.50, 0.32, 0.16, 1.0), z + 2)
		_add_poly("ShedEave", IsoUtil.raise_poly(base, SHED_WALL_H), Color(0.52, 0.34, 0.18, 1.0), z + 3)

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

		## Wood side walls (extrusion)
		var faces: Array = IsoUtil.extrusion_side_faces(base, BED_HEIGHT)
		_add_poly(id + "_wall_w", faces[0], Color(0.62, 0.42, 0.22, 1.0), z + 1)
		_add_poly(id + "_wall_e", faces[1], Color(0.48, 0.30, 0.14, 1.0), z + 2)

		## Bed top: lighter wooden frame with dark freshly-turned soil inside.
		var top := IsoUtil.raise_poly(base, BED_HEIGHT)
		_add_poly(id, top, Color(0.55, 0.36, 0.18, 1.0), z + 3)
		var soil_poly := IsoUtil.raise_poly(IsoUtil.diamond_polygon(tile, half * 0.86), BED_HEIGHT)
		var soil := _add_poly(id + "_soil", soil_poly, Color(0.30, 0.185, 0.09, 1.0), z + 4)
		if sprites:
			var ttex := sprites.tilled_texture()
			if ttex:
				soil.texture = ttex
				soil.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED

		## Two perpendicular furrows split the soil into four iso plots — clean
		## "plant here" squares, no grey overlay.
		_add_plot_grid(id, tile, half, z + 5)
		_add_slot_markers(id, tile, half)

## Iso half-size (in tiles) of one "plant here" patch. Kept comfortably inside
## the bed lip (half * 0.90) and clear of the neighboring slot.
const SLOT_MARKER_HALF := Vector2(0.22, 0.155)

func _add_slot_markers(bed_id: String, tile: Vector2, half: Vector2) -> void:
	## Logical plot centers (hit/path targets) — geometry only, drawn as the grid.
	var positions: Array = []
	for i in SLOT_OFFSETS.size():
		var slot_tile: Vector2 = tile + SLOT_OFFSETS[i] * half
		positions.append(IsoUtil.tile_to_world(slot_tile))
	slot_positions[bed_id] = positions

func _add_plot_grid(bed_id: String, tile: Vector2, half: Vector2, z: int) -> void:
	## Divide the soil-top diamond into four iso squares with two furrow lines
	## through the center (midpoint of each edge to the opposite edge midpoint).
	var top := IsoUtil.raise_poly(IsoUtil.diamond_polygon(tile, half * 0.82), BED_HEIGHT)
	var n := top[0]
	var e := top[1]
	var s := top[2]
	var w := top[3]
	var m_ne := (n + e) * 0.5
	var m_es := (e + s) * 0.5
	var m_sw := (s + w) * 0.5
	var m_wn := (w + n) * 0.5
	var furrow := Color(0.16, 0.10, 0.05, 0.9)
	_add_line("%s_grid_a" % bed_id, [m_wn, m_es], furrow, z)
	_add_line("%s_grid_b" % bed_id, [m_ne, m_sw], furrow, z)

func _add_line(node_name: String, pts: Array, color: Color, z: int) -> Line2D:
	var line := Line2D.new()
	line.name = node_name
	line.points = PackedVector2Array(pts)
	line.width = 3.0
	line.default_color = color
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.antialiased = true
	line.z_index = z
	add_child(line)
	return line

func slot_marker_poly(bed_id: String, slot: int) -> PackedVector2Array:
	## For UI validation: the logical plot diamond for a slot (drawn as grid).
	var tile: Vector2 = bed_tiles.get(bed_id, Vector2.ZERO)
	var half: Vector2 = bed_halves.get(bed_id, Vector2.ZERO)
	var slot_tile: Vector2 = tile + SLOT_OFFSETS[slot] * half
	return IsoUtil.raise_poly(IsoUtil.diamond_polygon(slot_tile, SLOT_MARKER_HALF), BED_HEIGHT)

func bed_soil_top_poly(bed_id: String) -> PackedVector2Array:
	var tile: Vector2 = bed_tiles.get(bed_id, Vector2.ZERO)
	var half: Vector2 = bed_halves.get(bed_id, Vector2.ZERO)
	return IsoUtil.raise_poly(IsoUtil.diamond_polygon(tile, half * 0.90), BED_HEIGHT)

func slot_plant_world(bed_id: String, slot: int) -> Vector2:
	## Visual plant anchor on the raised soil top.
	return slot_world(bed_id, slot) + Vector2(0, -BED_HEIGHT)

func bed_plot_cross(bed_id: String) -> Vector2:
	## Where the four plot furrows meet — soil-top center of the bed.
	var center: Vector2 = bed_centers.get(bed_id, Vector2.ZERO)
	return center + Vector2(0, -BED_HEIGHT)

func _build_fence() -> void:
	var fence: Dictionary = data.get("fence", {})
	var tile := _vec2(fence.get("tile", {"x": 13, "y": 3}))
	var half := _vec2(fence.get("half_tiles", {"x": 3.4, "y": 4.4}))
	fence_poly = IsoUtil.diamond_polygon(tile, half)
	pen_roam_poly = IsoUtil.diamond_polygon(tile, half * 0.78)
	fence_center = IsoUtil.tile_to_world(tile)
	var z := IsoUtil.depth_from_y(fence_center.y)
	_add_poly("FenceYard", fence_poly, Color(0.50, 0.68, 0.36, 1.0), z - 2)

	## Posts + rails with a gap on the west edge for the player-only gate.
	var corners := [
		tile + Vector2(-half.x, -half.y),
		tile + Vector2(half.x, -half.y),
		tile + Vector2(half.x, half.y),
		tile + Vector2(-half.x, half.y),
	]
	_draw_pen_fence_with_gate("Pen", corners, 5)

	## Gate world position — west midpoint of the pen (faces garden beds).
	gate_world = IsoUtil.tile_to_world(tile + Vector2(-half.x + 0.05, 0.0))

	## Chicken coop at the *upper* end of the pen.
	var coop_off := _vec2(fence.get("coop_offset", {"x": -0.2, "y": -2.6}))
	coop_world = IsoUtil.tile_to_world(tile + coop_off)
	if sprites:
		var coop := sprites.chicken_coop_texture()
		if coop:
			var spr := Sprite2D.new()
			spr.name = "ChickenCoop"
			spr.texture = coop
			spr.centered = true
			spr.position = coop_world + Vector2(0, -28)
			spr.z_index = z + 4
			spr.scale = Vector2(2.0, 2.0)
			spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			add_child(spr)

	_add_label("FenceLabel", fence_center + Vector2(0, -72), "ANIMALS", Color(1, 0.95, 0.8, 0.9))

func _draw_pen_fence_with_gate(prefix: String, corners: Array, posts_per_edge: int) -> void:
	for i in 4:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 4]
		var west_edge := (i == 3)
		## Rails — skip middle third on west edge (gate opening).
		for rail_y in [-18.0, -9.0]:
			if west_edge:
				_add_rail_segment("%sRail_%d_a_%d" % [prefix, i, int(rail_y)], a, a.lerp(b, 0.30), rail_y)
				_add_rail_segment("%sRail_%d_b_%d" % [prefix, i, int(rail_y)], a.lerp(b, 0.70), b, rail_y)
			else:
				_add_rail_segment("%sRail_%d_%d" % [prefix, i, int(rail_y)], a, b, rail_y)
		for step in posts_per_edge:
			var t: float = float(step) / float(maxi(posts_per_edge - 1, 1))
			if west_edge and t > 0.32 and t < 0.68:
				continue
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

func _add_rail_segment(name: String, tile_a: Vector2, tile_b: Vector2, rail_y: float) -> void:
	var wa := IsoUtil.tile_to_world(tile_a)
	var wb := IsoUtil.tile_to_world(tile_b)
	var rail := Polygon2D.new()
	rail.name = name
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

func _register_animal_spawns() -> void:
	## Positions only — World spawns roaming actors (correct sizes + motion).
	var animals: Array = data.get("animals", [])
	for a in animals:
		var d: Dictionary = a
		var id := str(d.get("id", "animal"))
		var tile := _vec2(d.get("tile", {"x": 12, "y": 2}))
		var pos := IsoUtil.tile_to_world(tile)
		if id.begins_with("dog"):
			dog_spawn_world = pos
			animal_positions[id] = pos
			continue
		if pen_roam_poly.size() >= 3 and not IsoUtil.point_in_polygon(pos, pen_roam_poly):
			pos = fence_center
		animal_positions[id] = pos
	if dog_spawn_world == Vector2.ZERO:
		dog_spawn_world = spawn_world + Vector2(40, 30)
		animal_positions["dog"] = dog_spawn_world
	if gate_world == Vector2.ZERO and fence_poly.size() >= 3:
		gate_world = fence_center + Vector2(-80, 0)

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
	## Solid: shed + garden beds. Pen is walkable (player enters via west gate).
	## Outside the farm yard is blocked (perimeter fence — meadows are scenery).
	if farm_yard_poly.size() >= 3 and not IsoUtil.point_in_polygon(world_pos, farm_yard_poly):
		return true
	if shed_poly.size() >= 3 and IsoUtil.point_in_polygon(world_pos, shed_poly):
		return true
	for id in bed_polys.keys():
		var poly: PackedVector2Array = bed_polys[id]
		if poly.size() >= 3 and IsoUtil.point_in_polygon(world_pos, poly):
			return true
	return false

## Keep Buddy clear of bed tops / aisles kids are using for gardening.
const DOG_BED_CLEARANCE := 92.0

func near_garden_bed(world_pos: Vector2, clearance: float = DOG_BED_CLEARANCE) -> bool:
	for id in bed_centers.keys():
		var c: Vector2 = bed_centers[id]
		if world_pos.distance_to(c) <= clearance:
			return true
	return false

func is_blocked_for_dog(world_pos: Vector2) -> bool:
	## Yard dog: no pen, no solids, and stay out of the garden-bed cluster.
	if in_pen(world_pos):
		return true
	if is_blocked(world_pos):
		return true
	return near_garden_bed(world_pos)

func nearest_dog_walkable(world_pos: Vector2, max_radius_tiles: int = 10) -> Vector2:
	if not is_blocked_for_dog(world_pos) and _nav_id_at_world(world_pos) >= 0:
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
				if is_blocked_for_dog(w):
					continue
				var d := world_pos.distance_squared_to(w)
				if d < best_d:
					best_d = d
					best = w
		if best_d < INF and r >= 1:
			break
	return best

func in_pen(world_pos: Vector2) -> bool:
	return fence_poly.size() >= 3 and IsoUtil.point_in_polygon(world_pos, fence_poly)

const GATE_PASS_RADIUS := 52.0

func crossing_allowed(a: Vector2, b: Vector2) -> bool:
	## A move between two points may not cross the pen fence except at the gate.
	## Both endpoints (and the midpoint) must sit near the gate corridor so the
	## avatar cannot clip under the fence rails by the coop.
	if in_pen(a) == in_pen(b):
		return true
	if gate_world == Vector2.ZERO:
		return true
	var mid := (a + b) * 0.5
	return a.distance_to(gate_world) <= GATE_PASS_RADIUS \
		and b.distance_to(gate_world) <= GATE_PASS_RADIUS \
		and mid.distance_to(gate_world) <= GATE_PASS_RADIUS

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
	## A* through walkable iso tiles. Crossing the pen boundary always routes
	## explicitly: to the gate → through it → to the destination. Same-side
	## walks (garden↔garden, pen↔pen) never touch the gate.
	var start_w := nearest_walkable(from_world)
	var end_w := nearest_walkable(to_world)
	if gate_world == Vector2.ZERO or in_pen(start_w) == in_pen(end_w):
		return _find_path_direct(start_w, end_w)
	var gate := nearest_walkable(gate_world)
	return _concat_paths(_find_path_direct(start_w, gate), _find_path_direct(gate, end_w))

func _find_path_direct(start_w: Vector2, end_w: Vector2) -> PackedVector2Array:
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

func _concat_paths(a: PackedVector2Array, b: PackedVector2Array) -> PackedVector2Array:
	if a.is_empty():
		return b
	if b.is_empty():
		return a
	var out := PackedVector2Array()
	out.append_array(a)
	var start_i := 0
	if not out.is_empty() and out[out.size() - 1].distance_to(b[0]) < 4.0:
		start_i = 1
	for i in range(start_i, b.size()):
		out.append(b[i])
	return out

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
		var wa: Vector2 = _astar.get_point_position(a)
		for d in deltas:
			var nb: Vector2i = cell + d
			if not _nav_cell_to_id.has(nb):
				continue
			var b: int = int(_nav_cell_to_id[nb])
			var wb: Vector2 = _astar.get_point_position(b)
			## Pen fence is impassable except through the gate opening.
			if not crossing_allowed(wa, wb):
				continue
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

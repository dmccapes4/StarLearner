class_name FarmMap
extends Node2D
## Builds the wide farm: shed (left) · path shed→gate · 3 beds north + 3 south · east pen.
## One sprite fence around the yard; the pen shares N/E/S rails. West divider + gate only.

const MAP_PATH := "res://data/map.json"
## Hit / path slot samples (tile space). Visual plant packs use furrow plot centers.
const SLOT_OFFSETS := [
	Vector2(-0.35, -0.25), Vector2(0.35, -0.25),
	Vector2(-0.35, 0.25), Vector2(0.35, 0.25),
]
## Soil diamond matching `_add_plot_grid` (furrow cross on this inset).
const PLOT_SOIL_SCALE := 0.82
const BED_HEIGHT := 28.0
## Collision pad beyond visual half — keep in sync with bed_approach stand-off.
## Must stay modest: 1.18 + wide nav samples sealed the dirt path west of bed_3
## and forced shed routes to loop east around the whole bed row.
const BED_SOLID_PAD := 1.08
## Stand just outside the raised lip — next to the bed for gardening, not mid-path.
const BED_STAND_TILES := 0.68
## Opposite-face taps may be longer than the near face; still prefer gap routes.
const BED_GAP_PATH_MAX := 320.0
const SHED_WALL_H := 64.0
const SHED_ROOF_H := 42.0

var data: Dictionary = {}
var sprites: FarmSprites
var shed_poly: PackedVector2Array = PackedVector2Array()
var fence_poly: PackedVector2Array = PackedVector2Array()
var farm_yard_poly: PackedVector2Array = PackedVector2Array()
## Inset from the perimeter fence — walkable yard (meadows / far side of rails are blocked).
var walk_yard_poly: PackedVector2Array = PackedVector2Array()
var bed_polys: Dictionary = {} ## id -> PackedVector2Array (footprint / hit)
var bed_centers: Dictionary = {} ## id -> Vector2
var bed_tiles: Dictionary = {} ## id -> Vector2
var bed_halves: Dictionary = {} ## id -> Vector2
var slot_positions: Dictionary = {} ## bed_id -> Array[Vector2]
var animal_positions: Dictionary = {} ## id -> Vector2
var shed_center: Vector2 = Vector2.ZERO
var shed_door_world: Vector2 = Vector2.ZERO ## Walk-to point just outside the door (faces garden).
var coop_world: Vector2 = Vector2.ZERO ## Chicken coop anchor (inside pen).
var coop_poly: PackedVector2Array = PackedVector2Array() ## Solid footprint — not walkable.
var coop_door_world: Vector2 = Vector2.ZERO ## Stand point in front of the coop door.
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
## Dedupes fence posts where yard perimeter meets the pen divider (T-junctions).
var _fence_post_keys: Dictionary = {}
## Keep the gardener inside the rails (tile units inset from yard bounds).
const YARD_WALK_INSET := 0.9
## Meadow trees outside the rails — kept clear of posts so canopies don't sit on them.
## Decorative trees outside the yard. South row sits fully past the rail so
## fence posts don't bisect trunks; canopy tops kiss / slightly overlap the
## fence bottom (same read as the west bush).
const MEADOW_TREES := [
	{"tile": Vector2(-12.0, -3.5), "variant": "large", "scale": 3.2},
	{"tile": Vector2(-7.0, -5.8), "variant": "med", "scale": 2.9},
	{"tile": Vector2(-2.0, -5.9), "variant": "large", "scale": 3.1},
	{"tile": Vector2(3.5, -5.9), "variant": "med", "scale": 2.8},
	{"tile": Vector2(9.0, -5.7), "variant": "narrow", "scale": 2.7},
	{"tile": Vector2(17.8, -2.0), "variant": "large", "scale": 3.0},
	{"tile": Vector2(18.0, 2.5), "variant": "med", "scale": 2.8},
	{"tile": Vector2(17.8, 7.0), "variant": "bush", "scale": 2.3},
	{"tile": Vector2(-12.0, 1.5), "variant": "med", "scale": 2.7},
	{"tile": Vector2(-11.8, 5.5), "variant": "narrow", "scale": 2.5},
	{"tile": Vector2(-11.6, 9.5), "variant": "bush", "scale": 2.2},
	## South: whole crown south of the rails so posts don't bisect trunks;
	## canopy top sits just under the post bottoms (bush-like tuck).
	{"tile": Vector2(-3.5, 18.6), "variant": "large", "scale": 3.0},
	{"tile": Vector2(1.5, 19.0), "variant": "med", "scale": 2.9},
	{"tile": Vector2(6.5, 18.6), "variant": "med", "scale": 2.7},
	{"tile": Vector2(11.0, 15.4), "variant": "bush", "scale": 2.3},
]
var _meadow_trees: Array = [] ## Sprite2D
var _season_id: String = "spring"
var _tree_wind_frame: int = 0
var _tree_wind_timer: Timer

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
	_build_shed()
	_build_beds()
	_build_perimeter_fence()
	_build_meadow_trees()
	_build_fence()
	_build_path()
	_register_animal_spawns()
	_compute_bounds()
	_rebuild_nav()
	apply_season_tint(_season_id)
	var spawn: Dictionary = data.get("player_spawn_tile", {"x": 2, "y": 4})
	spawn_world = nearest_walkable(IsoUtil.tile_to_world(Vector2(float(spawn.x), float(spawn.y))))
	if shed_door_world == Vector2.ZERO:
		shed_door_world = shed_center + Vector2(36, 40)
	## Prefer a clear apron stand — never leave the interact goal inside a bed.
	shed_door_world = shed_approach_world()
	if dog_spawn_world != Vector2.ZERO:
		dog_spawn_world = nearest_dog_walkable(dog_spawn_world)
		animal_positions["dog"] = dog_spawn_world
	if gate_world != Vector2.ZERO:
		gate_world = nearest_walkable(gate_world)
	if coop_door_world != Vector2.ZERO:
		coop_door_world = nearest_walkable(coop_door_world)
	elif coop_world != Vector2.ZERO:
		coop_door_world = nearest_walkable(coop_world + Vector2(0, 52))
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
		## Prefer a direct animal tap; otherwise the pen floor zone.
		var animal_id := animal_at(world_pos, 28.0)
		if not animal_id.is_empty():
			return {"id": animal_id, "kind": "animal"}
		return {"id": "fence", "kind": "fence"}
	## Yard dog: tight tap radius so path/bed taps near Buddy aren't stolen.
	var loose := animal_at(world_pos, 18.0)
	if not loose.is_empty():
		return {"id": loose, "kind": "animal"}
	return {}

func animal_at(world_pos: Vector2, radius: float = 48.0) -> String:
	var best := ""
	var best_d := INF
	for id in animal_positions.keys():
		## Buddy needs a deliberate tap — ignore him outside a smaller bubble.
		var r := minf(radius, 20.0) if str(id).begins_with("dog") else radius
		var d := world_pos.distance_squared_to(animal_positions[id] as Vector2)
		if d <= r * r and d < best_d:
			best_d = d
			best = str(id)
	return best

func apply_season_tint(season_id: String) -> void:
	_season_id = season_id
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
	_apply_meadow_tree_season(season_id)
	_apply_season_decor(season_id)

## Scatter decals + weather per season: fall leaves (ground + falling),
## spring flowers, winter rain over the full yard (above beds).
func _apply_season_decor(season_id: String) -> void:
	var old := get_node_or_null("SeasonDecor")
	if old:
		## Free immediately — queue_free keeps the name until frame end and
		## blocks the replacement node (weather children never register).
		remove_child(old)
		old.free()
	_clear_weather_layer()
	var decor := Node2D.new()
	decor.name = "SeasonDecor"
	decor.z_as_relative = false
	decor.z_index = IsoUtil.DEPTH_OFFSET - 10 ## ground decals under props
	add_child(decor)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260725
	match season_id:
		"fall":
			_scatter_ground_leaves(decor, rng, 46, false)
			_scatter_ground_leaves(decor, rng, 22, true) ## pen floor too
			_attach_weather_overlay("leaves")
		"spring":
			_scatter_ground_flowers(decor, rng, 36, false)
			_scatter_ground_flowers(decor, rng, 16, true)
		"winter":
			## World-space rain — yard + pen landings (SeasonWeather).
			_attach_weather_overlay("rain")
		_:
			pass

func _scatter_ground_leaves(decor: Node2D, rng: RandomNumberGenerator, count: int, in_pen_area: bool) -> void:
	for i in count:
		var p: Vector2 = _random_pen_point(rng) if in_pen_area else _random_yard_point(rng)
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

func _scatter_ground_flowers(decor: Node2D, rng: RandomNumberGenerator, count: int, in_pen_area: bool) -> void:
	for i in count:
		var p2: Vector2 = _random_pen_point(rng) if in_pen_area else _random_yard_point(rng)
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

func _clear_weather_layer() -> void:
	## World-space weather lives on FarmMap; also scrub legacy CanvasLayer hosts.
	var local := get_node_or_null("SeasonWeather")
	if local:
		remove_child(local)
		local.free()
	var hosts: Array = [self]
	if is_inside_tree():
		var scene := get_tree().current_scene
		if scene:
			hosts.append(scene)
		if get_parent():
			hosts.append(get_parent())
			if get_parent().get_parent():
				hosts.append(get_parent().get_parent())
	for host in hosts:
		if host == null:
			continue
		var old: Node = host.get_node_or_null("WeatherLayer")
		if old:
			host.remove_child(old)
			old.free()

func _attach_weather_overlay(mode: String) -> void:
	## World-space mapped landings so rain/leaves depth-sort with beds/plants.
	_clear_weather_layer()
	var weather = (load("res://scripts/world/SeasonWeather.gd") as GDScript).new()
	weather.name = "SeasonWeather"
	add_child(weather)
	weather.setup(self, sprites, mode)

func _yard_world_aabb() -> Rect2:
	## Axis-aligned bounds of the farm yard diamond (playable area).
	if farm_yard_poly.is_empty():
		return meadow_aabb()
	var min_p: Vector2 = farm_yard_poly[0]
	var max_p: Vector2 = farm_yard_poly[0]
	for p in farm_yard_poly:
		min_p.x = minf(min_p.x, p.x)
		min_p.y = minf(min_p.y, p.y)
		max_p.x = maxf(max_p.x, p.x)
		max_p.y = maxf(max_p.y, p.y)
	return Rect2(min_p, max_p - min_p)

func _random_yard_point(rng: RandomNumberGenerator) -> Vector2:
	## Playable yard floor outside the animal pen (garden side).
	for attempt in 12:
		var tx := rng.randf_range(_yard_min.x + 0.5, _yard_max.x - 0.5)
		var ty := rng.randf_range(_yard_min.y + 0.5, _yard_max.y - 0.5)
		var w := IsoUtil.tile_to_world(Vector2(tx, ty))
		if not is_blocked(w) and not in_pen(w):
			return w
	return Vector2.INF

func _random_pen_point(rng: RandomNumberGenerator) -> Vector2:
	## Inside the animal pen (for rain/leaves/decals). Prefer roam inset.
	var poly: PackedVector2Array = pen_roam_poly if pen_roam_poly.size() >= 3 else fence_poly
	if poly.size() < 3:
		return Vector2.INF
	var min_p: Vector2 = poly[0]
	var max_p: Vector2 = poly[0]
	for p in poly:
		min_p.x = minf(min_p.x, p.x)
		min_p.y = minf(min_p.y, p.y)
		max_p.x = maxf(max_p.x, p.x)
		max_p.y = maxf(max_p.y, p.y)
	for attempt in 16:
		var w := Vector2(rng.randf_range(min_p.x, max_p.x), rng.randf_range(min_p.y, max_p.y))
		if not IsoUtil.point_in_polygon(w, poly):
			continue
		if is_blocked(w):
			continue
		return w
	return Vector2.INF

func _build_meadow_trees() -> void:
	## Decorative trees outside the yard fence — never on the walkable diamond.
	_meadow_trees.clear()
	var old := get_node_or_null("MeadowTrees")
	if old:
		remove_child(old)
		old.free()
	_tree_wind_timer = null
	if sprites == null:
		return
	var root := Node2D.new()
	root.name = "MeadowTrees"
	add_child(root)
	for i in MEADOW_TREES.size():
		var spec: Dictionary = MEADOW_TREES[i]
		var tile: Vector2 = spec.get("tile", Vector2.ZERO)
		var world := IsoUtil.tile_to_world(tile)
		## Must sit outside the fenced yard (and preferably outside walk inset).
		if not farm_yard_poly.is_empty() and IsoUtil.point_in_polygon(world, farm_yard_poly):
			continue
		var variant := str(spec.get("variant", "med"))
		var tex := sprites.tree_texture(_season_id, variant, 0)
		if tex == null:
			push_warning("FarmMap: missing tree texture %s/%s" % [_season_id, variant])
			continue
		var sc := float(spec.get("scale", 2.5))
		var spr := Sprite2D.new()
		spr.name = "MeadowTree_%d" % i
		spr.texture = tex
		spr.centered = true
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.scale = Vector2(sc, sc)
		var h := float(FarmSprites.TREE_CELL_H) * sc
		spr.position = world - Vector2(0, h * 0.42)
		spr.set_meta("tree_variant", variant)
		spr.set_meta("tree_feet_y", world.y)
		spr.set_meta("wind_phase", i % 2)
		IsoUtil.apply_depth(spr, world.y, IsoUtil.BIAS_TREE)
		root.add_child(spr)
		_meadow_trees.append(spr)
	if not _meadow_trees.is_empty():
		_tree_wind_timer = Timer.new()
		_tree_wind_timer.name = "TreeWind"
		_tree_wind_timer.wait_time = 0.72
		_tree_wind_timer.autostart = true
		_tree_wind_timer.timeout.connect(_on_tree_wind_tick)
		root.add_child(_tree_wind_timer)
	print("FarmMap: meadow trees=%d" % _meadow_trees.size())

func _on_tree_wind_tick() -> void:
	_tree_wind_frame = 1 - _tree_wind_frame
	_refresh_meadow_tree_frames()

func _refresh_meadow_tree_frames() -> void:
	if sprites == null:
		return
	for spr in _meadow_trees:
		if spr == null or not is_instance_valid(spr):
			continue
		var variant := str(spr.get_meta("tree_variant", "med"))
		var phase := int(spr.get_meta("wind_phase", 0))
		var frame := (_tree_wind_frame + phase) % FarmSprites.TREE_WIND_FRAMES
		var tex := sprites.tree_texture(_season_id, variant, frame)
		if tex:
			(spr as Sprite2D).texture = tex

func _apply_meadow_tree_season(season_id: String) -> void:
	_season_id = season_id
	_refresh_meadow_tree_frames()

func slot_world(bed_id: String, slot: int) -> Vector2:
	var arr: Array = slot_positions.get(bed_id, [])
	if slot < 0 or slot >= arr.size():
		return bed_centers.get(bed_id, Vector2.ZERO)
	return arr[slot]

## Stand point for gardening a bed.
## Model (keep this simple — see docs/REVIEW_BED_APPROACH_AND_WATER.md):
##   • Each bed has four face panes (N/E/S/W) with outward normals.
##   • Default: pick the pane the avatar already faces (vector align) — walk there.
##   • Only special case: standing at an adjacent bed that blocks the line →
##     go around that bed on its closest side, then to the *same* face pane of
##     the target.
##   • Pen → garden: choose panes as if already just inside the gate; find_path
##     still routes through the gate automatically.
func bed_approach_world(bed_id: String, from_player: Vector2, tap: Vector2) -> Vector2:
	var panes: Dictionary = bed_face_panes(bed_id)
	if panes.is_empty():
		return nearest_walkable(bed_centers.get(bed_id, tap))
	var from := from_player
	var center: Vector2 = bed_centers.get(bed_id, tap)
	## Pen → garden: face selection uses a garden-side origin so the path-facing
	## pane wins; A* still walks gate → garden → pane.
	if gate_world != Vector2.ZERO and in_pen(from) != in_pen(center):
		from = _garden_just_inside_gate()
	var face := ""
	var blocker := _adjacent_blocker_at(from, bed_id)
	if not blocker.is_empty():
		face = _closest_face_key(blocker, from)
	else:
		face = _best_direct_face(bed_id, panes, from, tap)
	if face.is_empty() or not panes.has(face):
		face = _best_direct_face(bed_id, panes, from, tap)
	var pane: Dictionary = panes[face]
	return pane.get("stand", nearest_walkable(center)) as Vector2

## Four cardinal approach panes. Each: stand (world) + outward (unit, away from bed).
func bed_face_panes(bed_id: String) -> Dictionary:
	var out: Dictionary = {}
	if not bed_tiles.has(bed_id):
		return out
	var tile: Vector2 = bed_tiles[bed_id]
	var half: Vector2 = bed_halves.get(bed_id, Vector2(1.05, 0.8)) * BED_SOLID_PAD
	var stand := BED_STAND_TILES
	var center: Vector2 = bed_centers.get(bed_id, IsoUtil.tile_to_world(tile))
	var faces := {
		"N": Vector2(0.0, -(half.y + stand)),
		"S": Vector2(0.0, +(half.y + stand)),
		"E": Vector2(+(half.x + stand), 0.0),
		"W": Vector2(-(half.x + stand), 0.0),
	}
	for key in faces.keys():
		var ideal := IsoUtil.tile_to_world(tile + faces[key])
		var stand_w := _stand_clear_of_bed(bed_id, ideal)
		var outward := stand_w - center
		if outward.length_squared() < 1.0:
			outward = faces[key]
		out[key] = {
			"face": key,
			"stand": stand_w,
			"outward": outward.normalized(),
		}
	return out

func _garden_just_inside_gate() -> Vector2:
	var g := nearest_walkable(gate_world)
	## Pen is east of the west-edge gate — step west into the garden.
	for dx in [-28.0, -52.0, -76.0, -100.0]:
		var p := nearest_walkable(g + Vector2(dx, 0.0))
		if not in_pen(p):
			return p
	return g

func _adjacent_blocker_at(from: Vector2, target_id: String) -> String:
	## Player is "at" a neighboring bed (within its stand ring) that sits between
	## them and the target — that bed is the only thing we route around on purpose.
	var best := ""
	var best_d := INF
	var tcenter: Vector2 = bed_centers.get(target_id, from)
	for id in bed_centers.keys():
		var bid := str(id)
		if bid == target_id:
			continue
		if not _beds_are_neighbors(bid, target_id):
			continue
		var c: Vector2 = bed_centers[bid]
		var d := from.distance_to(c)
		if d > _bed_min_stand_dist(bid) * 1.35:
			continue
		## Blocker should lie roughly between player and target.
		var to_t := tcenter - from
		var to_b := c - from
		if to_t.length_squared() < 1.0:
			continue
		if to_b.dot(to_t.normalized()) < 8.0:
			continue
		if d < best_d:
			best_d = d
			best = bid
	return best

func _beds_are_neighbors(a: String, b: String) -> bool:
	## Two rows of three: horizontal neighbors in-row, vertical across the path.
	var order := ["bed_0", "bed_1", "bed_2", "bed_3", "bed_4", "bed_5"]
	var ia := order.find(a)
	var ib := order.find(b)
	if ia < 0 or ib < 0:
		## Fallback: nearby centers.
		var ca: Vector2 = bed_centers.get(a, Vector2.ZERO)
		var cb: Vector2 = bed_centers.get(b, Vector2.ZERO)
		return ca.distance_to(cb) < 220.0
	var row_a := 0 if ia < 3 else 1
	var row_b := 0 if ib < 3 else 1
	var col_a := ia % 3
	var col_b := ib % 3
	if row_a == row_b and absi(col_a - col_b) == 1:
		return true
	if col_a == col_b and absi(row_a - row_b) == 1:
		return true
	return false

func _closest_face_key(bed_id: String, from: Vector2) -> String:
	var panes: Dictionary = bed_face_panes(bed_id)
	var best := "S"
	var best_d := INF
	for key in panes.keys():
		var stand: Vector2 = (panes[key] as Dictionary).get("stand", from)
		var d := from.distance_squared_to(stand)
		if d < best_d:
			best_d = d
			best = str(key)
	return best

func _best_direct_face(bed_id: String, panes: Dictionary, from: Vector2, tap: Vector2) -> String:
	var center: Vector2 = bed_centers.get(bed_id, from)
	var from_dir := from - center
	if from_dir.length_squared() < 1.0:
		from_dir = Vector2(0, 1)
	from_dir = from_dir.normalized()
	var tap_off := tap - center
	var tap_clear := tap_off.length_squared() >= 120.0
	var tap_dir := tap_off.normalized() if tap_clear else from_dir
	## Kid tapped the far lip — honor that face.
	if tap_clear and tap_dir.dot(from_dir) < -0.15:
		return _face_from_dir(tap_dir, panes)
	var best := "S"
	var best_score := -INF
	for key in panes.keys():
		var pane: Dictionary = panes[key]
		var stand: Vector2 = pane.get("stand", center)
		var outward: Vector2 = pane.get("outward", Vector2(0, 1))
		## Pane facing the avatar (outward toward player) wins.
		var score := outward.dot(from_dir) * 100.0
		if tap_clear:
			score += outward.dot(tap_dir) * 35.0
		## Prefer almost-direct walks; heavy penalty for A* detours (wrong face).
		var crow := from.distance_to(stand)
		var plen := path_world_length(from, stand)
		if crow > 1.0 and plen > crow * 2.2:
			score -= (plen - crow) * 0.35
		score -= crow * 0.02
		if score > best_score:
			best_score = score
			best = str(key)
	return best

func _face_from_dir(dir: Vector2, panes: Dictionary) -> String:
	var best := "S"
	var best_dot := -INF
	for key in panes.keys():
		var outward: Vector2 = (panes[key] as Dictionary).get("outward", Vector2(0, 1))
		var d := outward.dot(dir)
		if d > best_dot:
			best_dot = d
			best = str(key)
	return best

func _stand_clear_of_bed(bed_id: String, ideal: Vector2) -> Vector2:
	## Prefer the face stand (half + small lip). Only nudge out if blocked.
	var center: Vector2 = bed_centers.get(bed_id, ideal)
	var dir := ideal - center
	if dir.length_squared() < 1.0:
		dir = Vector2(0.0, 1.0)
	dir = dir.normalized()
	var min_d := _bed_min_stand_dist(bed_id)
	var p := ideal if ideal.distance_to(center) >= min_d * 0.85 else center + dir * min_d
	for _i in 12:
		if not is_blocked(p) and _nav_id_at_world(p) >= 0:
			return p
		p += dir * 6.0
	return nearest_walkable(center + dir * min_d, 6)

func _bed_min_stand_dist(bed_id: String) -> float:
	var half: Vector2 = bed_halves.get(bed_id, Vector2(1.05, 0.8)) * BED_SOLID_PAD
	## Shorter axis (N/S) dominates "next to the lip" — keep a modest floor.
	var face_s := IsoUtil.tile_to_world(Vector2(0.0, half.y + BED_STAND_TILES)) \
		- IsoUtil.tile_to_world(Vector2.ZERO)
	return maxf(face_s.length(), 40.0)

func path_world_length(from_world: Vector2, to_world: Vector2) -> float:
	var pts := find_path(from_world, to_world)
	if pts.is_empty():
		return from_world.distance_to(to_world) * 12.0
	var L := from_world.distance_to(pts[0])
	for i in range(1, pts.size()):
		L += pts[i - 1].distance_to(pts[i])
	return L

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
	coop_poly = PackedVector2Array()
	coop_world = Vector2.ZERO
	coop_door_world = Vector2.ZERO
	_meadow_trees.clear()
	_fence_post_keys.clear()
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
	var yard_c := (_yard_min + _yard_max) * 0.5
	var yard_h := (_yard_max - _yard_min) * 0.5
	farm_yard_poly = IsoUtil.diamond_polygon(yard_c, yard_h)
	## Player stays inside the fence line — not on the far/meadow side of the rails.
	walk_yard_poly = IsoUtil.diamond_polygon(
		yard_c, Vector2(maxf(yard_h.x - YARD_WALK_INSET, 1.0), maxf(yard_h.y - YARD_WALK_INSET, 1.0))
	)
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

func _path_tile_y() -> float:
	return float(data.get("path", {}).get("tile_y", 3.0))

func _build_path() -> void:
	## Dirt strip shed door → pen gate. With 3 beds on each side, path is centered
	## (map.json tile_y); a single-sided 6-bed row would push the path lower/left.
	var cfg: Dictionary = data.get("path", {})
	var ty := float(cfg.get("tile_y", 3.0))
	var hy := float(cfg.get("half_y", 0.55))
	var pen_x := float(data.get("fence", {}).get("pen_min_x", 8.5))
	var from_x := float(cfg.get("from_x", -4.8))
	var to_x := float(cfg.get("to_x", pen_x))
	var shed: Dictionary = data.get("shed", {})
	if not shed.is_empty():
		var stile := _vec2(shed.get("tile", {"x": -7, "y": 2}))
		var shalf := _vec2(shed.get("half_tiles", {"x": 2.0, "y": 1.7}))
		## Start just east of the shed footprint so the path meets the door apron.
		from_x = stile.x + shalf.x * 0.55
	to_x = pen_x
	var cx := (from_x + to_x) * 0.5
	var hx := absf(to_x - from_x) * 0.5
	var path := Polygon2D.new()
	path.name = "Path"
	path.z_index = -15
	path.color = Color(0.72, 0.62, 0.42, 1.0)
	path.polygon = IsoUtil.diamond_polygon(Vector2(cx, ty), Vector2(hx, hy))
	add_child(path)
	if sprites:
		var ptex := sprites.path_texture()
		if ptex:
			path.texture = ptex
			path.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED

func _build_perimeter_fence() -> void:
	## Sprite fence around the whole farm yard (meadows read as outside).
	_fence_post_keys.clear()
	var corners := [
		_yard_min,
		Vector2(_yard_max.x, _yard_min.y),
		_yard_max,
		Vector2(_yard_min.x, _yard_max.y),
	]
	_draw_sprite_fence_loop("Yard", corners, -1)

func _draw_fence_loop(prefix: String, corners: Array, posts_per_edge: int) -> void:
	## Legacy poly fence (tests / no sprites).
	for i in 4:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 4]
		var wa := IsoUtil.tile_to_world(a)
		var wb := IsoUtil.tile_to_world(b)
		for rail_y in [-18.0, -9.0]:
			var rail := Polygon2D.new()
			rail.name = "%sRail_%d_%d" % [prefix, i, int(rail_y)]
			rail.z_index = IsoUtil.depth_from_y(maxf(wa.y, wb.y)) + 2
			rail.color = Color(196 / 255.0, 154 / 255.0, 108 / 255.0, 1.0)
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
			post.z_index = IsoUtil.depth_from_y(world.y) + 4
			post.color = Color(170 / 255.0, 121 / 255.0, 89 / 255.0, 1.0)
			post.polygon = PackedVector2Array([
				world + Vector2(-3.5, -24), world + Vector2(3.5, -24),
				world + Vector2(3.5, 5), world + Vector2(-3.5, 5),
			])
			add_child(post)

func _has_fence_sprites() -> bool:
	return sprites != null and sprites.has_method("pen_fence_segment") \
		and sprites.pen_fence_segment("rail_a") != null \
		and sprites.pen_fence_segment("post") != null

func _fence_rail_kind(edge_i: int) -> String:
	## Rails only (no baked posts). Match iso slope — no flip_h.
	##   slope +0.5 (edges 0, 2) → rail_b
	##   slope -0.5 (edges 1, 3) → rail_a
	if edge_i == 0 or edge_i == 2:
		return "rail_b"
	return "rail_a"

func _segs_for_edge(a: Vector2, b: Vector2) -> int:
	## ~2.2 tiles per rail — denser joints so near-corner posts aren't skipped.
	return maxi(4, int(ceil(a.distance_to(b) / 2.2)))

func _place_fence_sprite(name: String, tex: Texture2D, world: Vector2, scale: float, bias: int) -> void:
	if tex == null:
		return
	var spr := Sprite2D.new()
	spr.name = name
	spr.texture = tex
	spr.centered = true
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.scale = Vector2(scale, scale)
	spr.position = world + Vector2(0, -6)
	## Perimeter fence must read in front of beds even when iso Y is ambiguous.
	IsoUtil.apply_depth(spr, _fence_sort_y(world.y), bias)
	add_child(spr)

func _place_fence_rail(name: String, kind: String, tile_a: Vector2, tile_b: Vector2) -> void:
	## Rails sort by farther endpoint so neighboring posts (higher bias) stay on top.
	var tex: Texture2D = sprites.pen_fence_segment(kind)
	if tex == null:
		return
	var wa := IsoUtil.tile_to_world(tile_a)
	var wb := IsoUtil.tile_to_world(tile_b)
	var mid := (wa + wb) * 0.5
	var spr := Sprite2D.new()
	spr.name = name
	spr.texture = tex
	spr.centered = true
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.scale = Vector2(2.0, 2.0)
	spr.position = mid + Vector2(0, -6)
	IsoUtil.apply_depth(spr, _fence_sort_y(maxf(wa.y, wb.y)), IsoUtil.BIAS_RAIL)
	add_child(spr)

func _fence_sort_y(world_y: float) -> float:
	## Near-side rails/posts must clear bed decks (SW iso Y can put beds in front).
	## Far-side fence keeps natural Y so north rails stay behind the yard.
	var bed_y := _max_bed_sort_y()
	if world_y >= bed_y - 28.0:
		return maxf(world_y, bed_y + 14.0)
	return world_y

func _max_bed_sort_y() -> float:
	var best := -INF
	for id in bed_tiles.keys():
		best = maxf(best, _bed_sort_y(bed_tiles[id], bed_halves[id]))
	if best == -INF:
		return IsoUtil.tile_to_world(_yard_max).y
	return best

func _try_place_post(name: String, tile: Vector2) -> bool:
	## One post per joint. Deduped by key + proximity (corners / T-junctions).
	var key := "%.1f,%.1f" % [snappedf(tile.x, 0.1), snappedf(tile.y, 0.1)]
	if _fence_post_keys.has(key):
		return false
	var world := IsoUtil.tile_to_world(tile)
	for other_key in _fence_post_keys:
		var parts: PackedStringArray = str(other_key).split(",")
		if parts.size() != 2:
			continue
		var ot := Vector2(float(parts[0]), float(parts[1]))
		if world.distance_to(IsoUtil.tile_to_world(ot)) < 22.0:
			return false
	_fence_post_keys[key] = true
	var tex: Texture2D = sprites.pen_fence_segment("post")
	_place_fence_sprite(name, tex, world, 2.35, IsoUtil.BIAS_POST)
	return true

func _force_place_post(name: String, tile: Vector2) -> void:
	## Gate framing — always place even if a nearby joint already has a post.
	var key := "%.1f,%.1f" % [snappedf(tile.x, 0.1), snappedf(tile.y, 0.1)]
	_fence_post_keys[key] = true
	var tex: Texture2D = sprites.pen_fence_segment("post")
	_place_fence_sprite(name, tex, IsoUtil.tile_to_world(tile), 2.35, IsoUtil.BIAS_POST)

func _gate_seg_index(a: Vector2, b: Vector2) -> int:
	## One fence-section opening on the divider, aligned with the path tile-y.
	var n_segs := _segs_for_edge(a, b)
	var path_y := _path_tile_y()
	var denom := b.y - a.y
	var t := 0.5
	if absf(denom) > 0.001:
		t = clampf((path_y - a.y) / denom, 0.05, 0.95)
	var seg := int(floor(t * float(n_segs)))
	return clampi(seg, 1, maxi(n_segs - 2, 0))

func _draw_edge_fence(prefix: String, edge_i: int, a: Vector2, b: Vector2, leave_gate: bool, include_end: bool) -> void:
	var kind := _fence_rail_kind(edge_i)
	var n_segs := _segs_for_edge(a, b)
	var gate_seg := _gate_seg_index(a, b) if leave_gate else -1
	## Rails first (under).
	for step in range(0, n_segs):
		if leave_gate and step == gate_seg:
			continue
		var t0 := float(step) / float(n_segs)
		var t1 := float(step + 1) / float(n_segs)
		var ta: Vector2 = a.lerp(b, t0 + 0.10)
		var tb: Vector2 = a.lerp(b, t1 - 0.10)
		_place_fence_rail("%sRail_%d_%d" % [prefix, edge_i, step], kind, ta, tb)
	## Posts on joints (gate opening keeps its two framing posts — one section wide).
	for p in range(0, n_segs):
		var t := float(p) / float(n_segs)
		var pt: Vector2 = a.lerp(b, t)
		if not include_end and p > 0 and pt.distance_to(b) < 2.0:
			continue
		_try_place_post("%sPost_%d_%d" % [prefix, edge_i, p], pt)
	if include_end:
		_try_place_post("%sPost_end" % prefix, b)

func _draw_sprite_fence_loop(prefix: String, corners: Array, gate_edge: int) -> void:
	## Per-piece rails + posts with local iso depth (not one mega-sprite).
	if not _has_fence_sprites():
		_draw_fence_loop(prefix, corners, 5)
		return
	for i in 4:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 4]
		_draw_edge_fence(prefix, i, a, b, i == gate_edge, false)
	## Guarantee the four geometric corners.
	for i in 4:
		_try_place_post("%sCorner_%d" % [prefix, i], corners[i])
	## Pen T-junctions on N/S yard edges.
	if prefix == "Yard":
		var pen_x := float(data.get("fence", {}).get("pen_min_x", 8.5))
		_try_place_post("YardPenTee_N", Vector2(pen_x, _yard_min.y))
		_try_place_post("YardPenTee_S", Vector2(pen_x, _yard_max.y))
		## Fill near-corner gaps on the back (north) + west edges.
		var nw: Vector2 = corners[0]
		var ne: Vector2 = corners[1]
		var sw: Vector2 = corners[3]
		for t in [0.08, 0.16, 0.24]:
			_try_place_post("YardNorthNearW_%s" % str(t), nw.lerp(ne, t))
		_try_place_post("YardNorthNearE", nw.lerp(ne, 0.88))
		for t in [0.76, 0.88, 0.96]:
			_try_place_post("YardWestNearN_%s" % str(t), sw.lerp(nw, t))

const SHED_SPRITE := "res://assets/buildings/shed_v2.png"
const SHED_SPRITE_SCALE := 2.2

func _build_shed() -> void:
	## Composed Sprout Lands shed (tools/build_shed_sprite.py): front-facing
	## with a CENTERED door — the walk path leads straight to it.
	var shed: Dictionary = data.get("shed", {})
	var tile := _vec2(shed.get("tile", {"x": -7, "y": 2}))
	var half := _vec2(shed.get("half_tiles", {"x": 2.0, "y": 1.7}))
	var base := IsoUtil.diamond_polygon(tile, half)
	## Solid body matches the tall facade; shifted north so the door apron stays walkable.
	var solid_tile := tile + Vector2(0.0, -0.45)
	var solid_half := half + Vector2(1.15, 0.85)
	shed_poly = IsoUtil.solid_diamond(solid_tile, solid_half)
	shed_center = IsoUtil.tile_to_world(tile)
	var z := IsoUtil.depth_z(shed_center.y, IsoUtil.BIAS_BUILDING)

	## Bottom of the facade sits on the south corner row of the footprint,
	## so the door lands at the footprint's near edge, centered.
	var south := IsoUtil.tile_to_world(tile + Vector2(half.x * 0.5, half.y * 0.5))
	## Far enough south that nearest_walkable cannot snap into a bed diamond.
	shed_door_world = south + Vector2(0, 44)

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
		## Feet-based sort in the building/post band (see IsoUtil.BIAS_*).
		IsoUtil.apply_depth(spr, south.y, IsoUtil.BIAS_BUILDING)
		add_child(spr)
	else:
		## Fallback: simple extruded box (headless tests without the asset).
		var faces: Array = IsoUtil.extrusion_side_faces(base, SHED_WALL_H)
		_add_poly("ShedWallW", faces[0], Color(0.62, 0.42, 0.24, 1.0), z + 1)
		_add_poly("ShedWallE", faces[1], Color(0.50, 0.32, 0.16, 1.0), z + 2)
		_add_poly("ShedEave", IsoUtil.raise_poly(base, SHED_WALL_H), Color(0.52, 0.34, 0.18, 1.0), z + 3)

func _bed_sort_y(tile: Vector2, half: Vector2) -> float:
	## Near-side ground contact, inset from the extreme south tip so a gardener
	## at the lip / path sorts in front of the raised deck (not under it).
	return IsoUtil.feet_south(tile, half, 0.52).y

func bed_sort_y(bed_id: String) -> float:
	## Public sort key for plants / stars / weather that sit on a bed deck.
	if not bed_tiles.has(bed_id):
		return bed_centers.get(bed_id, Vector2.ZERO).y
	return _bed_sort_y(bed_tiles[bed_id], bed_halves[bed_id])

func player_depth_y(world_pos: Vector2) -> float:
	## Sort past every nearby prop whose art can cover the gardener.
	## Same-bed lip was not enough: a slightly more-southern neighbor bed has
	## higher sort_y, so its northern canopy painted over the player even when
	## player_z beat *that* bed's plant_z was never required.
	##
	## Contract: player_z = depth_y + BIAS_PLAYER must exceed
	##   bed_sort_y + BIAS_PLANT, gate.y + BIAS_GATE, and (near south) the
	##   perimeter fence band from _fence_sort_y (bed_max + 14 + BIAS_POST).
	var y := world_pos.y
	const CLEAR_PAST := 22.0
	## Raised wood + pack foliage still cover the path north of the sort line.
	const CANOPY_NORTH := 56.0
	for id in bed_tiles.keys():
		var half: Vector2 = bed_halves[id]
		var c: Vector2 = bed_centers[id]
		var sy := _bed_sort_y(bed_tiles[id], half)
		var reach := (half.x + half.y) * 22.0 + 48.0
		## A more-southern bed's north canopy shades far up the iso diagonal.
		if sy > world_pos.y:
			reach += minf(sy - world_pos.y, 90.0) + 36.0
		var in_soil := bed_polys.has(id) and not (bed_polys[id] as PackedVector2Array).is_empty() \
			and Geometry2D.is_point_in_polygon(world_pos, bed_polys[id])
		if not in_soil and world_pos.distance_to(c) > reach:
			continue
		if in_soil or world_pos.y >= sy - CANOPY_NORTH:
			y = maxf(y, sy + CLEAR_PAST)
	## Gate leaf / posts share the fence sort band (often _fence_sort_y-boosted).
	## Framing posts sit slightly south of gate_world — need a wide margin.
	if gate_world != Vector2.ZERO and world_pos.distance_to(gate_world) < 80.0:
		var gate_sort := _fence_sort_y(gate_world.y + 18.0)
		y = maxf(y, gate_sort + 36.0)
		y = maxf(y, gate_world.y + 40.0)
	## Near-side perimeter fence is boosted past all beds (_fence_sort_y).
	## Match that sort key or south-lip / bed_5 goals draw under the rails.
	var bed_max := _max_bed_sort_y()
	if world_pos.y >= bed_max - 48.0:
		var fence_sort := _fence_sort_y(maxf(world_pos.y, bed_max))
		y = maxf(y, fence_sort + 22.0)
	return y

func shed_approach_world() -> Vector2:
	## Walk-to stand on the dirt apron — never inside a bed diamond.
	var door := shed_door_world if shed_door_world != Vector2.ZERO \
		else shed_center + Vector2(36, 40)
	var candidates: Array = [
		door,
		door + Vector2(0, 16),
		door + Vector2(18, 20),
		door + Vector2(-18, 20),
		door + Vector2(0, 32),
		door + Vector2(28, 28),
		door + Vector2(-28, 28),
	]
	for c in candidates:
		var w: Vector2 = nearest_walkable(c as Vector2)
		if not _near_bed_footprint(w, 14.0):
			return w
	return nearest_walkable(door + Vector2(0, 48))

func _near_bed_footprint(world_pos: Vector2, pad: float) -> bool:
	for id in bed_polys.keys():
		var poly: PackedVector2Array = bed_polys[id]
		if poly.is_empty():
			continue
		if Geometry2D.is_point_in_polygon(world_pos, poly):
			return true
		## Pad: close to bed edge still reads as "in the bed" for kids.
		var c: Vector2 = bed_centers.get(id, world_pos)
		var half: Vector2 = bed_halves.get(id, Vector2(1.0, 0.8))
		if world_pos.distance_to(c) < (half.x + half.y) * 18.0 + pad:
			## Only count when roughly on the bed's south/path side cluster.
			if absf(world_pos.y - c.y) < 55.0 and absf(world_pos.x - c.x) < 70.0:
				return true
	return false

func _build_beds() -> void:
	var beds: Array = data.get("beds", [])
	assert(beds.size() == 6, "FarmMap: expected 6 beds")
	for i in beds.size():
		var bed: Dictionary = beds[i]
		var id := str(bed.get("id", "bed_%d" % i))
		var tile := _vec2(bed.get("tile", {"x": 0, "y": 0}))
		var half := _vec2(bed.get("half_tiles", {"x": 1.1, "y": 0.85}))
		var base := IsoUtil.diamond_polygon(tile, half)
		## Solid padded past the wood lip so soft-step / nav can't slip onto the soil.
		bed_polys[id] = IsoUtil.solid_diamond(tile, half * BED_SOLID_PAD)
		bed_tiles[id] = tile
		bed_halves[id] = half
		var center := IsoUtil.tile_to_world(tile)
		bed_centers[id] = center
		var z := IsoUtil.depth_z(_bed_sort_y(tile, half), IsoUtil.BIAS_BUILDING)

		## Wood side walls (extrusion) — visual uses unpadded footprint.
		## Keep the bed stack shallow (+1..+3) so lip standers clear it with little Y.
		var faces: Array = IsoUtil.extrusion_side_faces(base, BED_HEIGHT)
		_add_poly(id + "_wall_w", faces[0], Color(0.62, 0.42, 0.22, 1.0), z + 1)
		_add_poly(id + "_wall_e", faces[1], Color(0.48, 0.30, 0.14, 1.0), z + 1)

		## Bed top: lighter wooden frame with dark freshly-turned soil inside.
		var top := IsoUtil.raise_poly(base, BED_HEIGHT)
		_add_poly(id, top, Color(0.55, 0.36, 0.18, 1.0), z + 2)
		var soil_poly := IsoUtil.raise_poly(IsoUtil.diamond_polygon(tile, half * 0.86), BED_HEIGHT)
		var soil := _add_poly(id + "_soil", soil_poly, Color(0.30, 0.185, 0.09, 1.0), z + 2)
		if sprites:
			var ttex := sprites.tilled_texture()
			if ttex:
				soil.texture = ttex
				soil.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED

		## Two perpendicular furrows split the soil into four iso plots — clean
		## "plant here" squares, no grey overlay.
		_add_plot_grid(id, tile, half, z + 3)
		_add_slot_markers(id, tile, half)

## Iso half-size (in tiles) of one plot patch — inside its furrow square, no overlap.
const SLOT_MARKER_HALF := Vector2(0.22, 0.155)

func _add_slot_markers(bed_id: String, tile: Vector2, half: Vector2) -> void:
	## Logical plot centers (hit/path targets) — geometry only, drawn as the grid.
	var positions: Array = []
	for i in SLOT_OFFSETS.size():
		var slot_tile: Vector2 = tile + SLOT_OFFSETS[i] * half
		positions.append(IsoUtil.tile_to_world(slot_tile))
	slot_positions[bed_id] = positions

func plot_centers_raised(bed_id: String) -> Array:
	## World positions of the four furrow-plot centers on the raised soil top.
	## Order: N, E, S, W (diamond corners) — matches bed_packs bake order.
	if not bed_tiles.has(bed_id):
		return []
	return _plot_centers_raised(bed_tiles[bed_id], bed_halves[bed_id])

func plot_offsets_from_cross(bed_id: String) -> Array:
	## plot_center - bed_plot_cross for each plot (iso-correct pack child offsets).
	var cross := bed_plot_cross(bed_id)
	var out: Array = []
	for p in plot_centers_raised(bed_id):
		out.append(p - cross)
	return out

## Fraction along cross→soil-corner for plant landings (match tools/gen_bed_plant_packs.py).
const PLOT_CORNER_T := 0.42
## Seeds use geometric plot centroids (t=0.5), not the inset plant-foot landings.
const SEED_PLOT_CORNER_T := 0.5

func _plot_centers_raised(tile: Vector2, half: Vector2, corner_t: float = PLOT_CORNER_T) -> Array:
	## Furrows split the soil diamond into N/E/S/W regions. Landing sits on the
	## ray from the furrow cross toward each soil corner (not tile-space NW/NE).
	var top: PackedVector2Array = IsoUtil.raise_poly(
		IsoUtil.diamond_polygon(tile, half * PLOT_SOIL_SCALE), BED_HEIGHT
	)
	var cross := IsoUtil.tile_to_world(tile) + Vector2(0, -BED_HEIGHT)
	var centers: Array = []
	for i in mini(4, top.size()):
		centers.append(cross.lerp(top[i], corner_t))
	return centers

func plot_seed_offsets_from_cross(bed_id: String) -> Array:
	## True plot centers for seed sprites (geometric centroid of each furrow region).
	if not bed_tiles.has(bed_id):
		return []
	var cross := bed_plot_cross(bed_id)
	var out: Array = []
	for p in _plot_centers_raised(bed_tiles[bed_id], bed_halves[bed_id], SEED_PLOT_CORNER_T):
		out.append(p - cross)
	return out

func _add_plot_grid(bed_id: String, tile: Vector2, half: Vector2, z: int) -> void:
	## Divide the soil-top diamond into four squares with two furrow lines
	## through the center (midpoint of each edge to the opposite edge midpoint).
	var top := IsoUtil.raise_poly(IsoUtil.diamond_polygon(tile, half * PLOT_SOIL_SCALE), BED_HEIGHT)
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
	line.z_as_relative = false
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
	## Raised soil — center of furrow plot (for packs / tools).
	var centers: Array = plot_centers_raised(bed_id)
	if slot < 0 or slot >= centers.size():
		return bed_plot_cross(bed_id)
	return centers[slot]

func bed_plot_cross(bed_id: String) -> Vector2:
	## Where the four plot furrows meet — soil-top center of the bed.
	var center: Vector2 = bed_centers.get(bed_id, Vector2.ZERO)
	return center + Vector2(0, -BED_HEIGHT)

func _build_fence() -> void:
	## Pen = east strip of the yard, full N–S height. Shares the yard perimeter
	## on north / east / south; only the west divider + gate is drawn here.
	var fence: Dictionary = data.get("fence", {})
	var pen_min_x := float(fence.get("pen_min_x", 8.5))
	var pen_min := Vector2(pen_min_x, _yard_min.y)
	var pen_max := Vector2(_yard_max.x, _yard_max.y)
	var corners := [
		Vector2(pen_min.x, pen_min.y),
		Vector2(pen_max.x, pen_min.y),
		Vector2(pen_max.x, pen_max.y),
		Vector2(pen_min.x, pen_max.y),
	]
	fence_poly = PackedVector2Array()
	for c in corners:
		fence_poly.append(IsoUtil.tile_to_world(c))
	var inset := 0.55
	var roam_corners := [
		Vector2(pen_min.x + inset, pen_min.y + inset),
		Vector2(pen_max.x - inset, pen_min.y + inset),
		Vector2(pen_max.x - inset, pen_max.y - inset),
		Vector2(pen_min.x + inset, pen_max.y - inset),
	]
	pen_roam_poly = PackedVector2Array()
	for c in roam_corners:
		pen_roam_poly.append(IsoUtil.tile_to_world(c))
	var center_tile := (pen_min + pen_max) * 0.5
	fence_center = IsoUtil.tile_to_world(center_tile)
	var z := IsoUtil.depth_from_y(fence_center.y)

	## No separate pen floor fill — pen is just the east strip of the yard grass.

	## West divider only (SW→NW along pen_min_x) — one fence-section gate on the path.
	var div_a := Vector2(pen_min.x, pen_max.y)
	var div_b := Vector2(pen_min.x, pen_min.y)
	_draw_pen_divider("Pen", div_a, div_b)
	var n_segs := _segs_for_edge(div_a, div_b)
	var gseg := _gate_seg_index(div_a, div_b)
	var gt := (float(gseg) + 0.5) / float(n_segs)
	gate_world = IsoUtil.tile_to_world(div_a.lerp(div_b, gt) + Vector2(0.05, 0.0))
	## Framing posts: nearer (SW / higher world-y) above the leaf; farther (NW) behind it.
	## Force both — proximity dedupe can skip the far post when a divider joint is close.
	if _has_fence_sprites():
		_force_place_post("PenGatePost_near", div_a.lerp(div_b, float(gseg) / float(n_segs)))
		_force_place_post("PenGatePost_far", div_a.lerp(div_b, float(gseg + 1) / float(n_segs)))

	var coop_tile := _vec2(fence.get("coop_tile", {"x": 13.0, "y": -2.2}))
	coop_world = IsoUtil.tile_to_world(coop_tile)
	var coop_half := Vector2(1.25, 1.05)
	## Solid body for the 64×80 @ 2× sprite — path must go around, never through.
	coop_poly = IsoUtil.solid_diamond(coop_tile, coop_half)
	## Approach stands on the south (door) side, outside the solid.
	coop_door_world = IsoUtil.tile_to_world(coop_tile + Vector2(0.15, 1.25))
	var coop_feet := IsoUtil.feet_south(coop_tile, coop_half, 0.95)
	if sprites:
		var coop := sprites.chicken_coop_texture()
		if coop:
			var spr := Sprite2D.new()
			spr.name = "ChickenCoop"
			spr.texture = coop
			spr.centered = true
			spr.position = coop_world + Vector2(0, -28)
			IsoUtil.apply_depth(spr, coop_feet.y, IsoUtil.BIAS_BUILDING)
			spr.scale = Vector2(2.0, 2.0)
			spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			add_child(spr)

func coop_approach_world() -> Vector2:
	## Always walk to the door apron — never into / through the coop body.
	if coop_door_world != Vector2.ZERO:
		return nearest_walkable(coop_door_world)
	if coop_world == Vector2.ZERO:
		return Vector2.ZERO
	return nearest_walkable(coop_world + Vector2(0, 52))

func _draw_pen_divider(prefix: String, tile_sw: Vector2, tile_nw: Vector2) -> void:
	## West divider between garden beds and pen — one fence-section gate on the path.
	var a := tile_sw
	var b := tile_nw
	if not _has_fence_sprites():
		var n_segs := _segs_for_edge(a, b)
		var gseg := _gate_seg_index(a, b)
		var t0 := float(gseg) / float(n_segs)
		var t1 := float(gseg + 1) / float(n_segs)
		_add_rail_segment("%sRail_a_-18" % prefix, a, a.lerp(b, t0), -18.0)
		_add_rail_segment("%sRail_a_-9" % prefix, a, a.lerp(b, t0), -9.0)
		_add_rail_segment("%sRail_b_-18" % prefix, a.lerp(b, t1), b, -18.0)
		_add_rail_segment("%sRail_b_-9" % prefix, a.lerp(b, t1), b, -9.0)
		for t in [0.0, t0, t1, 1.0]:
			var pt: Vector2 = a.lerp(b, t)
			var world := IsoUtil.tile_to_world(pt)
			var post := Polygon2D.new()
			post.name = "%sPost_%s" % [prefix, str(t)]
			post.z_index = IsoUtil.depth_from_y(world.y) + 4
			post.color = Color(170 / 255.0, 121 / 255.0, 89 / 255.0, 1.0)
			post.polygon = PackedVector2Array([
				world + Vector2(-4.5, -26), world + Vector2(4.5, -26),
				world + Vector2(4.5, 6), world + Vector2(-4.5, 6),
			])
			add_child(post)
		return
	_draw_edge_fence(prefix, 3, a, b, true, true)

func _add_rail_segment(name: String, tile_a: Vector2, tile_b: Vector2, rail_y: float) -> void:
	var wa := IsoUtil.tile_to_world(tile_a)
	var wb := IsoUtil.tile_to_world(tile_b)
	var rail := Polygon2D.new()
	rail.name = name
	rail.z_index = IsoUtil.depth_from_y(maxf(wa.y, wb.y)) + 2
	rail.color = Color(196 / 255.0, 154 / 255.0, 108 / 255.0, 1.0) ## Sprout Lands rail light
	var n := (wb - wa).normalized().orthogonal() * 3.0
	rail.polygon = PackedVector2Array([
		wa + Vector2(0, rail_y) - n,
		wb + Vector2(0, rail_y) - n,
		wb + Vector2(0, rail_y + 4.5) + n,
		wa + Vector2(0, rail_y + 4.5) + n,
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
	## Camera / clamp AABB follows the inset walk yard (not the meadow outside the fence).
	var poly: PackedVector2Array = walk_yard_poly if walk_yard_poly.size() >= 3 else farm_yard_poly
	var min_p := Vector2(INF, INF)
	var max_p := Vector2(-INF, -INF)
	for pt in poly:
		min_p.x = minf(min_p.x, pt.x)
		min_p.y = minf(min_p.y, pt.y)
		max_p.x = maxf(max_p.x, pt.x)
		max_p.y = maxf(max_p.y, pt.y)
	walk_bounds = Rect2(min_p, max_p - min_p).grow(8.0)

func is_blocked(world_pos: Vector2) -> bool:
	## Solid: shed + coop + garden beds. Pen grass is walkable (enter via west gate).
	## Outside the inset walk yard is blocked (can't cross the perimeter fence).
	if walk_yard_poly.size() >= 3 and not IsoUtil.point_in_polygon(world_pos, walk_yard_poly):
		return true
	elif farm_yard_poly.size() >= 3 and not IsoUtil.point_in_polygon(world_pos, farm_yard_poly):
		return true
	if shed_poly.size() >= 3 and IsoUtil.point_in_polygon(world_pos, shed_poly):
		return true
	if coop_poly.size() >= 3 and IsoUtil.point_in_polygon(world_pos, coop_poly):
		return true
	for id in bed_polys.keys():
		var poly: PackedVector2Array = bed_polys[id]
		if poly.size() >= 3 and IsoUtil.point_in_polygon(world_pos, poly):
			return true
	return false

func _on_dirt_path_strip(world_pos: Vector2) -> bool:
	## Intentional shed↔gate walkway — bed *samples* must not erase it.
	var path: Dictionary = data.get("path", {})
	var path_y := IsoUtil.tile_to_world(Vector2(0.0, float(path.get("tile_y", 3.0)))).y
	## ~one iso tile of half-width + a little slack for tile centers.
	return absf(world_pos.y - path_y) <= 34.0

func _nav_point_blocked(world_pos: Vector2) -> bool:
	## Block a nav cell if its center hits a solid, or if nearby samples enter
	## the shed/coop/beds (stops slipping through between integer tile centers).
	if is_blocked(world_pos):
		return true
	## Shed/coop: wider samples (tall solids).
	for off in [
		Vector2(18, 0), Vector2(-18, 0), Vector2(0, 12), Vector2(0, -12),
		Vector2(14, 10), Vector2(-14, 10), Vector2(14, -10), Vector2(-14, -10),
	]:
		var p: Vector2 = world_pos + off
		if shed_poly.size() >= 3 and IsoUtil.point_in_polygon(p, shed_poly):
			return true
		if coop_poly.size() >= 3 and IsoUtil.point_in_polygon(p, coop_poly):
			return true
	## Dirt path: keep A* connected along the road. Cell centers still cannot
	## sit inside bed polys (is_blocked above); skip expanded bed samples that
	## were sealing the strip between bed_0/bed_3 and the shed.
	if _on_dirt_path_strip(world_pos):
		return false
	## Beds off-path: modest samples (wide ring + pad 1.18 caused farm-scale loops).
	for off_b in [Vector2(10, 0), Vector2(-10, 0), Vector2(0, 8), Vector2(0, -8)]:
		var pb: Vector2 = world_pos + off_b
		for id in bed_polys.keys():
			var poly: PackedVector2Array = bed_polys[id]
			if poly.size() >= 3 and IsoUtil.point_in_polygon(pb, poly):
				return true
	return false

## Keep Buddy clear of bed tops / aisles kids are using for gardening.
const DOG_BED_CLEARANCE := 92.0
## Stand beside a pet — never on top of them.
const ANIMAL_STAND_OFF := 36.0
## Soft footprint so the gardener sidesteps instead of walking through.
const ANIMAL_SOFT_R := 28.0

func animal_approach_world(from_player: Vector2, animal_pos: Vector2) -> Vector2:
	var dir := from_player - animal_pos
	if dir.length_squared() < 1.0:
		dir = Vector2(0.0, 1.0)
	var ideal := animal_pos + dir.normalized() * ANIMAL_STAND_OFF
	## Prefer path-side rim if the stand lands in a solid.
	var w := nearest_walkable(ideal)
	if w.distance_to(animal_pos) < ANIMAL_STAND_OFF * 0.55:
		w = nearest_walkable(animal_pos + Vector2(0.0, ANIMAL_STAND_OFF))
	return w

func near_roaming_animal(world_pos: Vector2, radius: float = ANIMAL_SOFT_R, ignore_id: String = "") -> String:
	var best := ""
	var best_d := radius
	for id in animal_positions.keys():
		if str(id) == ignore_id:
			continue
		var p: Vector2 = animal_positions[id]
		var d := world_pos.distance_to(p)
		if d <= best_d:
			best_d = d
			best = str(id)
	return best

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

func is_blocked_for_bug(world_pos: Vector2) -> bool:
	## Bugs may loiter on the rim, but not under the raised wood / on soil.
	if is_blocked(world_pos):
		return true
	for id in bed_centers.keys():
		if world_pos.distance_to(bed_centers[id]) < _bed_min_stand_dist(id) * 0.9:
			return true
	return false

func nearest_bug_walkable(world_pos: Vector2, max_radius_tiles: int = 8) -> Vector2:
	if not is_blocked_for_bug(world_pos) and _nav_id_at_world(world_pos) >= 0:
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
				if is_blocked_for_bug(w):
					continue
				var d := world_pos.distance_squared_to(w)
				if d < best_d:
					best_d = d
					best = w
		if best_d < INF and r >= 1:
			break
	return best

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

## One fence-section opening (~2 tiles / ~72 world units).
const GATE_PASS_RADIUS := 40.0

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
			if _nav_point_blocked(w):
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
			## Diagonal shortcuts must not cut through a bed solid.
			## Use is_blocked (not sample-expanded _nav_point_blocked) so midpoints
			## on the path strip / aisles stay connected.
			var mid: Vector2 = (wa + wb) * 0.5
			if is_blocked(mid):
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
	p.z_as_relative = false
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

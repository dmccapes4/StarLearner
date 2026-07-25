class_name IsoUtil
extends RefCounted
## 2:1 dimetric helpers. Tile (cell) → world; world → nearest cell.

const TILE_W: float = 64.0
const TILE_H: float = 32.0
const DEPTH_OFFSET: int = 2000

static func tile_to_world(cell: Vector2) -> Vector2:
	return Vector2(
		(cell.x - cell.y) * (TILE_W * 0.5),
		(cell.x + cell.y) * (TILE_H * 0.5)
	)

static func tile_to_world_i(cell: Vector2i) -> Vector2:
	return tile_to_world(Vector2(cell))

static func world_to_tile(world: Vector2) -> Vector2i:
	var x := world.x / (TILE_W * 0.5)
	var y := world.y / (TILE_H * 0.5)
	var cell_x := int(floor((x + y) * 0.5))
	var cell_y := int(floor((y - x) * 0.5))
	return Vector2i(cell_x, cell_y)

static func depth_from_y(world_y: float) -> int:
	return int(world_y) + DEPTH_OFFSET

## Axis-aligned diamond (iso footprint) centered on a tile with half-extents in tile units.
## Vertex order: far, east, near, west (screen: N, E, S, W of the diamond).
static func diamond_polygon(center_tile: Vector2, half_tiles: Vector2) -> PackedVector2Array:
	var c := tile_to_world(center_tile)
	var e := tile_to_world(center_tile + Vector2(half_tiles.x, 0.0)) - c
	var s := tile_to_world(center_tile + Vector2(0.0, half_tiles.y)) - c
	return PackedVector2Array([
		c - e - s,
		c + e - s,
		c + e + s,
		c - e + s,
	])

## Raise a footprint polygon up the screen (negative Y) for fake-3D tops.
static func raise_poly(poly: PackedVector2Array, height_px: float) -> PackedVector2Array:
	var up := Vector2(0.0, -height_px)
	var out := PackedVector2Array()
	for p in poly:
		out.append(p + up)
	return out

## Near-facing wall quads for an extruded iso prism (west+east sides the camera sees).
## Returns [west_face, east_face] as PackedVector2Array quads (bottom→top).
static func extrusion_side_faces(base: PackedVector2Array, height_px: float) -> Array:
	var top := raise_poly(base, height_px)
	## base: 0=far, 1=east, 2=near, 3=west
	var west := PackedVector2Array([base[3], base[2], top[2], top[3]])
	var east := PackedVector2Array([base[2], base[1], top[1], top[2]])
	return [west, east]

static func point_in_polygon(point: Vector2, poly: PackedVector2Array) -> bool:
	## Ray cast; Godot Geometry2D is fine when available.
	return Geometry2D.is_point_in_polygon(point, poly)

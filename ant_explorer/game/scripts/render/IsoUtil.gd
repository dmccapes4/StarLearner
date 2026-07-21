class_name IsoUtil
extends RefCounted
## 2:1 dimetric helpers. Tile (cell) → world; world → nearest cell.

const TILE_W: float = 64.0
const TILE_H: float = 32.0

static func tile_to_world(cell: Vector2i) -> Vector2:
	return Vector2(
		(cell.x - cell.y) * (TILE_W * 0.5),
		(cell.x + cell.y) * (TILE_H * 0.5)
	)

static func world_to_tile(world: Vector2) -> Vector2i:
	var x := world.x / (TILE_W * 0.5)
	var y := world.y / (TILE_H * 0.5)
	var cell_x := int(floor((x + y) * 0.5))
	var cell_y := int(floor((y - x) * 0.5))
	return Vector2i(cell_x, cell_y)

## Map floors live around z=-15. Offset keeps outdoor (negative y) ants above them.
const DEPTH_OFFSET: int = 2000

static func depth_from_y(world_y: float) -> int:
	## Coarse z for draw order. Outdoor north is y≈-720; without offset those
	## ants paint behind chambers and vanish.
	return int(world_y) + DEPTH_OFFSET

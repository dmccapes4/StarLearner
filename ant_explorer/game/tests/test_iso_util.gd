extends RefCounted
## Tests for IsoUtil tile/world conversion.

func run() -> TestAssert:
	var t := TestAssert.new("IsoUtil")
	var origin := IsoUtil.tile_to_world(Vector2i(0, 0))
	t.eq(origin, Vector2.ZERO, "tile (0,0) → world origin")
	var w := IsoUtil.tile_to_world(Vector2i(2, 0))
	t.approx(w.x, IsoUtil.TILE_W, 0.01, "tile (2,0) x = TILE_W")
	t.approx(w.y, IsoUtil.TILE_H, 0.01, "tile (2,0) y = TILE_H")
	var cell := IsoUtil.world_to_tile(IsoUtil.tile_to_world(Vector2i(3, 1)))
	t.eq(cell, Vector2i(3, 1), "world_to_tile round-trip (3,1)")
	t.eq(IsoUtil.depth_from_y(42.7), 42 + IsoUtil.DEPTH_OFFSET, "depth_from_y truncates + offset")
	t.gt(IsoUtil.depth_from_y(-720), -10.0, "outdoor ants above map floors")
	t.gt(float(IsoUtil.depth_from_y(180)), float(IsoUtil.depth_from_y(-720)), "south sorts in front of north")
	return t

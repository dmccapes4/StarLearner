extends RefCounted
## Tests for IsoUtil tile/world conversion.

func run() -> TestAssert:
	var t := TestAssert.new("IsoUtil")
	var origin := IsoUtil.tile_to_world(Vector2(0, 0))
	t.eq(origin, Vector2.ZERO, "tile (0,0) → world origin")
	var w := IsoUtil.tile_to_world(Vector2(2, 0))
	t.approx(w.x, IsoUtil.TILE_W, 0.01, "tile (2,0) x = TILE_W")
	t.approx(w.y, IsoUtil.TILE_H, 0.01, "tile (2,0) y = TILE_H")
	var cell := IsoUtil.world_to_tile(IsoUtil.tile_to_world(Vector2(3, 1)))
	t.eq(cell, Vector2i(3, 1), "world_to_tile round-trip (3,1)")
	var poly := IsoUtil.diamond_polygon(Vector2(0, 0), Vector2(1, 1))
	t.eq(poly.size(), 4, "diamond has 4 verts")
	t.ok(IsoUtil.point_in_polygon(Vector2.ZERO, poly), "center inside diamond")
	return t

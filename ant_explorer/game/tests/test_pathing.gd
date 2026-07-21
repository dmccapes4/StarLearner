extends RefCounted
## Tests for NavGraph + Pathing (Phase 0/1 single chamber).

func run() -> TestAssert:
	var t := TestAssert.new("Pathing")
	var graph := TestHarness.make_graph()
	var pathing := Pathing.new(graph)
	var ch := graph.default_chamber()
	t.ok(ch != null, "default chamber exists")
	t.ok(ch.contains_point(Vector2.ZERO), "origin inside walkable")
	t.ok(not ch.contains_point(Vector2(9999, 9999)), "far point outside")

	var clamped := ch.clamp_point(Vector2(9999, 0))
	t.ok(ch.contains_point(clamped) or ch.world_rect.has_point(clamped), "clamp pulls inward")

	var path := pathing.find_path(Vector2.ZERO, Vector2(100, 50))
	t.ge(path.size(), 2, "path has start + goal")
	t.eq(path[0], Vector2.ZERO, "path starts at from")
	t.approx(path[path.size() - 1].x, 100.0, 0.01, "path ends near goal x")

	var outside := pathing.find_path(Vector2.ZERO, Vector2(5000, 0))
	var goal := outside[outside.size() - 1]
	t.ok(ch.contains_point(goal), "path to outside clamps to chamber")
	return t

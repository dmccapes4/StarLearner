extends RefCounted
## Tapping a drawn corridor (void) must walk through — not no-op at room center.

var _tree: Node

func _init(tree: Node) -> void:
	_tree = tree

func run() -> TestAssert:
	var t := TestAssert.new("PathingTunnelTap")
	var builder := MapBuilder.new()
	var host := Node2D.new()
	_tree.add_child(host)
	var graph := builder.build(host)
	var pathing := Pathing.new(graph)

	var entrance := graph.get_chamber_by_name("entrance")
	var outpost := graph.get_chamber_by_name("outpost")
	t.ok(entrance != null and outpost != null, "entrance + outpost present")
	var edge := graph.tunnel_between(entrance.id, outpost.id)
	t.ok(edge != null and edge.waypoints.size() >= 2, "entrance↔outpost tunnel")

	# Mid-corridor void: previously clamped to entrance center → path_len 1.
	var mid := (edge.mouth_a() + edge.mouth_b()) * 0.5
	t.ok(graph.chamber_containing(mid) == null, "mid corridor is void")
	var hit := graph.nearest_tunnel(mid, 160.0)
	t.ok(hit != null and hit.id == edge.id, "nearest_tunnel finds east corridor")

	var path := pathing.find_path(entrance.center, mid)
	t.ge(path.size(), 4, "void tunnel tap yields corridor path (got %d)" % path.size())
	t.ok(outpost.contains_point(path[path.size() - 1]), "ends inside outpost")
	t.ok(_path_near(path, edge.mouth_a() if edge.a == entrance.id else edge.mouth_b(), 80.0),
		"path reaches near mouth")

	# East-of-room void (just past AABB) also traverses.
	var east_void := Vector2(entrance.world_rect.end.x + 80.0, entrance.center.y)
	t.ok(graph.chamber_containing(east_void) == null, "east void outside rooms")
	var path_e := pathing.find_path(entrance.center, east_void)
	t.ge(path_e.size(), 4, "east void tap yields corridor path")
	t.ok(outpost.contains_point(path_e[path_e.size() - 1]), "east void ends in outpost")

	# In-room tap still stays local (no forced transit).
	var local_tap := entrance.clamp_point(entrance.center + Vector2(120, 40))
	t.ok(entrance.contains_point(local_tap), "local tap inside entrance")
	var local := pathing.find_path(entrance.center, local_tap)
	t.ok(local.size() <= 3, "in-room tap stays short")
	t.ok(not outpost.contains_point(local[local.size() - 1]), "in-room tap does not jump rooms")

	# clamp_point on far void projects to boundary, not center.
	var far := mid
	var clamped := entrance.clamp_point(far)
	t.ok(clamped.distance_to(entrance.center) > 80.0, "clamp void → boundary, not center")
	t.ok(entrance.contains_point(clamped), "clamp stays walkable")

	# Pupae room: both exits (east→nursery, SE→queen) must be tappable from void.
	var pupae := graph.get_chamber_by_name("pupae")
	var nursery := graph.get_chamber_by_name("nursery")
	var queen := graph.get_chamber_by_name("queen")
	t.ok(pupae != null and nursery != null and queen != null, "pupae graph present")
	var edge_n := graph.tunnel_between(pupae.id, nursery.id)
	var edge_q := graph.tunnel_between(pupae.id, queen.id)
	t.ok(edge_n != null and edge_q != null, "pupae has both exits")
	var mid_n := (edge_n.mouth_a() + edge_n.mouth_b()) * 0.5
	var mid_q := (edge_q.mouth_a() + edge_q.mouth_b()) * 0.5
	var out_n := pathing.find_path(pupae.center, mid_n)
	var out_q := pathing.find_path(pupae.center, mid_q)
	t.ok(nursery.contains_point(out_n[out_n.size() - 1]), "pupae east corridor → nursery")
	t.ok(queen.contains_point(out_q[out_q.size() - 1]), "pupae SE corridor → queen")
	# Wide SE void (previously clamped back into pupae).
	var se_void := pupae.center + Vector2(500, 500)
	var out_se := pathing.find_path(pupae.center, se_void)
	t.ok(queen.contains_point(out_se[out_se.size() - 1]) or nursery.contains_point(out_se[out_se.size() - 1]),
		"pupae SE void leaves the room")

	# Star in pupae sits away from mouth suck zone.
	var star_pos: Vector2 = builder.star_placements["pupae"]["pos"]
	t.ok(pupae.contains_point(star_pos), "pupae star inside room")
	var mouth_n: Vector2 = edge_n.mouth_a() if edge_n.a == pupae.id else edge_n.mouth_b()
	t.ok(star_pos.distance_to(mouth_n) > float(TunnelTransit.TRIGGER_RADIUS) + 40.0,
		"pupae star clear of east mouth pad")

	host.queue_free()
	return t

func _path_near(path: PackedVector2Array, p: Vector2, rad: float) -> bool:
	var r2 := rad * rad
	for q in path:
		if q.distance_squared_to(p) <= r2:
			return true
	return false

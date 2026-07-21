extends RefCounted
## Multi-chamber BFS pathing — must follow tunnels, never wall-clip.

var _tree: Node

func _init(tree: Node) -> void:
	_tree = tree

func run() -> TestAssert:
	var t := TestAssert.new("MapPathing")
	var builder := MapBuilder.new()
	var host := Node2D.new()
	_tree.add_child(host)
	var graph := builder.build(host)
	t.eq(graph.chambers.size(), 12, "12 chambers from map.json")
	t.ok(graph.get_chamber_by_name("surface").is_outdoor, "surface is outdoor")
	t.eq(builder.star_placements.size(), 12, "one star placement per zone")

	var pathing := Pathing.new(graph)
	var surface := graph.get_chamber_by_name("surface")
	var queen := graph.get_chamber_by_name("queen")
	var entrance := graph.get_chamber_by_name("entrance")
	var path := pathing.find_path(surface.center + Vector2(-40, 20), queen.center + Vector2(30, -20))

	t.ge(path.size(), 5, "cross-nest path has tunnel waypoints")
	t.ok(surface.contains_point(path[0]) or path[0].distance_to(surface.clamp_point(path[0])) < 1.0,
		"path starts in/at surface")
	t.ok(queen.contains_point(path[path.size() - 1]) or path[path.size() - 1].distance_to(queen.center) < 80.0,
		"path ends in/at queen")

	# Must pass near entrance (hub on surface→queen BFS).
	t.ok(_path_near(path, entrance.center, 280.0), "route passes through entrance hub")

	# Tunnel mouths exist (not center-to-center only).
	var edge := graph.tunnel_between(surface.id, entrance.id)
	t.ok(edge != null and edge.waypoints.size() >= 3, "surface↔entrance has corridor waypoints")
	t.ok(surface.contains_point(edge.mouth_a()) or edge.mouth_a().distance_to(surface.center) < surface.world_rect.size.length() * 0.6,
		"tunnel mouth on surface side")

	# Exploration-scale rooms: corridor segments may be long, but not wall-clip leaps.
	var max_seg := 0.0
	for i in range(path.size() - 1):
		max_seg = maxf(max_seg, path[i].distance_to(path[i + 1]))
	t.lt(max_seg, 900.0, "no wall-clip mega-segments (max=%.0f)" % max_seg)

	# Chambers large enough to explore (nursery half ≥ 400×300).
	var nursery := graph.get_chamber_by_name("nursery")
	t.ok(nursery != null and nursery.world_rect.size.x >= 800.0, "nursery wide enough to explore")
	t.ok(nursery != null and nursery.world_rect.size.y >= 600.0, "nursery tall enough to explore")

	# Unreachable-style: same room still works
	var local := pathing.find_path(nursery_pt(graph), nursery_pt(graph) + Vector2(40, 10))
	t.ge(local.size(), 2, "intra-room path")

	# Star uniqueness
	var zones := {}
	for z in builder.star_placements:
		var sid: String = str(builder.star_placements[z]["star_id"])
		t.ok(not zones.has(sid), "star %s unique" % sid)
		zones[sid] = z

	var rooms := graph.bfs_chamber_path(surface.id, queen.id)
	t.ge(rooms.size(), 3, "BFS visits intermediate rooms")
	t.eq(rooms[0], surface.id, "BFS starts surface")
	t.eq(rooms[rooms.size() - 1], queen.id, "BFS ends queen")

	host.queue_free()
	return t

func nursery_pt(graph: NavGraph) -> Vector2:
	var n := graph.get_chamber_by_name("nursery")
	return n.center if n else Vector2.ZERO

func _path_near(path: PackedVector2Array, p: Vector2, rad: float) -> bool:
	var r2 := rad * rad
	for q in path:
		if q.distance_squared_to(p) <= r2:
			return true
	return false

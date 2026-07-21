extends RefCounted
## Paths should not detour through the room center when a straight chord is clear.

var _tree: Node

func _init(tree: Node) -> void:
	_tree = tree

func run() -> TestAssert:
	var t := TestAssert.new("PathingForward")
	var builder := MapBuilder.new()
	var host := Node2D.new()
	_tree.add_child(host)
	var graph := builder.build(host)
	var pathing := Pathing.new(graph)
	var nursery := graph.get_chamber_by_name("nursery")
	t.ok(nursery != null, "nursery present")

	# Clear mid-room chord: must be start→goal only (no center waypoint).
	var a := nursery.clamp_point(nursery.center + Vector2(-80, -40))
	var b := nursery.clamp_point(nursery.center + Vector2(90, 50))
	t.ok(nursery.contains_point(a) and nursery.contains_point(b), "samples inside nursery")
	t.ok(pathing._chord_inside(nursery, a, b), "chord inside for test samples")
	var local := pathing.find_path(a, b)
	t.eq(local.size(), 2, "clear same-room chord is direct (got %d pts)" % local.size())
	if local.size() >= 2:
		t.ok(local[0].distance_to(a) < 2.0, "starts at A")
		t.ok(local[local.size() - 1].distance_to(b) < 2.0, "ends at B")
		for i in range(1, local.size() - 1):
			t.ok(local[i].distance_to(nursery.center) > 30.0,
				"no via-center on clear chord")

	# Approach a tunnel mouth from nearby: path should not retreat to room center.
	var garden_a := graph.get_chamber_by_name("garden_a")
	var edge := graph.tunnel_between(nursery.id, garden_a.id)
	t.ok(edge != null, "nursery↔garden_a tunnel")
	if edge != null:
		var mouth: Vector2 = edge.mouth_a() if edge.a == nursery.id else edge.mouth_b()
		var near_mouth := nursery.clamp_point(mouth + (nursery.center - mouth).normalized() * 100.0)
		var to_mouth := pathing.find_path(near_mouth, mouth)
		var via_center := false
		for p in to_mouth:
			if p.distance_to(nursery.center) < 40.0 and near_mouth.distance_to(nursery.center) > 120.0:
				via_center = true
		t.ok(not via_center, "near-mouth walk does not retreat to room center")

	# Cross-room path still uses tunnels (regression).
	var surface := graph.get_chamber_by_name("surface")
	var entrance := graph.get_chamber_by_name("entrance")
	var cross := pathing.find_path(surface.center, nursery.center)
	t.ge(cross.size(), 4, "cross-room still has corridor waypoints")
	t.ok(_path_near(cross, entrance.center, 320.0), "still routes via entrance hub")

	host.queue_free()
	return t

func _path_near(path: PackedVector2Array, p: Vector2, rad: float) -> bool:
	var r2 := rad * rad
	for q in path:
		if q.distance_squared_to(p) <= r2:
			return true
	return false

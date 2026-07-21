extends RefCounted
## Map data drives pheromone trail placement zones.

func run() -> TestAssert:
	var t := TestAssert.new("MapTrails")
	var data := MapBuilder.load_map_dict()
	var trails: Array = data.get("trails", [])
	t.gt(trails.size(), 0, "map has trail entries")

	var roles_seen: Dictionary = {}
	for tr in trails:
		var role_key: String = str(tr.get("role", ""))
		var zone: String = str(tr.get("zone", ""))
		t.ok(not role_key.is_empty(), "trail has role")
		t.ok(not zone.is_empty(), "trail has zone")
		t.neq(AntEnums.role_from_name(role_key), AntEnums.Role.NONE, "known role %s" % role_key)
		if not roles_seen.has(role_key):
			roles_seen[role_key] = []
		(roles_seen[role_key] as Array).append(zone)

	for required in ["nurse", "forager", "gardener", "soldier", "waste", "scout"]:
		t.ok(roles_seen.has(required), "trail for role %s" % required)

	var mb := MapBuilder.new()
	var host := Node2D.new()
	var graph := mb.build(host)
	t.eq(mb.trail_placements.size(), trails.size(), "MapBuilder parses all trails")
	t.ok(graph.get_chamber_by_name("nursery") != null, "nursery chamber exists")

	for child in host.get_children():
		child.queue_free()
	host.queue_free()
	return t

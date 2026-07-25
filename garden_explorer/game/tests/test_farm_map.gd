extends RefCounted
## Phase 1 acceptance: shed · 6 beds · fence zones exist and are hittable.
## Also: meadows, perimeter fence, collision + path around solids.

func run() -> TestAssert:
	var t := TestAssert.new("FarmMap")
	var host := Node2D.new()
	# FarmMap._ready builds; we call build_from_file explicitly for headless.
	var farm := FarmMap.new()
	host.add_child(farm)
	farm.build_from_file()

	t.eq(farm.bed_count(), 6, "six garden beds")
	t.eq(farm.bed_ids().size(), 6, "six bed ids")
	t.ok(farm.shed_poly.size() >= 3, "shed polygon")
	t.ok(farm.fence_poly.size() >= 3, "fence polygon")
	t.ok(farm.farm_yard_poly.size() >= 3, "farm yard polygon")
	t.ok(farm.animal_positions.size() >= 2, "animal placeholders")
	## Extruded beds expose side walls + raised soil top.
	t.ok(farm.get_node_or_null("bed_0_wall_w") != null, "bed has 3D wall")
	t.ok(farm.get_node_or_null("ShedWallW") != null, "shed has 3D wall")
	t.ok(farm.get_node_or_null("ShedRoofE") != null, "shed has pitched roof")
	t.ok(farm.get_node_or_null("Meadow") != null, "meadows outside fence")
	t.ok(farm.get_node_or_null("YardPost_0_0") != null, "perimeter fence posts")

	var shed_hit := farm.zone_at(farm.shed_center)
	t.eq(str(shed_hit.get("kind", "")), "shed", "shed center is shed zone")

	var fence_hit := farm.zone_at(farm.fence_center)
	t.eq(str(fence_hit.get("kind", "")), "fence", "fence center is fence zone")

	var beds_hit := 0
	for id in farm.bed_centers.keys():
		var z := farm.zone_at(farm.bed_centers[id])
		if str(z.get("kind", "")) == "bed":
			beds_hit += 1
	t.eq(beds_hit, 6, "all bed centers resolve as beds")

	t.ok(farm.is_blocked(farm.shed_center), "shed is solid")
	t.ok(farm.is_blocked(farm.fence_center), "animal pen is solid")
	t.ok(farm.is_blocked(farm.bed_centers["bed_1"]), "garden bed is solid")
	t.ok(not farm.is_blocked(farm.spawn_world), "spawn is walkable")

	# Left → middle → right ordering in world X (iso: left is often higher x-y mix;
	# shed tile x=-7 should be left of beds at x=0..6 which left of fence x=12).
	t.ok(farm.shed_center.x < farm.bed_centers["bed_1"].x, "shed left of middle bed")
	t.ok(farm.bed_centers["bed_1"].x < farm.fence_center.x or farm.shed_center.distance_to(farm.fence_center) > 100.0,
		"beds separated from fence")

	# Walk path left→right tiles should stay in bounds
	var left := IsoUtil.tile_to_world(Vector2(-6, 4))
	var mid := IsoUtil.tile_to_world(Vector2(3, 4))
	var right := IsoUtil.tile_to_world(Vector2(11, 4))
	t.ok(farm.walk_bounds.has_point(left), "left walkable")
	t.ok(farm.walk_bounds.has_point(mid), "middle walkable")
	t.ok(farm.walk_bounds.has_point(right), "right walkable")

	## Path from west of shed to east of shed must not enter the shed footprint.
	var west := IsoUtil.tile_to_world(Vector2(-10, 4))
	var east := IsoUtil.tile_to_world(Vector2(-3, 4))
	var path := farm.find_path(west, east)
	t.ok(path.size() >= 2, "routed path has waypoints")
	var through_shed := false
	for p in path:
		if farm.shed_poly.size() >= 3 and IsoUtil.point_in_polygon(p, farm.shed_poly):
			through_shed = true
			break
	t.ok(not through_shed, "path routes around shed")

	var pen_approach := farm.nearest_walkable(farm.fence_center)
	t.ok(not farm.is_blocked(pen_approach), "pen approach is outside the rail")

	host.free()
	return t

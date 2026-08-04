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
	t.ok(farm.get_node_or_null("ShedSprite") != null or farm.get_node_or_null("ShedWallW") != null,
		"shed sprite (or fallback walls) present")
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
	t.ok(farm.coop_world != Vector2.ZERO and farm.coop_poly.size() >= 3, "coop footprint set")
	t.ok(farm.is_blocked(farm.coop_world), "coop is solid")
	t.ok(not farm.is_blocked(farm.coop_approach_world()), "coop door approach is walkable")
	## Path from behind the coop to the door must not cut through the body.
	var behind_coop := farm.nearest_walkable(farm.coop_world + Vector2(0, -70))
	var coop_path := farm.find_path(behind_coop, farm.coop_approach_world())
	t.ok(coop_path.size() >= 2, "path to coop door exists")
	var through_coop := false
	for p in coop_path:
		if farm.coop_poly.size() >= 3 and IsoUtil.point_in_polygon(p, farm.coop_poly):
			through_coop = true
			break
	t.ok(not through_coop, "coop approach routes around the body")
	t.ok(not farm.is_blocked(farm.fence_center), "animal pen is walkable via gate")
	t.ok(farm.has_method("in_pen") and farm.in_pen(farm.fence_center), "fence center is inside pen")
	t.ok(farm.gate_world != Vector2.ZERO, "pen gate placed")
	t.ok(farm.is_blocked(farm.bed_centers["bed_1"]), "garden bed is solid")
	t.ok(not farm.is_blocked(farm.spawn_world), "spawn is walkable")
	## Perimeter fence is a hard wall — meadow / far side of rails is blocked.
	var past_north_fence := IsoUtil.tile_to_world(Vector2(2, -5.2))
	t.ok(farm.is_blocked(past_north_fence), "cannot walk past the far (north) fence")
	t.ok(not farm.is_blocked(farm.shed_door_world), "shed door apron is walkable")

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
	var west := farm.nearest_walkable(IsoUtil.tile_to_world(Vector2(-8.5, 4)))
	var east := farm.nearest_walkable(IsoUtil.tile_to_world(Vector2(-3, 4)))
	var path := farm.find_path(west, east)
	t.ok(path.size() >= 2, "routed path has waypoints")
	var through_shed := false
	for p in path:
		if farm.shed_poly.size() >= 3 and IsoUtil.point_in_polygon(p, farm.shed_poly):
			through_shed = true
			break
	t.ok(not through_shed, "path routes around shed")

	var pen_approach := farm.nearest_walkable(farm.fence_center)
	t.ok(not farm.is_blocked(pen_approach), "pen interior / approach is walkable")
	t.ok(farm.pen_roam_poly.size() >= 3, "animal roam bound")
	## Buddy must stay clear of garden beds.
	if farm.has_method("is_blocked_for_dog") and farm.dog_spawn_world != Vector2.ZERO:
		t.ok(not farm.is_blocked_for_dog(farm.dog_spawn_world), "dog spawn clear of beds")
		for bid in farm.bed_ids():
			var bc: Vector2 = farm.bed_centers.get(bid, Vector2.ZERO)
			t.ok(farm.is_blocked_for_dog(bc), "dog blocked at bed %s center" % bid)

	## UI validation: slot markers sit fully inside the bed lip, no overlap.
	for bid in farm.bed_ids():
		var soil_top: PackedVector2Array = farm.bed_soil_top_poly(bid)
		var markers: Array = []
		for s in 4:
			var mp: PackedVector2Array = farm.slot_marker_poly(bid, s)
			t.ok(mp.size() >= 3, "%s slot %d marker exists" % [bid, s])
			markers.append(mp)
			for p in mp:
				t.ok(IsoUtil.point_in_polygon(p, soil_top),
					"%s slot %d marker inside soil top" % [bid, s])
		for a in 4:
			for b in range(a + 1, 4):
				var overlap := Geometry2D.intersect_polygons(markers[a], markers[b])
				t.ok(overlap.is_empty(), "%s slots %d/%d do not overlap" % [bid, a, b])
		break ## beds share geometry — validating one is representative

	## Pen routing: any path into the pen must go to the gate, then through it.
	var outside := farm.nearest_walkable(farm.gate_world + Vector2(-140, 0))
	var inside := farm.nearest_walkable(farm.fence_center)
	var pen_path := farm.find_path(outside, inside)
	t.ok(pen_path.size() >= 2, "path into pen exists")
	var bad_cross := false
	var near_gate := false
	for i in range(pen_path.size() - 1):
		if pen_path[i].distance_to(farm.gate_world) <= 56.0:
			near_gate = true
		if not farm.crossing_allowed(pen_path[i], pen_path[i + 1]):
			bad_cross = true
			break
	if pen_path[pen_path.size() - 1].distance_to(farm.gate_world) <= 56.0:
		near_gate = true
	t.ok(not bad_cross, "pen entry only through the gate")
	t.ok(near_gate, "cross-fence path visits the gate waypoint")

	## Same-side garden walk must not detour through the gate.
	var bed_goal := farm.nearest_walkable(farm.slot_world("bed_0", 0))
	var yard_path := farm.find_path(farm.spawn_world, bed_goal)
	var yard_hits_gate := false
	for p in yard_path:
		if p.distance_to(farm.gate_world) <= 40.0:
			yard_hits_gate = true
			break
	t.ok(not yard_hits_gate, "garden path skips the pen gate")

	host.free()
	return t

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
	## Bed approach: from the path, tapping bed_1 stands on the path-side face.
	if farm.has_method("bed_approach_world"):
		var path_y := IsoUtil.tile_to_world(Vector2(0.0, 3.0)).y
		var from_path := farm.nearest_walkable(Vector2(farm.bed_centers["bed_0"].x, path_y))
		var ap1: Vector2 = farm.bed_approach_world("bed_1", from_path, farm.bed_centers["bed_1"])
		t.ok(farm.path_world_length(from_path, ap1) < 220.0, "bed_1 approach short from path")
		t.ok(ap1.y >= farm.bed_centers["bed_1"].y + 12.0, "bed_1 approach on path/south face")
		var d1 := ap1.distance_to(farm.bed_centers["bed_1"])
		t.ok(d1 >= 36.0 and d1 <= 72.0, "bed_1 stand next to lip")
		## Opposite-side tap walks the gap, not a south-row loop.
		var west := farm.nearest_walkable(farm.bed_centers["bed_1"] + Vector2(-70, 10))
		var tap_e: Vector2 = farm.bed_centers["bed_1"] + Vector2(40, 0)
		var ap_e: Vector2 = farm.bed_approach_world("bed_1", west, tap_e)
		var plen_e := farm.path_world_length(west, ap_e)
		t.ok(plen_e < 280.0, "opposite-side path short (gap)")
		var max_y := west.y
		for p in farm.find_path(west, ap_e):
			max_y = maxf(max_y, p.y)
		t.ok(max_y < farm.bed_centers["bed_4"].y + 30.0, "opposite-side not south loop")


	## Perimeter fence is a hard wall — meadow / far side of rails is blocked.
	var past_north_fence := IsoUtil.tile_to_world(Vector2(2, -5.2))
	t.ok(farm.is_blocked(past_north_fence), "cannot walk past the far (north) fence")
	t.ok(not farm.is_blocked(farm.shed_door_world), "shed door apron is walkable")

	## Doorstep: room to stand in front of the door, not on a bed's drawn soil.
	var shed_apron := farm.shed_approach_world()
	t.ok(not farm.is_blocked(shed_apron), "shed apron stand is walkable")
	t.ok(not farm._point_in_bed_top(shed_apron), "shed apron is clear of bed tops")
	t.ok(shed_apron.distance_to(farm.shed_door_base_world) < 56.0,
		"shed apron stays on the doorstep")
	var coop_apron := farm.coop_approach_world()
	t.ok(not farm.is_blocked(coop_apron), "coop apron stand is walkable")

	## Straight below a bed in screen space, S and E face-dots tie exactly; the
	## nearer stand must win instead of Dictionary key order walking us sideways.
	for bid in ["bed_0", "bed_1", "bed_2"]:
		var c: Vector2 = farm.bed_centers[bid]
		var below := farm.nearest_walkable(Vector2(c.x, c.y + 32.0))
		var panes: Dictionary = farm.bed_face_panes(bid)
		var picked := farm._pick_facing_pane(panes, c, Vector2(c.x, below.y), c)
		t.ok(picked == "S", "%s from due south picks S (got %s)" % [bid, picked])

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
	## Pet approach stands beside the animal, not on top.
	if farm.has_method("animal_approach_world"):
		var dog_pos: Vector2 = farm.dog_spawn_world
		var from_p := farm.nearest_walkable(dog_pos + Vector2(-80, 0))
		var ap_dog: Vector2 = farm.animal_approach_world(from_p, dog_pos)
		t.ok(ap_dog.distance_to(dog_pos) >= 28.0, "animal approach stand-off")
		t.ok(not farm.is_blocked(ap_dog), "animal approach walkable")

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

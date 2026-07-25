extends RefCounted
## Player moves toward a tap target, routing around solids.

func run() -> TestAssert:
	var t := TestAssert.new("PlayerWalk")
	var tree_host := Node.new()
	# Autoloads exist when run via project; simulate path request on a player.
	var world := Node2D.new()
	tree_host.add_child(world)
	var farm := FarmMap.new()
	farm.name = "FarmMap"
	world.add_child(farm)
	farm.build_from_file()
	var player := Player.new()
	player.name = "Player"
	world.add_child(player)
	player.place_at(farm.spawn_world)
	var start := player.global_position
	var dest := farm.nearest_walkable(farm.fence_center)
	Events.player_path_requested.emit(farm.fence_center)
	t.ok(player.moving, "starts moving after path request")
	# Step ~7 seconds of movement (walk speed is intentionally leisurely).
	for i in 420:
		player._process(1.0 / 60.0)
		## Never stride into the animal pen.
		if farm.is_blocked(player.global_position) and player.global_position.distance_to(dest) >= 8.0:
			t.ok(false, "stays outside solids while walking")
			break
		if not player.moving:
			break
	t.ok(player.global_position.distance_to(start) > 20.0, "moved away from spawn")
	t.ok(player.global_position.distance_to(dest) < 48.0 or not player.moving,
		"approached or arrived at pen rim")
	t.ok(not farm.is_blocked(player.global_position), "final position is walkable")
	tree_host.free()
	return t

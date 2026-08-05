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
		## Never stride into shed / beds (pen is walkable).
		if farm.is_blocked(player.global_position) and player.global_position.distance_to(dest) >= 8.0:
			t.ok(false, "stays outside solids while walking")
			break
		if not player.moving:
			break
	t.ok(player.global_position.distance_to(start) > 20.0, "moved away from spawn")
	t.ok(player.global_position.distance_to(dest) < 64.0 or not player.moving,
		"approached or arrived at pen")
	t.ok(not farm.is_blocked(player.global_position), "final position is walkable")

	## Narration must pause the walk, never cancel it: cancelling left the avatar
	## parked short of the bed with the tap's action still pending.
	var NarratorScript := preload("res://scripts/audio/Narrator.gd")
	player.place_at(farm.spawn_world)
	var goal := farm.nearest_walkable(farm.fence_center)
	Events.player_path_requested.emit(goal)
	for i in 20:
		player._process(1.0 / 60.0)
	var held := player.global_position
	NarratorScript._lock_movement(0.05)
	for i in 10:
		player._process(1.0 / 60.0)
	t.ok(player.moving, "keeps the route while narration plays")
	t.ok(player.global_position.distance_to(held) < 1.0, "stands still while narration plays")
	OS.delay_msec(70)
	for i in 20:
		player._process(1.0 / 60.0)
	t.ok(player.global_position.distance_to(held) > 4.0, "resumes walking after narration")

	## A tap taken during narration is held, not dropped.
	player.stop()
	player.place_at(farm.spawn_world)
	NarratorScript._lock_movement(0.05)
	Events.player_path_requested.emit(goal)
	player._process(1.0 / 60.0)
	t.ok(not player.moving, "tap during narration does not walk yet")
	OS.delay_msec(70)
	player._process(1.0 / 60.0)
	t.ok(player.moving, "held tap walks once narration ends")

	tree_host.free()
	return t

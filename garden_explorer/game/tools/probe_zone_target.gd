extends SceneTree
## Verify same-zone animal targeting + explicit gate routing.

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var save := root.get_node_or_null("/root/Save")
	if save and save.has_method("clear_all"):
		save.clear_all()
	if save and save.has_method("set_intro_completed"):
		save.set_intro_completed(true)
	var main: Node = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for _i in 40:
		await process_frame
	var world: Node = main.get_node("World")
	var farm: FarmMap = world.get_node("FarmMap")
	var player: Node2D = world.get("player")
	var animal_db = world.get("animal_db")

	var fails := 0
	## --- Gate routing: garden → pen must visit the gate ---
	var garden_pt: Vector2 = farm.spawn_world
	var pen_pt: Vector2 = farm.fence_center
	var path: PackedVector2Array = farm.find_path(garden_pt, pen_pt)
	var near_gate := false
	for p in path:
		if p.distance_to(farm.gate_world) <= 56.0:
			near_gate = true
			break
	print("gate_path pts=%d near_gate=%s gate=%s" % [path.size(), near_gate, farm.gate_world])
	if not near_gate:
		print("FAIL gate_path")
		fails += 1
	else:
		print("OK gate_path")

	## Same-side path must NOT require the gate.
	var bed: Vector2 = farm.slot_world("bed_0", 0) if farm.bed_count() > 0 else garden_pt
	var path2: PackedVector2Array = farm.find_path(garden_pt, bed)
	var hit_gate := false
	for p in path2:
		if p.distance_to(farm.gate_world) <= 40.0:
			hit_gate = true
			break
	print("garden_path pts=%d hit_gate=%s" % [path2.size(), hit_gate])
	if hit_gate:
		print("FAIL garden_path_should_skip_gate")
		fails += 1
	else:
		print("OK garden_path_skips_gate")

	## --- Zone helpers ---
	player.global_position = farm.nearest_walkable(garden_pt)
	await process_frame
	var can_dog: bool = bool(world.call("_can_track_animal", "dog"))
	var can_cow: bool = bool(world.call("_can_track_animal", "cow"))
	print("in_garden can_dog=%s can_cow=%s (expect true/false)" % [can_dog, can_cow])
	if not can_dog or can_cow:
		print("FAIL garden_zone_rules")
		fails += 1
	else:
		print("OK garden_zone_rules")

	player.global_position = farm.nearest_walkable(pen_pt)
	await process_frame
	can_dog = bool(world.call("_can_track_animal", "dog"))
	can_cow = bool(world.call("_can_track_animal", "cow"))
	print("in_pen can_dog=%s can_cow=%s (expect false/true)" % [can_dog, can_cow])
	if can_dog or not can_cow:
		print("FAIL pen_zone_rules")
		fails += 1
	else:
		print("OK pen_zone_rules")

	## Tap cow from garden: must NOT start animal follow.
	player.global_position = farm.nearest_walkable(garden_pt)
	await process_frame
	var cow: Node2D = world.call("_animal_node", "cow")
	var tap: Vector2 = cow.global_position if cow else pen_pt
	var EventsNode := root.get_node("/root/Events")
	EventsNode.world_tapped.emit(tap)
	await process_frame
	await process_frame
	var pending: Dictionary = world.get("_pending")
	var kind := str(pending.get("kind", ""))
	print("tap_cow_from_garden pending_kind=%s (expect '' or nav, not animal)" % kind)
	if kind == "animal":
		print("FAIL no_cross_track")
		fails += 1
	else:
		print("OK no_cross_track")

	## Tap dog from garden: SHOULD start animal follow (or deferred after narrate).
	var dog: Node2D = world.call("_animal_node", "dog")
	if dog:
		EventsNode.world_tapped.emit(dog.global_position)
		## Wait a few frames for queue.
		for _j in 10:
			await process_frame
		pending = world.get("_pending")
		kind = str(pending.get("kind", ""))
		print("tap_dog_from_garden pending_kind=%s id=%s" % [kind, pending.get("id", "")])
		if kind != "animal" or str(pending.get("id", "")) != "dog":
			print("FAIL dog_track")
			fails += 1
		else:
			print("OK dog_track")

	## Tap cow from pen: SHOULD start animal follow.
	player.global_position = farm.nearest_walkable(pen_pt)
	## Clear any prior follow / narration lock.
	world.set("_pending", {})
	world.set("_follow_delay", 0.0)
	var NarratorScript := preload("res://scripts/audio/Narrator.gd")
	NarratorScript.stop()
	await process_frame
	cow = world.call("_animal_node", "cow")
	if cow:
		EventsNode.world_tapped.emit(cow.global_position)
		for _j in 10:
			await process_frame
		pending = world.get("_pending")
		kind = str(pending.get("kind", ""))
		print("tap_cow_from_pen pending_kind=%s id=%s" % [kind, pending.get("id", "")])
		if kind != "animal" or str(pending.get("id", "")) != "cow":
			print("FAIL cow_track_in_pen")
			fails += 1
		else:
			print("OK cow_track_in_pen")

	print("RESULT: %s (%d fails) animal_db_pen_cow=%s" % [
		"PASS" if fails == 0 else "FAIL", fails,
		animal_db.in_pen("cow") if animal_db else "?"
	])
	quit(0 if fails == 0 else 1)

extends SceneTree
## Verify same-zone animal interact (no chase) + explicit gate routing.

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
	var EventsNode := root.get_node("/root/Events")
	var fails := 0

	var path: PackedVector2Array = farm.find_path(farm.spawn_world, farm.fence_center)
	var near_gate := false
	for p in path:
		if p.distance_to(farm.gate_world) <= 56.0:
			near_gate = true
			break
	print("gate_path near_gate=%s" % near_gate)
	if not near_gate:
		fails += 1
		print("FAIL gate_path")
	else:
		print("OK gate_path")

	player.global_position = farm.nearest_walkable(farm.spawn_world)
	await process_frame
	if not bool(world.call("_can_interact_animal", "dog")) \
			or bool(world.call("_can_interact_animal", "cow")):
		fails += 1
		print("FAIL garden_zone_rules")
	else:
		print("OK garden_zone_rules")

	player.global_position = farm.nearest_walkable(farm.fence_center)
	await process_frame
	if bool(world.call("_can_interact_animal", "dog")) \
			or not bool(world.call("_can_interact_animal", "cow")):
		fails += 1
		print("FAIL pen_zone_rules")
	else:
		print("OK pen_zone_rules")

	## Tap cow from garden: must not queue animal interact.
	player.global_position = farm.nearest_walkable(farm.spawn_world)
	await process_frame
	var cow: Node2D = world.call("_animal_node", "cow")
	EventsNode.world_tapped.emit(cow.global_position if cow else farm.fence_center)
	await process_frame
	await process_frame
	var pending: Dictionary = world.get("_pending")
	if str(pending.get("kind", "")) == "animal":
		fails += 1
		print("FAIL no_cross_interact")
	else:
		print("OK no_cross_interact")

	## Tap dog from garden: one-shot walk to frozen approach (no chase).
	var dog: Node2D = world.call("_animal_node", "dog")
	if dog:
		var dog_at_tap: Vector2 = dog.global_position
		EventsNode.world_tapped.emit(dog_at_tap)
		for _j in 10:
			await process_frame
		pending = world.get("_pending")
		var approach: Vector2 = pending.get("approach", Vector2.ZERO)
		print("tap_dog pending=%s approach_dist=%.1f" % [
			pending.get("kind", ""), approach.distance_to(dog_at_tap)])
		if str(pending.get("kind", "")) != "animal" or str(pending.get("id", "")) != "dog":
			fails += 1
			print("FAIL dog_interact")
		elif approach.distance_to(dog_at_tap) > 8.0:
			fails += 1
			print("FAIL dog_approach_frozen")
		else:
			print("OK dog_oneshot")

	## Tap cow from pen: one-shot animal pending.
	player.global_position = farm.nearest_walkable(farm.fence_center)
	world.set("_pending", {})
	var NarratorScript := preload("res://scripts/audio/Narrator.gd")
	NarratorScript.stop()
	await process_frame
	cow = world.call("_animal_node", "cow")
	if cow:
		EventsNode.world_tapped.emit(cow.global_position)
		for _j in 10:
			await process_frame
		pending = world.get("_pending")
		if str(pending.get("kind", "")) != "animal" or str(pending.get("id", "")) != "cow":
			fails += 1
			print("FAIL cow_oneshot")
		else:
			print("OK cow_oneshot")

	print("RESULT: %s (%d fails)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(0 if fails == 0 else 1)

extends RefCounted
## Phase 2 acceptance: plant 4 in one bed, uproot one.

func run() -> TestAssert:
	var t := TestAssert.new("GardenPlant")
	var host := Node2D.new()
	var farm := FarmMap.new()
	host.add_child(farm)
	var art := FarmSprites.new()
	art.bootstrap()
	farm.set_sprites(art)
	farm.build_from_file()
	t.ok(farm.slot_positions.has("bed_0"), "bed_0 slots")
	t.eq((farm.slot_positions["bed_0"] as Array).size(), 4, "4 slot positions")

	var garden := GardenState.new()
	garden.setup(farm.bed_ids(), 4)
	t.eq(garden.first_empty_slot("bed_0"), 0, "first empty is 0")

	for i in 4:
		t.ok(garden.plant("bed_0", i, "tomato"), "plant slot %d" % i)
	t.eq(garden.occupied_count("bed_0"), 4, "bed full")
	t.eq(garden.first_empty_slot("bed_0"), -1, "no empty")
	t.ok(not garden.plant("bed_0", 0, "carrot"), "cannot overwrite")

	var removed := garden.uproot("bed_0", 2)
	t.eq(removed, "tomato", "uprooted tomato")
	t.eq(garden.occupied_count("bed_0"), 3, "3 remain")
	t.ok(garden.is_empty("bed_0", 2), "slot 2 empty after uproot")
	t.ok(garden.plant("bed_0", 2, "radish"), "replant radish")

	var layer := PlantLayer.new()
	host.add_child(layer)
	layer.setup(farm, garden, art)
	t.ok(layer.get_child_count() >= 4, "plant sprites present")

	# Seasonal shed list
	var db := SeedDB.new()
	db.load_all()
	db.set_season("spring")
	t.ok(db.available_seed_ids().size() >= 5, "spring shed stocked")

	host.free()
	return t

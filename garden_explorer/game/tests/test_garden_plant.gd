extends RefCounted
## Per-bed planting: one plant fills all four plots; uproot clears the bed.

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
	t.eq(garden.first_empty_slot("bed_0"), 0, "empty bed → slot 0")

	t.ok(garden.plant_bed("bed_0", "tomato"), "plant tomato bed")
	t.eq(garden.occupied_count("bed_0"), 4, "all four plots filled")
	t.eq(garden.first_empty_slot("bed_0"), -1, "no empty")
	t.ok(not garden.plant_bed("bed_0", "carrot"), "cannot overwrite bed")
	t.eq(garden.bed_plant_id("bed_0"), "tomato", "bed crop id")
	t.eq(garden.bed_stage("bed_0"), GardenState.STAGE_SEED, "starts as seed")

	var removed := garden.uproot_bed("bed_0")
	t.eq(removed, "tomato", "uprooted tomato")
	t.eq(garden.occupied_count("bed_0"), 0, "bed empty")
	t.ok(garden.plant_bed("bed_0", "radish"), "replant radish")
	t.eq(garden.occupied_count("bed_0"), 4, "full again")

	var layer := PlantLayer.new()
	host.add_child(layer)
	layer.setup(farm, garden, art)
	t.ok(layer.get_child_count() >= 1, "plant sprites present")

	var db := SeedDB.new()
	db.load_all()
	db.set_season("spring")
	t.ok(db.available_seed_ids().size() >= 5, "spring shed stocked")

	host.free()
	return t

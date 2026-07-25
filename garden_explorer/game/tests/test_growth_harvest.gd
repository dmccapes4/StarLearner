extends RefCounted
## Water + time growth, thirst gating, harvest.

func run() -> TestAssert:
	var t := TestAssert.new("GrowthHarvest")
	var db := SeedDB.new()
	db.load_all()
	var garden := GardenState.new()
	garden.setup(PackedStringArray(["bed_0"]), 4)
	t.ok(garden.plant("bed_0", 0, "radish"), "plant radish")
	var slot := garden.get_slot("bed_0", 0)
	t.eq(str(slot.get("stage", "")), GardenState.STAGE_SEED, "starts as seed")
	t.ok(bool(slot.get("thirsty", false)), "thirsty immediately after plant")

	## Watering while not thirsty should fail.
	garden.water("bed_0", 0, db) ## consumes thirst
	var dry := garden.water("bed_0", 0, db)
	t.ok(bool(dry.get("not_thirsty", false)), "second water blocked until thirst returns")

	## Force thirst + enough waters/time to reach grown.
	var advanced_to_grown := false
	for _i in 40:
		slot = garden.get_slot("bed_0", 0)
		if not bool(slot.get("thirsty", false)):
			slot["thirsty"] = true
			garden.beds["bed_0"][0] = slot
		garden.water("bed_0", 0, db)
		## Satisfy min stage time without waiting real seconds.
		slot = garden.get_slot("bed_0", 0)
		slot["stage_time"] = 999.0
		garden.beds["bed_0"][0] = slot
		garden._try_advance("bed_0", 0, db)
		if str(garden.get_slot("bed_0", 0).get("stage", "")) == GardenState.STAGE_GROWN:
			advanced_to_grown = true
			break
	t.ok(advanced_to_grown, "reaches grown with waters + time")
	t.ok(garden.is_harvestable("bed_0", 0), "harvestable icon state")
	var pid := garden.harvest("bed_0", 0)
	t.eq(pid, "radish", "harvest returns radish")
	t.ok(garden.is_empty("bed_0", 0), "slot empty after harvest")

	## Lettuce: plant → tick restores thirst on interval
	garden.plant("bed_0", 1, "lettuce")
	garden.water("bed_0", 1, db)
	t.ok(not garden.is_thirsty("bed_0", 1), "not thirsty right after water")
	var plant: Dictionary = db.get_plant("lettuce")
	var interval := float(plant.get("thirst_interval", 4.0))
	garden.tick(interval + 0.1, db)
	t.ok(garden.is_thirsty("bed_0", 1), "thirst returns after interval")
	return t

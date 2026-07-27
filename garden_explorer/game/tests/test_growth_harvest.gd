extends RefCounted
## Water-then-wait growth per bed, thirst gating, harvest.

func run() -> TestAssert:
	var t := TestAssert.new("GrowthHarvest")
	var db := SeedDB.new()
	db.load_all()
	var garden := GardenState.new()
	garden.setup(PackedStringArray(["bed_0"]), 4)
	t.ok(garden.plant_bed("bed_0", "radish"), "plant radish bed")
	t.eq(garden.bed_stage("bed_0"), GardenState.STAGE_SEED, "starts as seed")
	t.ok(garden.is_bed_thirsty("bed_0"), "thirsty immediately after plant")

	## Watering while not thirsty should fail.
	garden.water_bed("bed_0", db) ## consumes thirst + starts timer
	var dry := garden.water_bed("bed_0", db)
	t.ok(bool(dry.get("not_thirsty", false)), "second water blocked until next stage")

	## Force advance through stages: water → set time → try advance.
	var advanced_to_grown := false
	for _i in 12:
		if garden.is_bed_thirsty("bed_0"):
			garden.water_bed("bed_0", db)
		var slot := garden.get_slot("bed_0", 0)
		slot["stage_time"] = 999.0
		slot["watered_stage"] = true
		slot["thirsty"] = false
		garden.beds["bed_0"][0] = slot
		garden._sync_slots_from_lead("bed_0")
		garden._try_advance_bed("bed_0", db)
		if garden.bed_stage("bed_0") == GardenState.STAGE_GROWN:
			advanced_to_grown = true
			break
	t.ok(advanced_to_grown, "reaches grown with water + time")
	t.ok(garden.is_bed_harvestable("bed_0"), "harvestable")
	var pid := garden.harvest_bed("bed_0")
	t.eq(pid, "radish", "harvest returns radish")
	t.ok(garden.is_bed_empty("bed_0"), "bed empty after harvest")

	## Lettuce: water starts the stage clock; thirst does not return mid-stage.
	garden.plant_bed("bed_0", "lettuce")
	garden.water_bed("bed_0", db)
	t.ok(not garden.is_bed_thirsty("bed_0"), "not thirsty right after water")
	var plant: Dictionary = db.get_plant("lettuce")
	var need := float(plant.get("seconds_seed", 4.0))
	garden.tick(need + 0.1, db)
	t.eq(garden.bed_stage("bed_0"), GardenState.STAGE_SPROUT, "advances to sprout after wait")
	t.ok(garden.is_bed_thirsty("bed_0"), "thirsty again at new stage")
	return t

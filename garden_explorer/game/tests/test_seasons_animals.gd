extends RefCounted
## Phase 4 — season cycling + animal hit tests.

const SeasonClockScript := preload("res://scripts/sim/SeasonClock.gd")

func run() -> TestAssert:
	var t := TestAssert.new("SeasonsAnimals")
	var db := SeedDB.new()
	db.load_all()
	t.eq(db.current_season, "spring", "starts in spring")
	t.ok(db.season_duration_sec > 0.0, "duration from json")
	t.eq(db.next_season_id(), "summer", "next is summer")
	t.eq(db.advance_season(), "summer", "advance → summer")
	t.ok(db.is_seed_available("corn"), "summer has corn")
	t.ok(not db.is_seed_available("radish"), "summer has no radish")
	db.set_season("spring")
	t.ok(not db.is_seed_available("corn"), "spring has no corn")
	db.set_season("summer")
	db.advance_season()
	t.eq(db.current_season, "fall", "→ fall")
	db.advance_season()
	t.eq(db.current_season, "winter", "→ winter")
	db.advance_season()
	t.eq(db.current_season, "spring", "wraps to spring")
	t.eq(db.season_label("fall"), "Fall", "label")

	var clock = SeasonClockScript.new()
	db.set_season("spring")
	clock.setup(db, 9999.0)
	t.eq(clock.force_advance(), "summer", "clock force_advance")
	t.eq(db.current_season, "summer", "db synced via clock")

	var farm := FarmMap.new()
	farm.build_from_file()
	t.ok(farm.animal_positions.has("chicken_a"), "chicken_a placed")
	t.ok(farm.animal_positions.has("rabbit"), "rabbit placed")
	var chick_pos: Vector2 = farm.animal_positions["chicken_a"]
	t.eq(farm.animal_at(chick_pos, 48.0), "chicken_a", "animal_at hit")
	t.eq(farm.animal_at(chick_pos + Vector2(500, 500), 48.0), "", "animal_at miss")
	var zone := farm.zone_at(chick_pos)
	t.eq(str(zone.get("kind", "")), "animal", "zone prefers animal")
	var fence_hit := farm.zone_at(farm.fence_center)
	t.eq(str(fence_hit.get("kind", "")), "fence", "fence center stays fence")
	farm.apply_season_tint("winter")
	var ground := farm.get_node_or_null("Ground") as Polygon2D
	t.ok(ground != null, "ground exists")
	t.ok(ground.modulate != Color(1, 1, 1, 1), "winter tint applied")

	## Season change must NOT clear plants already in beds — only harvest / spade do.
	var garden := GardenState.new()
	garden.setup(["bed_0"], 4)
	t.ok(garden.plant_bed("bed_0", "lettuce"), "plant lettuce in spring bed")
	## Force grown without watering loop.
	var s: Dictionary = garden.get_slot("bed_0", 0)
	s["stage"] = GardenState.STAGE_GROWN
	s["thirsty"] = false
	garden.beds["bed_0"][0] = s
	garden._sync_slots_from_lead("bed_0")
	t.ok(garden.is_bed_harvestable("bed_0"), "lettuce harvestable before season flip")
	db.set_season("spring")
	db.advance_season() ## → summer; shed seeds change, beds must stay
	t.eq(db.current_season, "summer", "now summer")
	t.eq(garden.bed_plant_id("bed_0"), "lettuce", "plant remains after season change")
	t.eq(garden.bed_stage("bed_0"), GardenState.STAGE_GROWN, "stage remains grown")
	t.ok(garden.is_bed_harvestable("bed_0"), "still harvestable after season change")
	t.ok(not db.is_seed_available("lettuce"), "lettuce off shed in summer")
	t.ok(db.is_seed_available("tomato"), "tomato on shed in summer")
	return t

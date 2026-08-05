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
	var decor := farm.get_node_or_null("SeasonDecor")
	t.ok(decor != null, "season decor present")
	## World-space weather is a FarmMap child (mapped landings + splash/rest).
	var overlay := farm.get_node_or_null("SeasonWeather")
	t.ok(overlay != null, "winter rain overlay")
	t.ok(overlay.get("mode") == 1, "winter mode is rain") ## SeasonWeather.Mode.RAIN
	var winter_pen := 0
	if overlay and overlay.get("_landings") is Array:
		for land in overlay._landings:
			if farm.in_pen((land as Dictionary).get("pos", Vector2.ZERO)):
				winter_pen += 1
	t.ok(winter_pen >= 8, "winter rain landings include pen (%d)" % winter_pen)
	farm.apply_season_tint("fall")
	overlay = farm.get_node_or_null("SeasonWeather")
	t.ok(overlay != null, "fall has falling leaves")
	t.ok(overlay.get("mode") == 2, "fall mode is leaves")
	var fall_pen := 0
	if overlay and overlay.get("_landings") is Array:
		for land2 in overlay._landings:
			if farm.in_pen((land2 as Dictionary).get("pos", Vector2.ZERO)):
				fall_pen += 1
	t.ok(fall_pen >= 8, "fall leaf landings include pen (%d)" % fall_pen)
	var fall_decor := farm.get_node_or_null("SeasonDecor")
	t.ok(fall_decor != null and fall_decor.get_child_count() >= 40,
		"fall ground leaves cover yard+pen (%d)" % (fall_decor.get_child_count() if fall_decor else -1))
	## With sprites, meadow trees sit outside the yard and swap by season.
	var art := FarmSprites.new()
	art.bootstrap()
	var farm2 := FarmMap.new()
	farm2.set_sprites(art)
	farm2.build_from_file()
	t.ok(farm2._meadow_trees.size() >= 4, "meadow trees placed outside yard")
	farm2.apply_season_tint("winter")
	var first: Sprite2D = farm2._meadow_trees[0] if farm2._meadow_trees.size() > 0 else null
	t.ok(first != null and first.texture != null, "winter tree texture set")

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

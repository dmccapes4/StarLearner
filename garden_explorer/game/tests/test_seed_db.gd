extends RefCounted
## Seed catalogue + seasonal inventory (32 crops, 8 per season).

func run() -> TestAssert:
	var t := TestAssert.new("SeedDB")
	var db := SeedDB.new()
	db.load_all()
	t.eq(db.plant_order.size(), 32, "32 plants")
	t.ok(db.plants.has("tomato"), "tomato present")
	t.ok(db.plants.has("garlic"), "garlic present")
	db.set_season("spring")
	var spring := db.available_seed_ids()
	t.eq(spring.size(), 8, "spring has 8 seeds")
	t.ok(spring.has("radish"), "spring has radish")
	t.ok(spring.has("lettuce"), "spring has lettuce")
	t.ok(not spring.has("tomato"), "spring no tomato (summer)")
	db.set_season("winter")
	var winter := db.available_seed_ids()
	t.eq(winter.size(), 8, "winter has 8 seeds")
	t.ok(winter.has("garlic"), "winter has garlic")
	t.ok(not winter.has("corn"), "winter has no corn")
	## Slides-only plants still resolve a path string or empty — no crash.
	var mp := db.media_path("carrot", "seed")
	t.ok(typeof(mp) == TYPE_STRING, "media path is string")
	t.eq(db.advance_season(), "spring", "winter wraps to spring")
	t.eq(db.season_label(), "Spring", "spring label")
	return t

extends RefCounted
## Animal names / sizes + weighted bug picker against seed catalog plants.

func run() -> TestAssert:
	var t := TestAssert.new("BugsAnimalsCatalog")
	var animals = preload("res://scripts/content/AnimalCatalog.gd").new()
	animals.load_all()
	t.ok(animals.animals.size() >= 6, "six animals")
	t.eq(animals.display_name("chicken_a"), "Penny", "chicken named")
	t.eq(animals.display_name("dog"), "Buddy", "dog named")
	t.ok(animals.in_pen("pig"), "pig in pen")
	t.ok(not animals.in_pen("dog"), "dog outside pen")
	t.ok(absf(animals.scale_of("chicken_a") - 3.5) < 0.01, "chicken reference scale")
	t.ok(animals.scale_of("cow") < animals.scale_of("chicken_a"), "cow scaled down vs chicken")
	t.ok(animals.scale_of("pig") < 2.0, "pig not oversized")
	t.ok(animals.scale_of("dog") < 2.0, "dog not oversized")

	var bugs = preload("res://scripts/content/BugCatalog.gd").new()
	bugs.load_all()
	t.eq(bugs.bugs.size(), 12, "twelve bugs")
	t.ok(bugs.by_id.has("ladybug"), "ladybug")
	t.ok(bugs.by_id.has("rolly_polly"), "rolly polly")

	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var tomato_pick := bugs.pick_weighted(PackedStringArray(["tomato", "lettuce"]), rng)
	t.ok(not tomato_pick.is_empty(), "weighted pick returns bug")
	t.ok(str(tomato_pick.get("id", "")) != "", "pick has id")

	## Empty bed still returns something (soil critters boosted).
	rng.seed = 7
	var empty_pick := bugs.pick_weighted(PackedStringArray(), rng)
	t.ok(not empty_pick.is_empty(), "empty bed pick")

	var farm := FarmMap.new()
	farm.build_from_file()
	t.ok(not farm.is_blocked(farm.fence_center), "pen walkable")
	t.ok(farm.gate_world != Vector2.ZERO, "gate world set")
	return t

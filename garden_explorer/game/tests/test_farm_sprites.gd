extends RefCounted
## Mana Seed crop sheets + Sprout Lands world fills.

func run() -> TestAssert:
	var t := TestAssert.new("FarmSprites")
	var art := FarmSprites.new()
	art.bootstrap()
	t.ok(art.available, "sprite packs available")
	t.ok(art.mana_ready, "Mana Seed crops loaded")
	t.ok(art.grass_texture() != null or art.tilled_texture() != null, "ground fills")
	t.ok(art.seed_icon("tomato") != null, "tomato seed bag")
	t.ok(art.plant_stage_texture("bean", "sprout") != null, "bean sprout frame")
	t.ok(art.plant_stage_texture("lettuce", "grown") != null, "lettuce grown frame")
	t.ok(art.harvest_icon("carrot") != null, "carrot harvest icon")
	t.ok(art.character_idle() != null, "character idle")
	var chick := art.chicken_texture("default")
	t.ok(chick != null, "chicken frame")
	if chick:
		var sz := chick.get_size()
		t.ok(sz.x <= 16.5 and sz.y <= 16.5, "chicken is a single 16px frame")
	var brown := art.chicken_texture("brown")
	t.ok(brown != null, "brown chicken frame")
	return t

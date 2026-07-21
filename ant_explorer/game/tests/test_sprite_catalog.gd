extends RefCounted
const _SpriteCatalog := preload("res://scripts/render/SpriteCatalog.gd")
## Mega_pack sprite catalog maps castes; empty packs fall back to capsules.

func run() -> TestAssert:
	var t := TestAssert.new("SpriteCatalog")
	var cat := _SpriteCatalog.new()
	cat.bootstrap()

	t.ok(cat.available, "keyframes directory discovered")
	t.ok(cat.has_art(AntEnums.Caste.FORAGER), "forager has idle frames")
	t.ok(cat.has_art(AntEnums.Caste.PLAYER), "player has idle frames")
	t.ok(cat.has_art(AntEnums.Caste.QUEEN), "queen has idle frames")
	t.ok(cat.has_art(AntEnums.Caste.SOLDIER), "soldier has idle frames")
	t.ok(cat.has_art(AntEnums.Caste.NURSE), "nurse has idle frames")
	t.ok(cat.has_art(AntEnums.Caste.GARDENER), "gardener has idle frames")
	t.ok(cat.has_art(AntEnums.Caste.INVADER), "invader has idle frames")
	t.ok(cat.has_art(AntEnums.Caste.LARVA), "larva prop loaded")
	t.ok(cat.has_art(AntEnums.Caste.PUPA), "pupa/egg prop loaded")

	var forager: Dictionary = cat.frames_for(AntEnums.Caste.FORAGER, false)
	var idle: Array = forager.get("idle", []) as Array
	var move: Array = forager.get("move", []) as Array
	t.ge(idle.size(), 4, "forager idle has several frames")
	t.ge(move.size(), 4, "forager move has several frames")

	var leaf: Dictionary = cat.frames_for(AntEnums.Caste.FORAGER, true)
	var leaf_idle: Array = leaf.get("idle", []) as Array
	t.ge(leaf_idle.size(), 4, "leaf-carry forager pack")
	t.ok(leaf_idle[0] != idle[0], "leaf pack differs from bare forager")

	var player_leaf: Dictionary = cat.frames_for(AntEnums.Caste.PLAYER, true)
	t.ge((player_leaf.get("idle", []) as Array).size(), 4, "player uses leaf pack when carrying")

	return t

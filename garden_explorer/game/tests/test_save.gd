extends RefCounted
## Phase 6 — Save beds / season / wipe flag contract.

func run() -> TestAssert:
	var t := TestAssert.new("Save")
	## Exercise GardenState blob round-trip (Save autoload may be absent under -s).
	var gs := GardenState.new()
	gs.setup(PackedStringArray(["bed_0", "bed_1"]), 4)
	t.ok(gs.plant("bed_0", 0, "lettuce"), "plant")
	var blob := gs.to_blob()
	t.ok(blob.has("bed_0"), "blob has bed")
	var gs2 := GardenState.new()
	gs2.setup(PackedStringArray(["bed_0", "bed_1"]), 4)
	gs2.from_blob(blob)
	t.eq(str(gs2.get_slot("bed_0", 0).get("plant_id", "")), "lettuce", "restore plant")
	t.eq(str(gs2.get_slot("bed_0", 0).get("stage", "")), "seed", "restore stage")
	return t

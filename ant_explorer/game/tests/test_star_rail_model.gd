extends RefCounted
## StarRailModel — tile state from Save, friendly place labels, guidance/watch
## lines, and icon-path resolution.

const Model := preload("res://scripts/ui/StarRailModel.gd")
const Layout := preload("res://scripts/ui/StarRailLayout.gd")

func run() -> TestAssert:
	var t := TestAssert.new("StarRailModel")

	var m := Model.new()

	# Static state mapping.
	t.eq(Model.state_for(false), Model.TILE_UNDISCOVERED, "false → undiscovered")
	t.eq(Model.state_for(true), Model.TILE_COLLECTED, "true → collected")

	# tile_state follows Save.
	var saved: PackedStringArray = Save.stars_collected.duplicate()
	Save.stars_collected = PackedStringArray()
	t.eq(m.tile_state("01_queen"), Model.TILE_UNDISCOVERED, "uncollected → undiscovered")
	Save.stars_collected = PackedStringArray(["01_queen"])
	t.eq(m.tile_state("01_queen"), Model.TILE_COLLECTED, "collected → collected")
	Save.stars_collected = saved

	# Every star has a non-empty place label, guidance and watch line.
	for id in Layout.all_ids():
		var place := m.place_label(id)
		t.ok(not place.is_empty(), "place label for %s" % id)
		var guide := m.guidance_line(id)
		t.ok(guide.to_lower().contains("golden star"), "guidance mentions golden star (%s)" % id)
		t.ok(guide.contains(place) or guide.length() > 0, "guidance non-empty (%s)" % id)
		var prompt := m.watch_prompt(id)
		t.ok(prompt.to_lower().contains("tap again"), "watch prompt says tap again (%s)" % id)
		t.ok(prompt.to_lower().contains("watch"), "watch prompt says watch (%s)" % id)
		t.ok(not m.topic_short(id).is_empty(), "topic short for %s" % id)
		t.ok(m.file_for(id).ends_with(".ogv"), "file resolves to ogv (%s)" % id)

	# Zone label mapping is defined for the known zone.
	t.eq(m.zone_for("01_queen"), "queen", "zone for queen star")

	# Icon paths resolve to files that exist on disk (generated tiles).
	for id in Layout.all_ids():
		var p := m.icon_path(id)
		t.ok(not p.is_empty(), "icon path resolves for %s" % id)
		t.ok(FileAccess.file_exists(p) or ResourceLoader.exists(p), "icon file exists for %s" % id)

	return t

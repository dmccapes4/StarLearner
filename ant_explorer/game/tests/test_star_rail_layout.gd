extends RefCounted
## StarRailLayout — fixed 6+6 slot assignment, side/index lookups, StarDB coverage.

const Layout := preload("res://scripts/ui/StarRailLayout.gd")

func run() -> TestAssert:
	var t := TestAssert.new("StarRailLayout")

	var left := Layout.left_ids()
	var right := Layout.right_ids()
	t.eq(left.size(), 6, "6 left slots")
	t.eq(right.size(), 6, "6 right slots")

	var all := Layout.all_ids()
	t.eq(all.size(), 12, "12 slots total")

	# No id appears twice across the rails.
	var seen := {}
	var dupes := 0
	for id in all:
		if seen.has(id):
			dupes += 1
		seen[id] = true
	t.eq(dupes, 0, "no duplicate ids across rails")

	# Every layout id exists in StarDB, and every StarDB id has a slot.
	var db := StarDB.new()
	db.load_db()
	t.eq(db.stars_ordered.size(), 12, "StarDB has 12 stars")
	for id in all:
		t.ok(db.by_id.has(id), "layout id %s exists in StarDB" % id)
	for entry in db.stars_ordered:
		var sid := str(entry.get("id", ""))
		t.ok(seen.has(sid), "StarDB id %s has a rail slot" % sid)

	# Sides and indices.
	t.eq(Layout.side_for("01_queen"), Layout.SIDE_LEFT, "first star on left")
	t.eq(Layout.side_for("07_soldiers"), Layout.SIDE_RIGHT, "seventh star on right")
	t.eq(Layout.side_for("nope"), "", "unknown id has no side")
	t.eq(Layout.slot_index("01_queen"), 0, "first left slot index 0")
	t.eq(Layout.slot_index("06_pheromone"), 5, "sixth left slot index 5")
	t.eq(Layout.slot_index("07_soldiers"), 0, "first right slot index 0")
	t.eq(Layout.slot_index("12_invaders"), 5, "sixth right slot index 5")
	t.eq(Layout.slot_index("nope"), -1, "unknown id index -1")

	return t

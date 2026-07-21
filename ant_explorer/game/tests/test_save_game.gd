extends RefCounted
## Tests for SaveGame dict shape + Save autoload dirty flag.

func run() -> TestAssert:
	var t := TestAssert.new("SaveGame")
	var d := SaveGame.to_dict(
		12, 99, 0.8,
		[{"id": 1, "caste": 2}],
		PackedStringArray(["01_queen"]),
		{"node": 0, "pos": {"x": 1.0, "y": 2.0}}
	)
	t.eq(d["tick"], 12, "tick field")
	t.eq(d["rng_seed"], 99, "rng_seed field")
	t.approx(d["garden_health"], 0.8, 0.001, "garden_health field")
	t.eq(d["stars_collected"].size(), 1, "stars_collected")
	t.eq(d["player"]["node"], 0, "player node")

	Save.dirty = false
	Save.mark_dirty()
	t.ok(Save.dirty, "mark_dirty sets flag")
	Save.stars_collected = PackedStringArray(["test"])
	Save.save_if_dirty()
	t.ok(not Save.dirty, "save_if_dirty clears flag")
	var loaded := Save.load_save()
	t.ok(loaded.has("stars_collected"), "load_save returns blob")

	# rails hidden/shown persistence (landscape shell)
	var prev_rails := Save.rails_hidden
	Save.rails_hidden = false
	Save.dirty = false
	t.ok(Save.set_rails_hidden(true), "set_rails_hidden changes state")
	t.ok(Save.are_rails_hidden(), "are_rails_hidden reflects true")
	t.ok(not Save.dirty, "rails toggle flushes immediately")
	t.ok(not Save.set_rails_hidden(true), "set_rails_hidden idempotent")
	var blob2 := Save.load_save()
	t.ok(blob2.has("rails_hidden"), "rails_hidden persisted in blob")
	t.eq(bool(blob2.get("rails_hidden", false)), true, "rails_hidden value persisted")
	# Leave the on-disk save with rails shown (product default) so a dev boot
	# after tests doesn't start with the rails tucked away.
	Save.rails_hidden = false
	Save.dirty = true
	Save.save_if_dirty()
	Save.rails_hidden = prev_rails

	var prev_intro := Save.intro_completed
	Save.intro_completed = false
	Save.set_intro_completed(true)
	t.ok(Save.intro_completed, "intro_completed set")
	var blob3 := Save.load_save()
	t.eq(bool(blob3.get("intro_completed", false)), true, "intro_completed persisted")
	Save.set_player_pos(Vector2(12.5, -3.0))
	Save.save_if_dirty()
	t.ok(Save.has_player_pos(), "player pos stored")
	var blob4 := Save.load_save()
	t.approx(float(blob4.get("player_x", 0.0)), 12.5, 0.01, "player_x persisted")
	Save.clear_all()
	t.ok(not Save.intro_completed, "clear_all resets intro")
	t.ok(not Save.has_player_pos(), "clear_all clears player pos")
	t.eq(Save.stars_collected.size(), 0, "clear_all clears stars")
	Save.intro_completed = prev_intro
	return t

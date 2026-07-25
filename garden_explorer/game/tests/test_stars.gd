extends RefCounted
## Phase 5 — StarDB, reveal rules, Save collect, video path helper.

const StarDBScript := preload("res://scripts/content/StarDB.gd")
const StarProgressScript := preload("res://scripts/sim/StarProgress.gd")

func run() -> TestAssert:
	var t := TestAssert.new("Stars")
	var db = StarDBScript.new()
	db.load_all()
	t.eq(db.star_ids().size(), 12, "12 stars")
	t.ok(db.by_id.has("01_seeds"), "01_seeds")
	t.eq(db.reveal_rule("01_seeds"), "always", "always reveal")
	t.eq(db.reveal_rule("03_planting"), "gameplay:planted_once", "plant rule")
	t.eq(db.zone("11_animals"), "fence", "animals zone")
	t.ok(not db.intro.is_empty(), "intro meta")
	t.eq(StarDBScript.resolve_video_path("missing_nope.ogv"), "", "missing clip")

	var save := _FakeSave.new()
	var prog = StarProgressScript.new()
	prog.setup(db, save)
	t.ok(prog.is_revealed("01_seeds"), "always revealed")
	t.ok(not prog.is_revealed("03_planting"), "planting locked")
	save.set_flag("planted_once", true)
	t.ok(prog.is_revealed("03_planting"), "planting unlocked")
	t.ok(prog.collect("01_seeds"), "collect seeds star")
	t.ok(prog.is_collected("01_seeds"), "has collected")
	t.ok(not prog.collect("01_seeds"), "no double collect")
	t.ok(prog.unlock_hint("04_watering").findn("Water") >= 0, "hint")
	t.ok(prog.guidance_line("11_animals").findn("animal") >= 0, "guide line")
	return t


class _FakeSave:
	extends RefCounted
	var stars_collected: PackedStringArray = PackedStringArray()
	var flags: Dictionary = {}
	var intro_completed: bool = false

	func has_star(id: String) -> bool:
		return stars_collected.has(id)

	func collect_star(id: String) -> bool:
		if has_star(id):
			return false
		stars_collected.append(id)
		return true

	func has_flag(flag: String) -> bool:
		return bool(flags.get(flag, false))

	func set_flag(flag: String, value: bool = true) -> bool:
		if bool(flags.get(flag, false)) == value:
			return false
		flags[flag] = value
		return true

	func set_intro_completed(done: bool = true) -> void:
		intro_completed = done

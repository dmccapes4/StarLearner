extends RefCounted
## Phase 5 — StarDB, Save.collect_star, dwell trigger, ogv path resolution.

const StarTriggerScript := preload("res://scripts/content/StarTrigger.gd")

func run() -> TestAssert:
	var t := TestAssert.new("StarVideo")

	var db := StarDB.new()
	db.load_db()
	t.eq(db.stars_ordered.size(), 12, "StarDB loads 12 entries")
	for entry in db.stars_ordered:
		var file_name: String = str(entry.get("file", ""))
		t.ok(not file_name.is_empty(), "star has file field")
		t.ok(file_name.ends_with(".ogv"), "star file prefers ogv (%s)" % file_name)

	var saved: PackedStringArray = Save.stars_collected.duplicate()
	Save.stars_collected = PackedStringArray()
	t.ok(Save.collect_star("01_queen"), "collect_star first time returns true")
	t.ok(Save.has_star("01_queen"), "has_star after collect")
	t.ok(not Save.collect_star("01_queen"), "collect_star idempotent")
	t.eq(Save.stars_collected.size(), 1, "one star stored")
	Save.stars_collected = saved

	var radius: float = 90.0
	var dwell: float = 0.75
	var star_pos := Vector2(100, 100)
	var outside := Vector2(300, 100)
	var inside := Vector2(150, 100)
	t.ok(not StarTriggerScript.inside_radius(outside, star_pos, radius), "outside radius")
	t.ok(StarTriggerScript.inside_radius(inside, star_pos, radius), "inside radius")

	var moving := AntState.new()
	moving.state = AntEnums.State.WALK
	moving.path = PackedVector2Array([Vector2.ZERO, Vector2(10, 0)])
	t.ok(not StarTriggerScript.player_stationary(moving), "walking player not stationary")

	var idle := AntState.new()
	idle.state = AntEnums.State.IDLE
	idle.path = PackedVector2Array()
	idle.action_ticks_left = 0
	t.ok(StarTriggerScript.player_stationary(idle), "idle empty-path player stationary")

	var busy := AntState.new()
	busy.state = AntEnums.State.IDLE
	busy.path = PackedVector2Array()
	busy.action_ticks_left = 2
	t.ok(not StarTriggerScript.player_stationary(busy), "action ticks block stationary")

	var first: Dictionary = StarTriggerScript.should_trigger_dwell(
		idle, inside, star_pos, radius, dwell, 0.0, 0.5)
	t.ok(not first["trigger"], "half dwell does not trigger")
	t.ok(first["inside"], "inside during dwell")
	t.ok(first["stationary"], "stationary during dwell")
	t.ok(first["settled"], "settled during dwell")

	var ready: Dictionary = StarTriggerScript.should_trigger_dwell(
		idle, inside, star_pos, radius, dwell, 0.5, 0.3)
	t.ok(ready["trigger"], "full dwell triggers discovery")
	t.approx(ready["accumulated"], 0.8, 0.001, "accumulated dwell time")

	# Walking inside the radius still accumulates — kid taps must not wipe progress.
	var moving_pass: Dictionary = StarTriggerScript.should_trigger_dwell(
		moving, inside, star_pos, radius, dwell, 0.6, 0.2)
	t.ok(not moving_pass["trigger"], "still walking: no trigger yet")
	t.ok(not moving_pass["settled"], "walker is not settled")
	t.approx(moving_pass["accumulated"], 0.8, 0.001, "walking inside keeps accumulating")

	# After walking in range long enough, settling fires immediately.
	var arrive: Dictionary = StarTriggerScript.should_trigger_dwell(
		idle, inside, star_pos, radius, dwell, 0.8, 0.05)
	t.ok(arrive["trigger"], "settling after approach triggers")

	var leave: Dictionary = StarTriggerScript.should_trigger_dwell(
		idle, outside, star_pos, radius, dwell, 0.6, 0.2)
	t.ok(not leave["trigger"], "leaving radius clears dwell")
	t.eq(leave["accumulated"], 0.0, "outside clears accumulator")

	t.ok(StarTriggerScript.should_trigger_arrival(
		idle, inside, star_pos, radius, "01_queen", "01_queen"),
		"pending approach discovers on settle")
	t.ok(not StarTriggerScript.should_trigger_arrival(
		moving, inside, star_pos, radius, "01_queen", "01_queen"),
		"pending approach waits until settled")
	t.ok(not StarTriggerScript.should_trigger_arrival(
		idle, inside, star_pos, radius, "01_queen", "02_larvae"),
		"pending approach ignores other stars")

	var ogv_path: String = StarTriggerScript.resolve_video_path("01_queen.ogv")
	t.ok(ogv_path.ends_with("01_queen.ogv"), "ogv path resolves")
	t.ok(FileAccess.file_exists(ogv_path) or ResourceLoader.exists(ogv_path), "ogv file exists on disk")

	var vo_path: String = StarTriggerScript.resolve_star_vo_path("01_queen")
	if FileAccess.file_exists(vo_path) or ResourceLoader.exists(vo_path):
		t.ok(vo_path.ends_with("01_queen.wav"), "star VO path resolves when present")

	return t

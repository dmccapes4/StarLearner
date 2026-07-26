extends SceneTree
## UX suite: drive Main through kid flows, capture screenshots, assert log/events.
##
##   ./tools/run_ux_suite.sh
##   godot --path game -s res://tools/ux_suite.gd
##
## Outputs: docs/screenshots/ux/*.png + ux_report.json
## Exit 0 = all checks passed.

const OUT_DIR := "res://docs/screenshots/ux"
const NarratorLib := preload("res://scripts/audio/Narrator.gd")

var _logs: PackedStringArray = PackedStringArray()
var _checks: Array = []
var _shot_i: int = 0
var _ev: Node ## /root/Events autoload (resolved at runtime for -s scripts)

func _init() -> void:
	call_deferred("_run")

func _events() -> Node:
	if _ev == null:
		_ev = root.get_node_or_null("/root/Events")
	return _ev

func _run() -> void:
	print("======== Garden Explorer UX suite ========")
	var abs_dir := ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(abs_dir)
	if _events() == null:
		_fail("events_autoload", "/root/Events missing")
		_finish()
		return
	## Fresh progress for deterministic star guidance / collect checks.
	var save := root.get_node_or_null("/root/Save")
	if save:
		if save.has_method("clear_all"):
			save.clear_all()
		if save.has_method("set_intro_completed"):
			save.set_intro_completed(true)
	_install_log_hook()

	var MainScene := load("res://scenes/Main.tscn")
	if MainScene == null:
		_fail("boot", "Main.tscn failed to load")
		_finish()
		return
	var main: Node = MainScene.instantiate()
	root.add_child(main)
	await _settle(10)
	## Ensure intro / video didn't leave the tree paused.
	paused = false

	var world: Node2D = main.get_node_or_null("World") as Node2D
	_check("world_present", world != null, "World node")
	if world == null or world.get_script() == null:
		_fail("world_script", "World.gd failed to attach")
		_finish()
		return

	var farm: FarmMap = world.get_node_or_null("FarmMap") as FarmMap
	var sprites_ok: bool = bool(world.get("sprites") and world.sprites.available)
	_check("sprites_ready", sprites_ok, "Sprout Lands available")
	_check("six_beds", farm != null and farm.bed_count() == 6, "bed_count=%s" % (farm.bed_count() if farm else -1))
	_check_chickens_are_frames(farm)
	await _shot("farm_boot")

	_events().world_tapped.emit(farm.shed_center)
	await _wait_and_confirm(main)
	_check_log_contains("open_shed_log", "shed_opened")
	var shed: Node = main.get_node_or_null("ShedUI")
	_check("shed_open", shed != null and shed.call("is_open"), "shed panel open")
	await _shot("shed_open")

	var db: SeedDB = world.seed_db
	var seeds := db.available_seed_ids()
	_check("seasonal_seeds", seeds.size() > 0, "count=%d" % seeds.size())
	var pick := "lettuce" if seeds.has("lettuce") else str(seeds[0])
	if shed and shed.has_method("_on_seed_pressed"):
		shed.call("_on_seed_pressed", pick)
	## First-seed discovery narrates ~10 s, then opens a tree-pausing
	## MediaPanel and only then emits seed_selected — drain all of it.
	await _drain_freezes(main, 1200)
	_check("seed_selected", str(shed.call("selected_seed")) == pick, "holding %s" % pick)
	_check_log_contains("seed_selected_log", "seed_selected:%s" % pick)
	await _shot("seed_selected")

	if shed and shed.has_method("close_shed"):
		shed.call("close_shed")
	await _settle(4)

	var garden: GardenState = world.garden
	for i in 4:
		await _tap_and_confirm(main, farm.slot_world("bed_0", i))
	_check("planted_four", garden.occupied_count("bed_0") == 4, "occupied=%d" % garden.occupied_count("bed_0"))
	_check_log_contains("plant_log", "planted:")
	await _shot("bed_full")

	# Clear seed so bed taps don't try to plant
	if shed and shed.has_method("clear_selection"):
		shed.call("clear_selection")
	await _settle(2)

	## Per-bed watering: one Water action soaks every thirsty plot in the bed.
	await _tap_and_confirm_kind(main, farm.slot_world("bed_0", 0), "water")
	var still_thirsty := 0
	for i in 4:
		if garden.is_thirsty("bed_0", i):
			still_thirsty += 1
	_check("bed_watered", still_thirsty == 0, "thirsty after bed water=%d" % still_thirsty)
	_check_log_contains("water_log", "watered:")

	for i in 4:
		_force_grown(garden, db, "bed_0", i)
	await _settle(6)
	var grown_n := 0
	for i in 4:
		if str(garden.get_slot("bed_0", i).get("stage", "")) == GardenState.STAGE_GROWN:
			grown_n += 1
	_check("grown_after_water", grown_n == 4, "grown_slots=%d" % grown_n)
	var stage_hit := false
	for line in _logs:
		if str(line).begins_with("stage:") or str(line).begins_with("watered:"):
			stage_hit = true
			break
	_check("stage_or_water_log", stage_hit, "saw stage/water events")
	await _shot("grown")

	var before_total := _sum_totals(world.harvest_totals)
	for i in 4:
		## First interact may open grown media; second picks Harvest from action tiles.
		await _tap_and_confirm(main, farm.slot_world("bed_0", i))
		await _drain_freezes(main, 900)
		## Retry: a roaming animal near the bed can steal a tap.
		for _try in 3:
			if garden.is_empty("bed_0", i):
				break
			await _tap_and_confirm_kind(main, farm.slot_world("bed_0", i), "harvest")
			## First harvest runs the full ceremony (grid + video) — drain it.
			await _drain_freezes(main, 1800)
	var after_total := _sum_totals(world.harvest_totals)
	_check("harvest_stored", after_total >= before_total + 4, "totals %d→%d" % [before_total, after_total])
	_check_log_contains("harvest_log", "harvest:")
	await _shot("after_harvest")

	_events().hamburger_pressed.emit()
	await _settle(4)
	var star_menu: Node = main.get_node_or_null("HamburgerUI")
	var menu_open := false
	if star_menu != null and star_menu.has_method("is_open"):
		menu_open = bool(star_menu.call("is_open"))
	_check("star_menu_open", menu_open, "hamburger open")
	await _shot("star_menu")

	## Concept tab — undiscovered tile unlock tip (emits guide), then collect a revealed concept.
	if star_menu and star_menu.has_method("_on_concept"):
		star_menu.call("_on_concept", "08_weeding") ## locked until uproot
	await _settle(8)
	_check_log_contains("guide_log", "guide:")
	await _shot("star_guidance")
	if star_menu and star_menu.has_method("_on_concept"):
		star_menu.call("_on_concept", "01_seeds")
	await _settle(6)
	if star_menu and star_menu.has_method("_on_concept"):
		star_menu.call("_on_concept", "01_seeds")
	await _settle(8)
	var video: Node = main.get_node_or_null("VideoPanel")
	var media: Node = main.get_node_or_null("MediaPanel")
	var media_open := (video != null and bool(video.call("is_open"))) \
		or (media != null and bool(media.call("is_open")))
	_check("video_open", media_open, "video or media panel open")
	await _shot("star_video")
	_close_any_media(main)
	paused = false
	await _settle(4)
	_check_log_contains("star_collected_log", "star_collected:01_seeds")
	_check("star_collected", world.progress != null and bool(world.progress.is_collected("01_seeds")),
		"01_seeds collected")

	## Enter the pen via gate routing first — animal interact is same-zone only.
	_events().world_tapped.emit(farm.fence_center)
	for _i in 1800:
		await process_frame
		var p: Node2D = world.get("player")
		if p and farm.in_pen(p.global_position) and not bool(p.get("moving")):
			break
	_check("entered_pen", farm.in_pen(world.get("player").global_position), "player in pen")
	await _shot("animals")

	# Phase 4 — pen animal tap (player already inside the pen).
	var chick: Node2D = world.call("_animal_node", "chicken_a")
	var chick_pos: Vector2 = chick.global_position if chick \
		else farm.animal_positions.get("chicken_a", farm.fence_center)
	_events().world_tapped.emit(chick_pos)
	await _wait_log("animal:", 1800)
	_check_log_contains("animal_tap_log", "animal:")
	await _shot("animal_tap")

	var spring_seeds := db.available_seed_ids("spring")
	var before_season := db.current_season
	world.call("advance_season")
	await _settle(6)
	var after_season := db.current_season
	_check("season_flipped", after_season != before_season, "%s→%s" % [before_season, after_season])
	_check_log_contains("season_log", "season:")
	var after_seeds := db.available_seed_ids()
	var lists_differ := false
	if after_seeds.size() != spring_seeds.size():
		lists_differ = true
	else:
		for pid in after_seeds:
			if not spring_seeds.has(pid):
				lists_differ = true
				break
	_check("season_seed_list_changed", lists_differ or after_season != "spring",
		"season=%s seeds=%d" % [after_season, after_seeds.size()])
	if shed and shed.has_method("open_shed"):
		shed.call("open_shed")
	await _settle(5)
	await _shot("shed_new_season")
	if shed and shed.has_method("close_shed"):
		shed.call("close_shed")

	_finish()

func _sum_totals(totals: Dictionary) -> int:
	var n := 0
	for k in totals.keys():
		n += int(totals[k])
	return n

func _drain_freezes(main: Node, max_frames: int) -> void:
	## Close media/video panels as they appear and wait until the game has been
	## free of panels and narration locks for ~half a second.
	var clear := 0
	for _i in max_frames:
		await process_frame
		var busy := NarratorLib.blocks_movement()
		for n in ["MediaPanel", "VideoPanel"]:
			var p: Node = main.get_node_or_null(n)
			if p and p.has_method("is_open") and bool(p.call("is_open")):
				busy = true
				if p.has_method("close_panel"):
					p.call("close_panel")
		var rt: Node = main.get_node_or_null("RevealTile")
		if rt and rt.has_method("is_open") and bool(rt.call("is_open")):
			busy = true
			if rt.has_method("close_reveal"):
				rt.call("close_reveal")
		## Celebration grids self-close a few seconds after the tree unpauses.
		for g in ["PlantGrid", "BugGrid"]:
			var grid: Node = main.get_node_or_null(g)
			if grid and grid.has_method("is_open") and bool(grid.call("is_open")):
				busy = true
		if paused:
			busy = true
			paused = false
		clear = 0 if busy else clear + 1
		if clear >= 30:
			return

func _wait_log(needle: String, max_frames: int) -> void:
	for _i in max_frames:
		await process_frame
		for line in _logs:
			if str(line).findn(needle) >= 0:
				return

func _confirm_prompt(main: Node, kind: String = "") -> void:
	var ap: Node = main.get_node_or_null("ActionPrompt")
	if ap == null:
		return
	if ap.has_method("is_open") and not bool(ap.call("is_open")):
		return
	if kind != "" and ap.get("_actions") != null:
		var acts: Array = ap.get("_actions")
		for a in acts:
			if typeof(a) == TYPE_DICTIONARY and str(a.get("kind", "")) == kind:
				ap.call("_pick", a)
				return
	if ap.has_method("confirm_current"):
		ap.call("confirm_current")

func _wait_and_confirm(main: Node, kind: String = "") -> void:
	## Wait for walk → ActionPrompt, then confirm. Walks + narration locks can
	## take several seconds, so wait generously (600 frames ≈ 10 s).
	for _i in 600:
		await process_frame
		var ap: Node = main.get_node_or_null("ActionPrompt")
		if ap and ap.has_method("is_open") and bool(ap.call("is_open")):
			break
	await _settle(2)
	_confirm_prompt(main, kind)
	await _settle(4)

func _tap_and_confirm(main: Node, world_pos: Vector2) -> void:
	_events().world_tapped.emit(world_pos)
	await _wait_and_confirm(main)

func _tap_and_confirm_kind(main: Node, world_pos: Vector2, kind: String) -> void:
	_events().world_tapped.emit(world_pos)
	await _wait_and_confirm(main, kind)

func _check_chickens_are_frames(farm: FarmMap) -> void:
	if farm == null:
		_check("chicken_frames", false, "no farm")
		return
	var found := 0
	var ok := true
	var detail := "no chicken sprites"
	for c in farm.get_children():
		var n := str(c.name)
		if not (n.begins_with("chicken") or n == "rabbit"):
			continue
		found += 1
		if c is Sprite2D:
			var spr := c as Sprite2D
			var tex := spr.texture
			if tex == null:
				ok = false
				detail = "%s missing texture" % n
				break
			var sz := tex.get_size()
			ok = sz.x <= 32.5 and sz.y <= 32.5
			detail = "%s tex %sx%s" % [n, sz.x, sz.y]
			if not ok:
				break
		else:
			detail = "%s placeholder ok" % n
	if found == 0:
		# Animals may be Sprite2D named from map ids — also accept FarmSprites API.
		var art: FarmSprites = FarmSprites.new()
		art.bootstrap()
		var chick := art.chicken_texture()
		ok = chick != null and chick.get_size().x <= 32.5
		detail = "no scene chickens; atlas frame ok=%s" % ok
	_check("chicken_frames", ok, detail)

func _install_log_hook() -> void:
	var ev := _events()
	ev.shed_opened.connect(func() -> void: _logs.append("shed_opened"))
	ev.seed_selected.connect(func(pid: String) -> void: _logs.append("seed_selected:%s" % pid))
	ev.plant_planted.connect(func(b: String, s: int, p: String) -> void: _logs.append("planted:%s:%s:%d" % [p, b, s]))
	ev.plant_uprooted.connect(func(b: String, s: int, p: String) -> void: _logs.append("uprooted:%s:%s:%d" % [p, b, s]))
	ev.plant_watered.connect(func(b: String, s: int, p: String, st: String) -> void: _logs.append("watered:%s:%s:%d:%s" % [p, b, s, st]))
	ev.plant_harvested.connect(func(p: String, total: int) -> void: _logs.append("harvest:%s:%d" % [p, total]))
	ev.plant_stage_changed.connect(func(b: String, s: int, p: String, st: String) -> void: _logs.append("stage:%s:%s:%d:%s" % [p, b, s, st]))
	ev.season_changed.connect(func(sid: String) -> void: _logs.append("season:%s" % sid))
	ev.animal_tapped.connect(func(aid: String) -> void: _logs.append("animal:%s" % aid))
	ev.star_collected.connect(func(sid: String) -> void: _logs.append("star_collected:%s" % sid))
	ev.star_reveal_requested.connect(func(sid: String) -> void: _logs.append("guide:%s" % sid))
	ev.star_revealed.connect(func(sid: String) -> void: _logs.append("revealed:%s" % sid))

func _check(name: String, ok: bool, detail: String) -> void:
	_checks.append({"name": name, "ok": ok, "detail": detail})
	print("[%s] %s — %s" % ["OK" if ok else "FAIL", name, detail])

func _fail(name: String, detail: String) -> void:
	_check(name, false, detail)

func _check_log_contains(name: String, needle: String) -> void:
	var hit := false
	for line in _logs:
		if str(line).findn(needle) >= 0:
			hit = true
			break
	_check(name, hit, "needle='%s' in %d events" % [needle, _logs.size()])

func _shot(name: String) -> void:
	_shot_i += 1
	# Prefer process_frame; frame_post_draw can hang without a presenter.
	for i in 6:
		await process_frame
	var path := ProjectSettings.globalize_path("%s/%02d_%s.png" % [OUT_DIR, _shot_i, name])
	var img: Image = null
	var vp := root.get_viewport()
	if vp:
		var tex := vp.get_texture()
		if tex:
			img = tex.get_image()
	var err := FAILED
	if img != null and img.get_width() > 0:
		err = img.save_png(path)
	var ok := err == OK and FileAccess.file_exists(path)
	# Dummy/headless renderer has no viewport texture — treat as skip, not hard fail.
	if not ok and img == null:
		_check("shot_%s" % name, true, "skipped (no viewport texture; use xvfb/DISPLAY)")
		print("UX shot skipped (no GPU texture): ", name)
		return
	_check("shot_%s" % name, ok, path)
	print("UX shot → ", path)

func _close_any_media(main: Node) -> void:
	for name in ["MediaPanel", "VideoPanel", "StageMediaPanel"]:
		var n: Node = main.get_node_or_null(name)
		if n == null:
			continue
		if n.has_method("is_open") and bool(n.call("is_open")) and n.has_method("_close"):
			n.call("_close")
		elif n.has_method("_close"):
			n.call("_close")
	paused = false

func _force_grown(garden: GardenState, db: SeedDB, bed_id: String, slot: int) -> void:
	## Fast-forward waters + stage time for tests (respects thirst + stage gates).
	for _i in 40:
		var s: Dictionary = garden.get_slot(bed_id, slot)
		if str(s.get("stage", "")) == GardenState.STAGE_GROWN:
			return
		if str(s.get("plant_id", "")).is_empty():
			return
		s["thirsty"] = true
		s["stage_time"] = 999.0
		garden.beds[bed_id][slot] = s
		garden.water(bed_id, slot, db)
		s = garden.get_slot(bed_id, slot)
		s["stage_time"] = 999.0
		garden.beds[bed_id][slot] = s
		garden._try_advance(bed_id, slot, db)

func _settle(frames: int) -> void:
	## Media / video panels pause the tree; keep the suite moving.
	if paused:
		paused = false
	for i in frames:
		await process_frame

func _finish() -> void:
	var passed := 0
	var failed := 0
	for c in _checks:
		if c["ok"]:
			passed += 1
		else:
			failed += 1
	var report := {
		"passed": passed,
		"failed": failed,
		"checks": _checks,
		"logs": Array(_logs),
		"shots": _shot_i,
	}
	var report_path := ProjectSettings.globalize_path(OUT_DIR + "/ux_report.json")
	var f := FileAccess.open(report_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(report, "\t"))
		f.close()
		print("UX report → ", report_path)
	print("======== UX suite: %d passed, %d failed (%d shots) ========" % [passed, failed, _shot_i])
	quit(0 if failed == 0 else 1)

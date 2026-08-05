extends SceneTree
## Full gameplay playthrough + screenshots for docs/demo.
## Emphasizes plant packs (seed→grown + harvest star) and seasonal trees/weather.
##
##   DISPLAY=:1 godot --path game --fixed-fps 24 --disable-vsync \
##     --write-movie /tmp/garden_playthrough.avi \
##     -s res://tools/record_playthrough_demo.gd
##
## Also writes docs/demo/playthrough_markers.json (seconds → beat id) for the
## intro explainer highlight reel.

const SpeakScript := preload("res://scripts/audio/Speak.gd")
const NarratorScript := preload("res://scripts/audio/Narrator.gd")

var _main: Node
var _world: Node2D
var _ev: Node
var _shot_i: int = 0
var _demo_t: float = 0.0 ## movie/engine seconds (not wall clock — MovieWriter compresses real time)
var _markers: Array = [] ## {t, id, note}

func _init() -> void:
	call_deferred("_run")

func _events() -> Node:
	if _ev == null:
		_ev = root.get_node_or_null("/root/Events")
	return _ev

func _run() -> void:
	root.get_viewport().size = Vector2i(1280, 600)
	_demo_t = 0.0
	var save := root.get_node_or_null("/root/Save")
	if save:
		save.clear_all()
	var ig := root.get_node_or_null("/root/IdleGuard")
	if ig and ig.has_method("set_active"):
		ig.set_active(false)

	_main = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	await _sec(0.8)
	_world = _main.get_node_or_null("World") as Node2D
	var farm: FarmMap = _world.get_node_or_null("FarmMap") as FarmMap
	var shed: Node = _main.get_node_or_null("ShedUI")
	var intro: Node = _main.get_node_or_null("IntroPanel")
	self.paused = false

	print("DEMO: intro")
	_mark("intro", "title / start")
	if intro and intro.has_method("_on_start"):
		intro.visible = true
		if intro.get("_panel") != null:
			intro._panel.visible = true
		self.paused = false
		intro.call("_on_start")
		await _sec(2.0)
		var video: Node = _main.get_node_or_null("VideoPanel")
		if video and video.has_method("is_open") and bool(video.call("is_open")):
			await _sec(2.0)
			if video.has_method("_close"):
				video.call("_close")
		await _wait_narration()
		self.paused = false
	await _shot("01_intro")

	print("DEMO: shed supplies + first seed media")
	if save and save.has_method("set_flag"):
		save.set_flag("shed_tools_intro", true)
	_events().world_tapped.emit(farm.shed_center)
	await _sec(1.2)
	var db: SeedDB = _world.seed_db
	var seeds := db.available_seed_ids()
	var pick := "carrot" if seeds.has("carrot") else ("lettuce" if seeds.has("lettuce") else str(seeds[0]))
	if shed and shed.has_method("_on_tool_pressed"):
		shed.call("_on_tool_pressed", "seed")
		await _sec(0.8)
	if shed and shed.has_method("_on_seed_pressed"):
		shed.call("_on_seed_pressed", pick)
	await _sec(0.8)
	await _close_media_if_open()
	await _wait_narration()
	await _shot("02_seed_media")
	if shed and shed.has_method("close_shed"):
		shed.call("close_shed")
	await _sec(0.5)

	print("DEMO: plant whole bed — hold on seed at furrow cross")
	_mark("plant_seed", "seed on bed_0")
	_events().world_tapped.emit(farm.bed_centers.get("bed_0", farm.slot_world("bed_0", 0)))
	await _arrive_and_settle()
	await _wait_narration()
	await _focus_bed(farm, "bed_0", 2.4)
	await _sec(1.6)
	await _shot("03_planted_seed")

	var garden: GardenState = _world.garden
	print("DEMO: water → sprout / growing / grown + harvest star")
	if shed and shed.has_method("set_tool"):
		shed.call("set_tool", "water")
	await _grow_to_stage(garden, db, "bed_0", GardenState.STAGE_SPROUT)
	_mark("plant_sprout", "sprout pack")
	await _focus_bed(farm, "bed_0", 2.45)
	await _sec(1.8)
	await _shot("04_sprout")

	await _grow_to_stage(garden, db, "bed_0", GardenState.STAGE_GROWING)
	_mark("plant_growing", "growing pack")
	await _focus_bed(farm, "bed_0", 2.45)
	await _sec(1.8)
	await _shot("05_growing")

	await _grow_to_stage(garden, db, "bed_0", GardenState.STAGE_GROWN)
	_mark("plant_grown", "grown pack + harvest star")
	await _focus_bed(farm, "bed_0", 2.5)
	await _sec(2.2)
	await _shot("06_grown_star")

	## Hands-free examine: return tool, then tap bed → Examine tile.
	if shed and shed.has_method("clear_selection"):
		shed.call("clear_selection")
	_events().world_tapped.emit(farm.bed_centers.get("bed_0", farm.slot_world("bed_0", 0)))
	await _confirm_prompt_action("media")
	await _sec(1.0)
	await _close_media_if_open()
	await _wait_narration()
	await _shot("07_sprout_media")

	print("DEMO: fill every bed — a big beautiful garden")
	_mark("garden_full", "six beds planted")
	var variety: Array = db.available_seed_ids()
	var vi := 0
	for b in ["bed_1", "bed_2", "bed_3", "bed_4", "bed_5"]:
		var pid2 := str(variety[vi % variety.size()])
		vi += 1
		if garden.plant_bed(b, pid2):
			_events().plant_planted.emit(b, 0, pid2)
	for b in ["bed_1", "bed_2", "bed_3", "bed_4", "bed_5"]:
		await _grow_to_stage(garden, db, b, GardenState.STAGE_GROWN)
	## Overview of the planted yard.
	await _focus_overview(farm, Vector2(1.45, 1.45))
	await _sec(2.4)
	await _shot("08_beautiful_garden")

	print("DEMO: seasons with plants still on beds (trees + weather)")
	## Keep the full garden while seasons change so kids see both.
	for season_tag in ["summer", "fall", "winter"]:
		_mark("season_%s" % season_tag, "season tour")
		_world.call("advance_season")
		await _wait_narration()
		## Yard overview — ground tint + planted beds.
		await _focus_overview(farm, Vector2(1.4, 1.4))
		await _sec(1.6)
		await _shot("09_season_%s_yard" % season_tag)
		## Meadow trees close — seasonal foliage.
		await _focus_trees(farm, Vector2(1.85, 1.85))
		await _sec(2.0)
		await _shot("09b_season_%s_trees" % season_tag)
		## Weather / decor over the beds (rain / leaves / clear).
		await _focus_bed(farm, "bed_1", 1.75)
		await _sec(2.6)
		await _shot("09c_season_%s_fx" % season_tag)
		await _close_media_if_open()
		await _sec(0.4)

	print("DEMO: harvest ripe bed")
	_mark("harvest", "harvest bed_0")
	## Back to spring-ish clarity isn't required — harvest on current season.
	await _focus_bed(farm, "bed_0", 2.3)
	await _sec(0.8)
	_events().world_tapped.emit(farm.bed_centers.get("bed_0", farm.slot_world("bed_0", 0)))
	await _arrive_and_settle()
	await _confirm_prompt_action("harvest_confirm")
	await _wait_narration()
	await _close_media_if_open()
	await _shot("10_harvested")

	print("DEMO: animals — reveal tile + educational video")
	_mark("animals", "pen animals")
	var reveal: Node = _world.get("reveal_tile")
	var chick: Vector2 = farm.animal_positions.get("chicken_a", farm.fence_center)
	_events().world_tapped.emit(chick)
	await _wait_reveal_open(reveal)
	await _shot("11_animal_reveal")
	if reveal and reveal.has_method("is_open") and bool(reveal.call("is_open")):
		await _wait_reveal_narration(reveal)
		await _sec(0.6)
		if reveal.has_method("_on_tile_pressed"):
			reveal.call("_on_tile_pressed")
		await _sec(3.0)
		await _shot("12_animal_video")
		await _close_media_if_open()

	print("DEMO: bug catch — reveal tile + bug grid")
	_mark("bugs", "bug catch")
	var spawner: Node = _world.get("bug_spawner")
	if spawner and spawner.has_method("force_spawn") and _world.player:
		var near: Vector2 = _world.player.global_position + Vector2(64, 18)
		var bug: Node2D = spawner.call("force_spawn", "ladybug", near)
		if bug:
			await _sec(0.3)
			_events().world_tapped.emit(bug.global_position)
			await _wait_reveal_open(reveal)
			await _shot("13_bug_reveal")
			if reveal and reveal.has_method("is_open") and bool(reveal.call("is_open")):
				await _wait_reveal_narration(reveal)
				await _sec(0.6)
				if reveal.has_method("_on_tile_pressed"):
					reveal.call("_on_tile_pressed")
				await _sec(3.0)
				await _close_media_if_open()
			await _sec(1.2)
			await _shot("14_bug_grid")
			var bgrid: Node = _world.get("bug_grid")
			if bgrid and bgrid.has_method("is_open") and bool(bgrid.call("is_open")) and bgrid.has_method("close_grid"):
				bgrid.call("close_grid")
			await _sec(0.4)

	print("DEMO: hamburger library")
	_mark("library", "star menu")
	_events().hamburger_pressed.emit()
	await _sec(1.2)
	await _shot("15_concepts_tab")
	var menu: Node = _main.get_node_or_null("HamburgerUI")
	if menu and menu.has_method("_set_tab"):
		menu.call("_set_tab", "seeds")
		await _sec(1.0)
		await _shot("16_seeds_tab")
		menu.call("_set_tab", "concepts")
	if menu and menu.has_method("_on_concept"):
		menu.call("_on_concept", "01_seeds")
		await _wait_narration()
		menu.call("_on_concept", "01_seeds")
		await _sec(1.5)
		await _close_media_if_open()
	if menu and menu.has_method("is_open") and bool(menu.call("is_open")):
		_events().hamburger_pressed.emit()
	await _sec(0.8)

	print("DEMO: done")
	_mark("end", "playthrough complete")
	await _focus_overview(farm, Vector2(1.5, 1.5))
	await _sec(1.2)
	await _shot("17_end")
	_write_markers()
	await _sec(1.0)
	quit(0)

func _mark(id: String, note: String) -> void:
	_markers.append({"t": snappedf(_demo_t, 0.01), "id": id, "note": note})
	print("DEMO mark t=%.2f %s — %s" % [_demo_t, id, note])

func _write_markers() -> void:
	## res:// is game/; demo lives beside game under garden_explorer/docs/demo
	var game_dir := ProjectSettings.globalize_path("res://").rstrip("/")
	var path := game_dir.get_base_dir().path_join("docs/demo/playthrough_markers.json")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var payload := {
		"suite": "playthrough",
		"markers": _markers,
		"duration_s": snappedf(_demo_t, 0.01),
	}
	FileAccess.open(path, FileAccess.WRITE).store_string(JSON.stringify(payload, "\t"))
	print("DEMO markers → ", path)

func _cam() -> Camera2D:
	if _world and _world.get("camera"):
		return _world.camera as Camera2D
	return root.find_child("CameraFollow", true, false) as Camera2D

func _focus_bed(farm: FarmMap, bed_id: String, zoom: float) -> void:
	var cam := _cam()
	var cross: Vector2 = farm.bed_plot_cross(bed_id)
	if _world.player:
		_world.player.global_position = farm.nearest_walkable(farm.bed_centers[bed_id] + Vector2(0, 72))
		if _world.player.has_method("stop"):
			_world.player.call("stop")
		elif _world.player.has_method("_apply_player_depth"):
			_world.player.call("_apply_player_depth")
	if cam:
		cam.zoom = Vector2(zoom, zoom)
		cam.global_position = cross
		if cam.has_method("snap_to_target"):
			## Keep framing on the bed, not the player feet.
			cam.global_position = cross
	await _sec(0.15)

func _focus_overview(farm: FarmMap, zoom: Vector2) -> void:
	var cam := _cam()
	var mid: Vector2 = (farm.bed_centers["bed_1"] + farm.bed_centers["bed_4"]) * 0.5
	if _world.player:
		_world.player.global_position = farm.nearest_walkable(mid + Vector2(0, 96))
		if _world.player.has_method("stop"):
			_world.player.call("stop")
	if cam:
		cam.zoom = zoom
		cam.global_position = mid
	await _sec(0.15)

func _focus_trees(farm: FarmMap, zoom: Vector2) -> void:
	var cam := _cam()
	var focus := farm.spawn_world
	if farm._meadow_trees.size() > 0:
		var spr: Sprite2D = farm._meadow_trees[0] as Sprite2D
		if spr:
			focus = spr.global_position
	if _world.player:
		_world.player.global_position = farm.nearest_walkable(farm.spawn_world)
		if _world.player.has_method("stop"):
			_world.player.call("stop")
	if cam:
		cam.zoom = zoom
		cam.global_position = focus
	await _sec(0.15)

func _grow_to_stage(garden: GardenState, db: SeedDB, bed_id: String, target: String) -> void:
	for _i in 50:
		if garden.bed_stage(bed_id) == target:
			## Ensure PlantLayer / icons refresh for the camera hold.
			if _world.get("plant_layer") and _world.plant_layer.has_method("rebuild_all"):
				_world.plant_layer.rebuild_all()
			await _sec(0.2)
			return
		if garden.is_bed_empty(bed_id):
			return
		if garden.is_bed_thirsty(bed_id):
			garden.water_bed(bed_id, db)
		var s: Dictionary = garden.get_slot(bed_id, 0)
		s["stage_time"] = 999.0
		s["watered_stage"] = true
		s["thirsty"] = false
		garden.beds[bed_id][0] = s
		garden._sync_slots_from_lead(bed_id)
		garden._try_advance_bed(bed_id, db)
		await _sec(0.12)
	if garden.bed_stage(bed_id) != target and not garden.is_bed_empty(bed_id):
		var s2: Dictionary = garden.get_slot(bed_id, 0)
		s2["stage"] = target
		s2["thirsty"] = target != GardenState.STAGE_GROWN
		s2["watered_stage"] = true
		garden.beds[bed_id][0] = s2
		garden._sync_slots_from_lead(bed_id)
		if garden.has_signal("bed_changed"):
			garden.bed_changed.emit(bed_id)
		if _world.get("plant_layer") and _world.plant_layer.has_method("rebuild_all"):
			_world.plant_layer.rebuild_all()
		await _sec(0.2)

func _arrive_and_settle() -> void:
	var guard := 0
	while guard < 180:
		if _world.player and not bool(_world.player.get("moving")):
			break
		await _sec(0.1)
		guard += 1
	await _sec(0.45)

func _confirm_prompt_action(kind: String) -> void:
	var prompt: Node = _world.get("action_prompt")
	var guard := 0
	while guard < 150:
		if prompt and prompt.has_method("is_open") and bool(prompt.call("is_open")):
			break
		await _sec(0.1)
		guard += 1
	if prompt == null or not bool(prompt.call("is_open")):
		return
	var actions: Array = prompt.get("_actions")
	for a in actions:
		if str((a as Dictionary).get("kind", "")) == kind:
			prompt.call("_pick", a)
			return

func _close_media_if_open() -> void:
	for name in ["MediaPanel", "VideoPanel"]:
		var n: Node = _main.get_node_or_null(name)
		if n and n.has_method("is_open") and bool(n.call("is_open")):
			await _sec(2.2)
			if n.has_method("_close"):
				n.call("_close")
			self.paused = false
			await _sec(0.3)

func _wait_reveal_open(reveal: Node) -> void:
	var guard := 0
	while guard < 120:
		if reveal and reveal.has_method("is_open") and bool(reveal.call("is_open")):
			return
		await _sec(0.1)
		guard += 1

func _wait_reveal_narration(reveal: Node) -> void:
	var guard := 0
	while guard < 120:
		if not (reveal.has_method("is_narrating") and bool(reveal.call("is_narrating"))):
			return
		await _sec(0.1)
		guard += 1

func _wait_narration() -> void:
	var guard := 0
	while NarratorScript.blocks_movement() and guard < 120:
		await _sec(0.1)
		guard += 1
	await _sec(0.25)

func _shot(name: String) -> void:
	_shot_i += 1
	var dir := "res://docs/screenshots/playthrough"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var path := "%s/%02d_%s.png" % [dir, _shot_i, name]
	await process_frame
	await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	if img:
		img.save_png(ProjectSettings.globalize_path(path))
		print("DEMO shot → ", ProjectSettings.globalize_path(path))

func _sec(t: float) -> void:
	await create_timer(t, true, false, true).timeout
	_demo_t += t

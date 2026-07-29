extends SceneTree
## Full gameplay playthrough + screenshots for docs/demo.
##
##   DISPLAY=:1 godot --path game --fixed-fps 24 --disable-vsync \
##     --write-movie /tmp/garden_playthrough.avi \
##     -s res://tools/record_playthrough_demo.gd

const SpeakScript := preload("res://scripts/audio/Speak.gd")
const NarratorScript := preload("res://scripts/audio/Narrator.gd")

var _main: Node
var _world: Node2D
var _ev: Node
var _shot_i: int = 0

func _init() -> void:
	call_deferred("_run")

func _events() -> Node:
	if _ev == null:
		_ev = root.get_node_or_null("/root/Events")
	return _ev

func _run() -> void:
	root.get_viewport().size = Vector2i(1280, 600)
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
	## Skip the long first-open tools intro so the demo stays paced;
	## explainer VO covers the supplies flow.
	if save and save.has_method("set_flag"):
		save.set_flag("shed_tools_intro", true)
	_events().world_tapped.emit(farm.shed_center)
	await _sec(1.2)
	var db: SeedDB = _world.seed_db
	var seeds := db.available_seed_ids()
	var pick := "lettuce" if seeds.has("lettuce") else str(seeds[0])
	## Supplies modal → Seeds → pick crop (triggers first-seed media).
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

	print("DEMO: plant whole bed with one tap (seed tool auto-applies)")
	_events().world_tapped.emit(farm.bed_centers.get("bed_0", farm.slot_world("bed_0", 0)))
	await _arrive_and_settle()
	await _wait_narration()
	await _sec(0.5)
	await _shot("03_planted_thirst")

	print("DEMO: watering can → sprout")
	if shed and shed.has_method("set_tool"):
		shed.call("set_tool", "water")
	var garden: GardenState = _world.garden
	await _grow_to_stage(garden, db, "bed_0", 0, GardenState.STAGE_SPROUT)
	await _shot("04_sprout")
	## Hands-free examine: return tool, then tap bed → Examine tile.
	if shed and shed.has_method("clear_selection"):
		shed.call("clear_selection")
	_events().world_tapped.emit(farm.bed_centers.get("bed_0", farm.slot_world("bed_0", 0)))
	await _confirm_prompt_action("media")
	await _sec(1.0)
	await _close_media_if_open()
	await _wait_narration()
	await _shot("05_sprout_media")

	print("DEMO: fill every bed — a big beautiful garden")
	var variety: Array = db.available_seed_ids()
	var vi := 0
	for b in ["bed_1", "bed_2", "bed_3", "bed_4", "bed_5"]:
		var pid2 := str(variety[vi % variety.size()])
		vi += 1
		if garden.plant_bed(b, pid2):
			_events().plant_planted.emit(b, 0, pid2)
	## Walk to the middle of the garden and watch it bloom.
	_events().player_path_requested.emit(farm.nearest_walkable(farm.bed_centers.get("bed_1", Vector2.ZERO) + Vector2(0, 90)))
	for b in ["bed_1", "bed_2", "bed_3", "bed_4", "bed_5"]:
		await _grow_to_stage(garden, db, b, 0, GardenState.STAGE_GROWN)
	await _sec(1.0)
	await _shot("06a_beautiful_garden")

	print("DEMO: grow to harvest")
	await _grow_to_stage(garden, db, "bed_0", 0, GardenState.STAGE_GROWN)
	await _shot("06_grown_harvest_icon")
	_events().world_tapped.emit(farm.bed_centers.get("bed_0", farm.slot_world("bed_0", 0)))
	await _arrive_and_settle()
	await _confirm_prompt_action("harvest_confirm")
	await _wait_narration()
	await _close_media_if_open() ## first-harvest video
	await _shot("07_harvested")

	print("DEMO: animals — reveal tile + educational video")
	var reveal: Node = _world.get("reveal_tile")
	var chick: Vector2 = farm.animal_positions.get("chicken_a", farm.fence_center)
	_events().world_tapped.emit(chick)
	await _wait_reveal_open(reveal)      ## player walks over, then tile opens
	await _shot("08_animal_reveal")
	## Tap the reveal tile → launches the real animal documentary clip.
	if reveal and reveal.has_method("is_open") and bool(reveal.call("is_open")):
		await _wait_reveal_narration(reveal)
		await _sec(0.6)                  ## let the intro line be heard
		if reveal.has_method("_on_tile_pressed"):
			reveal.call("_on_tile_pressed")
		await _sec(3.0)
		await _shot("09_animal_video")
		await _close_media_if_open()

	print("DEMO: bug catch — reveal tile + bug grid")
	var spawner: Node = _world.get("bug_spawner")
	if spawner and spawner.has_method("force_spawn") and _world.player:
		var near: Vector2 = _world.player.global_position + Vector2(64, 18)
		var bug: Node2D = spawner.call("force_spawn", "ladybug", near)
		if bug:
			await _sec(0.3)
			_events().world_tapped.emit(bug.global_position)
			await _wait_reveal_open(reveal)
			await _shot("10_bug_reveal")
			if reveal and reveal.has_method("is_open") and bool(reveal.call("is_open")):
				await _wait_reveal_narration(reveal)
				await _sec(0.6)
				if reveal.has_method("_on_tile_pressed"):
					reveal.call("_on_tile_pressed")
				await _sec(3.0)
				await _close_media_if_open()
			## Bug grid celebrates the catch.
			await _sec(1.2)
			await _shot("11_bug_grid")
			var bgrid: Node = _world.get("bug_grid")
			if bgrid and bgrid.has_method("is_open") and bool(bgrid.call("is_open")) and bgrid.has_method("close_grid"):
				bgrid.call("close_grid")
			await _sec(0.4)

	print("DEMO: season card")
	_world.call("advance_season")
	await _wait_narration()
	await _shot("12_season")
	await _sec(3.0) ## season card holds 5s
	await _close_media_if_open()

	print("DEMO: hamburger library")
	_events().hamburger_pressed.emit()
	await _sec(1.2)
	await _shot("13_concepts_tab")
	var menu: Node = _main.get_node_or_null("HamburgerUI")
	if menu and menu.has_method("_set_tab"):
		menu.call("_set_tab", "seeds")
		await _sec(1.0)
		await _shot("14_seeds_tab")
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
	await _shot("15_end")
	await _sec(1.5)
	quit(0)

func _grow_to_stage(garden: GardenState, db: SeedDB, bed_id: String, slot: int, target: String) -> void:
	for _i in 50:
		var s: Dictionary = garden.get_slot(bed_id, slot)
		if str(s.get("stage", "")) == target or str(s.get("stage", "")) == GardenState.STAGE_GROWN and target == GardenState.STAGE_GROWN:
			if str(s.get("stage", "")) == target:
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
		await _sec(0.12)
		if str(garden.get_slot(bed_id, slot).get("stage", "")) == target:
			return

func _arrive_and_settle() -> void:
	## Wait for walk + auto tool apply (plant / harvest) to finish.
	var guard := 0
	while guard < 180:
		if _world.player and not bool(_world.player.get("moving")):
			break
		await _sec(0.1)
		guard += 1
	await _sec(0.45)

func _confirm_prompt_action(kind: String) -> void:
	## Wait for the walk-then-prompt flow, then pick the matching action tile.
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
	## Player must walk to the target before the reveal tile opens.
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

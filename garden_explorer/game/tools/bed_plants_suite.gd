extends SceneTree
## Bed + plant render suite — asserts furrow geometry, pack landings, stage art,
## and harvest star; writes agent PNGs under qa/out/bed_plants/<stamp>/.
##
##   ./qa/run_bed_plants_suite.sh
##   godot --path game -s res://tools/bed_plants_suite.gd

const VIEW := Vector2i(1280, 720)
const PLANT_ID := "carrot"

var _out_abs: String = ""
var _shot_i: int = 0
var _checks: Array = []
var _shots: Array = []

func _init() -> void:
	call_deferred("_run")

func _qa_root() -> String:
	var game_dir := ProjectSettings.globalize_path("res://").rstrip("/")
	return game_dir.get_base_dir().path_join("qa/out/bed_plants")

func _run() -> void:
	print("======== Garden Explorer BED PLANTS suite ========")
	root.get_viewport().size = VIEW
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	_out_abs = _qa_root().path_join(stamp)
	DirAccess.make_dir_recursive_absolute(_out_abs)

	_prep_save()
	var main: Node = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _settle(12)
	paused = false
	await _skip_intro(main)

	var world: Node = main.get_node_or_null("World")
	if world == null:
		_finish(false, "World missing")
		return
	var farm: FarmMap = world.get("farm_map") as FarmMap
	var player: Node2D = world.get("player") as Node2D
	var garden: GardenState = world.get("garden") as GardenState
	var seed_db: SeedDB = world.get("seed_db") as SeedDB
	var plant_layer: PlantLayer = world.get("plant_layer") as PlantLayer
	var sprites: FarmSprites = world.get("sprites") as FarmSprites
	if farm == null:
		farm = main.find_child("FarmMap", true, false) as FarmMap
	if plant_layer == null:
		plant_layer = main.find_child("PlantLayer", true, false) as PlantLayer
	if farm == null or player == null or garden == null or plant_layer == null:
		_finish(false, "FarmMap/Player/Garden/PlantLayer missing")
		return
	if sprites == null:
		sprites = FarmSprites.new()
		sprites.bootstrap()

	## Freeze clocks so stages stay put while we shoot.
	var clock: Node = world.get("season_clock") as Node
	if clock:
		clock.set("paused", true)

	_check_bed_geometry(farm)
	_check_pack_assets(sprites)
	await _shot_overview(player, farm, "00_beds_empty",
		"Six empty beds — furrow cross visible, soil inside wood lip, no plant SE spill")

	## Seed → four plot-sized sprites, true-centered on each plot (parent = cross).
	_check("plant_bed_api", garden.plant_bed("bed_1", PLANT_ID), "plant carrot on bed_1")
	await _settle(6)
	plant_layer.rebuild_all()
	await _settle(4)
	_check("stage_seed", garden.bed_stage("bed_1") == GardenState.STAGE_SEED, "stage=%s" % garden.bed_stage("bed_1"))
	_assert_bed_node(plant_layer, "bed_1", "seed", 4)
	await _shot_bed(player, farm, "bed_1", "01_seed_bed1",
		"Seed stage — four plot-sized seeds, true-centered on each furrow plot")

	## Sprout / growing / grown packs (four landings).
	for stage in [GardenState.STAGE_SPROUT, GardenState.STAGE_GROWING, GardenState.STAGE_GROWN]:
		_force_stage(garden, seed_db, "bed_1", stage)
		plant_layer.rebuild_all()
		await _settle(5)
		_check("stage_%s" % stage, garden.bed_stage("bed_1") == stage, "stage=%s" % garden.bed_stage("bed_1"))
		_assert_bed_node(plant_layer, "bed_1", stage, 1)
		var pack: Texture2D = sprites.bed_plant_pack_texture(PLANT_ID, stage)
		_check("pack_tex_%s" % stage, pack != null and pack.get_width() >= 64,
			"pack=%s" % (("null" if pack == null else "%dx%d" % [pack.get_width(), pack.get_height()])))
		var note := "Pack stage %s — four plant *feet* in furrow plots, not SE on the wood lip" % stage
		if stage == GardenState.STAGE_GROWN:
			note += "; harvest star hovers just above foliage (not covering roots)"
		await _shot_bed(player, farm, "bed_1", "02_%s_bed1" % stage, note)

	_check("harvestable_grown", garden.is_bed_harvestable("bed_1"), "grown bed harvestable")
	_assert_harvest_icon(plant_layer, "bed_1", true)

	## Multi-bed: different stages visible together.
	garden.plant_bed("bed_0", "lettuce")
	_force_stage(garden, seed_db, "bed_0", GardenState.STAGE_SPROUT)
	garden.plant_bed("bed_3", "radish")
	_force_stage(garden, seed_db, "bed_3", GardenState.STAGE_GROWING)
	garden.plant_bed("bed_4", "strawberry")
	_force_stage(garden, seed_db, "bed_4", GardenState.STAGE_GROWN)
	plant_layer.rebuild_all()
	await _settle(6)
	_check("multi_stages",
		garden.bed_stage("bed_0") == GardenState.STAGE_SPROUT \
		and garden.bed_stage("bed_3") == GardenState.STAGE_GROWING \
		and garden.bed_stage("bed_4") == GardenState.STAGE_GROWN,
		"b0=%s b3=%s b4=%s" % [
			garden.bed_stage("bed_0"), garden.bed_stage("bed_3"), garden.bed_stage("bed_4")])
	await _shot_overview(player, farm, "03_multi_beds",
		"Several beds planted — packs stay inside soil diamonds; beds don't paint over fence/path wrongly")

	## South bed close-up (depth vs path).
	await _shot_bed(player, farm, "bed_4", "04_grown_south_bed4",
		"South grown bed — plants above soil, star above pack, bed lip not covering foliage incorrectly")

	_finish(true, "")

func _check_bed_geometry(farm: FarmMap) -> void:
	_check("six_beds", farm.bed_count() == 6, "beds=%d" % farm.bed_count())
	for bed_id in ["bed_0", "bed_1", "bed_2", "bed_3", "bed_4", "bed_5"]:
		var cross: Vector2 = farm.bed_plot_cross(bed_id)
		var centers: Array = farm.plot_centers_raised(bed_id)
		var offs: Array = farm.plot_offsets_from_cross(bed_id)
		_check("%s_cross" % bed_id, cross != Vector2.ZERO, "cross=%s" % cross)
		_check("%s_four_plots" % bed_id, centers.size() == 4 and offs.size() == 4,
			"centers=%d offs=%d" % [centers.size(), offs.size()])
		if offs.size() == 4:
			var ok_span := true
			var detail_bits: Array = []
			for o in offs:
				var v: Vector2 = o
				var L := v.length()
				detail_bits.append("%.1f" % L)
				if L < 6.0 or L > 48.0:
					ok_span = false
			_check("%s_plot_span" % bed_id, ok_span, "offset_lens=[%s]" % ", ".join(detail_bits))
			## Offsets must average near zero (symmetric around cross).
			var acc := Vector2.ZERO
			for o2 in offs:
				acc += o2 as Vector2
			acc /= float(offs.size())
			_check("%s_offsets_balanced" % bed_id, acc.length() < 2.5, "mean=%s" % acc)

func _check_pack_assets(sprites: FarmSprites) -> void:
	var path := "res://assets/plants/bed_packs/offsets.json"
	_check("offsets_json", FileAccess.file_exists(path), path)
	if FileAccess.file_exists(path):
		var data = JSON.parse_string(FileAccess.get_file_as_string(path))
		_check("offsets_anchor_feet", typeof(data) == TYPE_DICTIONARY \
			and str(data.get("anchor", "")) == "landing_feet",
			"anchor=%s" % (data.get("anchor", "?") if typeof(data) == TYPE_DICTIONARY else "?"))
		if typeof(data) == TYPE_DICTIONARY:
			var offs: Variant = data.get("offsets_n_e_s_w", data.get("offsets_nw_ne_sw_se", []))
			_check("offsets_four", typeof(offs) == TYPE_ARRAY and offs.size() == 4,
				"count=%s" % (offs.size() if typeof(offs) == TYPE_ARRAY else -1))
			var hover: Variant = data.get("star_hover_y", {})
			_check("star_hover_meta", typeof(hover) == TYPE_DICTIONARY and hover.has("grown"),
				"hover=%s" % hover)
	for stage in ["sprout", "growing", "grown"]:
		var tex: Texture2D = sprites.bed_plant_pack_texture(PLANT_ID, stage)
		_check("asset_%s_%s" % [PLANT_ID, stage], tex != null, "missing pack png")

func _bed_plants_node(layer: PlantLayer, bed_id: String) -> Node2D:
	var node: Node2D = layer.get_node_or_null("BedPlants_%s" % bed_id) as Node2D
	if node:
		return node
	## Fallback: PlantLayer tracks live nodes in _beds.
	if layer.get("_beds") is Dictionary and (layer._beds as Dictionary).has(bed_id):
		return (layer._beds as Dictionary)[bed_id] as Node2D
	return null

func _assert_bed_node(layer: PlantLayer, bed_id: String, stage: String, expect_sprites: int) -> void:
	var node: Node2D = _bed_plants_node(layer, bed_id)
	_check("node_%s_%s" % [bed_id, stage], node != null and is_instance_valid(node),
		"BedPlants_%s present" % bed_id)
	if node == null:
		return
	var spr_n := 0
	var pack_like := false
	for c in node.get_children():
		if c is Sprite2D:
			spr_n += 1
			var spr := c as Sprite2D
			if spr.texture and spr.texture.get_width() >= 64:
				pack_like = true
				## Baked pack must sit on the cross (no SE nudge).
				_check("pack_pos_%s_%s" % [bed_id, stage],
					spr.position.length() < 3.0,
					"pack.pos=%s (want ~0)" % spr.position)
	if stage == GardenState.STAGE_SEED:
		_check("seed_sprite_count_%s" % bed_id, spr_n == expect_sprites, "sprites=%d want=%d" % [spr_n, expect_sprites])
		## Seeds must clear bed soil/furrows (building+2/+3), not sit under them.
		_check("seed_bias_above_furrow_%s" % bed_id,
			IsoUtil.BIAS_SEED > IsoUtil.BIAS_BUILDING + 3,
			"BIAS_SEED=%d furrow_band=%d" % [IsoUtil.BIAS_SEED, IsoUtil.BIAS_BUILDING + 3])
		## True-centered on seed plot centroids (no foot-anchor nudge).
		var offs: Array = []
		if layer.farm_map and layer.farm_map.has_method("plot_seed_offsets_from_cross"):
			offs = layer.farm_map.plot_seed_offsets_from_cross(bed_id)
		elif layer.farm_map and layer.farm_map.has_method("plot_offsets_from_cross"):
			offs = layer.farm_map.plot_offsets_from_cross(bed_id)
		var si := 0
		for c in node.get_children():
			if c is Sprite2D and si < offs.size():
				var want: Vector2 = offs[si]
				var got: Vector2 = (c as Sprite2D).position
				_check("seed_plot_center_%s_%d" % [bed_id, si],
					got.distance_to(want) < 1.5,
					"pos=%s want=%s" % [got, want])
				si += 1
	else:
		_check("pack_or_compose_%s_%s" % [bed_id, stage],
			pack_like or spr_n >= expect_sprites,
			"sprites=%d pack_like=%s" % [spr_n, pack_like])

func _assert_harvest_icon(layer: PlantLayer, bed_id: String, want: bool) -> void:
	var icon: Node2D = layer.get_node_or_null("BedIcon_%s" % bed_id) as Node2D
	if icon == null and layer.get("_bed_icons") is Dictionary \
			and (layer._bed_icons as Dictionary).has(bed_id):
		icon = (layer._bed_icons as Dictionary)[bed_id] as Node2D
	var have := icon != null and is_instance_valid(icon)
	_check("harvest_icon_%s" % bed_id, have == want,
		"icon=%s want=%s" % [have, want])
	if have and want:
		## Star should sit north of the cross (negative Y), not on the soil.
		_check("star_north_of_cross_%s" % bed_id, icon.position.y < -20.0,
			"icon.y=%.1f" % icon.position.y)
		_check("star_has_child_%s" % bed_id, icon.get_child_count() >= 1,
			"children=%d" % icon.get_child_count())

func _force_stage(garden: GardenState, db: SeedDB, bed_id: String, target: String) -> void:
	for _i in 16:
		if garden.bed_stage(bed_id) == target:
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
	## If still short of target, hard-set (suite needs a stable visual).
	if garden.bed_stage(bed_id) != target and not garden.is_bed_empty(bed_id):
		var s2: Dictionary = garden.get_slot(bed_id, 0)
		s2["stage"] = target
		s2["thirsty"] = target != GardenState.STAGE_GROWN
		s2["watered_stage"] = true
		garden.beds[bed_id][0] = s2
		garden._sync_slots_from_lead(bed_id)
		if garden.has_signal("bed_changed"):
			garden.bed_changed.emit(bed_id)
		elif garden.has_signal("changed"):
			garden.changed.emit(bed_id, 0)

func _shot_overview(player: Node2D, farm: FarmMap, id: String, note: String) -> void:
	var mid: Vector2 = (farm.bed_centers["bed_1"] + farm.bed_centers["bed_4"]) * 0.5
	player.global_position = farm.nearest_walkable(mid + Vector2(0, 90))
	if player.has_method("stop"):
		player.call("stop")
	elif player.has_method("_apply_player_depth"):
		player.call("_apply_player_depth")
	await _settle(4)
	_aim_cam(player, mid, Vector2(1.55, 1.55))
	await _settle(5)
	await _save_shot(id, note, {"focus": "beds_overview"})

func _shot_bed(player: Node2D, farm: FarmMap, bed_id: String, id: String, note: String) -> void:
	var cross: Vector2 = farm.bed_plot_cross(bed_id)
	var stand: Vector2 = farm.nearest_walkable(farm.bed_centers[bed_id] + Vector2(0, 70))
	player.global_position = stand
	if player.has_method("stop"):
		player.call("stop")
	elif player.has_method("_apply_player_depth"):
		player.call("_apply_player_depth")
	await _settle(4)
	_aim_cam(player, cross, Vector2(2.35, 2.35))
	await _settle(5)
	## South lip: player must draw above this bed's wood + pack.
	if id.begins_with("04_grown_south"):
		var bed_node := farm.get_node_or_null(bed_id) as CanvasItem
		var bed_z := bed_node.z_index if bed_node else -9999
		var pn := _bed_plants_node(
			player.get_parent().get_node_or_null("PlantLayer") as PlantLayer, bed_id)
		var plant_z := (pn as CanvasItem).z_index if pn is CanvasItem else -9999
		var need := maxi(bed_z + 3, plant_z)
		_check("south_lip_in_front_%s" % bed_id, player.z_index > need,
			"player.z=%d need>%d bed=%d plant=%d" % [player.z_index, need, bed_z, plant_z])
	await _save_shot(id, note, {"bed": bed_id, "cross": {"x": cross.x, "y": cross.y}})

func _aim_cam(player: Node2D, focus: Vector2, zoom: Vector2) -> void:
	var cam := player.get_parent().get_node_or_null("CameraFollow") as Camera2D
	if cam == null:
		cam = root.find_child("CameraFollow", true, false) as Camera2D
	if cam == null:
		return
	if cam.has_method("set_follow_target"):
		cam.call("set_follow_target", player)
	cam.zoom = zoom
	cam.global_position = focus

func _save_shot(id: String, note: String, meta: Dictionary = {}) -> void:
	await process_frame
	await process_frame
	var file := "%02d_%s.png" % [_shot_i, id]
	var img: Image = root.get_viewport().get_texture().get_image()
	if img:
		img.save_png(_out_abs.path_join(file))
	var entry := {"file": file, "id": id, "note": note}
	for k in meta.keys():
		entry[k] = meta[k]
	_shots.append(entry)
	_shot_i += 1
	print(" shot ", file, " — ", note)

func _prep_save() -> void:
	var save := root.get_node_or_null("/root/Save")
	if save:
		if save.has_method("clear_all"):
			save.clear_all()
		if save.has_method("set_intro_completed"):
			save.set_intro_completed(true)
		if save.has_method("set_flag"):
			save.set_flag("shed_tools_intro", true)
	var ig := root.get_node_or_null("/root/IdleGuard")
	if ig and ig.has_method("set_active"):
		ig.set_active(false)

func _skip_intro(main: Node) -> void:
	var intro: Node = main.get_node_or_null("IntroPanel")
	if intro and intro.has_method("_on_start"):
		intro.visible = true
		if intro.get("_panel") != null:
			intro._panel.visible = true
		intro.call("_on_start")
		await _settle(6)
		var video: Node = main.get_node_or_null("VideoPanel")
		if video and video.has_method("is_open") and bool(video.call("is_open")) and video.has_method("_close"):
			video.call("_close")
		intro.visible = false
	paused = false
	await _settle(4)

func _settle(frames: int) -> void:
	if paused:
		paused = false
	for _i in frames:
		await process_frame

func _check(name: String, ok: bool, detail: String) -> void:
	_checks.append({"name": name, "ok": ok, "detail": detail})
	print(("OK  " if ok else "FAIL"), " ", name, " — ", detail)

func _finish(ok_setup: bool, fatal: String) -> void:
	var fails := 0
	for c in _checks:
		if not c.get("ok", false):
			fails += 1
	if not ok_setup:
		fails += 1
	var report := {
		"suite": "bed_plants",
		"stamp": _out_abs.get_file(),
		"viewport": {"w": VIEW.x, "h": VIEW.y},
		"passed": _checks.size() - fails + (0 if ok_setup else 0),
		"failed": fails,
		"checks": _checks,
		"shots": _shots,
		"agent_brief": _agent_brief(),
	}
	if fatal != "":
		report["fatal"] = fatal
		print("FATAL ", fatal)
	FileAccess.open(_out_abs.path_join("report.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("BED PLANTS suite → %s (failed=%d shots=%d)" % [_out_abs, fails, _shot_i])
	quit(1 if fails > 0 else 0)

func _agent_brief() -> String:
	return """Bed/plant render suite. Read every PNG. Empty beds: furrow cross splits soil into four plots; wood lip clear. Seed: four plot-sized sprites true-centered on each furrow plot (parent at bed cross). Sprout/growing/grown: four plants whose feet sit inside each furrow plot (not SE-shifted onto the wood). Grown: harvest star floats just above foliage. Multi-bed shot: packs stay on soil; no bed painting over the dirt path/fence wrongly. Any FAIL in checks[] is a regression — fix production code, then re-run."""

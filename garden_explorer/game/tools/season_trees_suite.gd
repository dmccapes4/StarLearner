extends SceneTree
## Trees + seasonal FX suite — meadow trees and season decor/weather for each
## season, with agent PNGs under qa/out/season_trees/<stamp>/.
##
##   ./qa/run_season_trees_suite.sh
##   godot --path game -s res://tools/season_trees_suite.gd

const VIEW := Vector2i(1280, 720)
const SEASONS := ["spring", "summer", "fall", "winter"]

var _out_abs: String = ""
var _shot_i: int = 0
var _checks: Array = []
var _shots: Array = []
var _farm_cached: FarmMap

func _init() -> void:
	call_deferred("_run")

func _qa_root() -> String:
	var game_dir := ProjectSettings.globalize_path("res://").rstrip("/")
	return game_dir.get_base_dir().path_join("qa/out/season_trees")

func _run() -> void:
	print("======== Garden Explorer SEASON TREES suite ========")
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
	var sprites: FarmSprites = world.get("sprites") as FarmSprites
	if farm == null:
		farm = main.find_child("FarmMap", true, false) as FarmMap
	if player == null:
		player = main.find_child("Player", true, false) as Node2D
	if farm == null or player == null:
		_finish(false, "FarmMap/Player missing")
		return
	if sprites == null:
		sprites = farm.sprites if farm.sprites else FarmSprites.new()
		if sprites and not sprites.mana_ready and sprites.has_method("bootstrap"):
			sprites.bootstrap()

	var clock: Node = world.get("season_clock") as Node
	if clock:
		clock.set("paused", true)

	_check_tree_assets(sprites)
	_check_meadow_placement(farm)

	var tree_sigs: Dictionary = {} ## season -> first tree atlas sig
	for sid in SEASONS:
		farm.apply_season_tint(sid)
		## Let wind timer + weather spawn a few frames.
		await _settle(8)
		await create_timer(1.35).timeout
		await _settle(6)

		_check_season_state(farm, sprites, sid, tree_sigs)
		await _shot_season_yard(player, farm, sid)
		await _shot_season_trees(player, farm, sid)
		await _shot_season_weather(player, farm, sid)

	## Tree art must change across seasons (not stuck on one atlas row).
	var unique := {}
	for sid in tree_sigs.keys():
		unique[str(tree_sigs[sid])] = true
	_check("trees_seasonal_art", unique.size() >= 3,
		"distinct_rows=%d (%s)" % [unique.size(), tree_sigs])

	_finish(true, "")

func _check_tree_assets(sprites: FarmSprites) -> void:
	_check("sprites_ready", sprites != null, "FarmSprites")
	if sprites == null:
		return
	for sid in SEASONS:
		for variant in FarmSprites.TREE_VARIANTS:
			var tex: Texture2D = sprites.tree_texture(sid, variant, 0)
			_check("tree_tex_%s_%s" % [sid, variant], tex != null,
				("%dx%d" % [tex.get_width(), tex.get_height()]) if tex else "missing")
	_check("raindrop_tex", sprites.raindrop_texture() != null, "rain FX")
	_check("leaf_spin_tex", not sprites.leaf_spin_frames().is_empty(), "leaf spin FX")

func _check_meadow_placement(farm: FarmMap) -> void:
	var trees: Array = farm._meadow_trees
	_check("meadow_tree_count", trees.size() >= 8, "trees=%d (want ≥8)" % trees.size())
	var outside := 0
	var with_tex := 0
	for spr in trees:
		if spr == null or not is_instance_valid(spr):
			continue
		if spr is Sprite2D and (spr as Sprite2D).texture != null:
			with_tex += 1
		var feet_y := float(spr.get_meta("tree_feet_y", spr.position.y))
		## Approximate feet world from meta; placement used tile→world.
		var approx := Vector2(spr.position.x, feet_y)
		if farm.farm_yard_poly.is_empty() or not IsoUtil.point_in_polygon(approx, farm.farm_yard_poly):
			outside += 1
	_check("trees_have_textures", with_tex == trees.size() and with_tex > 0,
		"textured=%d / %d" % [with_tex, trees.size()])
	_check("trees_outside_yard", outside == trees.size(),
		"outside=%d / %d" % [outside, trees.size()])

func _check_season_state(farm: FarmMap, sprites: FarmSprites, sid: String, tree_sigs: Dictionary) -> void:
	_farm_cached = farm
	var ground := farm.get_node_or_null("Ground") as Polygon2D
	_check("%s_ground_modulate" % sid, ground != null and ground.modulate != Color(1, 1, 1, 1),
		"modulate=%s" % (ground.modulate if ground else "?"))

	var decor := farm.get_node_or_null("SeasonDecor") as Node2D
	var weather := farm.get_node_or_null("SeasonWeather") as Node
	match sid:
		"spring":
			_check("spring_flowers", decor != null and decor.get_child_count() >= 40,
				"decor_children=%d (yard+pen)" % (decor.get_child_count() if decor else -1))
			_check("spring_no_weather", weather == null or int(weather.get("mode")) == 0,
				"weather=%s" % weather)
		"summer":
			_check("summer_clear_sky", weather == null or int(weather.get("mode")) == 0,
				"weather=%s" % weather)
			_check("summer_decor_quiet", decor == null or decor.get_child_count() == 0,
				"decor_children=%d" % (decor.get_child_count() if decor else -1))
		"fall":
			_check("fall_ground_leaves", decor != null and decor.get_child_count() >= 40,
				"decor_children=%d (yard+pen)" % (decor.get_child_count() if decor else -1))
			_check("fall_leaf_weather", weather != null and int(weather.get("mode")) == 2,
				"mode=%s (want LEAVES=2)" % (weather.get("mode") if weather else null))
			_check_pen_weather_landings(weather, "fall")
		"winter":
			_check("winter_rain_weather", weather != null and int(weather.get("mode")) == 1,
				"mode=%s (want RAIN=1)" % (weather.get("mode") if weather else null))
			_check_pen_weather_landings(weather, "winter")
		_:
			pass

	## First meadow tree should show this season's atlas row (wind frame may tick).
	if farm._meadow_trees.size() > 0:
		var spr: Sprite2D = farm._meadow_trees[0] as Sprite2D
		var row := _atlas_row(spr.texture) if spr else -1
		tree_sigs[sid] = row
		var variant := str(spr.get_meta("tree_variant", "med")) if spr else "med"
		var expect0: Texture2D = sprites.tree_texture(sid, variant, 0)
		var expect1: Texture2D = sprites.tree_texture(sid, variant, 1)
		var ok_row := row >= 0 and (row == _atlas_row(expect0) or row == _atlas_row(expect1))
		_check("%s_tree_matches_season" % sid, ok_row,
			"row=%s expect=%s|%s" % [row, _atlas_row(expect0), _atlas_row(expect1)])

func _check_pen_weather_landings(weather: Node, sid: String) -> void:
	if weather == null or _farm_cached == null or not (weather.get("_landings") is Array):
		_check("%s_pen_landings" % sid, false, "no landings")
		return
	var lands: Array = weather._landings
	var pen_n := 0
	for land in lands:
		var pos: Vector2 = (land as Dictionary).get("pos", Vector2.ZERO)
		if _farm_cached.in_pen(pos):
			pen_n += 1
	_check("%s_pen_landings" % sid, pen_n >= 8, "pen_landings=%d / %d" % [pen_n, lands.size()])

func _atlas_row(tex: Texture2D) -> int:
	if tex is AtlasTexture:
		return int((tex as AtlasTexture).region.position.y)
	return -1

func _tex_sig(tex: Texture2D) -> String:
	if tex == null:
		return "null"
	if tex is AtlasTexture:
		var a := tex as AtlasTexture
		return "atlas:%s:%s" % [a.region.position, a.region.size]
	return "tex:%dx%d:%s" % [tex.get_width(), tex.get_height(), tex.resource_path]

func _shot_season_yard(player: Node2D, farm: FarmMap, sid: String) -> void:
	player.global_position = farm.nearest_walkable(farm.spawn_world)
	if player.has_method("stop"):
		player.call("stop")
	await _settle(3)
	_aim_cam(player, farm.spawn_world, Vector2(1.35, 1.35))
	await _settle(4)
	await _save_shot("%s_yard" % sid,
		"%s yard overview — ground tint, meadow trees around fence, season FX readable" % sid,
		{"season": sid, "view": "yard"})

func _shot_season_trees(player: Node2D, farm: FarmMap, sid: String) -> void:
	if farm._meadow_trees.is_empty():
		return
	## Frame the south fence line — where tall meadow canopies should kiss the rails.
	var sw := IsoUtil.tile_to_world(Vector2(farm._yard_min.x, farm._yard_max.y))
	var se := IsoUtil.tile_to_world(farm._yard_max)
	var focus: Vector2 = (sw + se) * 0.5 + Vector2(-40, 24)
	var stand := farm.nearest_walkable(focus + Vector2(0, -40))
	player.global_position = stand
	if player.has_method("stop"):
		player.call("stop")
	await _settle(3)
	_aim_cam(player, focus, Vector2(1.7, 1.7))
	await _settle(4)
	await _save_shot("%s_trees" % sid,
		"%s south meadow trees — canopies near/overlapping fence bottom (bush-like tuck), seasonal foliage" % sid,
		{"season": sid, "view": "trees"})

func _shot_season_weather(player: Node2D, farm: FarmMap, sid: String) -> void:
	## Frame the yard center so rain/leaves/flowers are visible over beds.
	var focus: Vector2 = farm.bed_centers.get("bed_1", farm.spawn_world)
	player.global_position = farm.nearest_walkable(focus + Vector2(0, 80))
	if player.has_method("stop"):
		player.call("stop")
	await _settle(3)
	_aim_cam(player, focus, Vector2(1.7, 1.7))
	await _settle(4)
	var note := "%s FX close — " % sid
	match sid:
		"spring":
			note += "ground flowers; no rain/leaf storm"
		"summer":
			note += "clear bright yard; no weather overlay"
		"fall":
			note += "falling/resting leaves above soil; ground leaf decals"
		"winter":
			note += "rain with mapped landings/splashes above beds"
		_:
			note += "season FX"
	await _save_shot("%s_fx" % sid, note, {"season": sid, "view": "fx"})

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
		"suite": "season_trees",
		"stamp": _out_abs.get_file(),
		"viewport": {"w": VIEW.x, "h": VIEW.y},
		"failed": fails,
		"checks": _checks,
		"shots": _shots,
		"agent_brief": _agent_brief(),
	}
	if fatal != "":
		report["fatal"] = fatal
		print("FATAL ", fatal)
	FileAccess.open(_out_abs.path_join("report.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("SEASON TREES suite → %s (failed=%d shots=%d)" % [_out_abs, fails, _shot_i])
	quit(1 if fails > 0 else 0)

func _agent_brief() -> String:
	return """Season/trees suite. For each season read yard, trees, and fx PNGs. Trees: horizontal canopies outside the fence; foliage must change spring→summer→fall→winter. Spring: flowers, no storm. Summer: bright clear yard. Fall: ground leaves + falling leaves. Winter: rain with landings/splashes over beds (not a free screen snow of ignore-depth particles). FAIL checks[] are regressions — fix FarmMap/SeasonWeather/FarmSprites, re-run."""

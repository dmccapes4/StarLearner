extends Node2D
## Farm world: map + player + garden + seasons + animals.

const SeasonClockScript := preload("res://scripts/sim/SeasonClock.gd")
const GoldOutlineScript := preload("res://scripts/ui/GoldOutline.gd")
const StarProgressScript := preload("res://scripts/sim/StarProgress.gd")
const SpeakScript := preload("res://scripts/audio/Speak.gd")

@onready var farm_map: FarmMap = $FarmMap
@onready var player: Player = $Player
@onready var camera: CameraFollow = $CameraFollow
@onready var tap_marker: Node2D = $TapMarker

const StarDBScript := preload("res://scripts/content/StarDB.gd")

var seed_db: SeedDB = SeedDB.new()
var star_db = StarDBScript.new()
var progress: RefCounted
var garden: GardenState = GardenState.new()
var sprites: FarmSprites = FarmSprites.new()
var plant_layer: PlantLayer
var season_clock: Node
var gold_outline: Node2D
var shed_ui: Node
var tool_bar: Node
var stage_media: Node
var season_hud: Node
var star_menu: Node
var harvest_totals: Dictionary = {} ## plant_id -> int
var tool_id: String = "water"
var action_prompt: Node
## Pending interactable: walk there first, then show ActionPrompt.
var _pending: Dictionary = {}

var _ripple_left: float = 0.0
var _guide_return_left: float = 0.0

const ANIMAL_LINES := {
	"chicken_a": "Cluck cluck! I'm pecking for seeds.",
	"chicken_b": "Hello! Chickens love a sunny garden.",
	"rabbit": "Hop hop! I like crunchy carrots and lettuce.",
}

func _ready() -> void:
	seed_db.load_all()
	star_db.load_all()
	progress = StarProgressScript.new()
	progress.setup(star_db, _save())
	progress.bind_events(Events)
	sprites.bootstrap()
	if sprites.has_method("set_seed_db"):
		sprites.set_seed_db(seed_db)
	if farm_map == null:
		farm_map = FarmMap.new()
		farm_map.name = "FarmMap"
		add_child(farm_map)
	farm_map.set_sprites(sprites)
	farm_map.build_from_file()
	garden.setup(farm_map.bed_ids(), int(farm_map.data.get("slots_per_bed", 4)))
	_restore_from_save()
	if not garden.stage_advanced.is_connected(_on_stage_advanced):
		garden.stage_advanced.connect(_on_stage_advanced)
	if not garden.changed.is_connected(_on_garden_changed):
		garden.changed.connect(_on_garden_changed)

	plant_layer = PlantLayer.new()
	plant_layer.name = "PlantLayer"
	add_child(plant_layer)
	plant_layer.setup(farm_map, garden, sprites, seed_db)

	season_clock = SeasonClockScript.new()
	season_clock.name = "SeasonClock"
	add_child(season_clock)
	var dur := _cfg_season_duration()
	season_clock.setup(seed_db, dur if dur > 0.0 else -1.0)
	var save := _save()
	if save:
		seed_db.set_season(str(save.season_id))
		season_clock.elapsed = float(save.season_elapsed)
	if not season_clock.season_tick.is_connected(_on_season_tick):
		season_clock.season_tick.connect(_on_season_tick)

	gold_outline = GoldOutlineScript.new()
	gold_outline.name = "GoldOutline"
	add_child(gold_outline)

	if player == null:
		player = Player.new()
		player.name = "Player"
		add_child(player)
	player.apply_sprites(sprites)
	player.place_at(farm_map.spawn_world)
	if camera:
		camera.set_follow_target(player)
		if camera.has_method("set_world_limits"):
			camera.set_world_limits(farm_map.meadow_aabb())
		camera.snap_to_target()

	farm_map.apply_season_tint(seed_db.current_season)
	call_deferred("_bind_ui")

	if not Events.world_tapped.is_connected(_on_world_tapped):
		Events.world_tapped.connect(_on_world_tapped)
	if not Events.player_arrived.is_connected(_on_player_arrived):
		Events.player_arrived.connect(_on_player_arrived)
	if not Events.seed_selected.is_connected(_on_seed_selected):
		Events.seed_selected.connect(_on_seed_selected)
	if not Events.seed_cleared.is_connected(_on_seed_cleared):
		Events.seed_cleared.connect(_on_seed_cleared)
	if not Events.star_reveal_requested.is_connected(_on_star_reveal_requested):
		Events.star_reveal_requested.connect(_on_star_reveal_requested)

func _bind_ui() -> void:
	shed_ui = get_tree().get_first_node_in_group("shed_ui")
	if shed_ui and shed_ui.has_method("setup"):
		shed_ui.call("setup", seed_db, sprites)
		if shed_ui.has_method("set_harvest_totals"):
			shed_ui.call("set_harvest_totals", harvest_totals)
	tool_bar = get_tree().get_first_node_in_group("tool_bar")
	if tool_bar and tool_bar.has_method("set_tool"):
		tool_bar.call("set_tool", tool_id, false)
	stage_media = get_tree().get_first_node_in_group("stage_media")
	if stage_media and stage_media.has_method("setup"):
		stage_media.call("setup", seed_db, sprites)
	season_hud = get_tree().get_first_node_in_group("season_hud")
	_sync_season_hud(false)
	star_menu = get_tree().get_first_node_in_group("star_menu")
	if star_menu and star_menu.has_method("setup"):
		star_menu.call("setup", star_db, progress, seed_db)
	var intro := get_tree().get_first_node_in_group("intro_panel")
	if intro and intro.has_method("setup"):
		intro.call("setup", star_db)
	action_prompt = get_tree().get_first_node_in_group("action_prompt")
	if action_prompt and action_prompt.has_method("setup"):
		action_prompt.call("setup", sprites)
		if action_prompt.has_signal("confirmed") and not action_prompt.confirmed.is_connected(_on_action_confirmed):
			action_prompt.confirmed.connect(_on_action_confirmed)
		if action_prompt.has_signal("cancelled") and not action_prompt.cancelled.is_connected(_on_action_cancelled):
			action_prompt.cancelled.connect(_on_action_cancelled)

func set_tool(id: String) -> void:
	tool_id = id
	if tool_bar and tool_bar.has_method("set_tool"):
		tool_bar.call("set_tool", id)
	else:
		Events.tool_changed.emit(id)
	var save := _save()
	if save and save.has_method("set_tool"):
		save.set_tool(id)

func advance_season() -> String:
	## Test / debug hook — same path as the wall-clock timer.
	if season_clock:
		return season_clock.force_advance()
	return ""

func _on_seed_selected(plant_id: String) -> void:
	## First time a seed type is collected → seed media (discover).
	_offer_plant_media(plant_id, "seed", true)

func _on_seed_cleared() -> void:
	pass

func _process(delta: float) -> void:
	if garden and seed_db:
		garden.tick(delta, seed_db)
	if tap_marker and _ripple_left > 0.0:
		_ripple_left -= delta
		var a := clampf(_ripple_left / Config.tap_ripple_sec, 0.0, 1.0)
		tap_marker.modulate.a = a
		tap_marker.scale = Vector2.ONE * (1.0 + (1.0 - a) * 0.8)
		if _ripple_left <= 0.0:
			tap_marker.visible = false
	if _guide_return_left > 0.0:
		_guide_return_left -= delta
		if _guide_return_left <= 0.0 and camera and camera.has_method("resume_follow"):
			camera.resume_follow(player)

func _on_world_tapped(world_pos: Vector2) -> void:
	_show_ripple(world_pos)
	if action_prompt and action_prompt.has_method("is_open") and bool(action_prompt.call("is_open")):
		return
	if shed_ui and shed_ui.has_method("is_open") and shed_ui.call("is_open"):
		return
	var zone := farm_map.zone_at(world_pos)
	if zone.is_empty():
		## Tap = navigate (immersive multi-tap walks).
		_pending.clear()
		if not farm_map.is_blocked(world_pos):
			Events.player_path_requested.emit(world_pos)
		else:
			Events.player_path_requested.emit(farm_map.nearest_walkable(world_pos))
		return
	var kind := str(zone.get("kind", ""))
	var zid := str(zone.get("id", ""))
	Events.zone_tapped.emit(zid, kind)
	## Walk to the interactable first; action tile opens on arrive.
	_queue_interact(kind, zid, world_pos)

func _queue_interact(kind: String, zid: String, world_pos: Vector2) -> void:
	var approach := world_pos
	var slot := -1
	match kind:
		"shed":
			approach = farm_map.nearest_walkable(farm_map.shed_center)
		"bed":
			slot = farm_map.nearest_slot(zid, world_pos)
			approach = farm_map.nearest_walkable(farm_map.slot_world(zid, slot))
		"fence":
			approach = farm_map.nearest_walkable(farm_map.fence_center)
			var near := farm_map.animal_at(world_pos, _cfg_animal_radius() * 1.6)
			if not near.is_empty():
				kind = "animal"
				zid = near
				approach = farm_map.nearest_walkable(farm_map.animal_positions.get(near, farm_map.fence_center))
		"animal":
			approach = farm_map.nearest_walkable(farm_map.animal_positions.get(zid, farm_map.fence_center))
		_:
			approach = farm_map.nearest_walkable(world_pos)
	_pending = {
		"kind": kind,
		"id": zid,
		"slot": slot,
		"approach": approach,
		"tap": world_pos,
	}
	## Already close enough → prompt immediately.
	if player and player.global_position.distance_to(approach) <= Config.get_interact_arrive_eps():
		_open_pending_prompt()
	else:
		Events.player_path_requested.emit(approach)

func _on_player_arrived() -> void:
	if _pending.is_empty():
		return
	var approach: Vector2 = _pending.get("approach", Vector2.ZERO)
	if player and player.global_position.distance_to(approach) > Config.get_interact_arrive_eps() * 1.5:
		return
	_open_pending_prompt()

func _open_pending_prompt() -> void:
	if _pending.is_empty() or action_prompt == null:
		return
	var action := _build_action_for_pending()
	if action.is_empty():
		_pending.clear()
		return
	action_prompt.call("show_action", action)

func _build_action_for_pending() -> Dictionary:
	var kind := str(_pending.get("kind", ""))
	var zid := str(_pending.get("id", ""))
	var slot := int(_pending.get("slot", -1))
	match kind:
		"shed":
			return {
				"kind": "open_shed",
				"label": "Open shed",
				"narration": "Open the shed to pick a seed.",
			}
		"animal":
			return {
				"kind": "pet_animal",
				"id": zid,
				"label": "Say hi",
				"narration": str(ANIMAL_LINES.get(zid, "Hello, little friend!")),
			}
		"fence":
			return {
				"kind": "look_animals",
				"label": "Animals",
				"narration": "Tap a chicken or rabbit to say hi.",
			}
		"bed":
			return _build_bed_action(zid, slot)
		_:
			return {}

func _build_bed_action(bed_id: String, slot: int) -> Dictionary:
	if slot < 0:
		slot = 0
	var held := ""
	if shed_ui and shed_ui.has_method("selected_seed"):
		held = str(shed_ui.call("selected_seed"))
	var tool := _current_tool()
	if garden.is_empty(bed_id, slot):
		if held.is_empty():
			SpeakScript.line("Pick a seed at the shed first.")
			return {}
		var pname := seed_db.display_name(held)
		return {
			"kind": "plant",
			"bed_id": bed_id,
			"slot": slot,
			"plant_id": held,
			"label": "Plant %s" % pname,
			"narration": "Plant the %s seed here?" % pname,
		}
	var st := garden.get_slot(bed_id, slot)
	var stage := str(st.get("stage", ""))
	var pid := str(st.get("plant_id", ""))
	var pname := seed_db.display_name(pid)
	var awaiting := str(st.get("awaiting_media", ""))
	if awaiting == GardenState.STAGE_SPROUT or awaiting == GardenState.STAGE_GROWN:
		return {
			"kind": "media",
			"bed_id": bed_id,
			"slot": slot,
			"plant_id": pid,
			"media_kind": awaiting,
			"label": "Look at %s" % pname,
			"narration": "Look at the %s!" % pname,
		}
	if tool == "uproot":
		return {
			"kind": "uproot",
			"bed_id": bed_id,
			"slot": slot,
			"plant_id": pid,
			"label": "Uproot",
			"narration": "Pull out the %s?" % pname,
		}
	if stage == GardenState.STAGE_GROWN and tool != "water":
		return {
			"kind": "harvest",
			"bed_id": bed_id,
			"slot": slot,
			"plant_id": pid,
			"label": "Harvest",
			"narration": "Harvest the %s?" % pname,
		}
	if tool == "harvest":
		if stage == GardenState.STAGE_GROWN:
			return {
				"kind": "harvest",
				"bed_id": bed_id,
				"slot": slot,
				"plant_id": pid,
				"label": "Harvest",
				"narration": "Harvest the %s?" % pname,
			}
		SpeakScript.line("Not ready to harvest yet.")
		return {}
	## Default: water
	if bool(st.get("thirsty", false)):
		return {
			"kind": "water",
			"bed_id": bed_id,
			"slot": slot,
			"plant_id": pid,
			"label": "Water",
			"narration": "Water the %s?" % pname,
		}
	SpeakScript.line("The %s is not thirsty yet." % pname)
	return {}

func _on_action_cancelled() -> void:
	_pending.clear()

func _on_action_confirmed(action: Dictionary) -> void:
	_pending.clear()
	var kind := str(action.get("kind", ""))
	match kind:
		"open_shed":
			if shed_ui and shed_ui.has_method("open_shed"):
				shed_ui.call("open_shed")
				print("Garden Explorer: open shed (%s)" % seed_db.current_season)
		"pet_animal":
			var aid := str(action.get("id", ""))
			Events.animal_tapped.emit(aid)
		"look_animals":
			pass
		"plant":
			_do_plant(str(action.bed_id), int(action.slot), str(action.plant_id))
		"water":
			_do_water(str(action.bed_id), int(action.slot))
		"harvest":
			_do_harvest(str(action.bed_id), int(action.slot))
		"uproot":
			var removed := garden.uproot(str(action.bed_id), int(action.slot))
			Events.plant_uprooted.emit(str(action.bed_id), int(action.slot), removed)
			print("Garden Explorer: uprooted %s" % removed)
		"media":
			garden.clear_awaiting_media(str(action.bed_id), int(action.slot))
			_offer_plant_media(str(action.plant_id), str(action.media_kind), true)
		_:
			pass

func _do_plant(bed_id: String, slot: int, plant_id: String) -> void:
	if not seed_db.is_seed_available(plant_id):
		SpeakScript.line("That seed is out of season.")
		if shed_ui and shed_ui.has_method("clear_selection"):
			shed_ui.call("clear_selection")
		return
	if garden.plant(bed_id, slot, plant_id):
		Events.plant_planted.emit(bed_id, slot, plant_id)
		print("Garden Explorer: planted %s in %s[%d]" % [plant_id, bed_id, slot])
	else:
		var empty := garden.first_empty_slot(bed_id)
		if empty >= 0 and garden.plant(bed_id, empty, plant_id):
			Events.plant_planted.emit(bed_id, empty, plant_id)
			print("Garden Explorer: planted %s in %s[%d]" % [plant_id, bed_id, empty])
		else:
			SpeakScript.line("This garden box is full.")

func _do_water(bed_id: String, slot: int) -> void:
	var result := garden.water(bed_id, slot, seed_db)
	if bool(result.get("ok", false)):
		Events.plant_watered.emit(bed_id, slot, str(result.plant_id), str(result.stage))
		print("Garden Explorer: watered %s → %s" % [result.plant_id, result.stage])
	elif bool(result.get("not_thirsty", false)):
		SpeakScript.line("Not thirsty yet.")

func _handle_animal_tap(animal_id: String) -> void:
	## Legacy hook — prefer arrive→prompt path.
	_queue_interact("animal", animal_id, farm_map.animal_positions.get(animal_id, farm_map.fence_center))

func _current_tool() -> String:
	if tool_bar and tool_bar.has_method("get_tool"):
		return str(tool_bar.call("get_tool"))
	return tool_id

func _do_harvest(bed_id: String, slot: int) -> void:
	var pid := garden.harvest(bed_id, slot)
	if pid.is_empty():
		return
	harvest_totals[pid] = int(harvest_totals.get(pid, 0)) + 1
	var total := int(harvest_totals[pid])
	Events.plant_harvested.emit(pid, total)
	print("Garden Explorer: harvest %s — total %d" % [pid, total])
	_speak_harvest(pid, total)
	if shed_ui and shed_ui.has_method("set_harvest_totals"):
		shed_ui.call("set_harvest_totals", harvest_totals)

func _speak_harvest(plant_id: String, total: int) -> void:
	var pname := seed_db.display_name(plant_id)
	var noun := pname if total == 1 else _plural_plant(pname)
	SpeakScript.line("You have %d %s." % [total, noun])
	var save := _save()
	if save and save.has_method("set_harvest_totals"):
		save.set_harvest_totals(harvest_totals)

static func _plural_plant(name: String) -> String:
	match name:
		"Tomato":
			return "Tomatoes"
		"Potato":
			return "Potatoes"
		"Strawberry":
			return "Strawberries"
		"Radish":
			return "Radishes"
		"Pea":
			return "Peas"
		"Bean":
			return "Beans"
		"Corn":
			return "Corn"
		_:
			if name.ends_with("y") and name.length() > 1:
				var prev := name[name.length() - 2]
				if not "aeiou".contains(prev.to_lower()):
					return name.substr(0, name.length() - 1) + "ies"
			if name.ends_with("s") or name.ends_with("x") or name.ends_with("ch") or name.ends_with("sh"):
				return name + "es"
			return name + "s"

func _on_season_tick(season_id: String, _index: int) -> void:
	_apply_season_change(season_id, true)

func _apply_season_change(season_id: String, announce: bool) -> void:
	farm_map.apply_season_tint(season_id)
	Events.season_changed.emit(season_id)
	## Drop held seed if it is out of season.
	if shed_ui and shed_ui.has_method("selected_seed"):
		var held := str(shed_ui.call("selected_seed"))
		if not held.is_empty() and not seed_db.is_seed_available(held):
			if shed_ui.has_method("clear_selection"):
				shed_ui.call("clear_selection")
	if shed_ui and shed_ui.has_method("refresh"):
		shed_ui.call("refresh")
	_sync_season_hud(announce)
	var label := seed_db.season_label(season_id)
	print("Garden Explorer: season → %s" % season_id)
	var save := _save()
	if save and save.has_method("set_season"):
		var elapsed := 0.0
		if season_clock:
			elapsed = float(season_clock.elapsed)
		save.set_season(season_id, elapsed)
	if announce:
		SpeakScript.line("It's %s! New seeds are in the shed." % label)

func _sync_season_hud(announce: bool) -> void:
	if season_hud == null:
		season_hud = get_tree().get_first_node_in_group("season_hud") if is_inside_tree() else null
	if season_hud == null:
		return
	var sid := seed_db.current_season
	var label := seed_db.season_label(sid)
	if season_hud.has_method("set_season"):
		season_hud.call("set_season", sid, label)
	if announce and season_hud.has_method("announce"):
		season_hud.call("announce", "It's %s!" % label)

func _on_garden_changed(_bed_id: String, _slot: int) -> void:
	_persist_beds()

func _persist_beds() -> void:
	var save := _save()
	if save and save.has_method("set_beds_blob"):
		save.set_beds_blob(garden.to_blob())

func _restore_from_save() -> void:
	var save := _save()
	if save == null:
		return
	if not save.beds_blob.is_empty():
		garden.from_blob(save.beds_blob)
	harvest_totals = save.harvest_totals.duplicate()
	tool_id = str(save.tool_id)

func _on_stage_advanced(bed_id: String, slot: int, plant_id: String, stage: String) -> void:
	Events.plant_stage_changed.emit(bed_id, slot, plant_id, stage)
	print("Garden Explorer: %s is now %s — tap the plant to watch (first time)" % [plant_id, stage])
	## No auto-play: MediaPanel opens only after the next player tap.

func _offer_plant_media(plant_id: String, kind: String, discover: bool) -> bool:
	## Returns true if media opened (first discovery). Replays are menu-only.
	if plant_id.is_empty() or kind.is_empty():
		return false
	var save := _save()
	var flag := "media:%s:%s" % [kind, plant_id]
	if save and save.has_flag(flag):
		return false
	var media := get_tree().get_first_node_in_group("media_panel")
	if media == null:
		media = stage_media
	if media == null or not media.has_method("play_plant"):
		if discover and save:
			save.set_flag(flag, true)
		return false
	var ok := bool(media.call("play_plant", plant_id, kind))
	if ok and discover and save:
		save.set_flag(flag, true)
		if star_menu and star_menu.has_method("refresh"):
			star_menu.call("refresh")
	return ok

func _show_ripple(world_pos: Vector2) -> void:
	if tap_marker == null:
		return
	tap_marker.visible = true
	tap_marker.global_position = world_pos
	tap_marker.modulate.a = 1.0
	tap_marker.scale = Vector2.ONE
	_ripple_left = Config.tap_ripple_sec

func _on_star_reveal_requested(star_id: String) -> void:
	## Close star menu so the kid sees the farm + gold outline.
	if star_menu and star_menu.has_method("is_open") and bool(star_menu.call("is_open")):
		Events.hamburger_pressed.emit()
	var target := _guidance_target(star_id)
	var radius := 64.0
	match star_db.zone(star_id):
		"shed":
			radius = 72.0
		"fence":
			radius = 70.0
		"map":
			radius = 90.0
		_:
			radius = 58.0
	if gold_outline and gold_outline.has_method("show_at"):
		gold_outline.call("show_at", target, radius, 4.5)
	if camera and camera.has_method("begin_pan_to"):
		camera.begin_pan_to(target, 1.4)
		_guide_return_left = 3.2
	print("Garden Explorer: guide → %s @ %s" % [star_id, star_db.zone(star_id)])

func _guidance_target(star_id: String) -> Vector2:
	match star_db.zone(star_id):
		"shed":
			return farm_map.shed_center
		"fence":
			return farm_map.fence_center
		"map":
			return farm_map.spawn_world
		_:
			if farm_map.bed_centers.has("bed_1"):
				return farm_map.bed_centers["bed_1"]
			return farm_map.spawn_world

func _save() -> Node:
	if not is_inside_tree():
		return null
	return get_tree().root.get_node_or_null("/root/Save")

func _cfg() -> Node:
	if not is_inside_tree():
		return null
	return get_tree().root.get_node_or_null("/root/Config")

func _cfg_season_duration() -> float:
	var c := _cfg()
	if c and c.has_method("get_season_duration_sec"):
		return float(c.get_season_duration_sec())
	return 0.0

func _cfg_animal_radius() -> float:
	var c := _cfg()
	if c and c.has_method("get_animal_tap_radius"):
		return float(c.get_animal_tap_radius())
	return 48.0

extends Node2D
## Farm world: map + player + garden + seasons + animals.

const SeasonClockScript := preload("res://scripts/sim/SeasonClock.gd")
const GoldOutlineScript := preload("res://scripts/ui/GoldOutline.gd")
const StarProgressScript := preload("res://scripts/sim/StarProgress.gd")
const SpeakScript := preload("res://scripts/audio/Speak.gd")
const NarratorScript := preload("res://scripts/audio/Narrator.gd")
const AnimalSfxScript := preload("res://scripts/audio/AnimalSfx.gd")
const GardenSfxScript := preload("res://scripts/audio/GardenSfx.gd")
const RoamingAnimalScript := preload("res://scripts/world/RoamingAnimal.gd")
const PenGateScript := preload("res://scripts/world/PenGate.gd")
const AnimalCatalogScript := preload("res://scripts/content/AnimalCatalog.gd")
const BugCatalogScript := preload("res://scripts/content/BugCatalog.gd")
const BugSpawnerScript := preload("res://scripts/world/BugSpawner.gd")
const GameFreezeScript := preload("res://scripts/sim/GameFreeze.gd")

@onready var farm_map: FarmMap = $FarmMap
@onready var player: Player = $Player
@onready var camera: CameraFollow = $CameraFollow
@onready var tap_marker: Node2D = $TapMarker

const StarDBScript := preload("res://scripts/content/StarDB.gd")

var seed_db: SeedDB = SeedDB.new()
var star_db = StarDBScript.new()
var animal_db = AnimalCatalogScript.new()
var bug_db = BugCatalogScript.new()
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
var tool_id: String = "" ## mirrored from shed hand / save
var action_prompt: Node
var reveal_tile: Node
var video_panel: Node
var bug_grid: Node
var plant_grid: Node
var season_card: Node
var pen_gate: Node2D
var bug_spawner: Node2D
var roaming_animals: Dictionary = {} ## id -> RoamingAnimal
## Context of the currently open reveal (for catch-on-close behavior).
var _reveal_ctx: Dictionary = {}
## Bug id waiting for its "You caught it!" grid after a video closes.
var _grid_after_video: String = ""
## Pending interactable: walk once to a fixed approach, then show ActionPrompt /
## RevealTile on arrive. No chase / repath onto moving animals or bugs.
var _pending: Dictionary = {}
var _animal_sfx_played: bool = false
## After first animal meet: single tap = SFX; second tap within window = reveal.
var _animal_met: Dictionary = {} ## animal_id -> true
var _animal_last_tap_ms: Dictionary = {} ## animal_id -> msec
const ANIMAL_DOUBLE_TAP_MS := 2000

var _ripple_left: float = 0.0
var _guide_return_left: float = 0.0
var _uproot_armed_bed: String = ""
var _harvest_armed_bed: String = ""
var _water_anim: Node2D = null
var _restoring_hand: bool = false

func _ready() -> void:
	seed_db.load_all()
	star_db.load_all()
	animal_db.load_all()
	bug_db.load_all()
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
	_spawn_pen_gate()
	_spawn_roaming_animals()
	_spawn_bug_spawner()
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
		_restore_shed_hand()
	tool_bar = get_tree().get_first_node_in_group("tool_bar")
	if tool_bar:
		if tool_bar.has_method("hide_bar"):
			tool_bar.call("hide_bar")
		else:
			tool_bar.visible = false
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
	reveal_tile = get_tree().get_first_node_in_group("reveal_tile")
	if reveal_tile:
		if reveal_tile.has_signal("confirmed") and not reveal_tile.confirmed.is_connected(_on_reveal_confirmed):
			reveal_tile.confirmed.connect(_on_reveal_confirmed)
		if reveal_tile.has_signal("cancelled") and not reveal_tile.cancelled.is_connected(_on_reveal_cancelled):
			reveal_tile.cancelled.connect(_on_reveal_cancelled)
	video_panel = get_tree().get_first_node_in_group("video_panel")
	if video_panel and video_panel.has_signal("closed") and not video_panel.closed.is_connected(_on_video_closed):
		video_panel.closed.connect(_on_video_closed)
	bug_grid = get_tree().get_first_node_in_group("bug_grid")
	if bug_grid and bug_grid.has_method("setup"):
		bug_grid.call("setup", bug_db, sprites)
	plant_grid = get_tree().get_first_node_in_group("plant_grid")
	if plant_grid and plant_grid.has_method("setup"):
		plant_grid.call("setup", seed_db, sprites)
	season_card = get_tree().get_first_node_in_group("season_card")

func _restore_shed_hand() -> void:
	## Boot hands-free. Save still records the hand mid-session, but each launch
	## starts empty so kids explore / catch bugs without a leftover watering can.
	var save := _save()
	if shed_ui == null or save == null:
		return
	tool_id = ""
	_restoring_hand = true
	if shed_ui.has_method("restore_tool"):
		shed_ui.call("restore_tool", "", "")
	elif shed_ui.has_method("clear_selection"):
		shed_ui.call("clear_selection")
	else:
		Events.tool_changed.emit("")
	_restoring_hand = false
	## Drop any persisted hand so the next cold start stays hands-free.
	if save.has_method("set_tool"):
		save.set_tool("", "")

func set_tool(id: String) -> void:
	tool_id = id
	if tool_bar and tool_bar.has_method("set_tool"):
		tool_bar.call("set_tool", id)
	else:
		Events.tool_changed.emit(id)
	var save := _save()
	if save and save.has_method("set_tool"):
		var plant := ""
		if id == "seed" and shed_ui and shed_ui.has_method("selected_seed"):
			plant = str(shed_ui.call("selected_seed"))
		save.set_tool(id, plant)

func advance_season() -> String:
	## Test / debug hook — same path as the wall-clock timer.
	if season_clock:
		return season_clock.force_advance()
	return ""

func _on_seed_selected(plant_id: String) -> void:
	## First time a seed type is collected → seed media (discover).
	if _restoring_hand:
		return
	_offer_plant_media(plant_id, "seed", true)

func _on_seed_cleared() -> void:
	pass

func _process(delta: float) -> void:
	## Game time (growth + season) freezes with the player: narration locks
	## and full-screen panels stop the clock; routine actions do not.
	var time_frozen := GameFreezeScript.frozen(get_tree())
	if season_clock:
		season_clock.paused = time_frozen
	if garden and seed_db and not time_frozen:
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
	## Taps made while narration froze the player: walk once the lock releases.
	if not _pending.is_empty() and bool(_pending.get("deferred_path", false)) \
			and not NarratorScript.blocks_movement():
		_pending.erase("deferred_path")
		var goal: Vector2 = farm_map.nearest_walkable(_pending.get("approach", Vector2.ZERO))
		## Pure navigate (e.g. pen entry via gate) — no arrive prompt.
		if str(_pending.get("kind", "")) == "nav":
			_pending.clear()
		Events.player_path_requested.emit(goal)

func _spawn_bug_spawner() -> void:
	if bug_spawner and is_instance_valid(bug_spawner):
		return
	bug_spawner = BugSpawnerScript.new()
	bug_spawner.name = "BugSpawner"
	add_child(bug_spawner)
	bug_spawner.setup(farm_map, bug_db, sprites, garden)

func _spawn_pen_gate() -> void:
	if pen_gate and is_instance_valid(pen_gate):
		return
	pen_gate = PenGateScript.new()
	pen_gate.name = "PenGate"
	add_child(pen_gate)
	var gpos: Vector2 = farm_map.gate_world if farm_map.gate_world != Vector2.ZERO \
		else farm_map.fence_center + Vector2(-90, 0)
	pen_gate.setup(sprites, gpos)
	pen_gate.bind_player(player)

func _spawn_roaming_animals() -> void:
	for id in roaming_animals.keys():
		var old: Node = roaming_animals[id]
		if old and is_instance_valid(old):
			old.queue_free()
	roaming_animals.clear()
	for a in animal_db.animals:
		var d: Dictionary = a
		var id := str(d.get("id", ""))
		if id.is_empty():
			continue
		var actor: Node2D = RoamingAnimalScript.new()
		actor.name = "Animal_%s" % id
		add_child(actor)
		var spawn: Vector2 = farm_map.animal_positions.get(id, farm_map.fence_center)
		var bound := PackedVector2Array()
		if bool(d.get("pen", true)):
			bound = farm_map.pen_roam_poly
			if bound.is_empty():
				bound = farm_map.fence_poly
		else:
			## Dog: yard wander (empty bound → yard logic). Prefer map spawn.
			spawn = farm_map.dog_spawn_world if farm_map.dog_spawn_world != Vector2.ZERO \
				else farm_map.spawn_world + Vector2(40, 20)
			if farm_map.has_method("nearest_dog_walkable"):
				spawn = farm_map.nearest_dog_walkable(spawn)
		actor.setup(
			id, farm_map, sprites, spawn, bound,
			float(d.get("scale", 3.5)),
			str(d.get("kind", "")),
			str(d.get("color", "default"))
		)
		roaming_animals[id] = actor
		farm_map.animal_positions[id] = spawn

func _animal_node(animal_id: String) -> Node2D:
	var n: Node = roaming_animals.get(animal_id, null)
	if n and is_instance_valid(n):
		return n
	return null

func _player_in_pen() -> bool:
	return player != null and farm_map != null and farm_map.in_pen(player.global_position)

func _same_side_of_fence(a: Vector2, b: Vector2) -> bool:
	## Garden and pen are separate movement zones.
	if farm_map == null:
		return true
	return farm_map.in_pen(a) == farm_map.in_pen(b)

func _can_interact_animal(animal_id: String) -> bool:
	## Pen animals only while the player is already in the pen. Dog only while
	## the player is in the garden. Cross-fence taps use gate navigate instead.
	if animal_id.is_empty() or player == null or animal_db == null:
		return false
	return _player_in_pen() == animal_db.in_pen(animal_id)

func _on_world_tapped(world_pos: Vector2) -> void:
	_show_ripple(world_pos)
	## Shed tool-pickup VO (and similar): tap cancels so kids can act immediately.
	if NarratorScript.is_tap_cancellable():
		NarratorScript.stop()
	## Action chip is non-blocking: tap elsewhere cancels and navigates.
	if action_prompt and action_prompt.has_method("is_open") and bool(action_prompt.call("is_open")):
		action_prompt.call("close_prompt")
		_on_action_cancelled()
		SpeakScript.stop()
	if shed_ui and shed_ui.has_method("is_open") and shed_ui.call("is_open"):
		return
	if bug_grid and bug_grid.has_method("is_open") and bool(bug_grid.call("is_open")):
		return
	if plant_grid and plant_grid.has_method("is_open") and bool(plant_grid.call("is_open")):
		return
	if season_card and season_card.has_method("is_open") and bool(season_card.call("is_open")):
		return
	## Beds / shed win over nearby animals — Buddy must not steal gardening taps.
	var zone := farm_map.zone_at(world_pos)
	var zone_kind := str(zone.get("kind", ""))
	if zone_kind == "bed" or zone_kind == "shed":
		var zid0 := str(zone.get("id", ""))
		Events.zone_tapped.emit(zid0, zone_kind)
		_queue_interact(zone_kind, zid0, world_pos)
		return
	## While walking to a gardening / interact goal, ignore distraction taps
	## (ground spam, Buddy, bugs). Retargeting another bed/shed is handled above.
	if _interact_pending_active() and player and bool(player.get("moving")):
		return
	## Roaming bugs: same side of the fence only; one walk to tap spot, no chase.
	if bug_spawner and bug_spawner.has_method("bug_at") and player:
		var bug: Node2D = bug_spawner.bug_at(world_pos, 34.0)
		if bug != null and _same_side_of_fence(player.global_position, bug.global_position):
			_queue_bug_interact(bug)
			return
	## Animals: same-zone only. Walk once to where they were; no chase.
	var hit_animal := _nearest_roaming_animal(world_pos, Config.get_animal_tap_radius())
	if not hit_animal.is_empty() and _can_interact_animal(hit_animal):
		var actor := _animal_node(hit_animal)
		_queue_interact("animal", hit_animal, actor.global_position if actor else world_pos)
		return
	## Chicken coop look — egg-collecting video (pen interaction).
	if farm_map.coop_world != Vector2.ZERO and world_pos.distance_to(farm_map.coop_world) <= 60.0:
		_queue_interact("coop", "coop", farm_map.nearest_walkable(farm_map.coop_world + Vector2(0, 40)))
		return
	if zone.is_empty():
		## Tap = navigate. Do not clear an in-flight interact if somehow still set.
		if _interact_pending_active() and player and bool(player.get("moving")):
			return
		_pending.clear()
		_animal_sfx_played = false
		if not farm_map.is_blocked(world_pos):
			Events.player_path_requested.emit(world_pos)
		else:
			Events.player_path_requested.emit(farm_map.nearest_walkable(world_pos))
		return
	var kind := zone_kind
	var zid := str(zone.get("id", ""))
	## zone_at may report an animal under the tap — only interact if same zone.
	if kind == "animal" and not _can_interact_animal(zid):
		kind = "fence"
		zid = "fence"
	Events.zone_tapped.emit(zid, kind)
	## Walk to the interactable first; action tile opens on arrive.
	_queue_interact(kind, zid, world_pos)

func _interact_pending_active() -> bool:
	var k := str(_pending.get("kind", ""))
	return k == "bed" or k == "shed" or k == "animal" or k == "bug" or k == "coop"

func _nearest_roaming_animal(world_pos: Vector2, radius: float) -> String:
	var best := ""
	var best_d := radius
	for id in roaming_animals.keys():
		var actor: Node2D = roaming_animals[id]
		if actor == null or not is_instance_valid(actor):
			continue
		var d := world_pos.distance_to(actor.global_position)
		if d <= best_d:
			best_d = d
			best = str(id)
	return best

func _queue_interact(kind: String, zid: String, world_pos: Vector2) -> void:
	var approach := world_pos
	var slot := -1
	match kind:
		"shed":
			approach = farm_map.shed_door_world if farm_map.shed_door_world != Vector2.ZERO \
				else farm_map.nearest_walkable(farm_map.shed_center + Vector2(36, 20))
		"bed":
			slot = farm_map.nearest_slot(zid, world_pos)
			approach = farm_map.nearest_walkable(farm_map.slot_world(zid, slot))
		"fence":
			## Pen ground tap: gate routing only from outside. Same-zone animal
			## hits become a one-shot walk to that animal's current spot.
			var near := ""
			if _player_in_pen():
				near = _nearest_roaming_animal(world_pos, _cfg_animal_radius() * 1.6)
				if near.is_empty():
					near = farm_map.animal_at(world_pos, _cfg_animal_radius() * 1.6)
			if not near.is_empty() and _can_interact_animal(near):
				kind = "animal"
				zid = near
				var a := _animal_node(near)
				approach = a.global_position if a else farm_map.animal_positions.get(near, farm_map.fence_center)
			else:
				## Enter / walk the pen via the gate.
				approach = farm_map.nearest_walkable(world_pos)
				_pending.clear()
				_animal_sfx_played = false
				if NarratorScript.blocks_movement():
					_pending = {"kind": "nav", "approach": approach, "deferred_path": true}
				else:
					Events.player_path_requested.emit(approach)
				return
		"animal":
			## Refuse cross-zone animal interact; fall back to gate navigate.
			if not _can_interact_animal(zid):
				approach = farm_map.nearest_walkable(world_pos)
				_pending.clear()
				_animal_sfx_played = false
				if NarratorScript.blocks_movement():
					_pending = {"kind": "nav", "approach": approach, "deferred_path": true}
				else:
					Events.player_path_requested.emit(approach)
				return
			var actor := _animal_node(zid)
			## Freeze approach at tap time — do not chase if they wander.
			approach = actor.global_position if actor else farm_map.animal_positions.get(zid, farm_map.fence_center)
		_:
			approach = farm_map.nearest_walkable(world_pos)
	_pending = {
		"kind": kind,
		"id": zid,
		"slot": slot,
		"approach": approach,
		"tap": world_pos,
	}
	_animal_sfx_played = false
	## Already close enough → prompt immediately.
	if player and player.global_position.distance_to(approach) <= Config.get_interact_arrive_eps():
		_open_pending_prompt()
		return
	if NarratorScript.blocks_movement():
		## Player is frozen by narration — Player would drop the path request,
		## leaving the tap dead. Defer it until the lock releases (_process).
		_pending["deferred_path"] = true
	else:
		Events.player_path_requested.emit(farm_map.nearest_walkable(approach))

func _queue_bug_interact(bug: Node2D) -> void:
	## Same-zone only. One walk to the bug's position at tap time — no chase.
	if player and not _same_side_of_fence(player.global_position, bug.global_position):
		Events.player_path_requested.emit(farm_map.nearest_walkable(bug.global_position))
		return
	var approach := farm_map.nearest_walkable(bug.global_position)
	_pending = {
		"kind": "bug",
		"id": str(bug.bug_id),
		"bug_iid": bug.get_instance_id(),
		"slot": -1,
		"approach": approach,
		"tap": bug.global_position,
	}
	if player and player.global_position.distance_to(bug.global_position) <= Config.get_interact_arrive_eps() * 1.4:
		_open_pending_prompt()
	elif NarratorScript.blocks_movement():
		_pending["deferred_path"] = true
	else:
		Events.player_path_requested.emit(approach)

func _pending_bug_node() -> Node2D:
	var iid := int(_pending.get("bug_iid", 0))
	if iid == 0:
		return null
	var obj := instance_from_id(iid)
	if obj is Node2D and is_instance_valid(obj):
		return obj as Node2D
	return null

func _on_player_arrived() -> void:
	if _pending.is_empty():
		return
	## Gate / ground navigate — no interaction on arrive.
	if str(_pending.get("kind", "")) == "nav":
		_pending.clear()
		return
	## Animal / bug / shed / bed: open at the fixed approach from the tap.
	var approach: Vector2 = _pending.get("approach", Vector2.ZERO)
	var kind := str(_pending.get("kind", ""))
	var eps := Config.get_interact_arrive_eps() * 2.0
	var close_enough := player != null and player.global_position.distance_to(approach) <= eps
	if not close_enough and kind == "bed" and farm_map:
		## Kids tap soil; approach is the walkable rim — also accept near bed center.
		var bed_id := str(_pending.get("id", ""))
		var center: Vector2 = farm_map.bed_centers.get(bed_id, approach)
		var rim := farm_map.nearest_walkable(center)
		close_enough = player.global_position.distance_to(rim) <= eps \
			or player.global_position.distance_to(center) <= eps + 40.0
	if not close_enough:
		var attempts := int(_pending.get("repaths", 0))
		if attempts < 2 and farm_map:
			_pending["repaths"] = attempts + 1
			Events.player_path_requested.emit(farm_map.nearest_walkable(approach))
			return
		## Soft-collision abort left us short — still try bed tools when nearby
		## so watering / planting is not lost after a walk.
		if kind == "bed" and farm_map and player:
			var bed_id2 := str(_pending.get("id", ""))
			var center2: Vector2 = farm_map.bed_centers.get(bed_id2, approach)
			if player.global_position.distance_to(center2) > 120.0:
				return
		else:
			return
	if kind == "bug":
		var bug := _pending_bug_node()
		if bug == null:
			_pending.clear()
			return
	_open_pending_prompt()

func _open_pending_prompt() -> void:
	if _pending.is_empty():
		return
	## Animals: first meet → reveal; later → SFX. Buddy is bark-only (no video).
	if str(_pending.get("kind", "")) == "animal":
		var aid := str(_pending.get("id", ""))
		_handle_animal_arrive(aid)
		return
	if str(_pending.get("kind", "")) == "bug":
		_show_roaming_bug_reveal()
		return
	if str(_pending.get("kind", "")) == "coop":
		_pending.clear()
		_show_coop_look()
		return
	## Beds: tools apply immediately; hands-free shows Bugs/Examine tiles.
	if str(_pending.get("kind", "")) == "bed":
		var bed_id := str(_pending.get("id", ""))
		_pending.clear()
		if _apply_bed_tool(bed_id):
			return
		_pending = {"kind": "bed", "id": bed_id, "slot": 0, "approach": Vector2.ZERO}
	if action_prompt == null:
		_pending.clear()
		return
	var actions := _build_actions_for_pending()
	if actions.is_empty():
		_pending.clear()
		return
	if action_prompt.has_method("show_actions"):
		action_prompt.call("show_actions", actions)
	else:
		action_prompt.call("show_action", actions[0])

func _handle_animal_arrive(animal_id: String) -> void:
	_pending.clear()
	var now := Time.get_ticks_msec()
	var kind := animal_db.kind_of(animal_id) if animal_db else ""
	## Buddy: bark only — skip reveal/video (playtest: daughter finds it annoying).
	if animal_id == "dog" or kind == "dog":
		if not _is_animal_met(animal_id):
			_mark_animal_met(animal_id)
		AnimalSfxScript.play(animal_id)
		Events.animal_tapped.emit(animal_id)
		print("Garden Explorer: animal:%s (bark)" % animal_id)
		_animal_sfx_played = false
		return
	if not _is_animal_met(animal_id):
		_mark_animal_met(animal_id)
		_animal_last_tap_ms[animal_id] = now
		_show_animal_reveal(animal_id)
		return
	var last := int(_animal_last_tap_ms.get(animal_id, 0))
	_animal_last_tap_ms[animal_id] = now
	if now - last <= ANIMAL_DOUBLE_TAP_MS:
		_show_animal_reveal(animal_id)
		return
	AnimalSfxScript.play(animal_id)
	Events.animal_tapped.emit(animal_id)
	print("Garden Explorer: animal:%s (sfx)" % animal_id)
	_animal_sfx_played = false

func _is_animal_met(animal_id: String) -> bool:
	if bool(_animal_met.get(animal_id, false)):
		return true
	var save := _save()
	if save and save.has_method("has_flag") and save.has_flag("animal_met:%s" % animal_id):
		_animal_met[animal_id] = true
		return true
	return false

func _mark_animal_met(animal_id: String) -> void:
	_animal_met[animal_id] = true
	var save := _save()
	if save and save.has_method("set_flag"):
		save.set_flag("animal_met:%s" % animal_id, true)

func _apply_bed_tool(bed_id: String) -> bool:
	## Returns true if the interaction was fully handled (no action tiles).
	## Grown plants always use the harvest confirm tile — held tool does not matter
	## (seed / water / spade / hands-free). Fall through so _build_bed_actions builds it.
	if garden != null and garden.is_bed_harvestable(bed_id):
		return false
	var tool := _shed_tool()
	match tool:
		"seed":
			var held := ""
			if shed_ui and shed_ui.has_method("selected_seed"):
				held = str(shed_ui.call("selected_seed"))
			if held.is_empty():
				SpeakScript.line("Pick a seed at the shed first.")
				return true
			if garden.is_bed_empty(bed_id):
				_do_plant_bed(bed_id, held)
			else:
				SpeakScript.line("This bed already has plants. Go to the shed and get the spade to uproot them.")
			return true
		"water":
			if garden.is_bed_empty(bed_id):
				SpeakScript.soft("Nothing to water yet. Get seeds from the shed and plant them.")
				return true
			if garden.is_bed_thirsty(bed_id):
				_do_water_bed(bed_id)
			else:
				SpeakScript.soft("This bed is not thirsty right now.")
			return true
		"uproot":
			if garden.is_bed_empty(bed_id):
				SpeakScript.line("No plants here. Get seeds from the shed to plant some.")
				return true
			## Spade only pulls non-grown plants; grown beds fall through to harvest.
			_arm_uproot(bed_id)
			return true
		_:
			return false

func _harvest_confirm_action(bed_id: String) -> Dictionary:
	var pid := garden.bed_plant_id(bed_id) if garden else ""
	var pname := seed_db.display_name(pid) if seed_db else pid
	var tex: Texture2D = null
	if sprites:
		## Prefer the pretty grown plant in the bed over the harvested produce icon.
		if sprites.has_method("plant_stage_texture"):
			tex = sprites.plant_stage_texture(pid, "grown")
		if tex == null and sprites.has_method("harvest_icon"):
			tex = sprites.harvest_icon(pid)
	var line := "Tap to harvest %s." % pname
	return {
		"kind": "harvest_confirm",
		"bed_id": bed_id,
		"plant_id": pid,
		"label": "Tap to harvest %s" % pname,
		"texture": tex,
		"tile_size": Vector2(220, 220),
		"icon_size": Vector2(120, 120),
		"narration": line,
	}

func _arm_harvest(bed_id: String) -> void:
	_harvest_armed_bed = bed_id
	if action_prompt == null:
		return
	action_prompt.call("show_actions", [_harvest_confirm_action(bed_id)])

func _arm_uproot(bed_id: String) -> void:
	_uproot_armed_bed = bed_id
	if action_prompt == null:
		return
	action_prompt.call("show_actions", [{
		"kind": "uproot_confirm",
		"bed_id": bed_id,
		"label": "Uproot?",
		"icon": "res://assets/ui/tile_uproot_confirm.png",
		"narration": "Are you sure you want to uproot these plants? Tap again to pull them out.",
	}])

var _interacting_animal: String = ""

func _release_interacting_animal() -> void:
	if _interacting_animal.is_empty():
		return
	var actor := _animal_node(_interacting_animal)
	if actor and actor.has_method("set_interacting"):
		actor.set_interacting(false)
	_interacting_animal = ""

func _show_animal_reveal(animal_id: String) -> void:
	if not _animal_sfx_played:
		AnimalSfxScript.play(animal_id)
		_animal_sfx_played = true
	Events.animal_tapped.emit(animal_id)
	print("Garden Explorer: animal:%s" % animal_id)
	## Pet greets the player: pause + happy stance for the whole interaction.
	var greet := _animal_node(animal_id)
	if greet and greet.has_method("set_interacting"):
		greet.set_interacting(true, player.global_position if player else greet.global_position)
		_interacting_animal = animal_id
	var name := animal_db.display_name(animal_id)
	var tex: Texture2D = sprites.portrait_texture(animal_db.portrait_path(animal_id))
	if tex == null:
		## Fallback: live sprite sheet / idle.
		var kind := animal_db.kind_of(animal_id)
		match kind:
			"chicken":
				tex = sprites.chicken_texture(animal_db.color_of(animal_id))
			"cow":
				tex = sprites.cow_texture()
			"pig":
				tex = sprites.pig_texture()
			"rabbit":
				tex = sprites.rabbit_texture()
			"dog":
				tex = sprites.dog_texture()
	var line := animal_db.tap_line(animal_id)
	_pending.clear()
	_reveal_ctx = {"kind": "animal", "id": animal_id}
	if reveal_tile and reveal_tile.has_method("show_reveal"):
		## Brief delay so animal SFX leads the narration.
		await get_tree().create_timer(0.45).timeout
		if reveal_tile and reveal_tile.has_method("show_reveal"):
			reveal_tile.call("show_reveal", {
				"kind": "animal_video",
				"id": animal_id,
				"title": name,
				"texture": tex,
				"narration": line,
				"hint": "Tap picture to learn more · tap away to skip",
				"video": animal_db.video_file(animal_id),
				"topic": "%s the %s" % [name, animal_db.kind_of(animal_id)],
			})
	else:
		SpeakScript.line(line)

func _show_roaming_bug_reveal() -> void:
	var bug := _pending_bug_node()
	var bid := str(_pending.get("id", ""))
	_pending.clear()
	if bug == null or bid.is_empty():
		return
	if bug.has_method("set_interacting"):
		bug.set_interacting(true)
	var d: Dictionary = bug_db.get_bug(bid)
	var bname := str(d.get("name", bid.capitalize()))
	var tex: Texture2D = sprites.portrait_texture(str(d.get("portrait", "")))
	_reveal_ctx = {"kind": "bug", "id": bid, "bug_iid": bug.get_instance_id(), "roaming": true}
	print("Garden Explorer: bug_tap:%s" % bid)
	if reveal_tile and reveal_tile.has_method("show_reveal"):
		reveal_tile.call("show_reveal", {
			"kind": "bug_video",
			"id": bid,
			"title": bname,
			"texture": tex,
			"narration": str(d.get("line", "A garden bug! Tap to learn more.")),
			"hint": "Tap picture to learn more · tap away to skip",
			"video": str(d.get("video", "")),
			"topic": "%s in the garden" % bname,
		})

func _finish_bug_catch(launched_video: bool) -> void:
	## Roaming bug is caught when its interaction ends (either way).
	var bid := str(_reveal_ctx.get("id", ""))
	if bool(_reveal_ctx.get("roaming", false)):
		var iid := int(_reveal_ctx.get("bug_iid", 0))
		var obj := instance_from_id(iid)
		if obj is Node2D and is_instance_valid(obj) and obj.has_method("catch_and_free"):
			obj.catch_and_free()
	var save := _save()
	var is_new: bool = save != null and save.has_method("catch_bug") and save.catch_bug(bid)
	if is_new:
		if launched_video:
			_grid_after_video = bid
		elif bug_grid and bug_grid.has_method("show_catch"):
			bug_grid.call("show_catch", bid)
	_reveal_ctx.clear()

func _on_video_closed() -> void:
	if _grid_after_video.is_empty():
		return
	var bid := _grid_after_video
	_grid_after_video = ""
	if bug_grid and bug_grid.has_method("show_catch"):
		bug_grid.call("show_catch", bid)

func _shed_tool() -> String:
	if shed_ui and shed_ui.has_method("selected_tool"):
		return str(shed_ui.call("selected_tool"))
	return ""

func _build_actions_for_pending() -> Array:
	var kind := str(_pending.get("kind", ""))
	var zid := str(_pending.get("id", ""))
	var slot := int(_pending.get("slot", -1))
	match kind:
		"shed":
			return [{
				"kind": "open_shed",
				"label": "Supplies",
				"icon": "res://assets/ui/tile_supplies.png",
				"narration": "Get or switch your garden supplies at the shed.",
			}]
		"bed":
			return _build_bed_actions(zid, slot)
		_:
			return []

func _build_bed_actions(bed_id: String, slot: int) -> Array:
	## Tool decided at the shed. Holding a tool auto-applies on arrive
	## (see _open_pending_prompt). Hands-free: Bugs + Examine tiles only.
	## Grown beds always get the harvest confirm tile (any held tool).
	if slot < 0:
		slot = 0
	var out: Array = []
	if garden != null and garden.is_bed_harvestable(bed_id):
		_harvest_armed_bed = bed_id
		return [_harvest_confirm_action(bed_id)]
	var tool := _shed_tool()
	match tool:
		"seed", "water", "uproot":
			return [] ## auto-applied on arrive
		_:
			pass
	var awaiting := garden.bed_awaiting_media(bed_id)
	var pid := garden.bed_plant_id(bed_id)
	if awaiting == GardenState.STAGE_SPROUT or awaiting == GardenState.STAGE_GROWN:
		out.append({
			"kind": "media",
			"bed_id": bed_id,
			"slot": 0,
			"plant_id": pid,
			"media_kind": awaiting,
			"label": "Examine",
			"icon": "res://assets/ui/tile_examine.png",
			"narration": "Examine the %s!" % seed_db.display_name(pid),
		})
	out.append({
		"kind": "bugs",
		"bed_id": bed_id,
		"slot": slot,
		"label": "Bugs",
		"icon": "res://assets/ui/icon_bugs.png",
		"narration": "Let's look for bugs in the garden!",
		"silent": true,
	})
	return out

func _on_action_cancelled() -> void:
	_pending.clear()
	_animal_sfx_played = false
	_uproot_armed_bed = ""
	_harvest_armed_bed = ""

func _on_action_confirmed(action: Dictionary) -> void:
	_pending.clear()
	var kind := str(action.get("kind", ""))
	match kind:
		"open_shed":
			if shed_ui and shed_ui.has_method("open_shed"):
				shed_ui.call("open_shed")
				print("Garden Explorer: open shed (%s)" % seed_db.current_season)
		"plant":
			_do_plant_bed(str(action.bed_id), str(action.plant_id))
		"water":
			_do_water_bed(str(action.bed_id))
		"harvest":
			_do_harvest_bed(str(action.bed_id))
		"harvest_confirm":
			## Second tap on the confirm tile — leave plants if they tap away instead.
			_do_harvest_bed(str(action.bed_id))
		"uproot":
			_do_uproot_bed(str(action.bed_id))
		"uproot_confirm":
			## Second tap on the confirm tile.
			_do_uproot_bed(str(action.bed_id))
		"media":
			garden.clear_awaiting_media(str(action.bed_id))
			_offer_plant_media(str(action.plant_id), str(action.media_kind), true)
		"bugs":
			_start_bug_hunt(str(action.get("bed_id", "")))
		_:
			pass

func _start_bug_hunt(bed_id: String) -> void:
	SpeakScript.line("We'll look carefully for bugs that live with our plants.")
	await get_tree().create_timer(1.1).timeout
	var plants := PackedStringArray()
	if not bed_id.is_empty() and garden:
		var slots := int(farm_map.data.get("slots_per_bed", 4))
		for s in slots:
			var st := garden.get_slot(bed_id, s)
			var pid := str(st.get("plant_id", ""))
			if not pid.is_empty():
				plants.append(pid)
	var bug: Dictionary = bug_db.pick_weighted(plants)
	if bug.is_empty():
		SpeakScript.line("No bugs today — try again later.")
		return
	var bid := str(bug.get("id", ""))
	var bname := str(bug.get("name", bid))
	var tex: Texture2D = sprites.portrait_texture(str(bug.get("portrait", "")))
	print("Garden Explorer: bug:%s bed:%s" % [bid, bed_id])
	_reveal_ctx = {"kind": "bug", "id": bid, "roaming": false}
	if reveal_tile and reveal_tile.has_method("show_reveal"):
		reveal_tile.call("show_reveal", {
			"kind": "bug_video",
			"id": bid,
			"title": bname,
			"texture": tex,
			"narration": str(bug.get("line", "A garden bug! Tap to learn more.")),
			"hint": "Tap picture to learn more · tap away to skip",
			"video": str(bug.get("video", "")),
			"topic": "%s in the garden" % bname,
		})

func _on_reveal_confirmed(payload: Dictionary) -> void:
	_release_interacting_animal()
	var kind := str(payload.get("kind", ""))
	var file_name := str(payload.get("video", ""))
	var topic := str(payload.get("topic", payload.get("title", "")))
	var id := str(payload.get("id", kind))
	var launched := false
	if video_panel == null:
		video_panel = get_tree().get_first_node_in_group("video_panel")
	if video_panel and video_panel.has_method("play_star") and not file_name.is_empty():
		launched = bool(video_panel.call("play_star", id, file_name, topic))
	elif not topic.is_empty():
		SpeakScript.line(topic)
	if kind == "bug_video" and str(_reveal_ctx.get("kind", "")) == "bug":
		_finish_bug_catch(launched)
	else:
		_reveal_ctx.clear()

func _on_reveal_cancelled() -> void:
	_release_interacting_animal()
	if str(_reveal_ctx.get("kind", "")) == "bug":
		_finish_bug_catch(false)
	else:
		_reveal_ctx.clear()

func _do_plant_bed(bed_id: String, plant_id: String) -> void:
	if not seed_db.is_seed_available(plant_id):
		SpeakScript.line("That seed is out of season.")
		if shed_ui and shed_ui.has_method("clear_selection"):
			shed_ui.call("clear_selection")
		return
	if garden.plant_bed(bed_id, plant_id):
		GardenSfxScript.plant()
		Events.plant_planted.emit(bed_id, 0, plant_id)
		var pname := seed_db.display_name(plant_id)
		SpeakScript.line("You planted %s seeds!" % pname)
		print("Garden Explorer: planted %s in %s (bed)" % [plant_id, bed_id])
	else:
		SpeakScript.line("This garden box is full.")

func _do_water_bed(bed_id: String) -> void:
	var result := garden.water_bed(bed_id, seed_db)
	if bool(result.get("ok", false)):
		GardenSfxScript.water()
		_play_water_anim(bed_id)
		Events.plant_watered.emit(bed_id, 0, str(result.plant_id), str(result.stage))
		SpeakScript.line("You watered the bed.")
		print("Garden Explorer: watered bed %s → %s" % [bed_id, result.stage])
	elif bool(result.get("not_thirsty", false)):
		SpeakScript.soft("This bed is not thirsty right now.")
	else:
		SpeakScript.soft("Nothing to water yet. Get seeds from the shed and plant them.")

func _do_uproot_bed(bed_id: String) -> void:
	NarratorScript.stop()
	var removed := garden.uproot_bed(bed_id)
	_uproot_armed_bed = ""
	if removed.is_empty():
		SpeakScript.line("No plants here. Get seeds from the shed to plant some.")
		return
	GardenSfxScript.uproot()
	Events.plant_uprooted.emit(bed_id, 0, removed)
	SpeakScript.line("You uprooted the %s." % seed_db.display_name(removed))
	print("Garden Explorer: uprooted bed %s (%s)" % [bed_id, removed])

func _play_water_anim(bed_id: String) -> void:
	## Watering can rises, tilts, and streams a few droplets over the bed.
	if _water_anim and is_instance_valid(_water_anim):
		_water_anim.queue_free()
	var center: Vector2 = farm_map.bed_centers.get(bed_id, player.global_position if player else Vector2.ZERO)
	var n := Node2D.new()
	n.name = "WaterAnim"
	n.z_index = 80
	add_child(n)
	_water_anim = n
	var can := Sprite2D.new()
	can.centered = true
	can.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists("res://assets/ui/carry_watering_can.png"):
		can.texture = load("res://assets/ui/carry_watering_can.png")
	elif FileAccess.file_exists("res://assets/ui/carry_watering_can.png"):
		var img := Image.load_from_file("res://assets/ui/carry_watering_can.png")
		if img:
			can.texture = ImageTexture.create_from_image(img)
	can.scale = Vector2(0.28, 0.28)
	can.position = center + Vector2(0, -FarmMap.BED_HEIGHT - 20)
	n.add_child(can)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(can, "position", can.position + Vector2(0, -18), 0.25)
	tw.tween_property(can, "rotation_degrees", -55.0, 0.35)
	tw.chain().tween_callback(func() -> void:
		for i in 6:
			var drop := Polygon2D.new()
			drop.color = Color(0.35, 0.65, 1.0, 0.85)
			drop.polygon = PackedVector2Array([Vector2(0, -4), Vector2(3, 2), Vector2(0, 6), Vector2(-3, 2)])
			drop.position = can.global_position + Vector2(14, 10) + Vector2(randf_range(-6, 6), 0)
			n.add_child(drop)
			var dtw := create_tween()
			dtw.tween_property(drop, "position", drop.position + Vector2(0, 28), 0.35)
			dtw.parallel().tween_property(drop, "modulate:a", 0.0, 0.35)
	)
	tw.chain().tween_interval(0.45)
	tw.tween_callback(func() -> void:
		if is_instance_valid(n):
			n.queue_free()
		if _water_anim == n:
			_water_anim = null
	)

func _handle_animal_tap(animal_id: String) -> void:
	## Legacy hook — prefer arrive→prompt path.
	_queue_interact("animal", animal_id, farm_map.animal_positions.get(animal_id, farm_map.fence_center))

func _current_tool() -> String:
	if tool_bar and tool_bar.has_method("get_tool"):
		return str(tool_bar.call("get_tool"))
	return tool_id

func _show_coop_look() -> void:
	## Peek in the coop: egg-collecting video with our narration.
	print("Garden Explorer: coop look")
	var dur := SpeakScript.line("Let's peek inside the chicken coop!")
	await get_tree().create_timer(maxf(dur, 0.5)).timeout
	if video_panel == null:
		video_panel = get_tree().get_first_node_in_group("video_panel")
	var played := false
	if video_panel and video_panel.has_method("play_star"):
		played = bool(video_panel.call("play_star", "coop_eggs", "coop_eggs.ogv", "Collecting eggs"))
	if not played:
		SpeakScript.line("Chickens lay their eggs in cozy nesting boxes. Farmers collect them every morning!")

func _do_harvest_bed(bed_id: String) -> void:
	_harvest_armed_bed = ""
	var pid := garden.harvest_bed(bed_id)
	if pid.is_empty():
		return
	## One bed harvest counts as four plants of that type.
	var yield_n := garden.slots_per_bed
	harvest_totals[pid] = int(harvest_totals.get(pid, 0)) + yield_n
	var total := int(harvest_totals[pid])
	GardenSfxScript.harvest()
	Events.plant_harvested.emit(pid, total)
	print("Garden Explorer: harvest bed %s — %s total %d" % [bed_id, pid, total])
	var save := _save()
	var first: bool = save != null and save.has_method("has_flag") and not save.has_flag("harvest_first:%s" % pid)
	if first:
		save.set_flag("harvest_first:%s" % pid, true)
		_run_first_harvest_ceremony(pid)
	else:
		SpeakScript.line("You harvested the %s!" % seed_db.display_name(pid))
	if shed_ui and shed_ui.has_method("set_harvest_totals"):
		shed_ui.call("set_harvest_totals", harvest_totals)

func _run_first_harvest_ceremony(pid: String) -> void:
	## Freeze (narration lock + fullscreen panels) → celebrate → plant grid
	## gold unlock → real harvest video / educational slides → resume.
	var pname := seed_db.display_name(pid)
	var dur := SpeakScript.line("You harvested your first %s!" % pname)
	await get_tree().create_timer(maxf(dur, 1.0)).timeout
	var save := _save()
	if save and save.has_method("set_harvest_totals"):
		save.set_harvest_totals(harvest_totals)
	if plant_grid and plant_grid.has_method("show_unlock"):
		plant_grid.call("show_unlock", pid, harvest_totals)
		await plant_grid.grid_closed
	_offer_plant_media(pid, "harvest", true)

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
	## Season only changes shed seeds + farm tint/VO. Plants already in beds stay
	## until the kid harvests or uses the spade — never auto-cleared here.
	farm_map.apply_season_tint(season_id)
	Events.season_changed.emit(season_id)
	## Drop held seed if it is out of season (hand only — not planted beds).
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
		## A new year begins each spring (cycle wrap).
		var year := 1
		if save:
			year = int(save.year)
			if seed_db.season_order.size() > 0 and season_id == str(seed_db.season_order[0]):
				year += 1
				save.set_year(year)
		if season_card and season_card.has_method("show_season"):
			season_card.call("show_season", season_id, label, year)
			await season_card.card_closed
			SpeakScript.line("New seeds are in the shed.")
		else:
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

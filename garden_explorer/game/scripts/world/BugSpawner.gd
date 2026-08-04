class_name BugSpawner
extends Node2D
## Spawns roaming bugs at habitat-weighted spots: garden beds (crop-weighted),
## pen/coop (soil critters), shed (shade dwellers), open grass.

const RoamingBugScript := preload("res://scripts/world/RoamingBug.gd")

const MAX_ACTIVE := 2
const SPAWN_MIN_SEC := 20.0
const SPAWN_MAX_SEC := 45.0

## Habitat → bug id weight boosts (besides bed crop weighting).
const HABITAT_BUGS := {
	"pen": ["rolly_polly", "earthworm", "ant", "grasshopper"],
	"coop": ["rolly_polly", "ant", "spider"],
	"shed": ["spider", "rolly_polly", "ant", "snail"],
	"grass": ["grasshopper", "butterfly", "honeybee", "ant", "ladybug", "praying_mantis"],
	"bed": [], ## crop-weighted via BugCatalog
}

var farm_map: FarmMap
var bug_db: RefCounted
var sprites: FarmSprites
var garden: GardenState
var _timer: float = 8.0
var _active: Dictionary = {} ## instance_id -> RoamingBug

func setup(map: FarmMap, bugs: RefCounted, art: FarmSprites, garden_state: GardenState) -> void:
	farm_map = map
	bug_db = bugs
	sprites = art
	garden = garden_state
	_timer = randf_range(6.0, 14.0)

func active_bugs() -> Array:
	var out: Array = []
	for k in _active.keys():
		var b: Node = _active[k]
		if b and is_instance_valid(b):
			out.append(b)
	return out

func bug_at(world_pos: Vector2, radius: float = 30.0) -> Node2D:
	var best: Node2D = null
	var best_d := radius
	for b in active_bugs():
		var d: float = world_pos.distance_to((b as Node2D).global_position)
		if d <= best_d:
			best_d = d
			best = b
	return best

func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = randf_range(SPAWN_MIN_SEC, SPAWN_MAX_SEC)
	if active_bugs().size() >= MAX_ACTIVE:
		return
	_spawn_one()

func force_spawn(bid: String, near: Vector2) -> Node2D:
	## Deterministic spawn for demos/tests: place a known bug at a walkable spot.
	if farm_map == null or bug_db == null:
		return null
	var bug: Dictionary = bug_db.get_bug(bid)
	if bug.is_empty():
		return null
	var spot := farm_map.nearest_walkable(near)
	if farm_map.has_method("nearest_bug_walkable"):
		spot = farm_map.nearest_bug_walkable(near)
	elif farm_map.has_method("is_blocked_for_bug") and farm_map.is_blocked_for_bug(spot):
		spot = farm_map.nearest_walkable(near + Vector2(0, 64))
	var tex: Texture2D = null
	if sprites and sprites.has_method("bug_sprite"):
		tex = sprites.bug_sprite(bid)
	if tex == null and sprites and sprites.has_method("portrait_texture"):
		tex = sprites.portrait_texture(str(bug.get("portrait", "")))
	var actor: Node2D = RoamingBugScript.new()
	actor.name = "Bug_%s_%d" % [bid, Time.get_ticks_msec()]
	add_child(actor)
	actor.setup(bid, tex, spot, 22.0, farm_map)
	_active[actor.get_instance_id()] = actor
	actor.despawned.connect(func(_id: String) -> void:
		_active.erase(actor.get_instance_id()))
	return actor

func _spawn_one() -> void:
	if farm_map == null or bug_db == null:
		return
	var habitat := _pick_habitat()
	var spot := _habitat_spot(habitat)
	var bug := _pick_bug(habitat)
	if bug.is_empty():
		return
	var bid := str(bug.get("id", ""))
	var tex: Texture2D = null
	if sprites and sprites.has_method("bug_sprite"):
		tex = sprites.bug_sprite(bid)
	if tex == null and sprites and sprites.has_method("portrait_texture"):
		tex = sprites.portrait_texture(str(bug.get("portrait", "")))
	var actor: Node2D = RoamingBugScript.new()
	actor.name = "Bug_%s_%d" % [bid, Time.get_ticks_msec()]
	add_child(actor)
	actor.setup(bid, tex, spot, 22.0, farm_map)
	_active[actor.get_instance_id()] = actor
	actor.despawned.connect(func(_id: String) -> void:
		_active.erase(actor.get_instance_id()))
	print("Garden Explorer: bug_spawn:%s at %s" % [bid, habitat])

func _pick_habitat() -> String:
	## Beds are the star: 6 beds vs one of each other habitat.
	var pool := ["bed", "bed", "bed", "grass", "grass", "pen", "coop", "shed"]
	return pool[randi() % pool.size()]

func _habitat_spot(habitat: String) -> Vector2:
	match habitat:
		"bed":
			var ids := farm_map.bed_ids()
			if ids.size() > 0:
				var bid := ids[randi() % ids.size()]
				var c: Vector2 = farm_map.bed_centers.get(bid, farm_map.spawn_world)
				## Clear of the raised lip (south rim) so bugs aren't under the wood.
				var rim := farm_map.nearest_walkable(c + Vector2(randf_range(-40, 40), randf_range(56, 78)))
				if farm_map.has_method("is_blocked_for_bug") and farm_map.is_blocked_for_bug(rim):
					rim = farm_map.nearest_walkable(c + Vector2(0, 72))
				return rim
			return farm_map.spawn_world
		"pen":
			return farm_map.nearest_walkable(farm_map.fence_center + Vector2(randf_range(-50, 50), randf_range(-20, 40)))
		"coop":
			return farm_map.nearest_walkable(farm_map.fence_center + Vector2(randf_range(-40, 10), randf_range(-70, -40)))
		"shed":
			return farm_map.nearest_walkable(farm_map.shed_center + Vector2(randf_range(30, 70), randf_range(10, 50)))
		_:
			return farm_map.nearest_walkable(farm_map.spawn_world + Vector2(randf_range(-160, 200), randf_range(-90, 120)))

func _pick_bug(habitat: String) -> Dictionary:
	## Beds: reuse crop weighting. Others: choose among habitat natives.
	if habitat == "bed" and garden:
		var plants := PackedStringArray()
		for bid in farm_map.bed_ids():
			for s in 4:
				var st := garden.get_slot(bid, s)
				var pid := str(st.get("plant_id", ""))
				if not pid.is_empty():
					plants.append(pid)
		return bug_db.pick_weighted(plants)
	var natives: Array = HABITAT_BUGS.get(habitat, [])
	if natives.is_empty():
		return bug_db.pick_weighted(PackedStringArray())
	var bid2 := str(natives[randi() % natives.size()])
	var d: Dictionary = bug_db.get_bug(bid2)
	return d if not d.is_empty() else bug_db.pick_weighted(PackedStringArray())

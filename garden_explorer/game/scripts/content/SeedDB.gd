class_name SeedDB
extends RefCounted
## Loads seeds.json + seasons.json; answers seasonal inventory.

const SEEDS_PATH := "res://data/seeds.json"
const SEASONS_PATH := "res://data/seasons.json"

var plants: Dictionary = {} ## id -> Dictionary
var plant_order: PackedStringArray = PackedStringArray()
var seasons: Dictionary = {}
var season_order: PackedStringArray = PackedStringArray()
var current_season: String = "spring"
var season_duration_sec: float = 180.0

func load_all() -> void:
	plants.clear()
	plant_order.clear()
	var seeds_raw := FileAccess.get_file_as_string(SEEDS_PATH)
	var seeds_data: Dictionary = JSON.parse_string(seeds_raw)
	for p in seeds_data.get("plants", []):
		var d: Dictionary = p
		var id := str(d.get("id", ""))
		if id.is_empty():
			continue
		plants[id] = d
		plant_order.append(id)
	var seasons_raw := FileAccess.get_file_as_string(SEASONS_PATH)
	var seasons_data: Dictionary = JSON.parse_string(seasons_raw)
	seasons = seasons_data.get("seasons", {})
	season_duration_sec = float(seasons_data.get("season_duration_sec", 180))
	season_order.clear()
	for s in seasons_data.get("season_order", ["spring", "summer", "fall", "winter"]):
		season_order.append(str(s))
	if not season_order.is_empty():
		current_season = season_order[0]

func set_season(season_id: String) -> void:
	if seasons.has(season_id):
		current_season = season_id

func season_index() -> int:
	return season_order.find(current_season)

func season_label(season_id: String = "") -> String:
	var sid := season_id if not season_id.is_empty() else current_season
	var season: Dictionary = seasons.get(sid, {})
	return str(season.get("label", sid.capitalize()))

func next_season_id() -> String:
	if season_order.is_empty():
		return current_season
	var i := season_index()
	if i < 0:
		return season_order[0]
	return season_order[(i + 1) % season_order.size()]

func advance_season() -> String:
	var nxt := next_season_id()
	set_season(nxt)
	return current_season

func is_seed_available(plant_id: String, season_id: String = "") -> bool:
	return available_seed_ids(season_id).has(plant_id)

func get_plant(plant_id: String) -> Dictionary:
	return plants.get(plant_id, {})

func display_name(plant_id: String) -> String:
	return str(get_plant(plant_id).get("name", plant_id))

func available_seed_ids(season_id: String = "") -> PackedStringArray:
	var sid := season_id if not season_id.is_empty() else current_season
	var out: PackedStringArray = PackedStringArray()
	var season: Dictionary = seasons.get(sid, {})
	for id in season.get("seed_ids", []):
		var pid := str(id)
		if plants.has(pid):
			out.append(pid)
	return out

func media_path(plant_id: String, kind: String) -> String:
	var media: Dictionary = get_plant(plant_id).get("media", {})
	var entry: Dictionary = media.get(kind, {})
	var file := str(entry.get("file", ""))
	if file.is_empty():
		return ""
	return "res://assets/plants/%s" % file

func media_type(plant_id: String, kind: String) -> String:
	var media: Dictionary = get_plant(plant_id).get("media", {})
	var entry: Dictionary = media.get(kind, {})
	return str(entry.get("type", "video"))

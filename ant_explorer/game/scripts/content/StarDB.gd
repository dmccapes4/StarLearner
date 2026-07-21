class_name StarDB
extends RefCounted
## Loads data/stars.json — one star per zone in Phase 2.

const PATH := "res://data/stars.json"

var by_zone: Dictionary = {}  ## zone -> star dict
var by_id: Dictionary = {}
var stars_ordered: Array = []  ## file order for StarProgress

func load_db() -> void:
	by_zone.clear()
	by_id.clear()
	stars_ordered.clear()
	if not FileAccess.file_exists(PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var stars: Array = (parsed as Dictionary).get("stars", [])
	for s in stars:
		var id := str(s.get("id", ""))
		var zone := str(s.get("zone", ""))
		by_id[id] = s
		by_zone[zone] = s
		stars_ordered.append(s)

func star_for_zone(zone: String) -> Dictionary:
	return by_zone.get(zone, {}) as Dictionary

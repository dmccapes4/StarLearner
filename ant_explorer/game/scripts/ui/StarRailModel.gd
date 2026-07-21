class_name StarRailModel
extends RefCounted
## Read model for the star rails: tile state (from Save), friendly place labels
## for guidance VO, kid-short topic names for the watch prompt, and icon paths.
## Pure data + string building so it can be unit-tested headless.

const TILE_UNDISCOVERED := 0
const TILE_COLLECTED := 1

const ICON_DIR := "res://assets/ui/star_tiles"
const RAIL_VO_PATH := "res://data/star_rail_vo.json"

## zone (stars.json) -> kid-friendly place name for guidance VO.
const PLACE_LABELS := {
	"queen": "queen's room",
	"nursery": "nursery",
	"pupae": "pupa room",
	"garden_a": "fungus garden",
	"surface": "sunny outside",
	"entrance": "doorway",
	"outpost": "soldier lookout",
	"dump": "dump",
	"garden_b": "busy garden",
	"hygiene": "cleaning room",
	"deep": "deep tunnels",
	"invasion": "invasion clearing",
}

## kid-short topic names for "Tap again to watch the {X} video."
const TOPIC_SHORT := {
	"01_queen": "queen",
	"02_larvae": "baby ant",
	"03_pupae": "growing up",
	"04_fungus": "mushroom garden",
	"05_forage": "leaf cutter",
	"06_pheromone": "ant talk",
	"07_soldiers": "soldier ant",
	"08_waste": "clean up crew",
	"09_labor": "teamwork",
	"10_bacteria": "tiny helpers",
	"11_architecture": "ant tunnels",
	"12_invaders": "brave ants",
}

var _db: StarDB
var _vo_lines: Dictionary = {}  ## star_id -> {"line": String, "place": String}

func _init(db: StarDB = null) -> void:
	if db != null:
		_db = db
	else:
		_db = StarDB.new()
		_db.load_db()
	_load_vo_lines()

static func state_for(collected: bool) -> int:
	return TILE_COLLECTED if collected else TILE_UNDISCOVERED

func tile_state(star_id: String) -> int:
	return state_for(Save.has_star(star_id))

func zone_for(star_id: String) -> String:
	var e: Dictionary = _db.by_id.get(star_id, {}) as Dictionary
	return str(e.get("zone", ""))

func place_label(star_id: String) -> String:
	# Prefer an explicit override from data/star_rail_vo.json, then the zone map.
	var entry: Dictionary = _vo_lines.get(star_id, {}) as Dictionary
	var override := str(entry.get("place", ""))
	if not override.is_empty():
		return override
	var zone := zone_for(star_id)
	return str(PLACE_LABELS.get(zone, zone))

func guidance_line(star_id: String) -> String:
	var entry: Dictionary = _vo_lines.get(star_id, {}) as Dictionary
	var line := str(entry.get("line", ""))
	if not line.is_empty():
		return line
	return "Explore the %s and look for the golden star!" % place_label(star_id)

func topic_short(star_id: String) -> String:
	if TOPIC_SHORT.has(star_id):
		return str(TOPIC_SHORT[star_id])
	var e: Dictionary = _db.by_id.get(star_id, {}) as Dictionary
	return str(e.get("topic", star_id))

func watch_prompt(star_id: String) -> String:
	return "Tap again to watch the %s video." % topic_short(star_id)

func file_for(star_id: String) -> String:
	var e: Dictionary = _db.by_id.get(star_id, {}) as Dictionary
	return str(e.get("file", ""))

func icon_path(star_id: String) -> String:
	var path := "%s/%s.png" % [ICON_DIR, star_id]
	if ResourceLoader.exists(path) or FileAccess.file_exists(path):
		return path
	return ""

func _load_vo_lines() -> void:
	_vo_lines.clear()
	if not FileAccess.file_exists(RAIL_VO_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(RAIL_VO_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var stars: Dictionary = (parsed as Dictionary).get("stars", {}) as Dictionary
	for sid in stars:
		_vo_lines[str(sid)] = stars[sid]

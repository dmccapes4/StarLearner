class_name StarDB
extends RefCounted
## Loads stars.json — 12 knowledge stars + intro metadata.

const STARS_PATH := "res://data/stars.json"
const STARS_DIR := "res://stars/"

var stars: Array = [] ## Array[Dictionary]
var by_id: Dictionary = {} ## id -> Dictionary
var intro: Dictionary = {}

func load_all() -> void:
	stars.clear()
	by_id.clear()
	intro.clear()
	var raw := FileAccess.get_file_as_string(STARS_PATH)
	var data: Dictionary = JSON.parse_string(raw)
	for s in data.get("stars", []):
		var d: Dictionary = s
		var id := str(d.get("id", ""))
		if id.is_empty():
			continue
		stars.append(d)
		by_id[id] = d
	intro = data.get("intro", {})

func star_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for s in stars:
		out.append(str(s.get("id", "")))
	return out

func get_star(star_id: String) -> Dictionary:
	return by_id.get(star_id, {})

func topic(star_id: String) -> String:
	return str(get_star(star_id).get("topic", star_id))

func zone(star_id: String) -> String:
	return str(get_star(star_id).get("zone", "beds"))

func reveal_rule(star_id: String) -> String:
	return str(get_star(star_id).get("reveal", "always"))

func file_name(star_id: String) -> String:
	return str(get_star(star_id).get("file", "%s.ogv" % star_id))

func intro_file() -> String:
	return str(intro.get("file", "intro.ogv"))

static func resolve_video_path(file_name: String) -> String:
	## Godot Mobile/Theora expects .ogv under res://stars/.
	var base := file_name.get_file()
	if base.is_empty():
		return ""
	if not base.ends_with(".ogv"):
		base = base.get_basename() + ".ogv"
	var path := STARS_DIR.path_join(base)
	if ResourceLoader.exists(path) or FileAccess.file_exists(path):
		return path
	return ""

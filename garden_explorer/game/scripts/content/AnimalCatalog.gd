class_name AnimalCatalog
extends RefCounted
## Named farm animals + portrait / video metadata.

const PATH := "res://data/animals.json"

var animals: Array = []
var by_id: Dictionary = {}

func load_all() -> void:
	animals.clear()
	by_id.clear()
	var raw := FileAccess.get_file_as_string(PATH)
	if raw.is_empty():
		return
	var data: Dictionary = JSON.parse_string(raw)
	for a in data.get("animals", []):
		var d: Dictionary = a
		var id := str(d.get("id", ""))
		if id.is_empty():
			continue
		animals.append(d)
		by_id[id] = d

func get_animal(animal_id: String) -> Dictionary:
	return by_id.get(animal_id, {})

func display_name(animal_id: String) -> String:
	var d := get_animal(animal_id)
	return str(d.get("name", animal_id.capitalize()))

func kind_of(animal_id: String) -> String:
	var d := get_animal(animal_id)
	if not d.is_empty():
		return str(d.get("kind", ""))
	var id := animal_id.to_lower()
	if id.begins_with("chicken"):
		return "chicken"
	if id.begins_with("cow"):
		return "cow"
	if id.begins_with("pig"):
		return "pig"
	if id.begins_with("rabbit"):
		return "rabbit"
	if id.begins_with("dog"):
		return "dog"
	return "chicken"

func in_pen(animal_id: String) -> bool:
	var d := get_animal(animal_id)
	if d.is_empty():
		return not animal_id.begins_with("dog")
	return bool(d.get("pen", true))

func scale_of(animal_id: String) -> float:
	var d := get_animal(animal_id)
	return float(d.get("scale", 3.5))

func color_of(animal_id: String) -> String:
	return str(get_animal(animal_id).get("color", "default"))

func portrait_path(animal_id: String) -> String:
	return str(get_animal(animal_id).get("portrait", ""))

func video_file(animal_id: String) -> String:
	return str(get_animal(animal_id).get("video", ""))

func pronoun(animal_id: String) -> String:
	var g := str(get_animal(animal_id).get("gender", "f"))
	return "He" if g == "m" else "She"

func tap_line(animal_id: String) -> String:
	## Upbeat pet intro — these are gardener girl's beloved friends.
	var d := get_animal(animal_id)
	if d.has("tap_line"):
		return str(d["tap_line"])
	var n := display_name(animal_id)
	var k := kind_of(animal_id)
	return "This is %s! %s is a %s. Tap to learn more about %ss on farms." % [n, pronoun(animal_id), k, k]

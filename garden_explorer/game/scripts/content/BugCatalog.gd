class_name BugCatalog
extends RefCounted
## 12 garden bugs weighted by crops actually planted in a bed.

const PATH := "res://data/bugs.json"

var bugs: Array = []
var by_id: Dictionary = {}

func load_all() -> void:
	bugs.clear()
	by_id.clear()
	var raw := FileAccess.get_file_as_string(PATH)
	if raw.is_empty():
		return
	var data: Dictionary = JSON.parse_string(raw)
	for b in data.get("bugs", []):
		var d: Dictionary = b
		var id := str(d.get("id", ""))
		if id.is_empty():
			continue
		bugs.append(d)
		by_id[id] = d

func get_bug(bug_id: String) -> Dictionary:
	return by_id.get(bug_id, {})

func pick_weighted(plant_ids: PackedStringArray, rng: RandomNumberGenerator = null) -> Dictionary:
	## Semi-random: base_weight + bonus per matching plant in the bed.
	## Empty beds favor soil critters (rolly / worm) via base weights.
	if bugs.is_empty():
		return {}
	var r := rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		r.randomize()
	var plants := {}
	for p in plant_ids:
		plants[str(p)] = true
	var weights: Array = []
	var total := 0.0
	for b in bugs:
		var d: Dictionary = b
		var w := float(d.get("base_weight", 1.0))
		var matched := 0
		for pid in d.get("plants", []):
			if plants.has(str(pid)):
				matched += 1
		if matched > 0:
			w += float(matched) * 1.35
		## Empty bed: boost decomposers a little.
		if plant_ids.is_empty():
			var id := str(d.get("id", ""))
			if id in ["rolly_polly", "earthworm", "ant", "spider"]:
				w += 0.8
		weights.append(w)
		total += w
	if total <= 0.0:
		return bugs[r.randi() % bugs.size()]
	var roll := r.randf() * total
	var acc := 0.0
	for i in bugs.size():
		acc += float(weights[i])
		if roll <= acc:
			return bugs[i]
	return bugs[bugs.size() - 1]

extends Node
## Persist beds, season, harvest, stars, intro — wipe via kiosk EXTRA_WIPE_SAVE.

const SAVE_PATH := "user://garden_explorer_save.json"
const WIPE_FLAG := "user://.antphone_wipe"

var dirty: bool = false
var stars_collected: PackedStringArray = PackedStringArray()
var intro_completed: bool = false
var flags: Dictionary = {}
var season_id: String = "spring"
var season_elapsed: float = 0.0
var harvest_totals: Dictionary = {} ## plant_id -> int
var beds_blob: Dictionary = {} ## bed_id -> Array[slot dict]
var tool_id: String = "water"

func _ready() -> void:
	if FileAccess.file_exists(WIPE_FLAG):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(WIPE_FLAG))
		_delete(SAVE_PATH)
		_reset()
		return
	_apply_blob(load_save())

func load_save() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func _apply_blob(blob: Dictionary) -> void:
	stars_collected = PackedStringArray()
	for s in blob.get("stars_collected", []):
		stars_collected.append(str(s))
	intro_completed = bool(blob.get("intro_completed", false))
	flags = {}
	var raw_flags = blob.get("flags", {})
	if typeof(raw_flags) == TYPE_DICTIONARY:
		for k in raw_flags.keys():
			flags[str(k)] = bool(raw_flags[k])
	season_id = str(blob.get("season_id", "spring"))
	season_elapsed = float(blob.get("season_elapsed", 0.0))
	harvest_totals = {}
	var ht = blob.get("harvest_totals", {})
	if typeof(ht) == TYPE_DICTIONARY:
		for k in ht.keys():
			harvest_totals[str(k)] = int(ht[k])
	beds_blob = {}
	var bb = blob.get("beds", {})
	if typeof(bb) == TYPE_DICTIONARY:
		beds_blob = bb.duplicate(true)
	tool_id = str(blob.get("tool_id", "water"))

func mark_dirty() -> void:
	dirty = true

func save_if_dirty() -> void:
	if not dirty:
		return
	var blob := {
		"version": 2,
		"stars_collected": Array(stars_collected),
		"intro_completed": intro_completed,
		"flags": flags.duplicate(),
		"season_id": season_id,
		"season_elapsed": season_elapsed,
		"harvest_totals": harvest_totals.duplicate(),
		"beds": beds_blob.duplicate(true),
		"tool_id": tool_id,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Save: cannot write %s" % SAVE_PATH)
		return
	f.store_string(JSON.stringify(blob, "\t"))
	dirty = false

func has_star(id: String) -> bool:
	return stars_collected.has(id)

func collect_star(id: String) -> bool:
	if has_star(id):
		return false
	stars_collected.append(id)
	mark_dirty()
	save_if_dirty()
	return true

func set_intro_completed(done: bool = true) -> void:
	if intro_completed == done:
		return
	intro_completed = done
	mark_dirty()
	save_if_dirty()

func has_flag(flag: String) -> bool:
	return bool(flags.get(flag, false))

func set_flag(flag: String, value: bool = true) -> bool:
	if bool(flags.get(flag, false)) == value:
		return false
	flags[flag] = value
	mark_dirty()
	save_if_dirty()
	return true

func set_season(sid: String, elapsed: float = 0.0) -> void:
	season_id = sid
	season_elapsed = elapsed
	mark_dirty()
	save_if_dirty()

func set_harvest_totals(totals: Dictionary) -> void:
	harvest_totals = totals.duplicate()
	mark_dirty()
	save_if_dirty()

func set_beds_blob(blob: Dictionary) -> void:
	beds_blob = blob.duplicate(true)
	mark_dirty()
	save_if_dirty()

func set_tool(id: String) -> void:
	tool_id = id
	mark_dirty()
	save_if_dirty()

func clear_all() -> void:
	_delete(SAVE_PATH)
	_reset()

func _reset() -> void:
	stars_collected = PackedStringArray()
	intro_completed = false
	flags.clear()
	season_id = "spring"
	season_elapsed = 0.0
	harvest_totals.clear()
	beds_blob.clear()
	tool_id = "water"
	dirty = false

func _delete(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

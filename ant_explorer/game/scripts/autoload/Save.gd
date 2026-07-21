extends Node
## Persistent progress for Ant Explorer (stars, rails, intro, last player spot).

const SAVE_PATH := "user://ant_explorer_save.json"

var dirty: bool = false
var stars_collected: PackedStringArray = PackedStringArray()
var rails_hidden: bool = false  ## default = rails shown so the goal is always visible
var intro_completed: bool = false
var player_x: float = NAN
var player_y: float = NAN

func _ready() -> void:
	var wipe_flag := "user://.antphone_wipe"
	if FileAccess.file_exists(wipe_flag):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(wipe_flag))
		if FileAccess.file_exists(SAVE_PATH):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
		stars_collected = PackedStringArray()
		rails_hidden = false
		intro_completed = false
		player_x = NAN
		player_y = NAN
		dirty = false
		return
	_apply_blob(load_save())

func _apply_blob(blob: Dictionary) -> void:
	if blob.has("stars_collected"):
		var arr: Array = blob["stars_collected"]
		stars_collected = PackedStringArray()
		for s in arr:
			stars_collected.append(str(s))
	if blob.has("rails_hidden"):
		rails_hidden = bool(blob["rails_hidden"])
	if blob.has("intro_completed"):
		intro_completed = bool(blob["intro_completed"])
	if blob.has("player_x") and blob.has("player_y"):
		player_x = float(blob["player_x"])
		player_y = float(blob["player_y"])

func has_star(id: String) -> bool:
	return stars_collected.has(id)

func collect_star(id: String) -> bool:
	if has_star(id):
		return false
	stars_collected.append(id)
	mark_dirty()
	save_if_dirty()
	return true

func are_rails_hidden() -> bool:
	return rails_hidden

func set_rails_hidden(hidden: bool) -> bool:
	if rails_hidden == hidden:
		return false
	rails_hidden = hidden
	mark_dirty()
	save_if_dirty()
	return true

func set_intro_completed(done: bool = true) -> void:
	if intro_completed == done:
		return
	intro_completed = done
	mark_dirty()
	save_if_dirty()

func has_player_pos() -> bool:
	return not is_nan(player_x) and not is_nan(player_y)

func player_pos() -> Vector2:
	return Vector2(player_x, player_y)

func set_player_pos(p: Vector2) -> void:
	player_x = p.x
	player_y = p.y
	mark_dirty()

func clear_all() -> void:
	stars_collected = PackedStringArray()
	rails_hidden = false
	intro_completed = false
	player_x = NAN
	player_y = NAN
	dirty = true
	save_if_dirty()

func mark_dirty() -> void:
	dirty = true

func save_if_dirty() -> void:
	if not dirty:
		return
	dirty = false
	var blob := {
		"version": 2,
		"stars_collected": Array(stars_collected),
		"rails_hidden": rails_hidden,
		"intro_completed": intro_completed,
	}
	if has_player_pos():
		blob["player_x"] = player_x
		blob["player_y"] = player_y
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Save: could not write %s" % SAVE_PATH)
		return
	f.store_string(JSON.stringify(blob))

func load_save() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed as Dictionary

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_if_dirty()

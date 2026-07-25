extends Node
## Persistent state for Math Explorer: which activities she has seen (so the
## launch tour + first-time tutorials fire only once), plus hidden per-activity
## stats. Cleared with the SAME mechanism as Ant Explorer — the Star Learner
## kiosk fires an EXTRA_WIPE_SAVE intent; our GodotApp deletes the save files and
## drops a one-shot `.antphone_wipe` flag, which we honour here on boot.
##
## Stats are recorded but not shown yet (no UI reads them). Keeping them in the
## save now means a future progress screen has real history to draw from.

const SAVE_PATH := "user://math_explorer_save.json"
const LEGACY_SEEN := "user://seen.cfg"  ## pre-Save flag store; imported once.
const WIPE_FLAG := "user://.antphone_wipe"

var dirty: bool = false
var intro_done: bool = false
var seen: Dictionary = {}      ## key -> true (tut_add, game_eggs, ...)
var stats: Dictionary = {}     ## see _stat_* helpers below

func _ready() -> void:
	if FileAccess.file_exists(WIPE_FLAG):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(WIPE_FLAG))
		_delete(SAVE_PATH)
		_delete(LEGACY_SEEN)
		_reset()
		return
	_load()

# ---- seen flags -------------------------------------------------------------

func was_seen(key: String) -> bool:
	return bool(seen.get(key, false))

func mark_seen(key: String) -> void:
	if was_seen(key):
		return
	seen[key] = true
	_mark_dirty()
	save_if_dirty()

func is_intro_done() -> bool:
	return intro_done

func set_intro_done(done: bool = true) -> void:
	if intro_done == done:
		return
	intro_done = done
	_mark_dirty()
	save_if_dirty()

# ---- hidden stats -----------------------------------------------------------

## One practice answer for an operation (add/sub/mul/div).
func record_practice_answer(op: String, correct: bool, streak: int) -> void:
	var b := _bucket("practice", op)
	b["seen"] = int(b.get("seen", 0)) + 1
	if correct:
		b["correct"] = int(b.get("correct", 0)) + 1
	else:
		b["wrong"] = int(b.get("wrong", 0)) + 1
	b["best_streak"] = maxi(int(b.get("best_streak", 0)), streak)
	_mark_dirty()
	save_if_dirty()

## An activity (tutorial or game) reached its end / a round completed.
func record_activity_finished(id: String) -> void:
	if id.is_empty():
		return
	var b := _bucket("activity", id)
	b["finished"] = int(b.get("finished", 0)) + 1
	_mark_dirty()
	save_if_dirty()

## An activity was opened / started.
func record_activity_started(id: String) -> void:
	if id.is_empty():
		return
	var b := _bucket("activity", id)
	b["started"] = int(b.get("started", 0)) + 1
	_mark_dirty()
	save_if_dirty()

func _bucket(group: String, id: String) -> Dictionary:
	if not stats.has(group):
		stats[group] = {}
	var g: Dictionary = stats[group]
	if not g.has(id):
		g[id] = {}
	return g[id]

# ---- lifecycle --------------------------------------------------------------

func clear_all() -> void:
	_delete(SAVE_PATH)
	_delete(LEGACY_SEEN)
	_reset()

func _reset() -> void:
	intro_done = false
	seen = {}
	stats = {}
	dirty = false

func _mark_dirty() -> void:
	dirty = true

func save_if_dirty() -> void:
	if not dirty:
		return
	dirty = false
	var blob := {
		"version": 1,
		"intro_done": intro_done,
		"seen": seen,
		"stats": stats,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Save: could not write %s" % SAVE_PATH)
		return
	f.store_string(JSON.stringify(blob))

func _load() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if f == null:
			return
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		if typeof(parsed) == TYPE_DICTIONARY:
			var blob: Dictionary = parsed
			intro_done = bool(blob.get("intro_done", false))
			seen = blob.get("seen", {}) if typeof(blob.get("seen")) == TYPE_DICTIONARY else {}
			stats = blob.get("stats", {}) if typeof(blob.get("stats")) == TYPE_DICTIONARY else {}
		return
	# First run after the update: import the old seen.cfg flags so returning
	# players are not re-shown tutorials / the launch tour they already know.
	_migrate_legacy_seen()

func _migrate_legacy_seen() -> void:
	if not FileAccess.file_exists(LEGACY_SEEN):
		return
	var cfg := ConfigFile.new()
	if cfg.load(LEGACY_SEEN) != OK:
		return
	if cfg.has_section("seen"):
		for key in cfg.get_section_keys("seen"):
			if key == "intro":
				intro_done = bool(cfg.get_value("seen", "intro", false))
			else:
				seen[key] = bool(cfg.get_value("seen", key, false))
	_mark_dirty()
	save_if_dirty()

func _delete(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_if_dirty()

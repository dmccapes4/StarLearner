extends Node
## Persistent state for Language Explorer: intro gate, language, letter-input
## mode, bookmarks, seen tutorials, and hidden stats. Cleared with the same
## kiosk mechanism as Math/Ant — EXTRA_WIPE_SAVE + user://.antphone_wipe.

const SAVE_PATH := "user://language_explorer_save.json"
const WIPE_FLAG := "user://.antphone_wipe"

var dirty: bool = false
var intro_done: bool = false
var lang: String = "en"
var letter_input: String = "alphabet"
var seen: Dictionary = {}
var bookmarks: Dictionary = {}
var stats: Dictionary = {}

func _ready() -> void:
	if FileAccess.file_exists(WIPE_FLAG):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(WIPE_FLAG))
		_delete(SAVE_PATH)
		_reset()
		return
	_load()

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

func get_lang() -> String:
	return lang

func set_lang(code: String) -> void:
	var next := "es" if code == "es" else "en"
	if lang == next:
		return
	lang = next
	_mark_dirty()
	save_if_dirty()

func get_letter_input() -> String:
	return letter_input

func set_letter_input(mode: String) -> void:
	var next := mode
	if next != "sketch" and next != "alphabet":
		next = "alphabet"
	if letter_input == next:
		return
	letter_input = next
	_mark_dirty()
	save_if_dirty()

func get_bookmark(book_id: String) -> int:
	return int(bookmarks.get(book_id, 0))

func set_bookmark(book_id: String, page: int) -> void:
	if book_id.is_empty():
		return
	bookmarks[book_id] = maxi(0, page)
	_mark_dirty()
	save_if_dirty()

func record_activity_started(id: String) -> void:
	if id.is_empty():
		return
	var b := _bucket("activity", id)
	b["started"] = int(b.get("started", 0)) + 1
	_mark_dirty()
	save_if_dirty()

func record_activity_finished(id: String) -> void:
	if id.is_empty():
		return
	var b := _bucket("activity", id)
	b["finished"] = int(b.get("finished", 0)) + 1
	_mark_dirty()
	save_if_dirty()

func _bucket(group: String, id: String) -> Dictionary:
	if not stats.has(group):
		stats[group] = {}
	var g: Dictionary = stats[group]
	if not g.has(id):
		g[id] = {}
	return g[id]

func clear_all() -> void:
	_delete(SAVE_PATH)
	_reset()

func _reset() -> void:
	intro_done = false
	lang = "en"
	letter_input = "alphabet"
	seen = {}
	bookmarks = {}
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
		"lang": lang,
		"letter_input": letter_input,
		"seen": seen,
		"bookmarks": bookmarks,
		"stats": stats,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Save: could not write %s" % SAVE_PATH)
		return
	f.store_string(JSON.stringify(blob))

func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var blob: Dictionary = parsed
	intro_done = bool(blob.get("intro_done", false))
	lang = "es" if str(blob.get("lang", "en")) == "es" else "en"
	var li := str(blob.get("letter_input", "alphabet"))
	letter_input = li if li == "sketch" or li == "alphabet" else "alphabet"
	seen = blob.get("seen", {}) if typeof(blob.get("seen")) == TYPE_DICTIONARY else {}
	bookmarks = blob.get("bookmarks", {}) if typeof(blob.get("bookmarks")) == TYPE_DICTIONARY else {}
	stats = blob.get("stats", {}) if typeof(blob.get("stats")) == TYPE_DICTIONARY else {}

func _delete(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_if_dirty()

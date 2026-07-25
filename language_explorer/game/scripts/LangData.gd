class_name LangData
extends RefCounted
## Lightweight catalogs for Phase 1+. JSON under res://data/ is the source of truth.

static func load_json_array(path: String) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return []
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_ARRAY:
		return []
	return parsed

static func sentences() -> Array:
	return load_json_array("res://data/sentences.json")

static func words() -> Array:
	return load_json_array("res://data/words.json")

static func books() -> Array:
	return load_json_array("res://data/books.json")

static func tutorials() -> Array:
	return load_json_array("res://data/tutorials.json")

static func load_json_dict(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed

## Shipped books only. Pass "" for any language.
static func books_shipped(lang: String = "") -> Array:
	var out: Array = []
	for row in books():
		if not bool(row.get("ship", false)):
			continue
		if lang != "" and str(row.get("lang", "")) != lang:
			continue
		out.append(row)
	return out

static func book_by_id(book_id: String) -> Dictionary:
	for row in books():
		if str(row.get("id", "")) == book_id:
			# Prefer per-book meta.json when present (richer notes).
			var meta_path := "res://books/%s/meta.json" % book_id
			var meta := load_json_dict(meta_path)
			if not meta.is_empty():
				return meta
			return row
	return {}

static func load_page(path: String) -> Dictionary:
	return load_json_dict(path)

static func tutorial_by_id(tutorial_id: String) -> Dictionary:
	for row in tutorials():
		if str(row.get("id", "")) == tutorial_id:
			return row
	return {}

static func sentences_for_lang(lang: String) -> Array:
	var out: Array = []
	for row in sentences():
		if str(row.get("lang", "")) == lang:
			out.append(row)
	return out

static func words_for_lang(lang: String) -> Array:
	var out: Array = []
	for row in words():
		if str(row.get("lang", "")) == lang:
			out.append(row)
	return out

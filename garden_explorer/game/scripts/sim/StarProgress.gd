class_name StarProgress
extends RefCounted
## Reveal rules + collection helpers for the 12 knowledge stars.

const FLAG_PLANTED := "planted_once"
const FLAG_WATERED := "watered_once"
const FLAG_SPROUT := "sprout_seen"
const FLAG_GROWING := "growing_seen"
const FLAG_UPROOTED := "uprooted_once"
const FLAG_HARVESTED := "harvested_once"
const FLAG_SEASON := "season_changed"
const FLAG_STORED := "stored_once"

var star_db ## StarDB
var _save: Object

func setup(db, save_node: Object = null) -> void:
	star_db = db
	_save = save_node

func bind_events(ev: Node) -> void:
	if ev == null:
		return
	if ev.has_signal("plant_planted") and not ev.plant_planted.is_connected(_on_planted):
		ev.plant_planted.connect(_on_planted)
	if ev.has_signal("plant_watered") and not ev.plant_watered.is_connected(_on_watered):
		ev.plant_watered.connect(_on_watered)
	if ev.has_signal("plant_stage_changed") and not ev.plant_stage_changed.is_connected(_on_stage):
		ev.plant_stage_changed.connect(_on_stage)
	if ev.has_signal("plant_uprooted") and not ev.plant_uprooted.is_connected(_on_uprooted):
		ev.plant_uprooted.connect(_on_uprooted)
	if ev.has_signal("plant_harvested") and not ev.plant_harvested.is_connected(_on_harvested):
		ev.plant_harvested.connect(_on_harvested)
	if ev.has_signal("season_changed") and not ev.season_changed.is_connected(_on_season):
		ev.season_changed.connect(_on_season)

func is_revealed(star_id: String) -> bool:
	var rule: String = star_db.reveal_rule(star_id) if star_db else "always"
	if rule == "always":
		return true
	if rule.begins_with("gameplay:"):
		return _has_flag(rule.trim_prefix("gameplay:"))
	return false

func is_collected(star_id: String) -> bool:
	return _save != null and _save.has_method("has_star") and bool(_save.has_star(star_id))

func collect(star_id: String) -> bool:
	if _save == null or not _save.has_method("collect_star"):
		return false
	if not bool(_save.collect_star(star_id)):
		return false
	return true

func unlock_hint(star_id: String) -> String:
	var rule: String = star_db.reveal_rule(star_id) if star_db else ""
	match rule:
		"gameplay:planted_once":
			return "Plant a seed in a garden bed to unlock this star."
		"gameplay:watered_once":
			return "Water a plant to unlock this star."
		"gameplay:sprout_seen":
			return "Watch a seed sprout to unlock this star."
		"gameplay:growing_seen":
			return "Help a plant grow bigger to unlock this star."
		"gameplay:uprooted_once":
			return "Uproot a plant to unlock this star."
		"gameplay:harvested_once":
			return "Harvest a grown plant to unlock this star."
		"gameplay:season_changed":
			return "Wait for the season to change to unlock this star."
		"gameplay:stored_once":
			return "Harvest something into the shed basket to unlock this star."
		_:
			return "Keep exploring the garden to unlock this star."

func guidance_line(star_id: String) -> String:
	var topic: String = star_db.topic(star_id) if star_db else star_id
	var z: String = star_db.zone(star_id) if star_db else "beds"
	match z:
		"shed":
			return "Let's look at the shed. %s" % topic
		"fence":
			return "Let's visit the animals. %s" % topic
		"map":
			return "Let's look around the whole garden. %s" % topic
		_:
			return "Let's look at the garden beds. %s" % topic

func _set_flag(flag: String) -> void:
	if _save == null or not _save.has_method("set_flag"):
		return
	if not bool(_save.set_flag(flag, true)):
		return
	_emit_reveals_for_flag(flag)

func _has_flag(flag: String) -> bool:
	return _save != null and _save.has_method("has_flag") and bool(_save.has_flag(flag))

func _emit_reveals_for_flag(flag: String) -> void:
	if star_db == null:
		return
	var ev := _events()
	var rule: String = "gameplay:%s" % flag
	for id in star_db.star_ids():
		if star_db.reveal_rule(id) != rule:
			continue
		if ev and ev.has_signal("star_revealed"):
			ev.star_revealed.emit(id)

func _events() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("/root/Events")

func _on_planted(_b: String, _s: int, _p: String) -> void:
	_set_flag(FLAG_PLANTED)

func _on_watered(_b: String, _s: int, _p: String, _st: String) -> void:
	_set_flag(FLAG_WATERED)

func _on_stage(_b: String, _s: int, _p: String, stage: String) -> void:
	if stage == "sprout":
		_set_flag(FLAG_SPROUT)
	elif stage == "growing":
		_set_flag(FLAG_GROWING)

func _on_uprooted(_b: String, _s: int, _p: String) -> void:
	_set_flag(FLAG_UPROOTED)

func _on_harvested(_p: String, _total: int) -> void:
	_set_flag(FLAG_HARVESTED)
	_set_flag(FLAG_STORED)

func _on_season(_sid: String) -> void:
	_set_flag(FLAG_SEASON)

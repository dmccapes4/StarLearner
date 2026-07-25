class_name GameFreeze
extends RefCounted
## Single source of truth for "is game time frozen?".
## Frozen while a full-freeze panel is open (videos, media, season card,
## celebration grids, intro, reveal-tile narration) or while a narration line
## locks player movement. Routine actions (planting, shed browsing) never
## freeze the clock.

const NarratorScript := preload("res://scripts/audio/Narrator.gd")

static func panels_open(tree: SceneTree) -> bool:
	for grp in ["video_panel", "media_panel", "season_card", "bug_grid", "plant_grid", "intro_panel"]:
		var n := tree.get_first_node_in_group(grp)
		if n and n.has_method("is_open") and bool(n.call("is_open")):
			return true
		if grp == "intro_panel" and n and n.get("visible") == true:
			return true
	## Reveal tile freezes only while its narration is playing.
	var rt := tree.get_first_node_in_group("reveal_tile")
	if rt and rt.has_method("is_narrating") and bool(rt.call("is_narrating")):
		return true
	return false

static func frozen(tree: SceneTree) -> bool:
	return panels_open(tree) or NarratorScript.blocks_movement()

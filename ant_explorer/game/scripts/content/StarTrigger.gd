class_name StarTrigger
extends RefCounted
## Approach-radius + dwell helper — unit-testable without a running scene tree.

static func inside_radius(player_pos: Vector2, star_pos: Vector2, radius: float) -> bool:
	return player_pos.distance_to(star_pos) <= radius


static func player_stationary(player: AntState) -> bool:
	if player == null:
		return false
	if player.action_ticks_left > 0:
		return false
	if player.state == AntEnums.State.WALK:
		return false
	if not player.path.is_empty():
		return false
	return true


static func should_trigger_dwell(
		player: AntState,
		player_pos: Vector2,
		star_pos: Vector2,
		radius: float,
		dwell_seconds: float,
		accumulated: float,
		delta: float,
) -> Dictionary:
	var inside := inside_radius(player_pos, star_pos, radius)
	var stationary := player_stationary(player)
	var next_accum := accumulated
	if inside and stationary:
		next_accum += delta
	else:
		next_accum = 0.0
	return {
		"trigger": inside and stationary and next_accum >= dwell_seconds,
		"inside": inside,
		"stationary": stationary,
		"accumulated": next_accum,
	}


static func resolve_video_path(file_name: String) -> String:
	## Stock Godot 4 plays Theora (.ogv) only — never hand back .mp4.
	if file_name.is_empty():
		return ""
	var base_name := file_name.get_basename()
	if base_name.is_empty():
		base_name = file_name
	var ogv := "res://stars/%s.ogv" % base_name
	if _path_exists(ogv):
		return ogv
	# Accept an already-correct .ogv path if the caller passed a full res path.
	var primary := file_name if file_name.begins_with("res://") else "res://stars/%s" % file_name
	if primary.ends_with(".ogv") and _path_exists(primary):
		return primary
	return ""


static func resolve_star_vo_path(star_id: String) -> String:
	const VO_DIR := "res://assets/audio/vo/stars"
	const _VoStream := preload("res://scripts/content/VoStream.gd")
	return _VoStream.resolve_vo(VO_DIR, star_id)


static func _path_exists(path: String) -> bool:
	return ResourceLoader.exists(path) or FileAccess.file_exists(path)

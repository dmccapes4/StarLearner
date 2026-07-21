class_name Pathing
extends RefCounted
## Route only along chamber graph: room → tunnel mouth → corridor → mouth → room.
## No wall cutting: cross-room travel must follow BFS tunnel sequence.
##
## Intra-room: prefer a straight chord when it stays inside the walkable polygon.
## Only detour (via a mid-point / center) when the chord would clip a wall —
## that stops the common "walk backwards through the room center" feel.

var graph: NavGraph

func _init(nav: NavGraph = null) -> void:
	graph = nav

func find_path(from_pos: Vector2, to_pos: Vector2) -> PackedVector2Array:
	var path := PackedVector2Array()
	if graph == null:
		path.append(from_pos)
		path.append(to_pos)
		return path

	var from_ch := graph.chamber_for_point(from_pos)
	var to_ch := graph.chamber_for_point(to_pos)
	if from_ch == null or to_ch == null:
		path.append(from_pos)
		return path

	# Snap endpoints into walkable rooms (taps in void/wall → nearest room).
	var start := from_ch.clamp_point(from_pos)
	var goal := to_ch.clamp_point(to_pos)

	if from_ch.id == to_ch.id:
		_append_unique(path, start)
		if start.distance_squared_to(goal) > 1.0:
			_append_room_leg(path, from_ch, start, goal)
		return path

	var rooms := graph.bfs_chamber_path(from_ch.id, to_ch.id)
	if rooms.is_empty():
		# Unreachable — stay put rather than phasing through walls.
		path.append(start)
		return path

	_append_unique(path, start)
	for i in range(rooms.size() - 1):
		var a_id: int = rooms[i]
		var b_id: int = rooms[i + 1]
		var edge := graph.tunnel_between(a_id, b_id)
		if edge == null:
			continue
		var corridor: PackedVector2Array
		if edge.a == a_id:
			corridor = edge.waypoints_a_to_b()
		else:
			corridor = edge.waypoints_b_to_a()
		if corridor.is_empty():
			continue
		var room := graph.get_chamber(a_id)
		var last := path[path.size() - 1]
		var mouth: Vector2 = corridor[0]
		# Walk to the mouth inside this room — straight when safe, else a short
		# in-room bend. Avoid a blanket "via center" that sends the ant backwards.
		if room != null and last.distance_squared_to(mouth) > 1.0:
			_append_room_leg(path, room, last, mouth)
		for wp in corridor:
			_append_unique(path, wp)

	# Final approach inside the destination chamber.
	if path.size() > 0 and path[path.size() - 1].distance_squared_to(goal) > 1.0:
		_append_room_leg(path, to_ch, path[path.size() - 1], goal)
	else:
		_append_unique(path, goal)
	return path

func find_path_to_chamber(from_pos: Vector2, chamber_name: String) -> PackedVector2Array:
	var ch := graph.get_chamber_by_name(chamber_name) if graph else null
	if ch == null:
		return find_path(from_pos, from_pos)
	return find_path(from_pos, ch.center)

## Append waypoints from `from` to `to` that stay inside `ch`.
## Prefers a direct chord; only detours when the chord leaves the polygon.
func _append_room_leg(path: PackedVector2Array, ch: NavGraph.ChamberNode, from: Vector2, to: Vector2) -> void:
	if ch == null:
		_append_unique(path, to)
		return
	if _chord_inside(ch, from, to):
		_append_unique(path, to)
		return
	# Try a single bend: mid-point pulled toward the chamber center just enough
	# to clear the wall — usually less backwards than a full trip to center.
	var mid := (from + to) * 0.5
	mid = mid.lerp(ch.center, 0.45)
	mid = ch.clamp_point(mid)
	if _chord_inside(ch, from, mid) and _chord_inside(ch, mid, to):
		# Skip the bend if it is clearly backwards relative to the goal
		# (farther from `to` than `from` already is by a wide margin).
		if mid.distance_to(to) <= from.distance_to(to) + 40.0:
			_append_unique(path, mid)
			_append_unique(path, to)
			return
	# Last resort: classic via-center (keeps hex-edge safety for awkward shapes).
	if from.distance_squared_to(ch.center) > 4.0 and to.distance_squared_to(ch.center) > 4.0:
		_append_unique(path, ch.center)
	_append_unique(path, to)

## True when the line segment stays inside the chamber walkable region.
func _chord_inside(ch: NavGraph.ChamberNode, a: Vector2, b: Vector2) -> bool:
	if ch == null:
		return true
	var dist := a.distance_to(b)
	if dist < 2.0:
		return ch.contains_point(a) and ch.contains_point(b)
	# Dense enough samples for exploration-scale rooms (~700 px half-width).
	var steps := clampi(int(ceil(dist / 28.0)), 2, 48)
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var p: Vector2 = a.lerp(b, t)
		if not ch.contains_point(p):
			return false
	return true

func _append_unique(path: PackedVector2Array, p: Vector2) -> void:
	if path.is_empty() or path[path.size() - 1].distance_squared_to(p) > 4.0:
		path.append(p)

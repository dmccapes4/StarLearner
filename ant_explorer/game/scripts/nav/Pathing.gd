class_name Pathing
extends RefCounted
## Route only along chamber graph: room → tunnel mouth → corridor → mouth → room.
## No wall cutting: cross-room travel must follow BFS tunnel sequence.

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
		path.append(start)
		if start.distance_squared_to(goal) > 1.0:
			# Stay inside room: go via center if the chord is long (avoids clipping hex edges).
			if start.distance_to(goal) > 160.0:
				path.append(from_ch.center)
			path.append(goal)
		return path

	var rooms := graph.bfs_chamber_path(from_ch.id, to_ch.id)
	if rooms.is_empty():
		# Unreachable — stay put rather than phasing through walls.
		path.append(start)
		return path

	path.append(start)
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
		# Long crossings route via the room center so big exploration-scale
		# chambers never produce wall-clipping chord segments.
		if not corridor.is_empty():
			var last := path[path.size() - 1]
			if last.distance_to(corridor[0]) > 600.0:
				var room := graph.get_chamber(a_id)
				if room != null:
					_append_unique(path, room.center)
		# Walk to mouth, then along corridor (includes both mouths).
		for wp in corridor:
			_append_unique(path, wp)

	_append_unique(path, goal)
	return path

func find_path_to_chamber(from_pos: Vector2, chamber_name: String) -> PackedVector2Array:
	var ch := graph.get_chamber_by_name(chamber_name) if graph else null
	if ch == null:
		return find_path(from_pos, from_pos)
	return find_path(from_pos, ch.center)

func _append_unique(path: PackedVector2Array, p: Vector2) -> void:
	if path.is_empty() or path[path.size() - 1].distance_squared_to(p) > 4.0:
		path.append(p)

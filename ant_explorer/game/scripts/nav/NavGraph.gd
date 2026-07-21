class_name NavGraph
extends RefCounted
## Chamber graph with tunnel edges. Paths only travel room → portal → corridor → portal → room.

class ChamberNode:
	var id: int
	var name: String
	var kind: String = "hub"
	var world_rect: Rect2
	var walkable: PackedVector2Array
	var center: Vector2 = Vector2.ZERO
	var star_id: String = ""
	var tunnel_ids: PackedInt32Array = PackedInt32Array()
	var neighbors: PackedInt32Array = PackedInt32Array()
	var is_outdoor: bool = false

	func contains_point(p: Vector2) -> bool:
		if walkable.size() >= 3:
			return Geometry2D.is_point_in_polygon(p, walkable)
		return world_rect.has_point(p)

	func clamp_point(p: Vector2) -> Vector2:
		if contains_point(p):
			return p
		# Prefer the walkable boundary in the tap's direction (mouth / east wall),
		# not chamber center — AABB clamp often lands outside the hex and used
		# to fall through to center, making tunnel taps look dead.
		var on_ray := portal_toward(p)
		if on_ray.distance_squared_to(center) > 1.0:
			return on_ray
		var c := p.clamp(world_rect.position, world_rect.end)
		if contains_point(c):
			return c
		return _closest_on_walkable(p)

	## Nearest point on the walkable polygon boundary (or center if degenerate).
	func _closest_on_walkable(p: Vector2) -> Vector2:
		if walkable.size() < 2:
			return center
		var best := center
		var best_d := INF
		var n := walkable.size()
		for i in n:
			var a: Vector2 = walkable[i]
			var b: Vector2 = walkable[(i + 1) % n]
			var q := Geometry2D.get_closest_point_to_segment(p, a, b)
			var d := p.distance_squared_to(q)
			if d < best_d:
				best_d = d
				best = q
		return best

	func random_point(rng: RandomNumberGenerator) -> Vector2:
		for _i in 32:
			var p := Vector2(
				rng.randf_range(world_rect.position.x, world_rect.end.x),
				rng.randf_range(world_rect.position.y, world_rect.end.y)
			)
			if contains_point(p):
				return p
		return center

	## Furthest point still inside this chamber toward `toward` (tunnel mouth).
	func portal_toward(toward: Vector2) -> Vector2:
		var dir := toward - center
		if dir.length_squared() < 1.0:
			return center
		dir = dir.normalized()
		var last_inside := center
		# Step out to the walkable boundary.
		for i in range(1, 64):
			var p: Vector2 = center + dir * float(i) * 6.0
			if contains_point(p):
				last_inside = p
			else:
				break
		return last_inside

class TunnelEdge:
	var id: int
	var a: int
	var b: int
	## Mouth on A, corridor samples, mouth on B (direction a → b).
	var waypoints: PackedVector2Array = PackedVector2Array()

	func mouth_a() -> Vector2:
		return waypoints[0] if waypoints.size() > 0 else Vector2.ZERO

	func mouth_b() -> Vector2:
		return waypoints[waypoints.size() - 1] if waypoints.size() > 0 else Vector2.ZERO

	func waypoints_a_to_b() -> PackedVector2Array:
		return waypoints

	func waypoints_b_to_a() -> PackedVector2Array:
		var out := PackedVector2Array()
		for i in range(waypoints.size() - 1, -1, -1):
			out.append(waypoints[i])
		return out

var chambers: Dictionary = {}
var chambers_by_name: Dictionary = {}
var tunnels: Array = []
var _default_id: int = 0

func clear() -> void:
	chambers.clear()
	chambers_by_name.clear()
	tunnels.clear()

func add_chamber(node: ChamberNode) -> void:
	chambers[node.id] = node
	chambers_by_name[node.name] = node
	if chambers.size() == 1:
		_default_id = node.id

func set_default_by_name(name: String) -> void:
	var ch: ChamberNode = chambers_by_name.get(name) as ChamberNode
	if ch != null:
		_default_id = ch.id

func add_tunnel(a_name: String, b_name: String) -> void:
	var ca: ChamberNode = chambers_by_name.get(a_name) as ChamberNode
	var cb: ChamberNode = chambers_by_name.get(b_name) as ChamberNode
	if ca == null or cb == null:
		push_warning("NavGraph: tunnel missing chamber %s-%s" % [a_name, b_name])
		return
	var edge := TunnelEdge.new()
	edge.id = tunnels.size()
	edge.a = ca.id
	edge.b = cb.id
	edge.waypoints = _build_corridor(ca, cb)
	tunnels.append(edge)
	if not _neighbor_has(ca, cb.id):
		ca.neighbors.append(cb.id)
	if not _neighbor_has(cb, ca.id):
		cb.neighbors.append(ca.id)
	ca.tunnel_ids.append(edge.id)
	cb.tunnel_ids.append(edge.id)

func _neighbor_has(ch: ChamberNode, id: int) -> bool:
	for n in ch.neighbors:
		if n == id:
			return true
	return false

func _build_corridor(ca: ChamberNode, cb: ChamberNode) -> PackedVector2Array:
	var mouth_a := ca.portal_toward(cb.center)
	var mouth_b := cb.portal_toward(ca.center)
	var span := mouth_b - mouth_a
	var length := span.length()
	# Organic winding: more waypoints on long tunnels, amplitude tapers to zero
	# at both mouths so corridors always meet chambers cleanly. Deterministic
	# per-edge phase keeps layouts stable across runs (and tests).
	var segs := clampi(int(ceil(length / 320.0)), 2, 8)
	var perp := span.orthogonal().normalized() if length > 1.0 else Vector2.ZERO
	var phase := float((ca.id * 31 + cb.id * 17) % 7)
	var amp := minf(90.0, length * 0.10)
	var pts := PackedVector2Array()
	pts.append(mouth_a)
	for i in range(1, segs):
		var t := float(i) / float(segs)
		var wobble := sin(t * TAU + phase) * sin(t * PI)
		pts.append(mouth_a + span * t + perp * amp * wobble)
	pts.append(mouth_b)
	return pts

func get_chamber(id: int) -> ChamberNode:
	return chambers.get(id) as ChamberNode

func get_chamber_by_name(name: String) -> ChamberNode:
	return chambers_by_name.get(name) as ChamberNode

func default_chamber() -> ChamberNode:
	return get_chamber(_default_id)

## Chamber whose walkable polygon contains `p`, or null if the tap is in void.
func chamber_containing(p: Vector2) -> ChamberNode:
	for id in chambers:
		var ch: ChamberNode = chambers[id]
		if ch.contains_point(p):
			return ch
	return null

func chamber_for_point(p: Vector2) -> ChamberNode:
	var inside := chamber_containing(p)
	if inside != null:
		return inside
	# Void / wall tap: nearest chamber by center (caller should clamp).
	var best: ChamberNode = null
	var best_d := INF
	for id in chambers:
		var ch2: ChamberNode = chambers[id]
		var d: float = ch2.center.distance_squared_to(p)
		if d < best_d:
			best_d = d
			best = ch2
	return best if best != null else default_chamber()

func tunnel_between(a_id: int, b_id: int) -> TunnelEdge:
	for t in tunnels:
		var e: TunnelEdge = t
		if (e.a == a_id and e.b == b_id) or (e.a == b_id and e.b == a_id):
			return e
	return null

## Hit-test a tap against corridor polylines. Returns the closest edge within
## `max_dist`, or null. Used so tapping a drawn tunnel walks through it.
func nearest_tunnel(p: Vector2, max_dist: float = 140.0) -> TunnelEdge:
	var best: TunnelEdge = null
	var best_d := max_dist
	for t in tunnels:
		var e: TunnelEdge = t
		var wps := e.waypoints
		if wps.size() < 2:
			continue
		for i in range(wps.size() - 1):
			var q := Geometry2D.get_closest_point_to_segment(p, wps[i], wps[i + 1])
			var d := p.distance_to(q)
			if d <= best_d:
				best_d = d
				best = e
	return best

## Goal just inside the chamber on the far side of `edge` from `from_chamber_id`.
func goal_past_tunnel(edge: TunnelEdge, from_chamber_id: int, past: float = 160.0) -> Vector2:
	if edge == null:
		return Vector2.ZERO
	var far: Vector2
	var dest_id: int
	if edge.a == from_chamber_id:
		far = edge.mouth_b()
		dest_id = edge.b
	elif edge.b == from_chamber_id:
		far = edge.mouth_a()
		dest_id = edge.a
	else:
		# Tap on a tunnel the player is not standing in — pick the end farther
		# from the player's chamber if known, else mouth_b's chamber.
		far = edge.mouth_b()
		dest_id = edge.b
	var dest := get_chamber(dest_id)
	if dest == null:
		return far
	var into := dest.center - far
	if into.length_squared() < 1.0:
		return dest.clamp_point(far)
	return dest.clamp_point(far + into.normalized() * past)

func bfs_chamber_path(from_id: int, to_id: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	if from_id == to_id:
		out.append(from_id)
		return out
	var q: Array = [from_id]
	var prev: Dictionary = {from_id: -1}
	var qi := 0
	while qi < q.size():
		var cur: int = q[qi]
		qi += 1
		var ch := get_chamber(cur)
		if ch == null:
			continue
		for n in ch.neighbors:
			if prev.has(n):
				continue
			prev[n] = cur
			if n == to_id:
				var stack: Array = [to_id]
				var p: int = cur
				while p != -1:
					stack.append(p)
					p = prev[p]
				stack.reverse()
				for id in stack:
					out.append(id)
				return out
			q.append(n)
	return out

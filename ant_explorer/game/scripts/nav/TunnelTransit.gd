class_name TunnelTransit
extends RefCounted
## When the player stands in the pads beside a tunnel mouth, auto-path through
## the corridor and stop well past the far exit — far enough that the arrival
## pad cannot immediately yank them back.

## Pads next to a mouth (≈ tunnel half-width + a little margin).
const TRIGGER_RADIUS := 64.0
## How far into the destination chamber past the far mouth.
## Must exceed TRIGGER_RADIUS so arrival is outside the suck zone.
const PAST_EXIT := 160.0
## Stay this far from *both* mouths of a suppressed edge before it can re-arm.
const CLEAR_RADIUS := 200.0
## After any transit settles, block all auto-transits for this many calls
## (sim ticks while idle). Stops bounce-back while the ant is still near mouths.
const COOLDOWN_TRIGGERS := 12

var graph: NavGraph
## Edge id suppressed after a crossing (both mouths).
var _suppress_edge_id: int = -1
var _suppress_active: bool = false
var _committed: bool = false
var _cooldown: int = 0
## First successful mouth-pad trigger this session → teach-in-context VO.
var _taught: bool = false
var _teach_pending: bool = false

func _init(nav: NavGraph = null) -> void:
	graph = nav

func reset() -> void:
	_suppress_active = false
	_suppress_edge_id = -1
	_committed = false
	_cooldown = 0
	_taught = false
	_teach_pending = false

## Manual tap — drop in-flight auto-transit; keep exit suppress so we don't
## immediately suck the ant back into the tunnel they just left.
func notify_manual_path() -> void:
	_committed = false
	# Brief grace so a tap near a mouth doesn't instantly re-arm auto-transit.
	_cooldown = maxi(_cooldown, 4)

func is_committed() -> bool:
	return _committed

## Call each player tick. Returns a destination past the far exit, or null.
func try_trigger(player_pos: Vector2) -> Variant:
	if graph == null:
		return null
	_update_suppress(player_pos)
	if _committed:
		return null
	if _cooldown > 0:
		_cooldown -= 1
		return null
	# Strict containment — never treat void as "in" a nearest chamber.
	var ch := graph.chamber_containing(player_pos)
	if ch == null:
		return null
	var best_edge: NavGraph.TunnelEdge = null
	var best_near := Vector2.ZERO
	var best_far := Vector2.ZERO
	var best_d := TRIGGER_RADIUS
	for tid in ch.tunnel_ids:
		if tid < 0 or tid >= graph.tunnels.size():
			continue
		var edge: NavGraph.TunnelEdge = graph.tunnels[tid]
		if _is_edge_suppressed(edge.id):
			continue
		var near: Vector2
		var far: Vector2
		if edge.a == ch.id:
			near = edge.mouth_a()
			far = edge.mouth_b()
		elif edge.b == ch.id:
			near = edge.mouth_b()
			far = edge.mouth_a()
		else:
			continue
		var d := player_pos.distance_to(near)
		if d <= best_d:
			best_d = d
			best_edge = edge
			best_near = near
			best_far = far
	if best_edge == null:
		return null
	var dest_ch: NavGraph.ChamberNode
	if best_edge.a == ch.id:
		dest_ch = graph.get_chamber(best_edge.b)
	else:
		dest_ch = graph.get_chamber(best_edge.a)
	if dest_ch == null:
		return null
	var into := dest_ch.center - best_far
	if into.length_squared() < 1.0:
		into = best_far - best_near
	if into.length_squared() < 1.0:
		return null
	into = into.normalized()
	# Prefer a point well toward the room center so small rooms still clear the pad.
	var goal := dest_ch.clamp_point(best_far + into * PAST_EXIT)
	var toward_center := dest_ch.clamp_point(best_far.lerp(dest_ch.center, 0.55))
	if goal.distance_to(best_far) < TRIGGER_RADIUS + 24.0:
		goal = toward_center
	if goal.distance_to(best_far) < TRIGGER_RADIUS + 8.0:
		goal = dest_ch.clamp_point(dest_ch.center)
	_committed = true
	_suppress_edge_id = best_edge.id
	_suppress_active = true
	if not _taught:
		_taught = true
		_teach_pending = true
	return goal

## World drains this once to speak the first-tunnel tip (does not pause movement).
func consume_teach() -> bool:
	if not _teach_pending:
		return false
	_teach_pending = false
	return true

func has_been_taught() -> bool:
	return _taught

## Path finished — drop commit; start cooldown; suppress clears once clear of both mouths.
func on_path_settled(player_pos: Vector2) -> void:
	_committed = false
	_cooldown = maxi(_cooldown, COOLDOWN_TRIGGERS)
	_update_suppress(player_pos)

func goal_past_exit(edge: NavGraph.TunnelEdge, from_chamber_id: int) -> Vector2:
	## Test/helper: compute the auto-transit goal for an edge entered from a chamber.
	var near: Vector2
	var far: Vector2
	var dest_id: int
	if edge.a == from_chamber_id:
		near = edge.mouth_a()
		far = edge.mouth_b()
		dest_id = edge.b
	else:
		near = edge.mouth_b()
		far = edge.mouth_a()
		dest_id = edge.a
	var dest_ch := graph.get_chamber(dest_id)
	if dest_ch == null:
		return far
	var into := dest_ch.center - far
	if into.length_squared() < 1.0:
		into = far - near
	if into.length_squared() < 1.0:
		return dest_ch.clamp_point(far)
	var goal := dest_ch.clamp_point(far + into.normalized() * PAST_EXIT)
	if goal.distance_to(far) < TRIGGER_RADIUS + 24.0:
		goal = dest_ch.clamp_point(far.lerp(dest_ch.center, 0.55))
	return goal

func _is_edge_suppressed(edge_id: int) -> bool:
	return _suppress_active and edge_id == _suppress_edge_id

func _update_suppress(player_pos: Vector2) -> void:
	if not _suppress_active or _suppress_edge_id < 0 or graph == null:
		return
	if _suppress_edge_id >= graph.tunnels.size():
		_suppress_active = false
		return
	var edge: NavGraph.TunnelEdge = graph.tunnels[_suppress_edge_id]
	var d_a := player_pos.distance_to(edge.mouth_a())
	var d_b := player_pos.distance_to(edge.mouth_b())
	if d_a > CLEAR_RADIUS and d_b > CLEAR_RADIUS:
		_suppress_active = false
		_suppress_edge_id = -1

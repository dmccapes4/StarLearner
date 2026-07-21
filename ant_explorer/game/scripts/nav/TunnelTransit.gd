class_name TunnelTransit
extends RefCounted
## When the player stands in the pads beside a tunnel mouth, auto-path through
## the corridor and stop about one ant-length past the far exit.

## Pads next to a mouth (≈ tunnel half-width + a little margin).
const TRIGGER_RADIUS := 72.0
## How far into the destination chamber past the far mouth.
const PAST_EXIT := 32.0  ## ≈ AntEnums PLAYER radius × 3.2
## Leave this far from the arrival mouth before that mouth can re-trigger.
const CLEAR_RADIUS := 110.0

var graph: NavGraph
## Mouth we must stay clear of after a transit (prevents bounce-back).
var _suppress_mouth: Vector2 = Vector2.ZERO
var _suppress_active: bool = false
var _committed: bool = false
## First successful mouth-pad trigger this session → teach-in-context VO.
var _taught: bool = false
var _teach_pending: bool = false

func _init(nav: NavGraph = null) -> void:
	graph = nav

func reset() -> void:
	_suppress_active = false
	_committed = false
	_taught = false
	_teach_pending = false

## Manual tap — drop in-flight auto-transit; keep exit suppress so we don't
## immediately suck the ant back into the tunnel they just left.
func notify_manual_path() -> void:
	_committed = false

func is_committed() -> bool:
	return _committed

## Call each player tick. Returns a destination past the far exit, or null.
func try_trigger(player_pos: Vector2) -> Variant:
	if graph == null:
		return null
	_update_suppress(player_pos)
	if _committed:
		return null
	var ch := graph.chamber_for_point(player_pos)
	if ch == null or not ch.contains_point(player_pos):
		return null
	var best_edge: NavGraph.TunnelEdge = null
	var best_near := Vector2.ZERO
	var best_far := Vector2.ZERO
	var best_d := TRIGGER_RADIUS
	for tid in ch.tunnel_ids:
		if tid < 0 or tid >= graph.tunnels.size():
			continue
		var edge: NavGraph.TunnelEdge = graph.tunnels[tid]
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
		if _is_suppressed(near) or _is_suppressed(far):
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
	var goal := dest_ch.clamp_point(best_far + into * PAST_EXIT)
	_committed = true
	_suppress_mouth = best_far
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

## Path finished — drop commit; suppress clears once the ant walks away.
func on_path_settled(player_pos: Vector2) -> void:
	_committed = false
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
	return dest_ch.clamp_point(far + into.normalized() * PAST_EXIT)

func _is_suppressed(mouth: Vector2) -> bool:
	if not _suppress_active:
		return false
	return mouth.distance_squared_to(_suppress_mouth) < 4.0

func _update_suppress(player_pos: Vector2) -> void:
	if not _suppress_active:
		return
	if player_pos.distance_to(_suppress_mouth) > CLEAR_RADIUS:
		_suppress_active = false

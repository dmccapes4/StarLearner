extends RefCounted
## Tunnel mouth pads auto-path the player through to past the far exit.

const TunnelTransitScript := preload("res://scripts/nav/TunnelTransit.gd")

var _tree: Node

func _init(tree: Node) -> void:
	_tree = tree

func run() -> TestAssert:
	var t := TestAssert.new("TunnelTransit")
	var builder := MapBuilder.new()
	var host := Node2D.new()
	_tree.add_child(host)
	var graph := builder.build(host)
	var transit = TunnelTransitScript.new(graph)
	var pathing := Pathing.new(graph)

	var surface := graph.get_chamber_by_name("surface")
	var entrance := graph.get_chamber_by_name("entrance")
	t.ok(surface != null and entrance != null, "surface + entrance present")
	var edge := graph.tunnel_between(surface.id, entrance.id)
	t.ok(edge != null and edge.waypoints.size() >= 2, "surface↔entrance tunnel")

	# Goal is past the far mouth, inside the destination chamber.
	var goal := transit.goal_past_exit(edge, surface.id)
	var far := edge.mouth_b() if edge.a == surface.id else edge.mouth_a()
	t.ok(entrance.contains_point(goal), "goal inside entrance")
	var past: float = float(TunnelTransitScript.PAST_EXIT)
	var trigger_r: float = float(TunnelTransitScript.TRIGGER_RADIUS)
	var clear_r: float = float(TunnelTransitScript.CLEAR_RADIUS)
	t.ok(goal.distance_to(far) >= minf(past * 0.35, 48.0), "goal past far mouth")
	# Arrival must clear the trigger pad so suppress isn't the only bounce guard.
	t.ok(goal.distance_to(far) >= trigger_r + 8.0, "goal outside trigger radius of arrival mouth")

	# Standing beside the near mouth triggers.
	var near := edge.mouth_a() if edge.a == surface.id else edge.mouth_b()
	var pad := near + (surface.center - near).normalized() * 24.0
	if not surface.contains_point(pad):
		pad = surface.clamp_point(near + (surface.center - near).normalized() * 12.0)
	t.ok(surface.contains_point(pad), "pad sample inside surface")
	var trig: Variant = transit.try_trigger(pad)
	t.ok(trig is Vector2, "trigger at mouth pad")
	if trig is Vector2:
		var g: Vector2 = trig
		t.ok(entrance.contains_point(g), "triggered goal in entrance")
		t.ok(g.distance_to(far) <= past + 40.0, "triggered goal near far mouth")

	# Bounce-back: arriving at goal must not reverse through the same tunnel.
	transit.on_path_settled(goal)
	# Drain cooldown so we test edge suppress, not the settle grace period.
	for _i in 20:
		transit.try_trigger(goal)
	var bounce: Variant = transit.try_trigger(goal)
	t.ok(bounce == null, "no bounce-back at arrival mouth")

	# After walking away past CLEAR_RADIUS from both mouths, reverse can arm.
	var away := entrance.clamp_point(far + (entrance.center - far).normalized() * (clear_r + 40.0))
	# Also clear of the near (surface) mouth.
	if away.distance_to(near) <= clear_r:
		away = entrance.clamp_point(entrance.center)
	transit.on_path_settled(away)
	for _j in 20:
		transit.try_trigger(away)
	var rearm_pad := entrance.clamp_point(far + (entrance.center - far).normalized() * 20.0)
	var re: Variant = transit.try_trigger(rearm_pad)
	t.ok(re is Vector2, "can re-trigger from entrance pad after clearing suppress")

	# Outside trigger radius: no fire.
	transit.reset()
	var far_from_mouth := surface.clamp_point(surface.center)
	t.ok(far_from_mouth.distance_to(near) > trigger_r, "center away from mouth")
	t.ok(transit.try_trigger(far_from_mouth) == null, "no trigger at chamber center")

	# Teach-in-context: first trigger arms VO once; second does not.
	transit.reset()
	t.eq(transit.consume_teach(), false, "no teach before first trigger")
	var first: Variant = transit.try_trigger(pad)
	t.ok(first is Vector2, "first trigger for teach")
	t.eq(transit.consume_teach(), true, "teach pending after first mouth pad")
	t.eq(transit.consume_teach(), false, "teach consumed once")
	t.eq(transit.has_been_taught(), true, "session remembers teach")
	transit.on_path_settled(goal)
	var away2 := entrance.clamp_point(entrance.center)
	# Clear both mouths + drain settle cooldown before reverse transit.
	transit.on_path_settled(away2)
	for _k in 20:
		transit.try_trigger(away2)
	t.ok(away2.distance_to(far) > clear_r and away2.distance_to(near) > clear_r,
		"teach rearm stand clears both mouths")
	var again: Variant = transit.try_trigger(rearm_pad)
	t.ok(again is Vector2, "later transit still works")
	t.eq(transit.consume_teach(), false, "no second teach VO this session")

	# JSON line present for gen_vo / World fallback TTS.
	t.ok(FileAccess.file_exists("res://data/tunnel_vo.json"), "tunnel_vo.json present")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/tunnel_vo.json"))
	t.ok(typeof(parsed) == TYPE_DICTIONARY, "tunnel_vo parses")
	if typeof(parsed) == TYPE_DICTIONARY:
		var line := str((parsed as Dictionary).get("tunnel", {}).get("text", ""))
		t.ok(line.to_lower().contains("tunnel"), "teach line mentions tunnel")

	# Colony integration: one tick near pad issues a corridor path ending past exit.
	var colony := Colony.new()
	_tree.add_child(colony)
	colony.setup(graph, pathing)
	colony.spawn_phase2(host, preload("res://scenes/Ant.tscn"), [])
	var player := colony.get_player()
	t.ok(player != null, "player spawned")
	player.cell = pad
	player.prev_cell = pad
	player.role = AntEnums.Role.NONE
	player.intent = AntEnums.State.IDLE
	player.clear_path()
	colony.on_sim_tick(1)
	t.ok(not player.path.is_empty() or player.cell.distance_to(goal) < 80.0,
		"colony issued transit path or already near goal")
	if not player.path.is_empty():
		var end: Vector2 = player.path[player.path.size() - 1]
		t.ok(entrance.contains_point(end) or end.distance_to(goal) < 60.0,
			"colony path ends in/at entrance past exit")
		t.ok(_path_near(player.path, far, 80.0), "colony path passes far mouth")
	t.eq(colony.tunnel_transit.call("consume_teach"), true, "colony transit arms teach VO")

	host.queue_free()
	colony.queue_free()
	return t

func _path_near(path: PackedVector2Array, p: Vector2, rad: float) -> bool:
	var r2 := rad * rad
	for q in path:
		if q.distance_squared_to(p) <= r2:
			return true
	return false

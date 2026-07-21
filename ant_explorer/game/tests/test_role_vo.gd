extends RefCounted
const ROLE_VO := preload("res://scripts/content/RoleVO.gd")
## First-adoption role VO: three lines, once per session per role.

var _host: Node

func _init(host: Node) -> void:
	_host = host

func run() -> TestAssert:
	var t := TestAssert.new("RoleVO")
	var vo := ROLE_VO.new()
	_host.add_child(vo)
	await _host.get_tree().process_frame

	var nurse := vo.lines_for(AntEnums.Role.NURSE)
	t.eq(nurse.size(), 3, "nurse has three sentences")
	t.ok(nurse[0].to_lower().contains("nursing") or nurse[0].to_lower().contains("trail"),
		"line1 describes trail entry")
	t.ok(nurse[1].to_lower().contains("garden") or nurse[1].to_lower().contains("nursery"),
		"line2 describes garden fetch")
	t.ok(nurse[2].to_lower().contains("larv"), "line3 mentions larvae")

	t.eq(vo.try_announce(AntEnums.Role.NURSE), true, "first adoption announces")
	t.eq(vo.has_visited(AntEnums.Role.NURSE), true, "marked visited")
	t.eq(vo.try_announce(AntEnums.Role.NURSE), false, "second adoption silent")

	t.eq(vo.try_announce(AntEnums.Role.SCOUT), true, "new role announces")
	vo.reset_session()
	t.eq(vo.has_visited(AntEnums.Role.NURSE), false, "session reset clears visits")
	t.eq(vo.try_announce(AntEnums.Role.NURSE), true, "after reset can announce again")

	for role_key in ["nurse", "forager", "gardener", "soldier", "waste", "scout"]:
		var role: int = AntEnums.role_from_name(role_key)
		var lines := vo.lines_for(role)
		t.eq(lines.size(), 3, "VO for %s" % role_key)
		t.ok(not lines[0].is_empty() and not lines[1].is_empty() and not lines[2].is_empty(),
			"non-empty lines for %s" % role_key)

	vo.queue_free()
	return t

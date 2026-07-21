extends RefCounted
const CHAMBER_VO := preload("res://scripts/content/ChamberVO.gd")
## First-visit chamber VO: two lines, once per session.
## World._check_chamber_vo gates try_announce to exploration (role == NONE) only;
## ChamberVO itself still marks visited when called — the World gate is what matters in play.

var _host: Node

func _init(host: Node) -> void:
	_host = host

func run() -> TestAssert:
	var t := TestAssert.new("ChamberVO")
	var vo := CHAMBER_VO.new()
	_host.add_child(vo)
	await _host.get_tree().process_frame

	var nursery := vo.lines_for("nursery")
	t.eq(nursery.size(), 2, "nursery has two sentences")
	t.ok(nursery[0].contains("nursery") or nursery[0].to_lower().contains("baby"),
		"line1 describes what the area is")
	t.ok(nursery[1].to_lower().contains("nurse") or nursery[1].to_lower().contains("feed"),
		"line2 describes what ants do")

	t.eq(vo.try_announce("nursery"), true, "first visit announces")
	t.eq(vo.has_visited("nursery"), true, "marked visited")
	t.eq(vo.try_announce("nursery"), false, "second visit silent")

	t.eq(vo.try_announce("queen"), true, "new chamber announces")
	vo.reset_session()
	t.eq(vo.has_visited("nursery"), false, "session reset clears visits")
	t.eq(vo.try_announce("nursery"), true, "after reset can announce again")

	# All map zones have VO copy.
	var map_txt := FileAccess.get_file_as_string("res://data/map.json")
	var map_data: Dictionary = JSON.parse_string(map_txt)
	for ch in map_data.get("chambers", []):
		var name: String = str(ch.get("name", ""))
		var lines := vo.lines_for(name)
		t.eq(lines.size(), 2, "VO for %s" % name)
		t.ok(not lines[0].is_empty() and not lines[1].is_empty(), "non-empty lines for %s" % name)

	vo.queue_free()
	return t

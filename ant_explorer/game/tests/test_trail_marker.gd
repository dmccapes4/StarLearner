extends RefCounted
## Trail entry icons: radius hit-testing + role colors.

var _tree: Node

func _init(tree: Node) -> void:
	_tree = tree

func run() -> TestAssert:
	var t := TestAssert.new("TrailMarker")
	var MarkerScript: GDScript = load("res://scripts/world/TrailMarker.gd") as GDScript
	var marker: Node2D = MarkerScript.new() as Node2D
	_tree.add_child(marker)
	marker.call("setup", AntEnums.Role.FORAGER, Vector2(100, 50))

	t.eq(int(marker.get("role")), AntEnums.Role.FORAGER, "marker stores role")
	t.ok(marker.has_method("hit_test"), "hit_test present")
	t.ok(marker.hit_test(Vector2(100, 50)), "hit at center")
	t.ok(marker.hit_test(Vector2(180, 50)), "hit within tap radius")
	t.ok(not marker.hit_test(Vector2(500, 500)), "miss far away")

	var scout_col := AntEnums.role_color(AntEnums.Role.SCOUT)
	t.ok(scout_col.b > scout_col.r, "scout role color is violet")
	t.eq(AntEnums.role_name(AntEnums.Role.SCOUT), "scout", "role_name scout")
	t.eq(AntEnums.role_from_name("waste"), AntEnums.Role.WASTE, "role_from_name waste")

	marker.queue_free()
	return t

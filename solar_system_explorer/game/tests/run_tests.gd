extends SceneTree
## Headless logic tests for the Solar System Explorer preview.
##   godot --headless --path . -s res://tests/run_tests.gd
## Exit code 0 = all passed; 1 = failures. Also force-loads every view script so
## a compile error anywhere fails the run (headless can't render the scenes).

var _pass := 0
var _fail := 0

func _init() -> void:
	call_deferred("_run")

func _ok(cond: bool, msg: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: ", msg)

func _run() -> void:
	print("======== Solar System Explorer tests ========")
	_test_data()
	_test_layout()
	_test_scripts_compile()
	print("======== TOTAL: %d passed, %d failed ========" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)

func _test_data() -> void:
	var bodies := SolarData.bodies()
	_ok(bodies.size() == 11, "11 bodies (Sun + 8 planets + asteroid belt + Pluto)")

	var ids := {}
	for b in bodies:
		ids[b["id"]] = true
		_ok(not str(b["blurb"]).is_empty(), "%s has a blurb" % b["id"])
		_ok((b.get("facts", []) as Array).size() >= 1, "%s has facts" % b["id"])
	_ok(ids.size() == 11, "all body ids unique")
	_ok(ids.has("sun") and ids.has("earth") and ids.has("pluto"), "key ids present")
	_ok(ids.has("asteroid_belt"), "asteroid belt present")

	var pluto := _by_id(bodies, "pluto")
	_ok(bool(pluto.get("dwarf", false)), "Pluto flagged as dwarf")
	var sun := _by_id(bodies, "sun")
	_ok(bool(sun.get("is_star", false)), "Sun flagged as star")

	var belt := SolarData.belt()
	_ok(bool(belt.get("belt", false)), "belt() returns the flagged belt body")
	_ok(str(belt.get("id", "")) == "asteroid_belt", "belt id is asteroid_belt")

	var order := _id_order(bodies)
	_ok(order.find("asteroid_belt") > order.find("mars"), "belt after Mars in strip")
	_ok(order.find("asteroid_belt") < order.find("jupiter"), "belt before Jupiter in strip")

	var orbiting := SolarData.orbiting()
	_ok(orbiting.size() == 8, "exactly 8 planets orbit in the orrery")
	_ok(not _contains_id(orbiting, "sun"), "Sun does not orbit itself")
	_ok(not _contains_id(orbiting, "pluto"), "Pluto not in orrery tour")
	_ok(not _contains_id(orbiting, "asteroid_belt"), "belt is not a single orbiting disc")
	for i in orbiting.size() - 1:
		_ok(float(orbiting[i]["orrery_rx"]) < float(orbiting[i + 1]["orrery_rx"]),
			"orbit radii increase outward at %d" % i)

	var tour := SolarData.tour_sequence()
	_ok(tour.size() == 9, "narrated tour is 8 planets + asteroid belt")
	_ok(_contains_id(tour, "asteroid_belt"), "belt is narrated in the tour")
	_ok(not _contains_id(tour, "sun") and not _contains_id(tour, "pluto"),
		"tour excludes Sun and Pluto")

func _test_layout() -> void:
	var layout := SolarData.scroll_layout()
	var xs: Array = layout["xs"]
	_ok(xs.size() == 11, "one scroll x per body")
	for i in xs.size() - 1:
		_ok(float(xs[i]) < float(xs[i + 1]), "scroll xs strictly increasing at %d" % i)
	_ok(float(layout["width"]) > float(xs[xs.size() - 1]), "strip width past last body")

func _test_scripts_compile() -> void:
	for path in [
		"res://scripts/Main.gd", "res://scripts/Starfield.gd",
		"res://scripts/TitleView.gd", "res://scripts/OrreryView.gd",
		"res://scripts/OrreryBodies.gd", "res://scripts/ScrollView.gd",
		"res://scripts/BodyCell.gd", "res://scripts/VideoPanel.gd",
		"res://scripts/Narrator.gd", "res://scripts/SolarData.gd",
		"res://scripts/AstronautIntro.gd",
	]:
		_ok(load(path) != null, "compiles: %s" % path)

func _by_id(bodies: Array, id: String) -> Dictionary:
	for b in bodies:
		if b["id"] == id:
			return b
	return {}

func _contains_id(bodies: Array, id: String) -> bool:
	for b in bodies:
		if b["id"] == id:
			return true
	return false

func _id_order(bodies: Array) -> Array:
	var out: Array = []
	for b in bodies:
		out.append(str(b["id"]))
	return out

extends SceneTree
## Headless test runner for Garden Explorer.
##
##   godot --headless --path . -s res://tests/run_tests.gd

const SUITES := [
	"res://tests/test_iso_util.gd",
	"res://tests/test_farm_map.gd",
	"res://tests/test_player_walk.gd",
	"res://tests/test_camera_follow.gd",
	"res://tests/test_seed_db.gd",
	"res://tests/test_farm_sprites.gd",
	"res://tests/test_garden_plant.gd",
	"res://tests/test_growth_harvest.gd",
	"res://tests/test_seasons_animals.gd",
	"res://tests/test_stars.gd",
	"res://tests/test_save.gd",
]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("======== Garden Explorer tests ========")
	var total_pass := 0
	var total_fail := 0
	for path in SUITES:
		var script: GDScript = load(path) as GDScript
		if script == null:
			push_error("Cannot load %s" % path)
			total_fail += 1
			continue
		var suite = script.new() if script.can_instantiate() else null
		if suite == null or not suite.has_method("run"):
			push_error("%s missing run() / failed to instantiate" % path)
			total_fail += 1
			continue
		var result = suite.run()
		if result == null:
			push_error("%s run() returned null" % path)
			total_fail += 1
			continue
		total_pass += result.passed
		total_fail += result.failed
		var status := "OK" if result.failed == 0 else "FAIL"
		print("[%s] %s  +%d -%d" % [status, result.name, result.passed, result.failed])
		for e in result.errors:
			print("  ", e)
	print("======== %d passed, %d failed ========" % [total_pass, total_fail])
	quit(0 if total_fail == 0 else 1)

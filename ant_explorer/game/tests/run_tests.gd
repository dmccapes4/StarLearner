extends SceneTree
## Headless test runner for Ant Explorer sim logic.
##
##   godot --headless --path . -s res://tests/run_tests.gd
##
## Exit code 0 = all passed; 1 = failures.

const SUITES := [
	"res://tests/test_ant_enums.gd",
	"res://tests/test_iso_util.gd",
	"res://tests/test_pathing.gd",
	"res://tests/test_pathing_forward.gd",
	"res://tests/test_pathing_tunnel_tap.gd",
	"res://tests/test_ant_state.gd",
	"res://tests/test_save_game.gd",
	"res://tests/test_brood.gd",
	"res://tests/test_colony_roles.gd",
	"res://tests/test_nurse_fsm.gd",
	"res://tests/test_trail_marker.gd",
	"res://tests/test_role_vo.gd",
	"res://tests/test_map_trails.gd",
	"res://tests/test_lifecycle.gd",
	"res://tests/test_sim_clock.gd",
	"res://tests/test_map_pathing.gd",
	"res://tests/test_tunnel_transit.gd",
	"res://tests/test_garden_economy.gd",
	"res://tests/test_homeostasis.gd",
	"res://tests/test_homeostasis_soak.gd",
	"res://tests/test_forager_fsm.gd",
	"res://tests/test_player_role_bot.gd",
	"res://tests/test_invaders.gd",
	"res://tests/test_chamber_vo.gd",
	"res://tests/test_sprite_catalog.gd",
	"res://tests/test_star_video.gd",
	"res://tests/test_double_tap_arm.gd",
	"res://tests/test_star_rail_layout.gd",
	"res://tests/test_star_rail_model.gd",
	"res://tests/test_landscape_shell.gd",
	"res://tests/test_camera_follow.gd",
	"res://tests/test_idle_policy.gd",
]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("======== Ant Explorer logic tests ========")
	var total_pass := 0
	var total_fail := 0

	var fixture_host := Node.new()
	fixture_host.name = "FixtureHost"
	root.add_child(fixture_host)

	for path in SUITES:
		var script: GDScript = load(path) as GDScript
		if script == null:
			push_error("Could not load %s" % path)
			total_fail += 1
			continue
		print("--- %s ---" % path.get_file())
		var suite: RefCounted = _make_suite(script, path, fixture_host)
		var result: TestAssert = await _invoke(suite)
		if result == null:
			push_error("Suite returned null: %s" % path)
			total_fail += 1
			continue
		total_pass += result.passed
		total_fail += result.failed
		print(result.summary())
		for e in result.errors:
			print("  ", e)
		for c in fixture_host.get_children():
			c.queue_free()
		await process_frame

	print("======== TOTAL: %d passed, %d failed ========" % [total_pass, total_fail])
	quit(1 if total_fail > 0 else 0)

func _make_suite(script: GDScript, path: String, host: Node) -> RefCounted:
	if path.ends_with("test_sim_clock.gd"):
		return script.new(self)
	if path.ends_with("test_brood.gd") \
			or path.ends_with("test_colony_roles.gd") \
			or path.ends_with("test_nurse_fsm.gd") \
			or path.ends_with("test_trail_marker.gd") \
			or path.ends_with("test_role_vo.gd") \
			or path.ends_with("test_map_trails.gd") \
			or path.ends_with("test_lifecycle.gd") \
			or path.ends_with("test_map_pathing.gd") \
			or path.ends_with("test_pathing_forward.gd") \
			or path.ends_with("test_pathing_tunnel_tap.gd") \
			or path.ends_with("test_tunnel_transit.gd") \
			or path.ends_with("test_garden_economy.gd") \
			or path.ends_with("test_homeostasis.gd") \
			or path.ends_with("test_homeostasis_soak.gd") \
			or path.ends_with("test_forager_fsm.gd") \
			or path.ends_with("test_player_role_bot.gd") \
			or path.ends_with("test_invaders.gd") \
			or path.ends_with("test_chamber_vo.gd") \
			or path.ends_with("test_landscape_shell.gd") \
			or path.ends_with("test_camera_follow.gd"):
		return script.new(host)
	return script.new()

func _invoke(suite: RefCounted) -> TestAssert:
	if suite == null or not suite.has_method("run"):
		return null
	var ret: Variant = suite.call("run")
	if ret is TestAssert:
		return ret as TestAssert
	return await ret

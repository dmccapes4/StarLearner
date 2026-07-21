extends SceneTree
## Headless logic tests for Math Explorer.
##   godot --headless --path . -s res://tests/run_tests.gd
## Exit code 0 = all passed; 1 = failures. Also force-loads every script so a
## compile error anywhere fails the run (headless can't render the scenes).

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
	print("======== Math Explorer tests ========")
	_test_theme()
	_test_data()
	_test_generator()
	_test_vo_coverage()
	_test_scripts_compile()
	print("======== TOTAL: %d passed, %d failed ========" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)

func _test_theme() -> void:
	_ok(MathTheme.OP_ORDER.size() == 4, "four operations")
	for op in ["add", "sub", "mul", "div"]:
		_ok(MathTheme.OPS.has(op), "OPS has %s" % op)
		_ok(not str(MathTheme.OPS[op]["symbol"]).is_empty(), "%s has a symbol" % op)
		_ok(not str(MathTheme.OPS[op]["label"]).is_empty(), "%s has a label" % op)

func _test_data() -> void:
	var tuts := MathData.tutorials()
	_ok(tuts.size() >= 5, "at least five tutorials")
	var ops_seen := {}
	for t in tuts:
		_ok(not str(t["id"]).is_empty(), "tutorial has id")
		_ok(not str(t["title"]).is_empty(), "tutorial %s has title" % t["id"])
		_ok(not str(t["example"]).is_empty(), "tutorial %s has example" % t["id"])
		_ok(MathTheme.OPS.has(t["op"]), "tutorial %s maps to a real op" % t["id"])
		ops_seen[t["op"]] = true
	_ok(ops_seen.size() == 4, "tutorials cover all four operations")

	var add := MathData.tutorial_for_op("add")
	_ok(bool(add.get("interactive", false)), "addition tutorial is interactive")

	var types := MathData.problem_types()
	_ok(types.size() >= 6, "at least six interactive problem types")
	for pt in types:
		_ok(not str(pt["id"]).is_empty(), "problem type has id")
		_ok((pt.get("ops", []) as Array).size() >= 1, "%s targets an op" % pt["id"])
		_ok(not str(pt["blurb"]).is_empty(), "%s has a blurb" % pt["id"])

	var samples := MathData.sample_problems()
	_ok(samples.size() >= 4, "at least four sample word problems")
	var by_type := {}
	for s in samples:
		by_type[s["type"]] = true
		_ok(not str(s["prompt"]).is_empty(), "%s has a prompt" % s["id"])
		_ok((s.get("steps", []) as Array).size() >= 1, "%s shows worked steps" % s["id"])
		_ok(s.has("answer"), "%s has an answer field" % s["id"])
	_ok(by_type.has("eggs_rate"), "chicken/eggs sample present")
	_ok(by_type.has("share_resources"), "shared-dolls sample present")
	_ok(by_type.has("make_change"), "counting-change sample present")
	_ok(by_type.has("rate_time"), "painting-stones rate sample present")

## Generate every template across many seeds and recompute the answer from the
## returned params — so a broken generator (wrong number, wrong formula) fails CI.
func _test_generator() -> void:
	var templates := MathProblemGen.templates()
	_ok(templates.size() >= 10, "at least ten procedural templates")
	for tid in templates:
		for s in range(0, 25):
			var p := MathProblemGen.generate(tid, s)
			_ok(not p.is_empty(), "%s[seed %d] generates" % [tid, s])
			_ok(not str(p.get("prompt", "")).is_empty(), "%s[%d] has a prompt" % [tid, s])
			_ok((p.get("steps", []) as Array).size() >= 1, "%s[%d] has steps" % [tid, s])
			_ok((p.get("subjects", []) as Array).size() >= 1, "%s[%d] names its sprites" % [tid, s])
			_ok(_recompute(tid, p) == p["answer"], "%s[%d] answer is correct" % [tid, s])

	# The two-trains problem must always end with Train B genuinely ahead.
	for s in range(0, 40):
		var p := MathProblemGen.generate("trains_gap", s)
		_ok(int(p["answer"]) > 0, "trains_gap[%d] B ends ahead (gap > 0)" % s)

	# Coin-ways helper sanity: make 12c with 2 dimes, 3 nickels, 7 pennies.
	_ok(MathProblemGen.count_coin_ways(12, 2, 3, 7) >= 1, "12c is makeable")
	_ok(MathProblemGen.count_coin_ways(3, 0, 0, 5) == 1, "3c = 3 pennies, one way")

	# Every subject a generator references must be a known sprite tag, and every
	# art-backed tag must have its file on disk.
	for tid in MathProblemGen.templates():
		var p := MathProblemGen.generate(tid, 3)
		for tag in (p.get("subjects", []) as Array):
			_ok(StorySprites.known(tag), "%s subject '%s' is a known sprite tag" % [tid, tag])
			if StorySprites.has_art(tag):
				_ok(FileAccess.file_exists(StorySprites.path(tag)),
					"sprite file exists: %s" % StorySprites.path(tag))

func _recompute(tid: String, p: Dictionary):
	var q: Dictionary = p["params"]
	match tid:
		"count_add": return int(q["a"]) + int(q["b"])
		"take_sub": return int(q["a"]) - int(q["b"])
		"groups_mul": return int(q["g"]) * int(q["n"])
		"share_div": return int(q["total"]) / int(q["buckets"])
		"eggs_rate": return (int(q["white"]) * int(q["w_eggs"]) + int(q["yellow"]) * int(q["y_eggs"])) * int(q["days"])
		"coins_make": return MathProblemGen.count_coin_ways(q["target"], q["dimes"], q["nickels"], q["pennies"])
		"share_dolls": return (int(q["start"]) + int(q["add1"]) + int(q["add2"])) / int(q["kids"])
		"paint_rate": return int(q["total"]) / (int(q["r1"]) + int(q["r2"]))
		"trains_gap": return int(q["t"]) * int(q["s_b"]) - (int(q["t"]) + int(q["h"])) * int(q["s_a"])
		"clock_elapsed": return int(q["start_h"]) + int(q["dur_h"])
	return null

## Every sentence a scene can speak (for its fixed seed pool) must have a baked
## ElevenLabs clip — so text edits without a re-bake (tools/gen_math_vo.py) fail.
func _test_vo_coverage() -> void:
	var AdditionTutorialS := load("res://scripts/AdditionTutorial.gd")
	var TrainsSceneS := load("res://scripts/TrainsScene.gd")
	var EggsSceneS := load("res://scripts/EggsScene.gd")
	var EggsDragSceneS := load("res://scripts/EggsDragScene.gd")
	var PracticeSceneS := load("res://scripts/PracticeScene.gd")
	var BlockTutorialS := load("res://scripts/BlockTutorial.gd")
	var CoinsSceneS := load("res://scripts/CoinsScene.gd")
	var MainS := load("res://scripts/Main.gd")
	var NarratorS := load("res://scripts/Narrator.gd")

	var lines: Array = []
	for op in MathTheme.OP_ORDER:
		var label := str(MathTheme.OPS[op]["label"])
		lines.append(label)
		lines.append("The %s tutorial is coming soon!" % label)
		lines.append("A story problem for %s is coming soon!" % label)
	lines.append_array(AdditionTutorialS.vo_lines(7, 4))
	for seed in TrainsSceneS.SEED_POOL:
		lines.append_array(TrainsSceneS.vo_lines(int(seed)))
	for seed in EggsSceneS.SEED_POOL:
		lines.append_array(EggsSceneS.vo_lines(int(seed)))
	for seed in EggsDragSceneS.SEED_POOL:
		lines.append_array(EggsDragSceneS.vo_lines(int(seed)))
	lines.append_array(PracticeSceneS.VO_FIXED)
	for op in ["sub", "mul", "div"]:
		lines.append_array(BlockTutorialS.vo_lines(op))
	lines.append_array(CoinsSceneS.VO_FIXED)
	lines.append_array(["Chickens & Eggs", "Two Trains", "Coin Counter",
		"Big kid ideas are coming soon!"])
	lines.append_array(MainS.intro_lines())

	var missing := 0
	for line in lines:
		for s in NarratorS.split_sentences(str(line)):
			if not FileAccess.file_exists(NarratorS.vo_path(s)):
				missing += 1
				print("  missing VO clip: ", s)
	_ok(missing == 0, "every narrated sentence has a baked ElevenLabs clip")
	_ok(lines.size() > 40, "VO enumeration is non-trivial (%d lines)" % lines.size())

func _test_scripts_compile() -> void:
	for path in [
		"res://scripts/Main.gd", "res://scripts/Narrator.gd",
		"res://scripts/MathTheme.gd", "res://scripts/MathData.gd",
		"res://scripts/CubeGroup.gd", "res://scripts/TabBar.gd",
		"res://scripts/AdditionTutorial.gd", "res://scripts/MathProblemGen.gd",
		"res://scripts/StorySprites.gd", "res://scripts/TrainsScene.gd",
		"res://scripts/EggsScene.gd", "res://scripts/EggsDragScene.gd",
		"res://scripts/VoStream.gd", "res://scripts/NarratorVoice.gd",
		"res://scripts/PracticeScene.gd", "res://scripts/BlockTutorial.gd",
		"res://scripts/CoinsScene.gd",
	]:
		_ok(load(path) != null, "compiles: %s" % path)

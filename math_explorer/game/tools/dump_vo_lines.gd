extends SceneTree
## Enumerate every sentence the narrator can ever speak and write a manifest
## (md5 key → text) for tools/gen_math_vo.py to bake with ElevenLabs.
##
## Dynamic lines are covered because each scene draws its numbers from a fixed
## SEED_POOL and exposes vo_lines(seed) — a pure function of the seed — so the
## runtime md5 lookup always hits a baked clip.
##
##   godot --headless --path . -s res://tools/dump_vo_lines.gd

const AdditionTutorial := preload("res://scripts/AdditionTutorial.gd")
const TrainsScene := preload("res://scripts/TrainsScene.gd")
const EggsScene := preload("res://scripts/EggsScene.gd")
const EggsDragScene := preload("res://scripts/EggsDragScene.gd")
const PracticeScene := preload("res://scripts/PracticeScene.gd")
const BlockTutorial := preload("res://scripts/BlockTutorial.gd")
const CoinsScene := preload("res://scripts/CoinsScene.gd")
const MainScript := preload("res://scripts/Main.gd")
const NarratorScript := preload("res://scripts/Narrator.gd")

const OUT_PATH := "res://data/math_vo_manifest.json"

var _lines: Dictionary = {}  ## md5 → sentence

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	# Main.gd: tab labels + coming-soon lines.
	for op in MathTheme.OP_ORDER:
		var label := str(MathTheme.OPS[op]["label"])
		_add(label)
		_add("The %s tutorial is coming soon!" % label)
		_add("A story problem for %s is coming soon!" % label)

	# Addition tutorial (Main launches 7 + 4 today; bake nearby pairs too so
	# future problem variety stays covered).
	for pair in [[7, 4], [6, 3], [8, 5], [5, 4], [9, 3], [6, 5], [4, 3], [8, 4]]:
		for s in AdditionTutorial.vo_lines(pair[0], pair[1]):
			_add(str(s))

	# Story scenes: every line for every seed in each scene's pool.
	for seed in TrainsScene.SEED_POOL:
		for s in TrainsScene.vo_lines(int(seed)):
			_add(str(s))
	for seed in EggsScene.SEED_POOL:
		for s in EggsScene.vo_lines(int(seed)):
			_add(str(s))
	for seed in EggsDragScene.SEED_POOL:
		for s in EggsDragScene.vo_lines(int(seed)):
			_add(str(s))

	# Practice mode: fixed praise/coaching lines are baked; the dynamic equation
	# speech ("What is 6 plus 3?") intentionally uses the OS TTS fallback.
	for s in PracticeScene.VO_FIXED:
		_add(str(s))

	# Block tutorials (fixed numbers per op).
	for op in ["sub", "mul", "div"]:
		for s in BlockTutorial.vo_lines(op):
			_add(str(s))

	# Coin counter fixed lines ("Make 12 cents." totals use the TTS fallback).
	for s in CoinsScene.VO_FIXED:
		_add(str(s))

	# Game-tab card titles + menu extras (spoken on tab select / menu tap).
	for s in ["Chickens & Eggs", "Two Trains", "Coin Counter",
			"Big kid ideas are coming soon!"]:
		_add(str(s))

	# Launch intro tour (highlights each tile + the ☰ menu).
	for s in MainScript.intro_lines():
		_add(str(s))

	var chars := 0
	for key in _lines:
		chars += str(_lines[key]).length()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://data"))
	var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(_lines, "  ", false))
	f.close()
	print("wrote %s: %d sentences, %d chars" % [
		ProjectSettings.globalize_path(OUT_PATH), _lines.size(), chars])
	quit()

func _add(text: String) -> void:
	for s in NarratorScript.split_sentences(text):
		_lines[NarratorScript.vo_key(s)] = s

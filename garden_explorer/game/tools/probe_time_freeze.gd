extends SceneTree
## Verify game time (garden tick + season clock) freezes during narration
## locks and resumes afterwards.

const SpeakScript := preload("res://scripts/audio/Speak.gd")
const NarratorScript := preload("res://scripts/audio/Narrator.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var save := root.get_node_or_null("/root/Save")
	if save and save.has_method("clear_all"):
		save.clear_all()
	if save and save.has_method("set_intro_completed"):
		save.set_intro_completed(true)
	var main: Node = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for _i in 30:
		await process_frame
	var world: Node = main.get_node("World")
	var clock: Node = world.get("season_clock")
	var garden: GardenState = world.garden
	garden.plant("bed_0", 0, "lettuce")

	## Let any boot narration drain first.
	while NarratorScript.blocks_movement():
		await process_frame
	await create_timer(0.5, true).timeout

	## 1) Clock runs while free.
	var e0: float = clock.elapsed
	await create_timer(1.0, true).timeout
	var ran: float = clock.elapsed - e0
	print("free_run elapsed_delta=%.2f (expect ~1.0)" % ran)

	## 2) Clock + garden freeze during a narration lock.
	SpeakScript.line("This is a long narration line used to lock player movement for several seconds so we can measure the clock.")
	await process_frame
	var e1: float = clock.elapsed
	var st1: float = float(garden.get_slot("bed_0", 0).get("stage_time", 0.0))
	await create_timer(1.5, true).timeout
	var frozen_clock: float = clock.elapsed - e1
	var frozen_stage: float = float(garden.get_slot("bed_0", 0).get("stage_time", 0.0)) - st1
	print("during_narration clock_delta=%.3f stage_time_delta=%.3f (expect ~0)" % [frozen_clock, frozen_stage])

	## 3) Resumes after the lock releases.
	while NarratorScript.blocks_movement():
		await process_frame
	var e2: float = clock.elapsed
	await create_timer(1.0, true).timeout
	var resumed: float = clock.elapsed - e2
	print("after_narration elapsed_delta=%.2f (expect ~1.0)" % resumed)

	var ok := ran > 0.7 and frozen_clock < 0.1 and frozen_stage < 0.1 and resumed > 0.7
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)

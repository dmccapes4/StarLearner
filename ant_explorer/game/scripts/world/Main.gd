extends Node
## Root scene wiring. Logic tests: godot --headless -s res://tests/run_tests.gd

@onready var world: Node2D = $World
@onready var tap_router: Node = $TapRouter
@onready var debug_hud: CanvasLayer = $DebugHUD

func _ready() -> void:
	var cam := world.get_node_or_null("CameraFollow") as Camera2D
	if tap_router and cam and tap_router.has_method("set_camera"):
		tap_router.call("set_camera", cam)
	var living := 0
	var rooms := 0
	if world and world.get("colony"):
		living = world.colony.living_count()
	if world and world.get("graph"):
		rooms = world.graph.chambers.size()
	print("Ant Explorer Phase 5 — %d rooms, %d living ants" % [rooms, living])
	print("Outdoor surface: foragers cut leaves. Invasion clearing: soldiers fend without harm.")
	print("Walk near yellow stars and stop beside them to unlock ant documentaries (12 clips, saved progress).")
	print("Tap a glowing pheromone icon to join a job — nurse, forager, gardener, soldier, waste, or scout.")
	print("While working, click anywhere to exit the trail and explore again.")

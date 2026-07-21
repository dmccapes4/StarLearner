extends Node
## Autoload: exposes GameConfig tunables from data/config.tres.

const CONFIG_PATH := "res://data/config.tres"

var data: GameConfig

func _ready() -> void:
	if ResourceLoader.exists(CONFIG_PATH):
		data = load(CONFIG_PATH) as GameConfig
	if data == null:
		push_warning("Config: missing data/config.tres — using defaults")
		data = GameConfig.new()

func get_sim_hz() -> float:
	return data.sim_hz

func get_agent_cap() -> int:
	return data.agent_cap

func get_walk_speed() -> float:
	return data.walk_speed_sim

func get_camera_lerp() -> float:
	return data.camera_lerp

func get_camera_zoom() -> float:
	return data.camera_zoom

func get_phase0_npc_count() -> int:
	return data.phase0_npc_count

func get_phase1_nurse_count() -> int:
	return data.phase1_nurse_count

func get_phase1_other_count() -> int:
	return data.phase1_other_count

func get_larva_tap_radius() -> float:
	return data.larva_tap_radius

func get_star_approach_radius() -> float:
	return data.star_approach_radius

func get_star_dwell_seconds() -> float:
	return data.star_dwell_seconds

func get_star_visual_scale() -> float:
	return data.star_visual_scale

func get_garden_health() -> float:
	return data.garden_health

func get_brood_k() -> float:
	return data.brood_k

func get_brood_min() -> int:
	return data.brood_min

func get_brood_max() -> int:
	return data.brood_max

func get_pupa_ticks() -> int:
	return data.pupa_ticks

func get_egg_interval() -> int:
	return data.egg_interval

func get_egg_ferry_min() -> int:
	return data.egg_ferry_min

func get_egg_ferry_max_nurses() -> int:
	return data.egg_ferry_max_nurses

func get_max_age() -> int:
	return data.max_age

func get_larva_passive_nutrition() -> float:
	return data.larva_passive_nutrition

func get_pupate_gap_ticks() -> int:
	return data.pupate_gap_ticks

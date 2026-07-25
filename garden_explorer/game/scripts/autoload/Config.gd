extends Node
## Autoload tunables.

var walk_speed: float = 105.0
var camera_lerp: float = 0.08
var camera_zoom: float = 2.05
var arrive_eps: float = 14.0
## How close the gardener must be (world px) before an action prompt may open.
var interact_arrive_eps: float = 28.0
var tap_ripple_sec: float = 0.35

## Phase 3 growth — keep first harvest under ~3 minutes with regular watering.
var water_per_tap: float = 1.0
var growth_per_water: float = 6.0 ## progress points per effective water
var growth_threshold_scale: float = 0.45 ## shrink seed.json tick thresholds

## Phase 4 — season length (seconds). ≤0 uses seasons.json.
var season_duration_sec: float = 0.0
var animal_tap_radius: float = 48.0
## Reveal tiles (animal/bug/season): tap window after narration ends.
var reveal_window_sec: float = 5.0

func get_walk_speed() -> float:
	return walk_speed

func get_camera_lerp() -> float:
	return camera_lerp

func get_camera_zoom() -> float:
	return camera_zoom

func get_interact_arrive_eps() -> float:
	return interact_arrive_eps

func get_arrive_eps() -> float:
	return arrive_eps

func get_water_per_tap() -> float:
	return water_per_tap

func get_growth_per_water() -> float:
	return growth_per_water

func get_growth_threshold_scale() -> float:
	return growth_threshold_scale

func get_season_duration_sec() -> float:
	return season_duration_sec

func get_animal_tap_radius() -> float:
	return animal_tap_radius

func get_reveal_window_sec() -> float:
	return reveal_window_sec

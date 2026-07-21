class_name GameConfig
extends Resource
## Tunable constants — edit data/config.tres, no code changes needed for balance.

@export var sim_hz: float = 2.5
@export var agent_cap: int = 100
@export var phase0_npc_count: int = 20
@export var phase1_nurse_count: int = 6
@export var phase1_other_count: int = 6
@export var phase2_foragers: int = 30
@export var phase2_gardeners: int = 12
@export var phase2_nurses: int = 14
@export var phase2_soldiers: int = 14

@export var walk_speed_sim: float = 64.0  ## px per sim tick; calm exploration pace
@export var camera_lerp: float = 0.06
@export var camera_zoom: float = 0.72  ## chamber fills the view; click-to-move only
@export var tap_target_px: float = 96.0
@export var larva_tap_radius: float = 48.0
@export var star_approach_radius: float = 90.0
@export var star_dwell_seconds: float = 0.75
@export var star_visual_scale: float = 2.4

# Brood (Phase 1) — tuned so feed→eclose is watchable in ~60–90s
@export var brood_k: float = 0.2
@export var brood_min: int = 15
@export var brood_max: int = 25
@export var larva_nutrition_stage: PackedFloat32Array = PackedFloat32Array([6.0, 12.0, 18.0])
@export var feed_nutrition: float = 2.0
@export var player_feed_nutrition: float = 5.0
@export var jh_step: float = 1.0
@export var player_jh_step: float = 2.0
@export var pupa_ticks: int = 30
@export var caste_destiny_high: float = 22.0
@export var caste_destiny_mid: float = 19.0
@export var garden_health: float = 0.75  ## initial; Garden owns live value in Phase 2
@export var nurse_action_pause: int = 4
@export var nest_cluster_radius: float = 320.0  ## brood cluster spread in the enlarged nursery
@export var cut_ticks: int = 6
@export var deposit_ticks: int = 4

# Population
@export var egg_interval: int = 50
@export var max_age: int = 4000

# Garden
@export var garden_deposit_gain: float = 0.025
@export var garden_waste_decay: float = 0.004

# Invaders (gentle, no death)
@export var invader_cooldown_min: int = 125
@export var invader_cooldown_max: int = 275

# Caste steady-state targets
@export var target_soldiers: int = 14
@export var target_foragers: int = 32
@export var target_minors: int = 28
@export var target_brood: int = 20

# Homeostasis feedback — the closed-loop colony controller (shipped ON).
# Set homeo_enabled = false (or both strengths to 0) to revert to fixed-ratio
# destiny thresholds. See scripts/sim/Homeostasis.gd and REPORT_SIMULATION §4a.
@export var homeo_enabled: bool = true  ## kill-switch: false → old fixed-threshold colony
@export var homeo_caste_bias_strength: float = 5.0  ## score-units the pressure can shift caste thresholds
@export var homeo_jh_bias_strength: float = 0.5     ## ±fraction the pressure scales JH dosing

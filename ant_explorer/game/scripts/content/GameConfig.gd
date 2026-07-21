class_name GameConfig
extends Resource
## Tunable constants — edit data/config.tres, no code changes needed for balance.

@export var sim_hz: float = 2.5
@export var agent_cap: int = 140
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

# Brood — denser nursery/pupa rooms; pupae linger so castes-in-waiting stay visible
@export var brood_k: float = 0.35
@export var brood_min: int = 28
@export var brood_max: int = 48
@export var larva_nutrition_stage: PackedFloat32Array = PackedFloat32Array([14.0, 28.0, 48.0])
@export var feed_nutrition: float = 1.5
@export var player_feed_nutrition: float = 4.0
@export var jh_step: float = 1.0
@export var player_jh_step: float = 2.0
@export var pupa_ticks: int = 70
# Tuned above pupate nutrition (~48) so "just pupated" ≠ automatic soldier.
@export var caste_destiny_high: float = 58.0
@export var caste_destiny_mid: float = 50.0
@export var garden_health: float = 0.75  ## initial; Garden owns live value in Phase 2
@export var nurse_action_pause: int = 4
@export var nest_cluster_radius: float = 320.0  ## brood cluster spread in the enlarged nursery
@export var cut_ticks: int = 6
@export var deposit_ticks: int = 4

# Population — NPC workers age out so eggs/pupae keep churning
@export var egg_interval: int = 10  ## queen lays fairly often so a visible pile can form
@export var egg_ferry_min: int = 3  ## nurses wait until the pile has this many eggs
@export var egg_ferry_max_nurses: int = 1  ## at most this many nurses on egg duty
@export var max_age: int = 1200  ## ~8 min at 2.5 Hz; queen/player never age out
@export var larva_passive_nutrition: float = 0.12  ## background drip; per-larva growth_rate desyncs it
@export var pupate_gap_ticks: int = 12  ## min ticks between passive pupations (~5s @ 2.5Hz)

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
@export var target_brood: int = 36

# Homeostasis feedback — the closed-loop colony controller (shipped ON).
# Set homeo_enabled = false (or both strengths to 0) to revert to fixed-ratio
# destiny thresholds. See scripts/sim/Homeostasis.gd and REPORT_SIMULATION §4a.
@export var homeo_enabled: bool = true  ## kill-switch: false → old fixed-threshold colony
@export var homeo_caste_bias_strength: float = 5.0  ## score-units the pressure can shift caste thresholds
@export var homeo_jh_bias_strength: float = 0.5     ## ±fraction the pressure scales JH dosing

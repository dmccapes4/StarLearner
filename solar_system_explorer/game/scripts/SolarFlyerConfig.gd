class_name SolarFlyerConfig
extends Resource
## Tunable knobs for the 3D flyer (§3.4 / §23 of STRATEGY_3D_FLYER).
## Defaults live in `res://data/solar_flyer_config.tres`. Optional JSON overlay
## (no APK rebuild): `/sdcard/AntPhone/solar_flyer.json` or `user://solar_flyer.json`.

const RES_PATH := "res://data/solar_flyer_config.tres"
const OVERRIDE_PATHS := [
	"user://solar_flyer.json",
	"/sdcard/AntPhone/solar_flyer.json",
	"/data/local/tmp/solar_flyer.json",
]

const OVERRIDE_KEYS := [
	"distance_base", "distance_span", "compression_exp", "a_max_au",
	"hero_min", "hero_max", "sun_hero_r",
	"cruise_speed", "game_year_seconds", "sun_clearance",
	"hop_min_s", "hop_max_s", "course_samples", "intercept_iters",
	"burn_accel", "v_max", "icon_scale",
	"orbit_time_scale", "belt_fade_near", "belt_fade_far",
]

@export var distance_base: float = 12.0
@export var distance_span: float = 420.0
@export var compression_exp: float = 0.45
@export var a_max_au: float = 39.5

@export var hero_min: float = 1.2
@export var hero_max: float = 12.0
@export var sun_hero_r: float = 16.0

## Marker size rule: in flight every world is an icon MARKER of world size
## icon_scale · distance · tier — a small constant screen size (the legible
## minimum at tier 1.0 ≈ Earth), tiered only for recognition (Jupiter reads
## double Earth). Markers look far away; space feels enormous.
@export var icon_scale: float = 0.023

## Orbital clock multiplier while parked in orbit (STRATEGY §4.3): the system
## slows to a near-rest so narration plays over a still sky. 1× restores on
## the next charted course.
@export var orbit_time_scale: float = 0.1

## Belt reveal (STRATEGY §5.1): rocks are fully visible within belt_fade_near
## of the camera, fully invisible beyond belt_fade_far — the belt is a
## surprise you fly INTO, not a dotted line across the sky.
@export var belt_fade_near: float = 35.0
@export var belt_fade_far: float = 70.0

## Legacy straight-line speed — only seeds the first intercept guess now.
@export var cruise_speed: float = 11.0
## Burn simulation (STRATEGY_FLIGHT_DYNAMICS_AND_PROXIMITY §1): constant-thrust
## accelerate → coast at v_max → flip-and-brake. Trip time emerges from these.
@export var burn_accel: float = 1.1
@export var v_max: float = 17.0
@export var game_year_seconds: float = 45.0
@export var sun_clearance: float = 18.0
## Design band asserted by ScaleTune — NOT a runtime clamp (burn profile owns time).
## Physics is ground truth: at close conjunction a neighbour world can pass
## right by the ship, making that hop genuinely tiny on a short transfer
## arc. The band is a design assertion, not a runtime clamp.
@export var hop_min_s: float = 1.5
@export var hop_max_s: float = 55.0
@export var course_samples: int = 96
@export var intercept_iters: int = 10

static func load_default() -> SolarFlyerConfig:
	var cfg: SolarFlyerConfig = null
	if ResourceLoader.exists(RES_PATH):
		var res := load(RES_PATH)
		if res is SolarFlyerConfig:
			cfg = (res as SolarFlyerConfig).duplicate(true) as SolarFlyerConfig
	if cfg == null:
		cfg = SolarFlyerConfig.new()
	_apply_json_overlays(cfg)
	return cfg

static func _apply_json_overlays(cfg: SolarFlyerConfig) -> void:
	for path in OVERRIDE_PATHS:
		if not FileAccess.file_exists(path):
			continue
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			continue
		var text := f.get_as_text()
		var parsed = JSON.parse_string(text)
		if typeof(parsed) != TYPE_DICTIONARY:
			push_warning("SolarFlyerConfig: ignore non-object JSON at %s" % path)
			continue
		ScaleTune.apply_overrides(cfg, parsed)
		print("SolarFlyerConfig: applied overlay ", path)
		return  # first hit wins

## Write current values as JSON (handy for capturing a tuned set).
func to_overlay_dict() -> Dictionary:
	var d := {}
	for k in OVERRIDE_KEYS:
		d[k] = get(k)
	return d

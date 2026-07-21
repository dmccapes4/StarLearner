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
	"focus_dist", "min_dot", "mesh_in", "mesh_out",
	"cruise_speed", "game_year_seconds", "sun_clearance",
	"hop_min_s", "hop_max_s", "course_samples", "intercept_iters",
]

@export var distance_base: float = 12.0
@export var distance_span: float = 340.0
@export var compression_exp: float = 0.45
@export var a_max_au: float = 39.5

@export var hero_min: float = 1.2
@export var hero_max: float = 12.0
@export var sun_hero_r: float = 16.0

@export var focus_dist: float = 26.0
@export var min_dot: float = 0.55
@export var mesh_in: float = 60.0
@export var mesh_out: float = 170.0

@export var cruise_speed: float = 11.0
@export var game_year_seconds: float = 30.0
@export var sun_clearance: float = 18.0
@export var hop_min_s: float = 12.0
@export var hop_max_s: float = 40.0
@export var course_samples: int = 48
@export var intercept_iters: int = 4

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

extends SceneTree
## Enumerate every sentence the narrator can ever speak and write a manifest
## (md5 key → text) for tools/gen_solar_vo.py to bake with ElevenLabs.
##
## Dynamic lines are covered by enumerating all origin → destination pairs:
## the arrival AU/miles figures and the trip-plot sentences are pure functions
## of the pair, so the runtime md5 lookup always hits a baked clip.
##
##   godot --headless --path . -s res://tools/dump_vo_lines.gd

const TitleView := preload("res://scripts/TitleView.gd")
const OrreryView := preload("res://scripts/OrreryView.gd")
const AstronautIntro := preload("res://scripts/AstronautIntro.gd")
const FlySceneScript := preload("res://scripts/FlyScene.gd")
const PlotBoardScript := preload("res://scripts/PlotBoard.gd")
const NarratorScript := preload("res://scripts/Narrator.gd")

const OUT_PATH := "res://data/solar_vo_manifest.json"

var _lines: Dictionary = {}  ## md5 → sentence

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_add(TitleView.WELCOME)
	_add(OrreryView.CLOSING)
	_add(AstronautIntro.BRIEFING)

	# Burn-phase beats spoken during every flight.
	_add(FlySceneScript.LINE_LAUNCH)
	_add(FlySceneScript.LINE_CRUISE)
	_add(FlySceneScript.LINE_BRAKE)
	# Engines-arming beat while the entry cinematic is already baked in.
	_add(PlotBoardScript.LINE_ENGINES)

	# Body blurbs (orrery tour + video card) + the video-card suffix.
	for b in SolarData.bodies() + SolarData.major_asteroids():
		_add(str(b.get("blurb", "")))

	# Belt-tap intros: one per major asteroid the tap can resolve to.
	for a in SolarData.major_asteroids():
		_add(OrbitMath.belt_intro_sentence(a))
	_add("A video about it is coming soon.")
	_add("Now let's look at them up close…")

	# Trip plot + arrival lines for every ordered pair the ship can fly.
	var cfg := SolarFlyerConfig.load_default()
	var dests := SolarData.flyer_destinations(cfg)
	for origin in dests:
		for dest in dests:
			if str(origin["id"]) == str(dest["id"]):
				continue
			for s in OrbitMath.trip_narration_sentences_all(origin, dest, cfg):
				_add(s)
			var travel_au: float = absf(
				float(dest.get("a_au", 0.0)) - float(origin.get("a_au", 0.0)))
			_add(OrbitMath.arrival_narration(str(dest.get("name", "")), travel_au,
				bool(dest.get("is_star", false))))
	# Main.gd fallback when the route lacks travel_au: distance from Earth.
	for dest in dests:
		var fallback_au: float = absf(float(dest.get("a_au", 1.0)) - 1.0)
		_add(OrbitMath.arrival_narration(str(dest.get("name", "")), fallback_au,
			bool(dest.get("is_star", false))))

	var chars := 0
	for key in _lines:
		chars += str(_lines[key]).length()
	var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(_lines, "  ", false))
	f.close()
	print("wrote %s: %d sentences, %d chars" % [
		ProjectSettings.globalize_path(OUT_PATH), _lines.size(), chars])
	quit()

func _add(text: String) -> void:
	for s in NarratorScript.split_sentences(text):
		_lines[NarratorScript.vo_key(s)] = s

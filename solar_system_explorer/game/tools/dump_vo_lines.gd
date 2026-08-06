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
const PlaygroundScript := preload("res://scripts/PlaygroundScene.gd")
const FlightChooserScript := preload("res://scripts/FlightChooser.gd")
const SpeedModeChooser := preload("res://scripts/SpeedModeChooser.gd")
const CourseModeChooser := preload("res://scripts/CourseModeChooser.gd")
const PropulsionChooser := preload("res://scripts/PropulsionChooser.gd")

const OUT_PATH := "res://data/solar_vo_manifest.json"

var _lines: Dictionary = {}  ## md5 → sentence

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_add(TitleView.LINE_SHIP)
	_add(TitleView.LINE_SOLAR)
	_add(TitleView.WELCOME)
	_add(FlightChooserScript.LINE_MISSION)
	_add(FlightChooserScript.LINE_FREE)
	_add(FlightChooserScript.NARRATION)
	_add(CourseModeChooser.LINE_KID)
	_add(CourseModeChooser.LINE_ROCKET)
	_add(PropulsionChooser.LINE_CHEM)
	_add(PropulsionChooser.LINE_NTP)
	_add(PropulsionChooser.LINE_ORION)
	_add(OrreryView.CLOSING)
	_add(OrreryView.BOOT_LINE)
	_add(AstronautIntro.BRIEFING_MISSION)
	_add(AstronautIntro.BRIEFING_FREE_FLIGHT)

	# Burn-phase beats spoken during every flight.
	_add(FlySceneScript.LINE_LAUNCH)
	_add(FlySceneScript.LINE_CRUISE)
	_add(FlySceneScript.LINE_BRAKE)
	_add(FlySceneScript.LINE_COAST_BOOST)
	_add(FlySceneScript.LINE_COAST_BOOST_YEARS)
	_add(FlySceneScript.LINE_COAST_SKIP)
	# Engines-arming beat while the entry cinematic is already baked in.
	_add(PlotBoardScript.LINE_ENGINES)
	# Rocket Science Hohmann window wait (orrery time-lapse / calendar skip).
	_add(PlotBoardScript.LINE_WINDOW)
	_add(PlotBoardScript.LINE_WINDOW_SKIP)
	# Rocket Science engine explainers (also embedded in mission_briefing).
	_add(AstrogatorPanel.engine_explain("chemical"))
	_add(AstrogatorPanel.engine_explain("ntp"))
	_add(AstrogatorPanel.engine_explain("orion"))

	# Free-flight playground beats (tap controls + legacy lines).
	_add(PlaygroundScript.LINE_WELCOME)
	_add(PlaygroundScript.LINE_WELCOME_TAP)
	_add(PlaygroundScript.LINE_CRUISE_DECAY)
	_add(PlaygroundScript.LINE_BAND)
	_add(PlaygroundScript.LINE_SEEK_CANCEL)
	for b in SolarData.flyer_bodies(SolarFlyerConfig.load_default()):
		if bool(b.get("belt", false)):
			continue
		_add(PlaygroundScript.LINE_SEEK % str(b.get("name", "")))
	_add(PlaygroundScript.LINE_TUT_RIGHT)
	_add(PlaygroundScript.LINE_TUT_LEFT)
	_add(PlaygroundScript.LINE_TUT_UP)
	_add(PlaygroundScript.LINE_TUT_DOWN)
	_add(PlaygroundScript.LINE_TUT_LIFT)
	_add(PlaygroundScript.LINE_TUT_LOWER)
	_add(PlaygroundScript.LINE_TUT_LIFT_CRUISE)
	_add(PlaygroundScript.LINE_TUT_LOWER_CRUISE)
	_add(PlaygroundScript.LINE_AIM)
	_add(SpeedModeChooser.LINE_GEARS)
	_add(SpeedModeChooser.LINE_CRUISE)
	_add(PlaygroundScript.LINE_STOP)
	_add(PlaygroundScript.LINE_RESUME)
	_add(PlaygroundScript.LINE_SPEEDING)
	_add(PlaygroundScript.LINE_SLOWING)
	_add(PlaygroundScript.LINE_JOY_READY)
	_add(PlaygroundScript.LINE_MIN)
	_add(PlaygroundScript.LINE_CRUISE_SPEED)
	_add(PlaygroundScript.LINE_MAX)
	_add(PlaygroundScript.LINE_ALREADY_MAX)
	_add(PlaygroundScript.LINE_ALREADY_STOP)
	for b in SolarData.flyer_destinations():
		_add("You have arrived at %s!" % str(b.get("name", "")))

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
			# Rocket Science pre-chart briefings (engine + window + fuel + assists).
			var phase := AstrogatorPanel.phase_now_rad(origin, dest, 0.0)
			var bud: Dictionary = RealismBudget.hop_budget(origin, dest, phase)
			for prop in AstrogatorPanel.PROP_ORDER:
				_add(AstrogatorPanel.mission_briefing(origin, dest, bud, prop, cfg))
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

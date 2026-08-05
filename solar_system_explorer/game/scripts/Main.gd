extends Node
## Solar System Explorer — flow controller.
##
##   Title boot: 3s orrery cinematic ("Welcome to Solar System Explorer!")
##      ─▶ Title (two tiles, gold-outline narration)
##      ─▶ Spaceship ─▶ FlightChooser (two tiles)
##           ─▶ Mission Flight ─▶ Astronaut briefing ─▶ ScrollView
##                ─▶ CourseModeChooser (Quick Course / Rocket Science)
##                     ─▶ [Rocket] PropulsionChooser ─▶ PlotBoard ─▶ FlyScene
##           ─▶ Free Flight ─▶ Astronaut briefing (tilt + surge) ─▶ Playground
##      ─▶ Solar System ─▶ Orrery tour ─▶ back to Title
##
## Flip USE_3D_FLYER to false for strip → video only (no 3D hop).

const USE_3D_FLYER := true

const Starfield := preload("res://scripts/Starfield.gd")
const TitleView := preload("res://scripts/TitleView.gd")
const OrreryView := preload("res://scripts/OrreryView.gd")
const ScrollView := preload("res://scripts/ScrollView.gd")
const PlotBoard := preload("res://scripts/PlotBoard.gd")
const FlyScene := preload("res://scripts/FlyScene.gd")
const VideoPanel := preload("res://scripts/VideoPanel.gd")
const AstronautIntro := preload("res://scripts/AstronautIntro.gd")
const PlaygroundScene := preload("res://scripts/PlaygroundScene.gd")
const FlightChooser := preload("res://scripts/FlightChooser.gd")
const CourseModeChooser := preload("res://scripts/CourseModeChooser.gd")
const PropulsionChooser := preload("res://scripts/PropulsionChooser.gd")
const NavModes := preload("res://scripts/NavModes.gd")

var _title: TitleView
var _chooser: FlightChooser
var _course_mode: CourseModeChooser
var _propulsion: PropulsionChooser
var _orrery: OrreryView
var _scroll: ScrollView
var _board: PlotBoard
var _fly: FlyScene
var _playground: PlaygroundScene
var _video: VideoPanel
var _astro: AstronautIntro
var _ship_at: String = "earth"
var _pending_dest: String = ""
var _last_route: Dictionary = {}
var _in_playground: bool = false

func _ready() -> void:
	var starfield := Starfield.new()
	add_child(starfield)

	_title = TitleView.new()
	_chooser = FlightChooser.new()
	_course_mode = CourseModeChooser.new()
	_propulsion = PropulsionChooser.new()
	_orrery = OrreryView.new()
	_scroll = ScrollView.new()
	_board = PlotBoard.new()
	_fly = FlyScene.new()
	_playground = PlaygroundScene.new()
	_video = VideoPanel.new()
	_astro = AstronautIntro.new()
	add_child(_title)
	add_child(_chooser)
	add_child(_course_mode)
	add_child(_propulsion)
	add_child(_orrery)
	add_child(_scroll)
	add_child(_board)
	add_child(_fly)
	add_child(_playground)
	add_child(_video)
	add_child(_astro)

	_title.flight_pressed.connect(_on_flight)
	_title.explainer_pressed.connect(_on_explainer)
	_chooser.mission_pressed.connect(_on_mission_flight)
	_chooser.free_flight_pressed.connect(_on_free_flight)
	_chooser.go_home.connect(_show_title)
	_course_mode.kid_pressed.connect(_on_course_kid)
	_course_mode.rocket_pressed.connect(_on_course_rocket)
	_course_mode.go_home.connect(_on_course_mode_back)
	_propulsion.propulsion_picked.connect(_on_propulsion_picked)
	_propulsion.go_home.connect(_on_propulsion_back)
	_orrery.tour_finished.connect(_show_title)
	_orrery.go_home.connect(_show_title)
	_scroll.go_home.connect(_show_title)
	_scroll.body_selected.connect(_on_body_selected)
	_board.go_home.connect(_show_title)
	_board.course_committed.connect(_on_course_committed)
	_fly.go_home.connect(_show_title)
	_fly.arrived.connect(_on_flight_arrived)
	_fly.learn_more.connect(_on_learn_more)
	_fly.chart_course.connect(_on_chart_new_course)
	_playground.go_home.connect(_show_title)
	_playground.arrived.connect(_on_playground_arrived)
	_playground.learn_more.connect(_on_learn_more)
	_video.closed.connect(_on_video_closed)
	_astro.finished.connect(_on_astro_finished)

	_hide_all_views()
	call_deferred("_boot_sequence")

func _boot_sequence() -> void:
	# 3s orrery welcome, then the two-tile hub with gold-outline narration.
	_title.visible = false
	await _orrery.play_boot_intro()
	_set_view(_title)

func _on_flight() -> void:
	# Spaceship → chooser first: Mission Flight (plot a course) or Free Flight.
	_set_view(_chooser)

func _on_mission_flight() -> void:
	_in_playground = false
	_show_scroll()
	_astro.begin(AstronautIntro.BRIEFING_MISSION)

func _on_free_flight() -> void:
	_in_playground = true
	_hide_all_views()
	_astro.begin(AstronautIntro.BRIEFING_FREE_FLIGHT)

func _on_explainer() -> void:
	_set_view(_orrery)
	_orrery.begin_tour()

func _show_title() -> void:
	_orrery.stop_tour()
	_fly.set_active(false)
	_playground.set_active(false)
	_in_playground = false
	_set_view(_title)

func _on_astro_finished() -> void:
	if _in_playground:
		_playground.set_active(true)
		_playground.begin(_ship_at)

func _show_scroll() -> void:
	_fly.set_active(false)
	_board.set_active(false)
	_set_view(_scroll)
	_scroll.set_ship_at(_ship_at)
	_scroll.begin_exploration()

func _on_body_selected(id: String) -> void:
	if not USE_3D_FLYER:
		_ship_at = id
		_video.play_body(id)
		return
	# Re-tap the world you're already at → optional documentary (including the Sun).
	if id == _ship_at:
		_video.play_body(id)
		return
	# Choose Quick Course vs Rocket Science (and engines) BEFORE charting.
	_pending_dest = id
	var body := SolarData.flyer_body_by_id(id)
	var name := str(body.get("name", id)) if not body.is_empty() else id
	_scroll.set_active(false)
	_scroll.visible = false
	_course_mode.begin_for(name)

func _on_course_mode_back() -> void:
	_pending_dest = ""
	_course_mode.set_active(false)
	_show_scroll()

func _on_course_kid() -> void:
	_course_mode.set_active(false)
	_start_plot(AstrogatorPanel.PACE_KID, AstrogatorPanel.PROP_CHEMICAL)

func _on_course_rocket() -> void:
	_course_mode.set_active(false)
	var body := SolarData.flyer_body_by_id(_pending_dest)
	var name := str(body.get("name", _pending_dest)) if not body.is_empty() \
		else _pending_dest
	_propulsion.begin_for(name)

func _on_propulsion_back() -> void:
	_propulsion.set_active(false)
	var body := SolarData.flyer_body_by_id(_pending_dest)
	var name := str(body.get("name", _pending_dest)) if not body.is_empty() \
		else _pending_dest
	_course_mode.begin_for(name)

func _on_propulsion_picked(propulsion_id: String) -> void:
	_propulsion.set_active(false)
	await _speak_rocket_briefing(propulsion_id)
	if _pending_dest.is_empty():
		return
	_start_plot(AstrogatorPanel.PACE_ASTROGATOR, propulsion_id)

## Engine science + window + fuel weight + gravity-assist honesty, before chart.
func _speak_rocket_briefing(propulsion_id: String) -> void:
	var cfg := SolarFlyerConfig.load_default()
	var origin := SolarData.flyer_body_by_id(_ship_at, cfg)
	var dest := SolarData.flyer_body_by_id(_pending_dest, cfg)
	if origin.is_empty() or dest.is_empty():
		return
	var phase := AstrogatorPanel.phase_now_rad(origin, dest, 0.0)
	var budget: Dictionary = RealismBudget.hop_budget(origin, dest, phase)
	var text := AstrogatorPanel.mission_briefing(
		origin, dest, budget, propulsion_id, cfg)
	var dur := Narrator.speak(text)
	var t := 0.0
	var target: float = maxf(dur, 4.0)
	while t < target:
		if Narrator.is_playing():
			while Narrator.is_playing() and t < 45.0:
				await get_tree().create_timer(0.05).timeout
				t += 0.05
			await get_tree().create_timer(0.4).timeout
			return
		await get_tree().create_timer(0.05).timeout
		t += 0.05

func _start_plot(pace_mode: String, propulsion_id: String) -> void:
	if _pending_dest.is_empty():
		_show_scroll()
		return
	var dest := _pending_dest
	_pending_dest = ""
	_board.set_ship_at(_ship_at)
	_board.set_mission_mode(pace_mode, propulsion_id)
	_set_view(_board)
	_board.begin_plot(dest)

func _on_course_committed(dest_id: String, route: Dictionary, t0: float) -> void:
	_last_route = route
	_board.set_active(false)
	# Rocket Science = cockpit SIM_VIEW (true angular size). Quick Course keeps
	# the title-screen MARKERS / Real-view toggle.
	if str(route.get("pace_mode", "")) == AstrogatorPanel.PACE_ASTROGATOR:
		_fly.render_mode = NavModes.MODE_SIM_VIEW
	else:
		_fly.render_mode = NavModes.mode()
	_fly.set_active(true)
	_fly.begin_flight(dest_id, route, t0)

func _on_flight_arrived(dest_id: String) -> void:
	_ship_at = dest_id
	var body := SolarData.flyer_body_by_id(dest_id)
	var place := str(body.get("name", dest_id)) if not body.is_empty() else dest_id
	var travel_au: float = float(_last_route.get("travel_au", 0.0))
	if travel_au < 0.05 and not body.is_empty():
		travel_au = absf(float(body.get("a_au", 1.0)) - 1.0)
	var is_star: bool = (not body.is_empty()) and bool(body.get("is_star", false))
	Narrator.speak(OrbitMath.arrival_narration(place, travel_au, is_star))
	_fly.show_arrival_ui()

func _on_learn_more(dest_id: String) -> void:
	_ship_at = dest_id
	# Major asteroids chain their own clip into the belt explainer — the rock
	# first, then what the belt IS (STRATEGY §5.3).
	var body := SolarData.flyer_body_by_id(dest_id)
	if bool(body.get("major_asteroid", false)):
		_video.play_chain([dest_id, "asteroid_belt"])
	else:
		_video.play_body(dest_id)

func _on_chart_new_course(dest_id: String) -> void:
	_ship_at = dest_id
	_show_scroll()

func _on_playground_arrived(dest_id: String) -> void:
	_ship_at = dest_id
	var body := SolarData.flyer_body_by_id(dest_id)
	Narrator.speak("You have arrived at %s!" % str(body.get("name", dest_id)))

func _on_video_closed() -> void:
	if _in_playground:
		_playground.set_active(true)
		_playground.resume_flying()
		return
	if USE_3D_FLYER:
		_fly.set_active(false)
		_show_scroll()
	# 2D strip stays underneath; nothing else to do.

func _set_view(active: Control) -> void:
	var views: Array = [_title, _chooser, _orrery, _scroll, _board]
	for v in views:
		var on: bool = (v == active)
		v.visible = on
		if v.has_method("set_active"):
			v.set_active(on)
	# Chooser overlays are managed separately (not in the exclusive list).
	if active != _course_mode:
		_course_mode.set_active(false)
	if active != _propulsion:
		_propulsion.set_active(false)
	if active != _fly:
		_fly.set_active(false)

func _hide_all_views() -> void:
	for v in [_title, _chooser, _orrery, _scroll, _board]:
		v.visible = false
		if v.has_method("set_active"):
			v.set_active(false)
	_course_mode.set_active(false)
	_propulsion.set_active(false)
	_fly.set_active(false)
	_playground.set_active(false)


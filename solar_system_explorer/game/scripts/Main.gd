extends Node
## Solar System Explorer — flow controller.
##
##   Title (two tiles)
##      ─▶ Spaceship ─▶ Astronaut briefing ─▶ ScrollView ─▶ PlotBoard ─▶ FlyScene
##           ─▶ optional Video ─▶ ScrollView again
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

var _title: TitleView
var _orrery: OrreryView
var _scroll: ScrollView
var _board: PlotBoard
var _fly: FlyScene
var _video: VideoPanel
var _astro: AstronautIntro
var _ship_at: String = "earth"
var _last_route: Dictionary = {}

func _ready() -> void:
	var starfield := Starfield.new()
	add_child(starfield)

	_title = TitleView.new()
	_orrery = OrreryView.new()
	_scroll = ScrollView.new()
	_board = PlotBoard.new()
	_fly = FlyScene.new()
	_video = VideoPanel.new()
	_astro = AstronautIntro.new()
	add_child(_title)
	add_child(_orrery)
	add_child(_scroll)
	add_child(_board)
	add_child(_fly)
	add_child(_video)
	add_child(_astro)

	_title.flight_pressed.connect(_on_flight)
	_title.explainer_pressed.connect(_on_explainer)
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
	_video.closed.connect(_on_video_closed)
	_astro.finished.connect(_on_astro_finished)

	_hide_all_views()
	_set_view(_title)

func _on_flight() -> void:
	_show_scroll()
	_astro.begin()

func _on_explainer() -> void:
	_set_view(_orrery)
	_orrery.begin_tour()

func _show_title() -> void:
	_orrery.stop_tour()
	_fly.set_active(false)
	_set_view(_title)

func _on_astro_finished() -> void:
	pass

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
	_board.set_ship_at(_ship_at)
	_set_view(_board)
	_board.begin_plot(id)

func _on_course_committed(dest_id: String, route: Dictionary, t0: float) -> void:
	_last_route = route
	_board.set_active(false)
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

func _on_video_closed() -> void:
	if USE_3D_FLYER:
		_fly.set_active(false)
		_show_scroll()
	# 2D strip stays underneath; nothing else to do.

func _set_view(active: Control) -> void:
	var views: Array = [_title, _orrery, _scroll, _board]
	for v in views:
		var on: bool = (v == active)
		v.visible = on
		if v.has_method("set_active"):
			v.set_active(on)
	if active != _fly:
		_fly.set_active(false)

func _hide_all_views() -> void:
	for v in [_title, _orrery, _scroll, _board]:
		v.visible = false
		if v.has_method("set_active"):
			v.set_active(false)
	_fly.set_active(false)


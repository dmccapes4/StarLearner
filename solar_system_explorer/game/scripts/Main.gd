extends Node
## Solar System Explorer — preview flow controller.
##
##   Title (START) ─▶ Orrery tour ─▶ Astronaut briefing ─▶ Piloting strip
##                                                           │ fly ship + tap
##                                                           ▼
##                                                       Video / "coming soon"
##
## Bodies + orbits are drawn in code; the astronaut girl and the ship marker are
## the only image assets (res://images/).

const Starfield := preload("res://scripts/Starfield.gd")
const TitleView := preload("res://scripts/TitleView.gd")
const OrreryView := preload("res://scripts/OrreryView.gd")
const ScrollView := preload("res://scripts/ScrollView.gd")
const VideoPanel := preload("res://scripts/VideoPanel.gd")
const AstronautIntro := preload("res://scripts/AstronautIntro.gd")

var _title: TitleView
var _orrery: OrreryView
var _scroll: ScrollView
var _video: VideoPanel
var _astro: AstronautIntro

func _ready() -> void:
	var starfield := Starfield.new()
	add_child(starfield)

	_title = TitleView.new()
	_orrery = OrreryView.new()
	_scroll = ScrollView.new()
	_video = VideoPanel.new()
	_astro = AstronautIntro.new()
	add_child(_title)
	add_child(_orrery)
	add_child(_scroll)
	add_child(_video)
	add_child(_astro)

	_title.start_pressed.connect(_on_start)
	_orrery.tour_finished.connect(_begin_astronaut)
	_orrery.go_home.connect(_show_title)
	_scroll.go_home.connect(_show_title)
	_scroll.body_selected.connect(_on_body_selected)
	_astro.finished.connect(_on_astro_finished)

	_add_preview_badge()
	_show_title()

func _on_start() -> void:
	_set_view(_orrery)
	_orrery.begin_tour()

func _show_title() -> void:
	_orrery.stop_tour()
	_set_view(_title)

## Orrery tour done → activate the piloting strip behind an astronaut briefing
## overlay, which fades away to reveal it (feels like changing to the fly screen).
func _begin_astronaut() -> void:
	_set_view(_scroll)
	_scroll.begin_exploration()
	_astro.begin()

func _on_astro_finished() -> void:
	pass

func _on_body_selected(id: String) -> void:
	_video.play_body(id)

func _set_view(active: Control) -> void:
	for v in [_title, _orrery, _scroll]:
		var on: bool = (v == active)
		v.visible = on
		if v.has_method("set_active"):
			v.set_active(on)

func _add_preview_badge() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	var badge := Label.new()
	badge.text = "PREVIEW"
	badge.add_theme_font_size_override("font_size", 22)
	badge.add_theme_color_override("font_color", Color(0.06, 0.05, 0.02))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1.0, 0.82, 0.28, 0.95)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 6.0
	badge.add_theme_stylebox_override("normal", sb)
	badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	badge.position = Vector2(-140, 16)
	badge.size = Vector2(124, 36)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	layer.add_child(badge)

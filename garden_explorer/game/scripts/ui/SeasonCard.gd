class_name SeasonCard
extends CanvasLayer
## Season-change card: generated season art centered for 5 s with "Year X"
## caption. No tap-to-close; the player is frozen (narration lock + this
## layer swallowing input).

signal card_closed()

const SpeakScript := preload("res://scripts/audio/Speak.gd")
const HOLD_SEC := 5.0

var _open: bool = false
var _hold_left: float = 0.0
var _art: TextureRect
var _season_lbl: Label
var _year_lbl: Label

func _ready() -> void:
	add_to_group("season_card")
	layer = 44
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false
	set_process(false)

func is_open() -> bool:
	return _open

func show_season(season_id: String, label: String, year: int) -> void:
	var path := "res://assets/seasons/season_%s.jpg" % season_id
	_art.texture = load(path) if ResourceLoader.exists(path) else null
	_season_lbl.text = label
	_year_lbl.text = "Year %d" % year
	_open = true
	visible = true
	## Narration includes the year; hold starts alongside (5 s total feel).
	SpeakScript.line("It's %s, year %d!" % [label, year])
	_hold_left = HOLD_SEC
	set_process(true)

func _process(delta: float) -> void:
	if not _open:
		return
	_hold_left -= delta
	if _hold_left <= 0.0:
		_open = false
		visible = false
		set_process(false)
		card_closed.emit()

func _build() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(root)

	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.06, 0.05, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(dim)

	var panel := VBoxContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_theme_constant_override("separation", 10)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)

	_season_lbl = Label.new()
	_season_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_season_lbl.add_theme_font_size_override("font_size", 40)
	_season_lbl.add_theme_color_override("font_color", Color(1, 0.95, 0.75, 1))
	panel.add_child(_season_lbl)

	_art = TextureRect.new()
	_art.custom_minimum_size = Vector2(420, 420)
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	panel.add_child(_art)

	_year_lbl = Label.new()
	_year_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_year_lbl.add_theme_font_size_override("font_size", 30)
	_year_lbl.add_theme_color_override("font_color", Color(1, 0.88, 0.4, 1))
	panel.add_child(_year_lbl)

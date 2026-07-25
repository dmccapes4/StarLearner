class_name SeasonHUD
extends CanvasLayer
## Top-center season label + soft sky cue text.

var _label: Label
var _toast: Label
var _toast_left: float = 0.0

func _ready() -> void:
	layer = 22
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_label = Label.new()
	_label.position = Vector2(520, 12)
	_label.add_theme_font_size_override("font_size", 22)
	_label.add_theme_color_override("font_color", Color(1, 0.98, 0.9, 0.95))
	_label.text = "Season: Spring"
	root.add_child(_label)

	_toast = Label.new()
	_toast.position = Vector2(420, 48)
	_toast.add_theme_font_size_override("font_size", 20)
	_toast.add_theme_color_override("font_color", Color(1, 0.95, 0.75, 1))
	_toast.visible = false
	root.add_child(_toast)

func set_season(season_id: String, label: String) -> void:
	_label.text = "Season: %s" % label
	_label.modulate = _tint(season_id)

func announce(line: String) -> void:
	_toast.text = line
	_toast.visible = true
	_toast_left = 3.5

func _process(delta: float) -> void:
	if _toast_left <= 0.0:
		return
	_toast_left -= delta
	if _toast_left <= 0.0:
		_toast.visible = false

func _tint(season_id: String) -> Color:
	match season_id:
		"summer":
			return Color(1.0, 0.95, 0.7, 1)
		"fall":
			return Color(1.0, 0.82, 0.55, 1)
		"winter":
			return Color(0.75, 0.88, 1.0, 1)
		_:
			return Color(0.85, 1.0, 0.8, 1)

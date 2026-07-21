class_name VideoPanel
extends CanvasLayer
## Full-screen body view. Plays res://videos/<id>.ogv if present; otherwise shows
## a friendly "video coming soon" card with facts and spoken narration. One
## decoder at a time; big Back button for kid thumbs.

signal closed()

var _dim: ColorRect
var _player: VideoStreamPlayer
var _card: Control
var _card_title: Label
var _card_facts: Label
var _back: Button
var _open: bool = false
var _current_id: String = ""

func _ready() -> void:
	layer = 20
	visible = false

	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.82)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)

	_player = VideoStreamPlayer.new()
	_player.set_anchors_preset(Control.PRESET_FULL_RECT)
	_player.expand = true
	_player.visible = false
	_player.finished.connect(_close)
	add_child(_player)

	_card = _build_card()
	add_child(_card)

	_back = _build_back()
	add_child(_back)

func is_open() -> bool:
	return _open

func play_body(id: String) -> void:
	if _open:
		return
	var body := _find(id)
	if body.is_empty():
		return
	_open = true
	_current_id = id
	visible = true

	var path := "res://videos/%s.ogv" % id
	var stream: VideoStream = null
	if ResourceLoader.exists(path):
		stream = ResourceLoader.load(path, "VideoStream") as VideoStream

	if stream != null:
		_card.visible = false
		_player.visible = true
		_player.stream = stream
		_player.play()
	else:
		_show_card(body)

func current_id() -> String:
	return _current_id

func _show_card(body: Dictionary) -> void:
	_player.visible = false
	_card.visible = true
	_card_title.text = body["name"]
	var lines: Array = []
	for f in body.get("facts", []):
		lines.append("\u2022  " + str(f))
	lines.append("")
	lines.append("(Video coming soon)")
	_card_facts.text = "\n".join(lines)
	var spoken: String = str(body.get("blurb", body["name"]))
	Narrator.speak(spoken + " A video about it is coming soon.")

func _close() -> void:
	if not _open:
		return
	_open = false
	Narrator.stop()
	if _player.is_playing():
		_player.stop()
	_player.stream = null
	_player.visible = false
	_card.visible = false
	visible = false
	var done_id := _current_id
	closed.emit()
	_current_id = done_id  # keep last id for the flyer to park at

func _find(id: String) -> Dictionary:
	for b in SolarData.bodies():
		if b["id"] == id:
			return b
	return {}

func _build_card() -> Control:
	var wrap := Control.new()
	wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.position = Vector2(-340, -150)
	box.custom_minimum_size = Vector2(680, 300)
	box.add_theme_constant_override("separation", 16)
	wrap.add_child(box)

	_card_title = Label.new()
	_card_title.add_theme_font_size_override("font_size", 46)
	_card_title.add_theme_color_override("font_color", Color(1, 1, 1))
	_card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_card_title)

	_card_facts = Label.new()
	_card_facts.add_theme_font_size_override("font_size", 26)
	_card_facts.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	_card_facts.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_card_facts)
	return wrap

func _build_back() -> Button:
	var b := Button.new()
	b.text = "\u25C0"
	b.custom_minimum_size = Vector2(112, 88)
	b.size = Vector2(112, 88)
	b.position = Vector2(28, 28)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 48)
	b.add_theme_color_override("font_color", Color(0.15, 0.1, 0.05))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.95, 0.86, 0.45, 0.98)
	sb.set_corner_radius_all(18)
	sb.set_border_width_all(4)
	sb.border_color = Color(1, 1, 1, 0.9)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("focus", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.pressed.connect(_close)
	return b

class_name LetterSlots
extends Control
## Grey underlines for the target word; filled slots show the chosen glyph.
## Current slot may pulse faintly.

var _letters: PackedStringArray = PackedStringArray()
var _filled: int = 0
var _labels: Array = []  # Label
var _underlines: Array = []  # ColorRect
var _pulse: float = 0.0

func setup(letters: PackedStringArray) -> void:
	_letters = letters
	_filled = 0
	_rebuild()

func set_filled(count: int) -> void:
	_filled = clampi(count, 0, _letters.size())
	_refresh()

func _ready() -> void:
	custom_minimum_size = Vector2(600, 70)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	if _filled >= _letters.size() or _labels.is_empty():
		return
	_pulse += delta * 3.0
	var i := _filled
	if i >= 0 and i < _underlines.size():
		var u: ColorRect = _underlines[i]
		var a := 0.35 + 0.25 * sin(_pulse)
		u.color = Color(LangTheme.GOLD.r, LangTheme.GOLD.g, LangTheme.GOLD.b, a)

func _rebuild() -> void:
	for c in get_children():
		c.queue_free()
	_labels.clear()
	_underlines.clear()
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	for i in _letters.size():
		var cell := VBoxContainer.new()
		cell.custom_minimum_size = Vector2(44, 64)
		cell.add_theme_constant_override("separation", 4)
		cell.alignment = BoxContainer.ALIGNMENT_END
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var lbl := Label.new()
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 36)
		lbl.add_theme_color_override("font_color", LangTheme.TEXT)
		lbl.custom_minimum_size = Vector2(44, 40)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(lbl)
		var line := ColorRect.new()
		line.custom_minimum_size = Vector2(44, 4)
		line.color = Color(LangTheme.GREY.r, LangTheme.GREY.g, LangTheme.GREY.b, 0.7)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(line)
		row.add_child(cell)
		_labels.append(lbl)
		_underlines.append(line)
	_refresh()

func _refresh() -> void:
	for i in _labels.size():
		var lbl: Label = _labels[i]
		var line: ColorRect = _underlines[i]
		if i < _filled:
			lbl.text = str(_letters[i])
			lbl.add_theme_color_override("font_color", LangTheme.GREEN)
			line.color = LangTheme.GREEN
		else:
			lbl.text = ""
			lbl.add_theme_color_override("font_color", LangTheme.TEXT)
			line.color = Color(LangTheme.GREY.r, LangTheme.GREY.g, LangTheme.GREY.b, 0.7)

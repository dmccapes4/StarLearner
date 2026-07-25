class_name AlphabetBoard
extends Control
const ChromeIcons := preload("res://scripts/ChromeIcons.gd")
## Ordered A–Z (ES: +Ñ) letter tiles + A|a case chrome. Not QWERTY.

signal letter_pressed(glyph: String)
signal case_changed(upper: bool)
signal clear_hint_pressed()

const TILE := 64.0
const COLS := 9

var lang: String = "en"
var upper: bool = true
var show_clear_hint: bool = false
## normalize_key → "wrong" | "reveal" | "" 
var tile_states: Dictionary = {}
var reveal_key: String = ""
var locked: bool = false

var _built := false
var _grid: GridContainer
var _case_upper: Button
var _case_lower: Button
var _clear_btn: Button
var _tiles: Dictionary = {}  # key -> Button

func setup(p_lang: String, p_upper: bool = true, p_show_clear: bool = false) -> void:
	lang = p_lang
	upper = p_upper
	show_clear_hint = p_show_clear
	_build()
	_rebuild_tiles()
	_refresh_case_chrome()

func set_case(p_upper: bool) -> void:
	if upper == p_upper:
		return
	upper = p_upper
	_rebuild_tiles()
	_refresh_case_chrome()
	case_changed.emit(upper)

func reset_attempt(expected_upper: bool, auto_case: bool = true) -> void:
	tile_states.clear()
	reveal_key = ""
	locked = false
	if auto_case:
		upper = expected_upper
	_rebuild_tiles()
	_refresh_case_chrome()

func mark_wrong(key: String) -> void:
	tile_states[key] = "wrong"
	_style_tile(key)

func apply_reveal(correct_key: String) -> void:
	reveal_key = correct_key
	for k in _tiles.keys():
		if str(k) == correct_key:
			tile_states[k] = "reveal"
		elif str(tile_states.get(k, "")) != "wrong":
			tile_states[k] = "dim"
		_style_tile(str(k))

func _build() -> void:
	if _built:
		return
	_built = true
	custom_minimum_size = Vector2(680, 280)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var case_row := HBoxContainer.new()
	case_row.alignment = BoxContainer.ALIGNMENT_CENTER
	case_row.add_theme_constant_override("separation", 12)
	case_row.position = Vector2(0, 0)
	case_row.size = Vector2(680, 48)
	add_child(case_row)

	_case_upper = Button.new()
	_case_upper.text = "A"
	_case_upper.custom_minimum_size = Vector2(64, 44)
	_case_upper.focus_mode = Control.FOCUS_NONE
	_case_upper.add_theme_font_size_override("font_size", 26)
	_case_upper.pressed.connect(func() -> void: set_case(true))
	case_row.add_child(_case_upper)

	var sep := Label.new()
	sep.text = "|"
	sep.add_theme_font_size_override("font_size", 26)
	sep.add_theme_color_override("font_color", LangTheme.TEXT_DIM)
	case_row.add_child(sep)

	_case_lower = Button.new()
	_case_lower.text = "a"
	_case_lower.custom_minimum_size = Vector2(64, 44)
	_case_lower.focus_mode = Control.FOCUS_NONE
	_case_lower.add_theme_font_size_override("font_size", 26)
	_case_lower.pressed.connect(func() -> void: set_case(false))
	case_row.add_child(_case_lower)

	_clear_btn = Button.new()
	_clear_btn.tooltip_text = "Hear letter"
	_clear_btn.custom_minimum_size = Vector2(72, 44)
	_clear_btn.focus_mode = Control.FOCUS_NONE
	LangTheme.style_secondary(_clear_btn)
	ChromeIcons.apply_button(_clear_btn, "hear", 32)
	_clear_btn.pressed.connect(func() -> void: clear_hint_pressed.emit())
	case_row.add_child(_clear_btn)

	_grid = GridContainer.new()
	_grid.columns = COLS
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	_grid.position = Vector2(28, 54)
	_grid.size = Vector2(624, 206)
	add_child(_grid)

func _rebuild_tiles() -> void:
	if _grid == null:
		return
	for c in _grid.get_children():
		c.queue_free()
	_tiles.clear()
	_clear_btn.visible = show_clear_hint
	var alphabet: Array = LangLetters.alphabet_for(lang)
	for ch in alphabet:
		var key := LangLetters.normalize_key(str(ch))
		var glyph := _glyph_for(key)
		var b := Button.new()
		b.text = glyph
		b.custom_minimum_size = Vector2(TILE, TILE)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 28)
		b.pressed.connect(func() -> void: _on_tile(key, glyph, b))
		_grid.add_child(b)
		_tiles[key] = b
		_style_tile(key)

func _glyph_for(key: String) -> String:
	if key == "Ñ":
		return "Ñ" if upper else "ñ"
	return key if upper else key.to_lower()

func _on_tile(key: String, glyph: String, _btn: Button) -> void:
	if locked:
		return
	var st := str(tile_states.get(key, ""))
	if st == "wrong" or st == "dim":
		return
	letter_pressed.emit(glyph)

func _style_tile(key: String) -> void:
	if not _tiles.has(key):
		return
	var b: Button = _tiles[key]
	var st := str(tile_states.get(key, ""))
	match st:
		"wrong":
			b.disabled = true
			b.add_theme_color_override("font_color", Color(0.55, 0.55, 0.58))
			b.add_theme_color_override("font_disabled_color", Color(0.55, 0.55, 0.58))
			var sb := LangTheme.rounded_box(LangTheme.RED.darkened(0.35), 14)
			sb.set_border_width_all(2)
			sb.border_color = LangTheme.RED
			for s in ["normal", "hover", "focus", "pressed", "disabled"]:
				b.add_theme_stylebox_override(s, sb)
		"reveal":
			b.disabled = false
			b.add_theme_color_override("font_color", Color(0.06, 0.06, 0.12))
			var sb2 := LangTheme.rounded_box(LangTheme.GOLD, 14)
			sb2.set_border_width_all(4)
			sb2.border_color = LangTheme.GOLD.lightened(0.2)
			sb2.shadow_color = Color(LangTheme.GOLD, 0.5)
			sb2.shadow_size = 8
			for s in ["normal", "hover", "focus", "pressed"]:
				b.add_theme_stylebox_override(s, sb2)
			b.add_theme_font_size_override("font_size", 34)
		"dim":
			b.disabled = true
			b.add_theme_color_override("font_disabled_color", Color(0.45, 0.48, 0.55))
			var sb3 := LangTheme.rounded_box(Color(0.20, 0.22, 0.30), 14)
			for s in ["normal", "hover", "focus", "pressed", "disabled"]:
				b.add_theme_stylebox_override(s, sb3)
		_:
			b.disabled = false
			b.add_theme_color_override("font_color", LangTheme.TEXT)
			b.add_theme_font_size_override("font_size", 28)
			LangTheme.style_secondary(b)

func _refresh_case_chrome() -> void:
	if upper:
		LangTheme.style_primary(_case_upper)
		LangTheme.style_secondary(_case_lower)
	else:
		LangTheme.style_primary(_case_lower)
		LangTheme.style_secondary(_case_upper)
	if show_clear_hint:
		LangTheme.style_primary(_clear_btn)

class_name HamburgerPanel
extends Control
const ChromeIcons := preload("res://scripts/ChromeIcons.gd")
## Icon-only settings / tutorials sheet for pre-readers.
## Every tile speaks its purpose; gold border marks the active language / letter input.

signal closed()
signal action(id: int)

const TILE := 88.0

var _built := false
var _btns: Dictionary = {}  # id -> Button

func open_panel() -> void:
	_build()
	_refresh()
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_ui_to_front()

func close_panel() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	closed.emit()

func _ui_to_front() -> void:
	var p := get_parent()
	if p != null:
		p.move_child(self, -1)

func _build() -> void:
	if _built:
		return
	_built = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.04, 0.09, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed:
			close_panel()
	)
	add_child(dim)

	var panel := Panel.new()
	panel.position = Vector2(160, 40)
	panel.size = Vector2(960, 520)
	var sb := LangTheme.rounded_box(LangTheme.PANEL, 28)
	sb.set_border_width_all(4)
	sb.border_color = LangTheme.GOLD
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)

	var close_btn := Button.new()
	close_btn.custom_minimum_size = Vector2(64, 64)
	close_btn.size = Vector2(64, 64)
	close_btn.position = Vector2(1030, 52)
	close_btn.focus_mode = Control.FOCUS_NONE
	LangTheme.style_secondary(close_btn)
	ChromeIcons.apply_button(close_btn, "close", 40)
	close_btn.pressed.connect(close_panel)
	add_child(close_btn)

	# Row 1 — tutorials (match Main menu ids 0..5)
	var tut := [
		{"id": 0, "icon": "read"},
		{"id": 1, "icon": "sentences"},
		{"id": 2, "icon": "books"},
		{"id": 3, "icon": "write"},
		{"id": 4, "icon": "alphabet"},
		{"id": 5, "icon": "sketch"},
	]
	_add_row(tut, Vector2(200, 70))

	# Row 2 — language (10, 11) + letter input (20, 21)
	var mid := [
		{"id": 10, "icon": "english"},
		{"id": 11, "icon": "spanish"},
		{"id": 20, "icon": "alphabet"},
		{"id": 21, "icon": "sketch"},
	]
	_add_row(mid, Vector2(340, 220))

	# Row 3 — about
	var about := [
		{"id": 25, "icon": "spell_demo"},
		{"id": 30, "icon": "credits"},
	]
	_add_row(about, Vector2(460, 370))

func _add_row(items: Array, origin: Vector2) -> void:
	var x := origin.x
	for item in items:
		var b := Button.new()
		b.custom_minimum_size = Vector2(TILE, TILE)
		b.size = Vector2(TILE, TILE)
		b.position = Vector2(x, origin.y)
		b.focus_mode = Control.FOCUS_NONE
		LangTheme.style_secondary(b)
		ChromeIcons.apply_button(b, str(item["icon"]), 64)
		var id: int = int(item["id"])
		b.pressed.connect(func() -> void: _on_tap(id))
		add_child(b)
		_btns[id] = b
		x += TILE + 24.0

func _on_tap(id: int) -> void:
	action.emit(id)
	# Keep panel open for language / letter-input toggles; close for navigations.
	if id in [10, 11, 20, 21, 30]:
		_refresh()
	else:
		close_panel()

func _refresh() -> void:
	var lang := Save.get_lang()
	var input := Save.get_letter_input()
	for id in _btns.keys():
		var b: Button = _btns[id]
		var active := false
		match int(id):
			10:
				active = lang == "en"
			11:
				active = lang == "es"
			20:
				active = input == "alphabet"
			21:
				active = input == "sketch"
		if active:
			LangTheme.style_primary(b)
			ChromeIcons.apply_button(b, _icon_for(int(id)), 64)
		else:
			LangTheme.style_secondary(b)
			ChromeIcons.apply_button(b, _icon_for(int(id)), 64)

func _icon_for(id: int) -> String:
	match id:
		0:
			return "read"
		1:
			return "sentences"
		2:
			return "books"
		3:
			return "write"
		4, 20:
			return "alphabet"
		5, 21:
			return "sketch"
		10:
			return "english"
		11:
			return "spanish"
		25:
			return "spell_demo"
		30:
			return "credits"
		_:
			return "menu"

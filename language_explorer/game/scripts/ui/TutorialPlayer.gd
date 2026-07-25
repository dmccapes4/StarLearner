class_name TutorialPlayer
extends Control
const ChromeIcons := preload("res://scripts/ChromeIcons.gd")
## Narrated bilingual tutorial overlay with a gold callout.

signal closed(tutorial_id: String)

var _built := false
var _tutorial_id: String = ""
var _steps: Array = []
var _index: int = 0
var _gen: int = 0

var _title: Label
var _target: Label
var _body: Label
var _progress: Label
var _next: Button

func start(tutorial_id: String, lang: String = "en") -> void:
	_build()
	var row := LangData.tutorial_by_id(tutorial_id)
	if row.is_empty():
		return
	_tutorial_id = tutorial_id
	var by_lang: Dictionary = row.get("steps", {})
	_steps = by_lang.get(lang, by_lang.get("en", []))
	if _steps.is_empty():
		return
	_index = 0
	_title.text = str(row.get("title_es" if lang == "es" else "title", "Tutorial"))
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_show_step()

func stop(mark_seen: bool = false) -> void:
	_gen += 1
	Narrator.stop()
	if mark_seen and not _tutorial_id.is_empty():
		Save.mark_seen(_tutorial_id)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _build() -> void:
	if _built:
		return
	_built = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.04, 0.09, 0.90)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var panel := Panel.new()
	panel.position = Vector2(210, 80)
	panel.size = Vector2(860, 440)
	var sb := LangTheme.rounded_box(LangTheme.PANEL, 28)
	sb.set_border_width_all(5)
	sb.border_color = LangTheme.GOLD
	sb.shadow_color = Color(LangTheme.GOLD, 0.35)
	sb.shadow_size = 12
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	_title = Label.new()
	_title.position = Vector2(255, 112)
	_title.size = Vector2(770, 52)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 34)
	_title.add_theme_color_override("font_color", LangTheme.GOLD)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title)

	_target = Label.new()
	_target.position = Vector2(390, 185)
	_target.size = Vector2(500, 64)
	_target.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_target.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_target.add_theme_font_size_override("font_size", 26)
	_target.add_theme_color_override("font_color", Color(0.06, 0.06, 0.12))
	_target.add_theme_stylebox_override("normal", LangTheme.rounded_box(LangTheme.GOLD, 18))
	_target.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_target)

	_body = Label.new()
	_body.position = Vector2(285, 275)
	_body.size = Vector2(710, 100)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_body.add_theme_font_size_override("font_size", 25)
	_body.add_theme_color_override("font_color", LangTheme.TEXT)
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_body)

	_progress = Label.new()
	_progress.position = Vector2(290, 455)
	_progress.size = Vector2(180, 40)
	_progress.add_theme_font_size_override("font_size", 18)
	_progress.add_theme_color_override("font_color", LangTheme.TEXT_DIM)
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_progress)

	var close_btn := Button.new()
	close_btn.position = Vector2(520, 430)
	close_btn.size = Vector2(100, 64)
	close_btn.focus_mode = Control.FOCUS_NONE
	LangTheme.style_secondary(close_btn)
	ChromeIcons.apply_button(close_btn, "close", 40)
	close_btn.pressed.connect(_close)
	add_child(close_btn)

	_next = Button.new()
	_next.position = Vector2(650, 430)
	_next.size = Vector2(120, 64)
	_next.focus_mode = Control.FOCUS_NONE
	LangTheme.style_primary(_next)
	ChromeIcons.apply_button(_next, "next", 48)
	_next.pressed.connect(_advance)
	add_child(_next)

func _show_step() -> void:
	if _index < 0 or _index >= _steps.size():
		_close()
		return
	_gen += 1
	var step: Dictionary = _steps[_index]
	_target.text = str(step.get("target", "Language Explorer"))
	_body.text = str(step.get("say", ""))
	_progress.text = "%d / %d" % [_index + 1, _steps.size()]
	if _index == _steps.size() - 1:
		LangTheme.style_primary(_next)
		ChromeIcons.apply_button(_next, "done", 48)
	else:
		LangTheme.style_primary(_next)
		ChromeIcons.apply_button(_next, "next", 48)
	Narrator.speak(_body.text)

func _advance() -> void:
	if Narrator.blocks_input():
		return
	if _index >= _steps.size() - 1:
		_close()
		return
	_index += 1
	_show_step()

func _close() -> void:
	if Narrator.blocks_input():
		return
	var id := _tutorial_id
	stop(true)
	closed.emit(id)

static func vo_lines() -> Array:
	var out: Array = []
	for row in LangData.tutorials():
		var by_lang: Dictionary = row.get("steps", {})
		for lang in ["en", "es"]:
			for step in by_lang.get(lang, []):
				out.append(str(step.get("say", "")))
	return out

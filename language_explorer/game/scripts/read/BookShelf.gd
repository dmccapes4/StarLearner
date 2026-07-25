class_name BookShelf
extends Control
const ChromeIcons := preload("res://scripts/ChromeIcons.gd")
## Cover grid. First tap arms (title + description + bookmark + “tap again”);
## second tap within 5 s opens the book.

signal open_book(book_id: String)
signal finished()

const ARM_WINDOW := 12.0

var _built := false
var _row: HBoxContainer
var _arm: DoubleTapArm
var _tiles: Array = []  # {id, btn}
var _busy: bool = false
var _gen: int = 0

func start() -> void:
	_build()
	_arm = DoubleTapArm.new(ARM_WINDOW)
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_rebuild_tiles()
	Narrator.speak(LangVo.line("books_blurb", Save.get_lang()))

func stop() -> void:
	_gen += 1
	_busy = false
	Narrator.stop()
	if _arm != null:
		_arm.clear()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _build() -> void:
	if _built:
		return
	_built = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var header := TextureRect.new()
	header.texture = ChromeIcons.texture("books")
	header.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	header.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.position = Vector2(576, 24)
	header.size = Vector2(128, 80)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(header)

	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", 48)
	_row.position = Vector2(40, 130)
	_row.size = Vector2(1200, 400)
	add_child(_row)

func _rebuild_tiles() -> void:
	for c in _row.get_children():
		c.queue_free()
	_tiles.clear()
	var books: Array = LangData.books_shipped("")  # both languages on one shelf
	if books.is_empty():
		return
	for book in books:
		_row.add_child(_make_tile(book))

func _make_tile(book: Dictionary) -> Control:
	var wrap := VBoxContainer.new()
	wrap.custom_minimum_size = Vector2(200, 320)
	wrap.add_theme_constant_override("separation", 10)
	wrap.alignment = BoxContainer.ALIGNMENT_CENTER

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(160, 220)
	btn.size = Vector2(160, 220)
	btn.focus_mode = Control.FOCUS_NONE
	btn.clip_contents = true
	var sb := LangTheme.rounded_box(LangTheme.PANEL, 16)
	sb.set_border_width_all(3)
	sb.border_color = Color(1, 1, 1, 0.25)
	for state in ["normal", "hover", "focus", "pressed"]:
		btn.add_theme_stylebox_override(state, sb)
	btn.icon = CoverArt.texture_for(book)
	btn.expand_icon = true
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var bid := str(book.get("id", ""))
	btn.pressed.connect(func() -> void: _on_cover(bid))
	wrap.add_child(btn)

	_tiles.append({"id": bid, "btn": btn})
	return wrap

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

func _on_cover(book_id: String) -> void:
	if book_id.is_empty():
		return
	_arm.poll(_now())
	var result := _arm.press(book_id, _now())
	if result == DoubleTapArm.RESULT_TRIGGER:
		_gen += 1  # cancel arm VO
		_busy = false
		Narrator.stop()
		_highlight(book_id, false)
		open_book.emit(book_id)
		return
	if _busy:
		return
	_highlight(book_id, true)
	_speak_arm(book_id)

func _highlight(book_id: String, on: bool) -> void:
	for t in _tiles:
		var btn: Button = t["btn"]
		var sb := LangTheme.rounded_box(LangTheme.PANEL, 16)
		sb.set_border_width_all(4 if (on and str(t["id"]) == book_id) else 3)
		sb.border_color = LangTheme.GOLD if (on and str(t["id"]) == book_id) else Color(1, 1, 1, 0.25)
		if on and str(t["id"]) == book_id:
			sb.shadow_color = Color(LangTheme.GOLD, 0.4)
			sb.shadow_size = 10
		for state in ["normal", "hover", "focus", "pressed"]:
			btn.add_theme_stylebox_override(state, sb)

func _speak_arm(book_id: String) -> void:
	_gen += 1
	var gen := _gen
	_busy = true
	var book := LangData.book_by_id(book_id)
	var lang := str(book.get("lang", Save.get_lang()))
	var parts: Array = []
	parts.append(str(book.get("title", "")))
	parts.append(str(book.get("description", "")))
	var bm := Save.get_bookmark(book_id)
	if bm > 0:
		parts.append(LangVo.page_saved_line(bm + 1, lang))
	else:
		parts.append(LangVo.line("start_beginning", lang))
	parts.append(LangVo.line("tap_again", lang))
	for p in parts:
		if gen != _gen:
			return
		var d := Narrator.speak(str(p))
		if not await _wait(gen, maxf(1.0, d)):
			return
	_busy = false
	# Refresh arm window after the VO so the second tap is still available.
	if _arm != null:
		_arm.rearm(book_id, _now())

func _wait(gen: int, secs: float) -> bool:
	await get_tree().create_timer(secs).timeout
	return gen == _gen and is_inside_tree() and visible

static func vo_lines() -> Array:
	var out: Array = []
	out.append(LangVo.line("books_blurb", "en"))
	out.append(LangVo.line("books_blurb", "es"))
	out.append(LangVo.line("tap_again", "en"))
	out.append(LangVo.line("tap_again", "es"))
	out.append(LangVo.line("start_beginning", "en"))
	out.append(LangVo.line("start_beginning", "es"))
	for n in range(1, 9):
		out.append(LangVo.page_saved_line(n, "en"))
		out.append(LangVo.page_saved_line(n, "es"))
	for book in LangData.books_shipped(""):
		out.append(str(book.get("title", "")))
		out.append(str(book.get("description", "")))
	return out

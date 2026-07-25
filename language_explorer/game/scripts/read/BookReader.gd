class_name BookReader
extends Control
## Page view: tap a word to spell gold/bold; Clear = read-all slowly or next page.
## Bookmark is saved on every page advance and on stop/back.

signal finished()
signal request_back()

const WordLabelS := preload("res://scripts/WordLabel.gd")
const ClearButtonS := preload("res://scripts/ClearButton.gd")

var _built := false
var _book_id: String = ""
var _meta: Dictionary = {}
var _page_index: int = 0
var _lang: String = "en"
var _busy: bool = false
var _gen: int = 0

var _title: Label
var _page_lbl: Label
var _flow: HFlowContainer
var _words: Array = []  # WordLabel
var _clear_read: ClearButton
var _clear_next: ClearButton
var _hint: Label

func start(book_id: String) -> void:
	_build()
	_book_id = book_id
	_meta = LangData.book_by_id(book_id)
	if _meta.is_empty():
		_meta = {"id": book_id, "title": book_id, "pages": [], "lang": Save.get_lang()}
	_lang = str(_meta.get("lang", Save.get_lang()))
	_page_index = Save.get_bookmark(book_id)
	var pages: Array = _meta.get("pages", [])
	if pages.is_empty():
		_page_index = 0
	else:
		_page_index = clampi(_page_index, 0, pages.size() - 1)
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_title.text = str(_meta.get("title", book_id))
	Save.record_activity_started("book_" + book_id)
	_show_page()

func stop() -> void:
	_gen += 1
	_busy = false
	Narrator.stop()
	if not _book_id.is_empty():
		Save.set_bookmark(_book_id, _page_index)
	if _built:
		_clear_words()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _build() -> void:
	if _built:
		return
	_built = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 28)
	_title.add_theme_color_override("font_color", LangTheme.TEXT)
	_title.position = Vector2(180, 16)
	_title.size = Vector2(920, 40)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title)

	_page_lbl = Label.new()
	_page_lbl.add_theme_font_size_override("font_size", 18)
	_page_lbl.add_theme_color_override("font_color", LangTheme.TEXT_DIM)
	_page_lbl.position = Vector2(180, 52)
	_page_lbl.size = Vector2(920, 28)
	_page_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_page_lbl)

	var panel := Panel.new()
	panel.position = Vector2(80, 90)
	panel.size = Vector2(1120, 360)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := LangTheme.rounded_box(LangTheme.PANEL, 20)
	sb.set_border_width_all(2)
	sb.border_color = Color(1, 1, 1, 0.18)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	_flow = HFlowContainer.new()
	_flow.position = Vector2(100, 110)
	_flow.size = Vector2(1080, 320)
	_flow.add_theme_constant_override("h_separation", 14)
	_flow.add_theme_constant_override("v_separation", 18)
	_flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flow)

	_hint = Label.new()
	_hint.visible = false
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)

	_clear_read = ClearButtonS.new()
	_clear_read.position = Vector2(420, 480)
	_clear_read.size = Vector2(120, 72)
	_clear_read.context_pressed.connect(_on_clear)
	add_child(_clear_read)

	_clear_next = ClearButtonS.new()
	_clear_next.position = Vector2(740, 480)
	_clear_next.size = Vector2(120, 72)
	_clear_next.context_pressed.connect(_on_clear)
	add_child(_clear_next)

func _clear_words() -> void:
	for w in _words:
		if is_instance_valid(w):
			w.queue_free()
	_words.clear()
	for c in _flow.get_children():
		c.queue_free()

func _show_page() -> void:
	_gen += 1
	_busy = false
	Narrator.stop()
	_clear_words()
	var pages: Array = _meta.get("pages", [])
	_clear_read.set_context(ClearButton.Context.READ_ALL, _lang)
	_clear_next.set_context(ClearButton.Context.NEXT_PAGE, _lang)
	_clear_read.visible = true
	_clear_next.visible = true

	if pages.is_empty():
		_page_lbl.text = LangVo.line("empty_page", _lang)
		_hint.text = LangVo.line("empty_page", _lang)
		Narrator.speak(LangVo.line("empty_page", _lang))
		return

	_page_index = clampi(_page_index, 0, pages.size() - 1)
	Save.set_bookmark(_book_id, _page_index)
	_page_lbl.text = "Page %d of %d" % [_page_index + 1, pages.size()]

	var page := LangData.load_page(str(pages[_page_index]))
	var tokens: Array = page.get("tokens", [])
	if tokens.is_empty():
		var text := str(page.get("text", ""))
		if text.is_empty():
			_hint.text = LangVo.line("empty_page", _lang)
			Narrator.speak(LangVo.line("empty_page", _lang))
			return
		tokens = text.split(" ", false)

	for tok in tokens:
		var wl: WordLabel = WordLabelS.new()
		wl.custom_minimum_size = Vector2(maxi(48, str(tok).length() * 18), 48)
		wl.setup(str(tok), 32)
		wl.mouse_filter = Control.MOUSE_FILTER_STOP
		var captured := wl
		wl.gui_input.connect(func(ev: InputEvent) -> void: _on_word_input(captured, ev))
		_flow.add_child(wl)
		_words.append(wl)

func _on_word_input(wl: WordLabel, ev: InputEvent) -> void:
	if _busy or wl == null:
		return
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if not (mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT):
			return
	elif ev is InputEventScreenTouch:
		if not (ev as InputEventScreenTouch).pressed:
			return
	else:
		return
	_spell_word(wl)

func _spell_word(wl: WordLabel) -> void:
	_gen += 1
	var gen := _gen
	_busy = true
	await wl.spell(_lang, WordLabel.State.NORMAL)
	if gen != _gen:
		return
	_busy = false

func _on_clear(ctx: int) -> void:
	if _busy:
		return
	match ctx:
		ClearButton.Context.READ_ALL:
			_read_all_slowly()
		ClearButton.Context.NEXT_PAGE:
			_next_page()

func _read_all_slowly() -> void:
	_gen += 1
	var gen := _gen
	_busy = true
	var d0 := Narrator.speak(LangVo.line("read_all", _lang))
	if not await _wait(gen, maxf(1.0, d0)):
		return
	if _words.is_empty():
		_busy = false
		return
	for wl in _words:
		if gen != _gen:
			return
		var label: WordLabel = wl
		label.apply_state(WordLabel.State.SPELLING_GOLD)
		var d := Narrator.speak(label.get_word())
		if not await _wait(gen, maxf(0.85, d - 0.05)):
			return
		label.apply_state(WordLabel.State.NORMAL)
	_busy = false

func _next_page() -> void:
	var pages: Array = _meta.get("pages", [])
	if pages.is_empty():
		return
	if _page_index >= pages.size() - 1:
		_gen += 1
		var gen := _gen
		_busy = true
		var d := Narrator.speak(LangVo.line("the_end", _lang))
		await _wait(gen, maxf(1.0, d))
		_busy = false
		Save.record_activity_finished("book_" + _book_id)
		return
	_gen += 1
	var gen2 := _gen
	_busy = true
	var d2 := Narrator.speak(LangVo.line("next_page", _lang))
	if not await _wait(gen2, maxf(0.8, d2)):
		return
	_busy = false
	_page_index += 1
	Save.set_bookmark(_book_id, _page_index)
	_show_page()

func _wait(gen: int, secs: float) -> bool:
	await get_tree().create_timer(secs).timeout
	return gen == _gen and is_inside_tree() and visible

static func vo_lines() -> Array:
	var out: Array = []
	out.append(LangVo.line("empty_page", "en"))
	out.append(LangVo.line("empty_page", "es"))
	out.append(LangVo.line("the_end", "en"))
	out.append(LangVo.line("the_end", "es"))
	out.append(LangVo.line("read_all", "en"))
	out.append(LangVo.line("read_all", "es"))
	out.append(LangVo.line("next_page", "en"))
	out.append(LangVo.line("next_page", "es"))
	for book in LangData.books_shipped(""):
		var lang := str(book.get("lang", "en"))
		for path in book.get("pages", []):
			var page := LangData.load_page(str(path))
			var text := str(page.get("text", ""))
			if not text.is_empty():
				out.append(text)
			for tok in page.get("tokens", []):
				out.append(str(tok))
				for ch in LangLetters.spell_letters(str(tok)):
					out.append(LangLetters.letter_name(ch, lang))
	return out

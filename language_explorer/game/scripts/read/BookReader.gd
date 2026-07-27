class_name BookReader
extends Control
## Books companion: one sentence at a time, gold word-follow narration,
## next-sentence tile anytime, tap-to-spell, long-press definition when known.
## Optional page image on entry + corner replay tile.

signal finished()
signal request_back()

const WordLabelS := preload("res://scripts/WordLabel.gd")
const ClearButtonS := preload("res://scripts/ClearButton.gd")

var _built := false
var _book_id: String = ""
var _meta: Dictionary = {}
var _page_index: int = 0
var _sentence_index: int = 0
var _sentences: PackedStringArray = PackedStringArray()
var _lang: String = "en"
var _busy: bool = false
var _gen: int = 0
var _page_shown_image: bool = false

var _title: Label
var _page_lbl: Label
var _panel: Panel
var _flow: HFlowContainer
var _words: Array = []  # WordLabel
var _clear_next: ClearButton
var _image_overlay: ColorRect
var _image_full: TextureRect
var _image_thumb: TextureButton
var _turn_cover: ColorRect
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
	_sentence_index = 0
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_title.text = str(_meta.get("title", book_id))
	Save.record_activity_started("book_" + book_id)
	_enter_page(true)

func stop() -> void:
	_gen += 1
	_busy = false
	Narrator.stop()
	if not _book_id.is_empty():
		Save.set_bookmark(_book_id, _page_index)
	if _built:
		_clear_words()
		_hide_image_overlay()
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

	_panel = Panel.new()
	_panel.position = Vector2(80, 90)
	_panel.size = Vector2(1120, 360)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := LangTheme.rounded_box(LangTheme.PANEL, 20)
	sb.set_border_width_all(2)
	sb.border_color = Color(1, 1, 1, 0.18)
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)

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

	_clear_next = ClearButtonS.new()
	_clear_next.position = Vector2(580, 480)
	_clear_next.size = Vector2(120, 72)
	_clear_next.context_pressed.connect(_on_clear)
	add_child(_clear_next)

	_image_thumb = TextureButton.new()
	_image_thumb.ignore_texture_size = true
	_image_thumb.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_image_thumb.custom_minimum_size = Vector2(96, 96)
	_image_thumb.size = Vector2(96, 96)
	_image_thumb.position = Vector2(1160, 480)
	_image_thumb.focus_mode = Control.FOCUS_NONE
	_image_thumb.visible = false
	_image_thumb.pressed.connect(_show_image_overlay)
	add_child(_image_thumb)

	_turn_cover = ColorRect.new()
	_turn_cover.color = Color(0.05, 0.07, 0.12, 0.0)
	_turn_cover.position = Vector2(80, 90)
	_turn_cover.size = Vector2(1120, 360)
	_turn_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_turn_cover.visible = false
	add_child(_turn_cover)

	_image_overlay = ColorRect.new()
	_image_overlay.color = Color(0.02, 0.03, 0.06, 0.88)
	_image_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_image_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_image_overlay.visible = false
	_image_overlay.gui_input.connect(_on_overlay_input)
	add_child(_image_overlay)

	_image_full = TextureRect.new()
	_image_full.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image_full.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_image_full.position = Vector2(140, 40)
	_image_full.size = Vector2(1000, 520)
	_image_full.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_image_overlay.add_child(_image_full)

func _clear_words() -> void:
	for w in _words:
		if is_instance_valid(w):
			w.queue_free()
	_words.clear()
	for c in _flow.get_children():
		c.queue_free()

func _enter_page(from_start: bool) -> void:
	_gen += 1
	_busy = false
	Narrator.stop()
	_clear_words()
	_hide_image_overlay()
	_clear_next.set_context(ClearButton.Context.NEXT_SENTENCE, _lang)
	_clear_next.visible = true

	var pages: Array = _meta.get("pages", [])
	if pages.is_empty():
		_page_lbl.text = LangVo.line("empty_page", _lang)
		Narrator.speak(LangVo.line("empty_page", _lang))
		return

	_page_index = clampi(_page_index, 0, pages.size() - 1)
	Save.set_bookmark(_book_id, _page_index)
	_page_lbl.text = "Page %d of %d" % [_page_index + 1, pages.size()]

	var page := LangData.load_page(str(pages[_page_index]))
	_sentences = _sentences_for_page(page)
	if from_start:
		_sentence_index = 0
	else:
		_sentence_index = clampi(_sentence_index, 0, maxi(0, _sentences.size() - 1))

	var tex := _page_image_texture(page)
	_page_shown_image = false
	if tex != null:
		_image_full.texture = tex
		_image_thumb.texture_normal = tex
		_image_thumb.visible = true
		_show_image_overlay()
		# Wait for tap-to-continue before sentence; overlay handler continues.
		return
	_image_thumb.visible = false
	_show_sentence()

func _sentences_for_page(page: Dictionary) -> PackedStringArray:
	var raw: Array = page.get("sentences", [])
	if not raw.is_empty():
		var packed := PackedStringArray()
		for s in raw:
			var line := Narrator.normalize_line(str(s))
			if not line.is_empty():
				packed.append(line)
		if not packed.is_empty():
			return packed
	var text := str(page.get("text", ""))
	if text.is_empty():
		var tokens: Array = page.get("tokens", [])
		if not tokens.is_empty():
			text = " ".join(PackedStringArray(tokens))
	var parts := Narrator.split_sentences(text)
	if parts.is_empty() and not text.strip_edges().is_empty():
		parts = PackedStringArray([Narrator.normalize_line(text)])
	return parts

func _page_image_texture(page: Dictionary) -> Texture2D:
	var path := str(page.get("image", page.get("image_path", "")))
	if path.is_empty():
		return null
	if not FileAccess.file_exists(path) and not ResourceLoader.exists(path):
		return null
	var res: Resource = load(path)
	if res is Texture2D:
		return res as Texture2D
	return null

func _show_image_overlay() -> void:
	if _image_full.texture == null:
		return
	_image_overlay.visible = true
	move_child(_image_overlay, -1)

func _hide_image_overlay() -> void:
	if _image_overlay != null:
		_image_overlay.visible = false

func _on_overlay_input(ev: InputEvent) -> void:
	if not _image_overlay.visible:
		return
	var tap := false
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		tap = mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
	elif ev is InputEventScreenTouch:
		tap = (ev as InputEventScreenTouch).pressed
	if not tap:
		return
	_hide_image_overlay()
	if not _page_shown_image:
		_page_shown_image = true
		_show_sentence()

func _show_sentence() -> void:
	_gen += 1
	_busy = false
	Narrator.stop()
	_clear_words()
	if _sentences.is_empty():
		Narrator.speak(LangVo.line("empty_page", _lang))
		return
	_sentence_index = clampi(_sentence_index, 0, _sentences.size() - 1)
	var sentence := str(_sentences[_sentence_index])
	var tokens := sentence.split(" ", false)
	for tok in tokens:
		var wl: WordLabel = WordLabelS.new()
		wl.custom_minimum_size = Vector2(maxi(48, str(tok).length() * 18), 48)
		wl.setup(str(tok), 32)
		wl.mouse_filter = Control.MOUSE_FILTER_STOP
		var captured := wl
		wl.tapped.connect(func() -> void: _spell_word(captured))
		wl.long_pressed.connect(func() -> void: _on_word_long_press(captured))
		_flow.add_child(wl)
		_words.append(wl)
	_narrate_sentence()

func _spell_word(wl: WordLabel) -> void:
	if wl == null:
		return
	_gen += 1
	var gen := _gen
	_busy = true
	Narrator.stop()
	await wl.spell(_lang, WordLabel.State.NORMAL)
	if gen != _gen:
		return
	_busy = false

func _on_word_long_press(wl: WordLabel) -> void:
	if wl == null:
		return
	var def := LangData.definition_for(wl.get_word(), _lang)
	if def.is_empty():
		return
	_gen += 1
	var gen := _gen
	_busy = true
	Narrator.stop()
	wl.apply_state(WordLabel.State.SPELLING_GOLD)
	var d := Narrator.speak(def)
	await _wait(gen, maxf(1.2, d))
	if gen != _gen:
		return
	wl.apply_state(WordLabel.State.NORMAL)
	_busy = false

func _on_clear(ctx: int) -> void:
	# Always interruptible — next sentence anytime.
	match ctx:
		ClearButton.Context.NEXT_SENTENCE, ClearButton.Context.NEXT_PAGE:
			_advance_sentence()

func _narrate_sentence() -> void:
	_gen += 1
	var gen := _gen
	_busy = true
	if _words.is_empty():
		_busy = false
		return
	for wl in _words:
		if gen != _gen:
			return
		var label: WordLabel = wl
		label.apply_state(WordLabel.State.SPELLING_GOLD)
		var d := Narrator.speak(label.get_word())
		if not await _wait(gen, maxf(0.7, d - 0.05)):
			return
		label.apply_state(WordLabel.State.NORMAL)
	_busy = false

func _advance_sentence() -> void:
	_gen += 1
	Narrator.stop()
	_busy = false
	if _sentences.is_empty():
		_advance_page()
		return
	if _sentence_index >= _sentences.size() - 1:
		_advance_page()
		return
	var d := Narrator.speak(LangVo.line("next_sentence", _lang))
	var gen := _gen
	_busy = true
	await _wait(gen, maxf(0.55, d - 0.1))
	if gen != _gen:
		return
	_busy = false
	_sentence_index += 1
	_show_sentence()

func _advance_page() -> void:
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
	await _page_turn_anim(gen2)
	if gen2 != _gen:
		return
	var d2 := Narrator.speak(LangVo.line("next_page", _lang))
	if not await _wait(gen2, maxf(0.55, d2 - 0.1)):
		return
	_busy = false
	_page_index += 1
	_sentence_index = 0
	Save.set_bookmark(_book_id, _page_index)
	_enter_page(true)

func _page_turn_anim(gen: int) -> void:
	# Rough page-turn: sweep a dark veil left→right across the page panel.
	_turn_cover.visible = true
	_turn_cover.color = Color(0.05, 0.07, 0.12, 0.0)
	_turn_cover.size = Vector2(0, 360)
	var steps := 8
	for i in range(steps + 1):
		if gen != _gen:
			_turn_cover.visible = false
			return
		var t := float(i) / float(steps)
		_turn_cover.size = Vector2(1120.0 * t, 360)
		_turn_cover.color = Color(0.05, 0.07, 0.12, 0.55 * (1.0 - absf(t - 0.5) * 2.0))
		await get_tree().create_timer(0.04).timeout
	_turn_cover.visible = false
	_turn_cover.size = Vector2(1120, 360)

func _wait(gen: int, secs: float) -> bool:
	await get_tree().create_timer(secs).timeout
	return gen == _gen and is_inside_tree() and visible

static func vo_lines() -> Array:
	var out: Array = []
	out.append(LangVo.line("empty_page", "en"))
	out.append(LangVo.line("empty_page", "es"))
	out.append(LangVo.line("the_end", "en"))
	out.append(LangVo.line("the_end", "es"))
	out.append(LangVo.line("next_sentence", "en"))
	out.append(LangVo.line("next_sentence", "es"))
	out.append(LangVo.line("next_page", "en"))
	out.append(LangVo.line("next_page", "es"))
	for book in LangData.books_shipped(""):
		var lang := str(book.get("lang", "en"))
		for path in book.get("pages", []):
			var page := LangData.load_page(str(path))
			var text := str(page.get("text", ""))
			if not text.is_empty():
				out.append(text)
			for s in Narrator.split_sentences(text):
				out.append(str(s))
			for tok in page.get("tokens", []):
				out.append(str(tok))
				for ch in LangLetters.spell_letters(str(tok)):
					out.append(LangLetters.letter_name(ch, lang))
	for def in LangData.definition_vo_lines():
		out.append(str(def))
	return out

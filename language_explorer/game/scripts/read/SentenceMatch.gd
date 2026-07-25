class_name SentenceMatch
extends Control
## Read → Sentences: watch a short sprite play-out, then match sprites to red words.
## Missing .ogv → still stage + VO. Drag or tap-to-place (EggsDrag pattern).

signal finished()
signal request_back()

enum Phase { INTRO, MATCH, DONE }

const WordLabelS := preload("res://scripts/WordLabel.gd")
const SpriteChipS := preload("res://scripts/SpriteChip.gd")
const ClearButtonS := preload("res://scripts/ClearButton.gd")

var _built := false
var _phase: int = Phase.INTRO
var _gen: int = 0
var _busy: bool = false
var _lang: String = "en"
var _queue: Array = []       # sentence dicts for current lang
var _index: int = 0
var _data: Dictionary = {}

var _stage: Control           # intro play-out area
var _stage_bg: Panel
var _sentence_row: HBoxContainer
var _words: Array = []        # WordLabel
var _word_meta: Array = []    # {token, matchable, matched, label}
var _chips: Array = []        # SpriteChip
var _matched: Dictionary = {} # normalize_token -> true

var _clear_read: ClearButton
var _clear_next: ClearButton
var _hint: Label

var _selected: SpriteChip = null
var _dragging: SpriteChip = null
var _drag_off: Vector2 = Vector2.ZERO
var _drag_start: Vector2 = Vector2.ZERO
var _moved: bool = false

func start(lang: String = "") -> void:
	_build()
	_lang = lang if not lang.is_empty() else Save.get_lang()
	_queue = LangData.sentences_for_lang(_lang)
	if _queue.is_empty():
		_queue = LangData.sentences()
	_index = 0
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_deal_current()

func stop() -> void:
	_gen += 1
	_busy = false
	Narrator.stop()
	if _built:
		_clear_scene()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _build() -> void:
	if _built:
		return
	_built = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)

	_stage = Control.new()
	_stage.position = Vector2(240, 40)
	_stage.size = Vector2(800, 160)
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)

	_stage_bg = Panel.new()
	_stage_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := LangTheme.rounded_box(LangTheme.PANEL, 18)
	sb.set_border_width_all(2)
	sb.border_color = Color(1, 1, 1, 0.2)
	_stage_bg.add_theme_stylebox_override("panel", sb)
	_stage.add_child(_stage_bg)

	_sentence_row = HBoxContainer.new()
	_sentence_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_sentence_row.add_theme_constant_override("separation", 18)
	_sentence_row.position = Vector2(40, 230)
	_sentence_row.size = Vector2(1200, 90)
	_sentence_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sentence_row)

	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 18)
	_hint.add_theme_color_override("font_color", LangTheme.TEXT_DIM)
	_hint.position = Vector2(40, 560)
	_hint.size = Vector2(1200, 28)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)

	_clear_read = ClearButtonS.new()
	_clear_read.position = Vector2(420, 500)
	_clear_read.size = Vector2(120, 72)
	_clear_read.visible = false
	_clear_read.context_pressed.connect(_on_clear)
	add_child(_clear_read)

	_clear_next = ClearButtonS.new()
	_clear_next.position = Vector2(740, 500)
	_clear_next.size = Vector2(120, 72)
	_clear_next.visible = false
	_clear_next.context_pressed.connect(_on_clear)
	add_child(_clear_next)

func _clear_scene() -> void:
	for w in _words:
		if is_instance_valid(w):
			w.queue_free()
	_words.clear()
	_word_meta.clear()
	for c in _chips:
		if is_instance_valid(c):
			c.queue_free()
	_chips.clear()
	_matched.clear()
	_selected = null
	_dragging = null
	for child in _stage.get_children():
		if child != _stage_bg:
			child.queue_free()
	_clear_read.visible = false
	_clear_next.visible = false
	_hint.text = ""

func _deal_current() -> void:
	_gen += 1
	var gen := _gen
	_clear_scene()
	if _queue.is_empty():
		_hint.text = "No sentences for this language yet."
		return
	_index = posmod(_index, _queue.size())
	_data = _queue[_index]
	_phase = Phase.INTRO
	_busy = true
	await _play_intro(gen)
	if gen != _gen:
		return
	_phase = Phase.MATCH
	_busy = false
	_spread_sentence()
	_spawn_chips()
	_hint.text = "Tap a picture, then tap a red word — or drag."

func _play_intro(gen: int) -> void:
	# Missing video → short sprite play-out on the stage + speak the sentence.
	var sprites: Array = _data.get("sprites", [])
	var actors: Array = []
	var x := 80.0
	for sp in sprites:
		var chip: SpriteChip = SpriteChipS.new()
		chip.setup(str(sp.get("id", "")), str(sp.get("token", "")), str(sp.get("image", "")))
		chip.position = Vector2(x, 36)
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stage.add_child(chip)
		actors.append(chip)
		x += 140.0
	# Simple left-to-right hop.
	for i in actors.size():
		if gen != _gen:
			return
		var a: SpriteChip = actors[i]
		var tw := create_tween()
		tw.tween_property(a, "position:y", 20.0, 0.22).set_trans(Tween.TRANS_SINE)
		tw.tween_property(a, "position:y", 36.0, 0.22).set_trans(Tween.TRANS_SINE)
		await tw.finished
	if gen != _gen:
		return
	var text := str(_data.get("text", ""))
	var d := Narrator.speak(text)
	if not await _wait(gen, maxf(1.6, d)):
		return
	for a in actors:
		a.queue_free()

func _spread_sentence() -> void:
	var tokens: Array = _data.get("tokens", [])
	var matchable: Array = _data.get("matchable", [])
	for tok in tokens:
		var wrap := Control.new()
		wrap.custom_minimum_size = Vector2(maxi(70, str(tok).length() * 28), 90)
		wrap.size = wrap.custom_minimum_size
		wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_sentence_row.add_child(wrap)

		var wl: WordLabel = WordLabelS.new()
		wl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		wl.offset_top = 24
		wl.setup(str(tok), 36)
		wl.mouse_filter = Control.MOUSE_FILTER_STOP
		if SentenceLogic.is_matchable_token(str(tok), matchable):
			wl.apply_state(WordLabel.State.TARGET_RED)
		wrap.add_child(wl)
		_words.append(wl)
		_word_meta.append({
			"token": str(tok),
			"matchable": SentenceLogic.is_matchable_token(str(tok), matchable),
			"matched": false,
			"label": wl,
			"wrap": wrap,
		})
		var idx := _word_meta.size() - 1
		wl.gui_input.connect(func(ev: InputEvent) -> void: _on_word_input(idx, ev))

func _spawn_chips() -> void:
	var sprites: Array = _data.get("sprites", [])
	var n := sprites.size()
	var total_w := float(n) * 110.0
	var x0 := 640.0 - total_w * 0.5
	for i in n:
		var sp: Dictionary = sprites[i]
		var chip: SpriteChip = SpriteChipS.new()
		chip.setup(str(sp.get("id", "")), str(sp.get("token", "")), str(sp.get("image", "")))
		var pos := Vector2(x0 + float(i) * 110.0, 360.0)
		chip.set_home(pos)
		add_child(chip)
		_chips.append(chip)

# ---- input -------------------------------------------------------------------

func _on_gui_input(ev: InputEvent) -> void:
	if _phase != Phase.MATCH or _busy:
		return
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_press_at(mb.position)
		else:
			_release_at(mb.position)
	elif ev is InputEventScreenTouch:
		var st := ev as InputEventScreenTouch
		if st.pressed:
			_press_at(st.position)
		else:
			_release_at(st.position)
	elif ev is InputEventMouseMotion and _dragging != null:
		var mm := ev as InputEventMouseMotion
		_drag_to(mm.position)
	elif ev is InputEventScreenDrag and _dragging != null:
		var sd := ev as InputEventScreenDrag
		_drag_to(sd.position)

func _press_at(local_pos: Vector2) -> void:
	_moved = false
	_drag_start = local_pos
	var chip := _chip_at(local_pos)
	if chip == null or chip.matched:
		return
	_dragging = chip
	_drag_off = local_pos - chip.position
	move_child(chip, -1)

func _drag_to(local_pos: Vector2) -> void:
	if _dragging == null:
		return
	if local_pos.distance_to(_drag_start) > SpriteChip.DRAG_THRESHOLD:
		_moved = true
		_select_chip(_dragging)
	_dragging.position = local_pos - _drag_off

func _release_at(local_pos: Vector2) -> void:
	var chip := _dragging
	_dragging = null
	if chip == null:
		# Tap on empty — ignore.
		return
	if not _moved:
		# Tap select / deselect.
		if _selected == chip:
			_select_chip(null)
			chip.return_home(true)
		else:
			_select_chip(chip)
		return
	# Drag end → try drop on a word.
	_try_drop(chip, local_pos)

func _on_word_input(idx: int, ev: InputEvent) -> void:
	if _phase == Phase.DONE:
		# Still allow spelling finished words.
		if _is_click(ev):
			_spell_word(idx)
		return
	if _phase != Phase.MATCH or _busy:
		return
	if not _is_click(ev):
		return
	var meta: Dictionary = _word_meta[idx]
	if _selected != null and bool(meta.get("matchable", false)) and not bool(meta.get("matched", false)):
		_try_match(_selected, idx)
		return
	_spell_word(idx)

func _is_click(ev: InputEvent) -> bool:
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		return mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
	if ev is InputEventScreenTouch:
		return (ev as InputEventScreenTouch).pressed
	return false

func _chip_at(local_pos: Vector2) -> SpriteChip:
	# Top-most first.
	for i in range(_chips.size() - 1, -1, -1):
		var c: SpriteChip = _chips[i]
		if c.matched:
			continue
		if Rect2(c.position, c.size * c.scale).grow(8).has_point(local_pos):
			return c
	return null

func _word_index_at(local_pos: Vector2) -> int:
	for i in _word_meta.size():
		var wrap: Control = _word_meta[i]["wrap"]
		var r := wrap.get_global_rect()
		# Convert local_pos (this control) to global.
		var g := get_global_transform() * local_pos
		if r.has_point(g):
			return i
	return -1

func _select_chip(chip: SpriteChip) -> void:
	if _selected != null and is_instance_valid(_selected) and _selected != chip:
		_selected.set_selected(false)
		if not _selected.matched:
			_selected.return_home(true)
	_selected = chip
	if chip != null:
		chip.set_selected(true)

func _try_drop(chip: SpriteChip, local_pos: Vector2) -> void:
	var idx := _word_index_at(local_pos)
	if idx < 0:
		chip.return_home(true)
		_select_chip(null)
		return
	_try_match(chip, idx)

func _try_match(chip: SpriteChip, word_idx: int) -> void:
	if _busy or chip == null or chip.matched:
		return
	var meta: Dictionary = _word_meta[word_idx]
	if not bool(meta.get("matchable", false)) or bool(meta.get("matched", false)):
		chip.return_home(true)
		_select_chip(null)
		return
	var ok := SentenceLogic.sprite_matches_token(chip.token, str(meta["token"]))
	if ok:
		_on_correct(chip, word_idx)
	else:
		_on_incorrect(chip, word_idx)

func _on_correct(chip: SpriteChip, word_idx: int) -> void:
	_gen += 1
	var gen := _gen
	_busy = true
	_select_chip(null)
	var meta: Dictionary = _word_meta[word_idx]
	var wl: WordLabel = meta["label"]
	var key := SentenceLogic.normalize_token(str(meta["token"]))
	var d := Narrator.speak(LangVo.line("correct", _lang))
	if not await _wait(gen, maxf(0.9, d)):
		return
	await wl.spell(_lang, WordLabel.State.DONE_GREEN)
	if gen != _gen:
		return
	meta["matched"] = true
	_matched[key] = true
	chip.mark_matched()
	# Park small sprite above the word.
	var wrap: Control = meta["wrap"]
	var target := wrap.global_position + Vector2(wrap.size.x * 0.5 - chip.size.x * 0.25, -8)
	chip.global_position = target
	_busy = false
	if SentenceLogic.all_matched(_matched, _data.get("matchable", [])):
		_enter_done()

func _on_incorrect(chip: SpriteChip, word_idx: int) -> void:
	_gen += 1
	var gen := _gen
	_busy = true
	var meta: Dictionary = _word_meta[word_idx]
	var wl: WordLabel = meta["label"]
	var line := LangVo.line("almost", _lang)
	var d := Narrator.speak(line)
	if not await _wait(gen, maxf(1.2, d)):
		return
	# Spell the *target* word so she hears the truth.
	await wl.spell(_lang, WordLabel.State.TARGET_RED)
	if gen != _gen:
		return
	chip.return_home(true)
	_select_chip(null)
	_busy = false

func _spell_word(word_idx: int) -> void:
	if _busy:
		return
	_gen += 1
	var gen := _gen
	_busy = true
	var meta: Dictionary = _word_meta[word_idx]
	var wl: WordLabel = meta["label"]
	var finish := WordLabel.State.DONE_GREEN if bool(meta.get("matched", false)) \
		else (WordLabel.State.TARGET_RED if bool(meta.get("matchable", false)) else WordLabel.State.NORMAL)
	await wl.spell(_lang, finish)
	if gen != _gen:
		return
	_busy = false

func _enter_done() -> void:
	_phase = Phase.DONE
	Save.record_activity_finished("sentence_" + str(_data.get("id", "")))
	_hint.text = ""
	_clear_read.set_context(ClearButton.Context.READ_ALL, _lang)
	_clear_read.visible = true
	_clear_next.set_context(ClearButton.Context.NEXT_SENTENCE, _lang)
	_clear_next.visible = true

func _on_clear(ctx: int) -> void:
	if _busy:
		return
	match ctx:
		ClearButton.Context.READ_ALL:
			_read_all_slowly()
		ClearButton.Context.NEXT_SENTENCE:
			_advance_sentence()

func _advance_sentence() -> void:
	_gen += 1
	var gen := _gen
	_busy = true
	var d := Narrator.speak(LangVo.line("next_sentence", _lang))
	if not await _wait(gen, maxf(0.8, d)):
		return
	_busy = false
	_index += 1
	_deal_current()

func _read_all_slowly() -> void:
	_gen += 1
	var gen := _gen
	_busy = true
	var d0 := Narrator.speak(LangVo.line("read_all", _lang))
	if not await _wait(gen, maxf(1.0, d0)):
		return
	for i in _word_meta.size():
		if gen != _gen:
			return
		var meta: Dictionary = _word_meta[i]
		var wl: WordLabel = meta["label"]
		var prev := WordLabel.State.DONE_GREEN if bool(meta.get("matched", false)) \
			else (WordLabel.State.TARGET_RED if bool(meta.get("matchable", false)) else WordLabel.State.NORMAL)
		wl.apply_state(WordLabel.State.SPELLING_GOLD)
		var d := Narrator.speak(wl.get_word())
		if not await _wait(gen, maxf(0.85, d - 0.05)):
			return
		wl.apply_state(prev)
	_busy = false

func _wait(gen: int, secs: float) -> bool:
	await get_tree().create_timer(secs).timeout
	return gen == _gen and is_inside_tree() and visible

static func vo_lines() -> Array:
	var out: Array = []
	out.append(LangVo.line("correct", "en"))
	out.append(LangVo.line("correct", "es"))
	out.append(LangVo.line("almost", "en"))
	out.append(LangVo.line("almost", "es"))
	out.append(LangVo.line("read_all", "en"))
	out.append(LangVo.line("read_all", "es"))
	out.append(LangVo.line("next_sentence", "en"))
	out.append(LangVo.line("next_sentence", "es"))
	# Every seed sentence text + each token as a spoken word.
	for row in LangData.sentences():
		out.append(str(row.get("text", "")))
		for tok in row.get("tokens", []):
			out.append(str(tok))
		# Letter names for matchable words (spell path).
		var lang := str(row.get("lang", "en"))
		for m in row.get("matchable", []):
			for ch in LangLetters.spell_letters(str(m)):
				out.append(LangLetters.letter_name(ch, lang))
			out.append(str(m))
	return out

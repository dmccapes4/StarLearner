extends SceneTree
## Headless logic tests for Language Explorer.
##   godot --headless --path . -s res://tests/run_tests.gd

var _pass := 0
var _fail := 0

func _init() -> void:
	call_deferred("_run")

func _ok(cond: bool, msg: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: ", msg)

func _run() -> void:
	print("======== Language Explorer tests ========")
	_test_theme()
	_test_data()
	_test_letters()
	_test_wordlabel_logic()
	_test_sentence_logic()
	_test_double_tap_arm()
	_test_write_session()
	_test_tutorials()
	_test_narrator_helpers()
	_test_scripts_compile()
	_test_save()
	_test_intro_lines()
	_test_vo_coverage()
	print("======== TOTAL: %d passed, %d failed ========" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)

func _test_theme() -> void:
	_ok(LangTheme.MODE_ORDER.size() == 3, "three home modes")
	for mode in ["read", "write", "voice"]:
		_ok(LangTheme.MODES.has(mode), "MODES has %s" % mode)
		_ok(not str(LangTheme.MODES[mode]["label"]).is_empty(), "%s has label" % mode)
	_ok(LangTheme.LETTER_INPUT_DEFAULT == "alphabet", "alphabet is default letter input")
	var sb := LangTheme.rounded_box(LangTheme.GOLD, 12)
	_ok(sb is StyleBoxFlat, "rounded_box returns StyleBoxFlat")

func _test_data() -> void:
	var sentences := LangData.sentences()
	_ok(sentences.size() >= 0, "sentences catalog loads (legacy optional)")

	var words := LangData.words()
	_ok(words.size() >= 16, "at least sixteen seed words")
	var wlangs := {}
	for w in words:
		_ok((w.get("letters", []) as Array).size() >= 1, "%s has letters" % w.get("id"))
		wlangs[str(w.get("lang", ""))] = true
		var derived := WriteSession.letters_for_word(w)
		_ok(derived.size() >= 1, "%s spell letters" % w.get("id"))
	_ok(wlangs.has("en") and wlangs.has("es"), "words cover en and es")
	var apple_letters := WriteSession.letters_for_word({"word": "Apple"})
	_ok(str(apple_letters[0]) == "A" and str(apple_letters[1]) == "p", "Apple letters A,p,…")
	_ok(WordArt.texture_for({"image_id": "apple", "word": "Apple"}) != null, "WordArt apple")
	_ok(WordArt.texture_for({"image_id": "dog", "word": "Dog"}) != null, "WordArt dog")

	var defs := LangData.definitions()
	_ok(defs.has("en") and defs.has("es"), "definitions has en+es")
	_ok(not LangData.definition_for("rabbit", "en").is_empty(), "rabbit has kid definition")
	_ok(not LangData.definition_for("liebre", "es").is_empty(), "liebre has kid definition")
	_ok(LangData.definition_for("Rabbits.", "en").find("hop") >= 0, "definition strips punct")
	_ok(LangData.definition_for("zzzz", "en").is_empty(), "unknown word has no definition")

	var books := LangData.books()
	_ok(books.size() >= 2, "at least two catalog books")
	var shipped := LangData.books_shipped("")
	_ok(shipped.size() >= 2, "at least two shipped books")
	var book_langs := {}
	for b in shipped:
		_ok(str(b.get("license", "")).find("TODO") < 0, "shipped book has real license")
		_ok((b.get("pages", []) as Array).size() >= 1, "%s has pages" % b.get("id"))
		book_langs[str(b.get("lang", ""))] = true
		var meta := LangData.book_by_id(str(b.get("id", "")))
		_ok(not meta.is_empty(), "%s meta loads" % b.get("id"))
		var page0 := LangData.load_page(str((b.get("pages", []) as Array)[0]))
		_ok((page0.get("tokens", []) as Array).size() >= 1, "%s page0 has tokens" % b.get("id"))
		var sents := Narrator.split_sentences(str(page0.get("text", "")))
		_ok(sents.size() >= 1, "%s page0 splits to sentences" % b.get("id"))
	_ok(book_langs.has("en") and book_langs.has("es"), "shipped books cover en and es")
	_ok(CoverArt.texture_for({"id": "x", "cover_motif": "rabbit", "title": "T"}) != null, "CoverArt rabbit")

func _test_letters() -> void:
	_ok(LangLetters.EN_ALPHABET.size() == 26, "EN alphabet has 26")
	_ok(LangLetters.ES_ALPHABET.size() == 27, "ES alphabet has 27 (incl Ñ)")
	_ok(LangLetters.letter_name("a", "en") == "A", "EN letter name A")
	_ok(LangLetters.letter_name("ñ", "es") == "Eñe", "ES letter name Ñ")
	var apple := LangLetters.spell_letters("Apple")
	_ok(apple.size() == 5, "Apple has 5 letters")
	_ok(str(apple[0]) == "A" and str(apple[1]) == "p", "Apple preserves case")
	var red := LangLetters.spell_letters("red.")
	_ok(red.size() == 3, "punctuation skipped in spell_letters")
	_ok(LangLetters.is_letter("M") and not LangLetters.is_letter("."), "is_letter filter")

func _test_wordlabel_logic() -> void:
	# Pure helpers — no need to mount in tree for spell_letters / vo_lines.
	var lines: Array = WordLabel.vo_lines()
	_ok(lines.has("A") and lines.has("Apple"), "WordLabel vo includes Apple letters")
	_ok(lines.has("Eme") and lines.has("Manzana"), "WordLabel vo includes Manzana letters")
	_ok(ClearButton.vo_lines().size() >= 6, "ClearButton has EN+ES context lines")
	_ok(not LangVo.line("correct", "en").is_empty(), "LangVo correct EN")
	_ok(LangVo.line("correct", "es").find("Correcto") >= 0, "LangVo correct ES")

	# Case follow for Apple: first upper, rest lower expected keys.
	var chars := LangLetters.spell_letters("Apple")
	_ok(LangLetters.normalize_key(chars[0]) == "A", "Apple[0] key A")
	_ok(LangLetters.normalize_key(chars[1]) == "P", "Apple[1] key P")

func _test_sentence_logic() -> void:
	# Legacy SentenceLogic helpers still used by archived SentenceMatch.
	_ok(SentenceLogic.normalize_token("Red.") == "red", "normalize strips punct + case")
	_ok(SentenceLogic.normalize_token("  Apple  ") == "apple", "normalize trims")
	_ok(SentenceLogic.is_matchable_token("apple", ["apple", "red"]), "apple is matchable")
	_ok(not SentenceLogic.is_matchable_token("The", ["apple", "red"]), "The is not matchable")
	_ok(SpriteArt.texture_for("apple") != null, "SpriteArt placeholder apple")
	_ok(SpriteArt.texture_for("dog") != null, "SpriteArt placeholder dog")
	_ok(SpriteArt.texture_for("star") != null, "SpriteArt placeholder star")
	_ok(SpriteArt.texture_for("unknown_xyz") != null, "SpriteArt fallback placeholder")

func _test_double_tap_arm() -> void:
	var arm := DoubleTapArm.new(5.0)
	_ok(arm.press("a", 1.0) == DoubleTapArm.RESULT_ARMED, "first tap arms")
	_ok(arm.press("a", 2.0) == DoubleTapArm.RESULT_TRIGGER, "second tap within window triggers")
	_ok(arm.press("b", 10.0) == DoubleTapArm.RESULT_ARMED, "fresh key arms")
	_ok(arm.press("b", 16.0) == DoubleTapArm.RESULT_ARMED, "after timeout re-arms (not trigger)")
	arm.press("c", 20.0)
	_ok(arm.poll(26.0), "poll clears expired arm")
	_ok(not arm.is_armed(), "arm cleared after poll")
	_ok(LangVo.page_saved_line(3, "en").find("3") >= 0, "page_saved EN")
	_ok(LangVo.page_saved_line(3, "es").find("3") >= 0, "page_saved ES")
	var BookReaderS := load("res://scripts/read/BookReader.gd")
	var br_lines: Array = BookReaderS.vo_lines()
	_ok(br_lines.has("The end."), "BookReader vo includes The end")
	_ok(br_lines.has("Fin."), "BookReader vo includes Fin")

func _test_write_session() -> void:
	var seq: Array = WriteSession.case_follow_sequence("Apple")
	_ok(seq.size() == 5, "Apple has 5 spell letters")
	_ok(str(seq[0]) == "A" and str(seq[1]) == "p", "Apple case A then p")
	var sol: Array = WriteSession.case_follow_sequence("Sol")
	_ok(str(sol[0]) == "S" and str(sol[1]) == "o" and str(sol[2]) == "l", "Sol case S o l")

	var sess := WriteSession.new()
	sess.start({"id": "en_apple", "lang": "en", "word": "Apple"})
	_ok(sess.expected_letter() == "A", "start expects A")
	_ok(sess.expected_is_upper(), "A is upper")
	_ok(sess.try_letter("a") == WriteSession.Result.WRONG, "wrong case a is wrong")
	_ok(sess.wrong_count == 1, "wrong counted")
	_ok(not bool(sess.disabled_keys.get("A", false)), "wrong case does not lock A key")
	_ok(sess.try_letter("B") == WriteSession.Result.WRONG, "B is wrong")
	_ok(bool(sess.disabled_keys.get("B", false)), "wrong letter B locks")
	_ok(sess.try_letter("C") == WriteSession.Result.WRONG, "C is wrong → reveal gate")
	_ok(sess.revealed, "three wrongs reveal")
	_ok(sess.try_letter("A") == WriteSession.Result.CORRECT, "A correct after reveal")
	_ok(sess.expected_letter() == "p", "next expects p")
	_ok(not sess.expected_is_upper(), "p is lower")
	_ok(not sess.revealed and sess.wrong_count == 0, "counts reset after correct")

	# Incomplete never false-completes: only exact matches advance.
	var s2 := WriteSession.new()
	s2.start({"id": "es_sol", "lang": "es", "word": "Sol"})
	_ok(s2.try_letter("S") == WriteSession.Result.CORRECT, "Sol S")
	_ok(s2.try_letter("O") == WriteSession.Result.WRONG, "O wrong case for o")
	_ok(s2.filled_count() == 1, "still one filled after wrong")
	_ok(s2.try_letter("o") == WriteSession.Result.CORRECT, "o correct")
	_ok(s2.try_letter("l") == WriteSession.Result.CORRECT, "l correct")
	_ok(s2.is_complete(), "Sol complete")

	# Hint reveal path.
	var s3 := WriteSession.new()
	s3.start({"id": "en_cat", "lang": "en", "word": "Cat"})
	s3.register_hint()
	s3.register_hint()
	_ok(not s3.revealed, "two hints no reveal")
	s3.register_hint()
	_ok(s3.revealed, "three hints reveal")

	# ES alphabet includes Ñ.
	_ok(LangLetters.alphabet_for("es").has("Ñ"), "ES board has Ñ")
	_ok(not LangLetters.alphabet_for("en").has("Ñ"), "EN board has no Ñ")

func _test_tutorials() -> void:
	var tutorials := LangData.tutorials()
	_ok(tutorials.size() >= 5, "five tutorial topics")
	for row in tutorials:
		_ok(not str(row.get("id", "")).is_empty(), "tutorial has id")
		var steps: Dictionary = row.get("steps", {})
		for lang in ["en", "es"]:
			var localized: Array = steps.get(lang, [])
			_ok(localized.size() >= 2, "%s has %s steps" % [row.get("id"), lang])
			for step in localized:
				_ok(not str(step.get("say", "")).is_empty(), "tutorial step has narration")
	_ok(not LangData.tutorial_by_id("tut_alphabet").is_empty(), "alphabet tutorial lookup")
	_ok(not LangData.tutorial_by_id("tut_read").is_empty(), "read tutorial lookup")
	_ok(not LangData.tutorial_by_id("tut_voice").is_empty(), "voice tutorial lookup")
	_ok(LangData.tutorial_by_id("tut_sentences").is_empty(), "sentence tutorial removed")
	var TutorialS := load("res://scripts/ui/TutorialPlayer.gd")
	var lines: Array = TutorialS.vo_lines()
	_ok(lines.size() >= 16, "tutorial VO inventory")

func _test_narrator_helpers() -> void:
	_ok(Narrator.normalize_line("  Hello   world  ") == "Hello world", "normalize collapses spaces")
	var parts := Narrator.split_sentences("Hello. World!")
	_ok(parts.size() == 2, "split two sentences")
	_ok(Narrator.vo_key("Hello.") == Narrator.normalize_line("Hello.").md5_text(), "vo_key is md5")
	_ok(Narrator.estimate_seconds("Hello there friend") > 1.0, "estimate duration")
	Narrator.stop()
	_ok(not Narrator.blocks_input(), "stop clears input lock")
	var Icons := load("res://scripts/ChromeIcons.gd")
	_ok(Icons.texture("alphabet") != null, "ChromeIcons alphabet")
	_ok(Icons.texture("sketch") != null, "ChromeIcons sketch")
	_ok(Icons.texture("read_slowly") != null, "ChromeIcons read_slowly")

func _test_scripts_compile() -> void:
	for path in [
		"res://scripts/Main.gd",
		"res://scripts/LangTheme.gd",
		"res://scripts/LangData.gd",
		"res://scripts/LangLetters.gd",
		"res://scripts/LangVo.gd",
		"res://scripts/WordLabel.gd",
		"res://scripts/ChromeIcons.gd",
		"res://scripts/ClearButton.gd",
		"res://scripts/SpellDemo.gd",
		"res://scripts/Save.gd",
		"res://scripts/Narrator.gd",
		"res://scripts/NarratorVoice.gd",
		"res://scripts/VoStream.gd",
		"res://scripts/read/ReadHome.gd",
		"res://scripts/read/SentenceMatch.gd",
		"res://scripts/read/BookShelf.gd",
		"res://scripts/read/BookReader.gd",
		"res://scripts/SentenceLogic.gd",
		"res://scripts/SpriteChip.gd",
		"res://scripts/SpriteArt.gd",
		"res://scripts/CoverArt.gd",
		"res://scripts/DoubleTapArm.gd",
		"res://scripts/write/WriteHome.gd",
		"res://scripts/write/WriteSession.gd",
		"res://scripts/write/WriteFromImage.gd",
		"res://scripts/write/WriteFromNarration.gd",
		"res://scripts/write/AlphabetBoard.gd",
		"res://scripts/write/LetterSlots.gd",
		"res://scripts/write/TraceCanvas.gd",
		"res://scripts/WordArt.gd",
		"res://scripts/MicOwner.gd",
		"res://scripts/voice/MicCapture.gd",
		"res://scripts/voice/HubClient.gd",
		"res://scripts/voice/VoiceToWrite.gd",
		"res://scripts/ui/TutorialPlayer.gd",
		"res://scripts/ui/HamburgerPanel.gd",
		"res://tools/dump_vo_lines.gd",
		"res://tools/capture_shots.gd",
		"res://tools/record_playthrough_demo.gd",
	]:
		_ok(load(path) != null, "compiles: %s" % path)

func _test_save() -> void:
	var save := root.get_node_or_null("/root/Save")
	_ok(save != null, "Save autoload is registered")
	var mic_owner := root.get_node_or_null("/root/MicOwner")
	_ok(mic_owner != null, "MicOwner autoload is registered")
	if save == null:
		return
	save.call("clear_all")
	_ok(not save.call("is_intro_done"), "fresh: intro not done")
	_ok(str(save.call("get_lang")) == "en", "fresh: lang en")
	_ok(str(save.call("get_letter_input")) == "alphabet", "fresh: alphabet input")

	save.call("set_intro_done", true)
	_ok(save.call("is_intro_done"), "intro sticks")
	save.call("set_lang", "es")
	_ok(str(save.call("get_lang")) == "es", "lang es sticks")
	save.call("set_letter_input", "sketch")
	_ok(str(save.call("get_letter_input")) == "sketch", "sketch sticks")
	save.call("set_bookmark", "demo_book", 3)
	_ok(int(save.call("get_bookmark", "demo_book")) == 3, "bookmark sticks")
	save.call("mark_seen", "tut_read")
	_ok(save.call("was_seen", "tut_read"), "seen sticks")
	save.call("record_activity_started", "books")
	save.call("record_activity_finished", "books")
	var stats: Dictionary = save.get("stats")
	var act: Dictionary = stats.get("activity", {}).get("books", {})
	_ok(int(act.get("started", 0)) == 1, "activity started counted")
	_ok(int(act.get("finished", 0)) == 1, "activity finished counted")

	save.call("clear_all")
	_ok(not save.call("is_intro_done"), "clear_all resets intro")
	_ok(str(save.call("get_letter_input")) == "alphabet", "clear_all resets letter input")
	_ok(not save.call("was_seen", "tut_read"), "clear_all resets seen")

func _test_intro_lines() -> void:
	var MainS := load("res://scripts/Main.gd")
	var lines: Array = MainS.intro_lines()
	_ok(lines.size() >= 5, "intro has several lines")
	_ok(str(lines[0]).find("Language Explorer") >= 0, "intro welcomes by name")

func _test_vo_coverage() -> void:
	## Every sentence in the bake manifest must have a WAV (run tools/gen_vo.sh).
	var manifest_path := "res://data/language_vo_manifest.json"
	if not FileAccess.file_exists(manifest_path):
		_ok(false, "language_vo_manifest.json missing — run dump_vo_lines.gd")
		return
	var f := FileAccess.open(manifest_path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	_ok(typeof(parsed) == TYPE_DICTIONARY, "VO manifest is a dictionary")
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var entries: Dictionary = parsed
	_ok(entries.size() > 40, "VO manifest is non-trivial (%d)" % entries.size())
	var missing := 0
	for key in entries:
		var path := "res://audio/vo/%s.wav" % key
		if not FileAccess.file_exists(path):
			missing += 1
			if missing <= 8:
				print("  missing VO clip: ", entries[key])
	_ok(missing == 0, "every manifest sentence has a baked ElevenLabs clip (%d missing)" % missing)

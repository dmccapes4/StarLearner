extends SceneTree
## Enumerate every sentence Language Explorer can speak → VO manifest for
## tools/gen_language_vo.py (ElevenLabs bake).
##
##   godot --headless --path . -s res://tools/dump_vo_lines.gd

const NarratorScript := preload("res://scripts/Narrator.gd")
const LangLettersS := preload("res://scripts/LangLetters.gd")
const LangVoS := preload("res://scripts/LangVo.gd")
const WordLabelS := preload("res://scripts/WordLabel.gd")
const ClearButtonS := preload("res://scripts/ClearButton.gd")
const SpellDemoS := preload("res://scripts/SpellDemo.gd")
# SentenceMatch references Save autoload — load at runtime (not preload).

const OUT_PATH := "res://data/language_vo_manifest.json"

var _lines: Dictionary = {}  ## md5 → sentence

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var MainScript: GDScript = load("res://scripts/Main.gd")

	for s in MainScript.intro_lines():
		_add(str(s))
	for s in LangLettersS.vo_lines():
		_add(str(s))
	for s in LangVoS.vo_lines():
		_add(str(s))
	for s in WordLabelS.vo_lines():
		_add(str(s))
	for s in ClearButtonS.vo_lines():
		_add(str(s))
	for s in SpellDemoS.vo_lines():
		_add(str(s))
	var SentenceMatchS: GDScript = load("res://scripts/read/SentenceMatch.gd")
	if SentenceMatchS != null:
		for s in SentenceMatchS.vo_lines():
			_add(str(s))
	var BookShelfS: GDScript = load("res://scripts/read/BookShelf.gd")
	if BookShelfS != null:
		for s in BookShelfS.vo_lines():
			_add(str(s))
	var BookReaderS: GDScript = load("res://scripts/read/BookReader.gd")
	if BookReaderS != null:
		for s in BookReaderS.vo_lines():
			_add(str(s))
	var WriteImageS: GDScript = load("res://scripts/write/WriteFromImage.gd")
	if WriteImageS != null:
		for s in WriteImageS.vo_lines():
			_add(str(s))
	var WriteNarrS: GDScript = load("res://scripts/write/WriteFromNarration.gd")
	if WriteNarrS != null:
		for s in WriteNarrS.vo_lines():
			_add(str(s))
	var TutorialS: GDScript = load("res://scripts/ui/TutorialPlayer.gd")
	if TutorialS != null:
		for s in TutorialS.vo_lines():
			_add(str(s))

	# Mode labels spoken on tile entry.
	_add("Read")
	_add("Write")
	_add("Books")
	_add("Images")
	_add("Narration")

	var chars := 0
	for key in _lines:
		chars += str(_lines[key]).length()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://data"))
	var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(_lines, "\t", false))
	f.close()
	print("wrote %s: %d sentences, %d chars" % [
		ProjectSettings.globalize_path(OUT_PATH), _lines.size(), chars])
	quit()

func _add(text: String) -> void:
	for s in NarratorScript.split_sentences(text):
		_lines[NarratorScript.vo_key(s)] = s

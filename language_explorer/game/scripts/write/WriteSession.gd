class_name WriteSession
extends RefCounted
## Shared write-practice state: letter index, wrong/hint counts, reveal gate, case follow.
## Pure logic — UI layers call try_letter / register_hint / complete_letter.

signal letter_advanced(index: int)
signal word_finished()
signal reveal_requested()
signal board_should_reset()

const REVEAL_AFTER := 3

enum Result { IGNORE, WRONG, CORRECT, ALREADY_DONE }

var word_id: String = ""
var word: String = ""
var lang: String = "en"
var letters: PackedStringArray = PackedStringArray()
var index: int = 0
var wrong_count: int = 0
var hint_count: int = 0
var revealed: bool = false
## Keys (uppercase normalize_key) disabled for this letter attempt.
var disabled_keys: Dictionary = {}
var done: bool = false

static func letters_for_word(data: Dictionary) -> PackedStringArray:
	var from_word := LangLetters.spell_letters(str(data.get("word", "")))
	if from_word.size() > 0:
		return from_word
	var arr: Array = data.get("letters", [])
	var out := PackedStringArray()
	for ch in arr:
		out.append(str(ch))
	return out

func start(data: Dictionary) -> void:
	word_id = str(data.get("id", ""))
	word = str(data.get("word", ""))
	lang = str(data.get("lang", "en"))
	letters = letters_for_word(data)
	index = 0
	done = letters.is_empty()
	_reset_letter_attempt()

func expected_letter() -> String:
	if done or index < 0 or index >= letters.size():
		return ""
	return str(letters[index])

func expected_key() -> String:
	return LangLetters.normalize_key(expected_letter())

func expected_is_upper() -> bool:
	var ch := expected_letter()
	if ch.is_empty():
		return true
	# Title-case / uppercase glyph?
	return ch == ch.to_upper() and ch != ch.to_lower()

func filled_count() -> int:
	return index if not done else letters.size()

func is_complete() -> bool:
	return done

## Case-sensitive glyph match against the current slot.
func try_letter(glyph: String) -> int:
	if done:
		return Result.ALREADY_DONE
	var want := expected_letter()
	if want.is_empty():
		return Result.IGNORE
	var key := LangLetters.normalize_key(glyph)
	if key.is_empty():
		return Result.IGNORE
	if bool(disabled_keys.get(key, false)) and not revealed:
		return Result.IGNORE
	# Exact case-sensitive compare of the display glyph.
	if glyph == want:
		_on_correct()
		return Result.CORRECT
	wrong_count += 1
	# Wrong case of the *right* letter still counts toward reveal, but do not
	# lock the key — she needs to flip A|a and tap the matching case.
	if key != expected_key():
		disabled_keys[key] = true
	if wrong_count >= REVEAL_AFTER and not revealed:
		revealed = true
		reveal_requested.emit()
	return Result.WRONG

## Image tap or clear-icon replay — bumps hint counter toward reveal.
func register_hint() -> String:
	if done:
		return ""
	var ch := expected_letter()
	if ch.is_empty():
		return ""
	hint_count += 1
	if hint_count >= REVEAL_AFTER and not revealed:
		revealed = true
		reveal_requested.emit()
	return ch

func complete_letter_from_sketch() -> void:
	## Sketch path: tracing the current outline counts as correct without a tile pick.
	if done:
		return
	_on_correct()

func _on_correct() -> void:
	index += 1
	if index >= letters.size():
		done = true
		index = letters.size()
		word_finished.emit()
	else:
		_reset_letter_attempt()
		letter_advanced.emit(index)
		board_should_reset.emit()

func _reset_letter_attempt() -> void:
	wrong_count = 0
	hint_count = 0
	revealed = false
	disabled_keys.clear()

## Headless helpers for tests.
static func case_follow_sequence(word_text: String) -> Array:
	var out: Array = []
	for ch in LangLetters.spell_letters(word_text):
		out.append(str(ch))
	return out

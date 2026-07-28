class_name LangLetters
extends RefCounted
## Letter inventories and spoken letter *names* for EN / ES.
## Spelling pedagogy: speak the name, then the full word.

const EN_ALPHABET := [
	"A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M",
	"N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
]

## Spanish alphabet for the board (base letters + Ñ). Accented vowels are spoken
## by glyph when they appear in a word; they are not separate board tiles in v1.
const ES_ALPHABET := [
	"A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M",
	"N", "Ñ", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
]

## Spoken letter names (uppercase keys). EN uses full names so ElevenLabs does not
## read a lone glyph as a sound ("Y" → ee, "U" → ooh). ES uses traditional names.
const EN_NAMES := {
	"A": "Ay", "B": "Bee", "C": "See", "D": "Dee", "E": "Ee", "F": "Eff", "G": "Jee",
	"H": "Aitch", "I": "Eye", "J": "Jay", "K": "Kay", "L": "Ell", "M": "Emm", "N": "Enn",
	"O": "Oh", "P": "Pee", "Q": "Cue", "R": "Ar", "S": "Ess", "T": "Tee", "U": "You",
	"V": "Vee", "W": "Double you", "X": "Ex", "Y": "Why", "Z": "Zee",
}

const ES_NAMES := {
	"A": "A", "B": "Be", "C": "Ce", "D": "De", "E": "E", "F": "Efe",
	"G": "Ge", "H": "Hache", "I": "I", "J": "Jota", "K": "Ka", "L": "Ele",
	"M": "Eme", "N": "Ene", "Ñ": "Eñe", "O": "O", "P": "Pe", "Q": "Cu",
	"R": "Erre", "S": "Ese", "T": "Te", "U": "U", "V": "Uve", "W": "Doble uve",
	"X": "Equis", "Y": "Ye", "Z": "Zeta",
	"Á": "A con acento", "É": "E con acento", "Í": "I con acento",
	"Ó": "O con acento", "Ú": "U con acento", "Ü": "U con diéresis",
}

static func alphabet_for(lang: String) -> Array:
	return ES_ALPHABET.duplicate() if lang == "es" else EN_ALPHABET.duplicate()

static func normalize_key(ch: String) -> String:
	if ch.is_empty():
		return ""
	var c := ch.substr(0, 1)
	# Preserve Ñ / ñ and accented vowels as distinct keys.
	var upper := c.to_upper()
	if c == "ñ" or c == "Ñ":
		return "Ñ"
	return upper

static func letter_name(ch: String, lang: String) -> String:
	var key := normalize_key(ch)
	if key.is_empty():
		return ""
	if lang == "es":
		return str(ES_NAMES.get(key, key))
	return str(EN_NAMES.get(key, key))

## Split a display word into spellable letters (skips spaces/punctuation).
static func spell_letters(word: String) -> PackedStringArray:
	var out := PackedStringArray()
	for i in word.length():
		var ch := word.substr(i, 1)
		if is_letter(ch):
			out.append(ch)
	return out

static func is_letter(ch: String) -> bool:
	if ch.is_empty():
		return false
	var lower := ch.to_lower()
	var code := lower.unicode_at(0)
	# a-z
	if code >= 97 and code <= 122:
		return true
	# Common Latin extras used in Spanish.
	if lower in ["ñ", "á", "é", "í", "ó", "ú", "ü"]:
		return true
	return false

## Every spoken letter-name string for the VO bake (both languages).
static func vo_lines() -> Array:
	var out: Array = []
	for ch in EN_ALPHABET:
		out.append(letter_name(ch, "en"))
	for ch in ES_ALPHABET:
		out.append(letter_name(ch, "es"))
	for ch in ["Á", "É", "Í", "Ó", "Ú", "Ü"]:
		out.append(letter_name(ch, "es"))
	return out

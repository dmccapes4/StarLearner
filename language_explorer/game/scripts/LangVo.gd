class_name LangVo
extends RefCounted
## Fixed coaching / chrome lines shared across Read + Write (both languages).
## Dynamic book page text may still fall back to OS TTS; these are always baked.

const EN := {
	"correct": "Correct!",
	"almost": "Nice try. Let's listen again.",
	"almost2": "Almost. Listen to the letters.",
	"great": "Great job!",
	"you_got_it": "You got it!",
	"read_all": "Let's read it slowly.",
	"next_sentence": "Next sentence.",
	"next_page": "Next page.",
	"tap_image_letter": "Tap the picture to hear the next letter.",
	"tap_clear_letter": "Tap the clear button to hear the letter again.",
	"coming_sentences": "Sentence practice is coming soon!",
	"coming_books": "Books are coming soon!",
	"coming_images": "Picture writing is coming soon!",
	"coming_narration": "Narration writing is coming soon!",
	"alphabet_tiles": "Alphabet tiles.",
	"sketch_letters": "Sketch letters.",
	"english": "English.",
	"spanish": "Español.",
	"credits": "Language Explorer. A Star Learner title for reading and writing.",
	"read_blurb": "Read. Practice sentences, or open a book.",
	"write_blurb": "Write. Practice with pictures, or with narration.",
	"demo_apple": "Let's spell Apple.",
	"demo_manzana": "Vamos a deletrear Manzana.",
	"books_blurb": "Books. Tap a cover once to hear about it, tap again to open.",
	"tap_again": "Tap again to open.",
	"start_beginning": "Starting at the beginning.",
	"empty_page": "This page is empty.",
	"the_end": "The end.",
	"write_images_blurb": "Write with pictures. Pick one, then tap letters.",
	"write_narration_blurb": "Write with narration. Pick a word, then tap letters.",
	"trace_hint": "Trace the grey letter with your finger.",
	"next_word": "Next word.",
}

const ES := {
	"correct": "¡Correcto!",
	"almost": "Buen intento. Escuchemos otra vez.",
	"almost2": "Casi. Escucha las letras.",
	"great": "¡Muy bien!",
	"you_got_it": "¡Lo lograste!",
	"read_all": "Léamoslo despacio.",
	"next_sentence": "Siguiente oración.",
	"next_page": "Siguiente página.",
	"tap_image_letter": "Toca la imagen para oír la siguiente letra.",
	"tap_clear_letter": "Toca el botón claro para oír la letra otra vez.",
	"coming_sentences": "¡La práctica de oraciones llega pronto!",
	"coming_books": "¡Los libros llegan pronto!",
	"coming_images": "¡La escritura con imágenes llega pronto!",
	"coming_narration": "¡La escritura con narración llega pronto!",
	"alphabet_tiles": "Fichas del alfabeto.",
	"sketch_letters": "Trazar letras.",
	"english": "English.",
	"spanish": "Español.",
	"credits": "Explorador de Lenguaje. Un título de Star Learner para leer y escribir.",
	"read_blurb": "Leer. Practica oraciones, o abre un libro.",
	"write_blurb": "Escribir. Practica con imágenes, o con narración.",
	"demo_apple": "Let's spell Apple.",
	"demo_manzana": "Vamos a deletrear Manzana.",
	"books_blurb": "Libros. Toca una portada para oír, toca otra vez para abrir.",
	"tap_again": "Toca otra vez para abrir.",
	"start_beginning": "Empezamos desde el principio.",
	"empty_page": "Esta página está vacía.",
	"the_end": "Fin.",
	"write_images_blurb": "Escribe con imágenes. Elige una, luego toca letras.",
	"write_narration_blurb": "Escribe con narración. Elige una palabra, luego toca letras.",
	"trace_hint": "Traza la letra gris con el dedo.",
	"next_word": "Siguiente palabra.",
}

static func line(key: String, lang: String = "en") -> String:
	var table: Dictionary = ES if lang == "es" else EN
	if table.has(key):
		return str(table[key])
	if EN.has(key):
		return str(EN[key])
	return key

## Spoken bookmark cue — page_num is 1-based for kids.
static func page_saved_line(page_num: int, lang: String = "en") -> String:
	if lang == "es":
		return "Te quedaste en la página %d." % page_num
	return "You left on page %d." % page_num

static func vo_lines() -> Array:
	var out: Array = []
	for k in EN.keys():
		out.append(str(EN[k]))
	for k in ES.keys():
		out.append(str(ES[k]))
	# Seed practice words / sentences spoken as wholes.
	for w in ["Apple", "Manzana", "Cat", "Gato", "Sun", "Sol", "Hat", "Sombrero"]:
		out.append(w)
	for s in [
		"The apple is red.",
		"La manzana es roja.",
		"The cat has a hat.",
		"El gato tiene un sombrero.",
		"The sun is big.",
		"El sol es grande.",
	]:
		out.append(s)
	for n in range(1, 9):
		out.append(page_saved_line(n, "en"))
		out.append(page_saved_line(n, "es"))
	return out

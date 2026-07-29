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
	"read_blurb": "Read. Open a book and follow along.",
	"write_blurb": "Write. Spell words from pictures.",
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
	"tap_picture_again": "Tap the picture to hear the letters again.",
	"voice_needs_wifi": "I can't reach the writing helper right now. Check Wi-Fi, or try Read or Write.",
	"voice_intro": "This mode is meant to be played while you write with pen and paper. Keep your pencil on the paper — say next to move, or tap the arrows.",
	"voice_intro_first": "This mode is meant to be played alongside writing with pen and paper. You say what you want to write — like, I want to go to the zoo. First tap the microphone and say next once, so your pencil can stay on the paper. Then say your idea. We write it letter by letter — say next, or tap the arrow on the right.",
	"voice_listen_dot": "When the red circle appears in the corner, I'm listening for you to say next.",
	"voice_tap_say_next": "Tap the microphone, then say next.",
	"voice_tap_say_idea": "Tap the microphone and say what you want to write. Tap again when you are done, or wait ten seconds.",
	"voice_rerecord_or_phrase": "Tap the microphone and say what you want to write. Or tap the red arrow to record next again.",
	"voice_enroll_next": "First, say next.",
	"voice_say_idea": "Tell me what you want to write.",
	"voice_listening": "I'm listening.",
	"voice_thinking": "One moment.",
	"voice_try_again": "Let's try again.",
	"voice_mic_busy": "I couldn't hear you. Tap the microphone and say it again.",
	"voice_got_it": "Got it!",
	"voice_say_next": "Say next, or tap the arrow.",
	"voice_confirm_rerecord": "If that's not right, tap the little microphone below and say it again.",
	"voice_upper_letter": "Upper case {letter}.",
	"voice_lower_letter": "Lower case {letter}.",
	"voice_first_letter": "First letter.",
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
	"read_blurb": "Leer. Abre un libro y sigue la historia.",
	"write_blurb": "Escribir. Deletrea palabras con dibujos.",
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
	"tap_picture_again": "Toca la imagen para oír las letras otra vez.",
	"voice_needs_wifi": "No puedo alcanzar el ayudante de escritura. Revisa el Wi-Fi, o prueba Leer o Escribir.",
	"voice_intro": "Este modo se juega mientras escribes con lápiz y papel. Deja el lápiz en el papel — di next para avanzar, o toca las flechas.",
	"voice_intro_first": "Este modo se juega junto con escribir con lápiz y papel. Dices lo que quieres escribir — por ejemplo, quiero ir al zoológico. Primero toca el micrófono y di next una vez, para que tu lápiz se quede en el papel. Luego di tu idea. La escribimos letra por letra — di next, o toca la flecha de la derecha.",
	"voice_listen_dot": "Cuando aparece el círculo rojo en la esquina, estoy escuchando para que digas next.",
	"voice_tap_say_next": "Toca el micrófono y di next.",
	"voice_tap_say_idea": "Toca el micrófono y di lo que quieres escribir. Toca otra vez cuando termines, o espera diez segundos.",
	"voice_rerecord_or_phrase": "Toca el micrófono y di lo que quieres escribir. O toca la flecha roja para grabar next otra vez.",
	"voice_enroll_next": "Primero, di next.",
	"voice_say_idea": "Dime qué quieres escribir.",
	"voice_listening": "Te escucho.",
	"voice_thinking": "Un momento.",
	"voice_try_again": "Intentemos otra vez.",
	"voice_mic_busy": "No te oí. Toca el micrófono y dilo otra vez.",
	"voice_got_it": "¡Listo!",
	"voice_say_next": "Di next, o toca la flecha.",
	"voice_confirm_rerecord": "Si no es correcto, toca el micrófono pequeño abajo y dilo otra vez.",
	"voice_upper_letter": "Mayúscula {letter}.",
	"voice_lower_letter": "Minúscula {letter}.",
	"voice_first_letter": "Primera letra.",
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
	for w in ["Apple", "Manzana", "Cat", "Gato", "Sun", "Sol", "Hat", "Sombrero",
			"Dog", "Perro", "Fish", "Pez", "Ball", "Pelota", "Tree", "Arbol",
			"Star", "Estrella", "Moon", "Luna", "Bird", "Pajaro", "Bee", "Abeja",
			"Árbol", "Pájaro"]:
		out.append(w)
	for n in range(1, 9):
		out.append(page_saved_line(n, "en"))
		out.append(page_saved_line(n, "es"))
	return out

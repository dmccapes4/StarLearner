class_name WordArt
extends RefCounted
## Cue images for Write mode. Prefer on-disk PNG; else reuse SpriteArt motifs.

static func texture_for(word: Dictionary) -> Texture2D:
	var path := str(word.get("image", ""))
	if not path.is_empty() and FileAccess.file_exists(path):
		var res: Resource = load(path)
		if res is Texture2D:
			return res as Texture2D
	var motif := str(word.get("image_id", word.get("id", "")))
	if motif.begins_with("en_") or motif.begins_with("es_"):
		motif = motif.substr(3)
	# Map pair nouns onto SpriteArt ids.
	match motif:
		"apple", "manzana":
			motif = "apple"
		"cat", "gato":
			motif = "cat"
		"hat", "sombrero":
			motif = "hat"
		"sun", "sol":
			motif = "sun"
		"dog", "perro":
			motif = "dog"
		"fish", "pez":
			motif = "fish"
		"ball", "pelota":
			motif = "ball"
		"tree", "arbol", "árbol":
			motif = "tree"
		"star", "estrella":
			motif = "star"
		"moon", "luna":
			motif = "moon"
		"bird", "pajaro", "pájaro":
			motif = "bird"
		"bee", "abeja":
			motif = "bee"
	return SpriteArt.texture_for(motif, path)

class_name StorySprites
extends RefCounted
## Maps a problem's `subjects` tags (from MathProblemGen) to the flat-vector art in
## res://images/story/. Some subjects are intentionally drawn procedurally (coins,
## cubes, the clock face, the rail track) and map to "" — callers draw those.
## Keeps art lookup in one place so generators stay art-agnostic.

const DIR := "res://images/story/"

const MAP := {
	# generated flat-vector sprites (keyed transparent):
	"chicken_white": "chicken_white.png",
	"chicken_yellow": "chicken_yellow.png",
	"egg": "egg.png",
	"carton": "carton_open.png",
	"carton_open": "carton_open.png",
	"carton_closed": "carton_closed.png",
	"doll": "doll.png",
	"basket": "basket.png",
	"piggy_bank": "piggy_bank.png",
	"stone_plain": "stone.png",
	"stone_painted": "stone.png",   # same art, tinted at runtime
	"kid": "painter_kid.png",
	"train_a": "train_a.png",
	"train_b": "train_b.png",
	"station": "station.png",
	# drawn procedurally (no file on purpose):
	"penny": "", "nickel": "", "dime": "",
	"cubes": "", "clock_face": "", "track": "",
}

## True if this subject tag is known (whether art-backed or procedural).
static func known(tag: String) -> bool:
	return MAP.has(tag)

## True if this subject has an image file (vs. being drawn procedurally).
static func has_art(tag: String) -> bool:
	return MAP.get(tag, "") != ""

static func path(tag: String) -> String:
	var f: String = MAP.get(tag, "")
	return (DIR + f) if f != "" else ""

static func texture(tag: String) -> Texture2D:
	var p := path(tag)
	if p == "" or not ResourceLoader.exists(p):
		return null
	return load(p) as Texture2D

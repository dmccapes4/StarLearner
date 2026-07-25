extends SceneTree
## Enumerate every Garden Explorer narration sentence → garden_vo_manifest.json
##
##   godot --headless --path game -s res://tools/dump_vo_lines.gd

const NarratorScript := preload("res://scripts/audio/Narrator.gd")
const OUT := "res://data/garden_vo_manifest.json"

var _lines: Dictionary = {} ## md5 -> sentence

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_add("Welcome to the garden! Tap the shed for seeds, water your plants, and open the star menu.")
	_add("Welcome to the garden")
	_add("Still there? Tap the garden to keep playing.")
	_add("Cluck cluck! I'm pecking for seeds.")
	_add("Hello! Chickens love a sunny garden.")
	_add("Hop hop! I like crunchy carrots and lettuce.")
	_add("Hello, little friend!")
	for season in ["Spring", "Summer", "Fall", "Winter"]:
		_add("It's %s! New seeds are in the shed." % season)
	var plants := {
		"Tomato": "Tomatoes",
		"Carrot": "Carrots",
		"Lettuce": "Lettuces",
		"Sunflower": "Sunflowers",
		"Pumpkin": "Pumpkins",
		"Strawberry": "Strawberries",
		"Pea": "Peas",
		"Radish": "Radishes",
		"Corn": "Corn",
		"Cucumber": "Cucumbers",
		"Bean": "Beans",
	}
	for p in plants.keys():
		_add("You have 1 %s." % p)
		var plural: String = plants[p]
		for n in [2, 3, 4, 5, 6, 8, 10, 12]:
			_add("You have %d %s." % [n, plural])
	_add("Plant a seed in a garden bed to unlock this star.")
	_add("Water a plant to unlock this star.")
	_add("Watch a seed sprout to unlock this star.")
	_add("Help a plant grow bigger to unlock this star.")
	_add("Uproot a plant to unlock this star.")
	_add("Harvest a grown plant to unlock this star.")
	_add("Wait for the season to change to unlock this star.")
	_add("Harvest something into the shed basket to unlock this star.")
	_add("Keep exploring the garden to unlock this star.")
	_add("Not discovered yet.")
	_add("Tap again to learn how to unlock.")
	_add("Tap again if you want to see the video without discovering it.")
	_add("Tap again to peek at the video without discovering it.")
	_add("Tap again to view.")
	_add("Follow the gold outline in the garden.")
	_add("Do that action in the garden to discover this video for real.")
	_add("Open the shed and pick up a seed.")
	_add("The first time you collect that seed, its seed video unlocks.")
	_add("Plant a seed and water it when the blue drop appears.")
	_add("When it sprouts, tap the plant to watch the sprout video.")
	_add("Keep watering your plant when it is thirsty.")
	_add("When it is fully grown, tap the harvest icon to watch its grown video.")
	_add("How to unlock")
	var topics := [
		"What is a seed?",
		"Soil & garden beds",
		"How to plant a seed",
		"Watering plants",
		"Seeds sprouting",
		"Sunlight & growing",
		"Watching plants grow",
		"Uprooting & clearing space",
		"Harvesting the garden",
		"Seasons in the garden",
		"Garden animals",
		"Storing the harvest",
	]
	for t in topics:
		_add("Let's look at the shed. %s Tap again to watch." % t)
		_add("Let's look at the garden beds. %s Tap again to watch." % t)
		_add("Let's visit the animals. %s Tap again to watch." % t)
		_add("Let's look around the whole garden. %s Tap again to watch." % t)
		_add("Tap again to watch %s." % t)
		_add(t)
	# Guidance lines without the confirm suffix
	for t in topics:
		_add("Let's look at the shed. %s" % t)
		_add("Let's look at the garden beds. %s" % t)
		_add("Let's visit the animals. %s" % t)
		_add("Let's look around the whole garden. %s" % t)

	## ---- Debug round 2: animals, bugs, harvest ceremony, seasons, shed UX ----
	var animals_raw = JSON.parse_string(FileAccess.get_file_as_string("res://data/animals.json"))
	if typeof(animals_raw) == TYPE_DICTIONARY:
		for a in animals_raw.get("animals", []):
			var an := str(a.get("name", ""))
			var kind := str(a.get("kind", ""))
			var pron := "He" if str(a.get("gender", "f")) == "m" else "She"
			_add("Walking to %s." % an)
			_add("This is %s! %s is a %s. Tap to learn more about %ss on farms." % [an, pron, kind, kind])
	var bugs_raw = JSON.parse_string(FileAccess.get_file_as_string("res://data/bugs.json"))
	if typeof(bugs_raw) == TYPE_DICTIONARY:
		for b in bugs_raw.get("bugs", []):
			_add(str(b.get("line", "")))
			_add("You caught a %s!" % str(b.get("name", "")))
	_add("We'll look carefully for bugs that live with our plants.")
	_add("No bugs today — try again later.")
	_add("Let's look for bugs in the garden!")
	_add("Let's peek inside the chicken coop!")
	_add("Chickens lay their eggs in cozy nesting boxes. Farmers collect them every morning!")
	_add("New seeds are in the shed.")
	_add("See the silver outline? Silver means you collected that seed before. When you harvest a plant, its seed turns gold!")
	for season in ["Spring", "Summer", "Fall", "Winter"]:
		for y in range(1, 11):
			_add("It's %s, year %d!" % [season, y])
	var seeds_raw = JSON.parse_string(FileAccess.get_file_as_string("res://data/seeds.json"))
	if typeof(seeds_raw) == TYPE_DICTIONARY:
		for p in seeds_raw.get("plants", []):
			var pn := str(p.get("name", str(p.get("id", "")).capitalize()))
			_add("You harvested your first %s!" % pn)
			_add("This is a %s seed." % pn)
			_add("Look — a real %s sprout!" % pn)
			_add("Farmers pick %s gently when it is ripe, so the plant is not hurt." % pn)
			_add("Fresh %s is full of vitamins that help you grow strong." % pn)
			_add("You picked %s!" % pn)

	var abs_path := ProjectSettings.globalize_path(OUT)
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	if f == null:
		push_error("Cannot write %s" % OUT)
		quit(1)
		return
	f.store_string(JSON.stringify(_lines, "\t"))
	f.close()
	print("Garden VO manifest: %d sentences → %s" % [_lines.size(), abs_path])
	quit(0)

func _add(text: String) -> void:
	for s in NarratorScript.split_sentences(text):
		_lines[NarratorScript.vo_key(s)] = s

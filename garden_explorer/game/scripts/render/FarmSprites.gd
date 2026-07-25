class_name FarmSprites
extends RefCounted
## Crop art from Mana Seed (Seliel) packs; world tiles still from Sprout Lands.
## Per-crop sheets are 160×32 (10 cells of 16×32):
##   0 inventory · 1 seed bag · 2 seeds-on-ground · 3–7 growth · 8–9 signs

const SPROUT_PACK := "res://assets/tiles/Sprout Lands - Sprites - premium pack/Sprout Lands - Sprites - premium pack"
const FILLS := "res://assets/tiles/sprout_lands/fills"
const MANA_CROPS := "res://assets/tiles/mana_seed_crops/crops"
const CELL_W := 16
const CELL_H := 32

## Fallback if a plant has no `sheet` field in seeds.json.
const SHEET_ALIAS := {
	"pea": "peasgreen",
	"bean": "beanspinto",
	"corn": "cornyellow",
	"onion": "onionyellow",
	"potato": "potatobrown",
	"grape": "grapesblue",
	"raspberry": "raspberries",
	"blueberry": "blueberries",
	"bell_pepper": "bellpeppergreen",
	"chili": "chilipepperred",
	"melon": "watermelon",
}

## Legacy Sprout Lands row map (only used if Mana Seed sheet missing).
const PLANT_ROWS := {
	"tomato": 0, "carrot": 1, "lettuce": 2, "pumpkin": 4, "strawberry": 5,
	"pea": 6, "radish": 7, "corn": 8, "cucumber": 9, "bean": 10,
}

var available: bool = false
var mana_ready: bool = false
var seed_db: SeedDB
var _plants_tex: Texture2D ## Sprout Lands fallback atlas
var _items_tex: Texture2D
var _char_tex: Texture2D
var _fence_tex: Texture2D
var _chicken_sheets: Dictionary = {}
var _barn_tex: Texture2D
var _coop_tex: Texture2D
var _crop_sheets: Dictionary = {} ## sheet_name -> Texture2D

func set_seed_db(db: SeedDB) -> void:
	seed_db = db

func bootstrap() -> void:
	_plants_tex = _load(SPROUT_PACK + "/Objects/Farming Plants.png")
	_items_tex = _load(SPROUT_PACK + "/Objects/Items/Farming Plants items.png")
	_char_tex = _load(SPROUT_PACK + "/Characters/Basic Charakter Spritesheet.png")
	_fence_tex = _load(SPROUT_PACK + "/Tilesets/Building parts/Fences.png")
	_barn_tex = _load(SPROUT_PACK + "/Tilesets/Building parts/Animal Structures/Barn structures.png")
	_coop_tex = _load(SPROUT_PACK + "/Tilesets/Building parts/Animal Structures/Chikcen_Houses.png")
	for color in ["default", "brown", "red", "blue", "green"]:
		_chicken_sheets[color] = _load(SPROUT_PACK + "/Animals/Chicken/chicken %s.png" % color)
	_preload_mana_crops()
	available = mana_ready or _plants_tex != null or _load(FILLS + "/sl_Mid_Grass1.png") != null
	if mana_ready:
		print("FarmSprites: Mana Seed crops ready (%d sheets)" % _crop_sheets.size())
	elif available:
		print("FarmSprites: Sprout Lands pack ready (Mana Seed missing)")
	else:
		push_warning("FarmSprites: no crop packs — placeholders only")

func _load(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is Texture2D:
			return res as Texture2D
	## Raw PNGs (Mana Seed, gitignored) may lack .import — load via Image.
	var abs := path
	if path.begins_with("res://"):
		abs = ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(abs):
		return null
	var img := Image.new()
	if img.load(abs) != OK:
		return null
	return ImageTexture.create_from_image(img)

func _preload_mana_crops() -> void:
	_crop_sheets.clear()
	var abs_dir := ProjectSettings.globalize_path(MANA_CROPS)
	var dir := DirAccess.open(abs_dir)
	if dir == null:
		dir = DirAccess.open(MANA_CROPS)
	if dir == null:
		mana_ready = false
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".png"):
			var stem := fname.get_basename()
			var tex := _load("%s/%s" % [MANA_CROPS, fname])
			if tex:
				_crop_sheets[stem] = tex
		fname = dir.get_next()
	dir.list_dir_end()
	mana_ready = not _crop_sheets.is_empty()

func grass_texture() -> Texture2D:
	return _load(FILLS + "/sl_Mid_Grass1.png")

func tilled_texture() -> Texture2D:
	var t := _load(FILLS + "/sl_tilled_0.png")
	if t == null:
		t = _load(FILLS + "/garden_soil.png")
	return t

func path_texture() -> Texture2D:
	return _load(FILLS + "/sl_soil_0.png")

func fence_texture() -> Texture2D:
	return _fence_tex

func chicken_texture(color: String = "default") -> Texture2D:
	var sheet: Texture2D = _chicken_sheets.get(color, null)
	if sheet == null:
		sheet = _chicken_sheets.get("default", null)
	if sheet == null:
		return null
	return _atlas(sheet, Rect2(0, 0, 16, 16))

func iso_crate_texture() -> Texture2D:
	if _barn_tex == null:
		return null
	return _atlas(_barn_tex, Rect2(0, 0, 16, 16))

func chicken_coop_texture() -> Texture2D:
	if _coop_tex == null:
		return null
	return _atlas(_coop_tex, Rect2(64 * 3, 0, 64, 80))

func character_walk_sheet() -> Texture2D:
	## Animated gardener girl (Mana Seed farmer base, palette-matched):
	## 3 rows x 6 cols of 64x64 — down / right / up walk cycles.
	return _load("res://assets/characters/gardener_walk.png")

func character_idle() -> Texture2D:
	## Daughter-like gardener (from solar_system astronaut girl likeness).
	var walk := character_walk_sheet()
	if walk:
		return _atlas(walk, Rect2(64, 0, 64, 64))
	var girl := _load("res://assets/characters/gardener_girl.png")
	if girl:
		return girl
	var hi := _load("res://assets/characters/gardener_girl_hi.png")
	if hi:
		return hi
	if _char_tex == null:
		return null
	return _atlas(_char_tex, Rect2(0, 0, 48, 48))

func sheet_name_for(plant_id: String) -> String:
	if seed_db:
		var plant := seed_db.get_plant(plant_id)
		var sheet := str(plant.get("sheet", ""))
		if not sheet.is_empty():
			return sheet
	return str(SHEET_ALIAS.get(plant_id, plant_id))

func seed_icon(plant_id: String) -> Texture2D:
	## Seed bag (col 1) — shed tiles + held chip.
	var mana := _mana_cell(plant_id, 1)
	if mana:
		return mana
	return _sprout_seed_icon(plant_id)

func harvest_icon(plant_id: String) -> Texture2D:
	## Ripe inventory icon (col 0).
	var mana := _mana_cell(plant_id, 0)
	if mana:
		return mana
	return plant_stage_texture(plant_id, "grown")

func plant_stage_texture(plant_id: String, stage: String) -> Texture2D:
	var col := 2 ## seeds on ground
	match stage:
		"seed":
			col = 2
		"sprout":
			col = 3
		"growing":
			col = 5
		"grown":
			col = 7
		_:
			col = 2
	var mana := _mana_cell(plant_id, col)
	if mana:
		return mana
	return _sprout_stage(plant_id, stage)

func _mana_cell(plant_id: String, col: int) -> Texture2D:
	var sheet_name := sheet_name_for(plant_id)
	var sheet: Texture2D = _crop_sheets.get(sheet_name, null)
	if sheet == null:
		## Lazy-load one file if bootstrap missed it.
		sheet = _load("%s/%s.png" % [MANA_CROPS, sheet_name])
		if sheet:
			_crop_sheets[sheet_name] = sheet
	if sheet == null:
		return null
	return _atlas(sheet, Rect2(col * CELL_W, 0, CELL_W, CELL_H))

func _sprout_seed_icon(plant_id: String) -> Texture2D:
	if _items_tex == null:
		return null
	var row := int(PLANT_ROWS.get(plant_id, 0))
	return _atlas(_items_tex, Rect2(0, row * 16, 16, 16))

func _sprout_stage(plant_id: String, stage: String) -> Texture2D:
	if _plants_tex == null:
		return null
	var row := int(PLANT_ROWS.get(plant_id, 0))
	var col := 0
	match stage:
		"seed":
			col = 0
		"sprout":
			col = 1
		"growing":
			col = 2
		"grown":
			col = 4
		_:
			col = 0
	return _atlas(_plants_tex, Rect2(col * 16, row * 16, 16, 16))

func _atlas(sheet: Texture2D, region: Rect2) -> AtlasTexture:
	var at := AtlasTexture.new()
	at.atlas = sheet
	at.region = region
	at.filter_clip = true
	return at

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
var _tools_tex: Texture2D
var _door_tex: Texture2D
var _cow_tex: Texture2D
var _crop_sheets: Dictionary = {} ## sheet_name -> Texture2D
var _action_icon_cache: Dictionary = {}
var _tree_sheet: Texture2D
var _raindrop_tex: Texture2D
var _rain_splash_tex: Texture2D
var _leaf_particle_tex: Texture2D
var _leaf_spin_tex: Texture2D
var _leaf_land_tex: Texture2D
var _bed_pack_cache: Dictionary = {} ## "plant_id:stage" -> Texture2D
var _bed_pack_star_hover: Dictionary = {} ## stage -> float (from offsets.json)
var _seed_plot_cache: Dictionary = {} ## plant_id -> cropped seed-ground Texture2D

## Wide horizontal canopy cells (Sprout Lands proportions).
const TREE_CELL_W := 56
const TREE_CELL_H := 48
const TREE_VARIANTS := ["narrow", "med", "large", "bush"]
const TREE_SEASONS := ["spring", "summer", "fall", "winter"]
const TREE_WIND_FRAMES := 2
const RAIN_SPLASH_FRAMES := 4
const RAIN_SPLASH_W := 16
const RAIN_SPLASH_H := 12
const LEAF_CELL := 12
const LEAF_SPIN_FRAMES := 8
const LEAF_LAND_POSES := 3
const LEAF_COLORS := 4

func set_seed_db(db: SeedDB) -> void:
	seed_db = db

func bootstrap() -> void:
	_plants_tex = _load(SPROUT_PACK + "/Objects/Farming Plants.png")
	_items_tex = _load(SPROUT_PACK + "/Objects/Items/Farming Plants items.png")
	_char_tex = _load(SPROUT_PACK + "/Characters/Basic Charakter Spritesheet.png")
	_fence_tex = _load(SPROUT_PACK + "/Tilesets/Building parts/Fences.png")
	_barn_tex = _load(SPROUT_PACK + "/Tilesets/Building parts/Animal Structures/Barn structures.png")
	_coop_tex = _load(SPROUT_PACK + "/Tilesets/Building parts/Animal Structures/Chikcen_Houses.png")
	_tools_tex = _load(SPROUT_PACK + "/Characters/Tools.png")
	_door_tex = _load(SPROUT_PACK + "/Tilesets/Building parts/door animation sprites.png")
	_cow_tex = _load(SPROUT_PACK + "/Animals/Cow/Free Cow Sprites.png")
	for color in ["default", "brown", "red", "blue", "green"]:
		_chicken_sheets[color] = _load(SPROUT_PACK + "/Animals/Chicken/chicken %s.png" % color)
	_preload_mana_crops()
	_tree_sheet = _load("res://assets/trees/seasonal_trees.png")
	_raindrop_tex = _load("res://assets/trees/raindrop.png")
	_rain_splash_tex = _load("res://assets/trees/rain_splash.png")
	_leaf_particle_tex = _load("res://assets/trees/leaf_particle.png")
	_leaf_spin_tex = _load("res://assets/trees/leaf_spin.png")
	_leaf_land_tex = _load("res://assets/trees/leaf_land.png")
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

func pen_fence_segment(kind: String) -> Texture2D:
	## Generated isometric pen fence:
	##   rail_a / rail_b — rails only (primary edge sections)
	##   post — standalone posts (placed on joints, above rails)
	##   run_* / seg_diag_* — legacy composites (unused by current placer)
	return _load("res://assets/ui/fence/%s.png" % kind)

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

func gate_frame_textures() -> Array:
	## Prefer generated isometric frames (match pen fence wood + 2:1 iso).
	## Fallback: Sprout Lands sheet (5 × 32×48).
	var frames: Array = []
	for i in 5:
		var path := "res://assets/ui/gate/open_%d.png" % i
		var tex := _load(path)
		if tex:
			frames.append(tex)
	if frames.size() == 5:
		return frames
	var sheet_path := "res://assets/tiles/sprout_lands/Tilesets/Building parts/Fence gates animation sprites .png"
	var sheet := _load(sheet_path)
	if sheet == null:
		return frames
	frames.clear()
	for i in 5:
		frames.append(_atlas(sheet, Rect2(i * 32, 0, 32, 48)))
	return frames

func portrait_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	return _load(path)

func bug_sprite(bug_id: String) -> Texture2D:
	## World bug sheet: 2×32 frames side-by-side (tools/gen_bug_sprites.py).
	## Falls back to a still portrait if the sheet is missing.
	var tex := _load("res://assets/bugs/%s.png" % bug_id)
	if tex:
		return tex
	return _load("res://assets/portraits/bug_%s.png" % bug_id)

func bug_frame_count(tex: Texture2D) -> int:
	## Horizontal 2-frame sheets are 2× taller-cell wide (e.g. 64×32).
	if tex == null:
		return 1
	var w := tex.get_width()
	var h := tex.get_height()
	if h > 0 and w >= h * 2:
		return 2
	return 1

func cow_texture() -> Texture2D:
	var packed := _load("res://assets/animals/cow_idle.png")
	if packed:
		return packed
	if _cow_tex == null:
		return null
	return _atlas(_cow_tex, Rect2(0, 0, 32, 32))

func pig_texture() -> Texture2D:
	return _load("res://assets/animals/pig_idle.png")

func rabbit_texture() -> Texture2D:
	return _load("res://assets/animals/rabbit_idle.png")

func dog_texture() -> Texture2D:
	return _load("res://assets/animals/dog_idle.png")

func dog_walk_sheet() -> Texture2D:
	## 4×4 sheet (tools/gen_buddy_sprites.py): cols back/right/front/left.
	return _load("res://assets/animals/dog_walk.png")

func shed_texture() -> Texture2D:
	return _load("res://assets/buildings/shed.png")

func door_texture() -> Texture2D:
	if _door_tex == null:
		return null
	return _atlas(_door_tex, Rect2(0, 0, 48, 32))

func watering_can_icon() -> Texture2D:
	var ui := _load("res://assets/ui/icon_water.png")
	if ui:
		return ui
	if _tools_tex == null:
		return null
	return _atlas(_tools_tex, Rect2(0, 0, 16, 16))

func action_icon(kind: String, plant_id: String = "") -> Texture2D:
	## Big readable icons for interaction tiles.
	var key := "%s:%s" % [kind, plant_id]
	if _action_icon_cache.has(key):
		return _action_icon_cache[key]
	var tex: Texture2D = null
	match kind:
		"plant":
			tex = seed_icon(plant_id) if not plant_id.is_empty() else null
		"harvest":
			## Prefer plant produce; fall back to basket glyph.
			tex = harvest_icon(plant_id) if not plant_id.is_empty() else null
			if tex == null:
				tex = _load("res://assets/ui/icon_harvest.png")
		"water":
			tex = watering_can_icon()
		"uproot":
			tex = _load("res://assets/ui/icon_uproot.png")
			if tex == null and _tools_tex:
				tex = _atlas(_tools_tex, Rect2(0, 64, 16, 16))
		"open_shed":
			## Generated seed-basket tile (not the old barn door sprite).
			tex = _load("res://assets/ui/icon_seeds.png")
			if tex == null:
				tex = door_texture()
		"media":
			tex = harvest_icon(plant_id) if not plant_id.is_empty() else seed_icon(plant_id)
		"bugs":
			tex = _load("res://assets/ui/icon_bugs.png")
			if tex == null:
				tex = _load("res://assets/portraits/bug_ladybug.png")
		_:
			tex = null
	_action_icon_cache[key] = tex
	return tex

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
	## Seed bag (col 1) — held chip / inventory. Native 16×32 pixel art.
	var mana := _mana_cell(plant_id, 1)
	if mana:
		return mana
	return _sprout_seed_icon(plant_id)

func shed_pick_icon(plant_id: String) -> Texture2D:
	## Prefer curated HD seed-bag tiles (assets/ui/seeds/<id>.png).
	var key := "shed_pick:%s" % plant_id
	if _action_icon_cache.has(key):
		return _action_icon_cache[key]
	var tile_path := "res://assets/ui/seeds/%s.png" % plant_id
	var tile := _load(tile_path)
	if tile:
		_action_icon_cache[key] = tile
		return tile
	## Fallback: nearest-upscale the Mana Seed bag crop (pack is 16×32 only).
	var sheet := _sheet_for(plant_id)
	if sheet == null:
		return seed_icon(plant_id)
	var src: Image = sheet.get_image()
	if src == null:
		return seed_icon(plant_id)
	var cell := src.get_region(Rect2i(1 * CELL_W, 0, CELL_W, CELL_H))
	var bb := cell.get_used_rect()
	if bb.size.x < 2 or bb.size.y < 2:
		bb = Rect2i(1, 16, 14, 16)
	var cropped := cell.get_region(bb)
	var long_edge := maxi(cropped.get_width(), cropped.get_height())
	var scale := maxi(10, int(round(160.0 / float(long_edge))))
	cropped.resize(cropped.get_width() * scale, cropped.get_height() * scale, Image.INTERPOLATE_NEAREST)
	var tex := ImageTexture.create_from_image(cropped)
	_action_icon_cache[key] = tex
	return tex

## Back-compat alias.
func seed_icon_ui(plant_id: String) -> Texture2D:
	return shed_pick_icon(plant_id)

func _sheet_for(plant_id: String) -> Texture2D:
	var sheet_name := sheet_name_for(plant_id)
	var sheet: Texture2D = _crop_sheets.get(sheet_name, null)
	if sheet == null:
		sheet = _load("%s/%s.png" % [MANA_CROPS, sheet_name])
		if sheet:
			_crop_sheets[sheet_name] = sheet
	return sheet

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

func seed_plot_texture(plant_id: String) -> Texture2D:
	## Seeds-on-ground art cropped to opaque bbox — true-center on each plot.
	## Full 16×32 Mana cells are mostly empty above the seeds; cropping keeps
	## the cluster optically centered (unlike foot-anchored plant packs).
	if plant_id.is_empty():
		return null
	if _seed_plot_cache.has(plant_id):
		return _seed_plot_cache[plant_id]
	var cell: Texture2D = plant_stage_texture(plant_id, "seed")
	if cell == null:
		_seed_plot_cache[plant_id] = null
		return null
	var img: Image = cell.get_image()
	if img == null:
		_seed_plot_cache[plant_id] = cell
		return cell
	var bb := img.get_used_rect()
	if bb.size.x < 2 or bb.size.y < 2:
		_seed_plot_cache[plant_id] = cell
		return cell
	var cropped := img.get_region(bb)
	var tex := ImageTexture.create_from_image(cropped)
	_seed_plot_cache[plant_id] = tex
	return tex

func bed_plant_pack_texture(plant_id: String, stage: String) -> Texture2D:
	## Baked four-plant pack (center = furrow cross). Null → PlantLayer composes.
	if stage == "seed" or plant_id.is_empty():
		return null
	var key := "%s:%s" % [plant_id, stage]
	if _bed_pack_cache.has(key):
		return _bed_pack_cache[key]
	var path := "res://assets/plants/bed_packs/%s_%s.png" % [plant_id, stage]
	var tex := _load(path)
	_bed_pack_cache[key] = tex
	return tex

func bed_pack_star_hover_y(stage: String, fallback: float = -48.0) -> float:
	## Y offset from furrow cross so the harvest star sits just above the pack.
	if _bed_pack_star_hover.is_empty():
		_load_bed_pack_offsets()
	if _bed_pack_star_hover.has(stage):
		return float(_bed_pack_star_hover[stage])
	return fallback

func _load_bed_pack_offsets() -> void:
	var path := "res://assets/plants/bed_packs/offsets.json"
	if not FileAccess.file_exists(path):
		return
	var raw := FileAccess.get_file_as_string(path)
	var data = JSON.parse_string(raw)
	if typeof(data) != TYPE_DICTIONARY:
		return
	var hover: Variant = data.get("star_hover_y", {})
	if typeof(hover) == TYPE_DICTIONARY:
		for k in hover.keys():
			_bed_pack_star_hover[str(k)] = float(hover[k])

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

func tree_texture(season_id: String, variant: String, wind_frame: int = 0) -> Texture2D:
	## Seasonal meadow trees — atlas rows = seasons, cols = variant×wind.
	if _tree_sheet == null:
		return null
	var row := TREE_SEASONS.find(season_id)
	if row < 0:
		row = TREE_SEASONS.find("summer")
	var vi := TREE_VARIANTS.find(variant)
	if vi < 0:
		vi = TREE_VARIANTS.find("med")
	if row < 0:
		row = 1
	if vi < 0:
		vi = 1
	var wf := clampi(wind_frame, 0, TREE_WIND_FRAMES - 1)
	var col := vi * TREE_WIND_FRAMES + wf
	return _atlas(_tree_sheet, Rect2(col * TREE_CELL_W, row * TREE_CELL_H, TREE_CELL_W, TREE_CELL_H))

func raindrop_texture() -> Texture2D:
	return _raindrop_tex

func leaf_particle_texture() -> Texture2D:
	return _leaf_particle_tex

func rain_splash_frames() -> Array:
	## Array[Texture2D] — expanding splash ring.
	var out: Array = []
	if _rain_splash_tex == null:
		return out
	for i in RAIN_SPLASH_FRAMES:
		out.append(_atlas(_rain_splash_tex, Rect2(i * RAIN_SPLASH_W, 0, RAIN_SPLASH_W, RAIN_SPLASH_H)))
	return out

func leaf_spin_frames() -> Array:
	## Array[Array[Texture2D]] — [color][spin frame].
	var out: Array = []
	if _leaf_spin_tex == null:
		return out
	for ci in LEAF_COLORS:
		var frames: Array = []
		for fi in LEAF_SPIN_FRAMES:
			frames.append(_atlas(_leaf_spin_tex, Rect2(fi * LEAF_CELL, ci * LEAF_CELL, LEAF_CELL, LEAF_CELL)))
		out.append(frames)
	return out

func leaf_land_frames() -> Array:
	## Array[Array[Texture2D]] — [color][land pose].
	var out: Array = []
	if _leaf_land_tex == null:
		return out
	for ci in LEAF_COLORS:
		var poses: Array = []
		for pi in LEAF_LAND_POSES:
			poses.append(_atlas(_leaf_land_tex, Rect2(pi * LEAF_CELL, ci * LEAF_CELL, LEAF_CELL, LEAF_CELL)))
		out.append(poses)
	return out

func _atlas(sheet: Texture2D, region: Rect2) -> AtlasTexture:
	var at := AtlasTexture.new()
	at.atlas = sheet
	at.region = region
	at.filter_clip = true
	return at

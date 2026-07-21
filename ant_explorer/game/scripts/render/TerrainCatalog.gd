class_name TerrainCatalog
extends RefCounted
## Sprout Lands floors from the pack's named Mid cutouts (Grass / Moss / Flowers /
## Sprouts) plus soil / stone / tilled mid-row crops. Each kind has a weighted
## variant pool so every cell can differ — never one stamp repeated.

const FILL_ROOT := "res://assets/tiles/sprout_lands/fills"
const TILE_SCALE := 4.0  ## chunkier pixels; reads more like the pack preview

var available: bool = false
var _by_kind: Dictionary = {}

func bootstrap() -> void:
	_by_kind.clear()

	# --- Outdoor grass: pack Mid band (plain → moss → sprouts → flowers) ---
	var outdoor: Array = []
	_w(outdoor, "sl_Mid.png", 3)
	_w(outdoor, "sl_Mid_Grass1.png", 4)
	_w(outdoor, "sl_Mid_Grass2.png", 4)
	_w(outdoor, "sl_mMid_Moss1.png", 3)
	_w(outdoor, "sl_Mid_Moss2.png", 3)
	_w(outdoor, "sl_Mid_Moss3.png", 2)
	_w(outdoor, "sl_Mid_Sprouts1.png", 2)
	_w(outdoor, "sl_Mid_Sprouts2.png", 2)
	_w(outdoor, "sl_Mid_Sprouts3.png", 1)
	_w(outdoor, "sl_Mid_Flowers1.png", 2)
	_w(outdoor, "sl_Mid_Flowers2.png", 2)

	# --- Nest soil ---
	var soil: Array = []
	for i in 6:
		_w(soil, "sl_soil_%d.png" % i, 1)

	# --- Stone floors (queen / outpost) ---
	var stone: Array = []
	for i in 6:
		_w(stone, "sl_stone_%d.png" % i, 1)

	# --- Garden: tilled dirt + a little moss/sprouts ---
	var garden: Array = []
	for i in 4:
		_w(garden, "sl_tilled_%d.png" % i, 3)
	_w(garden, "sl_mMid_Moss1.png", 1)
	_w(garden, "sl_Mid_Sprouts1.png", 1)

	# --- Darker explore / dump ---
	var explore: Array = []
	_w(explore, "sl_Mid_Moss2.png", 3)
	_w(explore, "sl_Mid_Moss3.png", 3)
	_w(explore, "sl_mMid_Moss1.png", 2)
	_w(explore, "sl_Mid_Grass1.png", 2)
	_w(explore, "sl_Mid_Sprouts2.png", 1)

	var dump: Array = []
	for i in 3:
		_w(dump, "sl_soil_%d.png" % i, 2)
	_w(dump, "soil_dark.png", 2)

	if outdoor.is_empty() and soil.is_empty():
		# Legacy numbered fills as last resort.
		_w(outdoor, "grass_0.png", 2)
		_w(outdoor, "grass_1.png", 2)
		_w(soil, "soil_0.png", 1)
		_w(soil, "soil_1.png", 1)

	available = not outdoor.is_empty() or not soil.is_empty()
	if not available:
		push_warning("TerrainCatalog: no Sprout Lands fills in %s" % FILL_ROOT)
		return

	_by_kind["outdoor"] = _entry(outdoor, Color.WHITE)
	_by_kind["hub"] = _entry(soil if not soil.is_empty() else outdoor, Color(1.03, 1.0, 0.96))
	_by_kind["garden"] = _entry(garden if not garden.is_empty() else soil, Color(0.98, 1.04, 0.94))
	_by_kind["nursery"] = _entry(soil if not soil.is_empty() else outdoor, Color(1.05, 1.02, 0.94))
	_by_kind["queen"] = _entry(stone if not stone.is_empty() else soil, Color.WHITE)
	_by_kind["dump"] = _entry(dump if not dump.is_empty() else soil, Color(0.94, 0.9, 0.86))
	_by_kind["defense"] = _entry(stone if not stone.is_empty() else soil, Color.WHITE)
	_by_kind["explore"] = _entry(explore if not explore.is_empty() else outdoor, Color(0.98, 1.02, 0.96))
	_by_kind["default"] = _entry(soil if not soil.is_empty() else outdoor, Color.WHITE)

	print("TerrainCatalog: outdoor=%d soil=%d stone=%d garden=%d variants" % [
		outdoor.size(), soil.size(), stone.size(), garden.size()])

func floor_for(kind: String) -> Dictionary:
	var k := kind if _by_kind.has(kind) else "default"
	return _by_kind.get(k, {"texture": null, "modulate": Color.WHITE, "tile_scale": TILE_SCALE, "variants": []})

func tunnel_color() -> Color:
	return Color(0.5, 0.37, 0.25, 1.0)

var _tunnel_soil_tex: Texture2D

## Tunnels use ONE uniform, seamless dark-brown soil tile (not a variant pool).
## The Sprout Lands soil cutouts carry an asymmetric pebble in a corner that looks
## wrong repeated across every corridor cell, so we generate a plain dug-earth
## texture instead — natural, symmetric, and tiles without seams.
func tunnel_floor() -> Dictionary:
	if _tunnel_soil_tex == null:
		_tunnel_soil_tex = _make_soil_texture()
	return {
		"texture": _tunnel_soil_tex,
		"modulate": Color.WHITE,
		"tile_scale": TILE_SCALE,
		"variants": [_tunnel_soil_tex],
	}

## Seamless 16×16 dark-brown soil. Variation is built from integer-harmonic
## sinusoids (exactly periodic over the tile, so left/right and top/bottom edges
## match) plus a faint deterministic grain — no single feature to repeat.
func _make_soil_texture() -> Texture2D:
	var size := 16
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var base := Color(0.50, 0.37, 0.25)  # tamped dug earth — reads against the darker void
	for y in size:
		for x in size:
			var u := float(x) / float(size) * TAU
			var v := float(y) / float(size) * TAU
			var n := sin(u + 1.7) * cos(v + 0.6)
			n += 0.5 * sin(2.0 * u + 4.2) * cos(3.0 * v + 2.1)
			n += 0.25 * sin(4.0 * u + 0.9) * cos(2.0 * v + 5.3)
			n *= 0.09  # gentle ±~0.16 shade swing
			var grain := (float(((x * 928371) ^ (y * 50331653)) & 255) / 255.0 - 0.5) * 0.05
			var shade := clampf(1.0 + n + grain, 0.78, 1.2)
			img.set_pixel(x, y, Color(base.r * shade, base.g * shade, base.b * shade))
	return ImageTexture.create_from_image(img)

func _entry(pool: Array, mod: Color) -> Dictionary:
	var tex: Texture2D = pool[0] as Texture2D if not pool.is_empty() else null
	return {
		"texture": tex,
		"modulate": mod,
		"tile_scale": TILE_SCALE,
		"variants": pool.duplicate(),
	}

func _w(pool: Array, name: String, weight: int) -> void:
	var tex := _fill(name)
	if tex == null or weight <= 0:
		return
	for _i in weight:
		pool.append(tex)

func _fill(name: String) -> Texture2D:
	var path := "%s/%s" % [FILL_ROOT, name]
	if not FileAccess.file_exists(path):
		return null
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	if img == null or img.get_width() < 1:
		return null
	return ImageTexture.create_from_image(img)

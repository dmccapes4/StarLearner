class_name SpriteCatalog
extends RefCounted
## Discovers mega_pack keyframes and maps castes → anim frame arrays.
## Falls back to empty arrays so AntView can keep capsules.
##
## On exported Android builds the raw `.png` files are absent — only
## `.png.import` / `.png.remap` + `.godot/imported/*.ctex` ship. Discovery
## therefore accepts `.png.import` names and loads the logical `.png` path
## (resolved via remap at runtime).

const KEYFRAMES := "res://assets/ants/mega_pack/keyframes"
const PROPS := "res://assets/ants/mega_pack/spriter_file_png_parts/props"

## caste -> { "idle": [Texture2D], "move": [...], "scale": float }
var _cache: Dictionary = {}
var available: bool = false

func bootstrap() -> void:
	_cache.clear()
	available = _dir_has_frames("leaf_cutter_ant")
	_cache[AntEnums.Caste.FORAGER] = _pack("leaf_cutter_ant", "leaf_cutter", 0.22)
	_cache[AntEnums.Caste.PLAYER] = _pack("leaf_cutter_ant", "leaf_cutter", 0.26)
	_cache[AntEnums.Caste.GARDENER] = _pack("black_ant", "black_ant", 0.18)
	_cache[AntEnums.Caste.NURSE] = _pack("black_ant", "black_ant", 0.17)
	_cache[AntEnums.Caste.SOLDIER] = _pack("army_ant_soldier_type_01", "army_ant_soldier_type_01", 0.24)
	_cache[AntEnums.Caste.QUEEN] = _pack("queen_ant_red", "red_queen", 0.32)
	_cache[AntEnums.Caste.INVADER] = _pack("fire_ant", "fire_ant", 0.22)
	# Brood from props (still images).
	# egg.png = round pearl (egg pile / carried eggs only).
	# larva_01/02 = segmented capsules — larvae stay warm/small; pupae use the
	# same art cooler+taller so they read as cocoons, not eggs.
	_cache[AntEnums.Caste.LARVA] = {
		"idle": _load_props(["larva_01.png", "larva_02.png"]),
		"move": [],
		"scale": 0.12,
	}
	_cache[AntEnums.Caste.PUPA] = {
		"idle": _load_props(["larva_01.png", "larva_02.png"]),
		"move": [],
		"scale": 0.18,
	}
	# Carry leaf forager / player variant
	_cache["forager_leaf"] = _pack("leaf_cutter_ant_with_leaf", "leaf_cutter_with_leaf", 0.22)

func frames_for(caste: int, carrying_leaf: bool = false) -> Dictionary:
	var leaf_caste := caste == AntEnums.Caste.FORAGER or caste == AntEnums.Caste.PLAYER
	if carrying_leaf and leaf_caste and _cache.has("forager_leaf"):
		return _cache["forager_leaf"]
	return _cache.get(caste, {"idle": [], "move": [], "scale": 0.2})

func has_art(caste: int) -> bool:
	var p: Dictionary = frames_for(caste)
	return (p.get("idle", []) as Array).size() > 0

func _pack(folder: String, prefix: String, scale: float) -> Dictionary:
	var idle := _load_anim(folder, prefix, "idle")
	if idle.is_empty():
		idle = _load_anim(folder, prefix, "base")
	var move := _load_anim(folder, prefix, "move")
	if move.is_empty():
		move = idle
	return {"idle": idle, "move": move, "scale": scale}

func _dir_has_frames(folder: String) -> bool:
	var path := "%s/%s" % [KEYFRAMES, folder]
	var da := DirAccess.open(path)
	if da != null:
		return true
	return DirAccess.open(KEYFRAMES) != null

func _load_anim(folder: String, prefix: String, anim: String) -> Array:
	var out: Array = []
	var dir_path := "%s/%s" % [KEYFRAMES, folder]
	var da := DirAccess.open(dir_path)
	if da == null:
		return _load_flat(prefix, anim)
	var names := _list_png_names(da, "_%s_" % anim)
	for n in names:
		var tex := _load_tex("%s/%s" % [dir_path, n])
		if tex:
			out.append(tex)
	if out.is_empty():
		return _load_flat(prefix, anim)
	return out

func _load_flat(prefix: String, anim: String) -> Array:
	var out: Array = []
	var da := DirAccess.open(KEYFRAMES)
	if da == null:
		return out
	var needle := "%s_%s" % [prefix, anim]
	var names := _list_png_names(da, needle)
	for n in names:
		var tex := _load_tex("%s/%s" % [KEYFRAMES, n])
		if tex:
			out.append(tex)
	return out

## Collect logical `*.png` names from a directory listing.
## Accepts `foo.png` (editor) and `foo.png.import` / `foo.png.remap` (export).
func _list_png_names(da: DirAccess, needle: String) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	var seen: Dictionary = {}
	da.list_dir_begin()
	var fn := da.get_next()
	while fn != "":
		if not da.current_is_dir():
			var logical := _logical_png_name(fn)
			if not logical.is_empty() and logical.find(needle) >= 0 and not seen.has(logical):
				seen[logical] = true
				names.append(logical)
		fn = da.get_next()
	da.list_dir_end()
	names.sort()
	return names

func _logical_png_name(fn: String) -> String:
	if fn.ends_with(".png"):
		return fn
	if fn.ends_with(".png.import"):
		return fn.substr(0, fn.length() - ".import".length())
	if fn.ends_with(".png.remap"):
		return fn.substr(0, fn.length() - ".remap".length())
	return ""

func _load_tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	# Export may only expose the remap sidecar; still try load().
	if ResourceLoader.exists(path + ".remap"):
		return load(path) as Texture2D
	return null

func _load_props(files: Array) -> Array:
	var out: Array = []
	for f in files:
		var path := "%s/%s" % [PROPS, f]
		var tex := _load_tex(path)
		if tex:
			out.append(tex)
	return out

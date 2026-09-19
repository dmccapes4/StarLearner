class_name ChromeIcons
extends RefCounted
## Painted chrome tiles for pre-readers (Back, Menu, Practice, Skip, Help).
## Prefer PNGs under res://images/ui/; Help also accepts the legacy help_tile path.

const SIZE := 256
const UI_DIR := "res://images/ui"

static var _cache: Dictionary = {}

static func texture(id: String) -> Texture2D:
	if _cache.has(id):
		return _cache[id] as Texture2D
	var path := _path_for(id)
	var tex := _load_path(path)
	if tex == null and id == "help":
		tex = _load_path("res://images/help_tile.png")
	if tex != null:
		_cache[id] = tex
	return tex

static func _path_for(id: String) -> String:
	return "%s/%s.png" % [UI_DIR, id]

static func _load_path(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if ResourceLoader.exists(path):
		var res: Resource = load(path)
		if res is Texture2D:
			return res as Texture2D
	if not FileAccess.file_exists(path):
		return null
	var abs_path := ProjectSettings.globalize_path(path)
	var img := Image.new()
	if img.load(abs_path) != OK:
		return null
	return ImageTexture.create_from_image(img)

## Style a flat icon Button with a painted tile (clears text).
static func apply_icon_button(btn: Button, id: String, side: float = 72.0) -> void:
	var tex := texture(id)
	btn.text = ""
	btn.flat = true
	btn.clip_contents = true
	btn.custom_minimum_size = Vector2(side, side)
	btn.size = Vector2(side, side)
	if tex != null:
		btn.icon = tex
		btn.expand_icon = true
	else:
		# Readable fallback if art is missing.
		btn.flat = false
		match id:
			"back":
				btn.text = "\u25C0"
			"menu":
				btn.text = "\u2630"
			"practice":
				btn.text = "\u25B6"
			"skip":
				btn.text = "\u23ED"
			"help":
				btn.text = "?"
			_:
				btn.text = id
		btn.add_theme_font_size_override("font_size", int(side * 0.45))

## Shared skip tile for tutorials / watch scenes (bottom-right, left of help).
static func make_skip_button(parent: Control, on_press: Callable, side: float = 64.0) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	apply_icon_button(b, "skip", side)
	b.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	b.position = Vector2(-92.0 - side - 12.0, -92.0)
	b.pressed.connect(on_press)
	parent.add_child(b)
	return b

## Gold outline used when a chrome tile is mentioned in the intro tour.
static func set_tour_outline(btn: Button, on: bool) -> void:
	if btn == null:
		return
	if on:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1, 1, 1, 0.06)
		sb.set_corner_radius_all(16)
		sb.set_border_width_all(5)
		sb.border_color = MathTheme.GOLD
		sb.shadow_color = Color(MathTheme.GOLD, 0.45)
		sb.shadow_size = 8
		for state in ["normal", "hover", "focus", "pressed"]:
			btn.add_theme_stylebox_override(state, sb)
	else:
		for state in ["normal", "hover", "focus", "pressed"]:
			btn.add_theme_stylebox_override(state, StyleBoxEmpty.new())

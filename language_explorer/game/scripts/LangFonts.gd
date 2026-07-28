class_name LangFonts
extends RefCounted
## Monospace letter fonts — equal width for sentence + letter wheel.

const REGULAR_PATH := "res://fonts/JetBrainsMono-Regular.ttf"
const BOLD_PATH := "res://fonts/JetBrainsMono-Bold.ttf"

static var _regular: FontFile
static var _bold: FontFile

static func _load_regular() -> FontFile:
	if _regular == null and ResourceLoader.exists(REGULAR_PATH):
		_regular = load(REGULAR_PATH) as FontFile
	return _regular

static func _load_bold() -> FontFile:
	if _bold == null and ResourceLoader.exists(BOLD_PATH):
		_bold = load(BOLD_PATH) as FontFile
	return _bold

static func mono(size: int) -> Font:
	var base := _load_regular()
	if base == null:
		return ThemeDB.fallback_font
	var f := FontVariation.new()
	f.base_font = base
	f.font_size = size
	return f

static func mono_bold(size: int) -> Font:
	var base := _load_bold()
	if base == null:
		return mono(size)
	var f := FontVariation.new()
	f.base_font = base
	f.font_size = size
	return f

static func apply_label(lbl: Label, size: int, bold: bool = false) -> void:
	lbl.add_theme_font_override("font", mono_bold(size) if bold else mono(size))
	lbl.add_theme_font_size_override("font_size", size)

static func apply_richtext(rtl: RichTextLabel, normal_size: int, bold_size: int) -> void:
	rtl.add_theme_font_override("normal_font", mono(normal_size))
	rtl.add_theme_font_override("bold_font", mono_bold(bold_size))
	rtl.add_theme_font_size_override("normal_font_size", normal_size)
	rtl.add_theme_font_size_override("bold_font_size", bold_size)

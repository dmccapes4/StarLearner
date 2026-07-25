class_name LangTheme
extends RefCounted
## Shared palette + tiny UI helpers so every Language Explorer screen looks
## consistent with the Math Explorer learning console.

const BG := Color(0.10, 0.12, 0.20)
const PANEL := Color(0.16, 0.19, 0.30)

const RED := Color(0.90, 0.30, 0.28)
const BLUE := Color(0.30, 0.55, 0.95)
const GREEN := Color(0.36, 0.78, 0.45)
const GREY := Color(0.60, 0.63, 0.72)
const GOLD := Color(1.00, 0.82, 0.30)

const TEXT := Color(0.96, 0.97, 1.00)
const TEXT_DIM := Color(0.72, 0.78, 0.92)

## Home mode tiles.
const MODES := {
	"read": {"label": "Read", "symbol": "Aa", "color": Color(0.30, 0.55, 0.95)},
	"write": {"label": "Write", "symbol": "A", "color": Color(1.00, 0.72, 0.28)},
}
const MODE_ORDER := ["read", "write"]

const LETTER_INPUT_SKETCH := "sketch"
const LETTER_INPUT_ALPHABET := "alphabet"
const LETTER_INPUT_DEFAULT := LETTER_INPUT_ALPHABET

static func rounded_box(fill: Color, radius: float = 12.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(int(radius))
	return sb

static func style_primary(b: Button) -> void:
	b.add_theme_color_override("font_color", Color(0.06, 0.06, 0.12))
	b.add_theme_color_override("font_hover_color", Color(0.06, 0.06, 0.12))
	b.add_theme_color_override("font_pressed_color", Color(0.06, 0.06, 0.12))
	var sb := StyleBoxFlat.new()
	sb.bg_color = GOLD
	sb.set_corner_radius_all(20)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 6
	var pressed := sb.duplicate() as StyleBoxFlat
	pressed.bg_color = GOLD.darkened(0.12)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("focus", sb)
	b.add_theme_stylebox_override("pressed", pressed)

static func style_secondary(b: Button) -> void:
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", TEXT)
	b.add_theme_color_override("font_pressed_color", TEXT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL
	sb.set_corner_radius_all(18)
	sb.set_border_width_all(2)
	sb.border_color = Color(1, 1, 1, 0.28)
	var pressed := sb.duplicate() as StyleBoxFlat
	pressed.bg_color = PANEL.lightened(0.06)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("focus", sb)
	b.add_theme_stylebox_override("pressed", pressed)

static func style_mode_tile(b: Button, color: Color, active: bool, tour: bool = false) -> void:
	b.add_theme_color_override("font_color", Color(1, 1, 1))
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	b.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
	var sb := StyleBoxFlat.new()
	sb.bg_color = color if (active or tour) else color.darkened(0.28)
	sb.set_corner_radius_all(28)
	if active or tour:
		sb.set_border_width_all(4)
		sb.border_color = GOLD
		sb.shadow_color = Color(GOLD, 0.45)
		sb.shadow_size = 10
	var pressed := sb.duplicate() as StyleBoxFlat
	pressed.bg_color = color.darkened(0.1)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("focus", sb)
	b.add_theme_stylebox_override("pressed", pressed)

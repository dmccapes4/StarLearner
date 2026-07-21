class_name MathTheme
extends RefCounted
## Shared palette + a couple of tiny UI helpers so every screen looks consistent.
## Counting cubes use a small, deliberate colour language:
##   • a group's base colour (red / blue / green / grey), then
##   • a highlight ring: GOLD while it is being counted, GREY for the "second"
##     group, each with a BRIGHT (current) and DULL (already-counted) shade.

const BG := Color(0.10, 0.12, 0.20)
const PANEL := Color(0.16, 0.19, 0.30)

const RED := Color(0.90, 0.30, 0.28)
const BLUE := Color(0.30, 0.55, 0.95)
const GREEN := Color(0.36, 0.78, 0.45)
const GREY := Color(0.60, 0.63, 0.72)
const GOLD := Color(1.00, 0.82, 0.30)

# Outline shades.
const OUT_GOLD_BRIGHT := Color(1.00, 0.86, 0.36)
const OUT_GOLD_DULL := Color(0.66, 0.55, 0.24)
const OUT_GREY_BRIGHT := Color(0.94, 0.96, 1.00)
const OUT_GREY_DULL := Color(0.46, 0.48, 0.56)
const OUT_NONE := Color(0, 0, 0, 0.18)

const TEXT := Color(0.96, 0.97, 1.00)
const TEXT_DIM := Color(0.72, 0.78, 0.92)

const OPS := {
	"add": {"label": "Addition", "symbol": "+", "color": Color(0.90, 0.30, 0.28)},
	"sub": {"label": "Subtraction", "symbol": "\u2212", "color": Color(0.30, 0.55, 0.95)},
	"mul": {"label": "Multiplication", "symbol": "\u00D7", "color": Color(0.36, 0.78, 0.45)},
	"div": {"label": "Division", "symbol": "\u00F7", "color": Color(1.00, 0.72, 0.28)},
}

const OP_ORDER := ["add", "sub", "mul", "div"]

static func rounded_box(fill: Color, radius: float = 12.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(int(radius))
	return sb

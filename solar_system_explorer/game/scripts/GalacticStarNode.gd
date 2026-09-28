class_name GalacticStarNode
extends Node2D
## A single arc star in the GalacticView — glowing dot with label and field ring.
## v0.0.4: receipt_flash() — expanding ring receipt when step advances (Stage 1 visual).

const STAR_COLORS := {
	"procyon":   Color(1.0, 0.95, 0.75),
	"sirius":    Color(0.75, 0.85, 1.0),
	"gomeisa":   Color(0.85, 0.90, 1.0),
	"pollux":    Color(1.0, 0.75, 0.45),
	"castor":    Color(0.95, 0.98, 1.0),
	"capella":   Color(1.0, 0.90, 0.60),
	"aldebaran": Color(1.0, 0.55, 0.30),
	"rigel":     Color(0.65, 0.78, 1.0),
	"m44":       Color(0.90, 0.95, 1.0),
}

var star_name: String = ""
var field_strength: float = 0.1

var _label: Label
var _base_radius: float = 6.0
var _color: Color = Color.WHITE
var _ring_phase: float = 0.0

## v0.0.4 receipt receipt — an expanding ring that fades after a step
var _receipt_active: bool = false
var _receipt_radius: float = 0.0
var _receipt_opacity: float = 0.0
var _receipt_n_score: float = 0.0

func _ready() -> void:
	_color = STAR_COLORS.get(star_name, Color.WHITE)
	_base_radius = 8.0 if star_name == "m44" else 5.0

	_label = Label.new()
	_label.text = star_name.capitalize() if star_name != "m44" else "M44 Beehive"
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_color", _color.lightened(0.2))
	_label.position = Vector2(_base_radius + 4, -10)
	add_child(_label)

## Called by GalacticView after each step — starts the receipt ring animation.
func receipt_flash(n_score: float) -> void:
	_receipt_active = true
	_receipt_radius = _base_radius * 1.2
	_receipt_n_score = n_score
	# opacity: clamped — high n_score = brighter receipt
	_receipt_opacity = clampf(0.15 + absf(n_score) * 0.5, 0.15, 0.9)

func _process(delta: float) -> void:
	_ring_phase += delta * (0.3 + field_strength * 1.8)
	if _receipt_active:
		# expand outward and fade — like the ripple rings in Stage 1
		_receipt_radius += delta * 80.0
		_receipt_opacity -= delta * 1.2
		if _receipt_opacity <= 0.0:
			_receipt_active = false
	queue_redraw()

func _draw() -> void:
	# v0.0.4 receipt ring — drawn FIRST (behind star)
	if _receipt_active and _receipt_opacity > 0.01:
		draw_circle(Vector2.ZERO, _receipt_radius,
			Color(_color.r, _color.g, _color.b, _receipt_opacity))
		# second ring slightly behind for depth
		if _receipt_radius > 20.0:
			draw_circle(Vector2.ZERO, _receipt_radius * 0.7,
				Color(_color.r, _color.g, _color.b, _receipt_opacity * 0.4))

	# Outer glow ring (field strength / always-on)
	var ring_r := _base_radius * (1.5 + 0.8 * sin(_ring_phase) * field_strength)
	var ring_opacity := 0.08 + field_strength * 0.30
	draw_circle(Vector2.ZERO, ring_r, Color(_color.r, _color.g, _color.b, ring_opacity))

	# Second ring for high-field stars (field > 0.6 = within ~40pc)
	if field_strength > 0.6:
		var r2 := _base_radius * (1.1 + 0.4 * sin(_ring_phase * 1.3 + 1.0))
		draw_circle(Vector2.ZERO, r2,
			Color(_color.r, _color.g, _color.b, (field_strength - 0.6) * 0.35))

	# Core dot
	var core_r := _base_radius * (0.7 + field_strength * 0.5)
	draw_circle(Vector2.ZERO, core_r, _color)

	# Inner bright spot
	draw_circle(Vector2.ZERO, core_r * 0.40, Color.WHITE.lerp(_color, 0.25))

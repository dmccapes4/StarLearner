class_name GalacticStarNode
extends Node2D
## A single arc star in the GalacticView — glowing dot with label and field ring.
## Position is set externally from the galactic_journey.jsonl data.

const STAR_COLORS := {
	"procyon":   Color(1.0, 0.95, 0.75),   # warm yellow-white
	"sirius":    Color(0.75, 0.85, 1.0),   # blue-white
	"gomeisa":   Color(0.85, 0.90, 1.0),
	"pollux":    Color(1.0, 0.75, 0.45),   # orange
	"castor":    Color(0.95, 0.98, 1.0),
	"capella":   Color(1.0, 0.90, 0.60),
	"aldebaran": Color(1.0, 0.55, 0.30),   # red-orange giant
	"rigel":     Color(0.65, 0.78, 1.0),   # blue supergiant
	"m44":       Color(0.90, 0.95, 1.0),   # cluster — diffuse
}

var star_name: String = ""
var field_strength: float = 0.1   ## ∈ [0,1] — drives ring radius

var _label: Label
var _base_radius: float = 6.0
var _color: Color = Color.WHITE
var _ring_phase: float = 0.0

func _ready() -> void:
	_color = STAR_COLORS.get(star_name, Color.WHITE)
	_base_radius = 8.0 if star_name == "m44" else 5.0

	_label = Label.new()
	_label.text = star_name.capitalize() if star_name != "m44" else "M44 Beehive"
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_color", _color.lightened(0.2))
	_label.position = Vector2(_base_radius + 4, -10)
	add_child(_label)

func _process(delta: float) -> void:
	# v0.0.3: ring pulse rate reflects galactic field mirror value.
	# Nearby stars (field≈0.9) pulse fast. Distant stars (Rigel field≈0.2) pulse slowly.
	# This is the mirror: the ring tells you the star's galactic field influence honestly.
	_ring_phase += delta * (0.3 + field_strength * 1.8)
	queue_redraw()

func _draw() -> void:
	# v0.0.3: outer ring radius and opacity scale with field_strength
	# Distant stars (Rigel, M44) have smaller, dimmer rings — honest
	var ring_r := _base_radius * (1.5 + 0.8 * sin(_ring_phase) * field_strength)
	var ring_opacity := 0.08 + field_strength * 0.30
	var ring_col := Color(_color.r, _color.g, _color.b, ring_opacity)
	draw_circle(Vector2.ZERO, ring_r, ring_col)

	# Second ring for high-field stars (field > 0.6 = within ~40pc)
	if field_strength > 0.6:
		var r2 := _base_radius * (1.1 + 0.4 * sin(_ring_phase * 1.3 + 1.0))
		draw_circle(Vector2.ZERO, r2,
			Color(_color.r, _color.g, _color.b, (field_strength - 0.6) * 0.35))

	# Core dot — size reflects field (nearer = slightly larger apparent disk)
	var core_r := _base_radius * (0.7 + field_strength * 0.5)
	draw_circle(Vector2.ZERO, core_r, _color)

	# Inner bright spot
	draw_circle(Vector2.ZERO, core_r * 0.40, Color.WHITE.lerp(_color, 0.25))

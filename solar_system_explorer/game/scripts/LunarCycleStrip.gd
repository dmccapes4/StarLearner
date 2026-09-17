class_name LunarCycleStrip
extends Control
## LunarCycleExposure, drawn as a strip of phases.
##
## WHY THIS IS A CHART AND NOT PART OF THE SKY
##
## RetrogradeExposure works in the sky because a retrograde loop is small: Mars
## sweeps a few degrees over months, so a whole loop fits in one field of view
## and the exposure trail can be plotted at each sample's TRUE position.
##
## A lunar cycle cannot be drawn that way and it is worth being exact about why.
## The Moon moves about 13 degrees a night. Over the 35-day buffer the spec asks
## for it travels the entire sky, more than once round. No field of view holds
## that, and no amount of cleverness changes it -- the positions are simply not
## simultaneously visible from one place at one time. Meanwhile the Moon's disc
## is half a degree, so a field wide enough to show much of the track renders
## the phase, which is the actual subject, as a dot.
##
## So the sky keeps the true track (the handful of nights that genuinely fit in
## frame) and the cycle is presented here, deliberately AS A CHART: evenly
## spaced, clearly chrome, no pretence of being a view out of a window. What is
## real in it is every phase and every weight -- each disc is the Moon's true
## illuminated fraction on that date, with the true lit limb orientation, faded
## by the same logistic buffer decay the retrograde trail uses.
##
## The one thing this does that the sky cannot: it shows the whole cycle at once,
## which is the only way to see that the phase sequence and the Moon's position
## relative to the Sun are the same fact.

const EphemerisScript := preload("res://scripts/Ephemeris.gd")
const ExposureScript := preload("res://scripts/Exposure.gd")

## Discs across the strip. One per night of a synodic month is too many to read
## at this size; every other night is plenty to show the progression.
const DISCS := 15
const DISC_R := 13.0
const GAP := 6.0

const LIT := Color(0.94, 0.94, 0.88)
const DARK := Color(0.10, 0.12, 0.17)
const RIM := Color(0.45, 0.52, 0.66, 0.55)

var _jd: float = EphemerisScript.J2000_JD
var _phases: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(
		DISCS * (DISC_R * 2.0 + GAP), DISC_R * 2.0 + 26.0)

## Recompute the strip for an instant. Cheap enough to call on a clock change,
## not something to do every frame.
func set_time(jd: float) -> void:
	_jd = jd
	_phases.clear()
	var span: float = ExposureScript.lunar_schedule_days()
	for i in DISCS:
		# i = 0 is the oldest sample, the last is now, so the strip reads
		# left to right like everything else.
		var u: float = 1.0 - float(i) / float(DISCS - 1)
		var t: float = jd - u * span
		_phases.append({
			"lit": EphemerisScript.moon_illumination(t),
			"waxing": EphemerisScript.moon_waxing(t),
			"w": ExposureScript.weight_at(u),
		})
	queue_redraw()

func _draw() -> void:
	if _phases.is_empty():
		return
	var step: float = DISC_R * 2.0 + GAP
	for i in _phases.size():
		var p: Dictionary = _phases[i]
		var c := Vector2(DISC_R + float(i) * step, DISC_R + 4.0)
		var w: float = float(p["w"])
		# Same decay as the sky trail, so the chart and the sky agree about
		# what "35 nights ago" is worth.
		var a: float = clampf(0.18 + 0.82 * w, 0.0, 1.0)
		draw_circle(c, DISC_R, Color(DARK.r, DARK.g, DARK.b, a * 0.9))
		_draw_phase(c, DISC_R, float(p["lit"]), bool(p["waxing"]), a)
		draw_arc(c, DISC_R, 0.0, TAU, 24, Color(RIM.r, RIM.g, RIM.b,
			RIM.a * a), 1.0)

## Fill the lit part of a phase. The terminator on a sphere seen from a distance
## projects to a half-ellipse whose width is the cosine of the phase angle, so
## the lit region is bounded by a semicircle on the sunward side and that
## ellipse on the other. Getting this from the illuminated FRACTION rather than
## drawing a fudged crescent is what makes a gibbous moon look gibbous.
func _draw_phase(c: Vector2, r: float, lit_frac: float, waxing: bool,
		alpha: float) -> void:
	var f: float = clampf(lit_frac, 0.0, 1.0)
	if f <= 0.005:
		return
	var col := Color(LIT.r, LIT.g, LIT.b, alpha)
	if f >= 0.995:
		draw_circle(c, r, col)
		return
	# Illuminated fraction f = (1 - cos(phase_angle)) / 2 for a sphere, so the
	# terminator's projected semi-width is |1 - 2f|, signed: positive when the
	# ellipse bulges away from the lit limb (gibbous), negative for a crescent.
	var k: float = 1.0 - 2.0 * f
	# Sun on the right while waxing, in the northern-hemisphere convention the
	# strip is drawn for.
	var side: float = 1.0 if waxing else -1.0
	var pts := PackedVector2Array()
	var steps: int = 26
	# Lit limb: the half of the rim on the sunward side, top to bottom.
	for i in steps + 1:
		var th: float = -PI * 0.5 + PI * float(i) / float(steps)
		pts.append(c + Vector2(side * r * cos(th), r * sin(th)))
	# Terminator: back up the ellipse, bottom to top.
	for i in steps + 1:
		var th: float = PI * 0.5 - PI * float(i) / float(steps)
		pts.append(c + Vector2(side * k * r * cos(th), r * sin(th)))
	draw_colored_polygon(pts, col)

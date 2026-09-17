class_name SolarBrilliance
extends RefCounted
## Brightness of a naked-eye body from reflected sunlight.
##
## Every planet in the sky is a mirror: it emits nothing, it returns sunlight.
## So how bright it looks is set by four things multiplied together -- how much
## light reaches it (inverse square of its distance from the Sun), how big a
## mirror it is (radius squared), how good a mirror it is (albedo), and how
## much of the lit face is turned toward us (the phase). Then the light spreads
## out again on the way here (inverse square of its distance from Earth).
##
## Rather than invent a brightness curve, this computes a real apparent
## magnitude the way an ephemeris does:
##
##     m = V(1,0) + 5 log10(d_sun * d_earth) + dm_phase(alpha)
##
## V(1,0) is the body's absolute magnitude -- what it would look like at 1 AU
## from the Sun, 1 AU from Earth, fully lit. dm_phase is the empirical phase
## law from the Astronomical Almanac (Meeus ch. 41), which matters enormously
## for Venus: at greatest brilliance Venus is a fat crescent only 27% lit, yet
## it is the brightest thing in the sky after the Sun and Moon, because it is
## also close. A naive Lambert-sphere phase law gets that wrong by ~0.9 mag;
## these laws get it right to about a tenth of a magnitude.
##
## Verified against published extremes in tools/ephemeris_check.gd:
##   Venus greatest brilliance  -4.6      Jupiter at opposition   -2.7
##   Mars perihelic opposition  -2.9      full Moon              -12.7
##
## The second half of the file maps magnitude to pixels. That mapping is
## perceptual, not physical: real flux spans 25 magnitudes, a ratio of ten
## billion, and no screen can show that. So brightness is compressed
## logarithmically, which is also roughly how the eye responds.

## Preloaded rather than reached by class_name so headless runs see the fresh
## class before the editor rescans its global class cache (same reason as the
## preload block in Main.gd).
const Ephemeris := preload("res://scripts/Ephemeris.gd")

## Absolute magnitude V(1,0): magnitude at 1 AU from Sun and Earth, fully lit.
## Keys are literal body ids so this stays a constant expression.
const ABS_MAG: Dictionary = {
	"mercury": -0.60,
	"venus": -4.40,
	"earth": -3.99,
	"mars": -1.52,
	"jupiter": -9.40,
	"moon": 0.21,
}

## Apparent magnitude of the Sun at 1 AU.
const SUN_MAG_AT_1AU := -26.74
## Faintest star a person can see from a dark site.
const NAKED_EYE_LIMIT := 6.0
## Magnitude that renders at full brightness -- Venus at her best.
const MAG_FULL_BRIGHT := -4.9

## Phase correction in magnitudes for phase angle `alpha_deg`. Positive makes
## the body fainter. Empirical fits; each is valid over the phase range that
## body can actually present to Earth.
static func phase_correction_mag(body_id: String, alpha_deg: float) -> float:
	var a: float = clampf(alpha_deg, 0.0, 180.0)
	match body_id:
		Ephemeris.MERCURY:
			return 0.0380 * a - 0.000273 * a * a + 0.000002 * a * a * a
		Ephemeris.VENUS:
			# Beyond 163 deg Venus is a thread against the Sun's glare and the
			# fit diverges; clamp to the far end of its valid range.
			var v: float = minf(a, 163.0)
			return 0.0009 * v + 0.000239 * v * v - 0.00000065 * v * v * v
		Ephemeris.MARS:
			return 0.016 * a
		Ephemeris.JUPITER:
			return 0.005 * a
		Ephemeris.MOON:
			# The Moon brightens sharply right at full (opposition surge from
			# a rough, back-scattering surface), so a linear law will not do.
			#
			# The quartic is fitted over roughly 0-150 degrees, so it is clamped
			# there rather than extrapolated.
			#
			# Do not expect the clamp to make a new moon come out faint: it
			# cannot. The distance term alone is about -13 magnitudes, and no
			# phase correction of this shape offsets that, so the formula says
			# roughly -6 whatever is done at the top end. That is not a bug in
			# the clamp, it is the model reaching a place where a single
			# magnitude is the wrong answer -- at zero illumination no light
			# reaches us at all and the quantity is undefined.
			#
			# So the magnitude is left alone and the two things that actually
			# matter are handled where they belong: the rendered glare is scaled
			# by illuminated fraction (EarthSkyViewer._glow_colour), so an unlit
			# Moon throws none, and the readout stops quoting a number near new
			# (EarthSkyViewer.magnitude_text).
			var mo: float = minf(a, 150.0)
			return 0.026 * mo + 4.0e-9 * pow(mo, 4.0)
		_:
			return 0.0

## Apparent magnitude as seen from Earth. Lower is brighter.
static func apparent_magnitude(body_id: String, jd: float) -> float:
	var d_earth: float = Ephemeris.earth_distance_au(body_id, jd)
	if body_id == Ephemeris.SUN:
		return SUN_MAG_AT_1AU + 5.0 * log_10(maxf(d_earth, 1.0e-6))
	var d_sun: float = Ephemeris.sun_distance_au(body_id, jd)
	if d_earth <= 0.0 or d_sun <= 0.0:
		return NAKED_EYE_LIMIT
	var base: float = float(ABS_MAG.get(body_id, 0.0))
	var alpha: float = rad_to_deg(Ephemeris.phase_angle_rad(body_id, jd))
	return base + 5.0 * log_10(d_sun * d_earth) \
		+ phase_correction_mag(body_id, alpha)

static func log_10(x: float) -> float:
	return log(maxf(x, 1.0e-30)) / log(10.0)

## Reflected flux relative to the same body fully lit at 1 AU / 1 AU. Purely
## geometric and monotonic -- handy when a shader wants a linear quantity
## instead of a magnitude.
static func relative_flux(body_id: String, jd: float) -> float:
	var d_earth: float = Ephemeris.earth_distance_au(body_id, jd)
	var d_sun: float = Ephemeris.sun_distance_au(body_id, jd)
	if d_earth <= 0.0 or d_sun <= 0.0:
		return 0.0
	var f: float = Ephemeris.illuminated_fraction(body_id, jd) \
		* Ephemeris.albedo(body_id)
	return f / (d_sun * d_sun * d_earth * d_earth)

# ── Magnitude to pixels ─────────────────────────────────────────────

## Perceptual brightness 0..1 from an apparent magnitude. Venus at her best
## and anything brighter saturate at 1.0; the naked-eye limit lands on 0.0.
static func brightness01(mag: float) -> float:
	var span: float = NAKED_EYE_LIMIT - MAG_FULL_BRIGHT
	var u: float = (NAKED_EYE_LIMIT - mag) / maxf(span, 0.001)
	return pow(clampf(u, 0.0, 1.0), 0.85)

## Brightness 0..1 for a body at a moment.
static func brightness_of(body_id: String, jd: float) -> float:
	return brightness01(apparent_magnitude(body_id, jd))

## Radius in pixels of the glow a bright point throws. A planet's true disk is
## far under a pixel from Earth (Jupiter at opposition is 47 arcseconds, about
## a fiftieth of a degree), so what the eye actually registers is scatter in
## the atmosphere and in the eye itself. That halo is the reason Venus looks
## "big" -- so it is rendered, and it is driven by brightness, not by size.
static func glow_radius_px(mag: float, base_px: float = 3.0) -> float:
	var b: float = brightness01(mag)
	return base_px * (0.55 + 3.1 * b * b)

## Direction from a body toward the Sun, in the star-sphere frame. Feeds the
## lit-limb shading so a crescent points the right way.
static func sun_dir_from(body_id: String, jd: float) -> Vector3:
	var to_sun: Vector3
	if body_id == Ephemeris.MOON:
		to_sun = -Ephemeris.heliocentric_ecliptic_au(Ephemeris.EARTH, jd) \
			- Ephemeris.geocentric_ecliptic_au(Ephemeris.MOON, jd)
	else:
		to_sun = -Ephemeris.heliocentric_ecliptic_au(body_id, jd)
	if to_sun.length() < 1.0e-12:
		return Vector3.FORWARD
	return Ephemeris.godot_dir_from_ecliptic(to_sun)

## Magnitude readout for the HUD, with the sign convention spelled out for a
## reader who has never met astronomical magnitudes.
static func magnitude_label(mag: float) -> String:
	return "magnitude %+.1f  (lower is brighter)" % mag

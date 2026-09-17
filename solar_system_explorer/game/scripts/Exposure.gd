class_name Exposure
extends RefCounted
## Logistic buffer decay -- the shared curve behind RetrogradeExposure and
## LunarCycleExposure.
##
## The effect is a long-exposure photograph of the sky: the selected body
## leaves a tail of where it has been, so an apparent retrograde loop is
## visible as a shape rather than only as motion you have to sit and watch.
##
## The curve is a reversed logistic in normalised age u = age / schedule:
##
##     raw(u) = 1 / (1 + exp(STEEPNESS * (u - MIDPOINT)))
##
## which gives a slow, nearly linear decline while u is small, then a knee,
## then a steep drop, then a long flat asymptote toward zero. The flat tail
## is worthless -- it is a smear of nearly invisible samples that costs draw
## calls and muddies the loop -- so the buffer is CUT OFF at u = 1, which sits
## on the steep part just before the curve flattens. Rescaling by the value at
## the cutoff makes the weight reach exactly zero there, so the tail ends
## cleanly instead of fading into a permanent haze:
##
##     weight(u) = (raw(u) - raw(1)) / (raw(0) - raw(1))
##
## Schedules are 1.2x the natural period of the thing being shown, so the
## buffer always holds slightly more than one full cycle. That 0.2 of overlap
## is what makes the loop close visibly: the head of the tail reaches back
## past the previous station, so the crossing point is on screen.
##
## Because the ephemeris is closed-form, the tail is COMPUTED rather than
## accumulated -- there is no history buffer to fill. That means it is exact
## on the first frame, survives scrubbing the clock forward or backward, and
## never shows a partially grown trail after a jump in time.

## Preloaded rather than reached by class_name so headless runs see the fresh
## class before the editor rescans its global class cache.
const Ephemeris := preload("res://scripts/Ephemeris.gd")

const STEEPNESS := 9.0
const MIDPOINT := 0.72
## Buffer spans 1.2 cycles, so slightly more than one full loop is held.
const SCHEDULE_MULTIPLIER := 1.2
## Default tail resolution. Enough to read a smooth loop at any field of view
## without becoming a per-frame cost problem on a Moto G.
const DEFAULT_SAMPLES := 132

## Raw reversed logistic, before cutoff rescaling.
static func raw_weight(u: float) -> float:
	return 1.0 / (1.0 + exp(STEEPNESS * (u - MIDPOINT)))

## Exposure weight for a sample of normalised age `u`. 1.0 at the head of the
## tail, exactly 0.0 at and beyond the cutoff.
static func weight_at(u: float) -> float:
	if u <= 0.0:
		return 1.0
	if u >= 1.0:
		return 0.0
	var lo: float = raw_weight(1.0)
	var hi: float = raw_weight(0.0)
	return clampf((raw_weight(u) - lo) / maxf(hi - lo, 1.0e-9), 0.0, 1.0)

## Exposure weight from an absolute age in days.
static func weight(age_days: float, schedule_days: float) -> float:
	if schedule_days <= 0.0:
		return 0.0
	return weight_at(age_days / schedule_days)

## Age, in normalised units, at which the weight first falls below `level`.
## Used by tests to assert the shape of the curve rather than its constants.
static func age_at_weight(level: float) -> float:
	var target: float = clampf(level, 0.0, 1.0)
	var lo: float = 0.0
	var hi: float = 1.0
	for _i in 60:
		var mid: float = (lo + hi) * 0.5
		if weight_at(mid) > target:
			lo = mid
		else:
			hi = mid
	return (lo + hi) * 0.5

# ── Schedules ───────────────────────────────────────────────────────

## RetrogradeExposure: 1.2x the body's mean retrograde period.
static func retrograde_schedule_days(body_id: String) -> float:
	var rx: float = Ephemeris.retrograde_days(body_id)
	if rx <= 0.0:
		# Sun and Moon never retrograde; fall back to the lunar schedule so a
		# tail still exists rather than vanishing.
		return lunar_schedule_days()
	return rx * SCHEDULE_MULTIPLIER

## LunarCycleExposure: 1.2x one synodic month.
static func lunar_schedule_days() -> float:
	return Ephemeris.SYNODIC_MONTH_DAYS * SCHEDULE_MULTIPLIER

## The schedule EarthShip uses for a given body: the lunar cycle for the Sun
## and Moon, the retrograde period for a planet.
static func schedule_days(body_id: String) -> float:
	if body_id == Ephemeris.MOON or body_id == Ephemeris.SUN:
		return lunar_schedule_days()
	return retrograde_schedule_days(body_id)

# ── Tail sampling ───────────────────────────────────────────────────

## Sample the exposure tail for `body_id` ending at `jd_now`.
##
## Returns newest-first, each entry:
##   dir        unit direction from the observer, star-sphere frame
##   weight     exposure weight, 1.0 at the head and 0.0 at the cutoff
##   jd         Julian Day of the sample
##   retrograde whether the body was moving retrograde at that sample
##
## `lat_deg`/`lon_deg` drive the topocentric correction, which only matters
## for the Moon but is applied uniformly so one code path serves both viewers.
static func sample_tail(body_id: String, jd_now: float,
		lat_deg: float = 0.0, lon_deg: float = 0.0,
		samples: int = DEFAULT_SAMPLES) -> Array:
	var out: Array = []
	var span: float = schedule_days(body_id)
	var n: int = maxi(samples, 2)
	for i in n:
		var u: float = float(i) / float(n - 1)
		var w: float = weight_at(u)
		if w <= 0.0:
			continue
		var jd: float = jd_now - u * span
		out.append({
			"dir": observed_dir(body_id, jd, lat_deg, lon_deg),
			"weight": w,
			"jd": jd,
			"retrograde": Ephemeris.is_retrograde(body_id, jd),
		})
	return out

## Unit direction to a body for an observer on Earth's surface, in the same
## frame as the star sphere. Topocentric, so the Moon sits where it really
## looks from that latitude rather than from Earth's centre.
static func observed_dir(body_id: String, jd: float, lat_deg: float,
		lon_deg: float) -> Vector3:
	var t: float = Ephemeris.centuries_since_j2000(jd)
	var eq: Vector3 = Ephemeris.ecliptic_to_equatorial(
		Ephemeris.geocentric_ecliptic_au(body_id, jd), t)
	eq -= Ephemeris.observer_offset_au(jd, lat_deg, lon_deg)
	return Ephemeris.godot_dir_from_ecliptic(
		Ephemeris.equatorial_to_ecliptic(eq, t))

## Fraction of the sampled tail that was retrograde -- drives the HUD readout
## and lets the tail be tinted where the motion reversed.
static func retrograde_fraction(tail: Array) -> float:
	if tail.is_empty():
		return 0.0
	var n: int = 0
	for s in tail:
		if bool(s.get("retrograde", false)):
			n += 1
	return float(n) / float(tail.size())

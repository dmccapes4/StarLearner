class_name Ephemeris
extends RefCounted
## Real Keplerian ephemeris for the naked-eye inner system.
##
## Why this exists: the Free Flight orrery moves every body on a perfect
## circle in the XZ plane (OrbitMath.body_pos) with a cosmetic start angle
## (theta0 = orbit_index * 0.7) and a clock that is just seconds since the
## scene opened. That is fine for flying between worlds, but it cannot show
## retrograde honestly, for two reasons:
##
##   1. Every orbit has inclination 0, so Earth, the target and the Sun are
##      exactly coplanar and an apparent path can only run back and forth
##      along a line. The retrograde LOOP is produced by orbital inclination.
##   2. There is no epoch, so "start from year N" has no meaning.
##
## So EarthShip mode runs on this instead: J2000 Keplerian elements with
## secular rates, solved per frame, in real AU. Nothing here is compressed
## and nothing is faked.
##
## Source of the planetary elements: E. M. Standish, "Keplerian Elements for
## Approximate Positions of the Major Planets" (JPL Solar System Dynamics).
## Valid 1800-2050 AD with errors well under an arcminute in longitude, which
## is far finer than a pixel at any field of view we render.
##
## The Moon uses the abbreviated lunar theory from Meeus, "Astronomical
## Algorithms" ch. 47 (principal terms only). That is good to roughly 10
## arcminutes in longitude -- about a third of a lunar diameter. Honest limit:
## enough to show phase, the synodic month, and why eclipse season happens,
## NOT enough to predict whether a given eclipse is total from a given town.
##
## Deliberately excluded: light-time, aberration, nutation, and topocentric
## parallax for the planets (all far below a pixel here). Lunar parallax IS
## included, because at 60 Earth radii it moves the Moon by up to a degree.

const SUN := "sun"
const MERCURY := "mercury"
const VENUS := "venus"
const EARTH := "earth"
const MARS := "mars"
const JUPITER := "jupiter"
const MOON := "moon"

## The naked-eye set EarthShip mode simulates: everything a person can see
## without a telescope by reflected or emitted sunlight.
const NAKED_EYE: Array = [SUN, MERCURY, VENUS, MARS, JUPITER, MOON]
## Bodies with Keplerian elements below (the Moon is handled separately).
const PLANETS: Array = [MERCURY, VENUS, EARTH, MARS, JUPITER]

const J2000_JD := 2451545.0
const DAYS_PER_CENTURY := 36525.0
const KM_PER_AU := 1.495978707e8
const EARTH_RADIUS_KM := 6378.137
## Mean synodic month, days -- the lunar cycle LunarCycleExposure schedules on.
const SYNODIC_MONTH_DAYS := 29.530588

## Keplerian elements at J2000 and their rates per Julian century.
##   a      semi-major axis, AU              (rate AU/cy)
##   e      eccentricity                      (rate /cy)
##   i      inclination to the ecliptic, deg  (rate deg/cy)
##   l      mean longitude, deg               (rate deg/cy)
##   peri   longitude of perihelion, deg      (rate deg/cy)
##   node   longitude of ascending node, deg  (rate deg/cy)
## Earth is the Earth-Moon barycentre, which is what the source tabulates.
const ELEMENTS: Dictionary = {
	MERCURY: {
		"a": 0.38709927, "a_dot": 0.00000037,
		"e": 0.20563593, "e_dot": 0.00001906,
		"i": 7.00497902, "i_dot": -0.00594749,
		"l": 252.25032350, "l_dot": 149472.67411175,
		"peri": 77.45779628, "peri_dot": 0.16047689,
		"node": 48.33076593, "node_dot": -0.12534081,
	},
	VENUS: {
		"a": 0.72333566, "a_dot": 0.00000390,
		"e": 0.00677672, "e_dot": -0.00004107,
		"i": 3.39467605, "i_dot": -0.00078890,
		"l": 181.97909950, "l_dot": 58517.81538729,
		"peri": 131.60246718, "peri_dot": 0.00268329,
		"node": 76.67984255, "node_dot": -0.27769418,
	},
	EARTH: {
		"a": 1.00000261, "a_dot": 0.00000562,
		"e": 0.01671123, "e_dot": -0.00004392,
		"i": -0.00001531, "i_dot": -0.01294668,
		"l": 100.46457166, "l_dot": 35999.37244981,
		"peri": 102.93768193, "peri_dot": 0.32327364,
		"node": 0.0, "node_dot": 0.0,
	},
	MARS: {
		"a": 1.52371034, "a_dot": 0.00001847,
		"e": 0.09339410, "e_dot": 0.00007882,
		"i": 1.84969142, "i_dot": -0.00813131,
		"l": -4.55343205, "l_dot": 19140.30268499,
		"peri": -23.94362959, "peri_dot": 0.44441088,
		"node": 49.55953891, "node_dot": -0.29257343,
	},
	JUPITER: {
		"a": 5.20288700, "a_dot": -0.00011607,
		"e": 0.04838624, "e_dot": -0.00013253,
		"i": 1.30439695, "i_dot": -0.00183714,
		"l": 34.39644051, "l_dot": 3034.74612775,
		"peri": 14.72847983, "peri_dot": 0.21252668,
		"node": 100.47390909, "node_dot": 0.20469106,
	},
}

## Mean radius in km and geometric albedo, for true angular size and for
## reflected-sunlight brightness (SolarBrilliance).
const PHYSICAL: Dictionary = {
	SUN: {"radius_km": 695700.0, "albedo": 1.0},
	MERCURY: {"radius_km": 2439.7, "albedo": 0.142},
	VENUS: {"radius_km": 6051.8, "albedo": 0.689},
	EARTH: {"radius_km": 6371.0, "albedo": 0.434},
	MARS: {"radius_km": 3389.5, "albedo": 0.170},
	JUPITER: {"radius_km": 69911.0, "albedo": 0.538},
	MOON: {"radius_km": 1737.4, "albedo": 0.136},
}

## Sidereal orbital period in Julian years, used for synodic / retrograde
## cadence. Derived from the mean longitude rate so it always agrees with
## the elements above.
static func period_yr(body_id: String) -> float:
	if not ELEMENTS.has(body_id):
		return 0.0
	var rate: float = float(ELEMENTS[body_id]["l_dot"])
	if absf(rate) < 0.000001:
		return 0.0
	return 360.0 / (rate / 100.0)

## Earth-relative synodic period in years: how long between one opposition
## (or inferior conjunction) and the next. A planet goes retrograde exactly
## once per synodic period, so this is the natural exposure schedule.
static func synodic_yr(body_id: String) -> float:
	var p: float = period_yr(body_id)
	var e: float = period_yr(EARTH)
	if p <= 0.0 or e <= 0.0 or is_equal_approx(p, e):
		return 0.0
	return absf(1.0 / (1.0 / e - 1.0 / p))

## Mean duration of one retrograde loop in days. Empirical fractions of the
## synodic period, from the standard apparition tables -- an inner planet
## spends a smaller share of its cycle retrograde than an outer one.
const RETRO_FRACTION: Dictionary = {
	MERCURY: 0.183,   # ~21 d of a 116 d cycle
	VENUS: 0.073,     # ~42 d of a 584 d cycle
	MARS: 0.096,      # ~72 d of a 780 d cycle
	JUPITER: 0.303,   # ~121 d of a 399 d cycle
}

static func retrograde_days(body_id: String) -> float:
	var syn: float = synodic_yr(body_id) * 365.25
	if syn <= 0.0:
		return 0.0
	return syn * float(RETRO_FRACTION.get(body_id, 0.1))

# ── Time ────────────────────────────────────────────────────────────

## Julian Day from a proleptic Gregorian calendar date (UT).
## Meeus ch. 7. `day` may carry a fraction.
static func julian_day(year: int, month: int, day: float) -> float:
	var y: int = year
	var m: int = month
	if m <= 2:
		y -= 1
		m += 12
	var a: int = int(floor(float(y) / 100.0))
	var b: int = 2 - a + int(floor(float(a) / 4.0))
	return floor(365.25 * float(y + 4716)) \
		+ floor(30.6001 * float(m + 1)) \
		+ day + float(b) - 1524.5

## Julian Day at 00:00 UT on 1 January of `year` -- the year picker's zero.
static func jd_at_year_start(year: int) -> float:
	return julian_day(year, 1, 1.0)

## Fractional-year label for a Julian Day, for HUD readouts.
static func year_fraction(jd: float) -> float:
	var year: int = int(floor(2000.0 + (jd - J2000_JD) / 365.25))
	# Walk to the containing year; the 365.25 guess can be off by one.
	while jd_at_year_start(year + 1) <= jd:
		year += 1
	while jd_at_year_start(year) > jd:
		year -= 1
	var start: float = jd_at_year_start(year)
	var span: float = maxf(jd_at_year_start(year + 1) - start, 1.0)
	return float(year) + (jd - start) / span

## Calendar date for a Julian Day, as {year, month, day}. Meeus ch. 7.
static func calendar_date(jd: float) -> Dictionary:
	var z_f: float = floor(jd + 0.5)
	var f: float = (jd + 0.5) - z_f
	var z: int = int(z_f)
	var a: int = z
	if z >= 2299161:
		var alpha: int = int(floor((float(z) - 1867216.25) / 36524.25))
		a = z + 1 + alpha - int(floor(float(alpha) / 4.0))
	var b: int = a + 1524
	var c: int = int(floor((float(b) - 122.1) / 365.25))
	var d: int = int(floor(365.25 * float(c)))
	var e: int = int(floor(float(b - d) / 30.6001))
	var day: float = float(b - d - int(floor(30.6001 * float(e)))) + f
	var month: int = e - 1 if e < 14 else e - 13
	var year: int = c - 4716 if month > 2 else c - 4715
	return {"year": year, "month": month, "day": day}

const MONTH_NAMES: Array = [
	"January", "February", "March", "April", "May", "June", "July",
	"August", "September", "October", "November", "December",
]

static func date_label(jd: float) -> String:
	var d: Dictionary = calendar_date(jd)
	var mi: int = clampi(int(d["month"]) - 1, 0, 11)
	return "%s %d, %d" % [MONTH_NAMES[mi], int(floor(float(d["day"]))),
		int(d["year"])]

static func centuries_since_j2000(jd: float) -> float:
	return (jd - J2000_JD) / DAYS_PER_CENTURY

## Mean obliquity of the ecliptic, degrees (IAU, linear term).
static func obliquity_deg(t_cy: float) -> float:
	return 23.439291 - 0.0130042 * t_cy

## General precession in ecliptic longitude since J2000, degrees.
##
## This is the difference between the two zodiacs, and it is worth being
## precise about because the mode shows both at once. Everything else in this
## file is referred to the FIXED J2000 equinox, which is the frame the star
## catalogue in ConstellationData uses -- so planets and constellations line
## up. But equinoxes, solstices and the tropical zodiac signs are defined
## against the MOVING equinox, which slides about 1.4 degrees per century.
## Add this when you want a longitude measured from the equinox of date.
static func precession_deg(t_cy: float) -> float:
	return 1.396971 * t_cy + 0.0003086 * t_cy * t_cy

## Geocentric ecliptic longitude referred to the equinox of date, degrees.
## Use this for tropical zodiac signs and for comparing against almanac
## equinox and solstice times; use ecliptic_longitude_deg for anything that
## has to agree with the fixed star catalogue.
static func ecliptic_longitude_of_date_deg(body_id: String,
		jd: float) -> float:
	return fposmod(ecliptic_longitude_deg(body_id, jd)
		+ precession_deg(centuries_since_j2000(jd)), 360.0)

# ── Kepler ──────────────────────────────────────────────────────────

## Elements at time t (Julian centuries from J2000), angles in degrees.
static func elements_at(body_id: String, t_cy: float) -> Dictionary:
	if not ELEMENTS.has(body_id):
		return {}
	var el: Dictionary = ELEMENTS[body_id]
	return {
		"a": float(el["a"]) + float(el["a_dot"]) * t_cy,
		"e": float(el["e"]) + float(el["e_dot"]) * t_cy,
		"i": float(el["i"]) + float(el["i_dot"]) * t_cy,
		"l": float(el["l"]) + float(el["l_dot"]) * t_cy,
		"peri": float(el["peri"]) + float(el["peri_dot"]) * t_cy,
		"node": float(el["node"]) + float(el["node_dot"]) * t_cy,
	}

## Eccentric anomaly from mean anomaly, by Newton-Raphson. Converges in a
## handful of passes for every eccentricity in the inner system (Mercury's
## 0.206 is the worst case).
static func solve_kepler(m_rad: float, e: float) -> float:
	var m: float = wrapf(m_rad, -PI, PI)
	var ecc: float = clampf(e, 0.0, 0.97)
	var ea: float = m if ecc < 0.8 else PI
	for _i in 12:
		var f: float = ea - ecc * sin(ea) - m
		var fp: float = 1.0 - ecc * cos(ea)
		var step: float = f / maxf(absf(fp), 1.0e-9) * signf(fp)
		ea -= step
		if absf(f) < 1.0e-12:
			break
	return ea

## Heliocentric position in J2000 ecliptic rectangular coordinates, AU.
## Returned as (x, y, z) with z toward the ecliptic north pole -- NOT Godot
## Y-up yet; see godot_dir() for that conversion.
static func heliocentric_ecliptic_au(body_id: String, jd: float) -> Vector3:
	if body_id == SUN:
		return Vector3.ZERO
	var t: float = centuries_since_j2000(jd)
	var el: Dictionary = elements_at(body_id, t)
	if el.is_empty():
		return Vector3.ZERO
	var a: float = float(el["a"])
	var e: float = float(el["e"])
	var inc: float = deg_to_rad(float(el["i"]))
	var node: float = deg_to_rad(float(el["node"]))
	# Argument of perihelion and mean anomaly follow from the tabulated
	# longitude of perihelion and mean longitude.
	var arg: float = deg_to_rad(float(el["peri"]) - float(el["node"]))
	var m: float = deg_to_rad(float(el["l"]) - float(el["peri"]))
	var ea: float = solve_kepler(m, e)
	# Position in the orbital plane, perifocal frame.
	var xv: float = a * (cos(ea) - e)
	var yv: float = a * sqrt(maxf(1.0 - e * e, 0.0)) * sin(ea)
	var cw: float = cos(arg)
	var sw: float = sin(arg)
	var cn: float = cos(node)
	var sn: float = sin(node)
	var ci: float = cos(inc)
	var si: float = sin(inc)
	return Vector3(
		(cw * cn - sw * sn * ci) * xv + (-sw * cn - cw * sn * ci) * yv,
		(cw * sn + sw * cn * ci) * xv + (-sw * sn + cw * cn * ci) * yv,
		(sw * si) * xv + (cw * si) * yv)

## Geocentric position in J2000 ecliptic rectangular coordinates, AU.
## This is the vector that matters: apparent retrograde is entirely a
## property of Earth-to-body geometry.
static func geocentric_ecliptic_au(body_id: String, jd: float) -> Vector3:
	if body_id == MOON:
		return moon_geocentric_ecliptic_au(jd)
	var earth: Vector3 = heliocentric_ecliptic_au(EARTH, jd)
	if body_id == SUN:
		return -earth
	return heliocentric_ecliptic_au(body_id, jd) - earth

# ── Moon ────────────────────────────────────────────────────────────

## Geocentric Moon in J2000 ecliptic rectangular coordinates, AU.
## Meeus ch. 47, principal terms only (~10 arcmin in longitude).
static func moon_geocentric_ecliptic_au(jd: float) -> Vector3:
	var t: float = centuries_since_j2000(jd)
	# Mean longitude, and the four fundamental arguments.
	var lp: float = 218.3164477 + 481267.88123421 * t
	var d: float = 297.8501921 + 445267.1114034 * t
	var ms: float = 357.5291092 + 35999.0502909 * t
	var mp: float = 134.9633964 + 477198.8675055 * t
	var f: float = 93.2720950 + 483202.0175233 * t
	var dr: float = deg_to_rad(d)
	var msr: float = deg_to_rad(ms)
	var mpr: float = deg_to_rad(mp)
	var fr: float = deg_to_rad(f)
	# Ecliptic longitude, degrees.
	var lon: float = lp \
		+ 6.288774 * sin(mpr) \
		+ 1.274027 * sin(2.0 * dr - mpr) \
		+ 0.658314 * sin(2.0 * dr) \
		+ 0.213618 * sin(2.0 * mpr) \
		- 0.185116 * sin(msr) \
		- 0.114332 * sin(2.0 * fr) \
		+ 0.058793 * sin(2.0 * dr - 2.0 * mpr) \
		+ 0.057066 * sin(2.0 * dr - msr - mpr) \
		+ 0.053322 * sin(2.0 * dr + mpr) \
		+ 0.045758 * sin(2.0 * dr - msr) \
		- 0.040923 * sin(msr - mpr) \
		- 0.034720 * sin(dr) \
		- 0.030383 * sin(msr + mpr)
	# Ecliptic latitude, degrees.
	var lat: float = 5.128122 * sin(fr) \
		+ 0.280602 * sin(mpr + fr) \
		+ 0.277693 * sin(mpr - fr) \
		+ 0.173237 * sin(2.0 * dr - fr) \
		+ 0.055413 * sin(2.0 * dr - mpr + fr) \
		+ 0.046271 * sin(2.0 * dr - mpr - fr) \
		+ 0.032573 * sin(2.0 * dr + fr) \
		+ 0.017198 * sin(2.0 * mpr + fr)
	# Distance, km.
	var dist_km: float = 385000.56 \
		- 20905.355 * cos(mpr) \
		- 3699.111 * cos(2.0 * dr - mpr) \
		- 2955.968 * cos(2.0 * dr) \
		- 569.925 * cos(2.0 * mpr) \
		+ 246.158 * cos(2.0 * dr - 2.0 * mpr) \
		- 152.138 * cos(2.0 * dr - msr - mpr) \
		- 170.733 * cos(2.0 * dr + mpr) \
		- 204.586 * cos(2.0 * dr - msr)
	var r_au: float = dist_km / KM_PER_AU
	var lo: float = deg_to_rad(lon)
	var la: float = deg_to_rad(lat)
	return Vector3(
		r_au * cos(la) * cos(lo),
		r_au * cos(la) * sin(lo),
		r_au * sin(la))

## Illuminated fraction of the Moon's disk, 0 at new and 1 at full.
static func moon_illumination(jd: float) -> float:
	return illuminated_fraction(MOON, jd)

## Signed elongation of the Moon from the Sun in degrees, -180..180. Zero at
## new moon, +-180 at full, positive while waxing. Crisper than differencing
## illumination, which is flat and therefore noisy near new and full.
static func moon_elongation_deg(jd: float) -> float:
	return wrapf(ecliptic_longitude_deg(MOON, jd)
		- ecliptic_longitude_deg(SUN, jd), -180.0, 180.0)

## True when the Moon is waxing, which sets which limb is lit and therefore
## which way the crescent's cusps point.
static func moon_waxing(jd: float) -> bool:
	return moon_elongation_deg(jd) > 0.0

# ── Frames ──────────────────────────────────────────────────────────

## Ecliptic rectangular -> equatorial rectangular, same units.
static func ecliptic_to_equatorial(v: Vector3, t_cy: float) -> Vector3:
	var eps: float = deg_to_rad(obliquity_deg(t_cy))
	var ce: float = cos(eps)
	var se: float = sin(eps)
	return Vector3(v.x, v.y * ce - v.z * se, v.y * se + v.z * ce)

## Right ascension in hours and declination in degrees, from an equatorial
## rectangular vector.
static func ra_dec_from_equatorial(v: Vector3) -> Vector2:
	var r: float = v.length()
	if r < 1.0e-12:
		return Vector2.ZERO
	var ra: float = rad_to_deg(atan2(v.y, v.x))
	if ra < 0.0:
		ra += 360.0
	return Vector2(ra / 15.0, rad_to_deg(asin(clampf(v.z / r, -1.0, 1.0))))

## Geocentric apparent right ascension (hours) and declination (degrees).
static func ra_dec(body_id: String, jd: float) -> Vector2:
	var t: float = centuries_since_j2000(jd)
	var geo: Vector3 = geocentric_ecliptic_au(body_id, jd)
	return ra_dec_from_equatorial(ecliptic_to_equatorial(geo, t))

## Geocentric ecliptic longitude in degrees -- the quantity whose direction
## of change defines retrograde motion.
static func ecliptic_longitude_deg(body_id: String, jd: float) -> float:
	var geo: Vector3 = geocentric_ecliptic_au(body_id, jd)
	if geo.length() < 1.0e-12:
		return 0.0
	var lon: float = rad_to_deg(atan2(geo.y, geo.x))
	return lon + 360.0 if lon < 0.0 else lon

## Rate of change of geocentric ecliptic longitude, degrees per day.
## Negative means retrograde (westward against the stars).
static func longitude_rate_deg_per_day(body_id: String, jd: float,
		h: float = 0.5) -> float:
	var a: float = ecliptic_longitude_deg(body_id, jd - h)
	var b: float = ecliptic_longitude_deg(body_id, jd + h)
	var d: float = wrapf(b - a, -180.0, 180.0)
	return d / (2.0 * h)

## True when the body is currently in apparent retrograde. The Sun and Moon
## never retrograde, so they always answer false.
static func is_retrograde(body_id: String, jd: float) -> bool:
	if body_id == SUN or body_id == MOON:
		return false
	return longitude_rate_deg_per_day(body_id, jd) < 0.0

## Julian date of the next stationary point at or after `from_jd`, where the
## body's apparent motion reverses. Returns 0.0 if none is found within
## `limit_days`, which for a naked-eye planet means the search was too short.
##
## Scans on a coarse step and then bisects the sign change. The step has to be
## well under Mercury's three-week retrograde or a whole loop can be stepped
## clean over; two days is comfortable for every body here.
static func next_station_jd(body_id: String, from_jd: float,
		limit_days: float = 800.0, step: float = 2.0) -> float:
	if body_id == SUN or body_id == MOON:
		return 0.0
	var was: bool = is_retrograde(body_id, from_jd)
	var t: float = from_jd
	var end: float = from_jd + limit_days
	while t < end:
		var next_t: float = minf(t + step, end)
		if is_retrograde(body_id, next_t) != was:
			# Bracketed: bisect to well under a day.
			var lo: float = t
			var hi: float = next_t
			for _i in 12:
				var mid: float = (lo + hi) * 0.5
				if is_retrograde(body_id, mid) == was:
					lo = mid
				else:
					hi = mid
			return (lo + hi) * 0.5
		t = next_t
	return 0.0

## Start and end of the first retrograde window that overlaps or follows
## `from_jd`, as {"start": jd, "end": jd}. Empty if none was found.
##
## If the body is already retrograde at `from_jd` the window it is in gets
## reported, by walking backwards to find where it began -- otherwise asking in
## the middle of a loop would skip to the next one, months away.
static func retrograde_window(body_id: String, from_jd: float,
		limit_days: float = 900.0) -> Dictionary:
	if body_id == SUN or body_id == MOON:
		return {}
	if is_retrograde(body_id, from_jd):
		var back: float = from_jd
		var floor_jd: float = from_jd - retrograde_days(body_id) * 1.6 - 10.0
		# Step back to before the loop started, then find the entry forwards.
		while back > floor_jd and is_retrograde(body_id, back):
			back -= 2.0
		var start: float = next_station_jd(body_id, back, limit_days)
		var stop: float = next_station_jd(body_id, from_jd, limit_days)
		if start <= 0.0 or stop <= 0.0:
			return {}
		return {"start": start, "end": stop}
	var s: float = next_station_jd(body_id, from_jd, limit_days)
	if s <= 0.0:
		return {}
	# Nudge past the station before hunting the exit, or the same crossing is
	# found again.
	var e: float = next_station_jd(body_id, s + 1.0, limit_days)
	if e <= 0.0:
		return {}
	return {"start": s, "end": e}

# ── Observer ────────────────────────────────────────────────────────

## Greenwich mean sidereal time in degrees.
static func gmst_deg(jd: float) -> float:
	var d: float = jd - J2000_JD
	var t: float = centuries_since_j2000(jd)
	return fposmod(280.46061837 + 360.98564736629 * d
		+ 0.000387933 * t * t, 360.0)

## Local mean sidereal time in degrees, east longitude positive.
static func lst_deg(jd: float, lon_deg: float) -> float:
	return fposmod(gmst_deg(jd) + lon_deg, 360.0)

## Altitude and azimuth in degrees for an observer at `lat_deg`/`lon_deg`.
## Azimuth is measured from north through east. This transform is what makes
## the southern tropic view genuinely upside down relative to the northern
## one -- the sky is not mirrored, the observer's local vertical is flipped.
static func alt_az(ra_h: float, dec_deg: float, jd: float,
		lat_deg: float, lon_deg: float) -> Vector2:
	var ha: float = deg_to_rad(lst_deg(jd, lon_deg) - ra_h * 15.0)
	var dec: float = deg_to_rad(dec_deg)
	var lat: float = deg_to_rad(lat_deg)
	var sin_alt: float = sin(dec) * sin(lat) + cos(dec) * cos(lat) * cos(ha)
	var alt: float = asin(clampf(sin_alt, -1.0, 1.0))
	var az: float = atan2(-cos(dec) * sin(ha),
		sin(dec) * cos(lat) - cos(dec) * sin(lat) * cos(ha))
	return Vector2(rad_to_deg(alt), fposmod(rad_to_deg(az), 360.0))

## Observer offset from Earth's centre in J2000 equatorial AU. Only the Moon
## is close enough for this to matter, but it matters by up to a degree.
static func observer_offset_au(jd: float, lat_deg: float,
		lon_deg: float) -> Vector3:
	var lst: float = deg_to_rad(lst_deg(jd, lon_deg))
	var lat: float = deg_to_rad(lat_deg)
	var r: float = EARTH_RADIUS_KM / KM_PER_AU
	return Vector3(r * cos(lat) * cos(lst), r * cos(lat) * sin(lst),
		r * sin(lat))

## Topocentric apparent RA/Dec: geocentric, corrected for the observer's
## displacement from Earth's centre.
static func topocentric_ra_dec(body_id: String, jd: float, lat_deg: float,
		lon_deg: float) -> Vector2:
	var t: float = centuries_since_j2000(jd)
	var eq: Vector3 = ecliptic_to_equatorial(
		geocentric_ecliptic_au(body_id, jd), t)
	return ra_dec_from_equatorial(
		eq - observer_offset_au(jd, lat_deg, lon_deg))

# ── Rendering helpers ───────────────────────────────────────────────

## Equatorial rectangular -> Godot direction, matching the convention
## ConstellationData.sky_pos already uses for stars, so planets and stars
## share one sky. Ecliptic longitude 0 points down -Z, +Y is the ecliptic
## north pole.
static func godot_dir_from_ecliptic(v: Vector3) -> Vector3:
	if v.length() < 1.0e-12:
		return Vector3.FORWARD
	var n: Vector3 = v.normalized()
	return Vector3(n.y, n.z, -n.x)

## Unit direction from Earth to a body, in the same frame as the star sphere.
static func sky_dir(body_id: String, jd: float) -> Vector3:
	return godot_dir_from_ecliptic(geocentric_ecliptic_au(body_id, jd))

## Equatorial rectangular -> ecliptic rectangular. Inverse of
## ecliptic_to_equatorial.
static func equatorial_to_ecliptic(v: Vector3, t_cy: float) -> Vector3:
	var eps: float = deg_to_rad(obliquity_deg(t_cy))
	var ce: float = cos(eps)
	var se: float = sin(eps)
	return Vector3(v.x, v.y * ce + v.z * se, -v.y * se + v.z * ce)

## Direction of the observer's local zenith, in the star-sphere frame.
##
## This one vector is the whole "upside down" question. The sky is not
## mirrored between hemispheres and the constellations are not redrawn -- what
## changes is which way is UP for the person looking. An observer at 38 N sees
## an object on the ecliptic to their south, so celestial north sits at the top
## of their view. An observer at 23.5 S sees that same object to their NORTH,
## overhead and past the zenith, so their local up points the other way and the
## whole field, retrograde loop included, arrives inverted. Using the true
## zenith as the camera's up vector reproduces that for free.
static func zenith_dir(jd: float, lat_deg: float, lon_deg: float) -> Vector3:
	var eq: Vector3 = observer_offset_au(jd, lat_deg, lon_deg)
	if eq.length() < 1.0e-15:
		return Vector3.UP
	var t: float = centuries_since_j2000(jd)
	return godot_dir_from_ecliptic(equatorial_to_ecliptic(eq, t))

## East longitude at which `body_id` is crossing the meridian at `jd` -- that
## is, where on Earth the body is due south (or north) and at its highest.
##
## EarthShip places the observer here and keeps them here as time runs. That is
## the observing convention a naked-eye watcher actually uses: you look at a
## planet when it culminates, night after night, and it is only by comparing
## those nightly culminations that a retrograde loop becomes visible at all.
## It also means the target never sets or wanders off frame during a months-long
## time lapse.
static func meridian_longitude_deg(body_id: String, jd: float) -> float:
	var ra_h: float = ra_dec(body_id, jd).x
	return wrapf(ra_h * 15.0 - gmst_deg(jd), -180.0, 180.0)

## Altitude of the Sun in degrees for an observer. Negative is below the
## horizon; this is the number that decides whether anything else is visible.
static func sun_altitude_deg(jd: float, lat_deg: float,
		lon_deg: float) -> float:
	var rd: Vector2 = ra_dec(SUN, jd)
	return alt_az(rd.x, rd.y, jd, lat_deg, lon_deg).x

## How dark the sky is, 0 (full daylight) to 1 (astronomically dark), from the
## Sun's altitude. The thresholds are the standard ones, and they are not
## arbitrary: the naked eye really does lose the planets around civil twilight
## and gains the faintest stars only past astronomical twilight.
##
##   above  0 deg : day, nothing but the Sun and Moon
##    0 to -6     : civil twilight, the brightest planets emerge
##   -6 to -12    : nautical, bright stars
##  -12 to -18    : astronomical, most stars
##  below -18     : night
static func darkness01(sun_alt_deg: float) -> float:
	if sun_alt_deg >= 0.0:
		return 0.0
	if sun_alt_deg <= -18.0:
		return 1.0
	return smoothstep(0.0, 1.0, -sun_alt_deg / 18.0)

## East longitude giving the best naked-eye view of a body on a given date:
## somewhere the sky is dark and the body is up.
##
## Placing the observer at the body's meridian crossing keeps it highest, but
## for Mercury and Venus that crossing happens in broad daylight -- their
## retrograde loops occur near inferior conjunction, close to the Sun. An
## observer standing at that longitude would see a blue sky and no planet.
##
## A real watcher does not stand still; they go out when it is dark and the
## planet is above the horizon, which is why Venus is the "evening star". So
## this searches hour angles either side of culmination and prefers darkness
## first, then altitude. The search is bounded so the body cannot wander to the
## far side of the sky, which keeps a months-long time lapse stable.
static func best_view_longitude_deg(body_id: String, jd: float,
		lat_deg: float) -> float:
	var meridian: float = meridian_longitude_deg(body_id, jd)
	# The Sun's own viewer wants daylight; searching for darkness is nonsense.
	if body_id == SUN:
		return meridian
	var rd: Vector2 = ra_dec(body_id, jd)
	var best_lon: float = meridian
	var best_score: float = -INF
	# +/- 5 hours of hour angle, in 20-minute steps.
	for i in range(-15, 16):
		var lon: float = meridian + float(i) * 5.0
		var alt: float = alt_az(rd.x, rd.y, jd, lat_deg, lon).x
		if alt < 8.0:
			continue
		var dark: float = darkness01(sun_altitude_deg(jd, lat_deg, lon))
		# Darkness dominates: a planet 20 degrees up in a dark sky beats the
		# same planet overhead at noon, because at noon it is not there at all.
		var score: float = dark * 120.0 + alt
		if score > best_score:
			best_score = score
			best_lon = lon
	return best_lon

## Distance from Earth in AU.
static func earth_distance_au(body_id: String, jd: float) -> float:
	return geocentric_ecliptic_au(body_id, jd).length()

## Distance from the Sun in AU.
static func sun_distance_au(body_id: String, jd: float) -> float:
	if body_id == SUN:
		return 0.0
	if body_id == MOON:
		return heliocentric_ecliptic_au(EARTH, jd).length()
	return heliocentric_ecliptic_au(body_id, jd).length()

static func radius_km(body_id: String) -> float:
	return float(PHYSICAL.get(body_id, {}).get("radius_km", 1000.0))

static func albedo(body_id: String) -> float:
	return float(PHYSICAL.get(body_id, {}).get("albedo", 0.3))

## True angular radius as seen from Earth, in radians.
static func apparent_radius_rad(body_id: String, jd: float) -> float:
	var d_au: float = earth_distance_au(body_id, jd)
	var r_km: float = radius_km(body_id)
	var d_km: float = maxf(d_au * KM_PER_AU, r_km * 1.001)
	return atan(r_km / d_km)

## Phase angle at the body, between the Sun and Earth, in radians. Drives
## the crescent: 0 is fully lit, PI is fully dark.
static func phase_angle_rad(body_id: String, jd: float) -> float:
	if body_id == SUN:
		return 0.0
	var to_earth: Vector3 = -geocentric_ecliptic_au(body_id, jd)
	var to_sun: Vector3 = -heliocentric_ecliptic_au(body_id, jd) \
		if body_id != MOON \
		else (heliocentric_ecliptic_au(EARTH, jd) * -1.0
			- geocentric_ecliptic_au(MOON, jd))
	if to_earth.length() < 1.0e-12 or to_sun.length() < 1.0e-12:
		return 0.0
	return acos(clampf(
		to_earth.normalized().dot(to_sun.normalized()), -1.0, 1.0))

## Illuminated fraction of the disk facing Earth, 0..1.
static func illuminated_fraction(body_id: String, jd: float) -> float:
	if body_id == SUN:
		return 1.0
	return 0.5 * (1.0 + cos(phase_angle_rad(body_id, jd)))

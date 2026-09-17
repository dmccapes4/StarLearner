extends SceneTree
## Validates Ephemeris.gd against published almanac values.
##
## Run: godot --headless --path game -s res://tools/ephemeris_check.gd
##
## This is a measurement tool, not an assertion suite -- it prints what the
## ephemeris says next to what the almanac says so the error is visible.
## The hard assertions live in tests/run_tests.gd.

const Eph := preload("res://scripts/Ephemeris.gd")
const Bril := preload("res://scripts/SolarBrilliance.gd")
const Expo := preload("res://scripts/Exposure.gd")

var _fails: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("======== Ephemeris check ========")
	_check_epoch()
	_check_equinox()
	_check_mars_opposition()
	_check_retrograde_windows()
	_check_moon()
	_check_loop_shape()
	_check_periods()
	_check_brilliance()
	_check_exposure()
	print("======== %s ========" % (
		"ALL CHECKS WITHIN TOLERANCE" if _fails == 0
		else "%d CHECK(S) OUT OF TOLERANCE" % _fails))
	quit(0)

func _near(label: String, got: float, want: float, tol: float,
		unit: String = "") -> void:
	var err: float = absf(got - want)
	var ok: bool = err <= tol
	if not ok:
		_fails += 1
	print("  %s %-42s got %12.5f  want %12.5f  err %9.5f %s" % [
		"OK  " if ok else "FAIL", label, got, want, err, unit])

func _check_epoch() -> void:
	print("\n-- J2000 epoch --")
	# Earth's MEAN longitude at J2000 is 100.46457, so the Sun's mean
	# longitude is 280.46457. Its TRUE longitude differs by the equation of
	# centre, about -2e sin M with M = 100.46457 - 102.93768 = -2.473 deg,
	# giving -0.0826 deg. So the true longitude is 280.382, not 280.465.
	var lon: float = Eph.ecliptic_longitude_deg(Eph.SUN, Eph.J2000_JD)
	_near("Sun true geocentric longitude at J2000", lon, 280.382, 0.005, "deg")
	var el: Dictionary = Eph.elements_at(Eph.EARTH, 0.0)
	_near("Earth mean longitude at J2000", float(el["l"]),
		100.46457, 0.00001, "deg")
	# Julian Day of a date everybody tabulates.
	_near("JD for 2000-01-01.5", Eph.julian_day(2000, 1, 1.5),
		2451545.0, 0.0001, "d")
	_near("JD for 1957-10-04.81 (Sputnik)",
		Eph.julian_day(1957, 10, 4.81), 2436116.31, 0.0001, "d")
	# Round trip through the calendar.
	var d: Dictionary = Eph.calendar_date(2451545.0)
	_near("calendar_date(2451545) year", float(d["year"]), 2000.0, 0.0)
	_near("calendar_date(2451545) month", float(d["month"]), 1.0, 0.0)
	_near("calendar_date(2451545) day", float(d["day"]), 1.5, 0.0001)

func _check_equinox() -> void:
	print("\n-- Equinoxes and solstices --")
	# These are defined against the equinox OF DATE, so they are the test of
	# precession_deg(). Measured against the fixed J2000 equinox the December
	# 2024 solstice misses 270 deg by 0.35 deg, which is exactly 25 years of
	# precession -- the frame difference, not an ephemeris error.
	# March equinox 2000: 20 Mar 07:35 UT -> 0 deg.
	var jd: float = Eph.julian_day(2000, 3, 20.0 + 7.58 / 24.0)
	_near("Sun longitude of date, Mar equinox 2000",
		wrapf(Eph.ecliptic_longitude_of_date_deg(Eph.SUN, jd), -180.0, 180.0),
		0.0, 0.02, "deg")
	# June solstice 2000: 21 Jun 01:48 UT -> 90 deg.
	var jd2: float = Eph.julian_day(2000, 6, 21.0 + 1.80 / 24.0)
	_near("Sun longitude of date, Jun solstice 2000",
		Eph.ecliptic_longitude_of_date_deg(Eph.SUN, jd2), 90.0, 0.02, "deg")
	# December solstice 2024: 21 Dec 09:21 UT -> 270 deg.
	var jd3: float = Eph.julian_day(2024, 12, 21.0 + 9.35 / 24.0)
	_near("Sun longitude of date, Dec solstice 2024",
		Eph.ecliptic_longitude_of_date_deg(Eph.SUN, jd3), 270.0, 0.02, "deg")
	# March equinox 2026: 20 Mar 14:46 UT -> 0 deg.
	var jd4: float = Eph.julian_day(2026, 3, 20.0 + 14.77 / 24.0)
	_near("Sun longitude of date, Mar equinox 2026",
		wrapf(Eph.ecliptic_longitude_of_date_deg(Eph.SUN, jd4), -180.0, 180.0),
		0.0, 0.02, "deg")
	# And show the size of the frame difference the mode has to be honest about.
	print("       precession J2000 -> 2026: %.4f deg (tropical vs fixed zodiac)"
		% Eph.precession_deg(Eph.centuries_since_j2000(jd4)))

func _check_mars_opposition() -> void:
	print("\n-- Mars opposition, 8 Dec 2022 --")
	# Almanac: opposition 8 Dec 2022, Earth-Mars distance 0.5445 AU.
	var jd: float = Eph.julian_day(2022, 12, 8.0)
	_near("Mars distance from Earth", Eph.earth_distance_au(Eph.MARS, jd),
		0.5445, 0.005, "AU")
	# At opposition Mars is 180 deg from the Sun as seen from Earth.
	var elong: float = absf(wrapf(
		Eph.ecliptic_longitude_deg(Eph.MARS, jd)
		- Eph.ecliptic_longitude_deg(Eph.SUN, jd), -180.0, 180.0))
	_near("Mars solar elongation", elong, 180.0, 1.5, "deg")
	# Mars must be retrograde at opposition -- that is what opposition means
	# geometrically, and it is the core claim of the whole mode.
	var rx: bool = Eph.is_retrograde(Eph.MARS, jd)
	print("  %s Mars retrograde at opposition: %s" % [
		"OK  " if rx else "FAIL", rx])
	if not rx:
		_fails += 1

func _check_retrograde_windows() -> void:
	print("\n-- Retrograde stations vs published dates --")
	# Published stationary points (geocentric, UT):
	#   Mars    2022-10-30 -> 2023-01-12  (opposition 2022-12-08)
	#   Mars    2024-12-07 -> 2025-02-23  (opposition 2025-01-16)
	#   Jupiter 2025-11-11 -> 2026-03-11  (opposition 2026-01-10)
	#   Venus   2025-03-01 -> 2025-04-12  (inferior conj. 2025-03-22)
	_station_pair(Eph.MARS, 2022, 2023,
		Eph.julian_day(2022, 10, 30.0), Eph.julian_day(2023, 1, 12.0))
	_station_pair(Eph.MARS, 2024, 2025,
		Eph.julian_day(2024, 12, 7.0), Eph.julian_day(2025, 2, 23.0))
	_station_pair(Eph.JUPITER, 2025, 2026,
		Eph.julian_day(2025, 11, 11.0), Eph.julian_day(2026, 3, 11.0))
	_station_pair(Eph.VENUS, 2025, 2025,
		Eph.julian_day(2025, 3, 1.0), Eph.julian_day(2025, 4, 12.0))
	# Invariant that ties it together: an outer planet's retrograde is centred
	# on opposition, so the midpoint of the window must land there.
	_retro_centred_on_opposition(Eph.MARS,
		Eph.julian_day(2022, 12, 8.0), "Mars 2022")
	_retro_centred_on_opposition(Eph.JUPITER,
		Eph.julian_day(2026, 1, 10.0), "Jupiter 2026")

func _station_pair(body: String, y0: int, y1: int, want_start: float,
		want_end: float) -> void:
	# Scan a wide window around the published dates for sign changes in the
	# longitude rate.
	var from: float = want_start - 60.0
	var to: float = want_end + 60.0
	var starts: Array = []
	var ends: Array = []
	var prev: float = Eph.longitude_rate_deg_per_day(body, from)
	var jd: float = from + 0.25
	while jd <= to:
		var cur: float = Eph.longitude_rate_deg_per_day(body, jd)
		if prev >= 0.0 and cur < 0.0:
			starts.append(jd)
		elif prev < 0.0 and cur >= 0.0:
			ends.append(jd)
		prev = cur
		jd += 0.25
	if starts.is_empty() or ends.is_empty():
		print("  FAIL %s %d: no station found in window" % [body, y0])
		_fails += 1
		return
	_near("%s retrograde start %d (days off)" % [body, y0],
		float(starts[0]) - want_start, 0.0, 1.5, "d")
	_near("%s retrograde end %d (days off)" % [body, y1],
		float(ends[ends.size() - 1]) - want_end, 0.0, 1.5, "d")

## The midpoint of a retrograde window must fall on opposition.
func _retro_centred_on_opposition(body: String, opp_jd: float,
		label: String) -> void:
	var from: float = opp_jd - 120.0
	var to: float = opp_jd + 120.0
	var start: float = -1.0
	var end: float = -1.0
	var prev: float = Eph.longitude_rate_deg_per_day(body, from)
	var jd: float = from + 0.25
	while jd <= to:
		var cur: float = Eph.longitude_rate_deg_per_day(body, jd)
		if prev >= 0.0 and cur < 0.0 and start < 0.0:
			start = jd
		elif prev < 0.0 and cur >= 0.0 and start > 0.0 and end < 0.0:
			end = jd
		prev = cur
		jd += 0.25
	if start < 0.0 or end < 0.0:
		print("  FAIL %s: incomplete retrograde window" % label)
		_fails += 1
		return
	_near("%s Rx midpoint vs opposition" % label,
		(start + end) * 0.5 - opp_jd, 0.0, 2.5, "d")
	_near("%s Rx duration" % label, end - start,
		Eph.retrograde_days(body), 12.0, "d")

func _check_moon() -> void:
	print("\n-- Moon --")
	# Full moon 6 Jan 2023 23:08 UT: illumination ~1.
	var full: float = Eph.julian_day(2023, 1, 6.0 + 23.13 / 24.0)
	_near("illumination at full moon 2023-01-06",
		Eph.moon_illumination(full), 1.0, 0.01)
	# New moon 21 Jan 2023 20:53 UT: illumination ~0.
	var new_moon: float = Eph.julian_day(2023, 1, 21.0 + 20.88 / 24.0)
	_near("illumination at new moon 2023-01-21",
		Eph.moon_illumination(new_moon), 0.0, 0.01)
	# Distance must stay inside the real perigee/apogee band.
	var min_km: float = 1.0e12
	var max_km: float = 0.0
	var jd: float = Eph.J2000_JD
	while jd < Eph.J2000_JD + 400.0:
		var km: float = Eph.geocentric_ecliptic_au(Eph.MOON, jd).length() \
			* Eph.KM_PER_AU
		min_km = minf(min_km, km)
		max_km = maxf(max_km, km)
		jd += 0.25
	_near("min Earth-Moon distance over 400 d", min_km, 357000.0, 3000.0, "km")
	_near("max Earth-Moon distance over 400 d", max_km, 406000.0, 3000.0, "km")
	# Synodic month from successive new moons.
	_near("mean synodic month", _mean_synodic_month(), 29.5306, 0.02, "d")
	# Angular diameter: the Moon is about half a degree.
	_near("Moon apparent diameter at J2000",
		rad_to_deg(Eph.apparent_radius_rad(Eph.MOON, Eph.J2000_JD)) * 2.0,
		0.52, 0.06, "deg")

func _mean_synodic_month() -> float:
	# New moon is where the signed Moon-Sun elongation crosses zero upward.
	# Illumination is flat near new, so differencing it is noisy; elongation
	# passes through zero cleanly.
	var found: Array = []
	var prev: float = Eph.moon_elongation_deg(Eph.J2000_JD)
	var jd: float = Eph.J2000_JD + 0.125
	while jd < Eph.J2000_JD + 420.0:
		var cur: float = Eph.moon_elongation_deg(jd)
		if prev < 0.0 and cur >= 0.0:
			found.append(jd)
		prev = cur
		jd += 0.125
	if found.size() < 2:
		return 0.0
	return (float(found[found.size() - 1]) - float(found[0])) \
		/ float(found.size() - 1)

func _check_loop_shape() -> void:
	print("\n-- Retrograde loop geometry (the reason we need real elements) --")
	# Across the 2022 Mars retrograde, the geocentric ecliptic LATITUDE must
	# change appreciably. With the old coplanar circular model it would be
	# identically zero and the path would be a straight line, not a loop.
	var from: float = Eph.julian_day(2022, 10, 1.0)
	var to: float = Eph.julian_day(2023, 2, 15.0)
	var lat_min: float = 1.0e9
	var lat_max: float = -1.0e9
	var jd: float = from
	while jd <= to:
		var geo: Vector3 = Eph.geocentric_ecliptic_au(Eph.MARS, jd)
		var lat: float = rad_to_deg(asin(clampf(
			geo.z / maxf(geo.length(), 1.0e-9), -1.0, 1.0)))
		lat_min = minf(lat_min, lat)
		lat_max = maxf(lat_max, lat)
		jd += 1.0
	var swing: float = lat_max - lat_min
	print("  %s Mars ecliptic latitude swing during 2022 Rx: %.3f deg"
		% ["OK  " if swing > 1.0 else "FAIL", swing])
	if swing <= 1.0:
		_fails += 1
	print("       (a coplanar circular model gives exactly 0.000 -> a line,")
	print("        not a loop. This is why EarthShip needs real elements.)")

func _check_periods() -> void:
	print("\n-- Derived periods --")
	_near("Mercury sidereal period", Eph.period_yr(Eph.MERCURY),
		0.2408, 0.001, "yr")
	_near("Venus sidereal period", Eph.period_yr(Eph.VENUS),
		0.6152, 0.001, "yr")
	_near("Mars sidereal period", Eph.period_yr(Eph.MARS),
		1.8808, 0.001, "yr")
	_near("Jupiter sidereal period", Eph.period_yr(Eph.JUPITER),
		11.862, 0.01, "yr")
	_near("Mars synodic period", Eph.synodic_yr(Eph.MARS),
		2.1354, 0.005, "yr")
	_near("Venus synodic period", Eph.synodic_yr(Eph.VENUS),
		1.5987, 0.005, "yr")
	_near("Jupiter synodic period", Eph.synodic_yr(Eph.JUPITER),
		1.0921, 0.005, "yr")
	_near("Mercury synodic period", Eph.synodic_yr(Eph.MERCURY),
		0.3178, 0.005, "yr")

func _check_brilliance() -> void:
	print("\n-- SolarBrilliance: apparent magnitude vs published extremes --")
	# The published -26.74 for the Sun and -12.74 for the full Moon are both
	# quoted at MEAN distance, so they have to be checked at mean distance.
	# J2000 falls near perihelion, where the Sun is genuinely a little
	# brighter -- that is signal, not error.
	_near("Sun at mean distance (1 AU)",
		Bril.SUN_MAG_AT_1AU, -26.74, 0.001, "mag")
	var sun_now: float = Bril.apparent_magnitude(Eph.SUN, Eph.J2000_JD)
	print("       Sun at J2000 (near perihelion, %.4f AU): %+.3f mag"
		% [Eph.earth_distance_au(Eph.SUN, Eph.J2000_JD), sun_now])
	# Annual swing from perihelion to aphelion is about 0.07 mag.
	var sun_min: float = 99.0
	var sun_max: float = -99.0
	var jd: float = Eph.J2000_JD
	while jd < Eph.J2000_JD + 366.0:
		var m: float = Bril.apparent_magnitude(Eph.SUN, jd)
		sun_min = minf(sun_min, m)
		sun_max = maxf(sun_max, m)
		jd += 1.0
	_near("Sun annual magnitude swing", sun_max - sun_min, 0.07, 0.01, "mag")
	# Full Moon at mean distance (384400 km) and zero phase angle.
	var moon_mean_au: float = 384400.0 / Eph.KM_PER_AU
	_near("full Moon at mean distance",
		float(Bril.ABS_MAG["moon"]) + 5.0 * Bril.log_10(moon_mean_au),
		-12.74, 0.01, "mag")
	# The specific full moon of 6 Jan 2023 was near apogee, so it must come
	# out slightly fainter than the mean figure.
	var fm: float = Bril.apparent_magnitude(Eph.MOON,
		Eph.julian_day(2023, 1, 6.0 + 23.13 / 24.0))
	var fm_ok: bool = fm > -12.9 and fm < -12.3
	print("  %s full Moon 2023-01-06 (near apogee): %+.2f mag, in band -12.9..-12.3"
		% ["OK  " if fm_ok else "FAIL", fm])
	if not fm_ok:
		_fails += 1
	# Jupiter at the 10 Jan 2026 opposition.
	_near("Jupiter at opposition",
		Bril.apparent_magnitude(Eph.JUPITER,
			Eph.julian_day(2026, 1, 10.0)), -2.70, 0.15, "mag")
	# Mars at the perihelic opposition of 27 Jul 2018 (its brightest in years).
	_near("Mars at perihelic opposition 2018",
		Bril.apparent_magnitude(Eph.MARS,
			Eph.julian_day(2018, 7, 27.0)), -2.78, 0.20, "mag")
	# Venus greatest brilliance: scan one synodic cycle for the minimum.
	_near("Venus greatest brilliance",
		_brightest(Eph.VENUS, Eph.julian_day(2025, 1, 1.0), 600.0),
		-4.6, 0.20, "mag")
	# Mercury's full range is -2.48 to +7.25. The bright end happens at
	# superior conjunction, where Mercury is nearly full but behind the Sun
	# and so unobservable -- the model should still reproduce it.
	_near("Mercury greatest brilliance",
		_brightest(Eph.MERCURY, Eph.julian_day(2025, 1, 1.0), 200.0),
		-2.48, 0.10, "mag")
	# Every naked-eye body must actually be naked-eye at its best.
	for body in [Eph.MERCURY, Eph.VENUS, Eph.MARS, Eph.JUPITER]:
		var best: float = _brightest(body, Eph.julian_day(2025, 1, 1.0), 4400.0)
		var vis: bool = best < Bril.NAKED_EYE_LIMIT
		print("  %s %-16s best magnitude %+6.2f  brightness01 %.3f" % [
			"OK  " if vis else "FAIL", body, best, Bril.brightness01(best)])
		if not vis:
			_fails += 1

func _brightest(body: String, from_jd: float, span_days: float) -> float:
	var best: float = 99.0
	var jd: float = from_jd
	while jd < from_jd + span_days:
		best = minf(best, Bril.apparent_magnitude(body, jd))
		jd += 0.5
	return best

func _check_exposure() -> void:
	print("\n-- Exposure: logistic buffer decay --")
	_near("weight at head of tail", Expo.weight_at(0.0), 1.0, 0.0001)
	_near("weight at cutoff", Expo.weight_at(1.0), 0.0, 0.0001)
	_near("weight past cutoff", Expo.weight_at(1.4), 0.0, 0.0001)
	# The shape the spec asks for: a slow, nearly linear start, then a knee,
	# then a drop to the cutoff. Test it as shape, not as constants.
	var w25: float = Expo.weight_at(0.25)
	var w50: float = Expo.weight_at(0.50)
	var w75: float = Expo.weight_at(0.75)
	print("       weight at u=0.25/0.50/0.75: %.3f / %.3f / %.3f"
		% [w25, w50, w75])
	# Monotonically decreasing.
	var mono: bool = w25 > w50 and w50 > w75
	print("  %s monotonically decreasing" % ["OK  " if mono else "FAIL"])
	if not mono:
		_fails += 1
	# First half must lose far less than the second half -- that is what
	# "slow nearly linear start then a drop" means.
	var first: float = 1.0 - w50
	var second: float = w50 - 0.0
	var slow_start: bool = first < second * 0.5
	print("  %s slow start: first half loses %.3f, second half loses %.3f"
		% ["OK  " if slow_start else "FAIL", first, second])
	if not slow_start:
		_fails += 1
	# Still above half strength at the midpoint of the buffer.
	var holds: bool = w50 > 0.5
	print("  %s tail still above half strength at u=0.5 (%.3f)"
		% ["OK  " if holds else "FAIL", w50])
	if not holds:
		_fails += 1
	print("\n-- Exposure schedules (1.2x the natural period) --")
	for body in [Eph.MERCURY, Eph.VENUS, Eph.MARS, Eph.JUPITER]:
		var rx: float = Eph.retrograde_days(body)
		var sched: float = Expo.retrograde_schedule_days(body)
		_near("%s schedule / retrograde period" % body, sched / maxf(rx, 0.001),
			1.2, 0.0001, "x")
		print("       %-8s retrograde %6.1f d   buffer %6.1f d"
			% [body, rx, sched])
	_near("lunar schedule / synodic month",
		Expo.lunar_schedule_days() / Eph.SYNODIC_MONTH_DAYS, 1.2, 0.0001, "x")
	# A sampled tail must span the schedule and be dense enough to read.
	var tail: Array = Expo.sample_tail(Eph.MARS,
		Eph.julian_day(2022, 12, 8.0), -23.5, 0.0)
	print("       Mars tail at 2022 opposition: %d samples, %.1f%% retrograde"
		% [tail.size(), Expo.retrograde_fraction(tail) * 100.0])
	var dense: bool = tail.size() > 80
	print("  %s tail dense enough to read as a curve" % [
		"OK  " if dense else "FAIL"])
	if not dense:
		_fails += 1
	# Head of the tail must be the newest sample and carry full weight.
	var head_ok: bool = tail.size() > 0 \
		and absf(float(tail[0]["weight"]) - 1.0) < 0.001
	print("  %s tail head is newest and at full weight" % [
		"OK  " if head_ok else "FAIL"])
	if not head_ok:
		_fails += 1

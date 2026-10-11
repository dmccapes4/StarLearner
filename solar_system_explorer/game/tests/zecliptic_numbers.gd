extends SceneTree
## Numbers check for ZeclipticBodies against DE421 points exported in
## docs/MERCURY_VULCAN_LADDER_20261010/data/ephem_2026_2027_6h.json and the
## values used in OurMercilessJourney / the ladder report.
##
##   godot --headless --path game -s res://tests/zecliptic_numbers.gd

var fails := 0

func _init() -> void:
	call_deferred("_run")

func _check(label: String, got: float, want: float, tol: float) -> void:
	var ok := absf(got - want) <= tol
	if not ok:
		fails += 1
	print("%s  %s  got %.5f  want %.5f  tol %.5f" % ["ok  " if ok else "FAIL", label, got, want, tol])

func _run() -> void:
	var jd := 2461041.5008   # 2026-01-01 00:00 UTC (TT), first row of the DE421 export
	# DE421 heliocentric ecliptic AU, from the JSON (read, not typed, below)
	var doc := ProjectSettings.globalize_path("res://").path_join("../docs/MERCURY_VULCAN_LADDER_20261010/data/ephem_2026_2027_6h.json")
	var f := FileAccess.open(doc, FileAccess.READ)
	# Ledger 2026-10-11: ephem_2026_2027_6h.json is labelled "ecliptic J2000" but was written with
	# skyfield's ecliptic_frame (of date) — a 0.36 deg precession offset, 0.006 AU at Earth. The
	# planet rows are therefore checked against DE421 in the true J2000 ecliptic (skyfield
	# ecliptic_J2000_frame, run 2026-10-11 02:55) typed here with that source; the of-date file is
	# still checked at a loose tolerance so the offset itself is on record.
	var de421_j2000 := {
		"mercury": Vector3(-0.215186, -0.409217, -0.013705),
		"earth": Vector3(-0.174295, 0.967756, -0.000059),
		"mars": Vector3(0.340591, -1.386998, -0.037417),
	}
	for id in de421_j2000:
		var got := ZeclipticBodies.helio_ecl_km(id, jd) / ZeclipticBodies.AU_KM
		_check(id + " vs DE421 J2000 2026-01-01 (AU, |dr|)", (got - de421_j2000[id]).length(), 0.0, 0.0003)
	if f != null:
		var E = JSON.parse_string(f.get_as_text())
		for id in ["mercury", "venus", "earth", "mars"]:
			var ref: Array = E[id][0]
			var got := ZeclipticBodies.helio_ecl_km(id, float(E["jd_tt"][0])) / ZeclipticBodies.AU_KM
			var want := Vector3(ref[0], ref[1], ref[2])
			_check(id + " vs ladder export (of-date, |dr| should be ~0.0063*r)", (got - want).length(), 0.0063 * want.length(), 0.004)
		var moon_ref: Array = E["moon_geo_km"][0]
		var moon_got := ZeclipticBodies.moon_offset_ecl_km("luna", float(E["jd_tt"][0]))
		_check("luna geocentric vs DE421 (km, |dr|)", (moon_got - Vector3(moon_ref[0], moon_ref[1], moon_ref[2])).length(), 0.0, 1500.0)
	else:
		print("skip: DE421 export not found at " + doc)

	# Sol's B0: -7.055 on 2026-03-20, ~0 on 2026-06-06, +7.066 on 2026-09-22 (video CH02, DE421)
	_check("B0 2026-03-20", ZeclipticBodies.sol_b0_deg(ZeclipticBodies.jd_from_ymd(2026, 3, 20.0)), -7.055, 0.08)
	_check("B0 2026-06-06", ZeclipticBodies.sol_b0_deg(ZeclipticBodies.jd_from_ymd(2026, 6, 6.0)), 0.0, 0.12)
	_check("B0 2026-09-22", ZeclipticBodies.sol_b0_deg(ZeclipticBodies.jd_from_ymd(2026, 9, 22.0)), 7.066, 0.08)

	# spin tilts (tilt_curve.json values, recomputed here from the poles)
	var zb := ZeclipticBodies.frame_basis("zecliptic")
	for pair in [["pluto", 119.14], ["earth", 26.13], ["mercury", 3.40], ["uranus", 97.90], ["venus", 173.58]]:
		var p: Vector3 = zb * ZeclipticBodies.pole_ecl(pair[0])
		_check(pair[0] + " spin tilt to Zecliptic", rad_to_deg(acos(clampf(p.z, -1, 1))), pair[1], 0.05)

	# Pis clocks
	_check("Luna Pis in one year", ZeclipticBodies.pis_elapsed("luna", jd, jd + 365.25636), 42.0, 0.01)
	_check("Charon Pis in one year", ZeclipticBodies.pis_elapsed("charon", jd, jd + 365.25636), 179.65, 0.02)

	# Charon from Pluto's surface at the sub-Charon point: 2 asin(606 / (19591.4 - 1188.3))
	var d := ZeclipticBodies.semi_major_axis_km("charon") - ZeclipticBodies.radius_km("pluto")
	_check("Charon angular diameter from Pluto surface", ZeclipticBodies.angular_diameter_deg(ZeclipticBodies.radius_km("charon"), d), 3.775, 0.01)

	# Charon's orbit lies in Pluto's equator: normal vs pole
	var n := ZeclipticBodies.moon_orbit_normal_ecl("charon")
	_check("Charon orbit normal vs Pluto pole (deg)", rad_to_deg(acos(clampf(n.dot(ZeclipticBodies.pole_ecl("pluto")), -1, 1))), 0.08, 0.01)

	# moon offset magnitude and period
	var c0 := ZeclipticBodies.moon_offset_ecl_km("charon", jd)
	var c1 := ZeclipticBodies.moon_offset_ecl_km("charon", jd + 6.387221)
	_check("Charon |r|", c0.length(), 19591.4, 0.1)
	_check("Charon returns after one period", (c1 - c0).length(), 0.0, 0.1)

	# Earth perihelion distance early January
	var r_peri := ZeclipticBodies.helio_ecl_km("earth", ZeclipticBodies.jd_from_ymd(2026, 1, 3.5)).length() / ZeclipticBodies.AU_KM
	_check("Earth distance 2026-01-03", r_peri, 0.9833, 0.0005)

	# Ceres: SBDB epoch position should have |r| between q and Q
	var ce := ZeclipticBodies.helio_ecl_km("ceres", 2461200.5).length() / ZeclipticBodies.AU_KM
	_check("Ceres |r| within [q,Q] (midpoint check loose)", ce, 2.7656, 0.25)

	# oddly-planed belt: Pallas / Juno / Hidalgo vs Psyche (named, plane ordinary)
	_check("Pallas i to Zecliptic", ZeclipticBodies.orbit_i_zecliptic_deg("pallas"), 36.46, 0.15)
	_check("Juno i to Zecliptic", ZeclipticBodies.orbit_i_zecliptic_deg("juno"), 15.28, 0.15)
	_check("Hidalgo i to Zecliptic", ZeclipticBodies.orbit_i_zecliptic_deg("hidalgo"), 38.65, 0.2)
	_check("Psyche i to Zecliptic (ordinary)", ZeclipticBodies.orbit_i_zecliptic_deg("psyche"), 7.06, 0.15)
	_check("Ceres i to Zecliptic (aligned with Sol)", ZeclipticBodies.orbit_i_zecliptic_deg("ceres"), 3.41, 0.15)
	_check("Pallas flagged odd", 1.0 if ZeclipticBodies.odd_plane("pallas") else 0.0, 1.0, 0.0)
	_check("Psyche not flagged odd", 1.0 if not ZeclipticBodies.odd_plane("psyche") else 0.0, 1.0, 0.0)
	_check("Hidalgo in odd_plane_ids", 1.0 if "hidalgo" in ZeclipticBodies.odd_plane_ids() else 0.0, 1.0, 0.0)

	# surface direction: north pole dir equals pole
	var sd := ZeclipticBodies.surface_dir_ecl("earth", jd, 90.0, 0.0)
	_check("Earth north pole surface dir = pole", sd.dot(ZeclipticBodies.pole_ecl("earth")), 1.0, 1e-6)

	print("zecliptic_numbers: %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)

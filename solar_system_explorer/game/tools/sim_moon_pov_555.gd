extends SceneTree
## Moon far-side orrery simulation — Mars retrograde 555 AD
## ─────────────────────────────────────────────────────────
## Computes and records the heliocentric position of every body at each step.
## Nothing is faked. Nothing is interpolated. Every JD is evaluated directly
## from the Keplerian polynomial — no step-by-step integration, therefore
## zero drift between steps.
##
## Coordinate frame throughout: J2000 ecliptic rectangular, AU.
##   +X = toward vernal equinox (J2000)
##   +Y = 90° east of vernal equinox (J2000)
##   +Z = ecliptic north pole (J2000)
##
## Bodies
##   earth  — heliocentric (Earth-Moon barycentre elements, standard)
##   moon   — geocentric from Meeus ch.47 principal terms (~10 arcmin)
##             absolute = earth_helio + moon_geo
##   mars   — heliocentric, Keplerian
##   flower — M44 NGC 2632, fixed at J2000 RA 8h40m24s Dec +19°59'18"
##             Distance ~520 ly → direction is constant to any precision
##             relevant to this simulation.
##
## POV: Moon far side (the side that always faces away from Earth).
##   position    = earth_helio + moon_geo
##   look_dir    = moon_geo.normalized()   (away from Earth = toward outer system)
##   When Moon is between Earth and Mars, this is the side closest to Mars.
##
## Accuracy notes
##   • Keplerian elements: Standish JPL, calibrated 1800–2050 AD.
##   • At 555 AD (~14.5 cy from J2000): longitude error ~2° for Mars.
##   • At Year 0  (~20.0 cy from J2000): longitude error ~5° for Mars.
##   • Moon: ±10 arcmin longitude from principal terms (Meeus ch.47).
##   • M44 direction: exact to J2000 catalogue precision.

const E := preload("res://scripts/Ephemeris.gd")

## M44 "the flower" — J2000 equatorial RA/Dec (SIMBAD/IAU)
const FLOWER_RA_H  := 8.6733    # 8h 40m 24s
const FLOWER_DEC   := 19.988    # +19° 59' 17"

## Angular separation threshold (degrees) to flag Moon near Mars.
const NEAR_THRESHOLD_DEG := 5.0

var _out: FileAccess

func _init() -> void:
	var out_path := "res://docs/video/orrery_555.jsonl"
	_out = FileAccess.open(out_path, FileAccess.WRITE)
	if _out == null:
		push_error("Cannot create " + out_path); quit(); return

	# ── Compute M44 ecliptic unit vector (fixed for all time) ────────────────
	# Step 1: equatorial rectangular unit vector at J2000
	var ra_r  := deg_to_rad(FLOWER_RA_H * 15.0)
	var dec_r := deg_to_rad(FLOWER_DEC)
	var flower_eq := Vector3(
		cos(dec_r) * cos(ra_r),
		cos(dec_r) * sin(ra_r),
		sin(dec_r)).normalized()
	# Step 2: rotate to J2000 ecliptic frame (t_cy = 0)
	var flower_ecl: Vector3 = E.equatorial_to_ecliptic(flower_eq, 0.0)
	# flower_ecl is now a unit vector in J2000 ecliptic coords pointing at M44.

	# ── Metadata header ───────────────────────────────────────────────────────
	_emit({
		"type": "metadata",
		"frame": "J2000 ecliptic rectangular",
		"units": {"positions": "AU", "distances": "AU or km as labelled", "angles": "degrees", "ra": "decimal hours"},
		"flower_m44": {
			"name": "M44 / NGC 2632 (the flower)",
			"ra_h": FLOWER_RA_H, "dec_deg": FLOWER_DEC,
			"j2000_ecl_unit_vector": _v3(flower_ecl),
			"distance_ly": 520, "note": "direction constant to any relevant precision"
		},
		"ephemeris": {
			"planets": "Standish JPL Keplerian, calibrated 1800-2050 AD",
			"moon": "Meeus ch.47 principal terms, ~10 arcmin longitude",
			"drift": "none — every JD evaluated independently from polynomial"
		},
		"accuracy_at_target_dates": {
			"555_AD": "Mars ecliptic longitude ~2 deg error vs VSOP87",
			"year_0_1BC": "Mars ecliptic longitude ~5 deg error vs VSOP87"
		}
	})

	# ── Snapshot A: Dec 25, Year 0 (1 BC, proleptic Gregorian) ───────────────
	var jd_y0  := E.julian_day(0, 12, 25.0)
	_emit_state(flower_ecl, jd_y0, "snapshot_year_0",
		"Dec 25, Year 0 (1 BC, astronomical year 0, proleptic Gregorian)")

	# ── Snapshot B: Dec 25, 555 AD (proleptic Gregorian) ─────────────────────
	var jd_555 := E.julian_day(555, 12, 25.0)
	_emit_state(flower_ecl, jd_555, "snapshot_555_ad",
		"Dec 25, 555 AD (proleptic Gregorian)")

	# ── Simulation: Sep 1, 557 AD → Apr 1, 558 AD (1-day steps) ─────────────
	# This spans the Mars retrograde window (model: ~Nov 23, 557 – ~Feb 11, 558)
	# with 83 days of direct-motion approach and 49 days of departure.
	var jd  := E.julian_day(557, 9, 1.0)
	var end := E.julian_day(558, 4, 1.0)
	while jd <= end:
		_emit_state(flower_ecl, jd, "sim", "")
		jd += 1.0

	_out.close()
	var abs_path := ProjectSettings.globalize_path(out_path)
	print("orrery written → " + abs_path)
	print("  snapshots: Year 0 (JD %.1f)  555 AD (JD %.1f)" % [jd_y0, jd_555])
	print("  sim: Sep 1 557 → Apr 1 558  (%d steps)" % [roundi((end - E.julian_day(557,9,1.0)) + 1)])
	quit()

## ── Core state computation ─────────────────────────────────────────────────

func _emit_state(flower_ecl: Vector3, jd: float,
		row_type: String, label: String) -> void:
	var t := E.centuries_since_j2000(jd)

	# ── 1. Earth heliocentric ecliptic, AU ────────────────────────────────────
	var earth_h := E.heliocentric_ecliptic_au(E.EARTH, jd)

	# ── 2. Moon geocentric ecliptic, AU ──────────────────────────────────────
	var moon_g  := E.moon_geocentric_ecliptic_au(jd)
	# Moon absolute (heliocentric) = Earth + Moon_geo
	var moon_h  := earth_h + moon_g
	# Far-side look direction = unit vector from Earth to Moon
	var moon_look := moon_g.normalized()   # pointing AWAY from Earth

	# ── 3. Mars heliocentric ecliptic, AU ─────────────────────────────────────
	var mars_h := E.heliocentric_ecliptic_au(E.MARS, jd)

	# ── 4. Derived geocentric vectors ─────────────────────────────────────────
	var mars_geo := mars_h - earth_h           # geocentric Mars (from Earth)
	var moon_geo_rd := _lon_lat(moon_g)        # geocentric Moon lon/lat

	# ── 5. Mars as seen from Moon far-side ────────────────────────────────────
	var mars_from_moon := mars_h - moon_h          # vector Moon → Mars
	var mars_moon_dir  := mars_from_moon.normalized()

	# RA/Dec from Moon POV
	var mars_eq_moon := E.ecliptic_to_equatorial(mars_from_moon, t)
	var mars_rd_moon := E.ra_dec_from_equatorial(mars_eq_moon)

	# ── 6. Mars as seen from Earth (geocentric reference) ─────────────────────
	var mars_eq_earth := E.ecliptic_to_equatorial(mars_geo, t)
	var mars_rd_earth := E.ra_dec_from_equatorial(mars_eq_earth)

	# ── 7. M44 direction from Moon (identical to from Earth — 520 ly away) ────
	# The Moon-Earth offset (0.0026 AU) vs. 520 ly is 1 part in 10^11. Ignore.
	var flower_sep_deg := rad_to_deg(
		acos(clampf(mars_moon_dir.dot(flower_ecl), -1.0, 1.0)))

	# ── 8. Retrograde state ───────────────────────────────────────────────────
	var retro       := E.is_retrograde(E.MARS, jd)
	var lon_rate    := E.longitude_rate_deg_per_day(E.MARS, jd)

	# ── 9. Moon between Earth and Mars? ──────────────────────────────────────
	# Yes when geocentric angular separation Moon-Mars < threshold.
	var moon_mars_sep := rad_to_deg(acos(clampf(
		moon_g.normalized().dot(mars_geo.normalized()), -1.0, 1.0)))
	var moon_between := moon_mars_sep < NEAR_THRESHOLD_DEG

	# ── Build record ──────────────────────────────────────────────────────────
	var rec := {
		"type": row_type,
		"jd": snapped(jd, 0.001),
		"date": E.date_label(jd),
		"earth": {
			"helio_ecl_au": _v3(earth_h),
			"ecl_lon_deg": snapped(_lon_lat(earth_h).x, 0.001),
			"ecl_lat_deg": snapped(_lon_lat(earth_h).y, 0.001),
			"dist_au":     snapped(earth_h.length(), 0.000001)
		},
		"moon": {
			"geo_ecl_au":        _v3(moon_g),
			"helio_ecl_au":      _v3(moon_h),
			"geo_dist_km":       snapped(moon_g.length() * E.KM_PER_AU, 1.0),
			"geo_lon_deg":       snapped(moon_geo_rd.x, 0.01),
			"geo_lat_deg":       snapped(moon_geo_rd.y, 0.01),
			"far_side_look_ecl": _v3(moon_look),
			"moon_between_earth_mars": moon_between,
			"moon_mars_sep_deg": snapped(moon_mars_sep, 0.01)
		},
		"mars": {
			"helio_ecl_au":      _v3(mars_h),
			"helio_lon_deg":     snapped(_lon_lat(mars_h).x, 0.001),
			"helio_lat_deg":     snapped(_lon_lat(mars_h).y, 0.001),
			"helio_dist_au":     snapped(mars_h.length(), 0.000001),
			"geo_dist_au":       snapped(mars_geo.length(), 0.000001),
			"from_earth_ra_h":   snapped(mars_rd_earth.x, 0.0001),
			"from_earth_dec_deg":snapped(mars_rd_earth.y, 0.001),
			"from_moon_ra_h":    snapped(mars_rd_moon.x, 0.0001),
			"from_moon_dec_deg": snapped(mars_rd_moon.y, 0.001),
			"retrograde":        retro,
			"ecl_lon_rate_deg_per_day": snapped(lon_rate, 0.0001)
		},
		"flower_m44": {
			"ra_h": FLOWER_RA_H,
			"dec_deg": FLOWER_DEC,
			"mars_sep_from_moon_deg": snapped(flower_sep_deg, 0.001),
			"mars_at_flower": flower_sep_deg < 1.0
		}
	}
	if not label.is_empty():
		rec["label"] = label
	_emit(rec)

## ── Helpers ────────────────────────────────────────────────────────────────

func _emit(d: Dictionary) -> void:
	_out.store_line(JSON.stringify(d))

func _v3(v: Vector3) -> Array:
	return [snapped(v.x, 0.000001), snapped(v.y, 0.000001), snapped(v.z, 0.000001)]

## Ecliptic longitude/latitude (degrees) from a rectangular vector.
func _lon_lat(v: Vector3) -> Vector2:
	if v.length() < 1e-12:
		return Vector2.ZERO
	var lon := fposmod(rad_to_deg(atan2(v.y, v.x)), 360.0)
	var lat := rad_to_deg(asin(clampf(v.z / v.length(), -1.0, 1.0)))
	return Vector2(lon, lat)

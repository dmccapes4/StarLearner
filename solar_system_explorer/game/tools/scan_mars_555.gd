extends SceneTree
## Scan Mars retrograde windows for years near 555 CE and report their
## midpoint RA/Dec and nearest constellation so we can find which model-year
## lands in the Castor–Pollux–Beehive corridor (RA 7.5–8.5h, Dec +20–30°).
const E := preload("res://scripts/Ephemeris.gd")
func _init():
	print("year | loop start              | mid RA | mid Dec | ecliptic lon")
	print("-----|-------------------------|--------|---------|-------------")
	var seen := {}
	for yr in range(540, 575):
		var jd0 := E.jd_at_year_start(yr)
		var w := E.retrograde_window("mars", jd0)
		if w.is_empty(): continue
		var key := "%d-%d" % [int(w["start"]), int(w["end"])]
		if seen.has(key): continue
		seen[key] = true
		var jd_mid := (float(w["start"]) + float(w["end"])) / 2.0
		var rd := E.ra_dec("mars", jd_mid)
		# Also compute ecliptic longitude at midpoint
		var t := E.centuries_since_j2000(jd_mid)
		var geo := E.geocentric_ecliptic_au("mars", jd_mid)
		var ecl_lon := fposmod(rad_to_deg(atan2(geo.y, geo.x)), 360.0)
		print("  %d  |  %s  |  %.2fh  |  %+.1f°  |  %.1f°" % [
			yr, E.date_label(float(w["start"])), rd.x, rd.y, ecl_lon])
	quit()

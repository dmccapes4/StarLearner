extends SceneTree
## Print retrograde STATION RA values for Mars near 555 CE.
## Station-1 = easternmost point (start retrograde)
## Station-2 = westernmost point (end retrograde)
## We want: station-1 ≈ 8.67h (Beehive), station-2 ≈ 7.76h (Pollux)
const E := preload("res://scripts/Ephemeris.gd")
func _init():
	print("yr  | sta1-RA | sta2-RA | mid-RA | mid-Dec | span(h)")
	print("----|---------|---------|--------|---------|--------")
	var seen := {}
	for yr in range(530, 580):
		var jd0 := E.jd_at_year_start(yr)
		var w := E.retrograde_window("mars", jd0)
		if w.is_empty(): continue
		var key := "%d-%d" % [int(w["start"]), int(w["end"])]
		if seen.has(key): continue
		seen[key] = true
		var rd1 := E.ra_dec("mars", float(w["start"]))
		var rd2 := E.ra_dec("mars", float(w["end"]))
		var jdm := (float(w["start"])+float(w["end"]))/2.0
		var rdm := E.ra_dec("mars", jdm)
		var span := rd1.x - rd2.x   ## station1 is further east (higher RA in direct)
		## label the year range for the retrograde
		print("  %d  |  %.2fh  |  %.2fh  |  %.2fh  |  %+.1f°  |  %.2fh  %s" % [
			yr, rd1.x, rd2.x, rdm.x, rdm.y, span,
			E.date_label(float(w["start"]))])
	quit()

extends SceneTree
const E := preload("res://scripts/Ephemeris.gd")
func _init():
	for yr in [554, 555, 556, 557]:
		var jd0 := E.jd_at_year_start(yr)
		var w := E.retrograde_window("mars", jd0)
		if w.is_empty():
			print("yr %d: no loop found" % yr)
		else:
			var jd_mid := (float(w["start"]) + float(w["end"])) / 2.0
			var rd := E.ra_dec("mars", jd_mid)
			# ra_dec returns RA in hours already
			print("yr %d  start=%s  end=%s  RA=%.2fh (%.0f deg)  Dec=%.1f" % [
				yr, E.date_label(float(w["start"])),
				E.date_label(float(w["end"])),
				rd.x, rd.x * 15.0, rd.y])
	quit()

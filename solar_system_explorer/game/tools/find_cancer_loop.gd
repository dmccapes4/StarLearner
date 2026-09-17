extends SceneTree
## Finds the years when Mars's retrograde loop falls across Cancer, arcing
## between Pollux and the Beehive Cluster.
##
## Cancer is a hard constellation to meet. Its brightest star is fourth
## magnitude, it holds no bright pattern, and the two things that mark it for the
## eye are borrowed: Pollux stands just outside it to the northwest, and the
## Beehive sits in its middle as a fuzzy patch rather than a point. A planet
## looping through it is the best introduction it gets.
##
## Mars's loop is about 15 degrees long, and Pollux and the Beehive are about 15
## degrees apart, so when the timing is right the loop spans almost exactly from
## one to the other. This finds those years rather than guessing at them.

const Ephemeris := preload("res://scripts/Ephemeris.gd")
const Exposure := preload("res://scripts/Exposure.gd")

## J2000 positions, right ascension in hours and declination in degrees.
## Pollux is the same figure the Gemini entry in ConstellationData plots.
const POLLUX := Vector2(7.7553, 28.026)
## M44, the Beehive: magnitude 3.1, the heart of Cancer, and a naked-eye object
## in a constellation that otherwise has almost nothing for the naked eye.
const BEEHIVE := Vector2(8.6733, 19.621)

const FIRST_YEAR := 1990
const LAST_YEAR := 2065

func _init() -> void:
	print("\n======== Mars retrograde over Cancer ========")
	print("Pollux  RA %.3fh Dec %+.2f" % [POLLUX.x, POLLUX.y])
	print("Beehive RA %.3fh Dec %+.2f  (%.1f deg apart)\n"
		% [BEEHIVE.x, BEEHIVE.y, _sep(POLLUX, BEEHIVE)])

	var found: Array = []
	var jd: float = Ephemeris.jd_at_year_start(FIRST_YEAR)
	var stop: float = Ephemeris.jd_at_year_start(LAST_YEAR)
	while jd < stop:
		var w: Dictionary = Ephemeris.retrograde_window("mars", jd)
		if w.is_empty():
			break
		var a: float = float(w["start"])
		var b: float = float(w["end"])
		if a >= stop:
			break
		found.append(_score_window(a, b))
		# Step past this window to find the next one.
		jd = b + 30.0

	found.sort_custom(func(x, y): return float(x["score"]) < float(y["score"]))
	print("-- ranked by how well the loop reaches BOTH markers --")
	for i in mini(10, found.size()):
		var r: Dictionary = found[i]
		print("%2d. %s  loop %s -> %s" % [i + 1, r["label"],
			Ephemeris.date_label(float(r["start"])),
			Ephemeris.date_label(float(r["end"]))])
		print("      nearest approach: Pollux %.1f deg, Beehive %.1f deg"
			% [float(r["d_pollux"]), float(r["d_beehive"])])
		print("      track spans RA %.2fh..%.2fh, Dec %+.1f..%+.1f, %.1f deg long"
			% [float(r["ra_lo"]), float(r["ra_hi"]),
				float(r["dec_lo"]), float(r["dec_hi"]), float(r["length"])])
	quit()

## Measure one retrograde window against the two markers.
##
## The exposure buffer holds 1.2 retrograde periods, so the track the player
## actually sees runs wider than the window itself -- it is scored over the same
## span the trail will draw, not just between the stations.
func _score_window(a: float, b: float) -> Dictionary:
	var span: float = Exposure.retrograde_schedule_days("mars")
	var mid: float = (a + b) * 0.5
	var from_jd: float = mid - span * 0.5
	var d_pollux := 1.0e9
	var d_beehive := 1.0e9
	var ra_lo := 99.0
	var ra_hi := -99.0
	var dec_lo := 99.0
	var dec_hi := -99.0
	var first := Vector2.ZERO
	var last := Vector2.ZERO
	var n := 120
	for i in n:
		var t: float = from_jd + span * float(i) / float(n - 1)
		var rd: Vector2 = Ephemeris.ra_dec("mars", t)
		d_pollux = minf(d_pollux, _sep(rd, POLLUX))
		d_beehive = minf(d_beehive, _sep(rd, BEEHIVE))
		ra_lo = minf(ra_lo, rd.x)
		ra_hi = maxf(ra_hi, rd.x)
		dec_lo = minf(dec_lo, rd.y)
		dec_hi = maxf(dec_hi, rd.y)
		if i == 0:
			first = rd
		last = rd
	# Score on the WORSE of the two approaches. A loop that sits on the Beehive
	# but never gets near Pollux does not arc between them, and averaging would
	# hide that.
	return {
		"score": maxf(d_pollux, d_beehive),
		"label": Ephemeris.date_label(a).right(4),
		"start": a, "end": b,
		"d_pollux": d_pollux, "d_beehive": d_beehive,
		"ra_lo": ra_lo, "ra_hi": ra_hi, "dec_lo": dec_lo, "dec_hi": dec_hi,
		"length": _sep(first, last),
	}

## Angular separation in degrees between two (RA hours, Dec degrees) points.
static func _sep(p: Vector2, q: Vector2) -> float:
	var ra1: float = deg_to_rad(p.x * 15.0)
	var ra2: float = deg_to_rad(q.x * 15.0)
	var d1: float = deg_to_rad(p.y)
	var d2: float = deg_to_rad(q.y)
	var c: float = sin(d1) * sin(d2) + cos(d1) * cos(d2) * cos(ra1 - ra2)
	return rad_to_deg(acos(clampf(c, -1.0, 1.0)))

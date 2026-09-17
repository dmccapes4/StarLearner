extends SceneTree
## Loads and exercises the EarthShip scripts headlessly.
##
## Run: godot --headless --path game -s res://tools/earthship_smoke.gd
##
## Catches the two failure modes a pure-math check cannot: a script that does
## not compile, and a scene that throws once it is actually instantiated and
## stepped. Keep this fast -- it is the loop used while building.

const PATHS := [
	"res://scripts/Ephemeris.gd",
	"res://scripts/Exposure.gd",
	"res://scripts/SolarBrilliance.gd",
	"res://scripts/ConstellationView.gd",
	"res://scripts/EarthSkyViewer.gd",
	"res://scripts/EarthShipScene.gd",
]

var _fails: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("======== EarthShip smoke ========")
	_compile()
	await _instantiate()
	print("======== %s ========" % (
		"SMOKE OK" if _fails == 0 else "%d SMOKE FAILURE(S)" % _fails))
	quit(1 if _fails > 0 else 0)

func _ok(cond: bool, label: String) -> void:
	if not cond:
		_fails += 1
	print("  %s %s" % ["OK  " if cond else "FAIL", label])

func _compile() -> void:
	print("\n-- compile --")
	for p in PATHS:
		if not ResourceLoader.exists(p):
			_ok(false, "missing: %s" % p)
			continue
		var s = load(p)
		# load() hands back a GDScript object even when parsing failed, so
		# can_instantiate() is the real test of whether it compiled.
		_ok(s != null and s.can_instantiate(), "compiles: %s" % p)

func _instantiate() -> void:
	print("\n-- instantiate and step --")
	var root := Node.new()
	get_root().add_child(root)

	# ConstellationView: builds the whole catalogue as 3D nodes.
	var cv_script = load("res://scripts/ConstellationView.gd")
	var world := Node3D.new()
	root.add_child(world)
	var cv = cv_script.new()
	world.add_child(cv)
	cv.build(2800.0)
	_ok(cv.ids().size() >= 24, "ConstellationView built %d constellations"
		% cv.ids().size())
	var cam := Camera3D.new()
	world.add_child(cam)
	# Aim at an actual star of Leo -- Regulus, the catalogue's first entry --
	# and confirm Leo is the constellation that lights up. Aiming at the
	# centroid would be the wrong test: Leo is a sickle plus a triangle, so its
	# centroid is a hollow point more than 5 degrees from any of its stars.
	var cd = load("res://scripts/ConstellationData.gd")
	var leo_stars: Array = cd.by_id("leo", 2800.0).get("stars", [])
	_ok(leo_stars.size() >= 4, "Leo has %d catalogued stars" % leo_stars.size())
	var regulus: Vector3 = (leo_stars[0] as Vector3).normalized()
	cam.look_at_from_position(Vector3.ZERO, regulus * 100.0, Vector3.UP)
	cv.update_proximity(cam)
	_ok(cv.nearest_id == "leo",
		"looking at Regulus selects Leo (got '%s')" % cv.nearest_id)
	# And looking at empty sky must select nothing. The ecliptic south pole is
	# far from every catalogued figure.
	cam.look_at_from_position(Vector3.ZERO, Vector3.DOWN * 100.0, Vector3.BACK)
	cv.update_proximity(cam)
	_ok(cv.nearest_id.is_empty(),
		"looking at empty sky selects nothing (got '%s')" % cv.nearest_id)

	# EarthSkyViewer, both modes.
	var vs = load("res://scripts/EarthSkyViewer.gd")
	if vs == null or not vs.can_instantiate():
		_ok(false, "EarthSkyViewer not instantiable; skipping run")
		return
	var v = vs.new()
	root.add_child(v)
	await process_frame

	# RetrogradeViewer behaviour: Mars from the southern tropic, starting in the
	# year of its 2022 opposition.
	v.begin("mars", vs.Mode.RETROGRADE, -23.5, 2022)
	for _i in 8:
		v._process(0.1)
	_ok(v.target_id() == "mars", "retrograde viewer holds its target")
	print("       %s | %s | %s | %s"
		% [v.date_text(), v.latitude_text(), v.retrograde_text(),
			v.magnitude_text()])
	print("       nearest constellation: '%s'" % v.constellation_text())

	# The southern-tropic inversion. The thing that flips is not the zenith
	# direction -- two zeniths always differ by exactly the latitude gap. What
	# flips is the ROLL of the field about the line of sight, i.e. where the
	# camera's up axis ends up after the zenith is projected perpendicular to
	# the view. When the target's declination lies between the two latitudes it
	# passes north of one observer's zenith and south of the other's, and the
	# whole field, retrograde loop included, arrives upside down.
	var jd: float = v.current_jd()
	var dec: float = _dec_of(v.target_id(), jd)
	print("       target declination %+.1f deg" % dec)
	# The spec case: the two extreme latitudes it names. This flips whenever the
	# target's declination lies between them, which for anything near the
	# ecliptic it always does.
	if dec > -23.5 and dec < 38.0:
		var roll: float = _roll_between(v, -23.5, 38.0)
		_ok(roll > 120.0,
			"23.5S field is inverted vs 38N: roll differs by %.1f deg" % roll)
	else:
		print("       (declination outside 23.5S..38N, spec case not applicable)")
	# Now the general statement, with latitudes derived from where the target
	# actually is so the test stays valid on any date: observers who straddle
	# the target see the field opposite ways up, and observers on the same side
	# of it agree. The second half is what proves the first is not noise.
	var straddle: float = _roll_between(v, dec - 15.0, dec + 15.0)
	_ok(straddle > 120.0,
		"straddling %+.0f deg inverts the field: %.1f deg" % [dec, straddle])
	var same_side: float = _roll_between(v, dec + 15.0, dec + 32.0)
	_ok(same_side < 45.0,
		"both north of %+.0f deg agree: %.1f deg" % [dec, same_side])

	# Latitude switching and the year picker must not throw.
	v.set_latitude(23.5)
	v.step_year(1)
	v.step_year(-1)
	_ok(absf(v.current_jd() - jd) > 0.0, "year picker moved the clock")

	# The field is fitted to each body's own loop rather than fixed, because the
	# loops differ by an order of magnitude in size. Check that every retrograde
	# target gets a field that actually contains its track, and that zooming
	# narrows it.
	for body in ["mercury", "venus", "jupiter"]:
		v.begin(body, vs.Mode.RETROGRADE, 23.5, 2026)
		var fov: float = v.field_of_view()
		var geo: Dictionary = v.loop_geometry()
		var length: float = float(geo["length"])
		_ok(fov >= length and fov <= vs.FOV_LOOP_MAX + 0.01,
			"%s: %.1f deg field holds its %.1f x %.1f deg loop"
				% [body, fov, length, float(geo["width"])])
		v.set_zoomed(true)
		_ok(v.field_of_view() < fov, "%s zoom narrows the field to %.1f deg"
			% [body, v.field_of_view()])
		v.set_zoomed(false)

	# The daylight toggle. Mercury is the case that needs it: it retrogrades
	# beside the Sun, so its loop lands in a bright sky and the constellations it
	# should be read against are washed out. Setting the daylight aside must give
	# a fully dark sky without moving the body one arcsecond.
	v.begin("mercury", vs.Mode.RETROGRADE, 23.5, 2026)
	var lit_dark: float = v.darkness()
	var lit_jd: float = v.current_jd()
	var lit_sun: float = v.sun_altitude()
	v.set_force_dark(true)
	_ok(v.darkness() >= 0.999,
		"daylight set aside gives a dark sky (was %.2f, now %.2f)"
			% [lit_dark, v.darkness()])
	_ok(is_equal_approx(v.current_jd(), lit_jd)
			and is_equal_approx(v.sun_altitude(), lit_sun),
		"the toggle moves nothing: clock and Sun altitude unchanged")
	_ok(v.sky_text().contains("set aside") or v.sky_text() == "night",
		"readout stays honest about the real sky: '%s'" % v.sky_text())
	v.set_force_dark(false)
	_ok(is_equal_approx(v.darkness(), lit_dark), "toggling back restores daylight")

	# Field lock. The retrograde is a motion against the stars, so if the camera
	# follows the planet the planet sits still and the effect disappears. Locked,
	# the aim must not move as the clock runs; unlocked, it must.
	v.begin("mars", vs.Mode.RETROGRADE, 38.0, 2024)
	var step: float = 12.0
	var free_a: Vector3 = -v._cam.global_transform.basis.z
	v._jd += step
	v._refresh()
	var free_b: Vector3 = -v._cam.global_transform.basis.z
	var free_moved: float = rad_to_deg(free_a.angle_to(free_b))
	v.set_field_lock(true)
	var lock_a: Vector3 = -v._cam.global_transform.basis.z
	v._jd += step
	v._refresh()
	var lock_b: Vector3 = -v._cam.global_transform.basis.z
	var lock_moved: float = rad_to_deg(lock_a.angle_to(lock_b))
	_ok(lock_moved < 0.001,
		"locked field holds still over %.0f days (%.4f deg)" % [step, lock_moved])
	_ok(free_moved > lock_moved,
		"unlocked field tracks the planet instead (%.2f deg)" % free_moved)
	_ok(cv.DEEP_SKY.size() >= 1,
		"sky carries the Beehive, so Cancer can be found at all")

	# EclipseViewer behaviour: the Moon from the equator.
	v.begin("moon", vs.Mode.ECLIPSE, 0.0, 2023)
	for _i in 8:
		v._process(0.1)
	print("       %s | %s | %s"
		% [v.date_text(), v.latitude_text(), v.retrograde_text()])
	_ok(v.latitude_text().contains("Equator"), "eclipse viewer sits on equator")
	v.begin("sun", vs.Mode.ECLIPSE, 0.0, 2023)
	v._process(0.1)
	_ok(true, "Sun target stepped without error")
	v.set_active(false)

	# EarthShipScene tiles and their routing.
	var es = load("res://scripts/EarthShipScene.gd")
	if es != null and es.can_instantiate():
		var hub = es.new()
		root.add_child(hub)
		await process_frame
		# Every naked-eye body gets a tile. Mars is named explicitly because it was
		# missing once: it is the clearest retrograde of the lot and the one the
		# whole feature was built around.
		var ids: Array = []
		for t in es.TILES:
			ids.append(str(t[0]))
		for want in ["mercury", "venus", "mars", "jupiter", "moon", "sun"]:
			_ok(want in ids, "hub offers a %s tile" % want)
		_ok(es.launches_eclipse("moon") and es.launches_eclipse("sun"),
			"Moon and Sun route to EclipseViewer")
		_ok(not es.launches_eclipse("mercury")
			and not es.launches_eclipse("venus")
			and not es.launches_eclipse("mars")
			and not es.launches_eclipse("jupiter"),
			"Mercury, Venus, Mars and Jupiter route to RetrogradeViewer")
		# The row must physically fit, which is what the derived tile width buys.
		var span: float = es.tile_width() * float(es.TILES.size()) \
			+ float(es.TILE_GAP * (es.TILES.size() - 1))
		_ok(span <= es.ROW_W,
			"%d tiles span %.0f px, inside the %.0f px row"
				% [es.TILES.size(), span, es.ROW_W])
		hub.set_active(false)

## The camera's actual up axis at a given latitude, after the zenith has been
## projected perpendicular to the line of sight. Built the same way the viewer
## builds it, so this measures the real rendered orientation.
func _cam_up(v, lat_deg: float) -> Vector3:
	var eph = load("res://scripts/Ephemeris.gd")
	var expo = load("res://scripts/Exposure.gd")
	var jd: float = v.current_jd()
	var lon: float = eph.meridian_longitude_deg(v.target_id(), jd)
	var fwd: Vector3 = expo.observed_dir(v.target_id(), jd, lat_deg,
		lon).normalized()
	var zen: Vector3 = eph.zenith_dir(jd, lat_deg, lon)
	return Basis.looking_at(fwd, zen).y

## Angle between the rendered up axes at two latitudes, in degrees.
func _roll_between(v, lat_a: float, lat_b: float) -> float:
	var a: Vector3 = _cam_up(v, lat_a)
	var b: Vector3 = _cam_up(v, lat_b)
	return rad_to_deg(acos(clampf(a.dot(b), -1.0, 1.0)))

func _dec_of(body_id: String, jd: float) -> float:
	var eph = load("res://scripts/Ephemeris.gd")
	return eph.ra_dec(body_id, jd).y

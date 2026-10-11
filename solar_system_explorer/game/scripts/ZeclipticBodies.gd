class_name ZeclipticBodies
extends RefCounted
## Data and math for the Zecliptic Flight mode. Everything comes from
## res://data/zecliptic_bodies.json (written by tools/zecliptic_export.py);
## nothing numeric is typed here except J2000's obliquity and the epoch.
##
## Units: kilometres and Julian days throughout. Display unit is R☉
## (Sol-centre to the photosphere). Classical AU is a table unit only —
## Standish / SBDB store `a` that way — and is converted to km at the
## Kepler boundary. It is not shown on screen.

const PATH := "res://data/zecliptic_bodies.json"
const J2000 := 2451545.0
const OBLIQ_J2000_DEG := 23.439291
const AU_KM := 1.495978707e8   ## table unit only (lossy Earth-orbit length)
const R_SOL_KM_FALLBACK := 695700.0
const DAY_S := 86400.0

static func r_sol_km() -> float:
	var r := radius_km("sol")
	return r if r > 1.0 else R_SOL_KM_FALLBACK

## Sol-radii: centre of Sol to the bubbling surface is 1.
static func rsol(km: float) -> float:
	return km / r_sol_km()

static func km_from_rsol(n: float) -> float:
	return n * r_sol_km()

static var _data: Dictionary = {}
static var _pole_cache: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f == null:
			push_error("ZeclipticBodies: cannot open " + PATH)
			return {}
		var parsed = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			_data = parsed
	return _data

static func bodies() -> Dictionary:
	return data().get("bodies", {})

static func body(id: String) -> Dictionary:
	return bodies().get(id, {})

static func ids_by_distance() -> Array:
	## Sol first, then everything by semi-major axis (moons right after their parent).
	var planets: Array = []
	for id in bodies():
		var b: Dictionary = bodies()[id]
		if b.get("parent", null) == "sol":
			planets.append(id)
	planets.sort_custom(func(a, b): return _a_au(a) < _a_au(b))
	var out: Array = ["sol"]
	for p in planets:
		out.append(p)
		var moons: Array = []
		for id in bodies():
			if bodies()[id].get("parent", null) == p:
				moons.append(id)
		moons.sort_custom(func(a, b): return float(body(a)["a_km"]) < float(body(b)["a_km"]))
		out.append_array(moons)
	return out

static func _a_au(id: String) -> float:
	var b := body(id)
	if b.has("elements"):
		return float(b["elements"]["a"])
	if b.has("sbdb"):
		return float(b["sbdb"]["a"])
	return 0.0

static func semi_major_axis_km(id: String) -> float:
	var b := body(id)
	if b.has("a_km"):
		return float(b["a_km"])
	return _a_au(id) * AU_KM

static func radius_km(id: String) -> float:
	return float(body(id).get("radius_km", 1.0))

static func period_d(id: String) -> float:
	return absf(float(body(id).get("period_d", 0.0)))

# ── Frames ──────────────────────────────────────────────────────────────

## Basis that takes a J2000-ecliptic vector into the named plane's frame:
## x along the plane's ascending node on the ecliptic, z the plane's pole.
## v_frame = Rx(-i) * Rz(-node) * v_ecl.
static func frame_basis(frame_id: String, body_for_equator: String = "") -> Basis:
	if frame_id == "body" and body_for_equator != "":
		return equator_basis(body_for_equator)
	var fr: Dictionary = data().get("frames", {}).get(frame_id, {})
	if fr.is_empty():
		return Basis.IDENTITY
	var i := deg_to_rad(float(fr["i_deg"]))
	var node := deg_to_rad(float(fr["node_deg"]))
	var rz := Basis(Vector3(0, 0, 1), -node)
	var rx := Basis(Vector3(1, 0, 0), -i)
	return rx * rz

## Frame whose z is the body's right-hand-rule spin pole (J2000 ecliptic),
## x along the ascending node of its equator on the ecliptic.
static func equator_basis(id: String) -> Basis:
	var p := pole_ecl(id)
	var x := Vector3(0, 0, 1).cross(p)
	if x.length() < 1.0e-9:
		x = Vector3(1, 0, 0)
	x = x.normalized()
	var y := p.cross(x).normalized()
	# rows of the basis are the frame axes expressed in ecliptic coordinates,
	# so that basis * v_ecl gives frame components
	return Basis(x, y, p).transposed()

## Unit spin-pole vector in J2000 ecliptic coordinates (right-hand rule).
static func pole_ecl(id: String) -> Vector3:
	if _pole_cache.has(id):
		return _pole_cache[id]
	var b := body(id)
	var p: Vector3
	if b.has("pole_radec_j2000") and b["pole_radec_j2000"] != null:
		var ra := deg_to_rad(float(b["pole_radec_j2000"][0]))
		var dec := deg_to_rad(float(b["pole_radec_j2000"][1]))
		var eq := Vector3(cos(dec) * cos(ra), cos(dec) * sin(ra), sin(dec))
		p = equatorial_to_ecliptic(eq)
		if bool(b.get("pole_right_hand_flipped", false)):
			p = -p
	elif b.get("kind", "") == "moon":
		# synchronous moons spin about their orbit normal
		p = moon_orbit_normal_ecl(id)
	else:
		p = Vector3(0, 0, 1)
	_pole_cache[id] = p
	return p

static func equatorial_to_ecliptic(v: Vector3) -> Vector3:
	var e := deg_to_rad(OBLIQ_J2000_DEG)
	return Vector3(v.x, cos(e) * v.y + sin(e) * v.z, -sin(e) * v.y + cos(e) * v.z)

## Frame vector -> Godot (Y up = frame pole; frame x (node) -> -Z).
static func to_godot(v: Vector3) -> Vector3:
	return Vector3(v.y, v.z, -v.x)

static func from_godot(v: Vector3) -> Vector3:
	return Vector3(-v.z, v.x, v.y)

# ── Kepler ──────────────────────────────────────────────────────────────

static func solve_kepler(m_rad: float, e: float) -> float:
	var m: float = wrapf(m_rad, -PI, PI)
	var ecc: float = clampf(e, 0.0, 0.97)
	var ea: float = m if ecc < 0.8 else PI
	for _i in 16:
		var f: float = ea - ecc * sin(ea) - m
		var fp: float = 1.0 - ecc * cos(ea)
		ea -= f / maxf(fp, 1.0e-9)
		if absf(f) < 1.0e-12:
			break
	return ea

## Position from classical elements (deg, AU) in the J2000 ecliptic, km.
static func kepler_pos_km(a_au: float, e: float, i_deg: float, node_deg: float,
		arg_deg: float, m_deg: float) -> Vector3:
	var inc := deg_to_rad(i_deg)
	var node := deg_to_rad(node_deg)
	var arg := deg_to_rad(arg_deg)
	var ea := solve_kepler(deg_to_rad(m_deg), e)
	var xv := a_au * (cos(ea) - e)
	var yv := a_au * sqrt(maxf(1.0 - e * e, 0.0)) * sin(ea)
	var cw := cos(arg); var sw := sin(arg)
	var cn := cos(node); var sn := sin(node)
	var ci := cos(inc); var si := sin(inc)
	return Vector3(
		(cw * cn - sw * sn * ci) * xv + (-sw * cn - cw * sn * ci) * yv,
		(cw * sn + sw * cn * ci) * xv + (-sw * sn + cw * cn * ci) * yv,
		(sw * si) * xv + (cw * si) * yv) * AU_KM

## Standish elements with secular rates, evaluated at jd.
static func planet_elements(id: String, jd: float) -> Dictionary:
	var el: Dictionary = body(id).get("elements", {})
	if el.is_empty():
		return {}
	var t := (jd - J2000) / 36525.0
	return {
		"a": float(el["a"]) + float(el["a_dot"]) * t,
		"e": float(el["e"]) + float(el["e_dot"]) * t,
		"i": float(el["i"]) + float(el["i_dot"]) * t,
		"l": float(el["l"]) + float(el["l_dot"]) * t,
		"peri": float(el["peri"]) + float(el["peri_dot"]) * t,
		"node": float(el["node"]) + float(el["node_dot"]) * t,
	}

## Position of `id` relative to `ref_id` in the J2000 ecliptic, km, computed
## so that bodies sharing a parent subtract only their (small, precise) offsets.
## Vector3 is 32-bit; a Pluto-centred scene would otherwise jitter by ~350 km.
## Returns a PackedFloat64Array [x, y, z].
static func rel_ecl_km64(id: String, ref_id: String, jd: float) -> PackedFloat64Array:
	var a := _chain64(id, jd)
	var b := _chain64(ref_id, jd)
	# a = [planet_x,y,z, off_x,y,z, planet_id]; subtract planet parts only when they differ
	var out := PackedFloat64Array([0.0, 0.0, 0.0])
	if a[6] != b[6]:
		for k in 3:
			out[k] = float(a[k]) - float(b[k])
	for k in 3:
		out[k] += float(a[3 + k]) - float(b[3 + k])
	return out

static func _chain64(id: String, jd: float) -> Array:
	## [planet xyz (km), offset-from-planet xyz (km), planet id]
	var b := body(id)
	if id == "sol" or b.is_empty():
		return [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, "sol"]
	if id == "bary":
		var c := barycentre_ecl_km(jd)
		return [0.0, 0.0, 0.0, c.x, c.y, c.z, "sol"]
	if b.get("kind", "") == "moon":
		var par := str(b["parent"])
		var pp := helio_ecl_km(par, jd)
		var off := moon_offset_ecl_km(id, jd)
		return [pp.x, pp.y, pp.z, off.x, off.y, off.z, par]
	var p := helio_ecl_km(id, jd)
	return [p.x, p.y, p.z, 0.0, 0.0, 0.0, id]

## Heliocentric J2000-ecliptic position, km, for anything orbiting Sol.
static func helio_ecl_km(id: String, jd: float) -> Vector3:
	var b := body(id)
	if id == "sol" or b.is_empty():
		return Vector3.ZERO
	if b.has("elements"):
		var el := planet_elements(id, jd)
		return kepler_pos_km(el["a"], el["e"], el["i"], el["node"],
			el["peri"] - el["node"], el["l"] - el["peri"])
	if b.has("sbdb"):
		var s: Dictionary = b["sbdb"]
		var n := 360.0 / float(s["period_d"])
		var m := float(s["ma"]) + n * (jd - float(s["epoch_jd"]))
		return kepler_pos_km(float(s["a"]), float(s["e"]), float(s["i"]), float(s["node"]), float(s["w"]), m)
	if b.get("kind", "") == "moon":
		return helio_ecl_km(str(b["parent"]), jd) + moon_offset_ecl_km(id, jd)
	return Vector3.ZERO

## Belt-sample member position (index into data.belt.sample).
static func belt_pos_km(idx: int, jd: float) -> Vector3:
	var s: Dictionary = data()["belt"]["sample"][idx]
	var a := float(s["a"])
	var per_d := 365.25636 * pow(a, 1.5)
	var m := float(s["ma"]) + 360.0 / per_d * (jd - J2000)
	return kepler_pos_km(a, float(s["e"]), float(s["i"]), float(s["node"]), float(s["w"]), m)

# ── Moons ───────────────────────────────────────────────────────────────

## Orbit normal of a moon in the ecliptic: the parent's pole tilted by the
## catalogued inclination (about the parent's equatorial node line).
static func moon_orbit_normal_ecl(id: String) -> Vector3:
	var b := body(id)
	if id == "luna":
		# Luna's orbit is ~5 deg from the ecliptic with a regressing node;
		# Meeus supplies its real position, so the normal here is the
		# ecliptic pole (used only for the drawn orbit ring).
		return Vector3(0, 0, 1)
	var p := pole_ecl(str(b["parent"]))
	var x := Vector3(0, 0, 1).cross(p)
	if x.length() < 1.0e-9:
		x = Vector3(1, 0, 0)
	x = x.normalized()
	return p.rotated(x, deg_to_rad(float(b.get("i_deg", 0.0)))).normalized()

## Moon position relative to its parent, km, J2000 ecliptic.
static func moon_offset_ecl_km(id: String, jd: float) -> Vector3:
	var b := body(id)
	if id == "luna":
		return Ephemeris.moon_geocentric_ecliptic_au(jd) * AU_KM
	var n := moon_orbit_normal_ecl(id)
	var e1 := Vector3(0, 0, 1).cross(n)
	if e1.length() < 1.0e-9:
		e1 = Vector3(1, 0, 0)
	e1 = e1.normalized()
	var e2 := n.cross(e1).normalized()
	var per := absf(float(b["period_d"]))
	var th := TAU * (jd - J2000) / per
	var a := float(b["a_km"])
	return (e1 * cos(th) + e2 * sin(th)) * a

# ── Spin / surface ──────────────────────────────────────────────────────

## Body-fixed basis in the ecliptic frame: z = spin pole, x = prime meridian
## direction. The prime meridian's zero is arbitrary (W0 is not in the data);
## for synchronous moons x points at the parent so sub-primary longitude is 0.
static func body_basis_ecl(id: String, jd: float) -> Basis:
	var p := pole_ecl(id)
	var b := body(id)
	var x: Vector3
	if b.get("kind", "") == "moon" and bool(b.get("synchronous", false)):
		var to_parent := -moon_offset_ecl_km(id, jd)
		x = (to_parent - p * to_parent.dot(p)).normalized()
	else:
		x = Vector3(0, 0, 1).cross(p)
		if x.length() < 1.0e-9:
			x = Vector3(1, 0, 0)
		x = x.normalized()
		var rot_d := float(b.get("rot_d", 0.0) if b.get("rot_d") != null else 0.0)
		if absf(rot_d) > 1.0e-9:
			x = x.rotated(p, TAU * (jd - J2000) / rot_d)
	var y := p.cross(x).normalized()
	return Basis(x, y, p)   # columns = body axes in ecliptic coords

## Unit vector (ecliptic) from the body's centre to the surface point at
## planetographic latitude/longitude (deg).
static func surface_dir_ecl(id: String, jd: float, lat_deg: float, lon_deg: float) -> Vector3:
	var bb := body_basis_ecl(id, jd)
	var la := deg_to_rad(lat_deg)
	var lo := deg_to_rad(lon_deg)
	var local := Vector3(cos(la) * cos(lo), cos(la) * sin(lo), sin(la))
	return (bb * local).normalized()

## Latitude of the tropics / polar circles from the body's obliquity to its orbit.
static func tropic_lat_deg(id: String) -> float:
	var ob := float(body(id).get("obliquity_deg", 0.0) if body(id).get("obliquity_deg") != null else 0.0)
	if ob > 90.0:
		ob = 180.0 - ob
	return ob

static func polar_circle_lat_deg(id: String) -> float:
	return 90.0 - tropic_lat_deg(id)

# ── Derived quantities ──────────────────────────────────────────────────

## Mass-weighted barycentre of Sol and the planets, km, ecliptic.
static func barycentre_ecl_km(jd: float) -> Vector3:
	var msum := float(body("sol")["mass_kg"])
	var acc := Vector3.ZERO
	for id in ["mercury", "venus", "earth", "mars", "jupiter", "saturn", "uranus", "neptune", "pluto"]:
		var m := float(body(id).get("mass_kg", 0.0))
		acc += helio_ecl_km(id, jd) * m
		msum += m
	return acc / msum

## Heliocentric latitude of a body in a frame (deg): the body's own "B0".
static func latitude_in_frame_deg(id: String, jd: float, fb: Basis) -> float:
	var v := fb * helio_ecl_km(id, jd)
	if v.length() < 1.0:
		return 0.0
	return rad_to_deg(asin(clampf(v.z / v.length(), -1.0, 1.0)))

## Sol's B0 as seen from Earth = heliographic latitude of the sub-Earth point
## = Earth's latitude in the Zecliptic frame.
static func sol_b0_deg(jd: float) -> float:
	return latitude_in_frame_deg("earth", jd, frame_basis("zecliptic"))

static func angular_diameter_deg(radius_km: float, dist_km: float) -> float:
	if dist_km <= radius_km:
		return 180.0
	return rad_to_deg(2.0 * asin(radius_km / dist_km))

## Pis elapsed for a moon since jd0: orbits x pi.
static func pis_elapsed(id: String, jd0: float, jd: float) -> float:
	var per := period_d(id)
	if per <= 0.0:
		return 0.0
	return (jd - jd0) / per * PI

static func odd_plane(id: String) -> bool:
	return bool(body(id).get("odd_plane", false))

static func odd_plane_ids() -> Array:
	var listed: Array = data().get("odd_plane_ids", [])
	if not listed.is_empty():
		return listed
	var out: Array = []
	for id in bodies():
		if odd_plane(id):
			out.append(id)
	return out

## Orbit inclination to the Zecliptic (not spin tilt). Pulled from the JSON
## when present; otherwise computed from the ecliptic (i, Ω) of the body.
static func orbit_i_zecliptic_deg(id: String) -> float:
	var b := body(id)
	if b.get("i_zecliptic_deg") != null:
		return float(b["i_zecliptic_deg"])
	var i := 0.0
	var node := 0.0
	if b.has("elements"):
		i = float(b["elements"]["i"])
		node = float(b["elements"]["node"])
	elif b.has("sbdb"):
		i = float(b["sbdb"]["i"])
		node = float(b["sbdb"]["node"])
	elif b.get("i_ecl_deg") != null:
		i = float(b["i_ecl_deg"])
		node = float(b.get("omega_node_deg", 0.0))
	else:
		return 0.0
	var zb := frame_basis("zecliptic")
	var inc := deg_to_rad(i)
	var O := deg_to_rad(node)
	var pole := Vector3(sin(inc) * sin(O), -sin(inc) * cos(O), cos(inc))
	var z := zb * pole
	return rad_to_deg(acos(clampf(z.z, -1.0, 1.0)))

static func spin_tilt_to_zecliptic_deg(id: String) -> float:
	var b := body(id)
	if b.get("spin_tilt_to_zecliptic_deg") != null:
		return float(b["spin_tilt_to_zecliptic_deg"])
	var zb := frame_basis("zecliptic")
	var p := zb * pole_ecl(id)
	return rad_to_deg(acos(clampf(p.z, -1.0, 1.0)))

static func jd_from_ymd(y: int, m: int, d: float) -> float:
	return Ephemeris.julian_day(y, m, d)

static func date_label(jd: float) -> String:
	return Ephemeris.date_label(jd)

static func calendar(jd: float) -> Dictionary:
	return Ephemeris.calendar_date(jd)

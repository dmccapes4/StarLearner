class_name SolarData
extends RefCounted
## Single source of truth for the bodies in the preview: the Sun, the eight
## planets, and Pluto (flagged as a dwarf planet). Kept as plain data so the
## layout + ordering can be unit-tested headlessly.
##
## Sizes and orbit radii are deliberately NOT to scale — they are chosen to read
## clearly for a six-year-old on a 1280x600 landscape panel.

## One record per body. Fields (2D preview + 3D flyer almanac):
##   id / name / color / ring / draw_radius / orbit_index / orrery_rx / period
##   is_star / dwarf / belt / blurb / facts
##   a_au          real semi-major axis (AU); 0 for the Sun
##   period_yr     sidereal period in Earth years; 0 for Sun / non-orbiting
##   real_radius_km  approximate mean radius (km); 0 for the belt
## Flyer-derived fields (orbit_r, omega, hero_r, theta0, spin) come from
## flyer_bodies() — never store them raw so knobs stay live.
static func bodies() -> Array:
	return [
		{
			"id": "sun", "name": "The Sun", "color": Color(1.0, 0.80, 0.24),
			"ring": false, "draw_radius": 150.0, "orbit_index": -1,
			"orrery_rx": 0.0, "period": 0.0, "is_star": true, "dwarf": false,
			"a_au": 0.0, "period_yr": 0.0, "real_radius_km": 695700.0,
			"blurb": "This is the Sun. It is a giant star at the center of everything, and its light and warmth reach all the way to Earth.",
			"facts": ["A star, not a planet", "All the planets circle around it", "So big a million Earths could fit inside"],
		},
		{
			"id": "mercury", "name": "Mercury", "color": Color(0.66, 0.63, 0.60),
			"ring": false, "draw_radius": 34.0, "orbit_index": 0,
			"orrery_rx": 90.0, "period": 6.0, "is_star": false, "dwarf": false,
			"a_au": 0.39, "period_yr": 0.24, "real_radius_km": 2440.0,
			"blurb": "Mercury is the closest planet to the Sun, and the smallest planet. A whole year there is only eighty-eight days.",
			"facts": ["Closest to the Sun", "The smallest planet", "No air to breathe"],
		},
		{
			"id": "venus", "name": "Venus", "color": Color(0.90, 0.72, 0.40),
			"ring": false, "draw_radius": 52.0, "orbit_index": 1,
			"orrery_rx": 150.0, "period": 8.0, "is_star": false, "dwarf": false,
			"a_au": 0.72, "period_yr": 0.62, "real_radius_km": 6052.0,
			"blurb": "Venus is the hottest planet, wrapped in thick clouds. It even spins backwards compared to the others.",
			"facts": ["The hottest planet", "Covered in thick clouds", "Spins backwards"],
		},
		{
			"id": "earth", "name": "Earth", "color": Color(0.28, 0.55, 0.85),
			"ring": false, "draw_radius": 54.0, "orbit_index": 2,
			"orrery_rx": 210.0, "period": 10.0, "is_star": false, "dwarf": false,
			"a_au": 1.0, "period_yr": 1.0, "real_radius_km": 6371.0,
			"blurb": "Earth is our home. It is the only planet we know that has life, with lots of water and one moon.",
			"facts": ["Our home planet", "The only one with life we know of", "Mostly covered in water"],
		},
		{
			"id": "mars", "name": "Mars", "color": Color(0.80, 0.36, 0.22),
			"ring": false, "draw_radius": 40.0, "orbit_index": 3,
			"orrery_rx": 270.0, "period": 12.0, "is_star": false, "dwarf": false,
			"a_au": 1.52, "period_yr": 1.88, "real_radius_km": 3390.0,
			"blurb": "Mars is the red planet, covered in rusty dust. It has the tallest volcano in the whole solar system.",
			"facts": ["The red planet", "Covered in rusty dust", "Has the tallest volcano"],
		},
		{
			"id": "asteroid_belt", "name": "Asteroid Belt", "color": Color(0.62, 0.58, 0.52),
			"ring": false, "draw_radius": 74.0, "orbit_index": -1, "belt": true,
			"orrery_rx": 305.0, "period": 0.0, "is_star": false, "dwarf": false,
			"a_au": 2.7, "period_yr": 4.6, "real_radius_km": 0.0,
			"blurb": "Between Mars and Jupiter is the asteroid belt, a wide ring of rocky chunks left over from when the planets formed.",
			"facts": ["A ring of rocky chunks", "Sits between Mars and Jupiter", "Leftovers from the young solar system"],
		},
		{
			"id": "jupiter", "name": "Jupiter", "color": Color(0.82, 0.66, 0.48),
			"ring": false, "draw_radius": 112.0, "orbit_index": 4,
			"orrery_rx": 340.0, "period": 15.0, "is_star": false, "dwarf": false,
			"a_au": 5.2, "period_yr": 11.86, "real_radius_km": 69911.0,
			"blurb": "Jupiter is the biggest planet, a giant ball of gas. Its Great Red Spot is a storm bigger than the whole Earth.",
			"facts": ["The biggest planet", "A giant ball of gas", "Has a storm bigger than Earth"],
		},
		{
			"id": "saturn", "name": "Saturn", "color": Color(0.86, 0.78, 0.55),
			"ring": true, "draw_radius": 94.0, "orbit_index": 5,
			"orrery_rx": 410.0, "period": 18.0, "is_star": false, "dwarf": false,
			"a_au": 9.58, "period_yr": 29.5, "real_radius_km": 58232.0,
			"blurb": "Saturn has beautiful rings made of ice and rock. It is so light that it could float in water.",
			"facts": ["Famous for its rings", "Rings are ice and rock", "Light enough to float in water"],
		},
		{
			"id": "uranus", "name": "Uranus", "color": Color(0.55, 0.82, 0.85),
			"ring": false, "draw_radius": 72.0, "orbit_index": 6,
			"orrery_rx": 480.0, "period": 21.0, "is_star": false, "dwarf": false,
			"a_au": 19.2, "period_yr": 84.0, "real_radius_km": 25362.0,
			"blurb": "Uranus is a cold, blue-green planet. It is tipped over, so it rolls on its side like a ball.",
			"facts": ["A cold blue-green world", "Rolls on its side", "Made mostly of icy gas"],
		},
		{
			"id": "neptune", "name": "Neptune", "color": Color(0.24, 0.40, 0.90),
			"ring": false, "draw_radius": 68.0, "orbit_index": 7,
			"orrery_rx": 550.0, "period": 24.0, "is_star": false, "dwarf": false,
			"a_au": 30.05, "period_yr": 165.0, "real_radius_km": 24622.0,
			"blurb": "Neptune is a deep blue, windy world. It is the farthest big planet from the Sun.",
			"facts": ["A deep blue planet", "The windiest world", "Farthest big planet from the Sun"],
		},
		{
			"id": "pluto", "name": "Pluto", "color": Color(0.78, 0.70, 0.62),
			"ring": false, "draw_radius": 26.0, "orbit_index": -1,
			"orrery_rx": 0.0, "period": 0.0, "is_star": false, "dwarf": true,
			"a_au": 39.5, "period_yr": 248.0, "real_radius_km": 1188.0,
			"blurb": "Pluto used to be called the ninth planet. Now it is a dwarf planet, because it is small and shares its faraway space with other icy worlds.",
			"facts": ["Not a planet anymore", "Now called a dwarf planet", "Small and very far away"],
		},
	]

## Bodies enriched with flyer geometry (orbit_r, omega, hero_r, theta0, spin).
## Safe to call every frame — cheap dict copies keyed off cfg.
static func flyer_bodies(cfg: SolarFlyerConfig = null) -> Array:
	if cfg == null:
		cfg = SolarFlyerConfig.load_default()
	var raw := bodies()
	# Size ranks among non-star, non-belt bodies by real_radius_km.
	var sized: Array = []
	for b in raw:
		if bool(b.get("is_star", false)) or bool(b.get("belt", false)):
			continue
		sized.append(float(b.get("real_radius_km", 0.0)))
	sized.sort()
	var r_min: float = float(sized[0]) if sized.size() > 0 else 1.0
	var r_max: float = float(sized[sized.size() - 1]) if sized.size() > 0 else 1.0

	var out: Array = []
	for b in raw:
		var e: Dictionary = b.duplicate()
		var a: float = float(b.get("a_au", 0.0))
		e["orbit_r"] = OrbitMath.compress_orbit_r(a, cfg)
		e["omega"] = OrbitMath.omega_from_period_yr(float(b.get("period_yr", 0.0)), cfg)
		var oi: int = int(b.get("orbit_index", -1))
		e["theta0"] = float(oi) * 0.7 if oi >= 0 else _flyer_theta0(str(b["id"]))
		e["spin"] = 0.4 if bool(b.get("is_star", false)) else 0.15

		if bool(b.get("is_star", false)):
			e["orbit_r"] = 0.0
			e["omega"] = 0.0
			e["hero_r"] = cfg.sun_hero_r
			e["theta0"] = 0.0
		elif bool(b.get("belt", false)):
			e["hero_r"] = cfg.hero_min * 1.5
		else:
			var rk: float = float(b.get("real_radius_km", 0.0))
			var rank01: float = 0.0
			if r_max > r_min:
				rank01 = (rk - r_min) / (r_max - r_min)
			e["hero_r"] = OrbitMath.hero_radius(rank01, cfg)
		out.append(e)
	return out

static func _flyer_theta0(id: String) -> float:
	match id:
		"asteroid_belt":
			return 1.1
		"pluto":
			return 2.4
		_:
			return 0.5

static func flyer_body_by_id(id: String, cfg: SolarFlyerConfig = null) -> Dictionary:
	for b in flyer_bodies(cfg):
		if str(b["id"]) == id:
			return b
	return {}

## Destinations you can plot a course to (planets, belt, Pluto, and the Sun).
## The Sun is a special hop: park at a safe standoff — never land on the star.
static func flyer_destinations(cfg: SolarFlyerConfig = null) -> Array:
	return flyer_bodies(cfg)

## Planets that trace an orbit in the top-down orrery, in Sun-outward order.
## (The asteroid belt is drawn separately; it is not a single orbiting disc.)
static func orbiting() -> Array:
	var out: Array = []
	for b in bodies():
		if int(b["orbit_index"]) >= 0:
			out.append(b)
	out.sort_custom(func(a, c): return int(a["orbit_index"]) < int(c["orbit_index"]))
	return out

## The single body flagged as the asteroid belt, or {} if none.
static func belt() -> Dictionary:
	for b in bodies():
		if bool(b.get("belt", false)):
			return b
	return {}

## Order of the narrated orrery tour: the eight planets with the asteroid belt
## slotted between Mars and Jupiter. (Sun is the centre; Pluto is saved for the
## scroll strip / closing line.)
const TOUR_IDS := [
	"mercury", "venus", "earth", "mars", "asteroid_belt",
	"jupiter", "saturn", "uranus", "neptune",
]

static func tour_sequence() -> Array:
	var by_id: Dictionary = {}
	for b in bodies():
		by_id[b["id"]] = b
	var out: Array = []
	for id in TOUR_IDS:
		if by_id.has(id):
			out.append(by_id[id])
	return out

## X centre for each body in the horizontal scroll strip, left to right, using a
## per-body gap proportional to its size. Returns {"xs": Array, "width": float}.
static func scroll_layout(gap: float = 90.0, edge: float = 120.0) -> Dictionary:
	var xs: Array = []
	var cursor := edge
	var list := bodies()
	for i in list.size():
		var r: float = float(list[i]["draw_radius"])
		cursor += r
		xs.append(cursor)
		cursor += r + gap
	var width: float = cursor - gap + edge
	return {"xs": xs, "width": width}

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

## Named worlds inside the asteroid belt — real orbits, tiny hero radii,
## their own skins/facts/clips. Tapping "Asteroid Belt" resolves to the
## nearest of these; they also appear on the plot board inside the ring.
## `belt_hook` is the one-line reason this rock is worth visiting (spoken
## when the belt tap resolves to it).
static func major_asteroids() -> Array:
	return [
		{
			"id": "ceres", "name": "Ceres", "color": Color(0.60, 0.57, 0.53),
			"ring": false, "draw_radius": 16.0, "orbit_index": -1,
			"orrery_rx": 0.0, "period": 0.0, "is_star": false, "dwarf": true,
			"major_asteroid": true,
			"a_au": 2.77, "period_yr": 4.6, "real_radius_km": 473.0,
			"belt_hook": "the biggest one — a real dwarf planet",
			"blurb": "Ceres is the biggest world in the asteroid belt — so big it counts as a dwarf planet. It has shiny bright spots made of salt.",
			"facts": ["Biggest rock in the belt", "A dwarf planet", "Has shiny salt spots"],
		},
		{
			"id": "vesta", "name": "Vesta", "color": Color(0.68, 0.63, 0.55),
			"ring": false, "draw_radius": 14.0, "orbit_index": -1,
			"orrery_rx": 0.0, "period": 0.0, "is_star": false, "dwarf": false,
			"major_asteroid": true,
			"a_au": 2.36, "period_yr": 3.63, "real_radius_km": 263.0,
			"belt_hook": "it has a mountain twice as tall as Everest",
			"blurb": "Vesta is the second-biggest asteroid. It has a giant mountain more than twice as tall as Mount Everest.",
			"facts": ["Second-biggest asteroid", "Has a giant mountain", "Visited by the Dawn spacecraft"],
		},
		{
			"id": "psyche", "name": "Psyche", "color": Color(0.62, 0.64, 0.68),
			"ring": false, "draw_radius": 12.0, "orbit_index": -1,
			"orrery_rx": 0.0, "period": 0.0, "is_star": false, "dwarf": false,
			"major_asteroid": true,
			"a_au": 2.92, "period_yr": 5.0, "real_radius_km": 113.0,
			"belt_hook": "a world made of metal",
			"blurb": "Psyche is an asteroid made mostly of metal, like the inside of a planet. A spacecraft is flying there right now to take a close look.",
			"facts": ["Made mostly of metal", "Like a planet's core", "A spacecraft is on its way now"],
		},
	]

## Bodies enriched with flyer geometry (orbit_r, omega, hero_r, theta0, spin).
## Safe to call every frame — cheap dict copies keyed off cfg.
static func flyer_bodies(cfg: SolarFlyerConfig = null) -> Array:
	if cfg == null:
		cfg = SolarFlyerConfig.load_default()
	var raw := bodies() + major_asteroids()
	# Size ranks among non-star, non-belt PLANET-class bodies by real_radius_km.
	# Major asteroids stay out of the rank basis — they get a fixed sub-Mercury
	# hero size below, so adding them never reshuffles the planets.
	var sized: Array = []
	for b in raw:
		if bool(b.get("is_star", false)) or bool(b.get("belt", false)) \
				or bool(b.get("major_asteroid", false)):
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
		elif bool(b.get("major_asteroid", false)):
			e["hero_r"] = cfg.hero_min * 0.75  # clearly smaller than any planet
		else:
			var rk: float = float(b.get("real_radius_km", 0.0))
			var rank01: float = 0.0
			if r_max > r_min:
				rank01 = (rk - r_min) / (r_max - r_min)
			e["hero_r"] = OrbitMath.hero_radius(rank01, cfg)
		out.append(e)
	return out

## Resolve a tap on the belt to the nearest major asteroid (by actual
## position at time t), skipping the world the ship is already parked at.
static func nearest_major_asteroid(ship_pos: Vector3, t: float,
		cfg: SolarFlyerConfig = null, exclude_id: String = "") -> String:
	var best := ""
	var best_d := INF
	for b in flyer_bodies(cfg):
		if not bool(b.get("major_asteroid", false)):
			continue
		if str(b["id"]) == exclude_id:
			continue
		var d := ship_pos.distance_to(OrbitMath.body_pos(b, t))
		if d < best_d:
			best_d = d
			best = str(b["id"])
	return best

## Marker recognition tier — NOT planetary scale. Earth-class is the 1.0
## baseline legible size; Jupiter reads exactly double Earth (design brief);
## small worlds a touch under baseline so they still read at a glance.
static func icon_tier_for(b: Dictionary) -> float:
	if bool(b.get("is_star", false)):
		return 2.4   # the Sun outranks everything, slightly
	var rk: float = float(b.get("real_radius_km", 0.0))
	if rk >= 50000.0:
		return 2.0   # giant: Jupiter, Saturn — double Earth
	if rk >= 20000.0:
		return 1.6   # large: Uranus, Neptune
	if rk >= 5000.0:
		return 1.0   # medium: Venus, Earth — the legible baseline
	return 0.8       # small: Mercury, Mars, Pluto, asteroids

static func _flyer_theta0(id: String) -> float:
	match id:
		"asteroid_belt":
			return 1.1
		"pluto":
			return 2.4
		# Major asteroids spread around the ring so "nearest" varies by epoch.
		"ceres":
			return 1.3
		"vesta":
			return 3.4
		"psyche":
			return 5.3
		_:
			return 0.5

static func flyer_body_by_id(id: String, cfg: SolarFlyerConfig = null) -> Dictionary:
	for b in flyer_bodies(cfg):
		if str(b["id"]) == id:
			return b
	return {}

## Destinations you can plot a course to (planets, major asteroids, Pluto,
## and the Sun). The Sun is a special hop: park at a safe standoff — never
## land on the star. The belt ring itself is NOT a destination — tapping it
## resolves to the nearest major asteroid (nearest_major_asteroid).
static func flyer_destinations(cfg: SolarFlyerConfig = null) -> Array:
	var out: Array = []
	for b in flyer_bodies(cfg):
		if bool(b.get("belt", false)):
			continue
		out.append(b)
	return out

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

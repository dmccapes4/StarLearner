class_name ConstellationData
extends RefCounted
## Zodiac + major Northern asterisms on a celestial sphere.
## Star positions are J2000 RA/Dec converted to ecliptic (λ, β) so they sit
## in the real night sky — not a uniform ring on the planetary plane.

## J2000 mean obliquity (IAU).
const OBLIQUITY_DEG := 23.4392911
## Default celestial-sphere radius (playground may pass a larger one).
const SKY_R := 2800.0
const REF_STAR_R := 3.6

static func celestial_radius(planet_r_max: float, y_max: float) -> float:
	return maxf(maxf(planet_r_max * 2.15, y_max * 8.0), SKY_R)


static func equatorial_to_ecliptic(ra_hours: float, dec_deg: float) -> Vector2:
	var a: float = deg_to_rad(ra_hours * 15.0)
	var d: float = deg_to_rad(dec_deg)
	var e: float = deg_to_rad(OBLIQUITY_DEG)
	var sin_b: float = sin(d) * cos(e) - cos(d) * sin(e) * sin(a)
	var cos_b_cos_l: float = cos(d) * cos(a)
	var cos_b_sin_l: float = sin(d) * sin(e) + cos(d) * cos(e) * sin(a)
	return Vector2(atan2(cos_b_sin_l, cos_b_cos_l), asin(clampf(sin_b, -1.0, 1.0)))


static func sky_pos(ra_hours: float, dec_deg: float, radius: float = SKY_R) -> Vector3:
	var lb: Vector2 = equatorial_to_ecliptic(ra_hours, dec_deg)
	var cb: float = cos(lb.y)
	return Vector3(cb * sin(lb.x), sin(lb.y), -cb * cos(lb.x)) * radius


static func all_constellations(radius: float = SKY_R) -> Array:
	var out: Array = []
	for spec in _SPECS:
		out.append(_build(spec, radius))
	return out


static func zodiac_only(radius: float = SKY_R) -> Array:
	var out: Array = []
	for c in all_constellations(radius):
		if str(c.get("kind", "")) == "zodiac":
			out.append(c)
	return out


static func by_id(id: String, radius: float = SKY_R) -> Dictionary:
	for c in all_constellations(radius):
		if str(c["id"]) == id:
			return c
	return {}


static func center_of(data: Dictionary) -> Vector3:
	var stars: Array = data.get("stars", [])
	if stars.is_empty():
		return Vector3.ZERO
	var acc := Vector3.ZERO
	for s in stars:
		acc += s as Vector3
	return acc / float(stars.size())


static func line_ask(data: Dictionary) -> String:
	return "Would you like to learn about %s constellation?" % str(data.get("name", ""))


static func line_learn(data: Dictionary) -> String:
	return "%s %s" % [str(data.get("napa", "")), str(data.get("culture", ""))]


static func line_travel(place: String) -> String:
	return "Tap again to fly to %s." % place


## Build distant lights under `parent`. Connecting lines exist but start hidden
## (HUD tiles draw lines; Free Flight only shows them on a focused tap).
static func build_sky(parent: Node3D, radius: float = SKY_R,
		with_lines: bool = false) -> Dictionary:
	var out: Dictionary = {}
	for data in all_constellations(radius):
		var root := Node3D.new()
		root.name = str(data["id"])
		parent.add_child(root)
		var stars: Array = data["stars"]
		var mags: Array = data.get("mags", [])
		for i in stars.size():
			var mag: float = float(mags[i]) if i < mags.size() else 1.0
			var star_r: float = REF_STAR_R * lerpf(0.72, 1.35, clampf(mag, 0.35, 1.4))
			var mi := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = star_r
			sm.height = star_r * 2.0
			sm.radial_segments = 8
			sm.rings = 4
			mi.mesh = sm
			mi.material_override = _star_mat(false, mag)
			mi.position = stars[i] as Vector3
			mi.set_meta("mag", mag)
			root.add_child(mi)
		var links_root := Node3D.new()
		links_root.name = "Links"
		links_root.visible = with_lines
		root.add_child(links_root)
		for link in data.get("links", []):
			var a: int = int(link[0])
			var b: int = int(link[1])
			if a < 0 or b < 0 or a >= stars.size() or b >= stars.size():
				continue
			links_root.add_child(_make_link_mesh(
				stars[a] as Vector3, stars[b] as Vector3, 0.55))
		out[str(data["id"])] = {"root": root, "data": data, "links": links_root}
	return out


static func set_focus(entry: Dictionary, on: bool) -> void:
	if entry.is_empty():
		return
	var root: Node3D = entry.get("root") as Node3D
	var links: Node3D = entry.get("links") as Node3D
	if links != null:
		links.visible = on
	if root == null:
		return
	for child in root.get_children():
		if child is MeshInstance3D and child.material_override is StandardMaterial3D:
			var mag: float = float(child.get_meta("mag", 1.0))
			child.material_override = _star_mat(on, mag)


static func _star_mat(focus: bool, mag: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var warm := Color(1.0, 0.96, 0.82)
	mat.albedo_color = warm
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.93, 0.68) if focus else Color(0.95, 0.92, 0.85)
	mat.emission_energy_multiplier = (3.4 if focus else 2.15) * clampf(mag, 0.5, 1.5)
	return mat


static func _make_link_mesh(a: Vector3, b: Vector3, radius: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	var length: float = a.distance_to(b)
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = maxf(length, 0.1)
	cyl.radial_segments = 6
	mi.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.95, 0.82, 0.42, 0.88)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.86, 0.4)
	mat.emission_energy_multiplier = 1.4
	mi.material_override = mat
	var mid: Vector3 = (a + b) * 0.5
	var y: Vector3 = (b - a).normalized()
	var x: Vector3 = y.cross(Vector3.UP)
	if x.length() < 0.05:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	var z: Vector3 = x.cross(y).normalized()
	mi.transform = Transform3D(Basis(x, y, z), mid)
	return mi


static func _build(spec: Dictionary, radius: float) -> Dictionary:
	var stars: Array = []
	var mags: Array = []
	for st in spec["stars"]:
		stars.append(sky_pos(float(st[0]), float(st[1]), radius))
		mags.append(float(st[2]) if st.size() > 2 else 1.0)
	var name: String = str(spec["name"])
	return {
		"id": spec["id"],
		"name": name,
		"kind": spec["kind"],
		"stars": stars,
		"mags": mags,
		"links": spec["links"],
		"star_eq": spec["stars"],
		"napa": spec["napa"],
		"culture": spec["culture"],
		"line_ask": "Would you like to learn about %s constellation?" % name,
		"line_learn": "%s %s" % [str(spec["napa"]), str(spec["culture"])],
	}


# ── Catalog: [RA hours, Dec degrees, relative brightness] ─────────────
# Coordinates: Hipparcos / SIMBAD J2000 for the stick-figure stars.
const _SPECS: Array = [
	{"id": "aries", "name": "Aries", "kind": "zodiac",
		"stars": [[2.1196, 23.463, 1.05], [1.9107, 20.808, 0.85],
			[1.9106, 19.294, 0.70], [2.8314, 27.261, 0.75]],
		"links": [[0, 1], [1, 2], [0, 3]],
		"napa": "From Napa, California, Aries sits in the autumn and winter evening sky, low in the south-southeast after dusk.",
		"culture": "Ancient Babylonian sky-watchers saw a hired farm worker here. Later Greek stories named it the golden ram that flew Phrixus to safety."},
	{"id": "taurus", "name": "Taurus", "kind": "zodiac",
		"stars": [[4.5987, 16.509, 1.25], [5.4382, 28.608, 1.05],
			[4.4777, 19.180, 0.85], [4.3289, 15.628, 0.80],
			[4.3822, 17.543, 0.80], [3.7914, 24.105, 0.95]],
		"links": [[4, 0], [3, 4], [3, 2], [0, 1], [2, 5]],
		"napa": "From Napa, Taurus stands high in the south on winter evenings. Look for orange Aldebaran and the tiny dipper of the Pleiades.",
		"culture": "The bull is one of the oldest sky pictures — painted in Ice Age caves and named by Babylonian, Greek, and many later sky cultures."},
	{"id": "gemini", "name": "Gemini", "kind": "zodiac",
		"stars": [[7.5765, 31.888, 1.15], [7.7553, 28.026, 1.20],
			[6.6285, 16.399, 0.95], [7.3354, 21.982, 0.75],
			[6.7322, 25.131, 0.80], [6.3827, 22.514, 0.80]],
		"links": [[0, 4], [1, 3], [4, 5], [3, 2], [0, 1]],
		"napa": "From Napa, Gemini rides high in the winter and early-spring south. The twin bright stars Castor and Pollux mark the two heads.",
		"culture": "Greek myth called them Castor and Pollux, twin brothers. Many cultures saw a pair of figures standing side by side."},
	{"id": "cancer", "name": "Cancer", "kind": "zodiac",
		"stars": [[8.9748, 11.858, 0.70], [8.7448, 18.155, 0.75],
			[8.7214, 21.469, 0.70], [8.2753, 9.186, 0.80],
			[8.7783, 28.760, 0.70]],
		"links": [[3, 1], [1, 2], [1, 0], [2, 4]],
		"napa": "From Napa, Cancer is a faint spring pattern between Gemini and Leo, highest in the south late on spring evenings.",
		"culture": "Greek storytellers said Hera sent a crab to pinch Hercules. In the middle sits the Beehive, a star cluster known since ancient times."},
	{"id": "leo", "name": "Leo", "kind": "zodiac",
		"stars": [[10.1395, 11.967, 1.30], [11.8181, 14.572, 1.05],
			[10.3328, 19.842, 1.00], [11.2373, 20.524, 0.90],
			[11.2370, 15.430, 0.85], [10.2781, 23.417, 0.80],
			[9.7642, 23.774, 0.80]],
		"links": [[6, 5], [5, 2], [2, 0], [0, 4], [4, 1], [2, 3], [3, 4]],
		"napa": "From Napa, Leo is the spring lion. The backward question-mark sickle stands in the south after sunset from March through May.",
		"culture": "Egyptians tied the lion to the Sun's heat. Greeks named it the Nemean Lion that Hercules defeated."},
	{"id": "virgo", "name": "Virgo", "kind": "zodiac",
		"stars": [[13.4199, -11.161, 1.25], [12.6943, -1.450, 0.90],
			[13.0363, 10.959, 0.90], [12.9267, 3.397, 0.80],
			[13.5782, -0.596, 0.80], [11.8448, 1.765, 0.80]],
		"links": [[5, 1], [1, 3], [3, 2], [3, 4], [4, 0]],
		"napa": "From Napa, Virgo stretches across the spring and early-summer south. Bright blue-white Spica is the easy landmark, low in the south.",
		"culture": "Many peoples saw a harvest maiden here. Greeks called her Persephone or Astraea, the star of the wheat sheaf."},
	{"id": "libra", "name": "Libra", "kind": "zodiac",
		"stars": [[14.8479, -16.042, 0.90], [15.2835, -9.383, 0.90],
			[15.0672, -25.282, 0.75], [15.5921, -14.789, 0.75]],
		"links": [[0, 1], [1, 3], [0, 2]],
		"napa": "From Napa, Libra is a late-spring and summer pattern low in the south, a diamond of stars between Virgo and Scorpius.",
		"culture": "Romans named these stars the Scales of justice. Older Babylonian lists kept them as the claws of the scorpion."},
	{"id": "scorpio", "name": "Scorpius", "kind": "zodiac",
		"stars": [[16.4901, -26.432, 1.35], [16.0906, -19.805, 0.95],
			[16.0056, -22.622, 1.00], [17.5601, -37.104, 1.10],
			[17.6217, -37.296, 0.95], [17.6211, -42.998, 0.95],
			[16.5984, -28.216, 0.90], [15.9808, -26.114, 0.90]],
		"links": [[7, 2], [2, 1], [2, 0], [0, 6], [6, 3], [3, 4], [3, 5]],
		"napa": "From Napa, Scorpius crawls along the southern horizon on summer nights. Red Antares is the heart; the hooked tail sits even lower.",
		"culture": "Babylonian, Greek, and Polynesian sky stories all kept a scorpion here. In Greek myth it is the creature that stung Orion."},
	{"id": "sagittarius", "name": "Sagittarius", "kind": "zodiac",
		"stars": [[18.4029, -34.384, 1.05], [18.3499, -29.828, 0.90],
			[18.3498, -25.421, 0.90], [18.9211, -26.297, 1.05],
			[19.0435, -29.880, 0.90], [19.1627, -21.024, 0.85],
			[18.7608, -26.991, 0.80]],
		"links": [[2, 1], [1, 0], [1, 6], [6, 3], [3, 4], [4, 0], [3, 5]],
		"napa": "From Napa, Sagittarius is the summer teapot, low in the south. Its spout points toward the glowing band of the Milky Way's center.",
		"culture": "Greeks saw an archer-centaur. Many skywatchers also notice the teapot shape, sitting in front of our galaxy's bright heart."},
	{"id": "capricorn", "name": "Capricornus", "kind": "zodiac",
		"stars": [[21.7833, -16.127, 0.85], [20.3502, -14.781, 0.85],
			[21.6680, -16.662, 0.80], [20.2945, -12.545, 0.80],
			[20.8636, -26.919, 0.70]],
		"links": [[3, 1], [1, 4], [4, 0], [0, 2], [3, 0]],
		"napa": "From Napa, Capricornus is a faint summer-to-autumn triangle low in the south, following Sagittarius across the evening.",
		"culture": "Babylonians drew a goat-fish here. The Greeks kept that sea-goat, a climber with a fish's tail."},
	{"id": "aquarius", "name": "Aquarius", "kind": "zodiac",
		"stars": [[22.0964, -0.320, 0.90], [21.5259, -5.571, 0.90],
			[22.8769, -0.300, 0.80], [22.9108, -15.821, 0.80],
			[22.0960, -9.495, 0.70]],
		"links": [[1, 0], [0, 2], [0, 4], [4, 3]],
		"napa": "From Napa, Aquarius is a wide autumn pattern in the southern sky, a stream of medium-bright stars after dusk from September on.",
		"culture": "Sumerian and later Greek stories saw a water-bearer pouring a river. In Egypt the figure was tied to the Nile's flood."},
	{"id": "pisces", "name": "Pisces", "kind": "zodiac",
		"stars": [[2.0344, 2.764, 0.75], [23.2867, 3.282, 0.75],
			[1.5247, 15.346, 0.80], [23.9887, 6.863, 0.70],
			[1.8583, 5.418, 0.70], [23.4620, 6.379, 0.70]],
		"links": [[1, 5], [5, 3], [3, 0], [0, 4], [4, 2]],
		"napa": "From Napa, Pisces is a dim autumn and winter circlet plus a long cord, south and southeast in the evening from October through January.",
		"culture": "Greek myth tied two fishes to Aphrodite and Eros swimming to safety. Older Mesopotamian lists also kept a pair of fish."},
	{"id": "orion", "name": "Orion", "kind": "major",
		"stars": [[5.9195, 7.407, 1.40], [5.4189, 6.350, 1.15],
			[5.6036, -1.202, 1.20], [5.6794, -1.943, 1.15],
			[5.5335, -0.299, 1.15], [5.2423, -8.202, 1.40],
			[5.7959, -9.670, 1.10], [5.5854, 9.934, 0.85]],
		"links": [[7, 0], [7, 1], [0, 3], [1, 4], [4, 2], [2, 3], [3, 6], [4, 5]],
		"napa": "From Napa, Orion is the great winter hunter, standing tall in the southern sky from December through March. Three belt stars in a row are the clue.",
		"culture": "Almost every sky culture named this figure. Greeks called him the hunter Orion. The belt also points to Sirius, the brightest night star."},
	{"id": "lepus", "name": "Lepus", "kind": "major",
		"stars": [[5.5455, -17.822, 0.95], [5.4707, -20.759, 0.90],
			[5.2108, -16.205, 0.85], [5.0941, -22.371, 0.78],
			[5.2189, -22.448, 0.72], [5.3518, -21.040, 0.68]],
		"links": [[0, 1], [1, 3], [3, 4], [4, 5], [5, 1], [0, 2]],
		"napa": "From Napa, Lepus crouches just below Orion in the winter southern sky. It is small and easy to overlook but lies in a rich Milky Way field.",
		"culture": "Greeks placed the hare here as prey for Orion and his hunting dogs. It is one of Ptolemy's original 48 constellations, always depicted cowering beneath the great hunter."},
	{"id": "ursa_major", "name": "Ursa Major", "kind": "major",
		"stars": [[11.0621, 61.751, 1.15], [11.0307, 56.382, 1.10],
			[11.8972, 53.695, 1.05], [12.2571, 57.033, 1.00],
			[12.9004, 55.960, 1.10], [13.3987, 54.925, 1.10],
			[13.7923, 49.313, 1.10]],
		"links": [[0, 1], [1, 2], [2, 3], [3, 0], [3, 4], [4, 5], [5, 6]],
		"napa": "From Napa, Ursa Major — the Big Dipper — never sets. It swings around the north star all year, highest in spring evenings.",
		"culture": "Many peoples saw a great bear or a ladle. The two pointer stars on the bowl's front edge aim at Polaris, the North Star."},
	{"id": "cassiopeia", "name": "Cassiopeia", "kind": "major",
		"stars": [[0.1528, 59.150, 1.05], [0.6751, 56.537, 1.10],
			[0.9451, 60.717, 1.15], [1.4302, 60.235, 1.05],
			[1.9066, 63.670, 1.00]],
		"links": [[0, 1], [1, 2], [2, 3], [3, 4]],
		"napa": "From Napa, Cassiopeia is a bright W or M in the northern sky all year, opposite the Big Dipper around Polaris.",
		"culture": "Greeks named her the seated queen Cassiopeia. The W shape made it a favorite guide constellation for northern travelers."},
	{"id": "cygnus", "name": "Cygnus", "kind": "major",
		"stars": [[20.6905, 45.280, 1.30], [20.3705, 40.257, 1.05],
			[20.7702, 33.970, 0.95], [19.7496, 45.131, 0.90],
			[19.5120, 27.960, 0.95]],
		"links": [[0, 1], [1, 4], [3, 1], [1, 2]],
		"napa": "From Napa, Cygnus the Swan — the Northern Cross — flies along the summer Milky Way, high overhead on July and August nights.",
		"culture": "Greeks saw Zeus as a swan. Deneb, the tail star, is one corner of the Summer Triangle with Vega and Altair."},
	{"id": "lyra", "name": "Lyra", "kind": "major",
		"stars": [[18.6156, 38.783, 1.45], [18.8347, 33.363, 0.85],
			[18.9824, 32.690, 0.85], [18.7462, 37.605, 0.75],
			[18.8800, 36.900, 0.70]],
		"links": [[0, 3], [3, 4], [4, 1], [1, 2], [4, 2]],
		"napa": "From Napa, Lyra is a small summer harp nearly overhead. Vega is one of the brightest stars in the whole sky.",
		"culture": "Greeks said this was Orpheus's lyre. Vega has been a pole star in the deep past and will be again as Earth slowly wobbles."},
	{"id": "aquila", "name": "Aquila", "kind": "major",
		"stars": [[19.8464, 8.868, 1.30], [19.7709, 10.613, 0.95],
			[19.9219, 6.407, 0.85], [20.1886, -0.821, 0.80],
			[19.4249, 3.115, 0.80]],
		"links": [[1, 0], [0, 2], [0, 4], [4, 3]],
		"napa": "From Napa, Aquila the Eagle soars in the summer south. Altair is the bright middle star of the Summer Triangle.",
		"culture": "Romans and Greeks saw Zeus's eagle. In Japan, Altair is the cowherd star in the Tanabata story, facing Vega across the Milky Way."},
	{"id": "pegasus", "name": "Pegasus", "kind": "major",
		"stars": [[23.0793, 15.205, 1.05], [23.0629, 28.083, 1.10],
			[0.2206, 15.184, 1.00], [0.1398, 29.090, 1.10],
			[21.7364, 9.875, 1.05]],
		"links": [[0, 1], [1, 3], [3, 2], [2, 0], [0, 4]],
		"napa": "From Napa, the Great Square of Pegasus stands high in the autumn south and overhead. Four stars make an easy box.",
		"culture": "Greeks named the winged horse Pegasus. One corner star, Alpheratz, is shared with Andromeda."},
	{"id": "andromeda", "name": "Andromeda", "kind": "major",
		"stars": [[0.1398, 29.090, 1.10], [1.1622, 35.621, 1.05],
			[2.0648, 42.330, 1.05], [0.6554, 30.861, 0.80]],
		"links": [[0, 3], [3, 1], [1, 2]],
		"napa": "From Napa, Andromeda stretches northeast from Pegasus on autumn evenings. A faint oval nearby is the Andromeda Galaxy, visible on dark nights.",
		"culture": "Greek myth chained princess Andromeda to a rock. The nearby galaxy is the farthest thing most people can see with just their eyes."},
	{"id": "perseus", "name": "Perseus", "kind": "major",
		"stars": [[3.4054, 49.861, 1.15], [3.1361, 40.956, 1.05],
			[3.7386, 32.288, 0.90], [3.9827, 39.996, 0.90],
			[3.7154, 47.788, 0.90]],
		"links": [[0, 4], [4, 3], [0, 1], [1, 2]],
		"napa": "From Napa, Perseus stands in the northeast on autumn and winter evenings, between Cassiopeia and Taurus. Algol, the Demon Star, slowly blinks.",
		"culture": "Greeks named him the hero who rescued Andromeda. Algol's blinks were recorded as a winking eye for thousands of years."},
	{"id": "canis_major", "name": "Canis Major", "kind": "major",
		"stars": [[6.7525, -16.716, 1.50], [6.9771, -28.972, 1.10],
			[7.1399, -26.393, 1.00], [7.4016, -29.303, 0.90],
			[6.3783, -17.956, 1.00]],
		"links": [[4, 0], [0, 2], [2, 1], [2, 3]],
		"napa": "From Napa, Canis Major follows Orion in the winter south. Sirius, the Dog Star, is the brightest star in Earth's night sky.",
		"culture": "Greeks saw Orion's hunting dog. Egyptians watched Sirius return with the Nile flood. Many cultures called it the dog or a canoe."},
	{"id": "canis_minor", "name": "Canis Minor", "kind": "major",
		"stars": [[7.6550, 5.225, 1.40], [7.4525, 8.289, 0.95],
			[7.4288, 9.174, 0.70], [7.4016, 8.145, 0.65]],
		"links": [[1, 0], [2, 1], [1, 3]],
		"napa": "From Napa, Canis Minor is a short bright pair southeast of Gemini. Procyon is one of the sky's brightest stars and joins the Winter Triangle with Sirius and Betelgeuse.",
		"culture": "Greeks saw Orion's smaller hunting dog. Procyon means 'before the dog' — it rises just ahead of Sirius."},
	{"id": "bootes", "name": "Boötes", "kind": "major",
		"stars": [[14.2610, 19.182, 1.40], [14.7498, 27.074, 1.00],
			[14.5346, 38.308, 0.90], [15.0324, 40.390, 0.85],
			[13.9114, 18.398, 0.85]],
		"links": [[4, 0], [0, 1], [1, 2], [2, 3]],
		"napa": "From Napa, Boötes is a spring and summer kite high in the south and overhead. Orange Arcturus is the bright foot of the kite.",
		"culture": "Greeks saw a herdsman driving the great bear around the pole. Arcturus means 'guardian of the bear.'"},
	{"id": "auriga", "name": "Auriga", "kind": "major",
		"stars": [[5.2782, 45.998, 1.35], [5.9922, 44.947, 1.05],
			[5.9962, 37.213, 0.90], [5.0237, 43.823, 0.90],
			[4.9499, 33.166, 0.85]],
		"links": [[3, 0], [0, 1], [1, 2], [2, 4], [4, 3]],
		"napa": "From Napa, Auriga is a bright winter pentagon high in the south and overhead. Capella is the golden goat star at the top.",
		"culture": "Greeks saw a charioteer carrying a goat. Capella has been a seasonal marker from the Mediterranean to the Arctic."},
	# ── Southern and extended sky ─────────────────────────────────────────────
	{"id": "crux", "name": "Crux", "kind": "southern",
		"stars": [[12.4433, -63.099, 1.35], [12.7954, -59.689, 1.25],
			[12.5194, -57.113, 1.15], [12.2508, -58.749, 0.78]],
		"links": [[0, 2], [1, 3]],
		"napa": "From Napa, Crux never rises — it stays below the southern horizon. Travel south of about 25 degrees north latitude and it appears low in the spring sky.",
		"culture": "The Southern Cross guided Pacific and South American navigators for millennia. It appears on the flags of Australia, New Zealand, Brazil, Papua New Guinea, and Samoa."},
	{"id": "hydra", "name": "Hydra", "kind": "major",
		"stars": [[8.6278, 5.704, 0.68], [8.7795, 6.419, 0.72],
			[8.9232, 5.946, 0.72], [8.7203, 3.399, 0.65],
			[9.4597, -8.659, 1.35], [10.4344, -16.836, 0.70],
			[10.8274, -16.193, 0.72], [11.8816, -33.908, 0.68]],
		"links": [[0, 1], [1, 2], [1, 3], [3, 4], [4, 5], [5, 6], [6, 7]],
		"napa": "From Napa, Hydra stretches across the spring southern sky from February through May. Alphard — the lone bright star — is the easiest landmark in a very long, faint chain.",
		"culture": "Greek myth called this the nine-headed water monster Hercules killed. It is the largest of all 88 modern constellations, coiling across 100 degrees of sky."},
	{"id": "monoceros", "name": "Monoceros", "kind": "major",
		"stars": [[7.6860, -9.548, 0.72], [6.4793, -7.017, 0.75],
			[6.2477, -6.274, 0.70], [7.1983, -0.492, 0.68],
			[6.8197, 4.594, 0.68], [8.1431, -2.983, 0.65]],
		"links": [[2, 1], [1, 4], [4, 3], [3, 0], [3, 5]],
		"napa": "From Napa, Monoceros fills the winter southern sky between Orion, Canis Major, and Canis Minor. Its stars are faint — find it by the bright neighbors that surround it.",
		"culture": "The unicorn was placed here in the 17th century by Dutch navigators. It is a modern constellation, not an ancient one, filling a gap between older figures."},
	{"id": "corvus", "name": "Corvus", "kind": "major",
		"stars": [[12.1393, -24.729, 0.68], [12.5730, -23.397, 0.90],
			[12.2636, -17.542, 0.95], [12.4980, -16.515, 0.85],
			[12.1681, -22.620, 0.78]],
		"links": [[2, 3], [3, 1], [1, 4], [4, 2], [4, 0]],
		"napa": "From Napa, Corvus is a neat four-star kite low in the spring south following Virgo. On a clear night its compact box shape is easy to spot.",
		"culture": "Greek myth sent Apollo's crow here with a cup and a water snake for company, as punishment for dawdling. The cup and snake are the neighboring constellations Crater and Hydra."},
	{"id": "centaurus", "name": "Centaurus", "kind": "southern",
		"stars": [[14.6601, -60.835, 1.50], [14.0638, -60.373, 1.35],
			[14.5920, -42.157, 0.85], [13.9255, -47.288, 0.80],
			[13.6643, -53.466, 0.78], [12.6920, -48.960, 0.80]],
		"links": [[0, 1], [0, 2], [2, 3], [3, 4], [4, 5], [4, 1]],
		"napa": "From Napa, only the top of Centaurus rises above the horizon in spring. The two brilliant pointer stars — the nearest star system to our Sun — stay below the horizon for most of California.",
		"culture": "Alpha Centauri, in the centaur's foreleg, is the closest star system to the Sun at 4.2 light-years. Greeks saw a wise centaur here, said to be Chiron the teacher of heroes."},
	{"id": "ophiuchus", "name": "Ophiuchus", "kind": "major",
		"stars": [[17.5830, 12.560, 0.95], [17.7230, 4.567, 0.82],
			[16.2390, -3.695, 0.82], [16.3050, -4.693, 0.75],
			[16.6190, -10.567, 0.85], [17.1810, -15.725, 0.88],
			[16.9620, 9.375, 0.72]],
		"links": [[0, 6], [6, 1], [1, 2], [2, 3], [3, 4], [4, 5]],
		"napa": "From Napa, Ophiuchus fills the summer southern sky between Scorpius and Hercules. The Sun actually passes through it in December — it is sometimes called the unlisted 13th zodiac sign.",
		"culture": "Greek myth saw a healer holding a serpent here, associated with Asclepius the physician. The caduceus — a staff with a snake — is still used as a symbol of medicine today."},
	{"id": "hercules", "name": "Hercules", "kind": "major",
		"stars": [[17.2440, 14.390, 0.73], [16.5040, 21.490, 0.82],
			[16.3650, 19.153, 0.70], [17.2500, 24.839, 0.76],
			[17.0050, 30.926, 0.68], [16.6880, 31.602, 0.82],
			[16.7160, 38.922, 0.72], [17.2510, 36.809, 0.76]],
		"links": [[0, 1], [1, 2], [2, 3], [3, 0], [3, 5], [3, 4],
			[4, 6], [5, 6], [6, 7], [7, 5]],
		"napa": "From Napa, Hercules is a large summer constellation high in the south and overhead. The four-star Keystone marks the torso and points toward the Great Hercules Cluster.",
		"culture": "The Greeks placed their greatest hero here — upside-down, kneeling. The Hercules Cluster, M13, sits in the Keystone and is the finest globular star cluster visible from the northern hemisphere."},
]


static func make_orion_tile(w: int = 256, h: int = 160) -> Texture2D:
	return make_asterism_tile(by_id("orion"), w, h, true)


static func make_grid_preview_tile(w: int = 256, h: int = 160) -> Texture2D:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.03, 0.04, 0.10, 1.0))
	var ids := ["orion", "ursa_major", "cassiopeia", "cygnus"]
	var cell_w: int = w / 2
	var cell_h: int = h / 2
	for i in 4:
		var c: Dictionary = by_id(ids[i])
		var ox: int = (i % 2) * cell_w
		var oy: int = (i / 2) * cell_h
		_stamp_asterism(img, c, Rect2i(ox + 4, oy + 4, cell_w - 8, cell_h - 8), true)
	for x in w:
		img.set_pixel(x, cell_h, Color(0.25, 0.28, 0.40, 0.8))
	for y in h:
		img.set_pixel(cell_w, y, Color(0.25, 0.28, 0.40, 0.8))
	return ImageTexture.create_from_image(img)


static func make_asterism_tile(data: Dictionary, w: int = 220, h: int = 220,
		with_lines: bool = true) -> Texture2D:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.02, 0.03, 0.08, 1.0))
	_stamp_asterism(img, data, Rect2i(8, 8, w - 16, h - 16), with_lines)
	return ImageTexture.create_from_image(img)


static func make_telescope_plate(data: Dictionary, w: int = 520, h: int = 360) -> Texture2D:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 1.0))
	var cx := w * 0.5
	var cy := h * 0.5
	var rad: float = minf(cx, cy) - 6.0
	var rng := RandomNumberGenerator.new()
	rng.seed = int(str(data.get("id", "sky")).hash())
	for y in h:
		for x in w:
			var d: float = Vector2(x + 0.5 - cx, y + 0.5 - cy).length()
			if d > rad:
				img.set_pixel(x, y, Color(0.04, 0.04, 0.05, 1.0))
				continue
			var u: float = 1.0 - d / rad
			var fog: float = 0.04 + 0.07 * u * u
			if str(data.get("id", "")) == "orion":
				fog += 0.08 * exp(-Vector2(x - cx, y - cy - 18.0).length_squared() / 2800.0)
			var n: float = rng.randf() * 0.03
			img.set_pixel(x, y, Color(0.06 + fog + n, 0.07 + fog, 0.10 + fog * 0.6, 1.0))
	_stamp_asterism(img, data, Rect2i(int(cx - rad * 0.78), int(cy - rad * 0.78),
		int(rad * 1.56), int(rad * 1.56)), false, true)
	# Eyepiece ring.
	for i in 180:
		var ang: float = TAU * float(i) / 180.0
		var px := int(cx + cos(ang) * rad)
		var py := int(cy + sin(ang) * rad)
		if px >= 0 and py >= 0 and px < w and py < h:
			img.set_pixel(px, py, Color(0.55, 0.55, 0.58, 1.0))
	return ImageTexture.create_from_image(img)


static func _stamp_asterism(img: Image, data: Dictionary, rect: Rect2i,
		with_lines: bool, telescope: bool = false) -> void:
	var eq: Array = data.get("star_eq", [])
	if eq.is_empty():
		return
	var ras: Array = []
	var decs: Array = []
	for st in eq:
		ras.append(float(st[0]) * 15.0)
		decs.append(float(st[1]))
	var ra0: float = 0.0
	var dec0: float = 0.0
	for i in ras.size():
		ra0 += float(ras[i])
		dec0 += float(decs[i])
	ra0 /= float(ras.size())
	dec0 /= float(decs.size())
	var pts: Array = []
	var min_x := INF
	var max_x := -INF
	var min_y := INF
	var max_y := -INF
	for i in ras.size():
		var dx: float = wrapf(float(ras[i]) - ra0, -180.0, 180.0)
		var dy: float = float(decs[i]) - dec0
		# RA increases west on the sky; flip so east is right for kids.
		var p := Vector2(-dx, -dy)
		pts.append(p)
		min_x = minf(min_x, p.x)
		max_x = maxf(max_x, p.x)
		min_y = minf(min_y, p.y)
		max_y = maxf(max_y, p.y)
	var span: float = maxf(maxf(max_x - min_x, max_y - min_y), 1.0)
	var pad: float = 0.18
	var usable := Vector2(float(rect.size.x), float(rect.size.y)) * (1.0 - pad * 2.0)
	var scale: float = minf(usable.x, usable.y) / span
	var mid := Vector2(float(rect.position.x) + float(rect.size.x) * 0.5,
		float(rect.position.y) + float(rect.size.y) * 0.5)
	var pix: Array = []
	for p in pts:
		pix.append(mid + Vector2(p.x, p.y) * scale)
	if with_lines:
		for link in data.get("links", []):
			var a: int = int(link[0])
			var b: int = int(link[1])
			if a < 0 or b < 0 or a >= pix.size() or b >= pix.size():
				continue
			_line(img, pix[a] as Vector2, pix[b] as Vector2,
				Color(0.85, 0.72, 0.38, 0.85 if telescope else 0.75))
	for i in pix.size():
		var mag: float = float(eq[i][2]) if (eq[i] as Array).size() > 2 else 1.0
		var r: int = 2 if telescope else 3
		if mag > 1.2:
			r += 1
		_dot(img, pix[i] as Vector2, r, Color(1.0, 0.96, 0.82, 1.0))


static func _dot(img: Image, p: Vector2, r: int, col: Color) -> void:
	var w: int = img.get_width()
	var h: int = img.get_height()
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if dx * dx + dy * dy > r * r:
				continue
			var x: int = int(p.x) + dx
			var y: int = int(p.y) + dy
			if x >= 0 and y >= 0 and x < w and y < h:
				img.set_pixel(x, y, col)


static func _line(img: Image, a: Vector2, b: Vector2, col: Color) -> void:
	var steps: int = maxi(int(a.distance_to(b)), 1)
	var w: int = img.get_width()
	var h: int = img.get_height()
	for s in steps + 1:
		var t: float = float(s) / float(steps)
		var p: Vector2 = a.lerp(b, t)
		var x := int(p.x)
		var y := int(p.y)
		if x >= 0 and y >= 0 and x < w and y < h:
			img.set_pixel(x, y, col)

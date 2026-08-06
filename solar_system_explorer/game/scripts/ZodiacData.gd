class_name ZodiacData
extends RefCounted
## Twelve zodiac signs: simplified asterisms on an outer ecliptic shell.
## Free Flight treats that shell as the ceiling / outer wall of the circular
## pill (planetary plane + ±Y band). Season cinematics keep Earth on its
## real orbit — Sun at the center, constellation on the far shell — then
## look outward from Earth's perspective.

## Default shell radius (Zodiac Sky + fallback). Free Flight computes a
## larger value from planet span + band height via playground_shell_radius().
const RING_R := 1100.0
## Local asterism offsets were authored at this radius; scale with ring_r.
const REF_RING := 380.0
## Earth orbit as a fraction of shell during season cinematics (readable gap).
const EARTH_ORBIT_FRAC := 0.15

## Tropical ecliptic longitudes (degrees) for sign centers.
const LONG_DEG: Dictionary = {
	"aries": 15.0, "taurus": 45.0, "gemini": 75.0, "cancer": 105.0,
	"leo": 135.0, "virgo": 165.0, "libra": 195.0, "scorpio": 225.0,
	"sagittarius": 255.0, "capricorn": 285.0, "aquarius": 315.0, "pisces": 345.0,
}

static func playground_shell_radius(planet_r_max: float, y_max: float) -> float:
	## Outer shell beyond every world and beyond the vertical turn-around band.
	return maxf(maxf(planet_r_max * 1.45, y_max * 4.6), RING_R)

static func sign_dir(long_deg: float) -> Vector3:
	var yaw: float = deg_to_rad(long_deg)
	return Vector3(sin(yaw), 0.0, -cos(yaw)).normalized()

static func sign_anchor(long_deg: float, ring_r: float = RING_R) -> Vector3:
	return sign_dir(long_deg) * ring_r

## When the Sun appears in this sign, Earth is opposite the sign on its orbit.
static func earth_season_pos(long_deg: float, earth_orbit_r: float) -> Vector3:
	return -sign_dir(long_deg) * earth_orbit_r

static func earth_orbit_radius(ring_r: float = RING_R) -> float:
	return ring_r * EARTH_ORBIT_FRAC

static func signs(ring_r: float = RING_R) -> Array:
	## Ordered Aries → Pisces. Star positions depend on shell radius.
	return [
		_sign("aries", "Aries", "♈",
			[[0, 0], [12, 8], [22, 2], [34, -4], [48, 6]],
			[[0, 1], [1, 2], [2, 3], [3, 4]],
			"mid March to mid April",
			"Spring north — autumn south.",
			"Aries is a small ram of stars. In spring up north, the Sun lines up with the Ram.",
			"In astrology, Aries is the brave starter — bold, quick, and ready to begin.",
			ring_r),
		_sign("taurus", "Taurus", "♉",
			[[0, 2], [14, 8], [28, 10], [40, 4], [22, -2], [34, -6], [48, 0]],
			[[0, 1], [1, 2], [2, 3], [1, 4], [4, 5], [5, 6]],
			"mid April to mid May",
			"Spring north — autumn south.",
			"Taurus is the Bull — a V of stars called the Hyades. Late spring, the Sun stands with the Bull.",
			"Astrologers say Taurus is steady and cozy — loves comfort, nature, and good food.",
			ring_r),
		_sign("gemini", "Gemini", "♊",
			[[0, 10], [0, -10], [18, 12], [18, -12], [36, 8], [36, -8]],
			[[0, 1], [0, 2], [1, 3], [2, 4], [3, 5]],
			"mid May to mid June",
			"Late spring north — late autumn south.",
			"Gemini is the Twins — two bright side-by-side figures. The Sun visits near the start of summer north.",
			"In astrology, Gemini is curious and talkative — a twin mind full of ideas.",
			ring_r),
		_sign("cancer", "Cancer", "♋",
			[[0, 0], [10, 8], [22, 10], [34, 6], [20, -4], [32, -8]],
			[[0, 1], [1, 2], [2, 3], [0, 4], [4, 5]],
			"mid June to mid July",
			"Summer north — winter south.",
			"Cancer is the Crab — a quiet sideways shape. Midsummer north, the Sun rests with the Crab.",
			"Astrologers call Cancer the caretaker — home-loving, soft-hearted, and protective.",
			ring_r),
		_sign("leo", "Leo", "♌",
			[[0, 0], [10, 10], [22, 14], [34, 8], [48, 2], [20, -2], [36, -6]],
			[[0, 1], [1, 2], [2, 3], [3, 4], [1, 5], [5, 6]],
			"mid July to mid August",
			"Summer north — winter south.",
			"Leo is the Lion — a sickle of stars for the mane. High summer, the Sun walks with the Lion.",
			"In astrology, Leo is the performer — warm, proud, and generous with cheer.",
			ring_r),
		_sign("virgo", "Virgo", "♍",
			[[0, 6], [12, 10], [24, 6], [36, 0], [48, -4], [20, -8], [40, 8]],
			[[0, 1], [1, 2], [2, 3], [3, 4], [2, 5], [3, 6]],
			"mid August to mid September",
			"Late summer north — late winter south.",
			"Virgo is the Maiden — a long chain of stars. Late summer, the Sun harvests with Virgo.",
			"Astrologers say Virgo is careful and helpful — loves tidy plans and kind details.",
			ring_r),
		_sign("libra", "Libra", "♎",
			[[0, 0], [16, 8], [32, 0], [16, -8], [48, 4]],
			[[0, 1], [1, 2], [2, 3], [3, 0], [1, 4]],
			"mid September to mid October",
			"Autumn north — spring south.",
			"Libra is the Scales — a balance of stars. At the fall equinox north, day and night tip even.",
			"In astrology, Libra seeks fairness — friendly, artistic, and good at sharing.",
			ring_r),
		_sign("scorpio", "Scorpio", "♏",
			[[0, 4], [12, 8], [24, 6], [36, 2], [48, -4], [30, -10], [42, -12]],
			[[0, 1], [1, 2], [2, 3], [3, 4], [3, 5], [5, 6]],
			"mid October to mid November",
			"Autumn north — spring south.",
			"Scorpio is the Scorpion — a curved tail of stars. Mid-autumn, the Sun travels with the Scorpion.",
			"Astrologers say Scorpio is deep and brave — feels a lot, and sticks with truth.",
			ring_r),
		_sign("sagittarius", "Sagittarius", "♐",
			[[0, 0], [14, 10], [28, 14], [20, -6], [36, -2], [48, 6]],
			[[0, 1], [1, 2], [0, 3], [3, 4], [1, 5]],
			"mid November to mid December",
			"Late autumn north — late spring south.",
			"Sagittarius is the Archer — a teapot shape aiming an arrow. Late autumn, the Sun rides with the Archer.",
			"In astrology, Sagittarius is the explorer — hopeful, funny, and ready for the next adventure.",
			ring_r),
		_sign("capricorn", "Capricorn", "♑",
			[[0, 8], [14, 4], [28, 0], [40, -6], [20, -10], [48, 2]],
			[[0, 1], [1, 2], [2, 3], [2, 4], [3, 5]],
			"mid December to mid January",
			"Winter north — summer south.",
			"Capricorn is the Sea-Goat — a triangle climbing the sky. Midwinter north, the Sun climbs with Capricorn.",
			"Astrologers call Capricorn the climber — patient, steady, and proud of hard work.",
			ring_r),
		_sign("aquarius", "Aquarius", "♒",
			[[0, 10], [12, 6], [24, 10], [36, 4], [48, 8], [20, -6], [40, -4]],
			[[0, 1], [1, 2], [2, 3], [3, 4], [1, 5], [3, 6]],
			"mid January to mid February",
			"Winter north — summer south.",
			"Aquarius is the Water-Bearer — a zig-zag stream of stars. Late winter, the Sun pours with Aquarius.",
			"In astrology, Aquarius is the innovator — friendly, future-minded, and a little quirky.",
			ring_r),
		_sign("pisces", "Pisces", "♓",
			[[0, 10], [10, 4], [20, 10], [30, 2], [40, 8], [50, 0],
				[8, -8], [18, -12], [28, -6]],
			[[0, 1], [1, 2], [2, 3], [3, 4], [4, 5], [1, 6], [6, 7], [7, 8]],
			"mid February to mid March",
			"Late winter north — late summer south.",
			"Pisces is two fish tied by a cord of stars. Late winter up north, the Sun swims near the Fishes.",
			"Astrologers say Pisces is dreamy and kind — full of imagination and empathy.",
			ring_r),
	]

static func sign_by_id(id: String, ring_r: float = RING_R) -> Dictionary:
	for s in signs(ring_r):
		if str(s["id"]) == id:
			return s
	return {}

static func _sign(id: String, name: String, symbol: String,
		pts: Array, links: Array, months: String, hemisphere: String,
		astronomy: String, astrology: String, ring_r: float) -> Dictionary:
	var long_deg: float = float(LONG_DEG.get(id, 0.0))
	var stars: Array = _place_asterism(pts, long_deg, ring_r)
	return {
		"id": id,
		"name": name,
		"symbol": symbol,
		"stars": stars,
		"links": links,
		"months": months,
		"hemisphere": hemisphere,
		"astronomy": astronomy,
		"astrology": astrology,
		"long_deg": long_deg,
		"ring_r": ring_r,
		"line_seek": "Flying to %s!" % name,
		"line_arrive": "Here is %s — the stars of the %s." % [name, name],
		"line_earth": (
			"Watch Earth move into season for %s, around %s. From Earth, the Sun lines up with these stars. %s"
			% [name, months, hemisphere]),
		"line_astro": astrology,
	}

static func _place_asterism(pts: Array, long_deg: float, ring_r: float) -> Array:
	## Local (along, up) offsets → world positions on the ecliptic shell.
	var scale: float = ring_r / REF_RING
	var yaw: float = deg_to_rad(long_deg)
	var center := sign_anchor(long_deg, ring_r)
	var along := Vector3(cos(yaw), 0.0, sin(yaw))
	var up := Vector3.UP
	var out: Array = []
	var i := 0
	for p in pts:
		var a: float = (float(p[0]) - 30.0) * scale
		var u: float = float(p[1]) * scale
		var pos: Vector3 = center + along * a + up * u
		pos += along * sin(float(i) * 1.7) * 2.0 * scale \
			+ up * cos(float(i) * 2.3) * 1.5 * scale
		out.append(pos)
		i += 1
	return out

static func center_of(sign: Dictionary) -> Vector3:
	var stars: Array = sign.get("stars", [])
	if stars.is_empty():
		var long_deg: float = float(sign.get("long_deg", 0.0))
		var ring_r: float = float(sign.get("ring_r", RING_R))
		return sign_anchor(long_deg, ring_r)
	var acc := Vector3.ZERO
	for s in stars:
		acc += s as Vector3
	return acc / float(stars.size())

## Build stick-figure asterisms under `parent`. Returns id → {root, data}.
static func build_sky(parent: Node3D, ring_r: float = RING_R) -> Dictionary:
	var out: Dictionary = {}
	var scale: float = ring_r / REF_RING
	var star_r: float = maxf(2.4, 2.4 * scale)
	var link_r: float = maxf(0.35, 0.35 * scale)
	for data in signs(ring_r):
		var root := Node3D.new()
		root.name = str(data["id"])
		parent.add_child(root)
		var stars: Array = data["stars"]
		for sp in stars:
			var mi := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = star_r
			sm.height = star_r * 2.0
			sm.radial_segments = 8
			sm.rings = 4
			mi.mesh = sm
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.albedo_color = Color(1.0, 0.95, 0.75)
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.9, 0.55)
			mat.emission_energy_multiplier = 1.8
			mi.material_override = mat
			mi.position = sp as Vector3
			root.add_child(mi)
		for link in data["links"]:
			var a: int = int(link[0])
			var b: int = int(link[1])
			if a < 0 or b < 0 or a >= stars.size() or b >= stars.size():
				continue
			root.add_child(_make_link_mesh(
				stars[a] as Vector3, stars[b] as Vector3, link_r))
		var label := Label3D.new()
		label.text = "%s %s" % [str(data["symbol"]), str(data["name"])]
		label.font_size = int(clampf(48.0 * sqrt(scale), 40.0, 96.0))
		label.modulate = Color(1.0, 0.88, 0.45)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = center_of(data) + Vector3(0.0, 22.0 * scale, 0.0)
		root.add_child(label)
		out[str(data["id"])] = {"root": root, "data": data}
	return out

static func _make_link_mesh(a: Vector3, b: Vector3, radius: float = 0.35) -> MeshInstance3D:
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
	mat.albedo_color = Color(0.95, 0.8, 0.35, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
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

static func make_tile_texture() -> Texture2D:
	## Procedural hub tile — night sky + Leo-like sickle.
	var img := Image.create(512, 320, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.04, 0.05, 0.12, 1.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for _i in 80:
		var x := rng.randi_range(4, 507)
		var y := rng.randi_range(4, 315)
		var b: float = rng.randf_range(0.45, 1.0)
		img.set_pixel(x, y, Color(b, b, 1.0, 1.0))
	var sickle: Array = [
		Vector2(180, 200), Vector2(220, 140), Vector2(280, 110),
		Vector2(340, 130), Vector2(380, 180), Vector2(300, 210), Vector2(250, 230),
	]
	for i in sickle.size():
		var p: Vector2 = sickle[i]
		for dx in range(-3, 4):
			for dy in range(-3, 4):
				var xx := int(p.x) + dx
				var yy := int(p.y) + dy
				if xx >= 0 and yy >= 0 and xx < 512 and yy < 320:
					img.set_pixel(xx, yy, Color(1.0, 0.92, 0.55, 1.0))
		if i + 1 < sickle.size():
			var q: Vector2 = sickle[i + 1]
			var steps := int(p.distance_to(q))
			for s in steps:
				var t := float(s) / float(maxi(steps, 1))
				var m: Vector2 = p.lerp(q, t)
				var mx := int(m.x)
				var my := int(m.y)
				if mx >= 0 and my >= 0 and mx < 512 and my < 320:
					img.set_pixel(mx, my, Color(0.95, 0.8, 0.35, 1.0))
	return ImageTexture.create_from_image(img)

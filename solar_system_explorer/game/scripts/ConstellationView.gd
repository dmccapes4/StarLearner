class_name ConstellationView
extends Node3D
## The fixed star background for EarthShip mode.
##
## Draws every constellation in the catalogue at its true relative position,
## labels them (the zodiac prominently, the rest quietly), and brightens
## whichever one the camera is looking at.
##
## It takes ConstellationData's catalogue -- real J2000 RA/Dec with a correct
## equatorial-to-ecliptic rotation, already covered by tests -- but draws it
## itself rather than calling build_sky, for one reason that matters:
##
##   build_sky draws each star as a world-space sphere of a fixed radius. That
##   is right for the Free Flight playground, where you fly among them, and
##   wrong here. A world-space star grows when the camera zooms, so narrowing
##   the field from 38 degrees to 4 for EclipseViewer would inflate every star
##   into a ball. Real stars do the opposite of that: they never resolve, no
##   matter the magnification. So stars are drawn here as PointGlow quads at a
##   fixed PIXEL size, exactly like the planets.
##
## The other half of that decision is brightness. build_sky sizes stars by an
## art value on a compressed scale, so Sirius and Vega come out nearly equal and
## a third-magnitude star renders as big as Jupiter. Here every star carries its
## real published V magnitude (StarMagnitudes, cross-matched against HYG) and
## goes through the same magnitude-to-pixels function the planets use. One scale
## for the whole sky, which is the only way the planets can look like the
## brightest things in it -- because they are.
##
## Also added on top of the catalogue:
##
##   1. Labels, which build_sky has none of.
##   2. An ANGULAR proximity test. The rest of the project picks constellations
##      by screen-pixel distance, which changes meaning with field of view. A
##      5-degree cone does not.
##   3. Continuous brightening with a falloff, instead of a binary focus flag.
##
## No allocation after setup: each star keeps its own material and the proximity
## boost mutates it in place.

const ConstellationDataScript := preload("res://scripts/ConstellationData.gd")
const ZodiacDataScript := preload("res://scripts/ZodiacData.gd")
const StarMagnitudesScript := preload("res://scripts/StarMagnitudes.gd")
const PointGlowScript := preload("res://scripts/PointGlow.gd")
const BrillianceScript := preload("res://scripts/SolarBrilliance.gd")

## A constellation counts as "looked at" inside this cone, per the spec.
const PROXIMITY_DEG := 5.0
## Brightening ramps in over a slightly wider cone so it fades rather than
## snapping on at exactly 5 degrees.
const FALLOFF_DEG := 8.0
## Extra brightness at full proximity, as a fraction. ConstellationData's own
## focus state is a 1.58x jump; this is deliberately gentler -- the spec asks
## for "brightens slightly".
const BOOST := 0.85
## Star colour. Real stars run from blue-white to orange, but the catalogue
## carries no spectral type, so a neutral warm white is the honest choice.
const STAR_TINT := Color(1.0, 0.97, 0.92)

## Link alpha and emission for the two display states.
## DIM: always-on background lines so every constellation is readable at a glance.
## BRIGHT: the proximate / focused constellation, clearly highlighted.
const LINK_DIM_ALPHA := 0.18
const LINK_DIM_EMISSION := 0.20
const LINK_BRIGHT_ALPHA := 0.68
const LINK_BRIGHT_EMISSION := 1.10
## Angular height of a zodiac label, degrees. Drives pixel_size so text stays
## legible whatever the sphere radius is.
const LABEL_HEIGHT_DEG := 1.15
const MAJOR_LABEL_HEIGHT_DEG := 0.78

## Naked-eye objects with a real angular size, as (RA hours, Dec degrees, V
## magnitude, diameter in degrees). Only the Beehive so far: it is the one case
## where leaving an object out changes whether a constellation can be found at
## all. Magnitude 3.1 makes it naked-eye from a dark site, and at 1.5 degrees it
## is three times the width of the Moon.
const DEEP_SKY := [
	{"name": "Beehive", "ra": 8.6733, "dec": 19.621, "mag": 3.1,
		"size_deg": 1.5},
]

var _radius: float = ConstellationDataScript.SKY_R
## Current camera geometry, needed to hold stars at a fixed pixel size.
var _view_h: float = 600.0
var _fov_deg: float = 38.0
var _glow_tex: Texture2D
var _glow_quad: QuadMesh
## 1 when astronomically dark, 0 in full daylight.
var _dark: float = 1.0
## Labels are wanted at all (caller's choice) and the sky is dark enough for
## them. Both must hold; kept separate so neither can clobber the other.
var _labels_wanted: bool = true
var _labels_dark_ok: bool = true
## When true, all stick-figure lines stay visible at dim alpha; the proximate
## constellation's lines are boosted to full bright. When false (the default,
## used by EarthSkyViewer) lines only appear inside the proximity cone.
var _links_always_dim: bool = false
## id -> {stars: Array[Dictionary], links: Node3D, label: Label3D,
##        dir: Vector3, boost: float, data: Dictionary}
var _entries: Dictionary = {}
var _nearest_id: String = ""
var _closest_id: String = ""
## Extended naked-eye objects: {mi, mat, label, mag}.
var _deep_sky: Array = []

## The constellation inside the proximity cone, or "" when none is.
var nearest_id: String:
	get:
		return _nearest_id

## The closest constellation at any distance. Unlike `nearest_id` this is never
## empty once built, because the camera is always pointing somewhere.
##
## The two exist separately because they answer different questions. The spec's
## 5-degree cone decides what BRIGHTENS, and it should stay strict. But "which
## constellation is the planet in?" always has an answer, and the catalogue
## carries only a handful of stars per figure, so a strict cone would leave the
## readout blank most of the time even when the planet is unambiguously in
## Taurus. The HUD wants this one.
var closest_id: String:
	get:
		return _closest_id

func build(radius: float = ConstellationDataScript.SKY_R) -> void:
	_radius = maxf(radius, 100.0)
	_glow_tex = PointGlowScript.make_texture()
	_glow_quad = PointGlowScript.make_quad()
	for data in ConstellationDataScript.all_constellations(_radius):
		var id: String = str(data["id"])
		var root := Node3D.new()
		root.name = id
		add_child(root)
		var stars: Array = _build_stars(root, id, data)
		var links: Node3D = _build_links(root, data)
		var centre: Vector3 = ConstellationDataScript.center_of(data)
		# Proximity is measured to the nearest STAR, not to the centroid.
		# Constellations are big -- Virgo spans about 40 degrees -- so a
		# 5-degree cone around a centroid would almost never fire, and would
		# ignore you looking straight at Spica. Measuring per star means
		# "pointing at any part of the figure" counts, which is what the eye
		# and the spec both mean by "near a constellation".
		var star_dirs: Array = []
		for sv in data.get("stars", []):
			var v: Vector3 = sv as Vector3
			if v.length() > 0.001:
				star_dirs.append(v.normalized())
		_entries[id] = {
			"stars": stars,
			"star_dirs": star_dirs,
			"links": links,
			"label": _make_label(data, centre, root),
			"dir": centre.normalized(),
			"boost": 0.0,
			"data": data,
		}
	_build_deep_sky()
	_rescale_stars()

## Naked-eye objects that are not points.
##
## Cancer needs this more than any other constellation. Its brightest star is
## fourth magnitude and it has no bright pattern at all -- the reason anyone finds
## it is the Beehive sitting in the middle of it, and the Beehive is not a star
## but a patch about three Moon-diameters wide. Plotted as a point it would be
## indistinguishable from the faint stars around it and would misrepresent the one
## thing that makes it recognisable.
##
## The key difference from a star: this object is genuinely RESOLVED, so it is
## sized in world space and grows when the camera zooms in. Stars are pinned to a
## fixed pixel size precisely because they do not.
func _build_deep_sky() -> void:
	for spec in DEEP_SKY:
		var pos: Vector3 = ConstellationDataScript.sky_pos(
			float(spec["ra"]), float(spec["dec"]), _radius)
		var mi := MeshInstance3D.new()
		mi.mesh = _glow_quad
		mi.position = pos
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mat.billboard_keep_scale = true
		mat.albedo_texture = _glow_tex
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.no_depth_test = true
		mi.material_override = mat
		# True angular size on the sky, in world units at the star shell.
		mi.scale = Vector3.ONE * (_radius
			* tan(deg_to_rad(float(spec["size_deg"]) * 0.5)) * 2.0)
		add_child(mi)
		var label := Label3D.new()
		label.text = str(spec["name"])
		label.position = pos
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.modulate = Color(0.70, 0.80, 0.95, 0.85)
		label.outline_size = 5
		label.pixel_size = _radius * deg_to_rad(0.5) / 40.0
		label.offset = Vector2(0.0, -34.0)
		add_child(label)
		_deep_sky.append({"mi": mi, "mat": mat, "label": label,
			"mag": float(spec["mag"])})

## One additive glow quad per star, sized and faded by its real V magnitude.
func _build_stars(root: Node3D, id: String, data: Dictionary) -> Array:
	var out: Array = []
	var stars: Array = data.get("stars", [])
	for i in stars.size():
		var v: float = StarMagnitudesScript.of(id, i)
		var mi: MeshInstance3D = PointGlowScript.make_quad_instance(
			_glow_quad, _glow_tex)
		mi.position = stars[i] as Vector3
		var mat: StandardMaterial3D = mi.material_override as StandardMaterial3D
		var alpha: float = PointGlowScript.alpha_for(v)
		mat.albedo_color = Color(STAR_TINT.r, STAR_TINT.g, STAR_TINT.b, alpha)
		root.add_child(mi)
		out.append({
			"mi": mi,
			"mat": mat,
			"v": v,
			"alpha": alpha,
			"px": PointGlowScript.diameter_px(v),
		})
	return out

## Stick figure, hidden until the constellation is the one being looked at.
func _build_links(root: Node3D, data: Dictionary) -> Node3D:
	var links := Node3D.new()
	links.name = "Links"
	links.visible = false
	root.add_child(links)
	var stars: Array = data.get("stars", [])
	for link in data.get("links", []):
		var a: int = int(link[0])
		var b: int = int(link[1])
		if a < 0 or b < 0 or a >= stars.size() or b >= stars.size():
			continue
		var seg: MeshInstance3D = ConstellationDataScript._make_link_mesh(
			stars[a] as Vector3, stars[b] as Vector3, 0.55)
		# The catalogue's link material is tuned for the playground, where you
		# fly among bright gold figures. Against a naked-eye sky whose faintest
		# stars are two-pixel pinpricks it reads as a neon overlay, so knock it
		# back to a hint of a line.
		var mat := seg.material_override as StandardMaterial3D
		if mat != null:
			mat.albedo_color = Color(0.86, 0.78, 0.48, 0.30)
			mat.emission_energy_multiplier = 0.35
		links.add_child(seg)
	return links

## Tell the view what the camera is doing. Stars hold a fixed PIXEL size, so
## their world scale has to be recomputed whenever the field of view changes --
## which is how a point source behaves and a sphere does not.
func set_view(view_h: float, fov_deg: float) -> void:
	if is_equal_approx(view_h, _view_h) and is_equal_approx(fov_deg, _fov_deg):
		return
	_view_h = maxf(view_h, 1.0)
	_fov_deg = clampf(fov_deg, 0.01, 179.0)
	_rescale_stars()

func _rescale_stars() -> void:
	for id in _entries:
		_apply_star_look(_entries[id])
	_apply_deep_sky_look()

## Fade the sky for daylight, where `dark` is 0 in full sun and 1 when
## astronomically dark.
##
## Stars do not survive twilight equally: Sirius hangs on well into it while a
## fourth-magnitude star is gone before the Sun has finished setting. The fade
## is therefore applied per star against its own magnitude, so they disappear
## faintest-first and come back brightest-first, which is the most recognisable
## thing about a real twilight.
func set_daylight(dark: float) -> void:
	var d: float = clampf(dark, 0.0, 1.0)
	if is_equal_approx(d, _dark):
		return
	_dark = d
	for id in _entries:
		_apply_star_look(_entries[id])
	# Labels and stick figures are chrome, not sky. They have no business over a
	# daylit blue field where the stars they annotate are gone -- a stray gold
	# line across a blue sky just looks like a rendering fault.
	var show: bool = d > 0.35
	_labels_dark_ok = show
	for id in _entries:
		var e: Dictionary = _entries[id]
		var label: Label3D = e["label"] as Label3D
		if label != null:
			label.visible = show and _labels_wanted
		var links: Node3D = e["links"] as Node3D
		if links == null:
			pass
		elif not show:
			links.visible = false
		elif _links_always_dim:
			links.visible = true
			_set_link_look(links, str(id) == _nearest_id)
		elif str(id) == _nearest_id:
			links.visible = true
	_apply_deep_sky_look()

## Extended objects fade like faint stars, only faster: their light is spread over
## a degree or more instead of concentrated in a point, so a brightening sky
## erases them well before it erases a star of the same total magnitude. The
## Beehive is a dark-sky object for exactly this reason.
func _apply_deep_sky_look() -> void:
	for o in _deep_sky:
		var mat: StandardMaterial3D = o["mat"] as StandardMaterial3D
		var b: float = BrillianceScript.brightness01(float(o["mag"]))
		var a: float = clampf(0.34 * b + 0.06, 0.0, 1.0) * pow(_dark, 1.8)
		mat.albedo_color = Color(0.86, 0.90, 1.0, a)
		var label: Label3D = o["label"] as Label3D
		if label != null:
			label.visible = _dark > 0.35 and _labels_wanted

## Label placed above the asterism. Zodiac signs carry their astrological
## glyph and read gold; the rest are dim, so the twelve stand out without the
## other thirteen becoming invisible.
func _make_label(data: Dictionary, centre: Vector3, root: Node3D) -> Label3D:
	var id: String = str(data.get("id", ""))
	var is_zodiac: bool = str(data.get("kind", "")) == "zodiac"
	var label := Label3D.new()
	var text: String = str(data.get("name", id))
	if is_zodiac:
		# ZodiacData and ConstellationData use identical ids for the twelve,
		# so the glyph can be joined on straight from the other table.
		var sign: Dictionary = ZodiacDataScript.sign_by_id(id)
		var glyph: String = str(sign.get("symbol", ""))
		if not glyph.is_empty():
			text = "%s  %s" % [glyph, text]
	label.text = text
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.font_size = 64 if is_zodiac else 48
	var height_deg: float = LABEL_HEIGHT_DEG if is_zodiac \
		else MAJOR_LABEL_HEIGHT_DEG
	# Label3D height in world units is font_size * pixel_size, so pick
	# pixel_size to subtend a fixed angle from the centre of the sphere.
	label.pixel_size = (_radius * deg_to_rad(height_deg)) \
		/ maxf(float(label.font_size), 1.0)
	label.modulate = Color(1.0, 0.87, 0.45, 0.95) if is_zodiac \
		else Color(0.62, 0.70, 0.86, 0.55)
	label.outline_size = 10 if is_zodiac else 6
	label.outline_modulate = Color(0.0, 0.0, 0.0, 0.75)
	# "Above the constellation": clear of its own topmost star, not just of
	# its centroid, so a tall figure like Gemini is not written across.
	label.position = centre + Vector3.UP * (_figure_reach(data, centre)
		+ _radius * deg_to_rad(height_deg) * 1.6)
	root.add_child(label)
	return label

## Distance from the centroid to the furthest star, so labels clear the figure.
func _figure_reach(data: Dictionary, centre: Vector3) -> float:
	var reach: float = 0.0
	for s in data.get("stars", []):
		reach = maxf(reach, (s as Vector3).distance_to(centre))
	return reach

func set_labels_visible(on: bool) -> void:
	_labels_wanted = on
	for id in _entries:
		var label: Label3D = _entries[id]["label"] as Label3D
		if label != null:
			label.visible = on and _labels_dark_ok

## Show all stick-figure lines at dim alpha when `on` is true, rather than
## hiding them until the camera enters the proximity cone.
##
## Intended for ConstellationViewer, where the whole sky is visible at once
## and the lines act as a built-in star atlas. The proximate / focused
## constellation is automatically boosted to LINK_BRIGHT when `update_proximity`
## runs, so the selection still reads as clearly highlighted.
func set_links_always_dim(on: bool) -> void:
	_links_always_dim = on
	var show: bool = _dark > 0.35
	for id in _entries:
		var e: Dictionary = _entries[id]
		var links: Node3D = e["links"] as Node3D
		if links == null:
			continue
		var is_nearest: bool = str(id) == _nearest_id
		if on:
			links.visible = show
			_set_link_look(links, is_nearest)
		else:
			links.visible = show and is_nearest


## Apply dim or bright material to every cylinder in a links node.
func _set_link_look(links: Node3D, bright: bool) -> void:
	if links == null:
		return
	for seg in links.get_children():
		var mi := seg as MeshInstance3D
		if mi == null:
			continue
		var mat := mi.material_override as StandardMaterial3D
		if mat == null:
			continue
		if bright:
			mat.albedo_color = Color(0.95, 0.86, 0.44, LINK_BRIGHT_ALPHA)
			mat.emission_energy_multiplier = LINK_BRIGHT_EMISSION
		else:
			mat.albedo_color = Color(0.72, 0.65, 0.38, LINK_DIM_ALPHA)
			mat.emission_energy_multiplier = LINK_DIM_EMISSION

## Hide labels that would land underneath the HUD.
##
## The labels live in the sky, the HUD lives on the glass, and neither knows
## about the other -- so a constellation name drifts across the title and the
## date and turns both to mush. Projecting each label and dropping the ones that
## collide is cheap (a couple of dozen unprojections) and it is the only way to
## keep sky text legible without pinning the labels to fixed screen positions,
## which would make them lie about where the constellations are.
func cull_labels(cam: Camera3D, rects: Array) -> void:
	if cam == null:
		return
	for id in _entries:
		var e: Dictionary = _entries[id]
		var label: Label3D = e["label"] as Label3D
		if label == null:
			continue
		var want: bool = _labels_wanted and _labels_dark_ok
		if want:
			var world: Vector3 = label.global_position
			if cam.is_position_behind(world):
				want = false
			else:
				var p: Vector2 = cam.unproject_position(world)
				for r in rects:
					if (r as Rect2).has_point(p):
						want = false
						break
		label.visible = want

## Point the proximity test at wherever the camera is aimed. Brightens the
## constellations inside the cone and reveals the stick figure of the nearest.
##
## Cheap enough to call every frame: 25 dot products plus a material write only
## for constellations whose boost actually changed.
func update_proximity(cam: Camera3D) -> void:
	if cam == null:
		return
	var fwd: Vector3 = -cam.global_transform.basis.z
	if fwd.length() < 0.001:
		return
	fwd = fwd.normalized()
	var best: String = ""
	var best_sep: float = INF
	var closest: String = ""
	var closest_sep: float = INF
	for id in _entries:
		var e: Dictionary = _entries[id]
		var sep: float = separation_deg(fwd, e["star_dirs"] as Array)
		var want: float = proximity_boost(sep)
		if sep < closest_sep:
			closest_sep = sep
			closest = id
		if sep < best_sep and sep <= PROXIMITY_DEG:
			best_sep = sep
			best = id
		if absf(want - float(e["boost"])) > 0.01:
			e["boost"] = want
			_apply_star_look(e)
	_closest_id = closest
	if best != _nearest_id:
		# Stick figures only for the one being looked at, edge-triggered so the
		# visibility flag is not written every frame.
		if _entries.has(_nearest_id):
			var prev: Node3D = _entries[_nearest_id]["links"] as Node3D
			if prev != null:
				if _links_always_dim:
					# Keep visible but drop back to dim rather than hiding.
					_set_link_look(prev, false)
				else:
					prev.visible = false
		if _entries.has(best) and _dark > 0.35:
			var links: Node3D = _entries[best]["links"] as Node3D
			if links != null:
				links.visible = true
				_set_link_look(links, true)
		_nearest_id = best

## Push one constellation's stars to match the current proximity boost, field of
## view and daylight. Every star's appearance funnels through here so the three
## effects compose instead of overwriting one another.
##
## Brightening pushes alpha up and the glare out a little, which is what a star
## looks like when it gets brighter. Faint stars gain proportionally the most,
## so a dim constellation becomes legible rather than staying invisible next to
## its one bright member.
func _apply_star_look(entry: Dictionary) -> void:
	var boost: float = float(entry["boost"])
	# Limiting magnitude: 6 in the dark, dropping to about -2 in full daylight,
	# where only the Moon and Venus at her best would stand a chance.
	var limit: float = lerpf(-2.0, 6.0, _dark)
	for s in entry["stars"]:
		var mat: StandardMaterial3D = s["mat"] as StandardMaterial3D
		var mi: MeshInstance3D = s["mi"] as MeshInstance3D
		if mat == null or mi == null:
			continue
		# Fade over the last magnitude and a half before the limit, so stars
		# wink out gradually rather than the whole sky going at once.
		var vis: float = clampf((limit - float(s["v"])) / 1.5, 0.0, 1.0)
		mat.albedo_color = Color(STAR_TINT.r, STAR_TINT.g, STAR_TINT.b,
			clampf(float(s["alpha"]) * (1.0 + boost) * vis, 0.0, 1.0))
		mi.scale = Vector3.ONE * PointGlowScript.scale_for(
			float(s["px"]) * (1.0 + 0.35 * boost), _view_h, _fov_deg, _radius)
		mi.visible = vis > 0.002

## Display name of a constellation id, or "" if unknown.
func name_of(id: String) -> String:
	if not _entries.has(id):
		return ""
	return str(_entries[id]["data"].get("name", id))

## Unit direction to a constellation, or ZERO if unknown.
func dir_of(id: String) -> Vector3:
	if not _entries.has(id):
		return Vector3.ZERO
	return _entries[id]["dir"] as Vector3

func ids() -> Array:
	return _entries.keys()

# ── Headless-testable helpers ───────────────────────────────────────

## Angle in degrees between two directions.
static func bearing_deg(a: Vector3, b: Vector3) -> float:
	if a.length() < 0.000001 or b.length() < 0.000001:
		return 180.0
	return rad_to_deg(acos(clampf(
		a.normalized().dot(b.normalized()), -1.0, 1.0)))

## Angle to the closest of a set of directions -- the separation from a
## constellation's nearest star.
static func separation_deg(fwd: Vector3, dirs: Array) -> float:
	var best: float = 180.0
	for d in dirs:
		best = minf(best, bearing_deg(fwd, d as Vector3))
	return best

## Brightening 0..1 for an angular separation. Full inside the 5-degree cone
## the spec names, then a smooth ramp out to FALLOFF_DEG so the transition is
## not a visible step.
static func proximity_boost(sep_deg: float) -> float:
	if sep_deg <= PROXIMITY_DEG:
		return BOOST
	if sep_deg >= FALLOFF_DEG:
		return 0.0
	var u: float = (sep_deg - PROXIMITY_DEG) / (FALLOFF_DEG - PROXIMITY_DEG)
	return BOOST * (1.0 - smoothstep(0.0, 1.0, u))

## True when a direction is inside the proximity cone.
static func within_proximity(fwd: Vector3, dir: Vector3) -> bool:
	return bearing_deg(fwd, dir) <= PROXIMITY_DEG

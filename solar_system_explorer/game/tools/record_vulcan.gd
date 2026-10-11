extends SceneTree
## Records the Mercury/Vulcan ladder shots as PNG frame sequences.
##
##   DISPLAY=:1 godot --path game -s res://tools/record_vulcan.gd
##   VULCAN_SHOTS=lock_orrery,binaries DISPLAY=:1 godot --path game -s res://tools/record_vulcan.gd
##
## Reads the DE421-derived JSON written by tools/vulcan/vulcan_derivation.py
## and ladder_analysis.py (docs/MERCURY_VULCAN_LADDER_20261010/data) and
## writes docs/MERCURY_VULCAN_LADDER_20261010/video/<shot>/frame_#####.png.
## Encode with tools/vulcan/encode_vulcan.sh.
##
## Nothing here is simulated by the game loop: every frame is one step of
## the precomputed ephemeris, so the output is deterministic.

const FPS := 30
const W := 1280.0
const H := 600.0
const BG := Color(0.03, 0.035, 0.08)
const AU_KM := 1.495978707e8

var DOC: String
var OUT: String
var E: Dictionary        # ephem_2026_2027_6h.json
var O: Dictionary        # ephem_occultation_closeup.json
var V: Dictionary        # vulcan_derivation.json
var L: Dictionary        # ladder_analysis.json
var M: Dictionary        # ephem_luna_from_mercury.json (2028-02-23 seen from Mercury, 1-min)
var font: Font

func _init() -> void:
	call_deferred("_run")

func _load_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("cannot open " + path)
		return {}
	var d = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}

func _run() -> void:
	DOC = ProjectSettings.globalize_path("res://").path_join("../docs/MERCURY_VULCAN_LADDER_20261010")
	OUT = DOC.path_join("video")
	E = _load_json(DOC.path_join("data/ephem_2026_2027_6h.json"))
	O = _load_json(DOC.path_join("data/ephem_occultation_closeup.json"))
	V = _load_json(DOC.path_join("data/vulcan_derivation.json"))
	L = _load_json(DOC.path_join("data/ladder_analysis.json"))
	font = ThemeDB.fallback_font
	var want := OS.get_environment("VULCAN_SHOTS")
	M = _load_json(DOC.path_join("data/ephem_luna_from_mercury.json"))
	var all_shots := ["lock_orrery", "hill_frame", "occultation_2028", "binaries", "ladder_orrery", "equinox_zecliptic", "luna_from_mercury"]
	var shots: Array = all_shots if want.is_empty() else Array(want.split(","))
	for s in shots:
		await _record(String(s))
	print("all done")
	quit()

func _record(shot: String) -> void:
	var node: Shot
	match shot:
		"lock_orrery": node = LockOrrery.new()
		"hill_frame": node = HillFrame.new()
		"occultation_2028": node = Occultation.new()
		"binaries": node = Binaries.new()
		"ladder_orrery": node = LadderOrrery.new()
		"equinox_zecliptic": node = EquinoxZecliptic.new()
		"luna_from_mercury": node = LunaFromMercury.new()
		_:
			push_error("unknown shot " + shot); return
	node.rec = self
	var dir := OUT.path_join(shot)
	DirAccess.make_dir_recursive_absolute(dir)
	root.add_child(node)
	var n := node.frames()
	print("recording %s: %d frames (%.1f s)" % [shot, n, float(n) / FPS])
	node.set_frame(0); node.queue_redraw()
	for _i in 8:
		await process_frame
	for i in n:
		node.set_frame(i)
		node.queue_redraw()
		await RenderingServer.frame_post_draw
		var img: Image = root.get_texture().get_image()
		img.save_png(dir.path_join("frame_%05d.png" % i))
		if i % 100 == 0:
			print("  %s frame %d/%d" % [shot, i, n])
	root.remove_child(node)
	node.queue_free()
	await process_frame

# ─────────────────────────────────────────────────────────────────────────
# helpers shared by shots
# ─────────────────────────────────────────────────────────────────────────
static func jd_to_label(jd: float) -> String:
	var J := int(floor(jd + 0.5))
	var frac := jd + 0.5 - float(J)
	var a := J + 32044
	var b := (4 * a + 3) / 146097
	var c := a - (146097 * b) / 4
	var d := (4 * c + 3) / 1461
	var e := c - (1461 * d) / 4
	var m := (5 * e + 2) / 153
	var day := e - (153 * m + 2) / 5 + 1
	var month := m + 3 - 12 * (m / 10)
	var year := 100 * b + d - 4800 + m / 10
	var hh := int(frac * 24.0)
	return "%04d-%02d-%02d %02dh" % [year, month, day, hh]

class Shot extends Node2D:
	var rec            # the SceneTree recorder (holds data + font)
	var fi: int = 0
	func frames() -> int: return 1
	func set_frame(i: int) -> void: fi = i
	func F() -> Font: return rec.font
	func txt(p: Vector2, s: String, size: int = 14, col: Color = Color(0.9, 0.92, 1.0), align: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1) -> void:
		draw_string(F(), p, s, align, width, size, col)
	func bg() -> void:
		draw_rect(Rect2(0, 0, 1280, 600), Color(0.03, 0.035, 0.08))
	func title(s: String, sub: String = "") -> void:
		txt(Vector2(0, 26), s, 20, Color(1, 1, 1), HORIZONTAL_ALIGNMENT_CENTER, 1280)
		if not sub.is_empty():
			txt(Vector2(0, 46), sub, 13, Color(1.0, 0.8, 0.33), HORIZONTAL_ALIGNMENT_CENTER, 1280)
	func v3(a: Array) -> Vector3: return Vector3(a[0], a[1], a[2])
	func ring(c: Vector2, r: float, col: Color, w: float = 1.0) -> void:
		draw_arc(c, r, 0.0, TAU, 128, col, w, true)
	func panel(r: Rect2, col: Color = Color(0.07, 0.08, 0.15, 0.92)) -> void:
		draw_rect(r, col); draw_rect(r, Color(0.3, 0.33, 0.45), false, 1.0)

# ─────────────────────────────────────────────────────────────────────────
# SHOT 1 — heliocentric Zecliptic view, anti-Earth lock, 2026 at 12 h/frame
# ─────────────────────────────────────────────────────────────────────────
class LockOrrery extends Shot:
	const PX_AU := 175.0
	const C := Vector2(760, 318)
	func frames() -> int: return 730
	func idx() -> int: return mini(fi * 2, rec.E["jd_tt"].size() - 1)
	func P(a: Array) -> Vector2:
		return C + Vector2(a[0], -a[1]) * PX_AU
	func _draw() -> void:
		bg()
		var E: Dictionary = rec.E
		var k := idx()
		title("Mercury / Vulcan — Config A anti-Earth lock",
			"heliocentric · Zecliptic north up · JPL DE421 · 12 h per frame · Vulcan drawn where the axiom puts it")
		# orbits
		for a in [0.387098, 0.723332, 1.0, 1.523679]:
			ring(C, a * PX_AU, Color(0.3, 0.33, 0.45, 0.6))
		draw_circle(C, 9, Color(1.0, 0.85, 0.35))
		txt(C + Vector2(-10, 24), "Sol", 12, Color(1.0, 0.85, 0.35))
		var pm := P(E["mercury"][k]); var pv := P(E["venus"][k]); var pe := P(E["earth"][k]); var pma := P(E["mars"][k])
		draw_circle(pv, 4.5, Color(0.9, 0.72, 0.4)); txt(pv + Vector2(7, 4), "Venus", 11, Color(0.9, 0.72, 0.4))
		draw_circle(pma, 4, Color(0.8, 0.36, 0.22)); txt(pma + Vector2(7, 4), "Mars", 11, Color(0.8, 0.36, 0.22))
		# Earth + exaggerated Moon (x60)
		draw_circle(pe, 5.5, Color(0.28, 0.55, 0.85)); txt(pe + Vector2(8, -4), "Earth", 11, Color(0.5, 0.7, 1.0))
		var mo: Array = E["moon_geo_km"][k]
		var pmo := pe + Vector2(mo[0], -mo[1]) / AU_KM * PX_AU * 60.0
		draw_circle(pmo, 2.2, Color(0.8, 0.8, 0.85)); txt(pmo + Vector2(5, 3), "Luna (×60)", 9, Color(0.7, 0.7, 0.75))
		# Earth -> Mercury line and the anti-Earth ray
		draw_line(pe, pm, Color(0.3, 0.8, 1.0, 0.55), 1.0, true)
		var dir := (pm - pe).normalized()
		draw_dashed_line(pm, pm + dir * 60.0, Color(1.0, 0.36, 0.48), 1.2, 4.0)
		draw_circle(pm, 4.0, Color(0.66, 0.63, 0.60)); txt(pm + Vector2(6, -6), "Mercury", 11, Color(0.8, 0.8, 0.8))
		var pvul := pm + dir * 22.0
		draw_circle(pvul, 2.8, Color(1.0, 0.36, 0.48)); txt(pvul + Vector2(6, 12), "Vulcan (axiom, exaggerated)", 10, Color(1.0, 0.5, 0.6))
		# Sun -> Earth line (so the libration about it is visible)
		draw_line(C, pe, Color(1.0, 0.85, 0.35, 0.18), 1.0, true)
		# ── inset: Mercury-centred true scale ─────────────────────────
		var box := Rect2(18, 64, 330, 330)
		panel(box)
		var ic := box.position + box.size * 0.5
		var px_km := 150.0 / 900000.0
		var hill: float = E["hill_radius_km"]
		var variants: Dictionary = E["variants"]
		ring(ic, hill * px_km, Color(1.0, 0.36, 0.48, 0.9), 1.4)
		txt(ic + Vector2(hill * px_km + 3, -4), "Hill %.0f km" % hill, 10, Color(1.0, 0.5, 0.6))
		var cols := {"charon_scaled": Color(0.31, 0.82, 1.0), "spin_locked": Color(1.0, 0.7, 0.28), "earth_synchronous": Color(1.0, 0.36, 0.48), "chain_scaled": Color(0.62, 1.0, 0.42)}
		for key in variants:
			var a_km: float = variants[key]["separation_km"]
			ring(ic, a_km * px_km, Color(cols[key], 0.55), 1.0)
		var ff: float = E["free_fall_radius_km"][k]
		var ffr: float = minf(ff * px_km, 150.0)
		ring(ic, ffr, Color(1.0, 0.2, 0.2), 2.0)
		draw_circle(ic, maxf(E["mercury_radius_km"] * px_km, 2.5), Color(0.75, 0.73, 0.7))
		# anti-Earth ray in the inset (same direction as main view)
		var ray := dir
		draw_dashed_line(ic, ic + ray * 160.0, Color(1.0, 0.36, 0.48), 1.0, 3.0)
		draw_line(ic, ic - ray * 40.0, Color(0.3, 0.8, 1.0), 1.0, true)
		txt(ic - ray * 48.0 + Vector2(-16, 4), "to Earth", 9, Color(0.5, 0.8, 1.0))
		for key in variants:
			var a_km: float = variants[key]["separation_km"]
			var p := ic + ray * minf(a_km * px_km, 160.0)
			draw_circle(p, 3.0, cols[key])
		txt(box.position + Vector2(8, 16), "Mercury-centred, true scale (1 px = 6000 km)", 11, Color(0.9, 0.9, 1.0))
		txt(box.position + Vector2(8, 32), "red circle: radius where Mercury's gravity = required rate", 10, Color(1.0, 0.4, 0.4))
		txt(box.position + Vector2(8, 46), "free-fall radius %.0f km = %.2f × Hill%s" % [ff, ff / hill, "  (ring clipped)" if ff * px_km > 150.0 else ""], 10, Color(1.0, 0.4, 0.4))
		var yy := box.end.y - 62
		for key in ["charon_scaled", "spin_locked", "earth_synchronous", "chain_scaled"]:
			var vv: Dictionary = variants[key]
			draw_circle(Vector2(box.position.x + 14, yy - 4), 3, cols[key])
			txt(Vector2(box.position.x + 22, yy), "%s  a=%.0f km" % [vv["label"], vv["separation_km"]], 9, Color(cols[key], 0.95))
			yy += 13
		# ── HUD ───────────────────────────────────────────────────────
		var hud := Rect2(18, 410, 330, 172); panel(hud)
		var jd: float = E["jd_tt"][k]
		txt(hud.position + Vector2(10, 20), rec.jd_to_label(jd) + " TT", 15, Color(1, 1, 1))
		var el: float = E["elongation_signed_deg"][k]
		txt(hud.position + Vector2(10, 42), "Mercury elongation  %+.1f°  (%s)" % [el, "east/evening" if el > 0 else "west/morning"], 12)
		txt(hud.position + Vector2(10, 62), "Earth–Mercury distance  %.3f AU" % (float(E["earth_mercury_dist_km"][k]) / AU_KM), 12)
		var per: float = E["implied_vulcan_period_d"][k]
		txt(hud.position + Vector2(10, 84), "implied Vulcan period  %.0f d" % per, 12, Color(0.31, 0.82, 1.0))
		txt(hud.position + Vector2(10, 100), "(2π ÷ turning rate of the Earth→Mercury line)", 10, Color(0.6, 0.7, 0.8))
		txt(hud.position + Vector2(10, 122), "Kepler period at 16.5 R_M would be 3.73 d", 11, Color(0.9, 0.9, 0.9))
		txt(hud.position + Vector2(10, 140), "Mercury spin 58.65 d  ·  orbit 87.97 d  (3:2)", 11, Color(0.9, 0.9, 0.9))
		txt(hud.position + Vector2(10, 160), "verdict this frame: free-fall radius %s Hill" % ["OUTSIDE" if ff > hill else "inside"], 12, Color(1.0, 0.4, 0.4) if ff > hill else Color(0.6, 1.0, 0.4))

# ─────────────────────────────────────────────────────────────────────────
# SHOT 2 — Mercury-centred: locked Vulcan vs free (Kepler) Vulcan, 180 days
# ─────────────────────────────────────────────────────────────────────────
class HillFrame extends Shot:
	const CL := Vector2(330, 345)     # zoom panel centre (V1 scale)
	const CR := Vector2(950, 345)     # wide panel centre (Hill scale)
	const START := 0
	func frames() -> int: return 360   # 12 h/frame → 180 d
	func idx() -> int: return mini(START + fi * 2, rec.E["jd_tt"].size() - 1)
	func _draw() -> void:
		bg()
		var E: Dictionary = rec.E
		var k := idx()
		title("Mercury-centred frame — a locked Vulcan versus a free Vulcan",
			"left: V1 scale (40,223 km) · right: Hill-sphere scale · Sun and Earth directions from DE421 · 12 h per frame")
		var hill: float = E["hill_radius_km"]
		var variants: Dictionary = E["variants"]
		var cols := {"charon_scaled": Color(0.31, 0.82, 1.0), "spin_locked": Color(1.0, 0.7, 0.28), "earth_synchronous": Color(1.0, 0.36, 0.48), "chain_scaled": Color(0.62, 1.0, 0.42)}
		var u: Array = E["earth_to_mercury_unit"][k]
		var to_earth := -Vector2(u[0], -u[1]).normalized()
		var anti := -to_earth
		var m: Array = E["mercury"][k]
		var to_sun := -Vector2(m[0], -m[1]).normalized()
		var jd0: float = E["jd_tt"][START]
		var jd: float = E["jd_tt"][k]
		var a1: float = variants["charon_scaled"]["separation_km"]
		var T1: float = rec.V["variants"]["charon_scaled"]["kepler_period_d"]
		# ── LEFT: zoom ─────────────────────────────────────────────
		var pl := 120.0 / a1
		ring(CL, 8533.0 * pl, Color(0.7, 0.7, 0.4, 0.8), 1.0)
		txt(CL + Vector2(8533.0 * pl + 4, 4), "Roche 8,533 km", 9, Color(0.8, 0.8, 0.5))
		ring(CL, a1 * pl, Color(0.31, 0.82, 1.0, 0.7), 1.2)
		txt(CL + Vector2(-70, -a1 * pl - 6), "V1 / V4 orbit  a = 40,223 km", 10, Color(0.31, 0.82, 1.0))
		draw_line(CL, CL + to_sun * 150.0, Color(1.0, 0.85, 0.35, 0.5), 1.0, true)
		txt(CL + to_sun * 156.0 + Vector2(-10, 4), "Sun", 10, Color(1.0, 0.85, 0.35))
		draw_line(CL, CL + to_earth * 150.0, Color(0.3, 0.8, 1.0, 0.8), 1.2, true)
		txt(CL + to_earth * 156.0 + Vector2(-14, 4), "Earth", 10, Color(0.5, 0.8, 1.0))
		draw_dashed_line(CL, CL + anti * 150.0, Color(1.0, 0.36, 0.48), 1.2, 4.0)
		var p_lock := CL + anti * a1 * pl
		draw_circle(p_lock, 5.0, Color(1.0, 0.36, 0.48)); txt(p_lock + Vector2(8, 4), "locked (axiom)", 10, Color(1.0, 0.5, 0.6))
		var u0: Array = E["earth_to_mercury_unit"][START]
		var anti0 := Vector2(u0[0], -u0[1]).normalized()
		var ang0 := atan2(anti0.y, anti0.x)
		var ang := ang0 - TAU * (jd - jd0) / T1
		var p_free := CL + Vector2(cos(ang), sin(ang)) * a1 * pl
		# short trail for the free Vulcan
		var trail := PackedVector2Array()
		for s in 25:
			var aa := ang + TAU * (float(s) / 24.0 * 0.5) / T1
			trail.append(CL + Vector2(cos(aa), sin(aa)) * a1 * pl)
		draw_polyline(trail, Color(0.62, 1.0, 0.42, 0.35), 3.0, true)
		draw_circle(p_free, 5.0, Color(0.62, 1.0, 0.42)); txt(p_free + Vector2(8, 4), "free (Kepler 3.73 d)", 10, Color(0.7, 1.0, 0.6))
		draw_circle(CL, 2439.7 * pl, Color(0.75, 0.73, 0.7)); txt(CL + Vector2(-22, 2439.7 * pl + 12), "Mercury", 10)
		# ── RIGHT: wide ────────────────────────────────────────────
		var pr: float = 145.0 / float(variants["earth_synchronous"]["separation_km"])
		ring(CR, hill * pr, Color(1.0, 0.36, 0.48), 1.6)
		txt(CR + Vector2(hill * pr * 0.71 + 4, -hill * pr * 0.71 - 2), "Hill %.0f km" % hill, 10, Color(1.0, 0.5, 0.6))
		for key in ["charon_scaled", "spin_locked", "earth_synchronous"]:
			var a_km: float = variants[key]["separation_km"]
			ring(CR, a_km * pr, Color(cols[key], 0.6), 1.0)
		txt(CR + Vector2(-80, -variants["earth_synchronous"]["separation_km"] * pr - 6), "V3 854,287 km (T = 365 d)", 10, Color(1.0, 0.36, 0.48))
		txt(CR + Vector2(variants["spin_locked"]["separation_km"] * pr * 0.71 + 4, variants["spin_locked"]["separation_km"] * pr * 0.71 + 10), "V2 252,366 km (T = 58.6 d)", 10, Color(1.0, 0.7, 0.28))
		txt(CR + Vector2(6, -variants["charon_scaled"]["separation_km"] * pr - 4), "V1", 9, Color(0.31, 0.82, 1.0))
		var ff: float = E["free_fall_radius_km"][k]
		var ffr := minf(ff * pr, 150.0)
		ring(CR, ffr, Color(1.0, 0.2, 0.2), 2.4)
		txt(CR + Vector2(-110, ffr + 14), "free-fall radius %.0f km = %.2f × Hill%s" % [ff, ff / hill, " (clipped)" if ff * pr > 150.0 else ""], 11, Color(1.0, 0.4, 0.4))
		draw_line(CR, CR + to_sun * 150.0, Color(1.0, 0.85, 0.35, 0.5), 1.0, true)
		draw_line(CR, CR + to_earth * 150.0, Color(0.3, 0.8, 1.0, 0.8), 1.2, true)
		draw_dashed_line(CR, CR + anti * 150.0, Color(1.0, 0.36, 0.48), 1.2, 4.0)
		for key in ["charon_scaled", "spin_locked", "earth_synchronous"]:
			draw_circle(CR + anti * variants[key]["separation_km"] * pr, 3.5, cols[key])
		draw_circle(CR, 3.0, Color(0.75, 0.73, 0.7))
		# ── HUD ────────────────────────────────────────────────────
		var hud := Rect2(18, 64, 300, 120); panel(hud)
		txt(hud.position + Vector2(10, 20), rec.jd_to_label(jd) + " TT", 15, Color(1, 1, 1))
		txt(hud.position + Vector2(10, 40), "days since 2026-01-01: %.1f" % (jd - jd0), 12)
		txt(hud.position + Vector2(10, 58), "free Vulcan: %.2f orbits done" % ((jd - jd0) / T1), 12, Color(0.7, 1.0, 0.6))
		var sep_ang := rad_to_deg(abs(angle_difference(ang, atan2(anti.y, anti.x))))
		txt(hud.position + Vector2(10, 76), "free vs locked: %.0f° apart" % sep_ang, 12, Color(1.0, 0.7, 0.4))
		txt(hud.position + Vector2(10, 96), "they part within a day; gravity cannot hold the lock", 10, Color(1.0, 0.5, 0.5))
		var hud2 := Rect2(962, 64, 300, 120); panel(hud2)
		txt(hud2.position + Vector2(10, 20), "What the lock would need", 13, Color(1, 1, 1))
		txt(hud2.position + Vector2(10, 40), "Mercury gravity at V1: 1.36e-2 m/s²", 11)
		txt(hud2.position + Vector2(10, 56), "centripetal needed:   3.1e-6 m/s²  (÷ 4,400)", 11)
		txt(hud2.position + Vector2(10, 72), "tangential needed:   up to 1.9e-5 m/s²", 11)
		txt(hud2.position + Vector2(10, 90), "no central force gives a tangential push", 11, Color(1.0, 0.6, 0.6))
		txt(hud2.position + Vector2(10, 108), "free-fall radius never enters the Hill sphere", 10, Color(1.0, 0.6, 0.6))
		var ft := Rect2(360, 540, 560, 44); panel(ft)
		txt(ft.position + Vector2(10, 18), "Left: both Vulcans start on the anti-Earth ray on 2026-01-01. The free one obeys Kepler III; the locked one obeys the axiom.", 10, Color(0.9, 0.9, 1.0))
		txt(ft.position + Vector2(10, 34), "Right: the red ring is the radius at which Mercury's gravity would supply the turning rate the axiom demands. It stays outside the Hill sphere.", 10, Color(0.9, 0.9, 1.0))

# ─────────────────────────────────────────────────────────────────────────
# SHOT 3 — 2028-02-23 geocentric lunar occultation of Mercury, 1 min/frame
# ─────────────────────────────────────────────────────────────────────────
class Occultation extends Shot:
	const C := Vector2(640, 322)
	const HALF_MIN := 90.0          # ± minutes around mid-event shown
	const SUB := 4                  # frames per minute (linear interpolation of the 1-min ephemeris)
	func frames() -> int: return int(2.0 * HALF_MIN) * SUB
	func samp(key: String, tmin: float) -> float:
		var arr: Array = rec.O[key]
		var i0 := int(floor(tmin)); var i1 := mini(i0 + 1, arr.size() - 1)
		var u := tmin - float(i0)
		return lerpf(float(arr[i0]), float(arr[i1]), u)
	func _draw() -> void:
		bg()
		var O: Dictionary = rec.O
		var n: int = O["n"]
		var mid := n / 2
		var tmin := float(mid) - HALF_MIN + float(fi) / float(SUB)
		title("Lunar occultation of Mercury — %s UTC (geocentric)  ·  Config A vs Config B" % O["event_utc"],
			"15 s per frame · field 1.4° centred on Mercury · Moon and Mercury discs to scale · inset ×80 · the test the axiom offers")
		var ra0: float = O["mercury_ra_deg"][mid]; var dec0: float = O["mercury_dec_deg"][mid]
		var px_deg := 1280.0 / 1.4
		var cosd := cos(deg_to_rad(dec0))
		var pm := C + Vector2(-(samp("moon_ra_deg", tmin) - ra0) * cosd, -(samp("moon_dec_deg", tmin) - dec0)) * px_deg
		var pe := C + Vector2(-(samp("mercury_ra_deg", tmin) - ra0) * cosd, -(samp("mercury_dec_deg", tmin) - dec0)) * px_deg
		var r_moon_deg := rad_to_deg(atan(1737.4 / samp("moon_dist_km", tmin)))
		var r_merc_deg := rad_to_deg(atan(2439.7 / samp("mercury_dist_km", tmin)))
		# Moon disc (dark side mostly; sunlit limb toward the Sun direction)
		var sun_dir := Vector2(-(float(O["sun_ra_deg"]) - ra0) * cosd, -(float(O["sun_dec_deg"]) - dec0)).normalized()
		draw_circle(pm, r_moon_deg * px_deg, Color(0.16, 0.16, 0.19))
		draw_arc(pm, r_moon_deg * px_deg - 2.0, atan2(sun_dir.y, sun_dir.x) - 1.3, atan2(sun_dir.y, sun_dir.x) + 1.3, 64, Color(0.85, 0.85, 0.8), 3.0, true)
		ring(pm, r_moon_deg * px_deg, Color(0.6, 0.6, 0.65), 1.0)
		txt(pm + Vector2(-20, 0), "Luna", 14, Color(0.7, 0.7, 0.75))
		# Mercury (true angular size ≈ 1 px)
		var behind := pm.distance_to(pe) < r_moon_deg * px_deg
		var merc_col := Color(0.95, 0.9, 0.8) if not behind else Color(0.95, 0.9, 0.8, 0.15)
		draw_circle(pe, maxf(r_merc_deg * px_deg, 2.0), merc_col)
		txt(pe + Vector2(8, -6), "Mercury", 11, merc_col)
		# inset ×120 on Mercury
		var box := Rect2(930, 70, 330, 330); panel(box)
		var ic := box.position + box.size * 0.5
		var mag := 80.0
		var rM := r_merc_deg * px_deg * mag
		var D: float = samp("mercury_dist_km", tmin)
		var a1: float = O["variants"]["charon_scaled"]["separation_km"]
		var rV1: float = O["variants"]["charon_scaled"]["radius_km"]
		# Config B (near side): Vulcan in front, dark disc
		var rVb := rad_to_deg(atan(rV1 / (D - a1))) * px_deg * mag
		# Config A (far side): Vulcan behind, radius smaller
		var rVa := rad_to_deg(atan(rV1 / (D + a1))) * px_deg * mag
		# Moon limb through the inset: distance from Mercury to Moon limb along pm->pe
		var d_centres := pe.distance_to(pm)
		var limb_offset := (d_centres - r_moon_deg * px_deg) * mag   # px in inset units from Mercury centre to limb (positive = limb hasn't reached)
		var ldir := (pe - pm).normalized()
		# left half: Config A, right half: Config B — split by drawing two mini Mercurys
		var cA := ic + Vector2(-80, 10); var cB := ic + Vector2(80, 10)
		for pair in [[cA, true], [cB, false]]:
			var c: Vector2 = pair[0]; var isA: bool = pair[1]
			if isA:
				# hidden behind: dashed outline just inside Mercury's limb
				draw_circle(c, rM, Color(0.95, 0.9, 0.8))
				draw_arc(c, rVa, 0, TAU, 64, Color(1.0, 0.36, 0.48, 0.9), 1.0, true)
				txt(c + Vector2(-rM, rM + 16), "A: Vulcan BEHIND", 11, Color(1.0, 0.5, 0.6))
				txt(c + Vector2(-rM, rM + 30), "r %.2f″ < Mercury %.2f″" % [rad_to_deg(atan(rV1 / (D + a1))) * 3600.0, r_merc_deg * 3600.0], 9, Color(0.9, 0.9, 0.9))
				txt(c + Vector2(-rM, rM + 42), "hidden from Earth and Moon", 9, Color(0.9, 0.9, 0.9))
			else:
				draw_circle(c, rM, Color(0.95, 0.9, 0.8))
				draw_circle(c, rVb, Color(0.05, 0.05, 0.08))
				ring(c, rVb, Color(1.0, 0.36, 0.48), 1.0)
				txt(c + Vector2(-rM, rM + 16), "B: Vulcan IN FRONT", 11, Color(1.0, 0.5, 0.6))
				txt(c + Vector2(-rM, rM + 30), "dark disc, %.0f%% of disc area" % (100.0 * pow(rVb / rM, 2.0)), 9, Color(0.9, 0.9, 0.9))
				txt(c + Vector2(-rM, rM + 42), "seen in any 10 cm telescope", 9, Color(0.9, 0.9, 0.9))
			# lunar limb sweeping through the inset
			if abs(limb_offset) < 200.0:
				var lp := c - ldir * limb_offset
				var perp := Vector2(-ldir.y, ldir.x)
				draw_line(lp - perp * 160.0, lp + perp * 160.0, Color(0.6, 0.6, 0.65), 2.0, true)
				if limb_offset < 0.0:
					# limb has passed: cover the side toward the Moon
					var poly := PackedVector2Array([lp - perp * 160.0, lp + perp * 160.0, lp + perp * 160.0 - ldir * 200.0, lp - perp * 160.0 - ldir * 200.0])
					draw_colored_polygon(poly, Color(0.16, 0.16, 0.19, 0.96))
		txt(box.position + Vector2(8, 16), "inset ×80 — Mercury disc r = %.2f″" % (r_merc_deg * 3600.0), 11, Color(0.9, 0.9, 1.0))
		txt(box.position + Vector2(8, 30), "V1 Charon-scaled Vulcan, a = 40,223 km, R = 1,244 km", 10, Color(0.31, 0.82, 1.0))
		# HUD
		var hud := Rect2(18, 64, 330, 150); panel(hud)
		var minutes := tmin - float(mid)
		txt(hud.position + Vector2(10, 20), "%s  %+.1f min" % [O["event_utc"], minutes], 15, Color(1, 1, 1))
		txt(hud.position + Vector2(10, 42), "Moon–Mercury separation  %.3f°" % (pm.distance_to(pe) / px_deg), 12)
		txt(hud.position + Vector2(10, 60), "Moon radius %.3f°  ·  Mercury %.3f AU" % [r_moon_deg, D / AU_KM], 12)
		txt(hud.position + Vector2(10, 80), "Mercury %s" % ("OCCULTED" if behind else "visible"), 13, Color(1.0, 0.7, 0.4) if behind else Color(0.6, 1.0, 0.6))
		txt(hud.position + Vector2(10, 102), "Config A: Earth→Moon→Mercury→Vulcan", 11, Color(0.9, 0.9, 0.9))
		txt(hud.position + Vector2(10, 118), "Config B: Earth→Moon→Vulcan→Mercury (rare)", 11, Color(0.9, 0.9, 0.9))
		txt(hud.position + Vector2(10, 138), "B predicts a dark bite on Mercury's disc tonight", 11, Color(1.0, 0.5, 0.6))
		var hud2 := Rect2(18, 430, 330, 150); panel(hud2)
		txt(hud2.position + Vector2(10, 20), "Lunar far-side camera test", 13, Color(1, 1, 1))
		txt(hud2.position + Vector2(10, 40), "baseline 384,400 km ⇒ Vulcan shifts 0.18″ (V1)", 11)
		txt(hud2.position + Vector2(10, 56), "Mercury limb margin ≈ 1.8″  → still hidden", 11, Color(1.0, 0.6, 0.6))
		txt(hud2.position + Vector2(10, 72), "V2 (252,366 km): 60% of time visible from Moon", 11, Color(1.0, 0.7, 0.28))
		txt(hud2.position + Vector2(10, 88), "V3 (854,287 km): always visible from Moon", 11, Color(1.0, 0.36, 0.48))
		txt(hud2.position + Vector2(10, 104), "V1 needs a 12-lunar-distance baseline", 11, Color(0.31, 0.82, 1.0))
		txt(hud2.position + Vector2(10, 124), "next geocentric occultations: 2028-02-23", 10, Color(0.7, 0.8, 0.9))
		txt(hud2.position + Vector2(10, 138), "near-misses 2027-01-08, 2027-02-08, 2027-08-01", 10, Color(0.7, 0.8, 0.9))

# ─────────────────────────────────────────────────────────────────────────
# SHOT 4 — Pluto/Charon vs Mercury/Vulcan (V1), barycentres, 20 s
# ─────────────────────────────────────────────────────────────────────────
class Binaries extends Shot:
	func frames() -> int: return 600
	func _draw() -> void:
		bg()
		title("Pluto / Charon  versus  Mercury / Vulcan (Charon-scaled)",
			"both drawn to scale about their barycentres · Pluto/Charon measured (New Horizons) · Mercury/Vulcan as the analogy demands")
		var t_days := float(fi) / 600.0 * 2.0 * 6.387221   # two Charon periods across the clip
		# left: Pluto/Charon
		var cl := Vector2(330, 330)
		var s_pc := 0.0112    # px per km
		var aP := 19591.4; var qP := 0.1217
		var bP := aP * qP / (1 + qP)          # Pluto distance from barycentre
		var bC := aP - bP
		var angP := TAU * t_days / 6.387221
		var pP := cl + Vector2(cos(angP), -sin(angP)) * bP * s_pc
		var pC := cl - Vector2(cos(angP), -sin(angP)) * bC * s_pc
		ring(cl, bP * s_pc, Color(0.5, 0.5, 0.6, 0.5)); ring(cl, bC * s_pc, Color(0.5, 0.5, 0.6, 0.5))
		draw_circle(pP, 1188.3 * s_pc, Color(0.78, 0.70, 0.62)); draw_circle(pC, 606.0 * s_pc, Color(0.6, 0.6, 0.65))
		draw_line(pP, pC, Color(0.4, 0.4, 0.5, 0.6), 1.0, true)
		draw_circle(cl, 2.5, Color(1.0, 0.36, 0.48)); txt(cl + Vector2(5, -5), "barycentre", 10, Color(1.0, 0.5, 0.6))
		txt(pP + Vector2(-18, 1188.3 * s_pc + 14), "Pluto", 11); txt(pC + Vector2(-20, 606 * s_pc + 14), "Charon", 11)
		var pl := Rect2(18, 64, 300, 170); panel(pl)
		txt(pl.position + Vector2(10, 20), "Pluto / Charon (measured)", 14, Color(1, 1, 1))
		txt(pl.position + Vector2(10, 42), "mass ratio q = 0.1217", 11)
		txt(pl.position + Vector2(10, 58), "radius ratio 0.510   a = 16.49 R_P = 19,591 km", 11)
		txt(pl.position + Vector2(10, 74), "period 6.3872 d = Pluto spin = Charon spin", 11)
		txt(pl.position + Vector2(10, 90), "barycentre 2,126 km from Pluto centre (R_P 1,188)", 11)
		txt(pl.position + Vector2(10, 106), "→ OUTSIDE Pluto: a true binary", 11, Color(0.6, 1.0, 0.6))
		txt(pl.position + Vector2(10, 126), "Kepler III check: 6.385 d (0.04 %)", 11, Color(0.6, 1.0, 0.6))
		txt(pl.position + Vector2(10, 146), "t = %.2f d   (%.2f Charon periods)" % [t_days, t_days / 6.387221], 11, Color(1.0, 0.85, 0.35))
		# right: Mercury/Vulcan V1
		var cr := Vector2(950, 330)
		var s_mv := 0.0055
		var aM := 40223.0; var qM := 0.1217
		var bM := aM * qM / (1 + qM); var bV := aM - bM
		var T1 := 3.73
		var angM := TAU * t_days / T1
		var pM := cr + Vector2(cos(angM), -sin(angM)) * bM * s_mv
		var pV := cr - Vector2(cos(angM), -sin(angM)) * bV * s_mv
		ring(cr, bM * s_mv, Color(0.5, 0.5, 0.6, 0.5)); ring(cr, bV * s_mv, Color(0.5, 0.5, 0.6, 0.5))
		draw_circle(pM, 2439.7 * s_mv, Color(0.66, 0.63, 0.60)); draw_circle(pV, 1244.0 * s_mv, Color(1.0, 0.36, 0.48))
		draw_line(pM, pV, Color(0.4, 0.4, 0.5, 0.6), 1.0, true)
		draw_circle(cr, 2.5, Color(1.0, 0.36, 0.48)); txt(cr + Vector2(5, -5), "barycentre", 10, Color(1.0, 0.5, 0.6))
		txt(pM + Vector2(-24, 2439.7 * s_mv + 14), "Mercury", 11); txt(pV + Vector2(-20, 1244 * s_mv + 14), "Vulcan V1", 11, Color(1.0, 0.5, 0.6))
		# V4 chain-scaled dot on the same orbit
		var pV4 := cr + Vector2(cos(angM + 1.2), -sin(angM + 1.2)) * aM * s_mv
		draw_circle(pV4, 2.0, Color(0.62, 1.0, 0.42)); txt(pV4 + Vector2(5, 4), "V4 ≈ 10 km (chain-scaled)", 9, Color(0.7, 1.0, 0.6))
		# Mercury's spin marker (58.65 d) to show the mismatch with 3.73 d
		var spin_ang := TAU * t_days / 58.646
		draw_line(pM, pM + Vector2(cos(spin_ang), -sin(spin_ang)) * 2439.7 * s_mv, Color(0.1, 0.1, 0.15), 2.0, true)
		var pr := Rect2(962, 64, 300, 190); panel(pr)
		txt(pr.position + Vector2(10, 20), "Mercury / Vulcan  V1 (Charon-scaled)", 14, Color(1, 1, 1))
		txt(pr.position + Vector2(10, 42), "q = 0.1217 → M_V = 4.0e22 kg   R_V = 1,244 km", 11)
		txt(pr.position + Vector2(10, 58), "a = 16.49 R_M = 40,223 km", 11)
		txt(pr.position + Vector2(10, 74), "Kepler period 3.73 d", 11)
		txt(pr.position + Vector2(10, 90), "barycentre 4,365 km from Mercury centre (R_M 2,440)", 11)
		txt(pr.position + Vector2(10, 106), "→ OUTSIDE Mercury (1.79 R_M)", 11, Color(0.6, 1.0, 0.6))
		txt(pr.position + Vector2(10, 126), "Mercury's spin is 58.65 d, not 3.73 d: NOT locked", 11, Color(1.0, 0.5, 0.5))
		txt(pr.position + Vector2(10, 142), "reflex wobble 4,365 km vs ranging ~10 m", 11, Color(1.0, 0.5, 0.5))
		txt(pr.position + Vector2(10, 158), "→ 4e5 × detectable; not seen (MESSENGER)", 11, Color(1.0, 0.5, 0.5))
		txt(pr.position + Vector2(10, 178), "V4 (q 2e-8): wobble 0.9 m → survives ranging", 11, Color(0.7, 1.0, 0.6))
		var ft := Rect2(330, 552, 620, 44); panel(ft)
		txt(ft.position + Vector2(10, 18), "Analogy tested: same q, same a/R, same R-ratio.  What the data must then show: Mercury spin = 3.73 d (measured 58.65 d), 4,365 km wobble (measured < 10 m).", 10, Color(0.9, 0.9, 1.0))
		txt(ft.position + Vector2(10, 34), "Both fail for V1.  A Phobos-class Vulcan (V4) passes ranging and parallax but is below Mariner-10 / MESSENGER search limits only if < ~1 km.", 10, Color(0.9, 0.9, 1.0))

# ─────────────────────────────────────────────────────────────────────────
# SHOT 5 — ladder orrery (log radius), AB, HB, Planet X, id/iv highlights
# ─────────────────────────────────────────────────────────────────────────
class LadderOrrery extends Shot:
	const C := Vector2(470, 322)
	var lines := [
		["id Sol : Jupiter : Mars", ["sol", "jupiter", "mars"], "iv Neptune : Saturn : Pluto/Charon", ["neptune", "saturn", "pluto"]],
		["id Mercury/Vulcan : AB : Earth/Luna", ["mercury", "ab", "earth"], "iv Pluto/Charon : HB : Uranus", ["pluto", "hb", "uranus"]],
		["id Venus : Sol : Jupiter", ["venus", "sol", "jupiter"], "iv Saturn : Jupiter : Neptune", ["saturn", "jupiter", "neptune"]],
		["id Earth : AB : Luna", ["earth", "ab", "luna"], "iv Uranus : HB : Uranus rings", ["uranus", "hb", "uranus_rings"]],
		["id Sol : Jupiter : Venus", ["sol", "jupiter", "venus"], "iv Neptune : Jupiter : Saturn", ["neptune", "jupiter", "saturn"]],
		["id AB : Mars : Mercury/Vulcan", ["ab", "mars", "mercury"], "iv HB : Neptune : Pluto/Charon", ["hb", "neptune", "pluto"]],
		["id Mars : Jupiter : Sol", ["mars", "jupiter", "sol"], "iv Planet X : Saturn : Neptune", ["planet_x", "saturn", "neptune"]],
		["id Earth : Luna : Mercury/Vulcan", ["earth", "luna", "mercury"], "iv Uranus : rings : Pluto/Charon", ["uranus", "uranus_rings", "pluto"]],
		["AB : HB : Sol", ["ab", "hb", "sol"], "Sol : HB : AB", ["sol", "hb", "ab"]],
	]
	const PER := 100
	func frames() -> int: return 90 + lines.size() * PER + 120
	func rpx(a_au: float) -> float:
		return 42.0 + 96.0 * log(a_au / 0.3) / log(10.0)
	func pos(a_au: float, ang: float) -> Vector2:
		return C + Vector2(cos(ang), -sin(ang)) * rpx(a_au)
	func ent_pos(id: String) -> Vector2:
		var S: Dictionary = rec.E["snapshot_2026_10_10_helio_au"]
		match id:
			"sol": return C
			"ab": return pos(2.7, deg_to_rad(200.0))
			"hb": return pos(121.6, deg_to_rad(255.7))
			"luna": return ent_pos("earth") + Vector2(10, -8)
			"uranus_rings": return ent_pos("uranus") + Vector2(10, -8)
			"planet_x": return pos(2.793, deg_to_rad(330.0))
			_:
				var p: Array = S[id]
				return pos(Vector2(p[0], p[1]).length(), atan2(p[1], p[0]))
	func _draw() -> void:
		bg()
		var S: Dictionary = rec.E["snapshot_2026_10_10_helio_au"]
		title("The ladder — Zecliptic view, log radius, 2026-10-10 positions (DE421)",
			"AB = asteroid belt with Kirkwood gaps · HB = heliobarrier, blunt nose at λ 255.7° (IBEX) · Planet X at the only non-absurd reading")
		_bottom_panel()
		# belt
		var r_in := rpx(2.06); var r_out := rpx(3.27)
		for i in 40:
			var rr: float = lerpf(r_in, r_out, (float(i) + 0.5) / 40.0)
			ring(C, rr, Color(0.62, 0.58, 0.52, 0.10), (r_out - r_in) / 40.0 + 0.5)
		for g in [2.502, 2.825, 2.958, 3.279]:
			ring(C, rpx(g), Color(0.03, 0.035, 0.08), 1.6)
		txt(C + Vector2(-rpx(2.7) - 70, 0), "AB 2.06–3.27 AU", 10, Color(0.75, 0.7, 0.6))
		# heliobarrier croissant: r(θ) = 121.6 AU × (1 + ((1-cos Δ)/2)^2)
		var nose := deg_to_rad(255.7)
		var hb := PackedVector2Array()
		for i in 181:
			var th := nose + TAU * float(i) / 180.0
			var dlt := th - nose
			var r_au := 121.6 * (1.0 + 1.0 * pow((1.0 - cos(dlt)) * 0.5, 2.0))
			hb.append(pos(r_au, th))
		draw_polyline(hb, Color(0.55, 0.45, 1.0, 0.9), 1.6, true)
		ring(C, rpx(94.0), Color(0.55, 0.45, 1.0, 0.35), 1.0)
		txt(pos(121.6, nose) + Vector2(-60, -8), "HB nose 121.6 AU (V1 heliopause)", 10, Color(0.7, 0.6, 1.0))
		txt(pos(94.0, nose + 0.9) + Vector2(4, 0), "termination shock 94 AU", 9, Color(0.6, 0.55, 0.9))
		# orbits
		var orb := {"mercury": 0.387, "venus": 0.723, "earth": 1.0, "mars": 1.524, "jupiter": 5.203, "saturn": 9.537, "uranus": 19.19, "neptune": 30.07, "pluto": 39.48}
		for id in orb:
			ring(C, rpx(orb[id]), Color(0.3, 0.33, 0.45, 0.7))
		ring(C, rpx(2.793), Color(1.0, 0.3, 0.9, 0.8), 1.0)
		ring(C, rpx(77.2), Color(0.8, 0.8, 0.8, 0.3), 1.0)
		txt(pos(77.2, deg_to_rad(20.0)) + Vector2(4, 0), "Titius–Bode slot 77.2 AU", 9, Color(0.7, 0.7, 0.7))
		draw_circle(C, 8, Color(1.0, 0.85, 0.35)); txt(C + Vector2(-9, 22), "Sol", 11, Color(1.0, 0.85, 0.35))
		var cols := {"mercury": Color(0.66, 0.63, 0.60), "venus": Color(0.9, 0.72, 0.4), "earth": Color(0.28, 0.55, 0.85), "mars": Color(0.8, 0.36, 0.22), "jupiter": Color(0.82, 0.66, 0.48), "saturn": Color(0.86, 0.78, 0.55), "uranus": Color(0.55, 0.82, 0.85), "neptune": Color(0.24, 0.40, 0.90), "pluto": Color(0.78, 0.70, 0.62)}
		var names := {"mercury": "Mercury/Vulcan", "venus": "Venus", "earth": "Earth/Luna", "mars": "Mars+2", "jupiter": "Jupiter+95, ring", "saturn": "Saturn+274, rings", "uranus": "Uranus+28, 13 rings", "neptune": "Neptune+16, rings", "pluto": "Pluto/Charon+4"}
		for id in orb:
			var p := ent_pos(id)
			var rad := 4.0 if id in ["jupiter", "saturn"] else 3.0
			draw_circle(p, rad, cols[id])
			if id in ["saturn", "uranus"]:
				ring(p, rad + 3.0, Color(cols[id], 0.8), 1.0)
			txt(p + Vector2(6, 4), names[id], 10, Color(cols[id], 1.0))
		var px := ent_pos("planet_x")
		draw_circle(px, 3.5, Color(1.0, 0.3, 0.9)); txt(px + Vector2(6, 4), "Planet X (H2): 2.79 AU, 0.03 M⊕", 10, Color(1.0, 0.5, 0.95))
		# right-hand panel
		var pr := Rect2(930, 64, 332, 520); panel(pr)
		txt(pr.position + Vector2(10, 20), "id ↔ iv ladder, tested in dex", 14, Color(1, 1, 1))
		txt(pr.position + Vector2(10, 38), "|residual| < 0.30 dex (×2) counts as holding", 10, Color(0.7, 0.75, 0.85))
		var li := -1
		if fi >= 90:
			li = mini((fi - 90) / PER, lines.size() - 1)
		var y := 60
		for i in lines.size():
			var active := i == li
			var col := Color(1, 1, 1) if active else Color(0.55, 0.6, 0.7)
			txt(pr.position + Vector2(10, y), lines[i][0], 10, Color(0.31, 0.82, 1.0) if active else col)
			txt(pr.position + Vector2(10, y + 13), lines[i][2], 10, Color(1.0, 0.7, 0.28) if active else col)
			y += 30
		# summary of holds from ladder_analysis.json
		var holds: Array = rec.L.get("holds_summary", [])
		txt(pr.position + Vector2(10, y + 10), "holds found: %d of 8×7×4 tests (strong: %d)" % [holds.size(), holds.filter(func(h): return h["strong"]).size()], 11, Color(0.9, 0.9, 0.9))
		txt(pr.position + Vector2(10, y + 26), "strong: Sol:Jup:Venus radius (0.07)", 10, Color(0.6, 1.0, 0.6))
		txt(pr.position + Vector2(10, y + 40), "        density mirror Sol:Jup:Venus ↔ Nep:Jup:Sat", 10, Color(0.6, 1.0, 0.6))
		txt(pr.position + Vector2(10, y + 54), "        a(helio) Earth:Luna ↔ Uranus:rings (0.00)", 10, Color(0.6, 1.0, 0.6))
		txt(pr.position + Vector2(10, y + 74), "mass never holds on any line", 10, Color(1.0, 0.6, 0.6))
		txt(pr.position + Vector2(10, y + 88), "Planet X: H1 → 528 M⊕ at 3.0 AU (absurd)", 10, Color(1.0, 0.6, 0.6))
		txt(pr.position + Vector2(10, y + 102), "          H3 → 0.85 M☉ at 32.6 AU (absurd)", 10, Color(1.0, 0.6, 0.6))
		txt(pr.position + Vector2(10, y + 116), "          H2 → 0.03 M⊕ at 2.79 AU = the belt", 10, Color(1.0, 0.5, 0.95))
		txt(pr.position + Vector2(10, y + 130), "belt holds 0.0004 M⊕: deficit ×80 = pattern break", 10, Color(1.0, 0.5, 0.95))
		# highlight the active line
		if li >= 0:
			var idt: Array = lines[li][1]; var ivt: Array = lines[li][3]
			var pa := PackedVector2Array([ent_pos(idt[0]), ent_pos(idt[1]), ent_pos(idt[2])])
			var pb := PackedVector2Array([ent_pos(ivt[0]), ent_pos(ivt[1]), ent_pos(ivt[2])])
			draw_polyline(pa, Color(0.31, 0.82, 1.0), 2.2, true)
			draw_polyline(pb, Color(1.0, 0.7, 0.28), 2.2, true)
			for p in pa: draw_circle(p, 6, Color(0.31, 0.82, 1.0, 0.5))
			for p in pb: draw_circle(p, 6, Color(1.0, 0.7, 0.28, 0.5))
			var lab := Rect2(18, 500, 880, 84)
			txt(lab.position + Vector2(10, 20), lines[li][0] + "      ⇄      " + lines[li][2], 14, Color(1, 1, 1))
			txt(lab.position + Vector2(10, 42), _best_for(li), 11, Color(0.9, 0.9, 1.0))
			txt(lab.position + Vector2(10, 62), "cyan = id (inner/direct) · orange = iv (outer/inverse) · 'A is to B is to C' tested as A/B = B/C and as mirror equal / mirror inverse", 10, Color(0.7, 0.75, 0.85))
		elif fi < 90:
			var lab := Rect2(18, 500, 880, 84)
			txt(lab.position + Vector2(10, 20), "Radius is log10(a/0.3 AU). Moons and rings sit on their primaries. Nothing is to scale in size; everything is to scale in angle.", 11, Color(0.9, 0.9, 1.0))
			txt(lab.position + Vector2(10, 40), "Mercury is the planet nearest the solar equator (3.38°); Earth is the farthest of the eight (7.25°); Venus and Uranus share the solar node (76.7°, 74.0° vs 75.8°).", 11, Color(0.9, 0.9, 1.0))
			txt(lab.position + Vector2(10, 60), "The HB is drawn as the IBEX/Voyager blunt-nosed shape, not a sphere; its tail length is the model's least-measured number.", 11, Color(0.9, 0.9, 1.0))
		else:
			var lab := Rect2(18, 500, 880, 84)
			txt(lab.position + Vector2(10, 20), "Final chain:  Sol/Jupiter : Pluto/Charon : Earth/Luna : Saturn/rings : Mercury/Vulcan : Mars/moons", 13, Color(1, 1, 1))
			txt(lab.position + Vector2(10, 42), "secondary/primary mass ratio:  9.5e-4 : 0.122 : 0.0123 : 2.7e-8 : (?) : 1.9e-8   — not monotone; read as three mirror pairs it puts Vulcan at q ≈ 2e-8", 11, Color(0.9, 0.9, 1.0))
			txt(lab.position + Vector2(10, 62), "→ Vulcan of ~7e15 kg (Phobos-class, R ≈ 10 km): the one variant that survives ranging and parallax. Its a is unconstrained; chain gives 2.2 R_M (inside fluid Roche).", 11, Color(0.7, 1.0, 0.6))
	func _bottom_panel() -> void:
		panel(Rect2(18, 500, 880, 84), Color(0.07, 0.08, 0.15, 0.80))
	func _best_for(i: int) -> String:
		var res: Array = rec.L.get("ladder_results", [])
		if i >= res.size():
			return "singletons AB:HB:Sol — HB has no mass; in radius the proportion misses by 6.7 dex; in a/T the Sun has no orbit. The line is a boundary statement, not a ratio."
		var best := INF; var bm := ""; var bh := ""
		var mets: Dictionary = res[i]["metrics"]
		for m in mets:
			for h in ["H1_id", "H1_iv", "H2_mirror_eq", "H3_mirror_inv"]:
				var v = mets[m][h]
				if v != null and abs(float(v)) < abs(best):
					best = float(v); bm = m; bh = h
		var verdict := "holds" if abs(best) < 0.3 else "fails (nearest miss)"
		return "closest proportion: %s under %s → residual %+.2f dex  (%s)" % [bm, bh, best, verdict]

# ─────────────────────────────────────────────────────────────────────────
# SHOT 6 — Equinox view: orbit planes against the solar equator
# ─────────────────────────────────────────────────────────────────────────
class EquinoxZecliptic extends Shot:
	const C := Vector2(560, 330)
	const R_SUN := 215.0
	const SOL_I := 7.25
	const SOL_OM := 75.76
	var planets := [["Mercury", 7.005, 48.331, Color(0.66, 0.63, 0.60)], ["Venus", 3.395, 76.680, Color(0.9, 0.72, 0.4)], ["Earth (ecliptic)", 0.0, 0.0, Color(0.28, 0.55, 0.85)],
		["Mars", 1.850, 49.558, Color(0.8, 0.36, 0.22)], ["Jupiter", 1.304, 100.464, Color(0.82, 0.66, 0.48)], ["Saturn", 2.485, 113.666, Color(0.86, 0.78, 0.55)],
		["Uranus", 0.772, 74.006, Color(0.55, 0.82, 0.85)], ["Neptune", 1.770, 131.784, Color(0.24, 0.40, 0.90)], ["Pluto", 17.16, 110.299, Color(0.78, 0.70, 0.62)]]
	func frames() -> int: return 540
	## sample index for the date sweep: Sep 22 2026 (equinox) → Mar 20 2027
	func idx() -> int:
		var jd_eq := 2461305.5 + 0.52   # 2026-09-22 ~12:30 UT
		var jd0: float = rec.E["jd_tt"][0]
		var k0 := int((jd_eq - jd0) * 4.0)
		if fi < 180:
			return k0
		var k1 := k0 + int(179.0 * 4.0)   # +179 days → ~2027-03-20
		return mini(k0 + int(float(fi - 180) / 360.0 * float(k1 - k0)), rec.E["jd_tt"].size() - 1)
	func _draw() -> void:
		bg()
		var E: Dictionary = rec.E
		var k := idx()
		var e: Array = E["earth"][k]
		var lam_sun := rad_to_deg(atan2(e[1], e[0])) + 180.0
		# apparent slope of a plane (i, Ω) across the Sun's disc at solar longitude λ: tan θ = tan i · cos(λ − Ω)
		# tilt toward the viewer (B0-like): sin B = sin i · sin(λ − Ω)
		var roll := 0.0
		var th_sun := rad_to_deg(atan(tan(deg_to_rad(SOL_I)) * cos(deg_to_rad(lam_sun - SOL_OM))))
		var B0 := rad_to_deg(asin(sin(deg_to_rad(SOL_I)) * sin(deg_to_rad(lam_sun - SOL_OM))))
		if fi >= 60 and fi < 180:
			roll = -th_sun * clampf(float(fi - 60) / 90.0, 0.0, 1.0)
		elif fi >= 180:
			roll = -th_sun
		title("Angles judged at the equinox — orbit planes against the solar equator (Zecliptic)",
			"Sun's disc as seen from Earth · solar axis tilted B0 toward/away from us · each line = a planet's orbit plane through the Sun at its on-sky slope")
		# Sun
		draw_circle(C, R_SUN, Color(1.0, 0.72, 0.25, 0.25))
		ring(C, R_SUN, Color(1.0, 0.85, 0.35), 1.5)
		# solar equator as the apparent ellipse arc (bowed by B0), rotated by th_sun + roll
		var rot := deg_to_rad(th_sun + roll)
		var pts := PackedVector2Array()
		for i in 101:
			var ph := -PI / 2.0 + PI * float(i) / 100.0
			var x := R_SUN * sin(ph)
			var yb := -R_SUN * cos(ph) * sin(deg_to_rad(B0))
			var p := Vector2(x, yb).rotated(rot)
			pts.append(C + Vector2(p.x, -p.y))
		draw_polyline(pts, Color(1.0, 0.36, 0.48), 2.4, true)
		var axis := Vector2(0, -R_SUN * 1.25).rotated(rot)
		draw_line(C - axis * 0.9, C + axis, Color(1.0, 0.36, 0.48, 0.8), 1.2, true)
		txt(C + axis + Vector2(6, 0), "solar axis", 10, Color(1.0, 0.5, 0.6))
		txt(pts[100] + Vector2(8, 4), "solar equator  B0 = %+.2f°" % B0, 12, Color(1.0, 0.5, 0.6))
		# ecliptic line
		var ecl := Vector2(1.0, 0.0).rotated(deg_to_rad(roll))
		draw_line(C - ecl * 520.0, C + ecl * 520.0, Color(0.28, 0.55, 0.85, 0.9), 1.4, true)
		txt(C + ecl * 470.0 + Vector2(0, -8), "ecliptic", 11, Color(0.5, 0.7, 1.0))
		# planet planes
		var y := 70
		var pr := Rect2(930, 64, 332, 420); panel(pr)
		txt(pr.position + Vector2(10, 20), "orbit plane    i_ecl    i_SolEq    on-sky slope", 11, Color(1, 1, 1))
		for pl in planets:
			var nm: String = pl[0]; var inc: float = pl[1]; var om: float = pl[2]; var col: Color = pl[3]
			var th := rad_to_deg(atan(tan(deg_to_rad(inc)) * cos(deg_to_rad(lam_sun - om)))) if inc > 0 else 0.0
			var d := Vector2(1.0, 0.0).rotated(deg_to_rad(th + roll))
			var len := 300.0 if nm != "Pluto" else 420.0
			draw_line(C - d * len, C + d * len, Color(col, 0.85), 1.2, true)
			txt(C + d * (len + 6.0) + Vector2(0, 4), nm.split(" ")[0], 10, col)
			var i_se := _incl_between(inc, om, SOL_I, SOL_OM)
			txt(pr.position + Vector2(10, y), "%-15s %6.2f°  %6.2f°   %+6.2f°" % [nm.split(" ")[0], inc, i_se, th - th_sun], 11, col)
			y += 20
		txt(pr.position + Vector2(10, y + 14), "on-sky slope is relative to the solar equator line", 10, Color(0.7, 0.75, 0.85))
		txt(pr.position + Vector2(10, y + 28), "tan θ = tan i · cos(λ☉ − Ω);  sin B0 = sin i · sin(λ☉ − Ω)", 10, Color(0.7, 0.75, 0.85))
		txt(pr.position + Vector2(10, y + 48), "Mercury: nearest the solar equator in 3-D (3.38°)", 10, Color(0.6, 1.0, 0.6))
		txt(pr.position + Vector2(10, y + 62), "Earth: farthest of the eight (7.25°) — by definition", 10, Color(0.6, 1.0, 0.6))
		txt(pr.position + Vector2(10, y + 76), "Venus & Uranus nodes within 2° of the solar node", 10, Color(0.6, 1.0, 0.6))
		# HUD
		var hud := Rect2(18, 64, 330, 120); panel(hud)
		txt(hud.position + Vector2(10, 20), rec.jd_to_label(E["jd_tt"][k]), 15, Color(1, 1, 1))
		txt(hud.position + Vector2(10, 42), "apparent solar longitude λ☉ = %.1f°" % fposmod(lam_sun, 360.0), 12)
		txt(hud.position + Vector2(10, 60), "B0 (equator bow toward us) = %+.2f°" % B0, 12, Color(1.0, 0.5, 0.6))
		txt(hud.position + Vector2(10, 78), "solar equator on-sky slope = %+.2f°" % th_sun, 12, Color(1.0, 0.5, 0.6))
		var phase := "ecliptic horizontal" if fi < 60 else ("rolling to solar equator…" if fi < 180 else "solar equator horizontal · date sweep")
		txt(hud.position + Vector2(10, 100), phase, 11, Color(1.0, 0.85, 0.35))
		var ft := Rect2(18, 500, 880, 84); panel(ft)
		txt(ft.position + Vector2(10, 20), "At the September equinox B0 ≈ +7.03°: the equator bows almost its full 7.25° — the best moment to read the Sun's tilt. Near Jun 6 / Dec 7 it is a straight line (B0 = 0).", 11, Color(0.9, 0.9, 1.0))
		txt(ft.position + Vector2(10, 40), "Rolling the frame by the equator's on-sky slope makes the Zecliptic horizontal; every other plane's angle is then read directly against it.", 11, Color(0.9, 0.9, 1.0))
		txt(ft.position + Vector2(10, 60), "3-D inclinations (right) are frame-independent measurements; on-sky slopes (lines) change with the date — which is why the date matters.", 11, Color(0.9, 0.9, 1.0))
	func _incl_between(i1: float, om1: float, i2: float, om2: float) -> float:
		var a := deg_to_rad(i1); var b := deg_to_rad(i2)
		var c := cos(a) * cos(b) + sin(a) * sin(b) * cos(deg_to_rad(om1 - om2))
		return rad_to_deg(acos(clampf(c, -1.0, 1.0)))

# ─────────────────────────────────────────────────────────────────────────
# SHOT 7 — the mirror: Luna crossing Earth's disc AS SEEN FROM MERCURY,
# 2028-02-23 00:05 UTC ± 6 h (the same event Earth sees as a lunar
# occultation of Mercury). 1 frame per minute of ephemeris, 2 sub-frames.
# ─────────────────────────────────────────────────────────────────────────
class LunaFromMercury extends Shot:
	const C := Vector2(560, 330)
	const SUB := 2
	const PX_PER_ARCSEC := 14.0
	func frames() -> int: return (int(rec.M["n"]) - 1) * SUB
	func samp(key: String, tm: float) -> float:
		var arr: Array = rec.M[key]
		var i0 := int(floor(tm)); var i1 := mini(i0 + 1, arr.size() - 1)
		return lerpf(float(arr[i0]), float(arr[i1]), tm - float(i0))
	func _draw() -> void:
		bg()
		var Mx: Dictionary = rec.M
		var n: int = Mx["n"]; var mid := (n - 1) / 2
		var tm := float(fi) / float(SUB)
		var dt_min := tm - float(mid)
		title("Luna seen FROM MERCURY — 2028-02-23 00:05 UTC %+d min  ·  the mirror of the lunar occultation of Mercury" % int(round(dt_min)),
			"Zecliptic frame: north = Sol's rotation pole, east = Sol's rotation sense (east LEFT, west RIGHT) · discs to scale · 30 s per frame · DE421")
		# sky panel ------------------------------------------------------------
		var rE := samp("earth_radius_arcsec", tm) * PX_PER_ARCSEC
		var rL := samp("moon_radius_arcsec", tm) * PX_PER_ARCSEC
		# Earth: x_rel is +east; on screen east is left → screen x = C.x - x
		draw_circle(C, rE, Color(0.16, 0.42, 0.75))
		ring(C, rE, Color(0.5, 0.75, 1.0), 1.5)
		txt(C + Vector2(-22, rE + 22), "Earth", 16, Color(0.9, 0.95, 1.0))
		# Luna trail (past positions, 1 per 10 min)
		var k := 0
		while k <= int(tm):
			var px := C + Vector2(-float(Mx["moon_x_arcsec_rel_earth"][k]), -float(Mx["moon_y_arcsec_rel_earth"][k])) * PX_PER_ARCSEC
			if k % 10 == 0: draw_circle(px, 1.5, Color(0.8, 0.8, 0.85, 0.5))
			k += 1
		var pL := C + Vector2(-samp("moon_x_arcsec_rel_earth", tm), -samp("moon_y_arcsec_rel_earth", tm)) * PX_PER_ARCSEC
		var in_front := pL.distance_to(C) < rE + rL
		draw_circle(pL, rL, Color(0.62, 0.62, 0.66))
		ring(pL, rL, Color(0.9, 0.9, 0.92), 1.0)
		txt(pL + Vector2(rL + 6, 4), "Luna" + ("  — IN TRANSIT across Earth" if in_front else ""), 13, Color(1.0, 0.85, 0.55))
		# motion arrow: Luna moves to screen-right (west)
		var x0: float = Mx["x_start"]; var x1: float = Mx["x_end"]
		var dir := -1.0 if x1 < x0 else 1.0                     # x decreasing (east→west) → screen x increasing
		var ar := pL + Vector2(0, -rL - 18)
		draw_line(ar, ar + Vector2(-dir * 60.0, 0), Color(1.0, 0.36, 0.48), 3.0, true)
		draw_line(ar + Vector2(-dir * 60.0, 0), ar + Vector2(-dir * 48.0, -7), Color(1.0, 0.36, 0.48), 3.0, true)
		draw_line(ar + Vector2(-dir * 60.0, 0), ar + Vector2(-dir * 48.0, 7), Color(1.0, 0.36, 0.48), 3.0, true)
		txt(ar + Vector2(-dir * 60.0 - 40.0, -14), "WEST" if x1 < x0 else "EAST", 12, Color(1.0, 0.36, 0.48))
		# compass
		txt(Vector2(40, 330), "← E", 14, Color(0.7, 0.75, 0.9)); txt(Vector2(1050, 330), "W →", 14, Color(0.7, 0.75, 0.9))
		txt(Vector2(C.x - 10, 90), "N", 14, Color(0.7, 0.75, 0.9))
		# scale bar 10 arcsec
		draw_line(Vector2(60, 560), Vector2(60 + 10.0 * PX_PER_ARCSEC, 560), Color(0.8, 0.8, 0.9), 2.0)
		txt(Vector2(60, 552), "10 arcsec", 11, Color(0.8, 0.8, 0.9))
		# top-down inset ----------------------------------------------------------
		var box := Rect2(905, 70, 345, 250); panel(box)
		var ic := box.position + Vector2(172, 160)
		var s_au := 95.0                                       # px per AU
		var hm := v3(Mx["helio_mercury_au"][int(tm)]); var he := v3(Mx["helio_earth_au"][int(tm)]); var mg := v3(Mx["moon_geo_km"][int(tm)])
		# frame: rotate so Earth sits at +x
		var ang := -atan2(he.y, he.x)
		var pm := ic + Vector2(hm.x, hm.y).rotated(ang) * Vector2(1, -1) * s_au
		var pe := ic + Vector2(he.x, he.y).rotated(ang) * Vector2(1, -1) * s_au
		draw_circle(ic, 7, Color(1.0, 0.85, 0.3)); txt(ic + Vector2(-10, 20), "Sol", 10, Color(1.0, 0.85, 0.3))
		ring(ic, 0.387 * s_au, Color(0.5, 0.5, 0.6, 0.5)); ring(ic, 1.0 * s_au, Color(0.4, 0.55, 0.8, 0.5))
		draw_circle(pm, 4, Color(0.95, 0.9, 0.8)); txt(pm + Vector2(6, -4), "Mercury", 10, Color(0.95, 0.9, 0.8))
		draw_circle(pe, 5, Color(0.3, 0.6, 1.0)); txt(pe + Vector2(8, 14), "Earth", 10, Color(0.5, 0.75, 1.0))
		# lunar orbit, exaggerated ×40, near half (facing Mercury) in red
		var ex := 40.0
		var r_orb := (384400.0 / 149597870.7) * ex * s_au
		var to_m := (pm - pe).normalized()
		for j in 72:
			var a0 := TAU * float(j) / 72.0; var a1 := TAU * float(j + 1) / 72.0
			var q0 := pe + Vector2(cos(a0), sin(a0)) * r_orb; var q1 := pe + Vector2(cos(a1), sin(a1)) * r_orb
			var near := (q0 - pe).dot(to_m) > 0.0
			draw_line(q0, q1, Color(1.0, 0.36, 0.48) if near else Color(0.4, 0.5, 0.9), 2.0 if near else 1.0, true)
		var pl := pe + Vector2(mg.x, mg.y).rotated(ang) * Vector2(1, -1) * (ex * s_au / 149597870.7)
		draw_circle(pl, 3, Color(0.85, 0.85, 0.9)); txt(pl + Vector2(5, -4), "Luna", 9, Color(0.85, 0.85, 0.9))
		draw_line(pm, pe, Color(0.8, 0.8, 0.8, 0.35), 1.0, true)
		txt(box.position + Vector2(10, 16), "Zecliptic (solar equator) view, Sol's pole up; lunar orbit ×40", 11, Color(1.0, 0.8, 0.33))
		txt(box.position + Vector2(10, 238), "red half: Luna moves WEST in Mercury's sky", 10, Color(1.0, 0.36, 0.48))
		# text panel ------------------------------------------------------------
		var tb := Rect2(905, 335, 345, 245); panel(tb)
		var y := tb.position.y + 20; var x := tb.position.x + 10
		var lines := [
			"Earth sees Luna move EAST across Mercury.",
			"Mercury sees Luna move WEST across Earth.",
			"",
			"Same orbit, same sense (prograde). Earth watches",
			"from the CENTRE of Luna's orbit — every part of it",
			"moves east. Mercury watches from OUTSIDE — the",
			"half facing Mercury moves west, the far half east.",
			"",
			"DE421, 2026-27: Luna moves west relative to Earth",
			"98.0 % of the time on the Mercury-facing half,",
			"2.4 % on the far half. Five Earth-transits by Luna",
			"from Mercury in 2026-27, all westward.",
			"",
			"Earth-Mercury %.3f AU · Earth %.1f\" · Luna %.1f\"" % [float(Mx["earth_mercury_dist_au"]), samp("earth_radius_arcsec", tm), samp("moon_radius_arcsec", tm)],
			"Earth B0 %+.2f° · Mercury B %+.2f° (solar latitude)" % [float(Mx["earth_B0_deg"]), float(Mx["mercury_B_deg"])]]
		for s in lines:
			txt(Vector2(x, y), s, 11, Color(0.9, 0.92, 1.0)); y += 15

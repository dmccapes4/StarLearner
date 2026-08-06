extends SceneTree
## Smoke checks for Zodiac Sky data + scene wiring.
##   DISPLAY=:1 godot --path . -s res://tools/zodiac_suite.gd

const ZodiacDataScript := preload("res://scripts/ZodiacData.gd")
const ConstellationScene := preload("res://scripts/ConstellationScene.gd")

var _pass := 0
var _fail := 0

func _init() -> void:
	call_deferred("_run")

func _check(name: String, ok: bool, detail: String = "") -> void:
	if ok:
		_pass += 1
		print("OK   ", name, (" — " + detail) if not detail.is_empty() else "")
	else:
		_fail += 1
		print("FAIL ", name, (" — " + detail) if not detail.is_empty() else "")

func _run() -> void:
	var signs: Array = ZodiacDataScript.signs()
	_check("twelve_signs", signs.size() == 12, "n=%d" % signs.size())
	var ids: Dictionary = {}
	for s in signs:
		var id := str(s["id"])
		_check("%s_unique" % id, not ids.has(id), id)
		ids[id] = true
		_check("%s_stars" % id, (s["stars"] as Array).size() >= 4,
			"n=%d" % (s["stars"] as Array).size())
		_check("%s_vo" % id,
			not str(s["astronomy"]).is_empty() \
			and not str(s["astrology"]).is_empty() \
			and not str(s["line_earth"]).is_empty(),
			str(s["name"]))
		var c: Vector3 = ZodiacDataScript.center_of(s)
		_check("%s_on_shell" % id,
			c.length() > ZodiacDataScript.RING_R * 0.7 \
			and c.length() < ZodiacDataScript.RING_R * 1.35,
			"r=%.1f" % c.length())
		var long_deg: float = float(s["long_deg"])
		var earth_r: float = ZodiacDataScript.earth_orbit_radius()
		var ep: Vector3 = ZodiacDataScript.earth_season_pos(long_deg, earth_r)
		# Earth opposite the sign: ep · sign_dir < 0 and |ep| ≈ earth_r.
		var dir: Vector3 = ZodiacDataScript.sign_dir(long_deg)
		_check("%s_earth_opposite" % id,
			ep.dot(dir) < -earth_r * 0.9 \
			and absf(ep.length() - earth_r) < 0.5,
			"dot=%.2f |e|=%.1f" % [ep.dot(dir), ep.length()])

	var shell := ZodiacDataScript.playground_shell_radius(700.0, 220.0)
	_check("playground_shell_beyond_planets",
		shell > 700.0 * 1.2 and shell >= ZodiacDataScript.RING_R,
		"shell=%.1f" % shell)

	var tex: Texture2D = ZodiacDataScript.make_tile_texture()
	_check("tile_texture", tex != null, "tex")

	var sky_host := Node3D.new()
	get_root().add_child(sky_host)
	var built: Dictionary = ZodiacDataScript.build_sky(sky_host)
	_check("build_sky_count", built.size() == 12, "n=%d" % built.size())
	_check("build_sky_leo", built.has("leo"), "keys")

	var root := Window.new()
	root.size = Vector2i(1280, 600)
	get_root().add_child(root)
	var scene := ConstellationScene.new()
	root.add_child(scene)
	await process_frame
	scene.begin()
	await process_frame
	_check("scene_active", scene._active and scene.visible, "active")
	_check("scene_sign_count", scene._signs.size() == 12,
		"n=%d" % scene._signs.size())
	scene._begin_seek("leo")
	_check("seek_leo",
		scene._state == ConstellationScene.State.SEEKING \
		and scene._seek_id == "leo",
		"state=%s id=%s" % [scene._state, scene._seek_id])
	for _i in 200:
		scene._seek_tick(0.1)
		if scene._state != ConstellationScene.State.SEEKING:
			break
	_check("arrive_or_vo",
		scene._state == ConstellationScene.State.ARRIVING \
		or scene._visit_id == "leo",
		"state=%s visit=%s" % [scene._state, scene._visit_id])

	scene.begin_at("virgo")
	await process_frame
	_check("begin_at_virgo",
		scene._visit_id == "virgo" \
		or scene._state == ConstellationScene.State.ARRIVING \
		or scene._state == ConstellationScene.State.EARTH_CINE \
		or scene._state == ConstellationScene.State.IDLE,
		"state=%s visit=%s" % [scene._state, scene._visit_id])

	# Season cine: Earth stays on orbit radius, never teleported to the shell.
	scene._start_earth_cine("leo")
	await process_frame
	var er: float = ZodiacDataScript.earth_orbit_radius(scene._ring_r)
	var elen: float = scene._earth.global_position.length()
	_check("cine_earth_on_orbit",
		scene._earth.visible and elen < er * 1.15 and elen > er * 0.5,
		"|e|=%.1f orbit=%.1f" % [elen, er])
	_check("cine_not_on_shell",
		elen < scene._ring_r * 0.35,
		"|e|=%.1f shell=%.1f" % [elen, scene._ring_r])

	print("ZODIAC suite done passed=%d failed=%d" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)

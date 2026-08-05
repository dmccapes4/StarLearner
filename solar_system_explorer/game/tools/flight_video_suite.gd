extends SceneTree
## Record short (~12s) Mission Flight clips with per-frame sim ground truth.
##
##   ./qa/run_flight_video_suite.sh
##
## Each trip folder under qa/out/flight_video/<stamp>/<trip_id>/:
##   frames/f_XXXX.png   — rendered canopy
##   sim.jsonl           — one JSON object per frame (what sim says is visible)
##   route.json          — charted course + encounters + realism
##   meta.json           — trip config / timing
##
## Shell runner muxes frames → flight.mp4 and optionally runs vision review.

const Starfield := preload("res://scripts/Starfield.gd")
const FlySceneScript := preload("res://scripts/FlyScene.gd")
const NavModes := preload("res://scripts/NavModes.gd")

const VIEW := Vector2i(1280, 600)
const CAPTURE_FPS := 12
const TARGET_S := 12.0          ## wall / movie seconds per trip
const ORBIT_TAIL_S := 2.0       ## of TARGET_S spent in orbit park

## Diverse hops: outward gas giants, inner, return, belt-crossing.
const TRIPS := [
	{
		"id": "earth_saturn_astro",
		"from": "earth", "to": "saturn",
		"pace": "astrogator", "prop": "chemical",
		"mode": NavModes.MODE_SIM_VIEW,
		"note": "Rocket Science SIM_VIEW — Jupiter close pass expected mid-cruise",
	},
	{
		"id": "earth_mars_kid",
		"from": "earth", "to": "mars",
		"pace": "kid", "prop": "chemical",
		"mode": NavModes.MODE_MARKERS,
		"note": "Quick Course MARKERS — regression vs Rocket Science cockpit",
	},
	{
		"id": "earth_neptune_astro",
		"from": "earth", "to": "neptune",
		"pace": "astrogator", "prop": "orion",
		"mode": NavModes.MODE_SIM_VIEW,
		"note": "Outer hop — dest should loom late; peers must stay honest",
	},
	{
		"id": "jupiter_earth_astro",
		"from": "jupiter", "to": "earth",
		"pace": "astrogator", "prop": "ntp",
		"mode": NavModes.MODE_SIM_VIEW,
		"note": "Inbound return — camera faces travel (toward Sun/Earth)",
	},
	{
		"id": "earth_jupiter_astro",
		"from": "earth", "to": "jupiter",
		"pace": "astrogator", "prop": "chemical",
		"mode": NavModes.MODE_SIM_VIEW,
		"note": "Belt-crossing hop — destination Jupiter should grow",
	},
]

var _out_abs: String = ""
var _manifest: Dictionary = {}
var _checks: Array = []

func _init() -> void:
	call_deferred("_run")

func _qa_root() -> String:
	var game_dir := ProjectSettings.globalize_path("res://").rstrip("/")
	return game_dir.get_base_dir().path_join("qa/out/flight_video")

func _selected_trips() -> Array:
	## FLIGHT_TRIPS=earth_jupiter_astro,earth_saturn_astro — empty = all.
	var filt := OS.get_environment("FLIGHT_TRIPS").strip_edges()
	if filt.is_empty():
		return TRIPS.duplicate(true)
	var want: Dictionary = {}
	for part in filt.split(","):
		var id := part.strip_edges()
		if not id.is_empty():
			want[id] = true
	var out: Array = []
	for trip in TRIPS:
		if want.has(str(trip["id"])):
			out.append(trip)
	return out

func _run() -> void:
	print("======== Solar FLIGHT VIDEO suite ========")
	root.get_viewport().size = VIEW
	var idle := root.get_node_or_null("/root/IdleGuard")
	if idle != null and idle.has_method("set_active"):
		idle.call("set_active", false)
	paused = false
	Narrator.stop()

	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	_out_abs = _qa_root().path_join(stamp)
	DirAccess.make_dir_recursive_absolute(_out_abs)
	var trips: Array = _selected_trips()
	_manifest = {
		"suite": "flight_video",
		"stamp": stamp,
		"viewport": {"w": VIEW.x, "h": VIEW.y},
		"capture_fps": CAPTURE_FPS,
		"target_s": TARGET_S,
		"flight_trips_filter": OS.get_environment("FLIGHT_TRIPS"),
		"trips": [],
		"checks": [],
		"agent_brief": _agent_brief(),
	}
	_check("trips_selected", not trips.is_empty(),
		"FLIGHT_TRIPS=%s → %d trips" % [
			OS.get_environment("FLIGHT_TRIPS"), trips.size()])

	var cfg := SolarFlyerConfig.load_default()
	for trip in trips:
		await _capture_trip(trip, cfg)

	_manifest["checks"] = _checks
	FileAccess.open(_out_abs.path_join("report.json"), FileAccess.WRITE) \
		.store_string(JSON.stringify(_manifest, "\t"))
	var fails := 0
	for c in _checks:
		if not c.get("ok", false):
			fails += 1
	print("FLIGHT_VIDEO done → %s (%d trips, %d fails)" % [
		_out_abs, (_manifest["trips"] as Array).size(), fails])
	quit(1 if fails > 0 else 0)

func _capture_trip(trip: Dictionary, cfg: SolarFlyerConfig) -> void:
	var tid: String = str(trip["id"])
	var from_id: String = str(trip["from"])
	var to_id: String = str(trip["to"])
	print("\n=== CAPTURE ", tid, " ===")
	var trip_dir := _out_abs.path_join(tid)
	var frames_dir := trip_dir.path_join("frames")
	DirAccess.make_dir_recursive_absolute(frames_dir)

	var origin := SolarData.flyer_body_by_id(from_id, cfg)
	var dest := SolarData.flyer_body_by_id(to_id, cfg)
	_check("%s_bodies" % tid, not origin.is_empty() and not dest.is_empty(),
		"%s→%s" % [from_id, to_id])
	if origin.is_empty() or dest.is_empty():
		return

	var t0 := 0.0
	var budget: Dictionary = {}
	if str(trip["pace"]) == "astrogator":
		var phase: float = AstrogatorPanel.phase_now_rad(origin, dest, 0.0)
		budget = RealismBudget.hop_budget(origin, dest, phase)
		if bool(budget.get("ok", false)):
			t0 = float(budget.get("window_wait_yr", 0.0)) * cfg.game_year_seconds

	var prefer := OrbitMath.body_pos(dest, t0)
	if prefer.length() < 0.001:
		prefer = Vector3.RIGHT
	var ship_pos := OrbitMath.park_pos(origin, t0, cfg, prefer)
	var depart := 0.0
	if not bool(origin.get("is_star", false)):
		depart = OrbitMath.orbit_standoff(float(origin.get("hero_r", 2.0)))
	var route := OrbitMath.plot_route(ship_pos, dest, t0, cfg, depart)
	route["origin_id"] = from_id
	route["dest_name"] = str(dest.get("name", to_id))
	route["travel_au"] = absf(float(dest.get("a_au", 0.0)) - float(origin.get("a_au", 0.0)))
	route["pace_mode"] = str(trip["pace"])
	route["propulsion_id"] = str(trip["prop"])
	route["realism"] = budget
	route["t_depart"] = t0
	route["window_wait_yr"] = float(budget.get("window_wait_yr", 0.0))

	# Serializable route snapshot (no Curve3D / Packed*).
	var clearance := _course_clearance(route, cfg, from_id, to_id, t0)
	var route_pub := {
		"from": from_id,
		"to": to_id,
		"origin_id": from_id,
		"t_depart": t0,
		"duration": float(route.get("duration", 0.0)),
		"t_arr": float(route.get("t_arr", 0.0)),
		"path_len": float(route.get("path_len", 0.0)),
		"min_sun_dist": float(route.get("min_sun_dist", 0.0)),
		"pace_mode": route["pace_mode"],
		"propulsion_id": route["propulsion_id"],
		"travel_au": route["travel_au"],
		"encounters": route.get("encounters", []),
		"course_clearance": clearance,
		"realism": _json_safe(budget),
		"narration": OrbitMath.trip_narration(origin, dest, route, cfg),
		"invariant": ("Charted timeline is flight source of truth. "
			+ "No collision dodge / bounce. Meshes are presentation only."),
	}
	FileAccess.open(trip_dir.path_join("route.json"), FileAccess.WRITE) \
		.store_string(JSON.stringify(route_pub, "\t"))

	var bg := Starfield.new()
	root.add_child(bg)
	var fly: FlyScene = FlySceneScript.new()
	root.add_child(fly)
	fly.cinematic_enabled = false
	fly.render_mode = int(trip["mode"])
	fly.set_active(true)
	fly.begin_flight(to_id, route, t0)
	fly.set_process(false)
	fly.set_physics_process(false)

	var total_frames: int = int(round(TARGET_S * float(CAPTURE_FPS)))
	var orbit_frames: int = int(round(ORBIT_TAIL_S * float(CAPTURE_FPS)))
	var cruise_frames: int = maxi(total_frames - orbit_frames, 1)
	var sim_path := trip_dir.path_join("sim.jsonl")
	var sim_f := FileAccess.open(sim_path, FileAccess.WRITE)
	_check("%s_sim_file" % tid, sim_f != null, sim_path)

	for fi in total_frames:
		var movie_t: float = float(fi) / float(CAPTURE_FPS)
		var in_orbit: bool = fi >= cruise_frames
		var path_u: float = 1.0
		if not in_orbit:
			path_u = float(fi) / float(maxi(cruise_frames - 1, 1))
			fly._flying = true
			fly._orbiting = false
			if fly._cam.get_parent() != fly._ship_rig:
				fly._cam.reparent(fly._ship_rig, false)
				fly._cam.position = Vector3.ZERO
			fly._place_ship_at_path(path_u)
			fly._play_u = path_u
			fly._progress_u = path_u
		else:
			if not fly._orbiting:
				fly._enter_orbit_from_timeline()
			fly._process_orbit(1.0 / float(CAPTURE_FPS))
			path_u = 1.0
		fly._place_bodies_at(fly._clock)
		fly._render_bodies()
		fly._update_hud()
		await process_frame
		await process_frame

		var snap: Dictionary = fly.debug_visibility_snapshot(path_u, movie_t)
		snap["frame"] = fi
		snap["in_orbit"] = in_orbit
		snap["trip_id"] = tid
		if sim_f != null:
			sim_f.store_line(JSON.stringify(snap))

		var img: Image = root.get_viewport().get_texture().get_image()
		if img != null:
			img.save_png(frames_dir.path_join("f_%04d.png" % fi))

	if sim_f != null:
		sim_f.close()

	var meta := {
		"id": tid,
		"note": str(trip.get("note", "")),
		"from": from_id,
		"to": to_id,
		"pace": trip["pace"],
		"prop": trip["prop"],
		"render_mode": int(trip["mode"]),
		"render_mode_label": NavModes.label(int(trip["mode"])),
		"t0": t0,
		"duration_sim_s": float(route.get("duration", 0.0)),
		"capture_fps": CAPTURE_FPS,
		"target_s": TARGET_S,
		"frame_count": total_frames,
		"frames_dir": "frames",
		"sim_jsonl": "sim.jsonl",
		"route_json": "route.json",
	}
	FileAccess.open(trip_dir.path_join("meta.json"), FileAccess.WRITE) \
		.store_string(JSON.stringify(meta, "\t"))
	(_manifest["trips"] as Array).append(meta)
	_check("%s_frames" % tid,
		DirAccess.open(frames_dir) != null, "frames written")

	fly.queue_free()
	bg.queue_free()
	await _settle(2)

## Min ship↔body distance along the charted curve (× hero). Proves the path
## never enters a planet — any glass-filling disc is a render bug, not truth.
func _course_clearance(route: Dictionary, cfg: SolarFlyerConfig,
		from_id: String, to_id: String, t0: float) -> Dictionary:
	if not route.has("curve"):
		return {}
	var curve: Curve3D = route["curve"]
	var clen: float = maxf(curve.get_baked_length(), 0.001)
	var t_arr: float = float(route.get("t_arr", 0.0))
	var out: Dictionary = {}
	for bid in [from_id, to_id, "mars", "jupiter", "saturn", "venus", "earth"]:
		var b := SolarData.flyer_body_by_id(bid, cfg)
		if b.is_empty() or out.has(bid):
			continue
		var hero: float = maxf(float(b.get("hero_r", 1.0)), 0.001)
		var min_d := INF
		var min_pu := 0.0
		for i in 61:
			var u: float = float(i) / 60.0
			var s: float = OrbitMath.burn_progress(u, clen, cfg) * clen
			var p: Vector3 = curve.sample_baked(s)
			var bp: Vector3 = OrbitMath.body_pos(b, t0 + t_arr * u)
			var d: float = p.distance_to(bp)
			if d < min_d:
				min_d = d
				min_pu = s / clen
		out[bid] = {
			"min_dist": min_d,
			"min_hero_x": min_d / hero,
			"at_path_u": min_pu,
			"inside_hero": min_d < hero,
			"role": ("origin" if bid == from_id
				else ("dest" if bid == to_id else "peer")),
		}
	return out

func _json_safe(v: Variant) -> Variant:
	match typeof(v):
		TYPE_DICTIONARY:
			var out := {}
			for k in (v as Dictionary).keys():
				out[str(k)] = _json_safe((v as Dictionary)[k])
			return out
		TYPE_ARRAY:
			var arr: Array = []
			for e in (v as Array):
				arr.append(_json_safe(e))
			return arr
		TYPE_FLOAT, TYPE_INT, TYPE_BOOL, TYPE_STRING:
			return v
		_:
			return str(v)

func _settle(n: int) -> void:
	for _i in n:
		await process_frame

func _check(name: String, ok: bool, detail: String) -> void:
	_checks.append({"name": name, "ok": ok, "detail": detail})
	print(("OK  " if ok else "FAIL"), " ", name, " — ", detail)

func _agent_brief() -> String:
	return ("Flight video QA. Each trip has frames/ + sim.jsonl + route.json. "
		+ "Review with ./qa/review_flight_videos.py — compare rendered canopy "
		+ "to sim visibility (bearing, angular px, in_fov). FAIL means capture broke.")

extends SceneTree
## Narrated homeostasis visualization — census, pressures, JH/nutrition, speed & zoom.
##
##   GODOT_USER_DATA_DIR=/tmp/ant_homeo_demo \
##   godot --path game --fixed-fps 24 --disable-vsync \
##     --write-movie /tmp/ant_homeostasis.avi \
##     -s res://tools/record_homeostasis_demo.gd

const FPS := 24.0
const VizScript := preload("res://tools/HomeostasisVizOverlay.gd")
func _init() -> void:
	call_deferred("_run")

func _cfg() -> Object:
	return root.get_node("Config").get("data")

func _vo_path(key: String) -> String:
	var res := "res://assets/audio/vo/homeostasis_demo/%s.wav" % key
	if FileAccess.file_exists(res):
		return res
	return "/home/dylanmccapes/dev/star_learning/ant_explorer/docs/demo/vo_homeo/%s.wav" % key

func _run() -> void:
	root.get_viewport().size = Vector2i(1280, 600)
	var save := root.get_node("Save")
	save.call("clear_all")
	save.set("intro_completed", true)

	var main: Node = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var hud := main.get_node_or_null("DebugHUD")
	if hud:
		hud.visible = false
	_silence_idle()
	_force_sim_running()

	var intro := get_first_node_in_group("intro_panel")
	if intro != null and intro.has_method("_finish"):
		intro.call("_finish")
	paused = false
	await _sec(0.6)
	_force_sim_running()
	print("HOMEO: sim armed tick=%d enabled=%s" % [_sim_tick(), _sim_enabled()])

	var world: Node = get_first_node_in_group("world")
	if world == null:
		push_error("HOMEOdemo: no world")
		quit(1)
		return
	var colony: Node = world.get("colony")
	var cam: Camera2D = world.get("camera") as Camera2D
	var viz: CanvasLayer = VizScript.new()
	main.add_child(viz)
	viz.call("set_colony", colony)

	var shell := get_first_node_in_group("landscape_shell")
	if shell != null:
		shell.visible = false

	var voice := AudioStreamPlayer.new()
	voice.name = "HomeoNarration"
	voice.process_mode = Node.PROCESS_MODE_ALWAYS
	main.add_child(voice)

	var base_hz: float = float(_cfg().sim_hz)
	var base_zoom: float = float(cam.zoom.x) if cam else 1.0
	var saved_tgt: int = int(_cfg().target_soldiers)

	print("HOMEO: beat 1 — open / census")
	viz.call("set_mode", 0)
	viz.call("set_chrome", "HOMEOSTASIS — the feedback nerve", "census every tick · pressures vs targets", "1×")
	_set_hz(base_hz)
	_look_at(cam, _chamber_center(world, "nursery"), base_zoom * 1.35)
	await _speak(voice, "01_open")
	_log_sim("after beat 1")

	print("HOMEO: beat 2 — larval nutrition / JH")
	viz.call("set_chrome", "LARVAL SPACE — nutrition & juvenile hormone", "score = nutrition + 2·JH  decides caste at pupation", "1×")
	_look_at(cam, _chamber_center(world, "nursery"), base_zoom * 1.6)
	await _speak(voice, "02_larval")
	_log_sim("after beat 2")

	print("HOMEO: beat 3 — food shock")
	viz.call("set_chrome", "SHOCK — garden health drops", "food demand rises → foragers urged back to work", "1×")
	if colony.get("garden") != null:
		colony.garden.health = 0.18
		colony.garden.waste = 0.35
	_look_at(cam, _chamber_center(world, "garden_a"), base_zoom * 1.15)
	await _speak(voice, "03_shock")
	_log_sim("after beat 3")

	print("HOMEO: beat 4 — soldier surplus")
	if colony.get("garden") != null:
		colony.garden.health = 0.75
		colony.garden.waste = 0.05
	_cfg().target_soldiers = 4
	# Apply surplus pressures before seeding so decide_caste sees the raised bar.
	if colony.get("homeostasis") != null and colony.homeostasis.has_method("tick"):
		colony.homeostasis.tick(colony)
	viz.call("reset_new_counts")
	viz.call("set_highlight_new", true)
	viz.call("set_chrome",
		"CASTE-MIX LOOP — soldier surplus",
		"adults stay · soldier bar ↑ · JH scale ↓ · watch NEW eclosions",
		"4×")
	var seeded: int = _seed_surplus_cohort(colony)
	print("HOMEO: seeded %d surplus-cohort pupae (score~60 → forager under raised bar)" % seeded)
	_set_hz(base_hz * 4.0)
	_look_at(cam, _chamber_center(world, "nursery"), base_zoom * 1.25)
	await _speak(voice, "04_surplus")
	# Hold so staggered pupae finish eclosing while the NEW counter is on screen.
	await _sec(8.0)
	var nc: Dictionary = viz.call("new_counts") if viz.has_method("new_counts") else {}
	print("HOMEO: surplus NEW S=%s F=%s N=%s" % [
		str(nc.get("soldiers", "?")), str(nc.get("foragers", "?")), str(nc.get("nurses", "?"))
	])
	_log_sim("after beat 4")

	print("HOMEO: beat 5 — wide / fast")
	viz.call("set_highlight_new", false)
	viz.call("reset_new_counts")
	viz.call("set_mode", 2)
	viz.call("set_chrome", "WHOLE COLONY — time compressed", "pressures drift toward the target mix", "6×")
	_cfg().target_soldiers = saved_tgt
	_set_hz(base_hz * 6.0)
	_look_at(cam, _nest_center(world), base_zoom * 0.40)
	await _speak(voice, "05_wide")
	_log_sim("after beat 5")

	print("HOMEO: beat 6 — close")
	viz.call("set_mode", 1)
	viz.call("set_chrome", "LOOP CLOSED", "census → destiny · JH · urgency · NEW tracks each beat", "2×")
	_set_hz(base_hz * 2.0)
	_look_at(cam, _nest_center(world), base_zoom * 0.52)
	await _speak(voice, "06_close")
	_log_sim("after beat 6")

	_cfg().target_soldiers = saved_tgt
	_set_hz(base_hz)
	print("HOMEO: done tick=%d" % _sim_tick())
	await _sec(0.8)
	quit(0)

func _speak(voice: AudioStreamPlayer, key: String) -> void:
	var path := _vo_path(key)
	if not FileAccess.file_exists(path):
		push_warning("HOMEOdemo: missing VO %s" % path)
		await _sec(6.0)
		return
	var stream: AudioStream = _load_wav(path)
	if stream == null:
		push_warning("HOMEOdemo: could not load %s" % path)
		await _sec(6.0)
		return
	voice.stream = stream
	voice.play()
	var secs := _stream_seconds(stream)
	await _sec(secs + 0.25)

func _load_wav(path: String) -> AudioStream:
	# Prefer ResourceLoader for res://; for absolute paths use AudioStreamWAV loader.
	if path.begins_with("res://") and ResourceLoader.exists(path):
		return load(path) as AudioStream
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var bytes := f.get_buffer(f.get_length())
	var wav := AudioStreamWAV.new()
	# Minimal WAV parse: assume our gen_vo output (PCM s16le mono 22050).
	if bytes.size() < 44:
		return null
	var data_ofs := 44
	# Find "data" chunk.
	for i in range(12, mini(bytes.size() - 8, 200)):
		if bytes[i] == 0x64 and bytes[i + 1] == 0x61 and bytes[i + 2] == 0x74 and bytes[i + 3] == 0x61:
			data_ofs = i + 8
			break
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	wav.stereo = false
	wav.data = bytes.slice(data_ofs)
	return wav

func _stream_seconds(stream: AudioStream) -> float:
	if stream is AudioStreamWAV:
		var w := stream as AudioStreamWAV
		var samples := w.data.size() / 2  # 16-bit mono
		if w.stereo:
			samples = w.data.size() / 4
		return float(samples) / float(maxi(w.mix_rate, 1))
	return 8.0

func _chamber_center(world: Node, name: String) -> Vector2:
	var graph = world.get("graph")
	if graph != null and graph.has_method("get_chamber_by_name"):
		var ch = graph.call("get_chamber_by_name", name)
		if ch != null:
			return ch.center
	return Vector2(-450, 400)

func _nest_center(world: Node) -> Vector2:
	return (_chamber_center(world, "nursery") + _chamber_center(world, "entrance")) * 0.5

func _look_at(cam: Camera2D, world_pos: Vector2, zoom: float) -> void:
	if cam == null:
		return
	if cam.has_method("set_follow_target"):
		cam.call("set_follow_target", null)
	cam.zoom = Vector2(zoom, zoom)
	cam.global_position = world_pos

func _set_hz(hz: float) -> void:
	_cfg().sim_hz = clampf(hz, 0.5, 40.0)

func _silence_idle() -> void:
	var ig := root.get_node_or_null("IdleGuard")
	if ig == null:
		return
	if ig.has_method("set_active"):
		ig.call("set_active", false)
	else:
		ig.set_process(false)
		ig.set_process_input(false)
		ig.set_process_unhandled_input(false)

func _force_sim_running() -> void:
	var clock := root.get_node_or_null("SimClock")
	if clock == null:
		return
	if clock.has_method("set_gate_on_app_pause"):
		clock.call("set_gate_on_app_pause", false)
	if clock.has_method("set_enabled"):
		clock.call("set_enabled", true)

func _sim_tick() -> int:
	var clock := root.get_node_or_null("SimClock")
	return int(clock.get("tick")) if clock != null else -1

func _sim_enabled() -> bool:
	var clock := root.get_node_or_null("SimClock")
	if clock != null and clock.has_method("is_enabled"):
		return bool(clock.call("is_enabled"))
	return false

func _log_sim(label: String) -> void:
	print("HOMEO: %s tick=%d enabled=%s" % [label, _sim_tick(), _sim_enabled()])

func _seed_surplus_cohort(colony: Node) -> int:
	## Queue pupae whose score (~60) would be SOLDIER under the neutral bar (58)
	## but FORAGER once surplus raises the soldier bar to 63. Plus a couple of
	## low-score nurses. Short pupa timers so NEW eclosions land in-beat.
	if colony == null or colony.get("brood") == null:
		return 0
	var brood: Object = colony.brood
	if not brood.has_method("spawn_larva") or not brood.has_method("decide_caste"):
		return 0
	var rng: RandomNumberGenerator = colony.get("rng") as RandomNumberGenerator
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	# (nutrition, jh) → score = nut + 2·JH
	var cohort: Array = [
		[56.0, 2.0], [55.0, 2.5], [57.0, 1.5], [54.0, 3.0], [56.5, 2.0], [55.5, 2.2],
		[40.0, 0.5], [38.0, 1.0],
	]
	var n := 0
	for i in cohort.size():
		var pair: Array = cohort[i]
		var pos: Vector2 = brood.call("chamber_spot", "nursery", rng) if brood.has_method("chamber_spot") \
			else _chamber_center(get_first_node_in_group("world"), "nursery")
		var larva = brood.call("spawn_larva", pos)
		if larva == null:
			continue
		larva.nutrition = float(pair[0])
		larva.jh_dose = float(pair[1])
		larva.larva_stage = 2
		var destiny: int = int(brood.call("decide_caste", larva))
		larva.caste_destiny = destiny
		larva.caste = 6  # AntEnums.Caste.PUPA
		larva.pupa_ticks_left = 8 + i * 4
		larva.state = 0
		larva.clear_path()
		if colony.has_method("ensure_view"):
			colony.call("ensure_view", larva)
		var score: float = float(pair[0]) + 2.0 * float(pair[1])
		print("HOMEO: cohort[%d] score=%.1f destiny=%d ticks=%d" % [i, score, destiny, larva.pupa_ticks_left])
		n += 1
	return n

func _frames(seconds: float) -> int:
	return maxi(1, int(ceil(seconds * FPS)))

func _sec(seconds: float) -> void:
	for i in _frames(seconds):
		await process_frame

extends Node2D
## Phase 2+ world: large nest, sprites, first-visit chamber VO.

const ANT_SCENE := preload("res://scenes/Ant.tscn")
const STAR_SCRIPT := preload("res://scripts/world/StarMarker.gd")
const STAR_TRIGGER := preload("res://scripts/content/StarTrigger.gd")
const CHAMBER_VO := preload("res://scripts/content/ChamberVO.gd")
const ROLE_VO := preload("res://scripts/content/RoleVO.gd")
const NARRATOR := preload("res://scripts/content/Narrator.gd")
const TRAIL_MARKER := preload("res://scripts/world/TrailMarker.gd")
const _VoStream := preload("res://scripts/content/VoStream.gd")
const _RailModel := preload("res://scripts/ui/StarRailModel.gd")

const TRAIL_VO_DIR := "res://assets/audio/vo/trails"
const TUNNEL_VO_PATH := "res://data/tunnel_vo.json"
const TUNNEL_VO_DIR := "res://assets/audio/vo"

@onready var map_root: Node2D = $MapRoot
@onready var ants_root: Node2D = $Ants
@onready var camera: Camera2D = $CameraFollow
@onready var tap_marker: Node2D = $TapMarker
@onready var trails_root: Node2D = $Trails
@onready var role_hud: Node2D = $RoleHUD

var graph: NavGraph
var pathing: Pathing
var colony: Colony
var map_builder: MapBuilder
var star_db: StarDB
var star_markers: Array = []
var _star_dwell: Dictionary = {}
var _discovery_active: bool = false
var _pending_star_id: String = ""
var _pending_star_file: String = ""
var _approach_star_id: String = ""  ## intentional tap → discover on arrival
var _discovery_vo_deadline: float = -1.0
var _sim_paused_for_discovery: bool = false
var _video_panel: CanvasLayer
var _intro_panel: CanvasLayer
var narrator: Node  ## Narrator queue (typed as Node: class_name cache may be stale at runtime)
var chamber_vo: Node
var role_vo: Node
var trails: Array = []
var _last_player_zone: String = ""
var _intro_done: bool = false
var _trail_entry_active: bool = false
var _pending_trail_role: int = AntEnums.Role.NONE
var _pos_save_ticks: int = 0

# Locked-rail camera reveal tour.
const REVEAL_TAP_SECONDS := 3.0
const REVEAL_PAN_DURATION := 1.8
const REVEAL_NONE := 0
const REVEAL_TO_STAR := 1
const REVEAL_AT_STAR := 2
const REVEAL_BACK := 3
const REVEAL_AUTO_TRAVEL := 4
var _reveal_phase: int = REVEAL_NONE
var _reveal_star_id: String = ""
var _reveal_tap_deadline: float = -1.0
var _reveal_auto_travel: bool = false
var _reveal_spoke_cancel: bool = false
var _rail_model  ## StarRailModel — prompts for reveal tour VO

func _ready() -> void:
	add_to_group("world")
	# Layer stack is z_index-based (Backdrop < Map < Ants < Trails < HUD).
	# Only the Ants root uses y-sort for ant-vs-ant overlap.
	y_sort_enabled = false
	ants_root.y_sort_enabled = true
	ants_root.z_index = 10
	var legacy := get_node_or_null("Chamber")
	if legacy:
		legacy.queue_free()
	map_builder = MapBuilder.new()
	graph = map_builder.build(map_root)
	pathing = Pathing.new(graph)
	star_db = StarDB.new()
	star_db.load_db()
	_rail_model = _RailModel.new(star_db)
	_spawn_star_markers()
	# VideoPanel / IntroPanel are *later siblings* in Main.tscn. World._ready
	# runs first — resolve them deferred (or on demand), never in this _ready.
	_video_panel = null
	_intro_done = false
	narrator = NARRATOR.new()
	narrator.name = "Narrator"
	add_child(narrator)
	narrator.clip_finished.connect(_on_narration_finished)
	Events.star_collected.connect(_on_star_collected)
	Events.star_reveal_requested.connect(_on_star_reveal_requested)
	Events.player_arrived.connect(_on_player_arrived)
	chamber_vo = CHAMBER_VO.new()
	chamber_vo.name = "ChamberVO"
	add_child(chamber_vo)
	chamber_vo.narrator = narrator
	role_vo = ROLE_VO.new()
	role_vo.name = "RoleVO"
	add_child(role_vo)
	role_vo.narrator = narrator
	colony = Colony.new()
	colony.name = "Colony"
	add_child(colony)
	colony.setup(graph, pathing)
	colony.spawn_phase2(ants_root, ANT_SCENE, map_builder.leaf_spots)
	_restore_player_pos()
	_place_trails()
	_bind_camera_to_player()
	call_deferred("_bind_camera_to_player")  # snap again after first frame positions settle
	if role_hud and role_hud.has_method("set_follow"):
		role_hud.call("set_follow", colony.get_view(colony.player_id))
	SimClock.sim_tick.connect(_on_sim_tick)
	SimClock.sim_tick.connect(_on_sim_tick_save_pos)
	Events.player_path_requested.connect(_on_player_path_requested)
	Events.world_tapped.connect(_on_world_tapped)
	Events.ant_eclosed.connect(_on_eclosed)
	Events.invader_event_started.connect(_on_invade)
	Events.role_changed.connect(_on_role_changed)
	if tap_marker:
		tap_marker.visible = false
	call_deferred("_wire_intro_panel")

func _wire_intro_panel() -> void:
	_intro_panel = get_tree().get_first_node_in_group("intro_panel") as CanvasLayer
	if _intro_panel == null:
		_intro_done = true
		_check_chamber_vo(true)
		return
	if bool(_intro_panel.get("intro_done")):
		_intro_done = true
		_check_chamber_vo(true)
		return
	if not _intro_panel.finished.is_connected(_on_intro_finished):
		_intro_panel.finished.connect(_on_intro_finished)
	# Stay gated until IntroPanel.finished — no chamber VO, no movement.

func _on_intro_finished() -> void:
	_intro_done = true
	Events.intro_done.emit()
	_bind_camera_to_player()
	# Drop anything that raced the intro; chamber VO speaks next, alone.
	if narrator != null and narrator.has_method("cancel"):
		narrator.cancel("chamber:")
		narrator.cancel("role:")
	call_deferred("_check_chamber_vo", true)

func _spawn_star_markers() -> void:
	star_markers.clear()
	for zone in map_builder.star_placements:
		var info: Dictionary = map_builder.star_placements[zone]
		var marker: Node2D = STAR_SCRIPT.new() as Node2D
		map_root.add_child(marker)
		var sid := str(info["star_id"])
		marker.call("setup", sid, info["pos"] as Vector2)
		star_markers.append(marker)
		if Save.has_star(sid):
			marker.call("set_collected", true)

func _place_trails() -> void:
	trails.clear()
	if trails_root == null:
		return
	for child in trails_root.get_children():
		child.queue_free()
	for placement in map_builder.trail_placements:
		var zone: String = str(placement.get("zone", ""))
		var role_key: String = str(placement.get("role", ""))
		var role: int = AntEnums.role_from_name(role_key)
		if role == AntEnums.Role.NONE or zone.is_empty():
			continue
		var ch := graph.get_chamber_by_name(zone)
		if ch == null:
			continue
		var marker: Node2D = TRAIL_MARKER.new() as Node2D
		trails_root.add_child(marker)
		# Offset the icon from the chamber center so it doesn't sit on stars.
		marker.call("setup", role, ch.center + Vector2(0, ch.world_rect.size.y * 0.18))
		trails.append(marker)

func _process(delta: float) -> void:
	if colony:
		colony.interpolate_views(SimClock.tick_alpha)
	_tick_reveal_tour(delta)
	_check_star_dwell(delta)
	_check_discovery_vo_timeout()

func _now() -> float:
	return float(Time.get_ticks_msec()) / 1000.0

func _input(event: InputEvent) -> void:
	var pressed: bool = event.is_action_pressed("ui_cancel")
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		pressed = pressed or (mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT)
	if not pressed:
		return
	if _trail_entry_active:
		narrator.cancel("trail:")
		_finish_trail_entry()
		get_viewport().set_input_as_handled()
	elif _discovery_active:
		var panel := _resolve_video_panel()
		if panel == null or not (panel.has_method("is_open") and panel.is_open()):
			narrator.cancel("star:")
			_play_pending_star_video()
			get_viewport().set_input_as_handled()

func _check_star_dwell(delta: float) -> void:
	if _discovery_active or _trail_entry_active or _reveal_phase != REVEAL_NONE:
		return
	var panel := _resolve_video_panel()
	if panel != null and panel.has_method("is_open") and panel.is_open():
		return
	if colony == null or star_db == null:
		return
	# On a pheromone trail: all other audio/video triggers are disabled.
	if colony.player_has_role():
		return
	var player := colony.get_player()
	if player == null:
		return
	var radius: float = Config.get_star_approach_radius()
	var dwell: float = Config.get_star_dwell_seconds()
	var player_pos := _player_world_pos(player)
	for marker in star_markers:
		if marker == null:
			continue
		var sid: String = str(marker.get("star_id"))
		if Save.has_star(sid):
			_star_dwell[sid] = 0.0
			continue
		var star_pos: Vector2 = marker.global_position
		if STAR_TRIGGER.should_trigger_arrival(
				player, player_pos, star_pos, radius, _approach_star_id, sid):
			_approach_star_id = ""
			var arrival_entry: Dictionary = star_db.by_id.get(sid, {}) as Dictionary
			if not arrival_entry.is_empty():
				_begin_star_discovery(sid, str(arrival_entry.get("file", "")))
				return
		var accumulated: float = float(_star_dwell.get(sid, 0.0))
		var result: Dictionary = STAR_TRIGGER.should_trigger_dwell(
			player, player_pos, star_pos, radius, dwell, accumulated, delta)
		_star_dwell[sid] = result["accumulated"]
		if not result["trigger"]:
			continue
		var entry: Dictionary = star_db.by_id.get(sid, {}) as Dictionary
		if entry.is_empty():
			continue
		_approach_star_id = ""
		_begin_star_discovery(sid, str(entry.get("file", "")))
		return

func _player_world_pos(player: AntState) -> Vector2:
	## Prefer the rendered ant (interpolated) so dwell matches what the child sees.
	if colony != null:
		var view: Node2D = colony.get_view(player.id)
		if view != null and is_instance_valid(view):
			return view.global_position
	return player.cell

func _begin_star_discovery(star_id: String, file_name: String) -> void:
	if _discovery_active or _trail_entry_active or star_id.is_empty() or file_name.is_empty():
		return
	if _reveal_phase != REVEAL_NONE:
		_end_reveal_tour(false)
	_discovery_active = true
	_pending_star_id = star_id
	_pending_star_file = file_name
	_approach_star_id = ""
	_star_dwell[star_id] = 0.0
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	# Freeze the colony clock — get_tree().paused alone does not stop SimClock
	# (it is PROCESS_MODE_ALWAYS), which used to keep yanking the ant during VO.
	if SimClock != null and SimClock.is_enabled():
		SimClock.set_enabled(false)
		_sim_paused_for_discovery = true
	if narrator != null and narrator.has_method("cancel"):
		narrator.cancel("chamber:")
		narrator.cancel("role:")
		narrator.cancel("tunnel:")
		narrator.cancel("trail:")
	if Save.collect_star(star_id):
		Events.star_collected.emit(star_id)
	var vo_path := STAR_TRIGGER.resolve_star_vo_path(star_id)
	var stream: AudioStream = _VoStream.load_path(vo_path) if not vo_path.is_empty() else null
	if stream != null:
		_discovery_vo_deadline = _now() + 12.0
		narrator.speak(stream, "star:%s" % star_id)
	else:
		_discovery_vo_deadline = -1.0
		_play_pending_star_video()

func _check_discovery_vo_timeout() -> void:
	if not _discovery_active or _discovery_vo_deadline < 0.0:
		return
	var panel := _resolve_video_panel()
	if panel != null and panel.has_method("is_open") and panel.is_open():
		_discovery_vo_deadline = -1.0
		return
	if _now() < _discovery_vo_deadline:
		return
	push_warning("World: star VO timed out for %s — opening video" % _pending_star_id)
	_discovery_vo_deadline = -1.0
	if narrator != null and narrator.has_method("cancel"):
		narrator.cancel("star:")
	_play_pending_star_video()

func _on_narration_finished(tag: String) -> void:
	if tag.begins_with("trail:"):
		_finish_trail_entry()
	elif tag.begins_with("star:") and _discovery_active:
		_discovery_vo_deadline = -1.0
		_play_pending_star_video()

func _resolve_video_panel() -> CanvasLayer:
	if _video_panel != null and is_instance_valid(_video_panel):
		return _video_panel
	_video_panel = get_tree().get_first_node_in_group("video_panel") as CanvasLayer
	if _video_panel == null:
		var parent := get_parent()
		if parent != null:
			_video_panel = parent.get_node_or_null("VideoPanel") as CanvasLayer
	return _video_panel

func _play_pending_star_video() -> void:
	if not _discovery_active:
		return
	_discovery_vo_deadline = -1.0
	if _pending_star_id.is_empty():
		_end_star_discovery()
		return
	var panel := _resolve_video_panel()
	var launched := false
	if panel != null and panel.has_method("play_star"):
		launched = bool(panel.call("play_star", _pending_star_id, _pending_star_file))
		if launched and panel.has_signal("closed"):
			if not panel.closed.is_connected(_on_star_video_closed):
				panel.closed.connect(_on_star_video_closed)
	if not launched:
		push_warning("World: could not launch video for star %s (%s)" % [_pending_star_id, _pending_star_file])
		_end_star_discovery()

func _on_star_video_closed() -> void:
	_end_star_discovery()

func _end_star_discovery() -> void:
	_discovery_active = false
	_pending_star_id = ""
	_pending_star_file = ""
	_discovery_vo_deadline = -1.0
	process_mode = Node.PROCESS_MODE_INHERIT
	if _sim_paused_for_discovery and SimClock != null:
		SimClock.set_enabled(true)
		_sim_paused_for_discovery = false
	if get_tree().paused:
		get_tree().paused = false

func _on_star_collected(star_id: String) -> void:
	for marker in star_markers:
		if marker != null and str(marker.get("star_id")) == star_id:
			marker.call("set_collected", true)
			return

func _on_player_arrived() -> void:
	## Arrival after an intentional star tap (or reveal auto-travel) — try discover next frame via dwell.
	if _reveal_phase == REVEAL_AUTO_TRAVEL and not _reveal_star_id.is_empty():
		_approach_star_id = _reveal_star_id
		_end_reveal_tour(false)

func _marker_for_star(star_id: String) -> Node2D:
	for marker in star_markers:
		if marker != null and str(marker.get("star_id")) == star_id:
			return marker as Node2D
	return null

func _star_at(world_pos: Vector2) -> Node2D:
	for marker in star_markers:
		if marker == null:
			continue
		if marker.has_method("hit_test") and marker.hit_test(world_pos):
			return marker as Node2D
	return null

# --- locked-rail camera reveal tour -----------------------------------------

func _on_star_reveal_requested(star_id: String) -> void:
	if not _intro_done or _discovery_active or _trail_entry_active:
		return
	if star_id.is_empty() or Save.has_star(star_id):
		return
	var marker := _marker_for_star(star_id)
	if marker == null:
		return
	_end_reveal_tour(false)
	_reveal_phase = REVEAL_TO_STAR
	_reveal_star_id = star_id
	_reveal_auto_travel = false
	_reveal_spoke_cancel = false
	_reveal_tap_deadline = -1.0
	_approach_star_id = ""
	if colony != null and colony.player_has_role():
		colony.set_player_role(AntEnums.Role.NONE)
	if narrator != null and narrator.has_method("cancel"):
		narrator.cancel("chamber:")
		narrator.cancel("role:")
	_speak_reveal_line(_rail_model.reveal_travel_prompt(star_id) if _rail_model else "Tap the star to travel all the way there.")
	if camera != null and camera.has_method("begin_pan_to"):
		if camera.has_signal("pan_arrived") and not camera.pan_arrived.is_connected(_on_reveal_pan_arrived):
			camera.pan_arrived.connect(_on_reveal_pan_arrived)
		camera.call("begin_pan_to", marker.global_position, REVEAL_PAN_DURATION, true)
	else:
		_on_reveal_pan_arrived()

func _tick_reveal_tour(_delta: float) -> void:
	if _reveal_phase == REVEAL_NONE:
		return
	if _reveal_phase == REVEAL_AT_STAR and _reveal_tap_deadline >= 0.0 and _now() >= _reveal_tap_deadline:
		_start_reveal_camera_back(false)

func _on_reveal_pan_arrived() -> void:
	if _reveal_phase == REVEAL_TO_STAR:
		_reveal_phase = REVEAL_AT_STAR
		_reveal_tap_deadline = _now() + REVEAL_TAP_SECONDS
	elif _reveal_phase == REVEAL_BACK:
		_on_reveal_camera_centered()

func _start_reveal_camera_back(auto_travel: bool) -> void:
	if _reveal_phase == REVEAL_NONE or _reveal_phase == REVEAL_BACK or _reveal_phase == REVEAL_AUTO_TRAVEL:
		return
	_reveal_auto_travel = auto_travel
	_reveal_phase = REVEAL_BACK
	_reveal_tap_deadline = -1.0
	if auto_travel and not _reveal_spoke_cancel:
		_reveal_spoke_cancel = true
		_speak_reveal_line(_rail_model.reveal_cancel_hint(_reveal_star_id) if _rail_model else "Tap anywhere to explore on your own.")
	var view := _player_view()
	if camera != null and view != null and camera.has_method("begin_pan_to"):
		camera.call("begin_pan_to", view.global_position, REVEAL_PAN_DURATION, true)
	else:
		_on_reveal_camera_centered()

func _on_reveal_camera_centered() -> void:
	if _reveal_phase != REVEAL_BACK:
		return
	_bind_camera_to_player()
	if _reveal_auto_travel and not _reveal_star_id.is_empty():
		var marker := _marker_for_star(_reveal_star_id)
		if marker != null and colony != null:
			_approach_star_id = _reveal_star_id
			_reveal_phase = REVEAL_AUTO_TRAVEL
			if not _reveal_spoke_cancel:
				_reveal_spoke_cancel = true
				_speak_reveal_line(_rail_model.reveal_cancel_hint(_reveal_star_id) if _rail_model else "Tap anywhere to explore on your own.")
			colony.request_player_path(marker.global_position)
			return
	_end_reveal_tour(true)

func _end_reveal_tour(rebind_camera: bool) -> void:
	_reveal_phase = REVEAL_NONE
	_reveal_star_id = ""
	_reveal_tap_deadline = -1.0
	_reveal_auto_travel = false
	_reveal_spoke_cancel = false
	if rebind_camera:
		_bind_camera_to_player()

func _player_view() -> Node2D:
	if colony == null:
		return null
	var player := colony.get_player()
	if player == null:
		return null
	return colony.get_view(player.id) as Node2D

func _speak_reveal_line(text: String) -> void:
	print("Reveal: %s" % text)
	if DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		DisplayServer.tts_stop()
		DisplayServer.tts_speak(text, "", 1.0, 1.0, 0.95)

func _on_sim_tick(tick: int) -> void:
	colony.on_sim_tick(tick)
	_maybe_tunnel_teach_vo()
	_check_chamber_vo(false)

func _restore_player_pos() -> void:
	if colony == null or not Save.has_player_pos():
		return
	var player := colony.get_player()
	if player == null:
		return
	var pos := Save.player_pos()
	player.cell = pos
	player.prev_cell = pos
	player.clear_path()
	var view := colony.get_view(colony.player_id)
	if view != null:
		view.global_position = pos

func _on_sim_tick_save_pos(_tick: int) -> void:
	if not _intro_done or colony == null:
		return
	_pos_save_ticks += 1
	if _pos_save_ticks < 40:  # ~8 s at 5 Hz
		return
	_pos_save_ticks = 0
	var player := colony.get_player()
	if player == null:
		return
	Save.set_player_pos(player.cell)
	Save.save_if_dirty()

func _maybe_tunnel_teach_vo() -> void:
	if not _intro_done or colony == null or colony.tunnel_transit == null:
		return
	if not colony.tunnel_transit.has_method("consume_teach"):
		return
	if not bool(colony.tunnel_transit.call("consume_teach")):
		return
	var text := _tunnel_teach_text()
	if not text.is_empty():
		print("VO [tunnel]: %s" % text)
	var wav_path: String = _VoStream.resolve_vo(TUNNEL_VO_DIR, "tunnel")
	var stream: AudioStream = _VoStream.load_path(wav_path) if not wav_path.is_empty() else null
	if stream != null and narrator != null and narrator.has_method("speak"):
		narrator.speak(stream, "tunnel:teach")
	elif not text.is_empty() and DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		DisplayServer.tts_speak(text, "", 1.0, 1.0, 0.9)

func _tunnel_teach_text() -> String:
	if not FileAccess.file_exists(TUNNEL_VO_PATH):
		return ""
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TUNNEL_VO_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return ""
	var entry: Variant = (parsed as Dictionary).get("tunnel", {})
	if typeof(entry) != TYPE_DICTIONARY:
		return ""
	return str((entry as Dictionary).get("text", "")).strip_edges()

func _check_chamber_vo(force: bool) -> void:
	if not _intro_done or _discovery_active or _reveal_phase != REVEAL_NONE:
		return
	if chamber_vo == null or colony == null:
		return
	var player := colony.get_player()
	if player == null:
		return
	var ch := graph.chamber_for_point(player.cell)
	if ch == null:
		return
	if not force and ch.name == _last_player_zone:
		return
	_last_player_zone = ch.name
	if player.role != AntEnums.Role.NONE:
		return
	chamber_vo.try_announce(ch.name)

func _on_role_changed(role: int) -> void:
	if role == AntEnums.Role.NONE:
		_check_chamber_vo(true)

func _on_player_path_requested(world_pos: Vector2) -> void:
	if not _intro_done:
		return
	_handle_tap(world_pos)

func _on_world_tapped(world_pos: Vector2) -> void:
	if not _intro_done:
		return
	_show_tap_marker(world_pos)

func _handle_tap(world_pos: Vector2) -> void:
	if not _intro_done or _trail_entry_active or _discovery_active:
		return
	# Camera reveal tour: tap the glowing star to commit; anything else is ignored
	# until the look-window times out (camera returns on its own).
	if _reveal_phase == REVEAL_TO_STAR or _reveal_phase == REVEAL_AT_STAR:
		var tour_star := _star_at(world_pos)
		if tour_star != null and str(tour_star.get("star_id")) == _reveal_star_id:
			_start_reveal_camera_back(true)
		return
	# Auto-walk after reveal: any tap cancels and resumes normal exploration.
	if _reveal_phase == REVEAL_AUTO_TRAVEL:
		_end_reveal_tour(true)
		_approach_star_id = ""
		_speak_reveal_line(_rail_model.reveal_cancel_hint("") if _rail_model else "Tap anywhere to explore on your own.")
		# Fall through to normal tap handling below.
	elif _reveal_phase == REVEAL_BACK:
		# Let the camera finish returning; ignore mid-pan taps.
		return
	# Working a trail: clicking anywhere exits back to exploration.
	if colony.player_has_role():
		narrator.cancel("role:")
		colony.set_player_role(AntEnums.Role.NONE)
		colony.request_player_path(world_pos)
		_approach_star_id = ""
		return
	for trail in trails:
		if trail != null and trail.has_method("hit_test") and trail.hit_test(world_pos):
			_approach_star_id = ""
			_begin_trail_entry(trail.role)
			return
	# Tap a glowing star → walk there and discover on arrival (no fragile re-dwell).
	var star := _star_at(world_pos)
	if star != null:
		var sid := str(star.get("star_id"))
		if not Save.has_star(sid):
			_approach_star_id = sid
			colony.request_player_path(star.global_position)
			return
	_approach_star_id = ""
	colony.request_player_path(world_pos)

func _begin_trail_entry(role: int) -> void:
	if _trail_entry_active or _discovery_active or role == AntEnums.Role.NONE:
		return
	_trail_entry_active = true
	_pending_trail_role = role
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	# Trails silence everything else: drop any pending chamber narration.
	narrator.cancel("chamber:")
	var key := AntEnums.role_name(role)
	var vo_path := _VoStream.resolve_vo(TRAIL_VO_DIR, key)
	var stream: AudioStream = _VoStream.load_path(vo_path) if not vo_path.is_empty() else null
	print("Trail entry [%s]" % key)
	if stream != null:
		narrator.speak(stream, "trail:%s" % key)
	else:
		# No clip yet: short beat so the pause registers, then start working.
		var timer := get_tree().create_timer(1.0, true, false, true)
		timer.timeout.connect(_finish_trail_entry)

func _finish_trail_entry() -> void:
	if not _trail_entry_active:
		return
	_trail_entry_active = false
	process_mode = Node.PROCESS_MODE_INHERIT
	if get_tree().paused:
		get_tree().paused = false
	var role := _pending_trail_role
	_pending_trail_role = AntEnums.Role.NONE
	# Automation launches; RoleVO fires next through the narration queue.
	colony.set_player_role(role)
	colony.kick_player_role_job()

func _show_tap_marker(world_pos: Vector2) -> void:
	if tap_marker == null:
		return
	tap_marker.global_position = world_pos
	tap_marker.visible = true
	tap_marker.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(tap_marker, "modulate:a", 0.0, 0.35)
	tw.tween_callback(func() -> void: tap_marker.visible = false)

func _on_eclosed(_ant_id: int, caste: int) -> void:
	print("Eclosion → %s" % _caste_name(caste))

func _on_invade(kind: int, count: int) -> void:
	var names := ["ant", "beetle", "spider"]
	var k: String = names[kind] if kind >= 0 and kind < names.size() else str(kind)
	print("Invaders! %d × %s (soldiers will swarm — shake — they flee)" % [count, k])

func _caste_name(caste: int) -> String:
	match caste:
		AntEnums.Caste.SOLDIER: return "soldier"
		AntEnums.Caste.FORAGER: return "forager"
		AntEnums.Caste.NURSE: return "nurse"
		AntEnums.Caste.GARDENER: return "gardener"
		_: return str(caste)

func _bind_camera_to_player() -> void:
	if colony == null or camera == null:
		return
	var player_state := colony.get_player()
	if player_state == null:
		return
	var view: Node2D = colony.get_view(player_state.id)
	if view == null:
		return
	if camera.has_method("resume_follow"):
		camera.call("resume_follow", view, true)
	elif camera.has_method("set_follow_target"):
		camera.call("set_follow_target", view)
		if camera.has_method("snap_to_target"):
			camera.call("snap_to_target")
		else:
			camera.global_position = view.global_position
	var z: float = Config.get_camera_zoom() if Config else 0.72
	camera.zoom = Vector2(z, z)

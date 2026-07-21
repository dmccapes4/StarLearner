extends CanvasLayer
## Launch gate + intro narration.
## Shows a clear START button first; narration (and rail cues) begin only after
## the child taps it. After START, the sequence cannot be skipped.

signal finished()

const INTRO_DIR := "res://assets/audio/vo/intro"
const LEGACY_WAV := "res://assets/audio/vo/intro.wav"
const _VoStream := preload("res://scripts/content/VoStream.gd")

var intro_done: bool = false
var _started: bool = false

@onready var _dim: ColorRect = $Dim
@onready var _start_btn: Button = $StartButton
@onready var _player: AudioStreamPlayer = $Player

var _lines: Array = []
var _idx: int = -1
var _shell: Node = null

func _ready() -> void:
	add_to_group("intro_panel")
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 25
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_player.finished.connect(_on_player_finished)
	_start_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	_start_btn.pressed.connect(_on_start_pressed)
	# Returning players skip START + narration — progress is already saved.
	if Save.intro_completed:
		_started = true
		_start_btn.visible = false
		_dim.visible = false
		visible = false
		call_deferred("_finish")
		return
	_show_start_gate()

func _show_start_gate() -> void:
	_started = false
	visible = true
	_dim.visible = true
	_start_btn.visible = true
	_start_btn.disabled = false
	# Let the colony render behind the dim; do not pause until narration begins.
	get_tree().paused = false

func _on_start_pressed() -> void:
	if _started or intro_done:
		return
	_started = true
	_start_btn.visible = false
	_start_btn.disabled = true
	_begin()

func _begin() -> void:
	_lines = _load_lines()
	_shell = get_tree().get_first_node_in_group("landscape_shell")
	if _lines.is_empty():
		# No per-line data: fall back to the legacy single clip, then finish.
		var legacy: AudioStream = _VoStream.load_path(LEGACY_WAV)
		if legacy != null:
			get_tree().paused = true
			_player.stream = legacy
			_player.play()
			return
		_finish()
		return
	get_tree().paused = true
	_advance()

func _load_lines() -> Array:
	var path := "res://data/intro_vo.json"
	if not FileAccess.file_exists(path):
		return []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return []
	var intro: Dictionary = (parsed as Dictionary).get("intro", {}) as Dictionary
	var lines: Variant = intro.get("lines", [])
	if lines is Array:
		return lines as Array
	# Legacy line1/line2/line3 → ordered lines, no cues.
	var out: Array = []
	for k in ["line1", "line2", "line3"]:
		var txt := str(intro.get(k, "")).strip_edges()
		if not txt.is_empty():
			out.append({"key": k, "text": txt, "cue": ""})
	return out

func _advance() -> void:
	_idx += 1
	if _idx >= _lines.size():
		_finish()
		return
	var line: Dictionary = _lines[_idx] as Dictionary
	_fire_cue(str(line.get("cue", "")))
	var key := str(line.get("key", ""))
	var text := str(line.get("text", ""))
	var clip := _VoStream.resolve_vo(INTRO_DIR, key)
	var stream: AudioStream = _VoStream.load_path(clip) if not clip.is_empty() else null
	if stream != null:
		_player.stream = stream
		_player.play()  # _on_player_finished advances
		return
	# No baked clip: speak via OS TTS (if any) and advance on a word-count timer.
	if DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		DisplayServer.tts_stop()
		DisplayServer.tts_speak(text, "", 1.0, 1.0, 0.95)
	_wait_then_advance(_estimate_seconds(text))

func _fire_cue(cue: String) -> void:
	if cue.is_empty() or _shell == null:
		return
	if cue == "reveal_rails" and _shell.has_method("begin_intro_hold"):
		_shell.call("begin_intro_hold")
	elif cue == "hide_rails" and _shell.has_method("end_intro_hold"):
		_shell.call("end_intro_hold")

func _estimate_seconds(text: String) -> float:
	var words := text.split(" ", false).size()
	return clampf(0.6 + words * 0.38, 1.0, 6.0)

func _on_player_finished() -> void:
	if intro_done:
		return
	if _lines.is_empty():
		_finish()  # legacy single-clip path
		return
	_wait_then_advance(0.35)

func _wait_then_advance(secs: float) -> void:
	var tmr := get_tree().create_timer(secs, true, false, true)  # runs while paused
	tmr.timeout.connect(_advance)

func _input(event: InputEvent) -> void:
	if intro_done:
		return
	# Before START: let the button receive the press; block world taps.
	if not _started:
		if event is InputEventMouseButton and event.pressed \
				or (event is InputEventScreenTouch and event.pressed):
			# Button handles its own press; swallow the rest so ants don't walk.
			if not _start_btn.get_global_rect().has_point(_event_pos(event)):
				get_viewport().set_input_as_handled()
		return
	# After START: swallow clicks/cancel so nothing else runs; do NOT skip.
	if event.is_action_pressed("ui_cancel") \
			or (event is InputEventMouseButton and event.pressed) \
			or (event is InputEventScreenTouch and event.pressed):
		get_viewport().set_input_as_handled()

func _event_pos(event: InputEvent) -> Vector2:
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).position
	if event is InputEventMouseButton:
		return (event as InputEventMouseButton).position
	return Vector2.ZERO

func _finish() -> void:
	if intro_done:
		return
	intro_done = true
	if _player.playing:
		_player.stop()
	# Ensure the shelves end tucked away (soil default) even if the hide cue
	# never played (e.g. legacy clip or skipped capture).
	if _shell != null and _shell.has_method("end_intro_hold"):
		_shell.call("end_intro_hold")
	Save.set_intro_completed(true)
	get_tree().paused = false
	visible = false
	finished.emit()

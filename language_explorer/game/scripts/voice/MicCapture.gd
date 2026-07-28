class_name MicCapture
extends Node
## Language Explorer owns the microphone exclusively.
##
## hold() keeps AudioStreamMicrophone playing (muted bus) so Android leaves the
## input with this process. start()/stop_to_file() only toggle AudioEffectRecord
## — they do not drop the hold. release() is for leaving the app / teardown.

signal recording_finished(path: String)
signal recording_failed(reason: String)

const BUS_NAME := "MicRecord"
const VOICE_DIR := "user://voice"
const PERSISTENT_WAV := ["next_enroll.wav"]
const SILENCE_PEAK := 800
const PERM := "android.permission.RECORD_AUDIO"

const VoiceTelemetryS := preload("res://scripts/voice/VoiceTelemetry.gd")

var _bus_idx: int = -1
var _effect: AudioEffectRecord
var _recording: bool = false
var _held: bool = false
var _muted_master_for_capture: bool = false
var _mic_player: AudioStreamPlayer
var _built: bool = false
var _last_peak: int = 0
var _last_stop_reason: String = ""

func last_peak() -> int:
	return _last_peak

func last_stop_reason() -> String:
	return _last_stop_reason

func ensure_ready() -> bool:
	if _built:
		return _mic_player != null
	_built = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(VOICE_DIR))
	_bus_idx = AudioServer.get_bus_index(BUS_NAME)
	if _bus_idx < 0:
		AudioServer.add_bus()
		_bus_idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(_bus_idx, BUS_NAME)
		AudioServer.set_bus_send(_bus_idx, "Master")
		AudioServer.set_bus_mute(_bus_idx, true)
	_mic_player = AudioStreamPlayer.new()
	_mic_player.bus = BUS_NAME
	add_child(_mic_player)
	_rebuild_record_effect()
	return _effect != null

func is_recording() -> bool:
	return _recording

func is_held() -> bool:
	return _held and _mic_player != null and _mic_player.playing

## Open the mic and keep it. Does not start a clip.
func hold() -> bool:
	if not ensure_ready():
		recording_failed.emit("mic_unavailable")
		return false
	if _mic_player.playing and _mic_player.stream is AudioStreamMicrophone:
		_held = true
		return true
	if _mic_player.playing:
		_mic_player.stop()
	_mic_player.stream = AudioStreamMicrophone.new()
	_mic_player.play()
	_held = _mic_player.playing
	if not _held:
		recording_failed.emit("mic_unavailable")
	return _held

## Drop exclusive mic ownership (leave Language Explorer / teardown only).
func release() -> void:
	if _recording and _effect != null:
		_effect.set_recording_active(false)
	_recording = false
	_held = false
	_mute_speakers(false)
	if _mic_player != null and _mic_player.playing:
		_mic_player.stop()
	_mic_player.stream = null
	_rebuild_record_effect()

## Begin capturing a clip. Keeps the hold after stop_to_file/cancel.
## Mutes Master speakers so VO / game audio cannot bleed into the mic.
func start() -> bool:
	if not hold():
		return false
	if _recording:
		_effect.set_recording_active(false)
		_recording = false
	_mute_speakers(true)
	if _effect == null:
		_rebuild_record_effect()
	_effect.set_recording_active(true)
	_recording = true
	return true

func stop_to_file(filename: String = "clip.wav", min_peak: int = SILENCE_PEAK) -> String:
	if not _recording:
		return ""
	_effect.set_recording_active(false)
	_recording = false
	var stream: AudioStreamWAV = _effect.get_recording()
	_rebuild_record_effect()
	_mute_speakers(false)
	# Keep selfish hold — do not stop the mic player.
	if not is_held():
		hold()
	_last_peak = _peak_of(stream)
	if stream == null:
		_last_stop_reason = "empty"
		recording_failed.emit("empty")
		return ""
	if _last_peak < min_peak:
		_last_stop_reason = "silent"
		recording_failed.emit("silent")
		push_warning("MicCapture: silent clip peak=%d min=%d" % [_last_peak, min_peak])
		return ""
	_last_stop_reason = "ok"
	var path := "%s/%s" % [VOICE_DIR, filename]
	var abs_path := ProjectSettings.globalize_path(path)
	var err := stream.save_to_wav(abs_path)
	if err != OK:
		_last_stop_reason = "save_failed"
		recording_failed.emit("save_failed")
		return ""
	recording_finished.emit(path)
	return path

## Abort an in-progress clip without releasing the mic.
func cancel() -> void:
	if not _recording:
		_mute_speakers(false)
		return
	if _effect != null:
		_effect.set_recording_active(false)
	_recording = false
	_rebuild_record_effect()
	_mute_speakers(false)
	if not is_held():
		hold()

## Android sometimes stops delivering mic samples mid-session. Restart the player.
func recover_hold() -> bool:
	if not is_inside_tree():
		return hold()
	VoiceTelemetryS.log("mic_recover_start", {
		"held": is_held(),
		"recording": _recording,
		"last_peak": _last_peak,
	})
	if _recording:
		cancel()
	else:
		_mute_speakers(false)
	if _mic_player != null:
		if _mic_player.playing:
			_mic_player.stop()
		_mic_player.stream = null
	_held = false
	_rebuild_record_effect()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.4).timeout
	var ok := hold()
	VoiceTelemetryS.log("mic_recover_done", {"ok": ok, "held": is_held()})
	return ok

func _mute_speakers(on: bool) -> void:
	var idx := AudioServer.get_bus_index("Master")
	if idx < 0:
		return
	if on:
		if not AudioServer.is_bus_mute(idx):
			AudioServer.set_bus_mute(idx, true)
			_muted_master_for_capture = true
	elif _muted_master_for_capture:
		AudioServer.set_bus_mute(idx, false)
		_muted_master_for_capture = false

func clear_session_files() -> void:
	var abs_dir := ProjectSettings.globalize_path(VOICE_DIR)
	var d := DirAccess.open(abs_dir)
	if d == null:
		return
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		if not d.current_is_dir() and (name.ends_with(".wav") or name.ends_with(".WAV")):
			if name in PERSISTENT_WAV:
				name = d.get_next()
				continue
			d.remove(name)
		name = d.get_next()
	d.list_dir_end()

func _rebuild_record_effect() -> void:
	if _bus_idx < 0:
		return
	for i in range(AudioServer.get_bus_effect_count(_bus_idx) - 1, -1, -1):
		var fx := AudioServer.get_bus_effect(_bus_idx, i)
		if fx is AudioEffectRecord:
			AudioServer.remove_bus_effect(_bus_idx, i)
	_effect = AudioEffectRecord.new()
	AudioServer.add_bus_effect(_bus_idx, _effect)

func _peak_of(stream: AudioStreamWAV) -> int:
	if stream == null:
		return 0
	var data: PackedByteArray = stream.data
	if data.is_empty():
		return 0
	var peak := 0
	var i := 0
	var n := data.size()
	while i + 1 < n:
		var s := int(data[i]) | (int(data[i + 1]) << 8)
		if s >= 32768:
			s -= 65536
		var a := absi(s)
		if a > peak:
			peak = a
		i += 2
	return peak

## Request RECORD_AUDIO once; await until granted or denied (Android).
static func ensure_permission(tree: SceneTree) -> bool:
	if OS.get_name() != "Android":
		return true
	var granted := OS.get_granted_permissions()
	if PERM in granted:
		return true
	OS.request_permission(PERM)
	# Dialog may steal the next tap — wait briefly for the grant to land.
	for _i in range(40):
		await tree.create_timer(0.25).timeout
		if PERM in OS.get_granted_permissions():
			return true
	return PERM in OS.get_granted_permissions()

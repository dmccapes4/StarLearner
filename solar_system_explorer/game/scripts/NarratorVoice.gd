class_name NarratorVoice
extends Node
## Plays queued baked VO sentence clips back to back. Created lazily by
## Narrator on first use; lives directly under the scene tree root.

var _player: AudioStreamPlayer
var _queue: Array = []

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = "Master"
	add_child(_player)

func _process(_delta: float) -> void:
	if _player == null or _player.playing or _queue.is_empty():
		return
	_player.stream = _queue.pop_front()
	_player.play()

func play_queue(streams: Array) -> void:
	stop_all()
	_queue = streams.duplicate()

func stop_all() -> void:
	_queue.clear()
	if _player != null and _player.playing:
		_player.stop()

func is_busy() -> bool:
	return not _queue.is_empty() or (_player != null and _player.playing)

class_name NarratorVoice
extends Node
## Plays queued baked VO sentence clips back to back. Created lazily by
## Narrator on first use; lives directly under the scene tree root.

var _player: AudioStreamPlayer
var _queue: Array = []

func _ready() -> void:
	## MediaPanel / reveal UIs pause the tree; VO must still advance.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.bus = "Master"
	_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_player.finished.connect(_advance)
	add_child(_player)

func _process(_delta: float) -> void:
	_advance()

func play_queue(streams: Array) -> void:
	stop_all()
	_queue = streams.duplicate()
	_advance()

func _advance() -> void:
	if _player == null or _player.playing or _queue.is_empty():
		return
	_player.stream = _queue.pop_front()
	_player.play()

func stop_all() -> void:
	_queue.clear()
	if _player != null and _player.playing:
		_player.stop()

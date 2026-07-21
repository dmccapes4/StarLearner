class_name Narrator
extends Node
## Single-voice narration queue. Every VO clip in the game routes through here
## so two narrations can never overlap: later requests wait their turn.
## Pausing the game is owned by the flows (intro, trail entry, star discovery),
## not by the queue.

signal clip_finished(tag: String)

var _player: AudioStreamPlayer
var _queue: Array = []  ## [{stream, tag}]
var _current_tag: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.name = "Voice"
	_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_player)
	_player.finished.connect(_on_finished)

func speak(stream: AudioStream, tag: String = "") -> void:
	if stream == null:
		return
	_queue.append({"stream": stream, "tag": tag})
	_pump()

func is_busy() -> bool:
	return _player != null and _player.playing

func current_tag() -> String:
	return _current_tag

## Silently drop queued clips whose tag starts with `prefix` and stop the
## current clip if it matches. Does NOT emit clip_finished — callers that skip
## drive their own continuation.
func cancel(prefix: String) -> void:
	var kept: Array = []
	for item in _queue:
		if not str(item["tag"]).begins_with(prefix):
			kept.append(item)
	_queue = kept
	if _current_tag.begins_with(prefix) and _player and _player.playing:
		_player.stop()
		_current_tag = ""
		_pump()

func clear_all() -> void:
	_queue.clear()
	_current_tag = ""
	if _player and _player.playing:
		_player.stop()

func _pump() -> void:
	if _player == null or _player.playing or _queue.is_empty():
		return
	var item: Dictionary = _queue.pop_front()
	_current_tag = str(item["tag"])
	_player.stream = item["stream"]
	_player.play()

func _on_finished() -> void:
	var tag := _current_tag
	_current_tag = ""
	clip_finished.emit(tag)
	_pump()

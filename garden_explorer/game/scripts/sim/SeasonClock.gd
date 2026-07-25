class_name SeasonClock
extends Node
## Advances seasons on a wall-clock timer. Call force_advance() from tests.

signal season_tick(season_id: String, index: int)

var seed_db: SeedDB
var elapsed: float = 0.0
var paused: bool = false
var duration_sec: float = 180.0

func setup(db: SeedDB, duration_override: float = -1.0) -> void:
	seed_db = db
	if duration_override > 0.0:
		duration_sec = duration_override
	elif db != null:
		duration_sec = db.season_duration_sec
	elapsed = 0.0

func _process(delta: float) -> void:
	if paused or seed_db == null:
		return
	elapsed += delta
	if elapsed >= duration_sec:
		elapsed = 0.0
		_advance()

func force_advance() -> String:
	elapsed = 0.0
	return _advance()

func time_remaining() -> float:
	return maxf(0.0, duration_sec - elapsed)

func _advance() -> String:
	if seed_db == null:
		return ""
	var sid := seed_db.advance_season()
	var idx := seed_db.season_index()
	season_tick.emit(sid, idx)
	return sid

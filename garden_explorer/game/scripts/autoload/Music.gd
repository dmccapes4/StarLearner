extends Node
## Seasonal background music (Stardew-style pastoral loops).
##
## One looping track per season at res://audio/music/<season>.ogg.
## Volume policy, checked every frame:
##   • a full-freeze panel is open (video, media, reveal narration, grids,
##     season card, intro)          → music pauses
##   • short narration is playing  → music ducks low ("Walking to Daisy.")
##   • otherwise                   → normal volume
## Season changes crossfade between the two players.

const NarratorScript := preload("res://scripts/audio/Narrator.gd")

const MUSIC_DIR := "res://audio/music"
const BASE_DB := -10.0
const DUCK_DB := -26.0
const FADE_SEC := 1.6
const VOL_LERP := 6.0

var _a: AudioStreamPlayer
var _b: AudioStreamPlayer
var _live: AudioStreamPlayer ## whichever of a/b carries the current season
var _season: String = ""
var _duck_db: float = 0.0
var _fade_t: float = 1.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_a = _mk_player("MusicA")
	_b = _mk_player("MusicB")
	_live = _a
	if not Events.season_changed.is_connected(set_season):
		Events.season_changed.connect(set_season)

func _mk_player(n: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.name = n
	p.bus = "Master"
	p.volume_db = -60.0
	add_child(p)
	return p

func set_season(season_id: String) -> void:
	if season_id == _season:
		return
	_season = season_id
	var stream := _load_track(season_id)
	if stream == null:
		return
	## Crossfade: retire the live player, bring the other in with the new track.
	var next := _b if _live == _a else _a
	next.stream = stream
	next.volume_db = -60.0
	next.play()
	_live = next
	_fade_t = 0.0

func _load_track(season_id: String) -> AudioStream:
	var path := "%s/%s.ogg" % [MUSIC_DIR, season_id]
	var s: AudioStream = null
	if ResourceLoader.exists(path):
		s = load(path)
	elif FileAccess.file_exists(path):
		s = AudioStreamOggVorbis.load_from_file(path) ## unimported (headless)
	if s is AudioStreamOggVorbis:
		s.loop = true
	return s

func _process(delta: float) -> void:
	## No season_changed fires at startup — pick up the saved season lazily.
	if _season.is_empty():
		var save := get_node_or_null("/root/Save")
		set_season(str(save.season_id) if save else "spring")
	_fade_t = minf(1.0, _fade_t + delta / FADE_SEC)
	var paused := _freeze_panel_open()
	var target_duck := DUCK_DB if (not paused and NarratorScript.blocks_movement()) else 0.0
	if paused:
		_a.stream_paused = true
		_b.stream_paused = true
		return
	_a.stream_paused = false
	_b.stream_paused = false
	_duck_db = lerpf(_duck_db, target_duck, minf(1.0, delta * VOL_LERP))
	var out := _b if _live == _a else _a
	_live.volume_db = lerpf(-60.0, BASE_DB, _fade_t) + _duck_db
	out.volume_db = lerpf(BASE_DB, -60.0, _fade_t) + _duck_db
	if _fade_t >= 1.0 and out.playing:
		out.stop()

func _freeze_panel_open() -> bool:
	for grp in ["video_panel", "media_panel", "season_card", "bug_grid", "plant_grid", "intro_panel"]:
		var n := get_tree().get_first_node_in_group(grp)
		if n and n.has_method("is_open") and bool(n.call("is_open")):
			return true
		if grp == "intro_panel" and n and n.get("visible") == true:
			return true
	## Reveal tile freezes only while its narration is playing.
	var rt := get_tree().get_first_node_in_group("reveal_tile")
	if rt and rt.has_method("is_narrating") and bool(rt.call("is_narrating")):
		return true
	return false

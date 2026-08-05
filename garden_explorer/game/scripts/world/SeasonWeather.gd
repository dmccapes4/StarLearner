class_name SeasonWeather
extends Node2D
## World-space seasonal weather with mapped landings (not free particles).
## Rain: fall → splash at target → clear. Leaves: fall (spin) → rest 1–2s → fade.
## Depth: mid-air BIAS_WEATHER_FALL; landed BIAS_WEATHER_LAND (above seeds, under plants).

enum Mode { NONE, RAIN, LEAVES }
enum Phase { FALL, LAND, DONE }

const MAX_ACTIVE_RAIN := 22
const MAX_ACTIVE_LEAVES := 14
const RAIN_SPAWN_INTERVAL := 0.055
const LEAF_SPAWN_INTERVAL := 0.22

var mode: int = Mode.NONE
var farm_map: Node2D
var sprites: FarmSprites

var _landings: Array = [] ## {pos: Vector2, feet_y: float, on_bed: bool}
var _cycle_i: int = 0
var _spawn_accum: float = 0.0
var _active: Array = [] ## dictionaries
var _rng := RandomNumberGenerator.new()

var _rain_tex: Texture2D
var _splash_frames: Array = [] ## Texture2D
var _leaf_spin: Array = [] ## [color][frame] Texture2D
var _leaf_land: Array = [] ## [color][pose] Texture2D

func setup(farm: Node2D, art: FarmSprites, mode_name: String) -> void:
	farm_map = farm
	sprites = art
	_rng.seed = 20260804
	_load_fx_textures()
	_build_landings()
	if mode_name == "rain":
		mode = Mode.RAIN
	elif mode_name == "leaves":
		mode = Mode.LEAVES
	else:
		mode = Mode.NONE
	_cycle_i = 0
	_spawn_accum = 0.0
	_clear_active()
	set_process(mode != Mode.NONE)

func clear_weather() -> void:
	mode = Mode.NONE
	_clear_active()
	set_process(false)

func _clear_active() -> void:
	for d in _active:
		var spr: Sprite2D = d.get("spr")
		if spr and is_instance_valid(spr):
			spr.queue_free()
	_active.clear()

func _load_fx_textures() -> void:
	_rain_tex = null
	_splash_frames.clear()
	_leaf_spin.clear()
	_leaf_land.clear()
	if sprites == null:
		return
	if sprites.has_method("raindrop_texture"):
		_rain_tex = sprites.raindrop_texture()
	if sprites.has_method("rain_splash_frames"):
		_splash_frames = sprites.rain_splash_frames()
	if sprites.has_method("leaf_spin_frames"):
		_leaf_spin = sprites.leaf_spin_frames()
	if sprites.has_method("leaf_land_frames"):
		_leaf_land = sprites.leaf_land_frames()
	## Fallback: single leaf particle tinted.
	if _leaf_spin.is_empty() and sprites.has_method("leaf_particle_texture"):
		var one := sprites.leaf_particle_texture()
		if one:
			_leaf_spin = [[one, one, one, one, one, one, one, one]]
			_leaf_land = [[one, one, one]]

func _build_landings() -> void:
	_landings.clear()
	if farm_map == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260804
	## Yard floor (garden side) + animal pen — rain/leaves must hit both.
	if farm_map.has_method("_random_yard_point"):
		for i in 36:
			var p: Vector2 = farm_map.call("_random_yard_point", rng)
			if p == Vector2.INF:
				continue
			_landings.append({"pos": p, "feet_y": p.y, "on_bed": false})
	if farm_map.has_method("_random_pen_point"):
		for i in 22:
			var pp: Vector2 = farm_map.call("_random_pen_point", rng)
			if pp == Vector2.INF:
				continue
			_landings.append({"pos": pp, "feet_y": pp.y, "on_bed": false})
	## Bed tops — splash/leaves can land here; plants still sort above.
	var centers: Dictionary = farm_map.get("bed_centers") as Dictionary if farm_map.get("bed_centers") != null else {}
	var tiles: Dictionary = farm_map.get("bed_tiles") as Dictionary if farm_map.get("bed_tiles") != null else {}
	var halves: Dictionary = farm_map.get("bed_halves") as Dictionary if farm_map.get("bed_halves") != null else {}
	var bed_h := 28.0
	var bed_h_v = farm_map.get("BED_HEIGHT")
	if bed_h_v != null:
		bed_h = float(bed_h_v)
	for id in centers.keys():
		var c: Vector2 = centers[id]
		var tile: Vector2 = tiles.get(id, Vector2.ZERO)
		var half: Vector2 = halves.get(id, Vector2(1.1, 1.1))
		var feet_y := c.y
		if farm_map.has_method("_bed_sort_y"):
			feet_y = float(farm_map.call("_bed_sort_y", tile, half))
		for k in 3:
			var ox := rng.randf_range(-18.0, 18.0)
			var oy := rng.randf_range(-8.0, 8.0)
			var top := c + Vector2(ox, oy - bed_h)
			_landings.append({"pos": top, "feet_y": feet_y, "on_bed": true})
	## Shuffle with fixed seed for variety in the cycle order.
	for i in range(_landings.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = _landings[i]
		_landings[i] = _landings[j]
		_landings[j] = tmp

func _process(delta: float) -> void:
	if mode == Mode.NONE or _landings.is_empty():
		return
	_spawn_accum += delta
	var interval := RAIN_SPAWN_INTERVAL if mode == Mode.RAIN else LEAF_SPAWN_INTERVAL
	var cap := MAX_ACTIVE_RAIN if mode == Mode.RAIN else MAX_ACTIVE_LEAVES
	while _spawn_accum >= interval and _active.size() < cap:
		_spawn_accum -= interval
		_spawn_one()
	_tick_active(delta)

func _spawn_one() -> void:
	if _landings.is_empty():
		return
	var land: Dictionary = _landings[_cycle_i % _landings.size()]
	_cycle_i += 1
	var target: Vector2 = land["pos"]
	var feet_y: float = land["feet_y"]
	var spr := Sprite2D.new()
	spr.centered = true
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.scale = Vector2(2.0, 2.0)
	add_child(spr)
	var start := target + Vector2(
		_rng.randf_range(-10.0, 28.0),
		_rng.randf_range(-140.0, -90.0)
	)
	spr.position = start
	IsoUtil.apply_depth(spr, feet_y, IsoUtil.BIAS_WEATHER_FALL)
	var d := {
		"spr": spr,
		"phase": Phase.FALL,
		"target": target,
		"feet_y": feet_y,
		"t": 0.0,
		"fall_dur": 0.0,
		"land_t": 0.0,
		"land_dur": 0.0,
		"color_i": 0,
		"frame": 0,
		"frame_t": 0.0,
		"spin_dir": 1.0,
		"land_pose": 0,
	}
	if mode == Mode.RAIN:
		d["fall_dur"] = _rng.randf_range(0.38, 0.55)
		d["land_dur"] = 0.28
		spr.texture = _rain_tex
		spr.modulate = Color(0.85, 0.92, 1.0, 0.95)
		spr.rotation = deg_to_rad(18.0)
	else:
		d["fall_dur"] = _rng.randf_range(1.1, 1.7)
		d["land_dur"] = _rng.randf_range(1.1, 2.0)
		d["color_i"] = _rng.randi_range(0, maxi(0, _leaf_spin.size() - 1))
		d["spin_dir"] = -1.0 if (_cycle_i % 2) == 0 else 1.0
		d["land_pose"] = _rng.randi_range(0, 2)
		_set_leaf_frame(d, 0)
	_active.append(d)

func _set_leaf_frame(d: Dictionary, fi: int) -> void:
	var spr: Sprite2D = d["spr"]
	if spr == null:
		return
	var ci: int = d["color_i"]
	if ci < 0 or ci >= _leaf_spin.size():
		return
	var frames: Array = _leaf_spin[ci]
	if frames.is_empty():
		return
	spr.texture = frames[fi % frames.size()]
	spr.modulate = Color(1, 1, 1, 1)

func _tick_active(delta: float) -> void:
	var keep: Array = []
	for d in _active:
		var spr: Sprite2D = d.get("spr")
		if spr == null or not is_instance_valid(spr):
			continue
		match int(d["phase"]):
			Phase.FALL:
				d["t"] = float(d["t"]) + delta
				if not d.has("origin"):
					d["origin"] = spr.position
				var u := clampf(float(d["t"]) / maxf(0.05, float(d["fall_dur"])), 0.0, 1.0)
				var ease_u := u * u ## accelerate toward ground
				var origin: Vector2 = d["origin"]
				var sway := 0.0
				if mode == Mode.LEAVES:
					sway = sin(float(d["t"]) * 6.0 + float(d["color_i"])) * 14.0 * (1.0 - u)
					d["frame_t"] = float(d["frame_t"]) + delta
					if float(d["frame_t"]) >= 0.07:
						d["frame_t"] = 0.0
						d["frame"] = int(d["frame"]) + 1
						_set_leaf_frame(d, int(d["frame"]))
					spr.rotation = deg_to_rad(float(d["frame"]) * 22.0 * float(d["spin_dir"]))
				else:
					spr.rotation = deg_to_rad(18.0)
				spr.position = origin.lerp(d["target"], ease_u) + Vector2(sway, 0.0)
				IsoUtil.apply_depth(spr, float(d["feet_y"]), IsoUtil.BIAS_WEATHER_FALL)
				if u >= 1.0:
					d["phase"] = Phase.LAND
					d["land_t"] = 0.0
					spr.position = d["target"]
					spr.rotation = 0.0
					IsoUtil.apply_depth(spr, float(d["feet_y"]), IsoUtil.BIAS_WEATHER_LAND)
					if mode == Mode.RAIN:
						_begin_splash(d)
					else:
						_begin_leaf_rest(d)
				keep.append(d)
			Phase.LAND:
				d["land_t"] = float(d["land_t"]) + delta
				if mode == Mode.RAIN:
					_tick_splash(d)
				else:
					var fade_start := float(d["land_dur"]) * 0.65
					if float(d["land_t"]) > fade_start:
						var fu := (float(d["land_t"]) - fade_start) / maxf(0.05, float(d["land_dur"]) - fade_start)
						spr.modulate.a = 1.0 - clampf(fu, 0.0, 1.0)
				if float(d["land_t"]) >= float(d["land_dur"]):
					spr.queue_free()
				else:
					keep.append(d)
			_:
				spr.queue_free()
	_active = keep

func _begin_splash(d: Dictionary) -> void:
	var spr: Sprite2D = d["spr"]
	d["frame"] = 0
	d["frame_t"] = 0.0
	if not _splash_frames.is_empty():
		spr.texture = _splash_frames[0]
		spr.modulate = Color(0.9, 0.95, 1.0, 0.95)
		spr.scale = Vector2(2.2, 2.2)
	else:
		## Tiny procedural splash stand-in.
		spr.modulate = Color(0.85, 0.92, 1.0, 0.7)
		spr.scale = Vector2(1.4, 0.7)

func _tick_splash(d: Dictionary) -> void:
	var spr: Sprite2D = d["spr"]
	if _splash_frames.is_empty():
		return
	d["frame_t"] = float(d["frame_t"]) + get_process_delta_time()
	if float(d["frame_t"]) >= 0.06:
		d["frame_t"] = 0.0
		d["frame"] = int(d["frame"]) + 1
		var fi := int(d["frame"])
		if fi < _splash_frames.size():
			spr.texture = _splash_frames[fi]
		else:
			spr.modulate.a = maxf(0.0, spr.modulate.a - 0.25)

func _begin_leaf_rest(d: Dictionary) -> void:
	var spr: Sprite2D = d["spr"]
	var ci: int = d["color_i"]
	var pose: int = d["land_pose"]
	if ci < _leaf_land.size():
		var poses: Array = _leaf_land[ci]
		if not poses.is_empty():
			spr.texture = poses[pose % poses.size()]
	spr.rotation = deg_to_rad(_rng.randf_range(-25.0, 25.0))
	spr.modulate = Color(1, 1, 1, 1)
	spr.scale = Vector2(2.0, 2.0)

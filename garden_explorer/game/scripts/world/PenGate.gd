class_name PenGate
extends Node2D
## Simple isometric-friendly brown fence bar that slides/fades open for the
## player. Animals stay in pen bounds regardless.

const OPEN_DIST := 52.0
const CLOSE_DIST := 78.0
const ANIM_SEC := 0.28

var player: Node2D
var is_open: bool = false
var _bar: Polygon2D
var _closed_poly: PackedVector2Array
var _open_poly: PackedVector2Array
var _t: float = 0.0 ## 0 closed → 1 open
var _dir: int = 0 ## -1 closing, 0 idle, 1 opening

func setup(_art: FarmSprites, world_pos: Vector2) -> void:
	position = world_pos
	## Short brown rail that matches the west fence gap — solid when closed.
	_closed_poly = PackedVector2Array([
		Vector2(-22, -6), Vector2(22, -6), Vector2(18, 10), Vector2(-18, 10),
	])
	_open_poly = PackedVector2Array([
		Vector2(-22, -6), Vector2(-10, -6), Vector2(-14, 10), Vector2(-26, 10),
	])
	_bar = Polygon2D.new()
	_bar.name = "GateBar"
	_bar.color = Color(0.42, 0.28, 0.14, 1.0)
	_bar.polygon = _closed_poly
	add_child(_bar)
	## Top highlight for a bit of iso depth.
	var lip := Polygon2D.new()
	lip.color = Color(0.55, 0.38, 0.20, 1.0)
	lip.polygon = PackedVector2Array([
		Vector2(-20, -8), Vector2(20, -8), Vector2(22, -6), Vector2(-22, -6),
	])
	lip.name = "GateLip"
	add_child(lip)
	z_index = IsoUtil.depth_from_y(position.y) + 40

func bind_player(p: Node2D) -> void:
	player = p

func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var d := global_position.distance_to(player.global_position)
	if not is_open and d <= OPEN_DIST and _dir == 0:
		_begin_open()
	elif is_open and d >= CLOSE_DIST and _dir == 0:
		_begin_close()
	if _dir == 0:
		return
	_t = clampf(_t + float(_dir) * delta / ANIM_SEC, 0.0, 1.0)
	_bar.polygon = _lerp_poly(_closed_poly, _open_poly, _t)
	_bar.modulate.a = lerpf(1.0, 0.15, _t)
	if _dir > 0 and _t >= 1.0:
		_dir = 0
		is_open = true
	elif _dir < 0 and _t <= 0.0:
		_dir = 0
		is_open = false

func _begin_open() -> void:
	if _dir > 0 or (is_open and _t >= 1.0):
		return
	_dir = 1
	var GateSfxScript := preload("res://scripts/audio/GateSfx.gd")
	GateSfxScript.play_open()

func _begin_close() -> void:
	if _dir < 0 or (not is_open and _t <= 0.0):
		return
	_dir = -1
	var GateSfxScript := preload("res://scripts/audio/GateSfx.gd")
	GateSfxScript.play_close()

func _lerp_poly(a: PackedVector2Array, b: PackedVector2Array, t: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := mini(a.size(), b.size())
	for i in n:
		out.append(a[i].lerp(b[i], t))
	return out

class_name PenGate
extends Node2D
## Animated pen gate — opens for the player only (animals stay in pen bounds).

const OPEN_DIST := 52.0
const CLOSE_DIST := 78.0
const FRAME_SEC := 0.05

var player: Node2D
var is_open: bool = false
var _spr: Sprite2D
var _frames: Array = [] ## Array[Texture2D] closed → open
var _anim_t: float = 0.0
var _frame_i: int = 0
var _anim_dir: int = 0 ## -1 closing, 0 idle, 1 opening

func setup(art: FarmSprites, world_pos: Vector2) -> void:
	position = world_pos
	_frames.clear()
	if art and art.has_method("gate_frame_textures"):
		_frames = art.gate_frame_textures()
	_spr = Sprite2D.new()
	_spr.name = "GateSprite"
	_spr.centered = true
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr.scale = Vector2(2.4, 2.4)
	_spr.position = Vector2(0, -10)
	if not _frames.is_empty():
		_spr.texture = _frames[0]
	add_child(_spr)
	z_index = IsoUtil.depth_from_y(position.y) + 40

func bind_player(p: Node2D) -> void:
	player = p

func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player) or _frames.is_empty():
		return
	var d := global_position.distance_to(player.global_position)
	if not is_open and d <= OPEN_DIST:
		_begin_open()
	elif is_open and d >= CLOSE_DIST and _anim_dir == 0 and _frame_i >= _frames.size() - 1:
		_begin_close()
	if _anim_dir == 0:
		return
	_anim_t += delta
	if _anim_t < FRAME_SEC:
		return
	_anim_t = 0.0
	_frame_i = clampi(_frame_i + _anim_dir, 0, _frames.size() - 1)
	_spr.texture = _frames[_frame_i]
	if _anim_dir > 0 and _frame_i >= _frames.size() - 1:
		_anim_dir = 0
		is_open = true
	elif _anim_dir < 0 and _frame_i <= 0:
		_anim_dir = 0
		is_open = false

func _begin_open() -> void:
	if _anim_dir > 0 or (is_open and _frame_i >= _frames.size() - 1):
		return
	_anim_dir = 1
	var GateSfxScript := preload("res://scripts/audio/GateSfx.gd")
	GateSfxScript.play_open()

func _begin_close() -> void:
	if _anim_dir < 0 or (not is_open and _frame_i <= 0):
		return
	_anim_dir = -1
	var GateSfxScript := preload("res://scripts/audio/GateSfx.gd")
	GateSfxScript.play_close()

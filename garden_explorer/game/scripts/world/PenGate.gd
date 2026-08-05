class_name PenGate
extends Node2D
## Isometric pen gate (sprite frames) that opens when the player is near.
## Animals stay in pen bounds regardless.
## Depth: same bias as fence posts, sorted at gate feet — nearer post (south) draws
## above the leaf, farther post (north) behind it, so the gate sits in the fence line.

const OPEN_DIST := 40.0
const CLOSE_DIST := 62.0
const ANIM_SEC := 0.28
## Match one fence rail span (rail_a ~38px @ 2.0 → gate content ~30px).
const GATE_SCALE := 2.55

var player: Node2D
var is_open: bool = false
var _spr: Sprite2D
var _frames: Array = [] ## Texture2D closed → open
var _t: float = 0.0 ## 0 closed → 1 open
var _dir: int = 0 ## -1 closing, 0 idle, 1 opening

func setup(art: FarmSprites, world_pos: Vector2) -> void:
	position = world_pos
	_frames.clear()
	if art and art.has_method("gate_frame_textures"):
		_frames = art.gate_frame_textures()
	if _frames.is_empty():
		_frames = _load_disk_frames()
	_spr = Sprite2D.new()
	_spr.name = "GateSprite"
	_spr.centered = true
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr.scale = Vector2(GATE_SCALE, GATE_SCALE)
	## Leaf + swinging end post. Slight down vs fence mid-rails (0 still read high).
	_spr.offset = Vector2(0, 3)
	add_child(_spr)
	_apply_frame()
	## In-line with divider posts (not +150 above the fence run).
	IsoUtil.apply_depth(self, position.y, IsoUtil.BIAS_GATE)

func bind_player(p: Node2D) -> void:
	player = p

func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	## While the gardener crosses the mouth, keep the leaf under their depth band.
	var sort_y := position.y
	if player.global_position.distance_to(global_position) < 48.0 \
			and player.global_position.y >= position.y - 8.0:
		sort_y = minf(sort_y, player.global_position.y - 12.0)
	IsoUtil.apply_depth(self, sort_y, IsoUtil.BIAS_GATE)
	var d := global_position.distance_to(player.global_position)
	if not is_open and d <= OPEN_DIST and _dir == 0:
		_begin_open()
	elif is_open and d >= CLOSE_DIST and _dir == 0:
		_begin_close()
	if _dir == 0:
		return
	_t = clampf(_t + float(_dir) * delta / ANIM_SEC, 0.0, 1.0)
	_apply_frame()
	if _dir > 0 and _t >= 1.0:
		_dir = 0
		is_open = true
	elif _dir < 0 and _t <= 0.0:
		_dir = 0
		is_open = false

func _apply_frame() -> void:
	if _spr == null:
		return
	if _frames.is_empty():
		return
	var idx := int(round(_t * float(_frames.size() - 1)))
	idx = clampi(idx, 0, _frames.size() - 1)
	_spr.texture = _frames[idx]

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

func _load_disk_frames() -> Array:
	var out: Array = []
	for i in 5:
		var path := "res://assets/ui/gate/open_%d.png" % i
		if ResourceLoader.exists(path):
			out.append(load(path))
		elif FileAccess.file_exists(path):
			var img := Image.load_from_file(path)
			if img:
				out.append(ImageTexture.create_from_image(img))
	return out

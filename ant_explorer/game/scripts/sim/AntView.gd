extends Node2D
const _SpriteCatalog := preload("res://scripts/render/SpriteCatalog.gd")
## Ant visual: mega_pack sprites when present, else colored capsules.

var state: AntState
var _body: Polygon2D
var _outline: Polygon2D
var _eye: Polygon2D
var _glow: Polygon2D
var _carry: Polygon2D
var _sparkle: Node2D
var _sprite: Sprite2D
var _last_caste: int = -1
var _last_stage: int = -1
var _last_carry: int = -1
var _audio: AudioStreamPlayer
var _frame_t: float = 0.0
var _frame_i: int = 0
var _using_sprite: bool = false
var _pack: Dictionary = {}

static var catalog: RefCounted

func _ready() -> void:
	if catalog == null:
		catalog = _SpriteCatalog.new()
		catalog.bootstrap()
	_build_placeholder()
	# Stay relative to the Ants root (z=10). Y-sort there handles overlap —
	# never scale z by world Y (huge maps pushed ants behind the backdrop).
	z_as_relative = true
	z_index = 0
	_audio = AudioStreamPlayer.new()
	_audio.volume_db = -6.0
	add_child(_audio)
	var chime := "res://assets/audio/kenney_ui/Audio/rollover2.ogg"
	if ResourceLoader.exists(chime):
		_audio.stream = load(chime)

func bind(s: AntState) -> void:
	state = s
	if _body == null:
		_build_placeholder()
	_last_caste = -1
	_last_carry = -1
	_apply_look()
	global_position = s.cell
	visible = true

func sync_visual(pos: Vector2, s: AntState) -> void:
	state = s
	global_position = pos
	if s.shake_ticks > 0 or s.intent == AntEnums.State.SHAKE:
		rotation = sin(float(s.shake_ticks) * 0.9) * 0.35
	else:
		rotation = 0.0
	if s.caste == AntEnums.Caste.LARVA or s.caste == AntEnums.Caste.PUPA:
		scale = Vector2.ONE
	elif s.facing.x < -0.1:
		scale = Vector2(-1, 1)
	elif s.facing.x > 0.1:
		scale = Vector2(1, 1)
	if s.caste != _last_caste or s.larva_stage != _last_stage or s.carry != _last_carry:
		_apply_look()
	_advance_anim()
	_update_jh_glow()
	_update_carry()

func play_eclosion() -> void:
	_burst_sparkle()
	if _audio and _audio.stream:
		_audio.play()

func _advance_anim() -> void:
	if not _using_sprite or _sprite == null or state == null:
		return
	var moving := state.state == AntEnums.State.WALK or not state.path.is_empty()
	var frames: Array = _pack.get("move" if moving else "idle", []) as Array
	if frames.is_empty():
		frames = _pack.get("idle", []) as Array
	if frames.is_empty():
		return
	_frame_t += 0.12
	if _frame_t >= 1.0:
		_frame_t = 0.0
		_frame_i = (_frame_i + 1) % frames.size()
		_sprite.texture = frames[_frame_i] as Texture2D

func _build_placeholder() -> void:
	for c in get_children():
		if c is AudioStreamPlayer:
			continue
		c.queue_free()
	_glow = Polygon2D.new()
	_glow.z_index = -1
	add_child(_glow)
	_outline = Polygon2D.new()
	_outline.color = Color(0.12, 0.08, 0.05, 0.85)
	add_child(_outline)
	_body = Polygon2D.new()
	add_child(_body)
	_eye = Polygon2D.new()
	_eye.color = Color(0.1, 0.08, 0.06)
	add_child(_eye)
	_sprite = Sprite2D.new()
	_sprite.visible = false
	_sprite.centered = true
	add_child(_sprite)
	_carry = Polygon2D.new()
	_carry.visible = false
	add_child(_carry)
	_sparkle = Node2D.new()
	add_child(_sparkle)
	_apply_look()

func _apply_look() -> void:
	if state == null:
		return
	_last_caste = state.caste
	_last_stage = state.larva_stage
	_last_carry = state.carry
	var leaf := state.carry == AntEnums.Carry.LEAF
	_pack = catalog.frames_for(state.caste, leaf) if catalog else {}
	var idle: Array = _pack.get("idle", []) as Array
	_using_sprite = idle.size() > 0
	if _using_sprite:
		_sprite.visible = true
		_body.visible = false
		_outline.visible = false
		_eye.visible = false
		_sprite.texture = idle[0] as Texture2D
		var sc: float = float(_pack.get("scale", 0.22))
		if state.caste == AntEnums.Caste.LARVA:
			sc *= 0.85 + float(state.larva_stage) * 0.08
		_sprite.scale = Vector2(sc, sc)
		_frame_i = 0
		if state.caste == AntEnums.Caste.INVADER:
			_sprite.modulate = AntEnums.enemy_color(state.enemy_kind)
		elif state.is_player:
			_sprite.modulate = Color(1.15, 1.1, 1.0)
		else:
			_sprite.modulate = Color(1, 1, 1)
		_glow.visible = state.is_player and state.role != AntEnums.Role.NONE
		if _glow.visible:
			var rc := AntEnums.role_color(state.role)
			_glow.color = Color(rc.r, rc.g, rc.b, 0.35)
			var r: float = AntEnums.caste_radius(state.caste)
			_glow.polygon = _capsule(r + 5.0, r * 1.55 + 5.0)
		return
	# Placeholder capsules
	_sprite.visible = false
	_body.visible = true
	_outline.visible = true
	if state.caste == AntEnums.Caste.LARVA:
		_apply_larva_look()
		return
	if state.caste == AntEnums.Caste.PUPA:
		_apply_pupa_look()
		return
	var r: float = AntEnums.caste_radius(state.caste)
	var col: Color = AntEnums.caste_color(state.caste)
	if state.caste == AntEnums.Caste.INVADER:
		col = AntEnums.enemy_color(state.enemy_kind)
	_body.color = col
	_body.polygon = _capsule(r, r * 1.55)
	_outline.polygon = _capsule(r + 1.5, r * 1.55 + 1.5)
	_eye.visible = true
	_eye.polygon = PackedVector2Array([
		Vector2(r * 0.35, -r * 0.25), Vector2(r * 0.55, -r * 0.15),
		Vector2(r * 0.55, r * 0.05), Vector2(r * 0.35, r * 0.15),
	])
	modulate = Color(1.15, 1.1, 1.0) if state.is_player else Color(1, 1, 1)
	_glow.visible = state.is_player and state.role != AntEnums.Role.NONE
	if _glow.visible:
		var rc := AntEnums.role_color(state.role)
		_glow.color = Color(rc.r, rc.g, rc.b, 0.35)
		_glow.polygon = _capsule(r + 5.0, r * 1.55 + 5.0)

func _apply_larva_look() -> void:
	var stage_scale: float = 0.7 + float(state.larva_stage) * 0.25
	var r: float = 5.0 * stage_scale
	var t: float = clampf(state.jh_dose / 6.0, 0.0, 1.0)
	var col := Color(0.93, 0.88, 0.78).lerp(Color(0.95, 0.55, 0.65), t * 0.7)
	_body.color = col
	_body.polygon = _capsule(r * 1.1, r * 0.7)
	_outline.polygon = _capsule(r * 1.1 + 1.2, r * 0.7 + 1.2)
	_eye.visible = false
	_glow.visible = t > 0.05
	if _glow.visible:
		_glow.color = Color(0.95, 0.45, 0.55, 0.2 + t * 0.35)
		_glow.polygon = _capsule(r * 1.1 + 4.0, r * 0.7 + 4.0)

func _apply_pupa_look() -> void:
	var r := 7.0
	_body.color = Color(0.96, 0.96, 0.98)
	_body.polygon = _rounded_rect(r * 0.9, r * 1.35)
	_outline.polygon = _rounded_rect(r * 0.9 + 1.5, r * 1.35 + 1.5)
	_eye.visible = false
	_glow.visible = true
	_glow.color = Color(0.85, 0.9, 1.0, 0.25)
	_glow.polygon = _rounded_rect(r * 0.9 + 4.0, r * 1.35 + 4.0)

func _update_jh_glow() -> void:
	if state == null or state.caste != AntEnums.Caste.LARVA:
		return
	if _using_sprite:
		var t: float = clampf(state.jh_dose / 6.0, 0.0, 1.0)
		_sprite.modulate = Color(1, 1, 1).lerp(Color(1.0, 0.7, 0.8), t * 0.5)
		return
	_apply_larva_look()

func _update_carry() -> void:
	if state == null or _carry == null:
		return
	# Leaf foragers use with_leaf sprite pack; skip overlay.
	if _using_sprite and state.carry == AntEnums.Carry.LEAF:
		_carry.visible = false
		return
	if state.carry == AntEnums.Carry.NONE or AntEnums.is_brood(state.caste):
		_carry.visible = false
		return
	_carry.visible = true
	match state.carry:
		AntEnums.Carry.FOOD:
			_carry.color = Color(0.45, 0.85, 0.4)
			_carry.polygon = _capsule(3.5, 3.5)
			_carry.position = Vector2(8, -6)
		AntEnums.Carry.EGG:
			_carry.color = Color(0.95, 0.9, 0.7)
			_carry.polygon = _capsule(4.0, 3.0)
			_carry.position = Vector2(8, -7)
		AntEnums.Carry.LARVA:
			_carry.color = Color(0.92, 0.85, 0.75)
			_carry.polygon = _capsule(5.0, 3.5)
			_carry.position = Vector2(6, -8)
		AntEnums.Carry.LEAF:
			_carry.color = Color(0.35, 0.75, 0.30)
			_carry.polygon = _capsule(6.0, 4.0)
			_carry.position = Vector2(10, -8)
		AntEnums.Carry.WASTE:
			_carry.color = Color(0.45, 0.4, 0.35)
			_carry.polygon = _capsule(4.0, 3.0)
			_carry.position = Vector2(8, -6)
		_:
			_carry.visible = false

func _burst_sparkle() -> void:
	if _sparkle == null:
		return
	for i in 8:
		var p := Polygon2D.new()
		p.color = Color(1.0, 0.9, 0.4, 0.95)
		p.polygon = PackedVector2Array([
			Vector2(0, -5), Vector2(1.5, -1.5), Vector2(5, 0),
			Vector2(1.5, 1.5), Vector2(0, 5), Vector2(-1.5, 1.5),
			Vector2(-5, 0), Vector2(-1.5, -1.5),
		])
		_sparkle.add_child(p)
		var ang := TAU * float(i) / 8.0
		var tw := create_tween()
		tw.tween_property(p, "position", Vector2(cos(ang), sin(ang)) * 28.0, 0.45)
		tw.parallel().tween_property(p, "modulate:a", 0.0, 0.45)
		tw.tween_callback(p.queue_free)

func _capsule(rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 16:
		var t := TAU * float(i) / 16.0
		pts.append(Vector2(cos(t) * rx, sin(t) * ry))
	return pts

func _rounded_rect(rx: float, ry: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-rx, -ry * 0.7), Vector2(rx, -ry * 0.7), Vector2(rx * 1.05, 0),
		Vector2(rx, ry * 0.7), Vector2(-rx, ry * 0.7), Vector2(-rx * 1.05, 0),
	])

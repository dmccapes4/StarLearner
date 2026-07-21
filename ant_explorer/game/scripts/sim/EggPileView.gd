extends Node2D
## Visible egg heap in the queen's chamber. Nurses pick from here — not the queen.

const MAX_SHOWN := 6
const _EGG_TEX := "res://assets/ants/mega_pack/spriter_file_png_parts/props/egg.png"

var _count: int = -1
var _sprites: Array[Sprite2D] = []
var _egg_tex: Texture2D

func _ready() -> void:
	z_as_relative = true
	z_index = 2
	if ResourceLoader.exists(_EGG_TEX):
		_egg_tex = load(_EGG_TEX) as Texture2D
	for i in MAX_SHOWN:
		var s := Sprite2D.new()
		s.texture = _egg_tex
		s.scale = Vector2(0.12, 0.12)
		s.visible = false
		# Slight scatter so the pile reads as a cluster, not a stack.
		var ang := float(i) * TAU / float(MAX_SHOWN)
		s.position = Vector2(cos(ang), sin(ang)) * (6.0 + float(i % 3) * 3.0)
		s.rotation = ang * 0.35
		add_child(s)
		_sprites.append(s)


func sync_count(n: int) -> void:
	n = clampi(n, 0, MAX_SHOWN)
	if n == _count:
		return
	_count = n
	for i in _sprites.size():
		var s: Sprite2D = _sprites[i]
		s.visible = i < n
		if _egg_tex == null:
			# Fallback: tinted capsule if texture missing.
			continue
	if _egg_tex == null:
		_ensure_poly_fallback(n)


func _ensure_poly_fallback(n: int) -> void:
	for c in get_children():
		if c is Polygon2D:
			c.queue_free()
	for i in n:
		var p := Polygon2D.new()
		p.color = Color(0.95, 0.9, 0.7)
		p.polygon = PackedVector2Array([
			Vector2(-4, -2), Vector2(4, -2), Vector2(3, 3), Vector2(-3, 3),
		])
		var ang := float(i) * TAU / float(MAX_SHOWN)
		p.position = Vector2(cos(ang), sin(ang)) * (6.0 + float(i % 3) * 3.0)
		add_child(p)

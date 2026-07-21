class_name CubeGroup
extends Control
## A row/grid of rounded cubes — the atom of Math Explorer. Each cube has a base
## colour and a highlight ring used while counting:
##   HL.CURRENT → bright, thick ring (the one being counted right now)
##   HL.DONE    → dull, medium ring (already counted)
##   HL.NONE    → faint ring (not yet counted)
## HUE picks the ring colour family (GOLD for the leading group, GREY for the
## second group), matching the tutorial choreography.

enum HL { NONE, DONE, CURRENT }
enum HUE { GOLD, GREY }

@export var cell: float = 58.0
@export var gap: float = 12.0
@export var columns: int = 8

var _cubes: Array = []   # each: {"color": Color, "hl": int, "hue": int}

func setup(n: int, color: Color, hue: int = HUE.GOLD) -> void:
	_cubes.clear()
	for i in n:
		_cubes.append({"color": color, "hl": HL.NONE, "hue": hue})
	_refit()
	queue_redraw()

func count() -> int:
	return _cubes.size()

func set_state(i: int, hl: int, hue: int = -1) -> void:
	if i < 0 or i >= _cubes.size():
		return
	_cubes[i]["hl"] = hl
	if hue >= 0:
		_cubes[i]["hue"] = hue
	queue_redraw()

func set_all_state(hl: int) -> void:
	for c in _cubes:
		c["hl"] = hl
	queue_redraw()

func set_all_color(color: Color) -> void:
	for c in _cubes:
		c["color"] = color
	queue_redraw()

func set_color(i: int, color: Color) -> void:
	if i >= 0 and i < _cubes.size():
		_cubes[i]["color"] = color
		queue_redraw()

## Centre of cube i in this control's local space (handy for flying cubes around).
func cube_center(i: int) -> Vector2:
	var r := _cube_rect(i)
	return r.position + r.size * 0.5

func _refit() -> void:
	var n := _cubes.size()
	var cols: int = mini(maxi(1, columns), maxi(1, n))
	var rows: int = int(ceil(float(n) / float(cols))) if n > 0 else 0
	custom_minimum_size = Vector2(
		cols * cell + maxf(0, cols - 1) * gap,
		rows * cell + maxf(0, rows - 1) * gap)
	size = custom_minimum_size

func _cube_rect(i: int) -> Rect2:
	var cols: int = mini(maxi(1, columns), maxi(1, _cubes.size()))
	var col := i % cols
	var row := i / cols
	var x := col * (cell + gap)
	var y := row * (cell + gap)
	return Rect2(Vector2(x, y), Vector2(cell, cell))

func _draw() -> void:
	for i in _cubes.size():
		var c: Dictionary = _cubes[i]
		var rect := _cube_rect(i)
		var sb := StyleBoxFlat.new()
		sb.bg_color = c["color"]
		sb.set_corner_radius_all(int(cell * 0.22))
		var bright: bool = int(c["hl"]) == HL.CURRENT
		var done: bool = int(c["hl"]) == HL.DONE
		var w := 6 if bright else (4 if done else 2)
		sb.set_border_width_all(w)
		sb.border_color = _ring_color(int(c["hue"]), int(c["hl"]))
		# A gentle pop for the current cube.
		var draw_rect := rect
		if bright:
			draw_rect = rect.grow(3.0)
			sb.shadow_color = Color(MathTheme.GOLD, 0.5)
			sb.shadow_size = 8
		sb.draw(get_canvas_item(), draw_rect)

func _ring_color(hue: int, hl: int) -> Color:
	if hl == HL.NONE:
		return MathTheme.OUT_NONE
	if hue == HUE.GREY:
		return MathTheme.OUT_GREY_BRIGHT if hl == HL.CURRENT else MathTheme.OUT_GREY_DULL
	return MathTheme.OUT_GOLD_BRIGHT if hl == HL.CURRENT else MathTheme.OUT_GOLD_DULL

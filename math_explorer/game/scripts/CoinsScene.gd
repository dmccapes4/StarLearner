class_name CoinsScene
extends Control
## The penny / nickel / dime exercise. A purse of coins sits at the bottom; she
## drags coins into the piggy-bank tray to make a target amount. The running
## total updates live and is spoken. Exactly the target → gold flash, praise,
## next round. Over the target → the last coin bounces back with a hint.
##
## Coins are drawn procedurally (copper penny 1¢, silver nickel 5¢, small
## silver dime 10¢ — sized like real coins: dime smaller than penny).
## Numbers come from MathProblemGen("coins_make") so a target is always makeable.

signal finished()

const COIN_R := {"penny": 30.0, "nickel": 34.0, "dime": 26.0}
const COIN_VAL := {"penny": 1, "nickel": 5, "dime": 10}
const COIN_FILL := {
	"penny": Color(0.80, 0.50, 0.28),
	"nickel": Color(0.78, 0.80, 0.85),
	"dime": Color(0.83, 0.85, 0.90),
}

## Fixed lines (baked ElevenLabs); dynamic totals use the OS TTS fallback.
const VO_FIXED := [
	"Time to count coins! A penny is one cent. A nickel is five. A dime is ten.",
	"Drag coins into the tray to make the amount.",
	"That is too much! Try a different coin.",
	"Perfect! You made it exactly.",
]

var _p: Dictionary = {}
var _target: int = 0
var _total: int = 0
var _rounds: int = 0
var _coins: Array = []       # draggable coin Controls
var _dragging: Control = null
var _drag_off: Vector2 = Vector2.ZERO
var _tray: Panel
var _title: Label
var _total_lbl: Label
var _bank: TextureRect
var _built := false

func start() -> void:
	_build()
	visible = true
	_rounds = 0
	Narrator.speak(VO_FIXED[0])
	_next_round()

func _build() -> void:
	if _built:
		return
	_built = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 40)
	_title.add_theme_color_override("font_color", MathTheme.TEXT)
	_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_title.add_theme_constant_override("outline_size", 5)
	_title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.offset_top = 22
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title)

	_tray = Panel.new()
	_tray.size = Vector2(560, 190)
	_tray.position = Vector2(360, 120)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.20, 0.24, 0.36, 0.85)
	sb.set_corner_radius_all(22)
	sb.set_border_width_all(3)
	sb.border_color = Color(1, 1, 1, 0.30)
	_tray.add_theme_stylebox_override("panel", sb)
	_tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tray)

	_bank = TextureRect.new()
	var tex := StorySprites.texture("piggy_bank")
	if tex:
		_bank.texture = tex
		_bank.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_bank.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var h := 150.0
		_bank.size = Vector2(h * tex.get_width() / float(tex.get_height()), h)
		_bank.position = Vector2(150, 140)
		_bank.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_bank)

	_total_lbl = Label.new()
	_total_lbl.add_theme_font_size_override("font_size", 46)
	_total_lbl.add_theme_color_override("font_color", MathTheme.GOLD)
	_total_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_total_lbl.add_theme_constant_override("outline_size", 5)
	_total_lbl.position = Vector2(950, 180)
	_total_lbl.size = Vector2(220, 60)
	_total_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_total_lbl)

func _next_round() -> void:
	for c in _coins:
		c.queue_free()
	_coins.clear()
	_rounds += 1
	_p = MathProblemGen.generate("coins_make", -1)
	var q: Dictionary = _p["params"]
	_target = q["target"]
	_total = 0
	_update_total()
	_title.text = "Make %d\u00A2" % _target
	Narrator.speak("Make %d cents." % _target)
	if _rounds == 1:
		Narrator.speak(VO_FIXED[1])

	# Purse rows: dimes, nickels, pennies.
	var y := 400.0
	var specs := [["dime", int(q["dimes"])], ["nickel", int(q["nickels"])], ["penny", int(q["pennies"])]]
	for spec in specs:
		var kind: String = spec[0]
		var count: int = spec[1]
		var r: float = COIN_R[kind]
		var gap := r * 2.0 + 14.0
		var x0 := 640.0 - (float(count) * gap - 14.0) * 0.5
		for i in count:
			_spawn_coin(kind, Vector2(x0 + i * gap, y))
		y += 92.0

func _spawn_coin(kind: String, pos: Vector2) -> void:
	var c := _CoinControl.new()
	c.kind = kind
	c.radius = COIN_R[kind]
	c.fill = COIN_FILL[kind]
	c.value = COIN_VAL[kind]
	c.size = Vector2(c.radius * 2.0, c.radius * 2.0)
	c.position = pos
	c.set_meta("home", pos)
	c.set_meta("in_tray", false)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	_coins.append(c)

# ---- drag --------------------------------------------------------------------

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed: _begin_drag(event.position)
		else: _end_drag(event.position)
	elif event is InputEventScreenTouch:
		if event.pressed: _begin_drag(event.position)
		else: _end_drag(event.position)
	elif (event is InputEventMouseMotion or event is InputEventScreenDrag) and _dragging:
		_dragging.position = event.position - _drag_off

func _begin_drag(pos: Vector2) -> void:
	for i in range(_coins.size() - 1, -1, -1):
		var c: Control = _coins[i]
		if c.get_meta("in_tray"):
			continue
		if Rect2(c.position, c.size).has_point(pos):
			_dragging = c
			_drag_off = pos - c.position
			move_child(c, get_child_count() - 1)
			return

func _end_drag(pos: Vector2) -> void:
	if _dragging == null:
		return
	var c := _dragging
	_dragging = null
	var center := c.position + c.size * 0.5
	if Rect2(_tray.position, _tray.size).has_point(center):
		var val: int = (c as _CoinControl).value
		if _total + val > _target:
			Narrator.speak(VO_FIXED[2])
			_snap_home(c)
			return
		c.set_meta("in_tray", true)
		_total += val
		_update_total()
		# Settle into the tray in a tidy row.
		var in_tray := 0
		for cc in _coins:
			if cc.get_meta("in_tray"):
				in_tray += 1
		var slot := Vector2(_tray.position.x + 26 + ((in_tray - 1) % 7) * 74,
			_tray.position.y + 24 + ((in_tray - 1) / 7) * 74)
		var tw := create_tween()
		tw.tween_property(c, "position", slot, 0.18).set_trans(Tween.TRANS_QUAD)
		Narrator.speak("%d cents." % _total)
		if _total == _target:
			_win()
	else:
		_snap_home(c)

func _snap_home(c: Control) -> void:
	var tw := create_tween()
	tw.tween_property(c, "position", c.get_meta("home"), 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _win() -> void:
	Narrator.speak(VO_FIXED[3])
	var tw := create_tween()
	tw.tween_property(_tray, "scale", Vector2(1.06, 1.06), 0.12)
	tw.tween_property(_tray, "scale", Vector2.ONE, 0.12)
	await get_tree().create_timer(2.0).timeout
	# Return to the card — Play again starts a fresh target.
	finished.emit()

func _update_total() -> void:
	_total_lbl.text = "%d\u00A2" % _total

func stop() -> void:
	_dragging = null

## A single drawn coin: filled circle, rim, and the value stamped on it.
class _CoinControl:
	extends Control
	var kind: String = "penny"
	var radius: float = 30.0
	var fill: Color = Color.WHITE
	var value: int = 1

	func _draw() -> void:
		var c := size * 0.5
		draw_circle(c, radius, fill)
		draw_arc(c, radius - 2.0, 0, TAU, 48, fill.darkened(0.35), 4.0)
		var f := ThemeDB.fallback_font
		var txt := "%d\u00A2" % value
		var fs := int(radius * 0.62)
		var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
		draw_string(f, c + Vector2(-w * 0.5, radius * 0.24), txt,
			HORIZONTAL_ALIGNMENT_CENTER, -1, fs, fill.darkened(0.55))

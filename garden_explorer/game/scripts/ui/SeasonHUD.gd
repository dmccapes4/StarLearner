class_name SeasonHUD
extends CanvasLayer
## Top-right season tile with progress shade + tap-to-hear time left.
## Center toast still announces season changes.

const SpeakScript := preload("res://scripts/audio/Speak.gd")

var season_clock: Node ## SeasonClock
var seed_db: SeedDB

var _icon_btn: TextureButton
var _shade: ColorRect
var _toast: Label
var _toast_left: float = 0.0
var _season_id: String = "spring"
var _label_name: String = "Spring"

const ICON_SIZE := 72.0
const MARGIN := 16.0

func _ready() -> void:
	add_to_group("season_hud")
	layer = 22
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	## Top-right season tile (kid-readable art + progress).
	_icon_btn = TextureButton.new()
	_icon_btn.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	_icon_btn.size = Vector2(ICON_SIZE, ICON_SIZE)
	_icon_btn.ignore_texture_size = true
	_icon_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_COVERED
	_icon_btn.focus_mode = Control.FOCUS_NONE
	_icon_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_icon_btn.pressed.connect(_on_icon_pressed)
	root.add_child(_icon_btn)

	_shade = ColorRect.new()
	_shade.color = Color(0.05, 0.08, 0.12, 0.55)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon_btn.add_child(_shade)

	_toast = Label.new()
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_font_size_override("font_size", 22)
	_toast.add_theme_color_override("font_color", Color(1, 0.95, 0.75, 1))
	_toast.visible = false
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_toast)

	set_process(true)
	call_deferred("_layout")
	get_viewport().size_changed.connect(_layout)

func setup(clock: Node, db: SeedDB) -> void:
	season_clock = clock
	seed_db = db
	if db:
		set_season(db.current_season, db.season_label(db.current_season))

func set_season(season_id: String, label: String) -> void:
	_season_id = season_id
	_label_name = label
	var path := "res://assets/seasons/season_%s.jpg" % season_id
	if ResourceLoader.exists(path):
		_icon_btn.texture_normal = load(path)
	_icon_btn.modulate = _tint(season_id)
	_layout()
	_update_progress()

func announce(line: String) -> void:
	_toast.text = line
	_toast.visible = true
	_toast_left = 3.5
	_layout()

func _process(delta: float) -> void:
	_update_progress()
	if _toast_left > 0.0:
		_toast_left -= delta
		if _toast_left <= 0.0:
			_toast.visible = false

func _layout() -> void:
	var vp := get_viewport().get_visible_rect().size
	_icon_btn.position = Vector2(vp.x - ICON_SIZE - MARGIN, MARGIN)
	_toast.position = Vector2(vp.x * 0.5 - 200.0, 96.0)
	_toast.size = Vector2(400, 36)

func _update_progress() -> void:
	if _icon_btn == null or _shade == null:
		return
	var frac := 0.0 ## 0 = just started (full bright), 1 = almost over (mostly shaded)
	if season_clock != null:
		var dur := float(season_clock.get("duration_sec"))
		var elapsed := float(season_clock.get("elapsed"))
		if dur > 0.0:
			frac = clampf(elapsed / dur, 0.0, 1.0)
	## Shade grows from the top as the season progresses (bright = time left).
	_shade.position = Vector2.ZERO
	_shade.size = Vector2(ICON_SIZE, ICON_SIZE * frac)

func _on_icon_pressed() -> void:
	var left := 0.0
	if season_clock != null and season_clock.has_method("time_remaining"):
		left = float(season_clock.call("time_remaining"))
	elif season_clock != null:
		left = maxf(0.0, float(season_clock.get("duration_sec")) - float(season_clock.get("elapsed")))
	var line := _format_remaining(left)
	## Soft VO — don't freeze walking just to hear the clock.
	SpeakScript.soft(line)

func _format_remaining(sec: float) -> String:
	var s := int(ceil(sec))
	if s <= 0:
		return "This season is almost over!"
	if s < 60:
		if s == 1:
			return "One second left in %s." % _label_name
		return "%d seconds left in %s." % [s, _label_name]
	var mins := s / 60
	var rem := s % 60
	if mins == 1 and rem == 0:
		return "One minute left in %s." % _label_name
	if rem == 0:
		return "%d minutes left in %s." % [mins, _label_name]
	if mins == 1:
		return "One minute and %d seconds left in %s." % [rem, _label_name]
	return "%d minutes and %d seconds left in %s." % [mins, rem, _label_name]

func _tint(season_id: String) -> Color:
	match season_id:
		"summer":
			return Color(1.0, 0.95, 0.7, 1)
		"fall":
			return Color(1.0, 0.82, 0.55, 1)
		"winter":
			return Color(0.75, 0.88, 1.0, 1)
		_:
			return Color(0.85, 1.0, 0.8, 1)

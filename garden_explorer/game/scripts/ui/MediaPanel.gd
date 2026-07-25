extends CanvasLayer
## Fullscreen plant / concept media: prefer .ogv, else narrated image slideshow.
## Always user-triggered — never auto-opens on its own.

signal closed()
signal started(media_id: String)

const SpeakScript := preload("res://scripts/audio/Speak.gd")

var seed_db: SeedDB
var sprites: FarmSprites
var _open: bool = false
var _dim: ColorRect
var _player: VideoStreamPlayer
var _tex: TextureRect
var _title: Label
var _body: Label
var _back: Button
var _slides: Array = []
var _slide_i: int = 0
var _slide_wait: float = 0.0
var _mode: String = "" ## video | slides
var _media_id: String = ""

func _ready() -> void:
	add_to_group("media_panel")
	add_to_group("stage_media") ## legacy group name used by VideoPanel
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 48
	_build()
	visible = false
	set_process(false)

func setup(db: SeedDB, art: FarmSprites) -> void:
	seed_db = db
	sprites = art

func is_open() -> bool:
	return _open

## Back-compat no-op — growth media is interaction-gated now.
func show_stage(_plant_id: String, _stage: String) -> void:
	pass

func play_plant(plant_id: String, kind: String, topic: String = "") -> bool:
	if _open or seed_db == null:
		return false
	var title := topic
	if title.is_empty():
		title = "%s — %s" % [seed_db.display_name(plant_id), kind.capitalize()]
	var path := seed_db.media_path(plant_id, kind)
	if not path.is_empty() and (ResourceLoader.exists(path) or FileAccess.file_exists(ProjectSettings.globalize_path(path))):
		return _open_video("plant:%s:%s" % [plant_id, kind], path, title)
	return _open_slides("plant:%s:%s" % [plant_id, kind], title, _plant_slides(plant_id, kind))

func play_file(media_id: String, path: String, title: String) -> bool:
	if _open:
		return false
	if not path.is_empty() and (ResourceLoader.exists(path) or FileAccess.file_exists(ProjectSettings.globalize_path(path))):
		return _open_video(media_id, path, title)
	_open_slides(media_id, title, [{
		"text": title,
		"image": "",
	}])
	return true

func play_unlock_demo(title: String, lines: PackedStringArray) -> bool:
	if _open:
		return false
	var slides: Array = []
	for line in lines:
		slides.append({"text": str(line), "image": ""})
	return _open_slides("unlock_demo", title, slides)

func _plant_slides(plant_id: String, kind: String) -> Array:
	var plant := seed_db.get_plant(plant_id)
	var slides_raw: Dictionary = plant.get("slides", {})
	var arr: Array = slides_raw.get(kind, [])
	var out: Array = []
	if arr.is_empty():
		var blurb := str(plant.get("blurb", seed_db.display_name(plant_id)))
		out.append({"text": blurb, "image": ""})
		return out
	for s in arr:
		if typeof(s) == TYPE_DICTIONARY:
			out.append(s)
	return out

func _open_video(media_id: String, path: String, title: String) -> bool:
	_stop_all()
	_media_id = media_id
	_mode = "video"
	_open = true
	visible = true
	_title.text = title
	_body.visible = false
	_tex.visible = false
	_player.visible = true
	var stream = load(path)
	if stream is VideoStream:
		_player.stream = stream
		_player.play()
		get_tree().paused = true
		started.emit(media_id)
		set_process(false)
		return true
	## Fall through to a single title slide.
	return _open_slides(media_id, title, [{"text": title, "image": ""}])

func _open_slides(media_id: String, title: String, slides: Array) -> bool:
	_stop_all()
	_media_id = media_id
	_mode = "slides"
	_slides = slides
	_slide_i = 0
	_open = true
	visible = true
	_title.text = title
	_player.visible = false
	_tex.visible = true
	_body.visible = true
	get_tree().paused = true
	started.emit(media_id)
	_show_slide(0)
	set_process(true)
	return true

func _show_slide(i: int) -> void:
	if i < 0 or i >= _slides.size():
		_close()
		return
	_slide_i = i
	var s: Dictionary = _slides[i]
	var text := str(s.get("text", ""))
	_body.text = text
	_tex.texture = null
	var img := str(s.get("image", ""))
	if not img.is_empty():
		var path := img if img.begins_with("res://") else "res://assets/plants/%s" % img
		if ResourceLoader.exists(path) or FileAccess.file_exists(ProjectSettings.globalize_path(path)):
			var tex = load(path)
			if tex is Texture2D:
				_tex.texture = tex
	## Prefer explicit slide stage (Mana Seed growth frames) for shed narration.
	var stage_hint := str(s.get("stage", ""))
	var pid := ""
	if _media_id.begins_with("plant:"):
		var parts := _media_id.split(":")
		if parts.size() >= 2:
			pid = parts[1]
	if _tex.texture == null and sprites != null and not pid.is_empty():
		var kind_guess := stage_hint
		if kind_guess.is_empty():
			kind_guess = "seed"
			if _media_id.contains(":sprout"):
				kind_guess = "sprout"
			elif _media_id.contains(":grown"):
				kind_guess = "grown"
		_tex.texture = sprites.plant_stage_texture(pid, kind_guess)
	## Seed-bag icon for the first seed slide when stage art is "seed" bag preferred.
	if _tex.texture == null and sprites != null and not pid.is_empty():
		_tex.texture = sprites.seed_icon(pid)
	var dur := SpeakScript.line(text)
	_slide_wait = maxf(2.4, dur + 0.35)

func _process(delta: float) -> void:
	if not _open or _mode != "slides":
		return
	_slide_wait -= delta
	if _slide_wait <= 0.0:
		if _slide_i + 1 < _slides.size():
			_show_slide(_slide_i + 1)
		else:
			_close()

func _build() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(root)

	_dim = ColorRect.new()
	_dim.color = Color(0.06, 0.1, 0.08, 1)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(_dim)

	_player = VideoStreamPlayer.new()
	_player.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_player.expand = true
	_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_player.finished.connect(_close)
	root.add_child(_player)

	_tex = TextureRect.new()
	_tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tex.offset_top = 70
	_tex.offset_bottom = -120
	_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tex.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(_tex)

	_title = Label.new()
	_title.position = Vector2(160, 20)
	_title.size = Vector2(960, 40)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 28)
	_title.add_theme_color_override("font_color", Color(1, 0.95, 0.75, 1))
	_title.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(_title)

	_body = Label.new()
	_body.position = Vector2(180, 480)
	_body.size = Vector2(920, 90)
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_font_size_override("font_size", 24)
	_body.add_theme_color_override("font_color", Color(0.95, 0.98, 0.9, 1))
	_body.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(_body)

	_back = Button.new()
	_back.text = "◀"
	_back.position = Vector2(28, 28)
	_back.custom_minimum_size = Vector2(112, 88)
	_back.add_theme_font_size_override("font_size", 48)
	_back.process_mode = Node.PROCESS_MODE_ALWAYS
	_back.pressed.connect(_close)
	_style_back(_back)
	root.add_child(_back)

func _style_back(btn: Button) -> void:
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_color_override("font_color", Color(0.15, 0.1, 0.05))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.95, 0.86, 0.45, 0.98)
	sb.set_corner_radius_all(18)
	sb.set_border_width_all(4)
	sb.border_color = Color(1, 1, 1, 0.9)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.add_theme_stylebox_override("pressed", sb)

func _stop_all() -> void:
	SpeakScript.stop()
	if _player:
		_player.stop()
		_player.stream = null
	_slides.clear()
	_slide_wait = 0.0

func _close() -> void:
	if not _open:
		return
	_open = false
	_stop_all()
	visible = false
	set_process(false)
	get_tree().paused = false
	closed.emit()
	_media_id = ""

func _stop_video() -> void:
	_close()

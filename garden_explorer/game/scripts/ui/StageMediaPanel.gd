class_name StageMediaPanel
extends CanvasLayer
## Brief media toast on sprout / grown (video if present, else pack icon).

var seed_db: SeedDB
var sprites: FarmSprites
var _panel: PanelContainer
var _tex: TextureRect
var _label: Label
var _video: VideoStreamPlayer
var _hide_left: float = 0.0

func _ready() -> void:
	layer = 35
	_build()
	visible = false

func setup(db: SeedDB, art: FarmSprites) -> void:
	seed_db = db
	sprites = art

func show_stage(plant_id: String, stage: String) -> void:
	if seed_db == null:
		return
	var kind := "sprout" if stage == "sprout" else ("grown" if stage == "grown" else "")
	if kind.is_empty():
		return
	visible = true
	_panel.visible = true
	_label.text = "%s — %s" % [seed_db.display_name(plant_id), stage]
	_stop_video()
	var path := seed_db.media_path(plant_id, kind)
	var played := false
	if not path.is_empty() and (ResourceLoader.exists(path) or FileAccess.file_exists(path)):
		var stream = load(path)
		if stream is VideoStream:
			_video.stream = stream
			_video.visible = true
			_tex.visible = false
			_video.play()
			played = true
	if not played:
		_video.visible = false
		_tex.visible = true
		if sprites:
			_tex.texture = sprites.plant_stage_texture(plant_id, stage)
	_hide_left = 2.8

func _process(delta: float) -> void:
	if _hide_left <= 0.0:
		return
	_hide_left -= delta
	if _hide_left <= 0.0:
		_stop_video()
		visible = false

func _build() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_panel = PanelContainer.new()
	_panel.position = Vector2(960, 80)
	_panel.custom_minimum_size = Vector2(280, 260)
	root.add_child(_panel)
	var v := VBoxContainer.new()
	_panel.add_child(v)
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_label)
	_tex = TextureRect.new()
	_tex.custom_minimum_size = Vector2(200, 200)
	_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	v.add_child(_tex)
	_video = VideoStreamPlayer.new()
	_video.custom_minimum_size = Vector2(240, 160)
	_video.visible = false
	v.add_child(_video)

func _stop_video() -> void:
	if _video and _video.is_playing():
		_video.stop()
	if _video:
		_video.visible = false

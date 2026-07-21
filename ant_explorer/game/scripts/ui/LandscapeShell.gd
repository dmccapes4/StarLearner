extends CanvasLayer
## Landscape chrome: centered playfield framed by permanent silver borders and
## 6+6 star rails. The rails sit OCCLUDED behind bright brown soil by default;
## touching a side brightens/reveals them (keeping the grey-vs-colour discovered
## variation) and makes the tiles clickable. With no interaction they slide back
## under the soil after REVEAL_SECONDS. Double-tap (1 s) a collected tile to play
## its video. See docs/STRATEGY_LANDSCAPE_STAR_RAILS.md.
##
## Built in code (no fragile .tscn paths) and driven by pure helpers
## (StarRailLayout / StarRailModel / DoubleTapArm) so the logic is unit-tested.

const _Layout := preload("res://scripts/ui/StarRailLayout.gd")
const _Model := preload("res://scripts/ui/StarRailModel.gd")
const _Arm := preload("res://scripts/ui/DoubleTapArm.gd")
const _Tile := preload("res://scripts/ui/StarRailTile.gd")
const _VoStream := preload("res://scripts/content/VoStream.gd")

const RAIL_VO_DIR := "res://assets/audio/vo/star_rail"

const RAIL_W := 190.0
const BORDER_W := 6.0
const TILE_MARGIN := 8.0
const REVEAL_SECONDS := 5.0  # auto re-occlude after this long with no interaction

const SILVER := Color(0.83, 0.83, 0.9, 1.0)
const SOIL := Color(0.55, 0.39, 0.24, 1.0)        # bright, inviting dirt (occluded)
const SOIL_DARK := Color(0.34, 0.24, 0.15, 1.0)   # recedes behind revealed tiles
const HINT := Color(1.0, 0.86, 0.4, 0.32)         # faint "there are stars here" glow

# Action codes returned by the tap handlers (also handy for tests).
const ACT_GUIDANCE := "guidance"
const ACT_ARMED := "armed"
const ACT_VIDEO := "video"
const ACT_VIDEO_UNAVAILABLE := "video_unavailable"
const ACT_BLOCKED := "blocked"
const ACT_REVEALED := "revealed"
const ACT_KEPT := "kept"

var model: StarRailModel
var video_arm: DoubleTapArm
var revealed: bool = false
var tiles: Dictionary = {}  ## star_id -> StarRailTile

var _root: Control
var _left_col: Control
var _right_col: Control
var _left_soil: ColorRect
var _right_soil: ColorRect
var _left_rail: VBoxContainer
var _right_rail: VBoxContainer
var _hints: Array = []
var _voice: AudioStreamPlayer
var _reveal_until: float = 0.0
var _intro_hold: bool = false
var _built: bool = false

func _ready() -> void:
	layer = 12  # above world + HUD (10), below VideoPanel (20)
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("landscape_shell")
	build()

func build() -> void:
	if _built:
		return
	_built = true
	model = _Model.new()
	video_arm = _Arm.new(1.0)
	revealed = false

	_voice = AudioStreamPlayer.new()
	_voice.name = "RailVoice"
	_voice.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_voice)

	_build_layout()
	_build_rail(_Layout.left_ids(), _left_rail)
	_build_rail(_Layout.right_ids(), _right_rail)
	refresh()
	occlude(false)  # always start tucked under the soil

	if not Events.star_collected.is_connected(_on_star_collected):
		Events.star_collected.connect(_on_star_collected)

func _build_layout() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE  # center taps fall through to the world
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	_left_col = _make_column("LeftColumn", true)
	_right_col = _make_column("RightColumn", false)

	_left_soil = _make_soil("LeftSoil", _left_col)
	_right_soil = _make_soil("RightSoil", _right_col)

	_hints.append(_make_hint("LeftHint", _left_col))
	_hints.append(_make_hint("RightHint", _right_col))

	_left_rail = _make_rail("LeftRail", _left_col)
	_right_rail = _make_rail("RightRail", _right_col)

	_make_border("LeftBorder", true)
	_make_border("RightBorder", false)

func _make_column(col_name: String, is_left: bool) -> Control:
	var c := Control.new()
	c.name = col_name
	c.mouse_filter = Control.MOUSE_FILTER_STOP  # rails own their gutter; no world taps here
	c.anchor_top = 0.0
	c.anchor_bottom = 1.0
	if is_left:
		c.anchor_left = 0.0
		c.anchor_right = 0.0
		c.offset_left = 0.0
		c.offset_right = RAIL_W
	else:
		c.anchor_left = 1.0
		c.anchor_right = 1.0
		c.offset_left = -RAIL_W
		c.offset_right = 0.0
	c.offset_top = 0.0
	c.offset_bottom = 0.0
	c.gui_input.connect(_on_column_gui_input)
	_root.add_child(c)
	return c

func _make_soil(soil_name: String, parent: Control) -> ColorRect:
	var soil := ColorRect.new()
	soil.name = soil_name
	soil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	soil.color = SOIL
	soil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(soil)
	return soil

func _make_hint(hint_name: String, parent: Control) -> Label:
	# Faint stacked stars so a child can tell the soil is "tap-able" while occluded.
	var l := Label.new()
	l.name = hint_name
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.text = "★\n★\n★"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 34)
	l.add_theme_color_override("font_color", HINT)
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(l)
	return l

func _make_rail(rail_name: String, parent: Control) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.name = rail_name
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE  # gaps pass to the column bg (reveal/keep)
	v.add_theme_constant_override("separation", int(TILE_MARGIN))
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = TILE_MARGIN
	v.offset_top = TILE_MARGIN
	v.offset_right = -TILE_MARGIN
	v.offset_bottom = -TILE_MARGIN
	parent.add_child(v)
	return v

func _make_border(border_name: String, is_left: bool) -> void:
	var b := ColorRect.new()
	b.name = border_name
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.color = SILVER
	b.anchor_top = 0.0
	b.anchor_bottom = 1.0
	if is_left:
		b.anchor_left = 0.0
		b.anchor_right = 0.0
		b.offset_left = RAIL_W
		b.offset_right = RAIL_W + BORDER_W
	else:
		b.anchor_left = 1.0
		b.anchor_right = 1.0
		b.offset_left = -RAIL_W - BORDER_W
		b.offset_right = -RAIL_W
	b.offset_top = 0.0
	b.offset_bottom = 0.0
	_root.add_child(b)

func _build_rail(ids: PackedStringArray, rail: VBoxContainer) -> void:
	for id in ids:
		var tile: StarRailTile = _Tile.new()
		tile.setup(id, _load_icon(model.icon_path(id)))
		tile.tapped.connect(_on_tile_tapped)
		rail.add_child(tile)
		tiles[id] = tile

func _load_icon(path: String) -> Texture2D:
	# Raw-load so a fresh PNG works before `godot --import` runs (VoStream philosophy).
	if path.is_empty():
		return null
	if ResourceLoader.exists(path):
		var res: Resource = load(path)
		if res is Texture2D:
			return res as Texture2D
	if FileAccess.file_exists(path):
		var img := Image.new()
		if img.load(path) == OK:
			return ImageTexture.create_from_image(img)
	return null

func refresh() -> void:
	if model == null:
		return
	for id in tiles:
		var tile: StarRailTile = tiles[id]
		tile.set_state(model.tile_state(id), false)

func _process(_delta: float) -> void:
	tick(_now())

func _now() -> float:
	return float(Time.get_ticks_msec()) / 1000.0

## Drives the arm timeout + auto re-occlusion. Extracted from _process for tests.
func tick(now: float) -> void:
	if video_arm != null:
		video_arm.poll(now)
	if _intro_hold:
		return  # intro narration owns the reveal until it releases
	if revealed and not _video_is_open() and now >= _reveal_until:
		occlude(true)

# --- intro choreography -----------------------------------------------------
## Reveal + hold the rails open while the intro narration explains them (auto
## re-occlude is suspended until end_intro_hold()).
func begin_intro_hold() -> void:
	_intro_hold = true
	reveal(_now())

## Release the intro hold and tuck the rails back under the soil.
func end_intro_hold() -> void:
	_intro_hold = false
	occlude(true)

# --- reveal / occlude -------------------------------------------------------

func _bump_reveal(now: float) -> void:
	_reveal_until = now + REVEAL_SECONDS

## Brighten the rails and make tiles clickable. If already revealed, just keep
## them up (resets the auto-occlude timer).
func reveal(now: float) -> void:
	_bump_reveal(now)
	if revealed:
		return
	revealed = true
	_set_tiles_interactive(true)
	_set_hints_visible(false)
	if _left_soil:
		_left_soil.color = SOIL_DARK
	if _right_soil:
		_right_soil.color = SOIL_DARK
	for rail in [_left_rail, _right_rail]:
		if rail == null:
			continue
		rail.visible = true
		rail.modulate.a = 0.0
		var tw := create_tween()
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)  # animate during the paused intro
		tw.tween_property(rail, "modulate:a", 1.0, 0.2)

## Slide the rails back under the soil.
func occlude(animate: bool) -> void:
	revealed = false
	_set_tiles_interactive(false)
	_set_hints_visible(true)
	if video_arm:
		video_arm.clear()
	if _left_soil:
		_left_soil.color = SOIL
	if _right_soil:
		_right_soil.color = SOIL
	for rail in [_left_rail, _right_rail]:
		if rail == null:
			continue
		if animate and rail.visible:
			var tw := create_tween()
			tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			tw.tween_property(rail, "modulate:a", 0.0, 0.3)
			tw.tween_callback(rail.hide)
		else:
			rail.modulate.a = 0.0
			rail.visible = false

func _set_tiles_interactive(on: bool) -> void:
	var mf := Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE
	for id in tiles:
		(tiles[id] as Control).mouse_filter = mf

func _set_hints_visible(on: bool) -> void:
	for h in _hints:
		if h != null:
			(h as Control).visible = on

# --- taps -------------------------------------------------------------------

func _on_column_gui_input(event: InputEvent) -> void:
	if _is_press(event):
		_handle_side_touch(_now())

func _on_tile_tapped(star_id: String) -> void:
	_handle_tile_tap(star_id, _now())

func _is_press(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		return mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	return false

## Touch on a side column. Reveals when occluded; otherwise keeps it up.
## Returns an ACT_* code (also used by tests).
func _handle_side_touch(now: float) -> String:
	if _video_is_open():
		return ACT_BLOCKED
	if not revealed:
		reveal(now)
		return ACT_REVEALED
	_bump_reveal(now)
	return ACT_KEPT

## Tap on a star tile. While occluded, the first tap only reveals (never fires an
## action). While revealed: undiscovered → guidance VO; collected → arm, then a
## second tap within 1 s plays the video. Any tap keeps the rails up.
func _handle_tile_tap(star_id: String, now: float) -> String:
	if _video_is_open():
		return ACT_BLOCKED
	if not revealed:
		reveal(now)
		return ACT_REVEALED
	_bump_reveal(now)
	if model.tile_state(star_id) == _Model.TILE_UNDISCOVERED:
		video_arm.clear()
		_speak_guidance(star_id)
		return ACT_GUIDANCE
	var result: String = video_arm.press(star_id, now)
	if result == _Arm.RESULT_TRIGGER:
		return _play_video(star_id)
	_speak_watch_prompt(star_id)
	return ACT_ARMED

# --- collection feedback ----------------------------------------------------

func _on_star_collected(star_id: String) -> void:
	if tiles.has(star_id):
		var tile: StarRailTile = tiles[star_id]
		tile.set_state(_Model.TILE_COLLECTED, true)

# --- video ------------------------------------------------------------------

func _video_is_open() -> bool:
	var panel := _video_panel()
	return panel != null and panel.has_method("is_open") and bool(panel.call("is_open"))

func _video_panel() -> CanvasLayer:
	if get_tree() == null:
		return null
	return get_tree().get_first_node_in_group("video_panel") as CanvasLayer

func _play_video(star_id: String) -> String:
	var panel := _video_panel()
	if panel != null and panel.has_method("play_star"):
		var file: String = model.file_for(star_id)
		if bool(panel.call("play_star", star_id, file)):
			occlude(false)  # video covers everything; rails come back occluded after
			return ACT_VIDEO
	push_warning("LandscapeShell: video unavailable for %s" % star_id)
	return ACT_VIDEO_UNAVAILABLE

# --- voice ------------------------------------------------------------------

func _speak_guidance(star_id: String) -> void:
	var line: String = model.guidance_line(star_id)
	print("Rail guidance [%s]: %s" % [star_id, line])
	var wav: String = _VoStream.resolve_vo(RAIL_VO_DIR, star_id)
	var stream: AudioStream = _VoStream.load_path(wav) if not wav.is_empty() else null
	_speak(stream, line)

func _speak_watch_prompt(star_id: String) -> void:
	var line: String = model.watch_prompt(star_id)
	print("Rail prompt [%s]: %s" % [star_id, line])
	_speak(null, line)

func _speak(stream: AudioStream, tts_text: String) -> void:
	if _voice != null and _voice.playing:
		_voice.stop()
	if stream != null and _voice != null:
		_voice.stream = stream
		_voice.play()
		return
	if DisplayServer.tts_get_voices().size() > 0:
		DisplayServer.tts_stop()
		DisplayServer.tts_speak(tts_text, "", 1.0, 1.0, 0.95)

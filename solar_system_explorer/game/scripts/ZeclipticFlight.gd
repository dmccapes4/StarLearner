class_name ZeclipticFlight
extends Control
## Zecliptic Flight — free-fly the real solar system in Sol's equatorial frame.
##
## Everything positional comes from ZeclipticBodies (data/zecliptic_bodies.json).
## The camera is the floating origin: every body is placed at
## (body - camera) / KM_PER_UNIT each frame, so a camera standing on Charon
## sees Pluto at 18 scene units, not at 5.9 million.
##
## Controls are listed in _help_text() and in docs/ZECLIPTIC_FLIGHT_20261011/GAME_PLAN.md.

signal go_home()

const KM_PER_UNIT := 1000.0
const GOLD := Color(1.0, 0.86, 0.28)
const DIM := Color(0.72, 0.78, 0.95)
const PANEL_BG := Color(0.03, 0.04, 0.09, 0.86)

enum Cam { FREE, ORBIT, SURFACE }

## sim days per real second
const RATES: Array = [
	["paused", 0.0], ["real time", 1.0 / 86400.0], ["1 min / s", 1.0 / 1440.0], ["1 hour / s", 1.0 / 24.0],
	["6 hours / s", 0.25], ["1 day / s", 1.0], ["1 week / s", 7.0], ["1 month / s", 30.436875],
	["1 year / s", 365.25636], ["10 years / s", 3652.5636], ["1 Pluto year / min", 90560.0 / 60.0]]
const SPEEDS: Array = [   # free-fly km per real second
	["1 km/s", 1.0], ["100 km/s", 100.0], ["1 R\u2609/s", 695700.0], ["1 Luna-dist/s", 384400.0],
	["1 AU/s", 1.495978707e8], ["10 AU/s", 1.495978707e9], ["auto", -1.0]]
const SIZE_SCALES: Array = [1.0, 10.0, 100.0, 1000.0]
const FRAMES: Array = ["zecliptic", "ecliptic", "invariable", "body"]
const LANDING_SPOTS: Array = ["north pole", "arctic circle", "tropic (N)", "equator", "tropic (S)",
	"antarctic circle", "south pole", "subsolar", "antisolar", "sub-primary", "custom"]

# ── state ──────────────────────────────────────────────────────────────
var jd: float = 2461319.5         # 2026-10-11 00:00 UTC
var epoch_jd: float = 2461319.5   # Pis clocks count from here
var rate_idx: int = 5
var reverse: bool = false
var paused_by_tap: bool = false
var frame_id: String = "zecliptic"
var frame_body: String = "earth"
var ref_id: String = "sol"
var cam_mode: int = Cam.FREE
var cam_pos: Vector3 = Vector3.ZERO    # km, ref-relative, frame-godot axes
var yaw: float = 0.0
var pitch: float = 0.0
var speed_idx: int = 4
var orbit_target: String = "earth"
var orbit_dist_km: float = 30000.0
var orbit_az: float = 0.6
var orbit_el: float = 0.25
var surf_body: String = "charon"
var surf_lat: float = 0.0
var surf_lon: float = 0.0
var surf_eye_km: float = 0.002
var surf_spot_idx: int = 9
var look_target: String = ""            # "" = free look
var size_idx: int = 0
var dist_log: bool = false
var alpha: Dictionary = {}              # id -> 0..1
var hidden_ids: Dictionary = {}             # id -> true
var selected: String = ""
var exposure: float = 1.0
var overlays: Dictionary = {
	"orbits": true, "moon_orbits": true, "labels": true, "markers": true, "axes": false, "equators": false,
	"tropics": false, "grid": true, "nodes": false, "hill": false, "annulus": false, "belt": true, "belt_big": true,
	"heliobarrier": false, "trails": false, "light_time": false, "glare": true, "sol_equator_disc": true,
	"readouts": true, "frame_banner": true}
var bookmarks: Dictionary = {}
var _trail: Dictionary = {}             # id -> PackedVector3Array of ref-rel km samples
var _trail_t: float = 0.0

# ── nodes ──────────────────────────────────────────────────────────────
var _vp_container: SubViewportContainer
var _vp: SubViewport
var _world: Node3D
var _cam: Camera3D
var _light: DirectionalLight3D
var _env: WorldEnvironment
var _body_nodes: Dictionary = {}        # id -> MeshInstance3D
var _body_mats: Dictionary = {}         # id -> StandardMaterial3D
var _ring_nodes: Dictionary = {}        # id -> MeshInstance3D (Saturn ring)
var _aux_nodes: Dictionary = {}         # id -> MeshInstance3D (axis + equator + tropics, ImmediateMesh)
var _hill_nodes: Dictionary = {}
var _orbit_mesh: MeshInstance3D
var _orbit_im: ImmediateMesh
var _moon_orbit_mesh: MeshInstance3D
var _moon_orbit_im: ImmediateMesh
var _grid_mesh: MeshInstance3D
var _annulus_mesh: MeshInstance3D
var _annulus_im: ImmediateMesh
var _helio_mesh: MeshInstance3D
var _trail_mesh: MeshInstance3D
var _trail_im: ImmediateMesh
var _belt_mm: MultiMeshInstance3D
var _overlay: Control                   # 2D markers/labels drawn over the viewport
var _hud: Control
var _readout: Label
var _banner: Label
var _timebar: Label
var _card: PanelContainer
var _card_text: RichTextLabel
var _panel: PanelContainer
var _help: PanelContainer
var _help_text_lbl: RichTextLabel
var _back: Button
var _menu_btn: Button
var _msg: Label
var _msg_t: float = 0.0
var _ids: Array = []
var _planet_ids: Array = []
var _asteroid_ids: Array = []
var _rel_cache: Dictionary = {}         # id -> Vector3 km, ref-relative, godot axes (this frame)
var _fb: Basis = Basis.IDENTITY         # ecliptic -> frame
var _orbit_rebuild_t: float = 0.0
var _belt_tick: int = 0
var _touch_pts: Dictionary = {}
var _tap_down_pos: Vector2 = Vector2.ZERO
var _tap_down_t: float = 0.0
var _drag_mode: int = 0                 # 0 none, 1 look, 2 move
var _move_vec: Vector2 = Vector2.ZERO
var _keys: Dictionary = {}
var _active: bool = false
var _frames_rendered: int = 0

# ────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_ids = ZeclipticBodies.ids_by_distance()
	for id in _ids:
		var b := ZeclipticBodies.body(id)
		if b.get("parent", null) == "sol":
			if b.has("elements"):
				_planet_ids.append(id)
			elif b.has("sbdb"):
				_asteroid_ids.append(id)
	_build_world()
	_build_hud()
	_apply_preset_charon_pluto()
	set_active(false)

func set_active(on: bool) -> void:
	_active = on
	visible = on
	set_process(on)
	set_process_input(on)
	set_process_unhandled_input(on)
	if _vp != null:
		_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED

# ── world ───────────────────────────────────────────────────────────────
func _build_world() -> void:
	_vp_container = SubViewportContainer.new()
	_vp_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vp_container.stretch = true
	_vp_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_vp_container)
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.size = Vector2i(1280, 600)
	_vp.msaa_3d = Viewport.MSAA_2X
	_vp_container.add_child(_vp)
	_world = Node3D.new()
	_vp.add_child(_world)

	_env = WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.0, 0.0, 0.004)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.06, 0.07, 0.1)
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = exposure
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.05
	_env.environment = env
	_world.add_child(_env)

	_cam = Camera3D.new()
	_cam.fov = 60.0
	_cam.near = 0.001
	_cam.far = 1.0e7
	_world.add_child(_cam)

	_light = DirectionalLight3D.new()
	_light.light_energy = 1.4
	_light.shadow_enabled = false
	_world.add_child(_light)

	for id in _ids:
		_make_body(id)

	_orbit_im = ImmediateMesh.new()
	_orbit_mesh = _line_node(_orbit_im, Color(0.45, 0.55, 0.8, 0.55))
	_moon_orbit_im = ImmediateMesh.new()
	_moon_orbit_mesh = _line_node(_moon_orbit_im, Color(0.6, 0.75, 0.9, 0.5))
	_annulus_im = ImmediateMesh.new()
	_annulus_mesh = _line_node(_annulus_im, Color(1.0, 0.55, 0.25, 0.8))
	_trail_im = ImmediateMesh.new()
	_trail_mesh = _line_node(_trail_im, Color(1.0, 0.9, 0.5, 0.6))
	_grid_mesh = _line_node(_build_grid_mesh(), Color(0.55, 0.5, 0.25, 0.35))
	_helio_mesh = _line_node(_build_sphere_wire(1.0, 48), Color(0.4, 0.8, 1.0, 0.35))

	_belt_mm = MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 6
	sm.rings = 3
	mm.mesh = sm
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0.6, 0.55, 0.5)
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.material = bm
	mm.instance_count = ZeclipticBodies.data()["belt"]["sample"].size()
	_belt_mm.multimesh = mm
	_world.add_child(_belt_mm)

func _line_node(mesh: Mesh, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = false
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	_world.add_child(mi)
	return mi

func _make_body(id: String) -> void:
	var b := ZeclipticBodies.body(id)
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 48 if b.get("kind") in ["planet", "star", "dwarf"] else 24
	sm.rings = 24 if b.get("kind") in ["planet", "star", "dwarf"] else 12
	mi.mesh = sm
	var mat := StandardMaterial3D.new()
	var skin_id := id if id != "sol" else "sun"
	var tex := PlanetSkins.texture_for(skin_id)
	if tex != null:
		mat.albedo_texture = tex
		mat.albedo_color = Color(1, 1, 1)
	else:
		mat.albedo_color = _fallback_color(id)
	mat.roughness = 1.0
	mat.metallic = 0.0
	if id == "sol":
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.85, 0.4)
		mat.emission_energy_multiplier = 1.6
	mi.material_override = mat
	_body_nodes[id] = mi
	_body_mats[id] = mat
	_world.add_child(mi)
	if id == "saturn":
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 1.24     # in planet radii: D ring ~1.11 to A ring ~2.27
		tm.outer_radius = 2.27
		tm.rings = 96
		tm.ring_segments = 4
		ring.mesh = tm
		var rm := StandardMaterial3D.new()
		rm.albedo_color = Color(0.85, 0.78, 0.62, 0.7)
		rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		rm.cull_mode = BaseMaterial3D.CULL_DISABLED
		ring.material_override = rm
		_world.add_child(ring)
		_ring_nodes[id] = ring
	var aux := MeshInstance3D.new()
	aux.mesh = ImmediateMesh.new()
	var am := StandardMaterial3D.new()
	am.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	am.vertex_color_use_as_albedo = true
	am.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	aux.material_override = am
	_world.add_child(aux)
	_aux_nodes[id] = aux
	if b.get("hill_radius_km") != null:
		var hn := MeshInstance3D.new()
		hn.mesh = _build_sphere_wire(1.0, 24)
		var hm := StandardMaterial3D.new()
		hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		hm.albedo_color = Color(0.3, 0.9, 0.5, 0.25)
		hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		hn.material_override = hm
		hn.visible = false
		_world.add_child(hn)
		_hill_nodes[id] = hn

func _fallback_color(id: String) -> Color:
	var fb := SolarData.flyer_body_by_id(id if id != "sol" else "sun")
	if not fb.is_empty():
		return fb.get("color", Color(0.7, 0.7, 0.7))
	var k := str(ZeclipticBodies.body(id).get("kind", ""))
	if k == "moon":
		return Color(0.62, 0.62, 0.66)
	if k == "asteroid":
		return Color(0.55, 0.5, 0.45)
	return Color(0.7, 0.7, 0.7)

func _build_sphere_wire(r: float, n: int) -> ImmediateMesh:
	var im := ImmediateMesh.new()
	for ring in 3:
		im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		for k in n + 1:
			var a := TAU * float(k) / float(n)
			var p: Vector3
			match ring:
				0: p = Vector3(cos(a), 0, sin(a))
				1: p = Vector3(cos(a), sin(a), 0)
				_: p = Vector3(0, cos(a), sin(a))
			im.surface_add_vertex(p * r)
		im.surface_end()
	return im

func _build_grid_mesh() -> ImmediateMesh:
	## Rings at 0.1, 0.5, 1..10 AU and every 10 AU to 50, plus 12 spokes; frame XZ plane; units.
	var im := ImmediateMesh.new()
	var au := ZeclipticBodies.AU_KM / KM_PER_UNIT
	var radii: Array = [0.1, 0.25, 0.5, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 20, 30, 40, 50]
	for r in radii:
		im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		for k in 181:
			var a := TAU * float(k) / 180.0
			im.surface_add_vertex(Vector3(cos(a), 0, sin(a)) * float(r) * au)
		im.surface_end()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for k in 12:
		var a := TAU * float(k) / 12.0
		im.surface_add_vertex(Vector3.ZERO)
		im.surface_add_vertex(Vector3(cos(a), 0, sin(a)) * 50.0 * au)
	im.surface_end()
	return im

# ── HUD ─────────────────────────────────────────────────────────────────
func _build_hud() -> void:
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)

	_hud = Control.new()
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hud)

	_back = Button.new()
	_back.text = "\u25C0"
	_back.size = Vector2(64, 50)
	_back.position = Vector2(14, 14)
	_back.focus_mode = Control.FOCUS_NONE
	_style_button(_back, Color(0.9, 0.75, 0.2))
	_back.pressed.connect(func(): go_home.emit())
	_hud.add_child(_back)

	_menu_btn = Button.new()
	_menu_btn.text = "\u2630 controls"
	_menu_btn.size = Vector2(140, 50)
	_menu_btn.position = Vector2(86, 14)
	_menu_btn.focus_mode = Control.FOCUS_NONE
	_style_button(_menu_btn, Color(0.2, 0.3, 0.55))
	_menu_btn.pressed.connect(func(): _panel.visible = not _panel.visible)
	_hud.add_child(_menu_btn)

	var help_btn := Button.new()
	help_btn.text = "?"
	help_btn.size = Vector2(50, 50)
	help_btn.position = Vector2(234, 14)
	help_btn.focus_mode = Control.FOCUS_NONE
	_style_button(help_btn, Color(0.2, 0.3, 0.55))
	help_btn.pressed.connect(func(): _help.visible = not _help.visible)
	_hud.add_child(help_btn)

	_banner = Label.new()
	_banner.position = Vector2(300, 18)
	_banner.size = Vector2(680, 44)
	_banner.add_theme_font_size_override("font_size", 15)
	_banner.add_theme_color_override("font_color", GOLD)
	_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hud.add_child(_banner)

	_readout = Label.new()
	_readout.position = Vector2(1280 - 420, 70)
	_readout.size = Vector2(406, 420)
	_readout.add_theme_font_size_override("font_size", 13)
	_readout.add_theme_color_override("font_color", Color(0.9, 0.93, 1.0))
	_readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hud.add_child(_readout)

	_timebar = Label.new()
	_timebar.position = Vector2(14, 600 - 58)
	_timebar.size = Vector2(1252, 48)
	_timebar.add_theme_font_size_override("font_size", 16)
	_timebar.add_theme_color_override("font_color", Color(1, 1, 1))
	_hud.add_child(_timebar)

	_msg = Label.new()
	_msg.position = Vector2(300, 600 - 100)
	_msg.size = Vector2(680, 36)
	_msg.add_theme_font_size_override("font_size", 18)
	_msg.add_theme_color_override("font_color", GOLD)
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud.add_child(_msg)

	_build_card()
	_build_panel()
	_build_help()

func _style_button(b: Button, tint: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = tint
	sb.set_corner_radius_all(12)
	b.add_theme_stylebox_override("normal", sb)
	var h := sb.duplicate() as StyleBoxFlat
	h.bg_color = tint.lightened(0.15)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", h)
	b.add_theme_stylebox_override("focus", sb)
	b.add_theme_color_override("font_color", Color(1, 1, 1))
	b.add_theme_font_size_override("font_size", 18)

func _small_button(text: String, cb: Callable, tint: Color = Color(0.18, 0.24, 0.42)) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 34)
	_style_button(b, tint)
	b.add_theme_font_size_override("font_size", 14)
	b.pressed.connect(cb)
	return b

func _build_card() -> void:
	_card = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.set_corner_radius_all(14)
	sb.border_color = GOLD
	sb.set_border_width_all(2)
	sb.content_margin_left = 14; sb.content_margin_right = 14; sb.content_margin_top = 10; sb.content_margin_bottom = 10
	_card.add_theme_stylebox_override("panel", sb)
	_card.position = Vector2(1280 - 430, 70)
	_card.size = Vector2(416, 440)
	_card.visible = false
	_hud.add_child(_card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_card.add_child(v)
	_card_text = RichTextLabel.new()
	_card_text.bbcode_enabled = true
	_card_text.fit_content = true
	_card_text.custom_minimum_size = Vector2(380, 150)
	_card_text.add_theme_font_size_override("normal_font_size", 13)
	_card_text.add_theme_font_size_override("bold_font_size", 15)
	v.add_child(_card_text)
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 6)
	g.add_theme_constant_override("v_separation", 6)
	v.add_child(g)
	g.add_child(_small_button("Teleport", func(): _teleport(selected), Color(0.6, 0.45, 0.1)))
	g.add_child(_small_button("Orbit cam", func(): _enter_orbit(selected)))
	g.add_child(_small_button("Land", func(): _land(selected, surf_spot_idx)))
	g.add_child(_small_button("Set reference", func(): _set_reference(selected)))
	g.add_child(_small_button("Look-at target", func(): _set_look_target(selected)))
	g.add_child(_small_button("Equator frame", func(): _set_frame("body", selected)))
	g.add_child(_small_button("Transparent", func(): _toggle_alpha(selected)))
	g.add_child(_small_button("Hide/show", func(): _toggle_hidden(selected)))
	g.add_child(_small_button("Resume time", func(): _resume_time(), Color(0.15, 0.45, 0.25)))
	var spots := OptionButton.new()
	for s in LANDING_SPOTS:
		spots.add_item(s)
	spots.selected = surf_spot_idx
	spots.item_selected.connect(func(i): surf_spot_idx = i)
	spots.focus_mode = Control.FOCUS_NONE
	v.add_child(spots)
	var row := HBoxContainer.new()
	v.add_child(row)
	var lat := SpinBox.new(); lat.min_value = -90; lat.max_value = 90; lat.step = 0.5; lat.value = surf_lat; lat.prefix = "lat"
	lat.value_changed.connect(_on_lat_changed)
	var lon := SpinBox.new(); lon.min_value = -180; lon.max_value = 360; lon.step = 1.0; lon.value = surf_lon; lon.prefix = "lon"
	lon.value_changed.connect(_on_lon_changed)
	row.add_child(lat); row.add_child(lon)
	var close := _small_button("close", func(): _card.visible = false)
	v.add_child(close)

func _build_panel() -> void:
	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 10; sb.content_margin_right = 10; sb.content_margin_top = 8; sb.content_margin_bottom = 8
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.position = Vector2(14, 70)
	_panel.size = Vector2(400, 470)
	_panel.visible = false
	_hud.add_child(_panel)
	var tabs := TabContainer.new()
	tabs.add_theme_font_size_override("font_size", 14)
	_panel.add_child(tabs)

	# — Nav —
	var nav := _tab(tabs, "Nav")
	var hop := OptionButton.new()
	for id in _ids:
		hop.add_item(_name(id))
	hop.add_item("barycentre (Sol+planets)")
	hop.item_selected.connect(_on_hop_selected)
	hop.focus_mode = Control.FOCUS_NONE
	nav.add_child(_lbl("Hop to (teleport):"))
	nav.add_child(hop)
	var hrow := HBoxContainer.new()
	hrow.add_child(_small_button("\u25C0 prev body", func(): _hop(-1)))
	hrow.add_child(_small_button("next body \u25B6", func(): _hop(1)))
	hrow.add_child(_small_button("Sol", func(): _select("sol", false); _teleport("sol")))
	nav.add_child(hrow)
	nav.add_child(_lbl("Free-fly speed:"))
	var sp := OptionButton.new()
	for s in SPEEDS:
		sp.add_item(s[0])
	sp.selected = speed_idx
	sp.item_selected.connect(func(i): speed_idx = i)
	sp.focus_mode = Control.FOCUS_NONE
	nav.add_child(sp)
	var crow := HBoxContainer.new()
	crow.add_child(_small_button("Free cam", func(): _to_free()))
	crow.add_child(_small_button("Orbit selected", func(): _enter_orbit(selected)))
	crow.add_child(_small_button("Lift off", func(): _lift_off()))
	nav.add_child(crow)
	var lrow := HBoxContainer.new()
	lrow.add_child(_small_button("Clear look-at", func(): look_target = ""; _say("free look")))
	lrow.add_child(_small_button("Look at Sol", func(): _set_look_target("sol")))
	lrow.add_child(_small_button("Reset view", func(): _apply_preset_charon_pluto()))
	nav.add_child(lrow)
	nav.add_child(_lbl("Presets:"))
	var prow := HBoxContainer.new()
	prow.add_child(_small_button("Charon \u2192 Pluto", func(): _apply_preset_charon_pluto(), Color(0.5, 0.35, 0.1)))
	prow.add_child(_small_button("Sol equator \u2192 Charon", func(): _apply_preset_sol_charon(), Color(0.5, 0.35, 0.1)))
	nav.add_child(prow)
	var prow2 := HBoxContainer.new()
	prow2.add_child(_small_button("Luna \u2192 Earth", func(): _apply_preset_luna_earth(), Color(0.5, 0.35, 0.1)))
	prow2.add_child(_small_button("Mercury annulus", func(): _apply_preset_mercury(), Color(0.5, 0.35, 0.1)))
	prow2.add_child(_small_button("Above the Zecliptic", func(): _apply_preset_overview(), Color(0.5, 0.35, 0.1)))
	nav.add_child(prow2)

	# — Time —
	var tm := _tab(tabs, "Time")
	tm.add_child(_lbl("Rate:"))
	var rt := OptionButton.new()
	for r in RATES:
		rt.add_item(r[0])
	rt.selected = rate_idx
	rt.item_selected.connect(func(i): rate_idx = i; paused_by_tap = false)
	rt.focus_mode = Control.FOCUS_NONE
	tm.add_child(rt)
	var trow := HBoxContainer.new()
	trow.add_child(_small_button("\u23EF pause/play", func(): _toggle_pause()))
	trow.add_child(_small_button("\u21C4 reverse", func(): reverse = not reverse))
	trow.add_child(_small_button("now", func(): _set_jd(_now_jd())))
	tm.add_child(trow)
	var srow := HBoxContainer.new()
	for step in [["-1 y", -365.25636], ["-1 mo", -30.44], ["-1 d", -1.0], ["+1 d", 1.0], ["+1 mo", 30.44], ["+1 y", 365.25636]]:
		var dd: float = step[1]
		srow.add_child(_small_button(step[0], func(): _set_jd(jd + dd)))
	tm.add_child(srow)
	var orow := HBoxContainer.new()
	orow.add_child(_small_button("+1 orbit of selected", func(): _set_jd(jd + ZeclipticBodies.period_d(selected))))
	orow.add_child(_small_button("+1 Pluto year", func(): _set_jd(jd + 90560.0)))
	orow.add_child(_small_button("epoch = now (Pis)", func(): epoch_jd = jd; _say("Pis clocks reset")))
	tm.add_child(orow)
	tm.add_child(_lbl("Date:"))
	var drow := HBoxContainer.new()
	var cal := ZeclipticBodies.calendar(jd)
	var yb := SpinBox.new(); yb.min_value = 1800; yb.max_value = 2050; yb.value = int(cal["year"]); yb.prefix = "y"
	var mb := SpinBox.new(); mb.min_value = 1; mb.max_value = 12; mb.value = int(cal["month"]); mb.prefix = "m"
	var db := SpinBox.new(); db.min_value = 1; db.max_value = 31; db.value = int(cal["day"]); db.prefix = "d"
	for sbx in [yb, mb, db]:
		sbx.value_changed.connect(func(_x): _set_jd(ZeclipticBodies.jd_from_ymd(int(yb.value), int(mb.value), float(db.value))))
	drow.add_child(yb); drow.add_child(mb); drow.add_child(db)
	tm.add_child(drow)
	tm.add_child(_lbl("Jump to event:"))
	var ev := OptionButton.new()
	for e in ZeclipticBodies.data().get("events", []):
		ev.add_item(str(e["label"]))
	ev.item_selected.connect(func(i):
		var e: Dictionary = ZeclipticBodies.data()["events"][i]
		var parts := str(e["date"]).split("-")
		_set_jd(ZeclipticBodies.jd_from_ymd(int(parts[0]), int(parts[1]), float(parts[2]))))
	ev.focus_mode = Control.FOCUS_NONE
	tm.add_child(ev)
	tm.add_child(_lbl("Standish elements are rated 1800–2050; outside that the planets drift, and the HUD says so."))

	# — Frame —
	var fr := _tab(tabs, "Frame")
	fr.add_child(_lbl("Reference plane (what 'up' and 'level' mean):"))
	var frow := HBoxContainer.new()
	frow.add_child(_small_button("Zecliptic", func(): _set_frame("zecliptic"), Color(0.5, 0.4, 0.1)))
	frow.add_child(_small_button("Ecliptic", func(): _set_frame("ecliptic")))
	frow.add_child(_small_button("Invariable", func(): _set_frame("invariable")))
	frow.add_child(_small_button("Selected's equator", func(): _set_frame("body", selected)))
	fr.add_child(frow)
	fr.add_child(_lbl("Reference body (the floating origin; with a planet here, Sol and the others trace epicycles):"))
	var rb := OptionButton.new()
	for id in _ids:
		rb.add_item(_name(id))
	rb.add_item("barycentre")
	rb.item_selected.connect(func(i): _set_reference(_ids[i] if i < _ids.size() else "bary"))
	rb.focus_mode = Control.FOCUS_NONE
	fr.add_child(rb)
	fr.add_child(_lbl("Distance scale:"))
	var drow2 := HBoxContainer.new()
	drow2.add_child(_small_button("real", func(): dist_log = false; _say("distances real")))
	drow2.add_child(_small_button("compressed (not to scale)", func(): dist_log = true; _say("distances compressed — NOT TO SCALE")))
	fr.add_child(drow2)
	fr.add_child(_lbl("Body size \u00d7 (centres fixed):"))
	var zrow := HBoxContainer.new()
	for k in SIZE_SCALES.size():
		var kk := k
		zrow.add_child(_small_button("\u00d7%d" % int(SIZE_SCALES[k]), func(): size_idx = kk; _say("body size \u00d7%d" % int(SIZE_SCALES[kk]))))
	fr.add_child(zrow)
	fr.add_child(_lbl("Exposure:"))
	var ex := HSlider.new(); ex.min_value = 0.2; ex.max_value = 4.0; ex.step = 0.05; ex.value = exposure
	ex.value_changed.connect(func(x): exposure = x; _env.environment.tonemap_exposure = x)
	fr.add_child(ex)
	fr.add_child(_lbl("Selected body alpha:"))
	var al := HSlider.new(); al.min_value = 0.0; al.max_value = 1.0; al.step = 0.05; al.value = 1.0
	al.value_changed.connect(func(x): if selected != "": alpha[selected] = x)
	fr.add_child(al)

	# — Overlays —
	var ov := _tab(tabs, "Overlays")
	var og := GridContainer.new()
	og.columns = 2
	ov.add_child(og)
	var names: Dictionary = {"orbits": "orbit lines", "moon_orbits": "moon orbits", "labels": "labels", "markers": "markers",
		"axes": "spin axes", "equators": "equator rings", "tropics": "tropics & polar circles", "grid": "plane grid (AU rings)",
		"nodes": "node markers", "hill": "Hill spheres", "annulus": "Mercury annulus", "belt": "belt sample (representative)",
		"belt_big": "belt big bodies", "heliobarrier": "heliobarrier (TS/HP)", "trails": "trails", "light_time": "light-time rings",
		"glare": "Sol glow", "sol_equator_disc": "Sol equator disc", "readouts": "readouts", "frame_banner": "frame banner"}
	for key in names:
		var cb := CheckButton.new()
		cb.text = names[key]
		cb.button_pressed = overlays[key]
		cb.add_theme_font_size_override("font_size", 13)
		cb.focus_mode = Control.FOCUS_NONE
		var kk := str(key)
		cb.toggled.connect(func(on): overlays[kk] = on)
		og.add_child(cb)

	# — Bookmarks —
	var bk := _tab(tabs, "Marks")
	bk.add_child(_lbl("Save / recall camera + time + frame (keys 1–9, Shift+key saves):"))
	var bg := GridContainer.new()
	bg.columns = 3
	bk.add_child(bg)
	for i in 9:
		var slot := i + 1
		var row := HBoxContainer.new()
		row.add_child(_small_button("save %d" % slot, func(): _save_mark(slot)))
		row.add_child(_small_button("go %d" % slot, func(): _go_mark(slot), Color(0.15, 0.4, 0.3)))
		bg.add_child(row)
	bk.add_child(_small_button("Screenshot \u2192 user://zecliptic/", func(): _screenshot()))

func _tab(tabs: TabContainer, title: String) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.name = title
	sc.custom_minimum_size = Vector2(370, 400)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	tabs.add_child(sc)
	return v

func _lbl(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", DIM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(360, 0)
	return l

func _build_help() -> void:
	_help = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 16; sb.content_margin_right = 16; sb.content_margin_top = 12; sb.content_margin_bottom = 12
	_help.add_theme_stylebox_override("panel", sb)
	_help.position = Vector2(420, 70)
	_help.size = Vector2(440, 470)
	_help.visible = false
	_hud.add_child(_help)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(408, 446)
	_help.add_child(sc)
	_help_text_lbl = RichTextLabel.new()
	_help_text_lbl.bbcode_enabled = true
	_help_text_lbl.fit_content = true
	_help_text_lbl.custom_minimum_size = Vector2(400, 0)
	_help_text_lbl.add_theme_font_size_override("normal_font_size", 12)
	_help_text_lbl.text = _help_text()
	sc.add_child(_help_text_lbl)

func _help_text() -> String:
	return """[b]Zecliptic Flight — controls[/b]
[b]Move[/b]  W/S forward-back · A/D strafe · Q/E down/up · Shift ×10 · wheel: speed · touch: drag left half
[b]Look[/b]  mouse drag (or arrows) · touch: drag right half · L: lock look at selected · K: clear
[b]Select[/b]  tap/click a body: pauses time, opens its card · N/P next/prev body · Esc closes
[b]Card[/b]  Teleport · Orbit cam (drag to orbit, wheel distance) · Land (pick spot: poles, tropics, equator, subsolar, sub-primary, custom lat/lon) · Set reference · Look-at · Equator frame · Transparent · Hide
[b]Time[/b]  Space pause · [ ] slower/faster · R reverse · , . ±1 day · < > ±1 year · 0 now · tap pauses, Resume on card
[b]Frame[/b]  F cycles Zecliptic → Ecliptic → Invariable → selected's equator · B sets reference body = selected · Z: Sol reference
[b]Scale[/b]  X body size ×1/10/100/1000 · C compressed distances (not to scale)
[b]Overlays[/b]  O orbits · G grid · I axes · U equators/tropics · J Hill · M annulus · V belt · T trails
[b]Marks[/b]  1–9 recall · Shift+1–9 save · F12 screenshot · H / ? this help · \u2630 the control panel
[b]Frame rule[/b]  Zecliptic (Sol's equator) unless a plane is named with a reason; the banner says which plane, which origin, and why.
[b]Honesty[/b]  Planets: Standish elements (1800–2050). Luna: Meeus. Other moons: real period and tilt, arbitrary phase (said on the card). Belt sample: representative, not real. Sizes real unless × is on. Distances real unless 'compressed' is on."""

# ── per-frame ───────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	if not _active:
		return
	var rate: float = RATES[rate_idx][1]
	if paused_by_tap:
		rate = 0.0
	if reverse:
		rate = -rate
	jd += rate * delta
	_fb = ZeclipticBodies.frame_basis(frame_id, frame_body)
	_rel_cache.clear()
	_move_camera(delta)
	_place_bodies()
	_update_lines(delta)
	_update_hud()
	_overlay.queue_redraw()
	_msg_t -= delta
	if _msg_t < 0:
		_msg.text = ""
	_frames_rendered += 1

## ref-relative km in frame-godot axes (with distance compression if on)
func _rel(id: String) -> Vector3:
	if _rel_cache.has(id):
		return _rel_cache[id]
	var v: Vector3
	if dist_log:
		v = _compressed(id) - _compressed(ref_id)
	else:
		var r := ZeclipticBodies.rel_ecl_km64(id, ref_id, jd)
		v = ZeclipticBodies.to_godot(_fb * Vector3(r[0], r[1], r[2]))
	_rel_cache[id] = v
	return v

func _compressed(id: String) -> Vector3:
	## heliocentric, frame-godot, with |r| -> 0.3 AU * (|r|/0.3 AU)^0.5 beyond 0.3 AU; moons keep real offsets.
	if id == "sol":
		return Vector3.ZERO
	var r := ZeclipticBodies.rel_ecl_km64(id, "sol", jd)
	var b := ZeclipticBodies.body(id)
	var base := Vector3(r[0], r[1], r[2])
	var off := Vector3.ZERO
	if b.get("kind", "") == "moon":
		off = ZeclipticBodies.moon_offset_ecl_km(id, jd)
		base -= off
	var L := base.length()
	var k := 0.3 * ZeclipticBodies.AU_KM
	if L > k:
		base = base.normalized() * (k * sqrt(L / k))
	return ZeclipticBodies.to_godot(_fb * (base + off))

func _body_basis_godot(id: String) -> Basis:
	var bb := ZeclipticBodies.body_basis_ecl(id, jd)      # columns: body x,y,z in ecliptic
	var x := ZeclipticBodies.to_godot(_fb * bb.x)
	var pole := ZeclipticBodies.to_godot(_fb * bb.z)
	var z := x.cross(pole).normalized()
	return Basis(x, pole, z)

func _radius_units(id: String) -> float:
	return ZeclipticBodies.radius_km(id) * SIZE_SCALES[size_idx] / KM_PER_UNIT

func _place_bodies() -> void:
	var sol_rel := _rel("sol")
	var min_surf := 1.0e12
	for id in _ids:
		var mi: MeshInstance3D = _body_nodes[id]
		var b := ZeclipticBodies.body(id)
		var vis := not hidden_ids.has(id)
		if b.get("kind", "") == "asteroid" and not overlays["belt_big"]:
			vis = false
		if cam_mode == Cam.SURFACE and id == surf_body and SIZE_SCALES[size_idx] > 1.0:
			pass  # keep the ground under your feet at its real size: handled below
		mi.visible = vis
		var rel := _rel(id)
		var p := (rel - cam_pos) / KM_PER_UNIT
		var ru := _radius_units(id)
		if cam_mode == Cam.SURFACE and id == surf_body:
			ru = ZeclipticBodies.radius_km(id) / KM_PER_UNIT
		var bas := _body_basis_godot(id)
		mi.transform = Transform3D(bas * Basis.from_scale(Vector3(ru, ru, ru)), p)
		var d := p.length() * KM_PER_UNIT
		min_surf = minf(min_surf, maxf(d - ZeclipticBodies.radius_km(id), 1.0e-3))
		var mat: StandardMaterial3D = _body_mats[id]
		var a: float = alpha.get(id, 1.0)
		if a < 0.999:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color.a = a
			mat.cull_mode = BaseMaterial3D.CULL_BACK
		else:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			mat.albedo_color.a = 1.0
		if id == "sol":
			mat.emission_energy_multiplier = 1.6 if overlays["glare"] else 0.6
		if _ring_nodes.has(id):
			var rn: MeshInstance3D = _ring_nodes[id]
			rn.visible = vis
			rn.transform = Transform3D(bas * Basis.from_scale(Vector3(ru, ru * 0.02, ru)), p)
		var aux: MeshInstance3D = _aux_nodes[id]
		aux.visible = vis and (overlays["axes"] or overlays["equators"] or overlays["tropics"]) and (id == selected or id == surf_body or id == orbit_target or id in _planet_ids)
		if aux.visible:
			aux.transform = Transform3D(bas, p)
			_draw_aux(id, aux.mesh as ImmediateMesh, ru)
		if _hill_nodes.has(id):
			var hn: MeshInstance3D = _hill_nodes[id]
			hn.visible = vis and overlays["hill"]
			if hn.visible:
				var hr := float(b["hill_radius_km"]) / KM_PER_UNIT
				hn.transform = Transform3D(Basis.IDENTITY.scaled(Vector3(hr, hr, hr)), p)
	# camera clip planes follow the nearest surface
	_cam.near = clampf(min_surf / KM_PER_UNIT * 0.05, 0.0005, 50.0)
	_cam.far = 1.0e7
	# light: from Sol toward the camera (parallel rays; good near the camera)
	var to_cam := -sol_rel + cam_pos
	if to_cam.length() > 1.0:
		_light.transform = Transform3D(Basis.looking_at(to_cam.normalized(), Vector3.UP if absf(to_cam.normalized().y) < 0.99 else Vector3.RIGHT), Vector3.ZERO)
	_light.light_energy = 1.4 * exposure if overlays["glare"] else 1.0
	# belt
	_belt_mm.visible = overlays["belt"]
	if _belt_mm.visible and _belt_tick % 2 == 0:
		var n := _belt_mm.multimesh.instance_count
		var sol_off := _rel("sol")
		var s := maxf(50.0 * SIZE_SCALES[size_idx] / KM_PER_UNIT, 0.02)
		for i in n:
			var pk := ZeclipticBodies.belt_pos_km(i, jd)
			var g := ZeclipticBodies.to_godot(_fb * pk) + sol_off - cam_pos
			_belt_mm.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3(s, s, s)), g / KM_PER_UNIT))
	_belt_tick += 1
	# grid & heliobarrier sit on Sol (the frame's origin)
	_grid_mesh.visible = overlays["grid"]
	_grid_mesh.transform = Transform3D(Basis.IDENTITY, (sol_rel - cam_pos) / KM_PER_UNIT)
	_helio_mesh.visible = overlays["heliobarrier"]
	if _helio_mesh.visible:
		var hp := float(ZeclipticBodies.data()["heliobarrier"]["heliopause_au"]["voyager1_2012_08_25"]) * ZeclipticBodies.AU_KM / KM_PER_UNIT
		_helio_mesh.transform = Transform3D(Basis.IDENTITY.scaled(Vector3(hp, hp, hp)), (sol_rel - cam_pos) / KM_PER_UNIT)

func _draw_aux(id: String, im: ImmediateMesh, ru: float) -> void:
	im.clear_surfaces()
	if overlays["axes"]:
		im.surface_begin(Mesh.PRIMITIVE_LINES)
		im.surface_set_color(Color(1, 0.4, 0.4, 0.9))
		im.surface_add_vertex(Vector3(0, -3.0 * ru, 0))
		im.surface_add_vertex(Vector3(0, 3.0 * ru, 0))
		im.surface_end()
	var rings: Array = []
	if overlays["equators"]:
		rings.append([0.0, Color(0.9, 0.9, 0.4, 0.8)])
	if overlays["tropics"]:
		var tl := ZeclipticBodies.tropic_lat_deg(id)
		var pl := ZeclipticBodies.polar_circle_lat_deg(id)
		for la in [tl, -tl]:
			rings.append([la, Color(0.4, 0.9, 0.9, 0.7)])
		for la in [pl, -pl]:
			rings.append([la, Color(0.6, 0.6, 1.0, 0.7)])
	for rg in rings:
		var la := deg_to_rad(float(rg[0]))
		im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		im.surface_set_color(rg[1])
		for k in 73:
			var a := TAU * float(k) / 72.0
			im.surface_add_vertex(Vector3(cos(la) * cos(a), sin(la), cos(la) * sin(a)) * ru * 1.003)
		im.surface_end()

func _update_lines(delta: float) -> void:
	_orbit_rebuild_t -= delta
	_orbit_mesh.visible = overlays["orbits"]
	if _orbit_mesh.visible:
		if _orbit_rebuild_t <= 0.0 or _orbit_im.get_surface_count() == 0:
			_orbit_rebuild_t = 2.0
			_rebuild_planet_orbits()
		_orbit_mesh.transform = Transform3D(Basis.IDENTITY, (_rel("sol") - cam_pos) / KM_PER_UNIT)
	_moon_orbit_mesh.visible = overlays["moon_orbits"]
	if _moon_orbit_mesh.visible:
		_rebuild_moon_orbits()
	_annulus_mesh.visible = overlays["annulus"]
	if _annulus_mesh.visible:
		_rebuild_annulus()
	_trail_mesh.visible = overlays["trails"]
	_trail_t += delta
	if overlays["trails"] and _trail_t > 0.1:
		_trail_t = 0.0
		for id in [selected, orbit_target, surf_body, look_target]:
			if id == "" or id == ref_id:
				continue
			if not _trail.has(id):
				_trail[id] = PackedVector3Array()
			var arr: PackedVector3Array = _trail[id]
			arr.append(_rel(id))
			if arr.size() > 600:
				arr.remove_at(0)
			_trail[id] = arr
		_trail_im.clear_surfaces()
		for id in _trail:
			var arr2: PackedVector3Array = _trail[id]
			if arr2.size() < 2:
				continue
			_trail_im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
			for q in arr2:
				_trail_im.surface_add_vertex((q - cam_pos) / KM_PER_UNIT)
			_trail_im.surface_end()
	elif not overlays["trails"] and not _trail.is_empty():
		_trail.clear()
		_trail_im.clear_surfaces()

func _rebuild_planet_orbits() -> void:
	_orbit_im.clear_surfaces()
	var ids := _planet_ids.duplicate()
	if overlays["belt_big"]:
		ids.append_array(_asteroid_ids)
	for id in ids:
		if hidden_ids.has(id):
			continue
		var per := ZeclipticBodies.period_d(id)
		var n := 256 if id in _planet_ids else 128
		_orbit_im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		for k in n + 1:
			var t := jd + per * float(k) / float(n)
			var p := ZeclipticBodies.helio_ecl_km(id, t)
			if dist_log:
				var L := p.length()
				var kk := 0.3 * ZeclipticBodies.AU_KM
				if L > kk:
					p = p.normalized() * (kk * sqrt(L / kk))
			_orbit_im.surface_add_vertex(ZeclipticBodies.to_godot(_fb * p) / KM_PER_UNIT)
		_orbit_im.surface_end()
	if overlays["nodes"]:
		# node markers: where each planet's orbit crosses the frame plane (y = 0)
		_orbit_im.surface_begin(Mesh.PRIMITIVE_LINES)
		for id in _planet_ids:
			var per := ZeclipticBodies.period_d(id)
			var prev := ZeclipticBodies.to_godot(_fb * ZeclipticBodies.helio_ecl_km(id, jd))
			for k in range(1, 361):
				var t := jd + per * float(k) / 360.0
				var cur := ZeclipticBodies.to_godot(_fb * ZeclipticBodies.helio_ecl_km(id, t))
				if (prev.y <= 0.0 and cur.y > 0.0) or (prev.y >= 0.0 and cur.y < 0.0):
					var m := (prev + cur) * 0.5 / KM_PER_UNIT
					var s := m.length() * 0.015
					_orbit_im.surface_add_vertex(m + Vector3(0, -s, 0))
					_orbit_im.surface_add_vertex(m + Vector3(0, s, 0))
				prev = cur
		_orbit_im.surface_end()

func _rebuild_moon_orbits() -> void:
	_moon_orbit_im.clear_surfaces()
	for id in _ids:
		var b := ZeclipticBodies.body(id)
		if b.get("kind", "") != "moon" or hidden_ids.has(id):
			continue
		var par := str(b["parent"])
		var pr := _rel(par)
		# only draw moons whose parent is within a sane distance (else they are sub-pixel)
		if (pr - cam_pos).length() > 400.0 * float(b["a_km"]):
			continue
		var per := absf(float(b["period_d"]))
		_moon_orbit_im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		for k in 97:
			var t := jd + per * float(k) / 96.0
			var off := ZeclipticBodies.moon_offset_ecl_km(id, t)
			_moon_orbit_im.surface_add_vertex((pr + ZeclipticBodies.to_godot(_fb * off) - cam_pos) / KM_PER_UNIT)
		_moon_orbit_im.surface_end()

func _rebuild_annulus() -> void:
	_annulus_im.clear_surfaces()
	var ann: Dictionary = ZeclipticBodies.data()["mercury_annulus_km"]
	var mr := _rel("mercury")
	var bas := _body_basis_godot("mercury")
	for key in ["inner_km_10km_body", "outer_km_prograde_this_run", "outer_km_retrograde_this_run"]:
		var r := float(ann[key])
		_annulus_im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		for k in 121:
			var a := TAU * float(k) / 120.0
			var local := Vector3(cos(a), 0, sin(a)) * r
			_annulus_im.surface_add_vertex((mr + bas * local - cam_pos) / KM_PER_UNIT)
		_annulus_im.surface_end()
	var hr := float(ZeclipticBodies.data()["mercury_hill_perihelion_km"])
	_annulus_im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for k in 121:
		var a := TAU * float(k) / 120.0
		_annulus_im.surface_add_vertex((mr + bas * (Vector3(cos(a), 0, sin(a)) * hr) - cam_pos) / KM_PER_UNIT)
	_annulus_im.surface_end()

# ── camera ──────────────────────────────────────────────────────────────
func _move_camera(delta: float) -> void:
	var up := Vector3.UP
	match cam_mode:
		Cam.FREE:
			var sp: float = SPEEDS[speed_idx][1]
			if sp < 0.0:
				sp = maxf(_nearest_surface_km() * 0.8, 1.0)
			if _keys.get("shift", false):
				sp *= 10.0
			var fwd := -_cam.global_transform.basis.z
			var right := _cam.global_transform.basis.x
			var mv := Vector3.ZERO
			if _keys.get("w", false): mv += fwd
			if _keys.get("s", false): mv -= fwd
			if _keys.get("d", false): mv += right
			if _keys.get("a", false): mv -= right
			if _keys.get("e", false): mv += up
			if _keys.get("q", false): mv -= up
			mv += fwd * (-_move_vec.y) + right * _move_vec.x
			if mv.length() > 1.0e-6:
				cam_pos += mv.normalized() * minf(mv.length(), 1.0) * sp * delta
			if _keys.get("left", false): yaw += 1.2 * delta
			if _keys.get("right", false): yaw -= 1.2 * delta
			if _keys.get("up", false): pitch = clampf(pitch + 1.0 * delta, -1.55, 1.55)
			if _keys.get("down", false): pitch = clampf(pitch - 1.0 * delta, -1.55, 1.55)
			_cam.transform = Transform3D(_look_basis(up), Vector3.ZERO)
		Cam.ORBIT:
			var c := _rel(orbit_target)
			if _keys.get("left", false): orbit_az += 1.0 * delta
			if _keys.get("right", false): orbit_az -= 1.0 * delta
			if _keys.get("up", false): orbit_el = clampf(orbit_el + 0.8 * delta, -1.5, 1.5)
			if _keys.get("down", false): orbit_el = clampf(orbit_el - 0.8 * delta, -1.5, 1.5)
			if _keys.get("w", false): orbit_dist_km *= pow(0.5, delta)
			if _keys.get("s", false): orbit_dist_km *= pow(2.0, delta)
			orbit_dist_km = maxf(orbit_dist_km, ZeclipticBodies.radius_km(orbit_target) * 1.05)
			var dir := Vector3(cos(orbit_el) * cos(orbit_az), sin(orbit_el), cos(orbit_el) * sin(orbit_az))
			cam_pos = c + dir * orbit_dist_km
			if look_target != "" and look_target != orbit_target:
				_cam.transform = Transform3D(_look_basis(up), Vector3.ZERO)
			else:
				_cam.transform = Transform3D(Basis.looking_at((c - cam_pos).normalized(), up), Vector3.ZERO)
		Cam.SURFACE:
			var c := _rel(surf_body)
			var spot := _surface_latlon()
			var dir_ecl := ZeclipticBodies.surface_dir_ecl(surf_body, jd, spot.x, spot.y)
			var dir := ZeclipticBodies.to_godot(_fb * dir_ecl)
			var R := ZeclipticBodies.radius_km(surf_body)
			cam_pos = c + dir * (R + surf_eye_km)
			up = dir
			if _keys.get("left", false): yaw += 1.2 * delta
			if _keys.get("right", false): yaw -= 1.2 * delta
			if _keys.get("up", false): pitch = clampf(pitch + 1.0 * delta, -1.55, 1.55)
			if _keys.get("down", false): pitch = clampf(pitch - 1.0 * delta, -1.55, 1.55)
			if _keys.get("w", false): surf_eye_km *= pow(4.0, delta)
			if _keys.get("s", false): surf_eye_km = maxf(surf_eye_km * pow(0.25, delta), 0.0017)
			_cam.transform = Transform3D(_look_basis(up), Vector3.ZERO)

func _look_basis(up: Vector3) -> Basis:
	if look_target != "" and look_target != surf_body:
		var t := _rel(look_target) - cam_pos
		if t.length() > 1.0e-6:
			var f := t.normalized()
			var u := up if absf(f.dot(up)) < 0.995 else (Vector3.RIGHT if absf(f.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD)
			return Basis.looking_at(f, u)
	# yaw/pitch about `up`: build a local frame with north = projection of frame-Y (or body pole on surface)
	var north := Vector3.UP
	if cam_mode == Cam.SURFACE:
		var pole := ZeclipticBodies.to_godot(_fb * ZeclipticBodies.pole_ecl(surf_body))
		north = pole - up * pole.dot(up)
		if north.length() < 1.0e-6:
			north = Vector3.RIGHT - up * up.dot(Vector3.RIGHT)
		north = north.normalized()
	else:
		north = Vector3.FORWARD
	var east := north.cross(up).normalized()
	var f := (north * cos(yaw) + east * sin(yaw)) * cos(pitch) + up * sin(pitch)
	return Basis.looking_at(f.normalized(), up)

func _surface_latlon() -> Vector2:
	var spot: String = LANDING_SPOTS[surf_spot_idx]
	var tl := ZeclipticBodies.tropic_lat_deg(surf_body)
	var pl := ZeclipticBodies.polar_circle_lat_deg(surf_body)
	match spot:
		"north pole": return Vector2(89.99, 0.0)
		"arctic circle": return Vector2(pl, surf_lon)
		"tropic (N)": return Vector2(tl, surf_lon)
		"equator": return Vector2(0.0, surf_lon)
		"tropic (S)": return Vector2(-tl, surf_lon)
		"antarctic circle": return Vector2(-pl, surf_lon)
		"south pole": return Vector2(-89.99, 0.0)
		"subsolar", "antisolar", "sub-primary":
			var target_id := "sol"
			if spot == "sub-primary":
				var par = ZeclipticBodies.body(surf_body).get("parent", "sol")
				target_id = str(par) if par != null else "sol"
			var r64 := ZeclipticBodies.rel_ecl_km64(target_id, surf_body, jd)
			var v := Vector3(r64[0], r64[1], r64[2])
			if spot == "antisolar":
				v = -v
			var bb := ZeclipticBodies.body_basis_ecl(surf_body, jd)
			var local := bb.transposed() * v.normalized()
			return Vector2(rad_to_deg(asin(clampf(local.z, -1, 1))), rad_to_deg(atan2(local.y, local.x)))
		_: return Vector2(surf_lat, surf_lon)

func _nearest_surface_km() -> float:
	var best := 1.0e12
	for id in _ids:
		var d := (_rel(id) - cam_pos).length() - ZeclipticBodies.radius_km(id)
		best = minf(best, maxf(d, 1.0))
	return best

# ── actions ─────────────────────────────────────────────────────────────
func _select(id: String, pause: bool = true) -> void:
	if id == "":
		return
	selected = id
	if pause:
		paused_by_tap = true
	_card.visible = true
	_fill_card()

func _fill_card() -> void:
	var b := ZeclipticBodies.body(selected)
	var r := ZeclipticBodies.radius_km(selected)
	var d := (_rel(selected) - cam_pos).length()
	var lines: Array = []
	lines.append("[b]%s[/b]  (%s)" % [_name(selected), str(b.get("kind", ""))])
	lines.append("radius %s km · distance from camera %s · angular diameter %.3f°" % [_fmt(r), _dist_str(d), ZeclipticBodies.angular_diameter_deg(r, d)])
	if b.get("parent", null) != null and b["parent"] != "sol":
		lines.append("orbits %s at %s km, period %.4f d%s · Pis/Earth-yr %.1f" % [_name(str(b["parent"])), _fmt(float(b["a_km"])), absf(float(b["period_d"])), " (retrograde)" if b.get("retrograde", false) else "", float(b.get("pis_per_earth_year", 0.0))])
		lines.append("[color=#aab]%s[/color]" % str(b.get("phase_note", "")))
	elif selected != "sol":
		var hel := ZeclipticBodies.helio_ecl_km(selected, jd).length()
		lines.append("from Sol %.4f AU = %.1f R\u2609 · period %.2f d · heliocentric lat (%s) %.2f°" % [hel / ZeclipticBodies.AU_KM, hel / ZeclipticBodies.radius_km("sol"), ZeclipticBodies.period_d(selected), frame_id, ZeclipticBodies.latitude_in_frame_deg(selected, jd, _fb)])
	if b.get("spin_tilt_to_zecliptic_deg") != null or b.get("pole_radec_j2000") != null:
		lines.append("spin tilt to Zecliptic %.2f° · obliquity to own orbit %s° · tropics ±%.1f°, polar circles ±%.1f°" % [ZeclipticBodies.spin_tilt_to_zecliptic_deg(selected), str(b.get("obliquity_deg", "—")), ZeclipticBodies.tropic_lat_deg(selected), ZeclipticBodies.polar_circle_lat_deg(selected)])
	if b.get("rot_d") != null:
		lines.append("rotation %.4f d%s" % [absf(float(b["rot_d"])), " (synchronous)" if b.get("synchronous", false) else ""])
	if b.get("hill_radius_km") != null:
		lines.append("Hill radius %s km" % _fmt(float(b["hill_radius_km"])))
	if selected == "mercury":
		var ann: Dictionary = ZeclipticBodies.data()["mercury_annulus_km"]
		lines.append("[color=#fa8]survival annulus %s – %s km (prograde), to %s km retrograde — no companion on the board[/color]" % [_fmt(float(ann["inner_km_10km_body"])), _fmt(float(ann["outer_km_prograde_this_run"])), _fmt(float(ann["outer_km_retrograde_this_run"]))])
	if b.has("sbdb"):
		lines.append("[color=#aab]%s · %s, epoch JD %.1f[/color]" % [str(b["sbdb"]["fullname"]), str(b["sbdb"]["source"]), float(b["sbdb"]["epoch_jd"])])
	if str(b.get("notes", "")) != "":
		lines.append("[color=#aab]%s[/color]" % str(b["notes"]))
	lines.append("[color=#fd8]time paused — Resume to continue[/color]" if paused_by_tap else "")
	_card_text.text = "\n".join(lines)

func _teleport(id: String) -> void:
	if id == "":
		return
	look_target = ""
	cam_mode = Cam.ORBIT
	orbit_target = id
	var r := ZeclipticBodies.radius_km(id)
	orbit_dist_km = r * (6.0 if id != "sol" else 4.0)
	# sunward quarter: azimuth toward Sol
	var to_sol := _rel("sol") - _rel(id)
	if to_sol.length() > 1.0:
		orbit_az = atan2(to_sol.z, to_sol.x) + 0.7
	else:
		orbit_az = 0.6
	orbit_el = 0.3
	_say("teleported to %s" % _name(id))

func _enter_orbit(id: String) -> void:
	if id == "":
		return
	cam_mode = Cam.ORBIT
	orbit_target = id
	orbit_dist_km = maxf((_rel(id) - cam_pos).length(), ZeclipticBodies.radius_km(id) * 3.0)
	var d := cam_pos - _rel(id)
	if d.length() > 1.0:
		orbit_az = atan2(d.z, d.x)
		orbit_el = asin(clampf(d.normalized().y, -1, 1))
	_say("orbit cam on %s" % _name(id))

func _land(id: String, spot_idx: int) -> void:
	if id == "":
		return
	cam_mode = Cam.SURFACE
	surf_body = id
	surf_spot_idx = spot_idx
	surf_eye_km = 0.002
	pitch = 0.05
	yaw = 0.0
	_say("landed on %s at %s" % [_name(id), LANDING_SPOTS[spot_idx]])

func _lift_off() -> void:
	if cam_mode == Cam.SURFACE:
		cam_mode = Cam.ORBIT
		orbit_target = surf_body
		orbit_dist_km = ZeclipticBodies.radius_km(surf_body) * 3.0
		_say("lift off")

func _to_free() -> void:
	# keep the camera where it is and its current look direction
	var f := -_cam.transform.basis.z
	cam_mode = Cam.FREE
	pitch = asin(clampf(f.y, -1, 1))
	yaw = atan2(f.dot(Vector3.FORWARD.cross(Vector3.UP)), f.dot(Vector3.FORWARD))
	_say("free camera")

func _set_reference(id: String) -> void:
	if id == "":
		return
	# keep the camera fixed in space across the switch
	var old_cam_abs := cam_pos + _rel_abs_ref()
	ref_id = id
	_rel_cache.clear()
	cam_pos = old_cam_abs - _rel_abs_ref()
	_trail.clear()
	_say("reference: %s%s" % [_name(id), "" if id == "sol" else " — Sol and the planets now move around this body"])

func _rel_abs_ref() -> Vector3:
	## position of the current reference body relative to Sol (for frame switches)
	var r := ZeclipticBodies.rel_ecl_km64(ref_id, "sol", jd)
	return ZeclipticBodies.to_godot(_fb * Vector3(r[0], r[1], r[2]))

func _set_frame(fid: String, body_id: String = "") -> void:
	frame_id = fid
	if body_id != "":
		frame_body = body_id
	_rel_cache.clear()
	_orbit_rebuild_t = 0.0
	_say("frame: %s" % _frame_label())

func _set_look_target(id: String) -> void:
	look_target = id
	_say("looking at %s" % _name(id))

func _toggle_alpha(id: String) -> void:
	if id == "":
		return
	alpha[id] = 0.25 if alpha.get(id, 1.0) > 0.5 else 1.0
	_say("%s alpha %.2f" % [_name(id), alpha[id]])

func _toggle_hidden(id: String) -> void:
	if hidden_ids.has(id):
		hidden_ids.erase(id)
	else:
		hidden_ids[id] = true

func _resume_time() -> void:
	paused_by_tap = false
	_fill_card()

func _toggle_pause() -> void:
	if paused_by_tap or rate_idx == 0:
		paused_by_tap = false
		if rate_idx == 0:
			rate_idx = 5
	else:
		paused_by_tap = true

func _set_jd(v: float) -> void:
	jd = v
	_rel_cache.clear()
	_orbit_rebuild_t = 0.0
	_trail.clear()

func _now_jd() -> float:
	var u := Time.get_unix_time_from_system()
	return 2440587.5 + u / 86400.0

func _hop(step: int) -> void:
	var i := _ids.find(selected) if selected != "" else 0
	i = wrapi(i + step, 0, _ids.size())
	_select(_ids[i], false)
	_teleport(_ids[i])

func _save_mark(slot: int) -> void:
	bookmarks[slot] = {"jd": jd, "rate_idx": rate_idx, "reverse": reverse, "frame_id": frame_id, "frame_body": frame_body,
		"ref_id": ref_id, "cam_mode": cam_mode, "cam_pos": cam_pos, "yaw": yaw, "pitch": pitch, "orbit_target": orbit_target,
		"orbit_dist_km": orbit_dist_km, "orbit_az": orbit_az, "orbit_el": orbit_el, "surf_body": surf_body, "surf_lat": surf_lat,
		"surf_lon": surf_lon, "surf_eye_km": surf_eye_km, "surf_spot_idx": surf_spot_idx, "look_target": look_target,
		"size_idx": size_idx, "dist_log": dist_log, "alpha": alpha.duplicate(), "selected": selected}
	_say("saved mark %d" % slot)

func _go_mark(slot: int) -> void:
	if not bookmarks.has(slot):
		_say("mark %d is empty" % slot)
		return
	var m: Dictionary = bookmarks[slot]
	for k in m:
		set(k, m[k])
	_rel_cache.clear()
	_orbit_rebuild_t = 0.0
	_say("mark %d" % slot)

func _screenshot() -> void:
	var img := _vp.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://zecliptic"))
	var name := "user://zecliptic/%s_%s_%s.png" % [ZeclipticBodies.date_label(jd).replace(" ", "_").replace(",", ""), frame_id, ref_id]
	img.save_png(name)
	_say("saved " + name)

# ── presets ─────────────────────────────────────────────────────────────
func _apply_preset_charon_pluto() -> void:
	frame_id = "zecliptic"
	ref_id = "pluto"
	selected = "pluto"
	surf_body = "charon"
	surf_spot_idx = LANDING_SPOTS.find("sub-primary")
	cam_mode = Cam.SURFACE
	surf_eye_km = 0.002
	look_target = "pluto"
	alpha["pluto"] = 0.25
	rate_idx = 5
	size_idx = 0
	_card.visible = false
	paused_by_tap = false
	_rel_cache.clear()
	_say("Charon \u2192 Pluto: standing at Charon's sub-Pluto point, Pluto at 25 % alpha, 1 day per second")

func _apply_preset_sol_charon() -> void:
	frame_id = "zecliptic"
	ref_id = "sol"
	selected = "charon"
	surf_body = "sol"
	cam_mode = Cam.SURFACE
	surf_eye_km = 2000.0
	surf_spot_idx = LANDING_SPOTS.find("equator")
	# longitude under Charon: use the custom lon from Pluto's direction in Sol's body frame
	var r64 := ZeclipticBodies.rel_ecl_km64("charon", "sol", jd)
	var v := Vector3(r64[0], r64[1], r64[2]).normalized()
	var bb := ZeclipticBodies.body_basis_ecl("sol", jd)
	var local := bb.transposed() * v
	surf_lon = rad_to_deg(atan2(local.y, local.x))
	look_target = "charon"
	alpha["pluto"] = 0.25
	rate_idx = 7
	size_idx = 0
	_card.visible = false
	paused_by_tap = false
	_rel_cache.clear()
	_say("Sol equator \u2192 Charon: 2,000 km above Sol's equator under Charon, 1 month per second (Sol's rotation carries the ground)")

func _apply_preset_luna_earth() -> void:
	frame_id = "zecliptic"; ref_id = "earth"; selected = "earth"; surf_body = "luna"
	surf_spot_idx = LANDING_SPOTS.find("sub-primary"); cam_mode = Cam.SURFACE; surf_eye_km = 0.002
	look_target = "earth"; rate_idx = 3; size_idx = 0; _card.visible = false; paused_by_tap = false; _rel_cache.clear()
	_say("Luna \u2192 Earth: Earth hangs nearly still over Luna's near side; 1 hour per second")

func _apply_preset_mercury() -> void:
	frame_id = "zecliptic"; ref_id = "mercury"; selected = "mercury"; look_target = ""
	cam_mode = Cam.ORBIT; orbit_target = "mercury"; orbit_dist_km = 400000.0; orbit_az = 0.8; orbit_el = 0.9
	overlays["annulus"] = true; overlays["hill"] = true; rate_idx = 5; size_idx = 1; _card.visible = false; paused_by_tap = false; _rel_cache.clear()
	_say("Mercury: survival annulus 13,254–81,473 km and the Hill sphere; body size \u00d710")

func _apply_preset_overview() -> void:
	frame_id = "zecliptic"; ref_id = "sol"; selected = "sol"; look_target = "sol"
	cam_mode = Cam.ORBIT; orbit_target = "sol"; orbit_dist_km = 45.0 * ZeclipticBodies.AU_KM; orbit_az = 0.0; orbit_el = 1.2
	overlays["grid"] = true; overlays["orbits"] = true; rate_idx = 8; size_idx = 3; _card.visible = false; paused_by_tap = false; _rel_cache.clear()
	_say("Above the Zecliptic: 45 AU over Sol's pole, 1 year per second, bodies \u00d71000")

# ── HUD text ────────────────────────────────────────────────────────────
func _update_hud() -> void:
	var rate_lbl: String = RATES[rate_idx][0]
	if paused_by_tap:
		rate_lbl = "paused (tap)"
	var cal := ZeclipticBodies.calendar(jd)
	var frac: float = float(cal["day"]) - floor(float(cal["day"]))
	var hh := int(frac * 24.0)
	var mm := int((frac * 24.0 - hh) * 60.0)
	var warn := "" if jd >= 2378497.0 and jd <= 2469808.0 else "  \u26A0 outside Standish 1800–2050"
	_timebar.text = "%s %02d:%02d UTC · JD %.3f · %s%s%s · Luna Pis since epoch %.1f · Charon Pis %.1f" % [
		ZeclipticBodies.date_label(jd), hh, mm, jd, rate_lbl, " \u25C0 reverse" if reverse else "", warn,
		ZeclipticBodies.pis_elapsed("luna", epoch_jd, jd), ZeclipticBodies.pis_elapsed("charon", epoch_jd, jd)]
	_banner.visible = overlays["frame_banner"]
	_banner.text = "FRAME %s · ORIGIN %s · %s" % [_frame_label(), _name(ref_id) if ref_id != "bary" else "barycentre", _frame_why()]
	_readout.visible = overlays["readouts"] and not _card.visible
	if _readout.visible:
		var lines: Array = []
		var mode_s: String = ["free", "orbit cam: " + _name(orbit_target), "on %s (%s)" % [_name(surf_body), LANDING_SPOTS[surf_spot_idx]]][cam_mode]
		lines.append("camera: %s%s" % [mode_s, ("  → looking at " + _name(look_target)) if look_target != "" else ""])
		lines.append("camera from %s: %s · alt above nearest surface %s" % [_name(ref_id), _dist_str(cam_pos.length()), _dist_str(_nearest_surface_km())])
		var sol_d := (_rel("sol") - cam_pos).length()
		lines.append("from Sol: %.4f AU = %s R\u2609 = %.1f light-min" % [sol_d / ZeclipticBodies.AU_KM, _fmt(sol_d / ZeclipticBodies.radius_km("sol")), sol_d / 299792.458 / 60.0])
		if selected != "":
			var d := (_rel(selected) - cam_pos).length()
			lines.append("selected %s: %s away · %.3f° across · spin tilt to Zecliptic %.2f°" % [_name(selected), _dist_str(d), ZeclipticBodies.angular_diameter_deg(ZeclipticBodies.radius_km(selected), d), ZeclipticBodies.spin_tilt_to_zecliptic_deg(selected)])
		if look_target != "":
			var d2 := (_rel(look_target) - cam_pos).length()
			lines.append("target %s: %s · %.3f° across" % [_name(look_target), _dist_str(d2), ZeclipticBodies.angular_diameter_deg(ZeclipticBodies.radius_km(look_target), d2)])
		lines.append("Sol B\u2080 from Earth %.2f° · Earth lat in %s frame %.2f°" % [ZeclipticBodies.sol_b0_deg(jd), frame_id, ZeclipticBodies.latitude_in_frame_deg("earth", jd, _fb)])
		lines.append("size \u00d7%d · distances %s · speed %s · %d fps" % [int(SIZE_SCALES[size_idx]), "COMPRESSED" if dist_log else "real", SPEEDS[speed_idx][0], Engine.get_frames_per_second()])
		_readout.text = "\n".join(lines)

func _frame_label() -> String:
	match frame_id:
		"zecliptic": return "Zecliptic (Sol's equator, i 7.25°, Ω 75.76°)"
		"ecliptic": return "Ecliptic (Earth's orbit)"
		"invariable": return "Invariable plane (system angular momentum, i 1.58°)"
		"body": return "%s's equator" % _name(frame_body)
	return frame_id

func _frame_why() -> String:
	match frame_id:
		"zecliptic": return "default — the rule"
		"ecliptic": return "named: the ephemeris is tabulated here"
		"invariable": return "named: Jupiter+Saturn set this plane; Sol is tipped 6° from it"
		"body": return "named: looking from this body's own spin"
	return ""

func _draw_overlay() -> void:
	if not _active:
		return
	var vp_size := _overlay.size
	var sel_pos := Vector2(-1, -1)
	for id in _ids:
		if hidden_ids.has(id):
			continue
		var b := ZeclipticBodies.body(id)
		if b.get("kind", "") == "asteroid" and not overlays["belt_big"]:
			continue
		var p := (_rel(id) - cam_pos) / KM_PER_UNIT
		if _cam.is_position_behind(p):
			continue
		var sp := _cam.unproject_position(p)
		if sp.x < -20 or sp.y < -20 or sp.x > vp_size.x + 20 or sp.y > vp_size.y + 20:
			continue
		var d := p.length()
		var ang := ZeclipticBodies.angular_diameter_deg(_radius_units(id) * KM_PER_UNIT, d * KM_PER_UNIT)
		var px := ang / _cam.fov * vp_size.y
		var is_moon: bool = b.get("kind", "") == "moon"
		if is_moon and px < 0.6 and id != selected and id != look_target:
			continue   # sub-pixel moons of far planets clutter
		if overlays["markers"] and px < 3.0:
			var col := Color(1, 1, 1, 0.8) if id != "sol" else GOLD
			_overlay.draw_circle(sp, 2.5 if not is_moon else 1.5, col)
		if overlays["labels"] and (px >= 1.0 or not is_moon or id == selected):
			var txt := _name(id)
			if id == selected:
				txt += "  \u25C1"
			_overlay.draw_string(ThemeDB.fallback_font, sp + Vector2(8, -6), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.9, 0.93, 1.0, 0.9) if id != selected else GOLD)
		if id == selected:
			sel_pos = sp
			_overlay.draw_arc(sp, maxf(px * 0.5 + 8.0, 14.0), 0, TAU, 48, GOLD, 1.5)
	# light-time rings (1, 8.3, 60 light-minutes) as text hints on the horizon of the grid
	if overlays["light_time"]:
		var c_km := 299792.458 * 60.0
		for lm in [1.0, 8.317, 60.0]:
			var ring_r: float = lm * c_km
			var pw := (_rel("sol") + Vector3(ring_r, 0, 0) - cam_pos) / KM_PER_UNIT
			if not _cam.is_position_behind(pw):
				var sp2 := _cam.unproject_position(pw)
				_overlay.draw_string(ThemeDB.fallback_font, sp2, "%.1f light-min" % lm, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.5, 0.8, 1.0, 0.8))
	# crosshair for free cam
	if cam_mode == Cam.FREE:
		var c := vp_size * 0.5
		_overlay.draw_line(c + Vector2(-8, 0), c + Vector2(8, 0), Color(1, 1, 1, 0.4))
		_overlay.draw_line(c + Vector2(0, -8), c + Vector2(0, 8), Color(1, 1, 1, 0.4))

# ── input ───────────────────────────────────────────────────────────────
func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_wheel(1)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_wheel(-1)
		elif mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				_tap_down_pos = mb.position
				_tap_down_t = Time.get_ticks_msec() / 1000.0
				_drag_mode = 1
			else:
				var moved := (mb.position - _tap_down_pos).length()
				var dt := Time.get_ticks_msec() / 1000.0 - _tap_down_t
				_drag_mode = 0
				_move_vec = Vector2.ZERO
				if moved < 12.0 and dt < 0.5 and mb.button_index == MOUSE_BUTTON_LEFT:
					_tap(mb.position)
		accept_event()
	elif ev is InputEventMouseMotion:
		var mm := ev as InputEventMouseMotion
		if _drag_mode == 1 and (mm.button_mask & (MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_RIGHT)) != 0:
			_drag_look(mm.relative)
	elif ev is InputEventScreenTouch:
		var st := ev as InputEventScreenTouch
		if st.pressed:
			_touch_pts[st.index] = st.position
			if st.index == 0:
				_tap_down_pos = st.position
				_tap_down_t = Time.get_ticks_msec() / 1000.0
				_drag_mode = 2 if st.position.x < size.x * 0.5 else 1
			if _touch_pts.size() >= 3:
				_toggle_pause()
		else:
			_touch_pts.erase(st.index)
			if st.index == 0:
				var moved := (st.position - _tap_down_pos).length()
				var dt := Time.get_ticks_msec() / 1000.0 - _tap_down_t
				_drag_mode = 0
				_move_vec = Vector2.ZERO
				if moved < 14.0 and dt < 0.45:
					_tap(st.position)
		accept_event()
	elif ev is InputEventScreenDrag:
		var sd := ev as InputEventScreenDrag
		_touch_pts[sd.index] = sd.position
		if sd.index == 0:
			if _drag_mode == 2 and cam_mode == Cam.FREE:
				_move_vec = ((sd.position - _tap_down_pos) / 160.0).limit_length(1.0)
			else:
				_drag_look(sd.relative)
		accept_event()

func _drag_look(rel: Vector2) -> void:
	if cam_mode == Cam.ORBIT:
		orbit_az -= rel.x * 0.006
		orbit_el = clampf(orbit_el + rel.y * 0.006, -1.5, 1.5)
	else:
		if look_target != "":
			look_target = ""
			_say("free look")
		yaw -= rel.x * 0.004
		pitch = clampf(pitch - rel.y * 0.004, -1.55, 1.55)

func _wheel(dir: int) -> void:
	if cam_mode == Cam.ORBIT:
		orbit_dist_km *= 0.8 if dir > 0 else 1.25
	elif cam_mode == Cam.SURFACE:
		surf_eye_km = maxf(surf_eye_km * (0.7 if dir < 0 else 1.4), 0.0017)
	else:
		speed_idx = clampi(speed_idx + dir, 0, SPEEDS.size() - 1)
		_say("speed " + SPEEDS[speed_idx][0])

func _tap(pos: Vector2) -> void:
	# hit-test bodies by projected position
	var best := ""
	var best_d := 1.0e9
	for id in _ids:
		if hidden_ids.has(id):
			continue
		var p := (_rel(id) - cam_pos) / KM_PER_UNIT
		if _cam.is_position_behind(p):
			continue
		var sp := _cam.unproject_position(p)
		var ang := ZeclipticBodies.angular_diameter_deg(_radius_units(id) * KM_PER_UNIT, p.length() * KM_PER_UNIT)
		var px := maxf(ang / _cam.fov * size.y * 0.5, 14.0)
		var d := sp.distance_to(pos)
		if d < px + 10.0 and d < best_d:
			best_d = d
			best = id
	if best != "":
		_select(best, true)
	else:
		_card.visible = false

func _unhandled_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey):
		return
	var k := ev as InputEventKey
	var name := OS.get_keycode_string(k.keycode).to_lower()
	var map: Dictionary = {"w": "w", "a": "a", "s": "s", "d": "d", "q": "q", "e": "e", "left": "left", "right": "right", "up": "up", "down": "down", "shift": "shift"}
	if map.has(name):
		_keys[map[name]] = k.pressed
	if not k.pressed:
		return
	match name:
		"space": _toggle_pause()
		"bracketleft": rate_idx = maxi(rate_idx - 1, 0); paused_by_tap = false
		"bracketright": rate_idx = mini(rate_idx + 1, RATES.size() - 1); paused_by_tap = false
		"r": reverse = not reverse
		"comma": _set_jd(jd - (365.25636 if k.shift_pressed else 1.0))
		"period": _set_jd(jd + (365.25636 if k.shift_pressed else 1.0))
		"0": _set_jd(_now_jd())
		"f":
			var i := FRAMES.find(frame_id)
			_set_frame(FRAMES[(i + 1) % FRAMES.size()], selected if selected != "" else "earth")
		"b": _set_reference(selected)
		"z": _set_reference("sol")
		"n": _hop(1)
		"p": _hop(-1)
		"t": overlays["trails"] = not overlays["trails"]
		"l": _set_look_target(selected)
		"k": look_target = ""
		"x": size_idx = (size_idx + 1) % SIZE_SCALES.size(); _say("body size \u00d7%d" % int(SIZE_SCALES[size_idx]))
		"c": dist_log = not dist_log; _say("distances " + ("COMPRESSED — not to scale" if dist_log else "real"))
		"o": overlays["orbits"] = not overlays["orbits"]
		"g": overlays["grid"] = not overlays["grid"]
		"i": overlays["axes"] = not overlays["axes"]
		"u": overlays["equators"] = not overlays["equators"]; overlays["tropics"] = overlays["equators"]
		"j": overlays["hill"] = not overlays["hill"]
		"m": overlays["annulus"] = not overlays["annulus"]
		"v": overlays["belt"] = not overlays["belt"]
		"h", "question", "slash": _help.visible = not _help.visible
		"escape": _card.visible = false; _help.visible = false; _panel.visible = false
		"f12": _screenshot()
		"1", "2", "3", "4", "5", "6", "7", "8", "9":
			var slot := int(name)
			if k.shift_pressed:
				_save_mark(slot)
			else:
				_go_mark(slot)

func _on_hop_selected(i: int) -> void:
	if i < _ids.size():
		_select(_ids[i], false)
		_teleport(_ids[i])
	else:
		_set_reference("bary")

func _on_lat_changed(x: float) -> void:
	surf_lat = x
	if cam_mode == Cam.SURFACE:
		surf_spot_idx = LANDING_SPOTS.size() - 1

func _on_lon_changed(x: float) -> void:
	surf_lon = x
	if cam_mode == Cam.SURFACE:
		surf_spot_idx = LANDING_SPOTS.size() - 1

# ── helpers ─────────────────────────────────────────────────────────────
func _name(id: String) -> String:
	if id == "bary":
		return "barycentre"
	return str(ZeclipticBodies.body(id).get("name", id))

func _fmt(x: float) -> String:
	if absf(x) >= 1000.0:
		var s := "%d" % int(round(x))
		var out := ""
		var n := s.length()
		for i in n:
			out += s[i]
			if (n - i - 1) % 3 == 0 and i < n - 1:
				out += ","
		return out
	return "%.1f" % x

func _dist_str(km: float) -> String:
	if km < 1.0e4:
		return "%s km" % _fmt(km)
	if km < 0.02 * ZeclipticBodies.AU_KM:
		return "%s km" % _fmt(km)
	return "%.4f AU (%s km)" % [km / ZeclipticBodies.AU_KM, _fmt(km)]

func _say(t: String) -> void:
	_msg.text = t
	_msg_t = 3.5

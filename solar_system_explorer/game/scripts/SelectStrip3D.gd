class_name SelectStrip3D
extends Control
## Horizontal destination picker — rotating skinned spheres in a side-on row.
## Tap a world to pick it; sun is decorative (not a hop target).

signal body_picked(id: String)
signal go_home()

var cfg: SolarFlyerConfig
var ship_id: String = "earth"
var _host: SubViewportContainer
var _viewport: SubViewport
var _world: Node3D
var _cam: Camera3D
var _roots: Dictionary = {}   ## id -> {root, mesh, label_anchor}
var _hint: Label
var _active: bool = false
var _spin_t: float = 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if cfg == null:
		cfg = SolarFlyerConfig.load_default()
	_build()
	gui_input.connect(_on_gui_input)

func begin() -> void:
	_active = true
	visible = true
	_spin_t = 0.0
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_hint.text = "Swipe the row — tap a planet to go there"
	_place_bodies()

func set_active(on: bool) -> void:
	_active = on
	visible = on
	if _viewport != null:
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on \
			else SubViewport.UPDATE_DISABLED

func set_ship_at(id: String) -> void:
	ship_id = id
	_place_bodies()

func _process(delta: float) -> void:
	if not _active:
		return
	_spin_t += delta
	for id in _roots:
		var info: Dictionary = _roots[id]
		var mesh: Node3D = info["mesh"]
		var spin: float = float(info.get("spin", 0.2))
		mesh.rotate_y(spin * delta)
		# Soft bob so the row feels alive.
		var root: Node3D = info["root"]
		root.position.y = sin(_spin_t * 1.3 + float(info.get("phase", 0.0))) * 0.15

func _build() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.02, 0.03, 0.07, 0.55)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_host = SubViewportContainer.new()
	_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_host.stretch = true
	_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_host)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1280, 600)
	_viewport.transparent_bg = true
	# Isolated world (see FlyScene): shared root World3D let scenes film
	# each other's planets.
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_host.add_child(_viewport)

	_world = Node3D.new()
	_viewport.add_child(_world)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.01, 0.015, 0.04, 0)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.35, 0.4, 0.55)
	e.ambient_light_energy = 0.85
	env.environment = e
	_world.add_child(env)
	var light := DirectionalLight3D.new()
	light.light_energy = 1.4
	light.rotation_degrees = Vector3(-35, 40, 0)
	_world.add_child(light)

	_cam = Camera3D.new()
	_cam.fov = 42.0
	_cam.near = 0.1
	_cam.far = 500.0
	_world.add_child(_cam)

	_build_bodies()
	_place_bodies()

	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 26)
	_hint.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	_hint.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.position = Vector2(0, 18)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)

	var home := Button.new()
	home.text = "\u25C0"
	home.custom_minimum_size = Vector2(84, 66)
	home.size = Vector2(84, 66)
	home.position = Vector2(20, 20)
	home.focus_mode = Control.FOCUS_NONE
	home.add_theme_font_size_override("font_size", 28)
	var hsb := StyleBoxFlat.new()
	hsb.bg_color = Color(0.95, 0.86, 0.45, 0.98)
	hsb.set_corner_radius_all(16)
	home.add_theme_stylebox_override("normal", hsb)
	home.pressed.connect(func() -> void: go_home.emit())
	add_child(home)

	# Name labels as 2D overlay (readable on landscape phone).
	_rebuild_labels()

func _build_bodies() -> void:
	for c in _world.get_children():
		if c is Node3D and c.name.begins_with("body_"):
			c.queue_free()
	_roots.clear()
	var i := 0
	for b in SolarData.flyer_bodies(cfg):
		var id := str(b["id"])
		var root := Node3D.new()
		root.name = "body_%s" % id
		_world.add_child(root)
		var mesh := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 1.0
		sphere.height = 2.0
		sphere.radial_segments = 24
		sphere.rings = 16
		mesh.mesh = sphere
		mesh.material_override = PlanetSkins.make_skinned_material(b)
		root.add_child(mesh)
		if bool(b.get("ring", false)):
			var ring := MeshInstance3D.new()
			var torus := TorusMesh.new()
			torus.inner_radius = 1.35
			torus.outer_radius = 2.05
			torus.rings = 24
			torus.ring_segments = 10
			ring.mesh = torus
			var rm := StandardMaterial3D.new()
			rm.albedo_color = Color(0.9, 0.82, 0.55, 0.8)
			rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			ring.material_override = rm
			ring.rotation_degrees = Vector3(78, 0, 0)
			root.add_child(ring)
		_roots[id] = {
			"root": root,
			"mesh": mesh,
			"data": b,
			"spin": float(b.get("spin", 0.15)) * (2.2 if id != "sun" else 0.6),
			"phase": float(i) * 0.7,
		}
		i += 1

func _place_bodies() -> void:
	## Lay bodies along X by compressed orbit; camera frames the row.
	if _roots.is_empty():
		return
	var xs: Array = []
	for id in _roots:
		var b: Dictionary = _roots[id]["data"]
		var x: float = float(b.get("orbit_r", 0.0)) * 0.11
		if bool(b.get("is_star", false)):
			x = 0.0
		xs.append(x)
		var hero: float = float(b.get("hero_r", 1.0))
		var s: float = clampf(hero * 0.22, 0.55, 2.8)
		if bool(b.get("belt", false)):
			s = 1.1
		var root: Node3D = _roots[id]["root"]
		root.position = Vector3(x, 0.0, 0.0)
		root.scale = Vector3.ONE * s
	xs.sort()
	var x0: float = float(xs[0]) if xs.size() else 0.0
	var x1: float = float(xs[xs.size() - 1]) if xs.size() else 10.0
	var mid := (x0 + x1) * 0.5
	var span := maxf(x1 - x0, 8.0)
	_cam.position = Vector3(mid, 2.2, span * 0.72)
	_cam.look_at(Vector3(mid, 0.2, 0.0), Vector3.UP)
	_rebuild_labels()

func _rebuild_labels() -> void:
	for c in get_children():
		if c is Label and c != _hint and str(c.name).begins_with("lbl_"):
			c.queue_free()
	for id in _roots:
		var b: Dictionary = _roots[id]["data"]
		var lbl := Label.new()
		lbl.name = "lbl_%s" % id
		lbl.text = str(b["name"])
		if id == ship_id:
			lbl.text = "%s  (you)" % str(b["name"])
		lbl.add_theme_font_size_override("font_size", 20 if id != ship_id else 22)
		lbl.add_theme_color_override("font_color",
			Color(1, 0.95, 0.55) if id == ship_id else Color(0.92, 0.95, 1.0))
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(lbl)
		# Approximate screen X from world X (updated each place).
		var root: Node3D = _roots[id]["root"]
		var sx := _world_to_screen_x(root.position.x)
		lbl.position = Vector2(sx - 70, 500)
		lbl.size = Vector2(140, 28)

func _world_to_screen_x(wx: float) -> float:
	## Orthographic-ish map from world X into the 1280 panel (matches camera framing).
	var xs: Array = []
	for id in _roots:
		xs.append(float((_roots[id]["root"] as Node3D).position.x))
	xs.sort()
	var x0: float = float(xs[0]) if xs.size() else 0.0
	var x1: float = float(xs[xs.size() - 1]) if xs.size() else 1.0
	var u: float = 0.5 if x1 <= x0 else (wx - x0) / (x1 - x0)
	return lerpf(80.0, 1200.0, clampf(u, 0.0, 1.0))

func _on_gui_input(event: InputEvent) -> void:
	if not _active:
		return
	var tap := false
	var pos := Vector2.ZERO
	if event is InputEventScreenTouch and not event.pressed:
		tap = true
		pos = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and not event.pressed:
		tap = true
		pos = event.position
	if not tap:
		return
	var id := hit_test(pos)
	if id.is_empty() or id == "sun" or id == ship_id:
		return
	body_picked.emit(id)

func hit_test(screen: Vector2) -> String:
	var best := ""
	var best_d := 72.0
	for id in _roots:
		var root: Node3D = _roots[id]["root"]
		var sx := _world_to_screen_x(root.position.x)
		var sy := 300.0
		var d: float = screen.distance_to(Vector2(sx, sy))
		var hit_r: float = 56.0 + float(_roots[id]["data"].get("hero_r", 1.0)) * 2.0
		if d < hit_r and d < best_d:
			best_d = d
			best = id
	return best

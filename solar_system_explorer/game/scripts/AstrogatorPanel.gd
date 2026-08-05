class_name AstrogatorPanel
extends Control
## Optional Astrogator ledger on PlotBoard (Phase B).
## Kid pace = default burn→coast→brake seconds. Astrogator shows real
## Hohmann coast / windows / rocket-equation fuel for a propulsion class.

signal pace_changed(pace_mode: String)
signal propulsion_changed(propulsion_id: String)

const PACE_KID := "kid"
const PACE_ASTROGATOR := "astrogator"

const PROP_CHEMICAL := "chemical"
const PROP_NTP := "ntp"
const PROP_ORION := "orion"

const PROP_ORDER := [PROP_CHEMICAL, PROP_NTP, PROP_ORION]
const PROP_LABELS := {
	PROP_CHEMICAL: "Chemical",
	PROP_NTP: "Nuclear thermal",
	PROP_ORION: "Nuclear pulse",
}

## Kid-softened engine names for narration.
const PROP_NARR := {
	PROP_CHEMICAL: "a chemical rocket",
	PROP_NTP: "a nuclear thermal rocket",
	PROP_ORION: "a nuclear pulse ship",
}

const MOSTLY_FUEL_FRAC := 0.55

var pace_mode: String = PACE_KID
var propulsion_id: String = PROP_CHEMICAL
var budget: Dictionary = {}
## When locked, pace/engine were chosen before chart — no in-plot toggles.
var locked: bool = false

var _pace_btn: Button
var _prop_row: HBoxContainer
var _prop_btns: Dictionary = {}  ## id -> Button
var _ledger: Label
var _fuel_bg: ColorRect
var _fuel_prop: ColorRect
var _fuel_ship: ColorRect
var _fuel_caption: Label
var _note: Label
var _header: Label

func _ready() -> void:
	custom_minimum_size = Vector2(420, 200)
	size = Vector2(420, 200)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build()
	_refresh()

func set_locked(on: bool) -> void:
	locked = on
	mouse_filter = Control.MOUSE_FILTER_IGNORE if on else Control.MOUSE_FILTER_STOP
	_refresh()

func set_session(pace: String, propulsion: String) -> void:
	pace_mode = pace if pace == PACE_ASTROGATOR else PACE_KID
	propulsion_id = propulsion if is_propulsion_id(propulsion) else PROP_CHEMICAL
	_refresh()

func show_for_route(budget_in: Dictionary) -> void:
	budget = budget_in
	visible = true
	_refresh()

func hide_panel() -> void:
	visible = false

func stamp_route(route: Dictionary) -> void:
	route["pace_mode"] = pace_mode
	route["propulsion_id"] = propulsion_id
	route["realism"] = budget.duplicate(true)

static func is_propulsion_id(id: String) -> bool:
	return RealismBudget.PROPULSION.has(id)

static func phase_now_rad(origin: Dictionary, dest: Dictionary, t: float) -> float:
	var po := OrbitMath.body_pos(origin, t)
	var pd := OrbitMath.body_pos(dest, t)
	if po.length() < 0.001 or pd.length() < 0.001:
		return 0.0
	var th_o := atan2(po.z, po.x)
	var th_d := atan2(pd.z, pd.x)
	return wrapf(th_d - th_o, -PI, PI)

static func format_duration_yr(years: float) -> String:
	var y: float = maxf(years, 0.0)
	if y < 1.0 / 12.0:
		return "%d days" % int(round(y * 365.25))
	if y < 1.5:
		var months: float = y * 12.0
		if months < 1.5:
			return "about 1 month"
		return "about %.0f months" % months
	if y < 10.0:
		return "%.1f years" % y
	return "%.0f years" % y

static func format_dv(km_s: float) -> String:
	return "%.1f km/s" % km_s

static func fuel_frac_for(budget_in: Dictionary, prop_id: String) -> float:
	if not bool(budget_in.get("ok", false)):
		return 0.0
	var fuels: Dictionary = budget_in.get("fuels", {})
	if not fuels.has(prop_id):
		return 0.0
	return float((fuels[prop_id] as Dictionary).get("propellant_frac_mission", 0.0))

static func ledger_lines(budget_in: Dictionary, prop_id: String) -> String:
	if not bool(budget_in.get("ok", false)):
		return "Nearby hop — no Hohmann window math."
	var coast := format_duration_yr(float(budget_in.get("coast_yr", 0.0)))
	var wait := format_duration_yr(float(budget_in.get("window_wait_yr", 0.0)))
	var dv := format_dv(float(budget_in.get("dv_mission_km_s", 0.0)))
	var frac := fuel_frac_for(budget_in, prop_id)
	var eng := str(PROP_LABELS.get(prop_id, prop_id))
	var lines := "Coast: %s\nNext window: %s\nMission Δv: %s\nEngine: %s" % [
		coast, wait, dv, eng]
	if frac >= MOSTLY_FUEL_FRAC:
		lines += "\nMost of this rocket is fuel."
	elif prop_id == PROP_ORION:
		lines += "\nPulse ship — more ship, less fuel."
	return lines

static func launch_narration(budget_in: Dictionary, prop_id: String) -> String:
	var eng := str(PROP_NARR.get(prop_id, "our rocket"))
	if not bool(budget_in.get("ok", false)):
		return "Leaving on %s." % eng
	var coast := format_duration_yr(float(budget_in.get("coast_yr", 0.0)))
	var frac := fuel_frac_for(budget_in, prop_id)
	var fuel_bit := "Most of the stack is fuel." if frac >= MOSTLY_FUEL_FRAC \
		else "Fuel is a smaller share of the ship."
	return "Astrogator: %s coast on %s. %s" % [coast, eng, fuel_bit]

## Kid-friendly science blurb for each engine class.
static func engine_explain(prop_id: String) -> String:
	match prop_id:
		PROP_CHEMICAL:
			return ("Chemical rockets burn cold fuel with oxygen — a carefully packed "
				+ "fire in a bottle. They push hard, but most of the rocket's weight "
				+ "has to be fuel.")
		PROP_NTP:
			return ("Nuclear thermal uses a reactor to super-heat hydrogen and shoot it "
				+ "out the nozzle — about twice as thrifty as chemical. Engineers have "
				+ "tested the idea on the ground; it hasn't flown in space yet.")
		PROP_ORION:
			return ("Nuclear pulse is a future ship idea — little controlled bangs push "
				+ "a giant plate at the back. You get huge thrust, and much less of the "
				+ "rocket has to be fuel.")
	return "We'll fly with our rocket engines."

## Full pre-chart Rocket Science briefing: engine + window + fuel + gravity honesty.
static func mission_briefing(origin: Dictionary, dest: Dictionary,
		budget_in: Dictionary, prop_id: String, cfg: SolarFlyerConfig) -> String:
	var dest_name := str(dest.get("name", "our destination"))
	var parts: PackedStringArray = PackedStringArray()
	parts.append(engine_explain(prop_id))
	if bool(budget_in.get("ok", false)):
		var wait := format_duration_yr(float(budget_in.get("window_wait_yr", 0.0)))
		var coast := format_duration_yr(float(budget_in.get("coast_yr", 0.0)))
		parts.append("The next good launch window toward %s is in %s." % [dest_name, wait])
		# format_duration_yr already includes "about" for month-scale values.
		parts.append("Once we leave, the coast alone takes %s." % coast)
		var frac := fuel_frac_for(budget_in, prop_id)
		var pct: int = clampi(int(round(frac * 100.0)), 1, 99)
		var ship_pct: int = 100 - pct
		parts.append(("For this trip, about %d percent of the rocket's starting weight "
			+ "must be fuel, and about %d percent can be the ship and crew.") % [
				pct, ship_pct])
	var t_depart := 0.0
	if bool(budget_in.get("ok", false)):
		t_depart = float(budget_in.get("window_wait_yr", 0.0)) * cfg.game_year_seconds
	parts.append(gravity_assist_line(origin, dest, cfg, t_depart))
	return " ".join(parts)

## Honest: only name planets the ship actually passes near (not radial rings).
static func gravity_assist_line(origin: Dictionary, dest: Dictionary,
		cfg: SolarFlyerConfig, t0: float = 0.0) -> String:
	var enc: Array = OrbitMath.preview_encounters(origin, dest, cfg, t0)
	if enc.is_empty():
		return ("This course doesn't borrow a gravity kick from another planet — "
			+ "our engines do all the pushing.")
	var names: Array = []
	for e in enc:
		var n := str(e.get("name", ""))
		if not n.is_empty():
			names.append(n)
		if names.size() >= 2:
			break
	var pass_line := ""
	if names.size() == 1:
		pass_line = "We'll pass close by %s" % names[0]
	else:
		pass_line = "We'll pass close by %s and %s" % [names[0], names[1]]
	return (pass_line + ", but we aren't swinging close enough to borrow a gravity kick — "
		+ "our engines do all the pushing.")

static func calendar_label(days_elapsed: float, days_total: float) -> String:
	var tot: float = maxf(days_total, 1.0)
	var el: float = clampf(days_elapsed, 0.0, tot)
	if tot >= 365.0:
		return "Coast calendar: %.1f / %.1f years" % [el / 365.25, tot / 365.25]
	if tot >= 45.0:
		return "Coast calendar: %.0f / %.0f months" % [el / 30.44, tot / 30.44]
	return "Coast calendar: %.0f / %.0f days" % [el, tot]

func _build() -> void:
	var bg := Panel.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.10, 0.20, 0.92)
	sb.set_corner_radius_all(16)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.45, 0.65, 1.0, 0.55)
	bg.add_theme_stylebox_override("panel", sb)
	add_child(bg)

	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 12
	col.offset_top = 10
	col.offset_right = -12
	col.offset_bottom = -10
	col.add_theme_constant_override("separation", 8)
	add_child(col)

	_header = Label.new()
	_header.add_theme_font_size_override("font_size", 18)
	_header.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0))
	col.add_child(_header)

	_pace_btn = Button.new()
	_pace_btn.focus_mode = Control.FOCUS_NONE
	_pace_btn.custom_minimum_size = Vector2(0, 44)
	_pace_btn.add_theme_font_size_override("font_size", 18)
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.10, 0.16, 0.30, 0.95)
	psb.set_corner_radius_all(12)
	psb.set_border_width_all(2)
	psb.border_color = Color(0.5, 0.7, 1.0, 0.6)
	_pace_btn.add_theme_stylebox_override("normal", psb)
	_pace_btn.add_theme_stylebox_override("hover", psb)
	_pace_btn.add_theme_stylebox_override("pressed", psb)
	_pace_btn.pressed.connect(_on_pace_pressed)
	col.add_child(_pace_btn)

	_prop_row = HBoxContainer.new()
	_prop_row.add_theme_constant_override("separation", 8)
	col.add_child(_prop_row)
	for pid in PROP_ORDER:
		var b := Button.new()
		b.text = str(PROP_LABELS[pid])
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(120, 40)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 14)
		b.pressed.connect(_on_prop_pressed.bind(pid))
		_prop_btns[pid] = b
		_prop_row.add_child(b)

	_ledger = Label.new()
	_ledger.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ledger.add_theme_font_size_override("font_size", 15)
	_ledger.add_theme_color_override("font_color", Color(0.88, 0.93, 1.0))
	_ledger.custom_minimum_size = Vector2(0, 72)
	col.add_child(_ledger)

	var fuel_wrap := Control.new()
	fuel_wrap.custom_minimum_size = Vector2(0, 28)
	fuel_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(fuel_wrap)

	_fuel_bg = ColorRect.new()
	_fuel_bg.color = Color(0.15, 0.18, 0.26, 1)
	_fuel_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fuel_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fuel_wrap.add_child(_fuel_bg)

	_fuel_prop = ColorRect.new()
	_fuel_prop.color = Color(0.95, 0.55, 0.28, 0.95)
	_fuel_prop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fuel_wrap.add_child(_fuel_prop)

	_fuel_ship = ColorRect.new()
	_fuel_ship.color = Color(0.35, 0.75, 0.95, 0.95)
	_fuel_ship.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fuel_wrap.add_child(_fuel_ship)

	_fuel_caption = Label.new()
	_fuel_caption.add_theme_font_size_override("font_size", 13)
	_fuel_caption.add_theme_color_override("font_color", Color(0.75, 0.82, 0.95))
	col.add_child(_fuel_caption)

	_note = Label.new()
	_note.add_theme_font_size_override("font_size", 13)
	_note.add_theme_color_override("font_color", Color(0.65, 0.75, 0.9))
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_note)

func _on_pace_pressed() -> void:
	pace_mode = PACE_ASTROGATOR if pace_mode == PACE_KID else PACE_KID
	_refresh()
	pace_changed.emit(pace_mode)

func _on_prop_pressed(pid: String) -> void:
	propulsion_id = pid
	_refresh()
	propulsion_changed.emit(propulsion_id)

func _refresh() -> void:
	if _pace_btn == null:
		return
	var astro: bool = pace_mode == PACE_ASTROGATOR
	var eng := str(PROP_LABELS.get(propulsion_id, propulsion_id))
	if locked:
		_pace_btn.visible = false
		_prop_row.visible = false
		_header.visible = astro
		_header.text = "Rocket Science · %s" % eng
	else:
		_header.visible = false
		_pace_btn.visible = true
		_pace_btn.text = "Pace:  Kid" if pace_mode == PACE_KID \
			else "Pace:  Astrogator"
		_prop_row.visible = astro

	_ledger.visible = astro
	_fuel_bg.get_parent().visible = astro
	_fuel_caption.visible = astro
	_note.visible = true

	if not astro:
		_note.text = "Quick Course — short burn, coast, brake."
		return

	_ledger.text = ledger_lines(budget, propulsion_id)
	var frac := fuel_frac_for(budget, propulsion_id)
	_layout_fuel_bar(frac)
	if bool(budget.get("ok", false)):
		_fuel_caption.text = "Propellant %.0f%%  ·  Ship %.0f%%" % [
			frac * 100.0, (1.0 - frac) * 100.0]
		_note.text = "Coast calendar skip · burn & brake stay cinematic."
	else:
		_fuel_caption.text = ""
		_note.text = str(budget.get("error", "Nearby hop — no long-coast ledger."))

	for pid in _prop_btns:
		var b: Button = _prop_btns[pid]
		var on: bool = pid == propulsion_id
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.22, 0.55, 0.85, 0.95) if on \
			else Color(0.14, 0.20, 0.32, 0.95)
		sb.set_corner_radius_all(10)
		sb.set_border_width_all(2)
		sb.border_color = Color(1, 1, 1, 0.85) if on \
			else Color(0.4, 0.5, 0.65, 0.5)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
		b.add_theme_stylebox_override("pressed", sb)
		b.add_theme_color_override("font_color",
			Color(0.05, 0.06, 0.1) if on else Color(0.85, 0.9, 1.0))

func _layout_fuel_bar(frac: float) -> void:
	var w: float = maxf(size.x - 24.0, 100.0)
	var h: float = 28.0
	var pf: float = clampf(frac, 0.0, 1.0)
	_fuel_prop.position = Vector2.ZERO
	_fuel_prop.size = Vector2(w * pf, h)
	_fuel_ship.position = Vector2(w * pf, 0)
	_fuel_ship.size = Vector2(w * (1.0 - pf), h)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and pace_mode == PACE_ASTROGATOR:
		_layout_fuel_bar(fuel_frac_for(budget, propulsion_id))

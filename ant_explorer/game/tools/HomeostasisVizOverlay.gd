extends CanvasLayer
## Live overlay for the homeostasis demo: caste census, pressures, demands,
## larva nutrition/JH histogram, and live controller readouts.

enum Mode { CLOSEUP, OVERVIEW, HISTOGRAM }

var colony: Node = null
var mode: int = Mode.CLOSEUP
var title: String = "HOMEOSTASIS"
var subtitle: String = ""
var speed_label: String = "1×"
var _panel: Control

func _ready() -> void:
	layer = 80
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = Control.new()
	_panel.name = "Draw"
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.draw.connect(_on_draw)
	add_child(_panel)

func _process(_delta: float) -> void:
	if _panel:
		_panel.queue_redraw()

func set_colony(c: Node) -> void:
	colony = c

func set_mode(m: int) -> void:
	mode = m

func set_chrome(t: String, sub: String = "", speed: String = "") -> void:
	title = t
	subtitle = sub
	if not speed.is_empty():
		speed_label = speed

func _on_draw() -> void:
	var c := _panel
	var size := c.size
	if size.x < 8.0 or colony == null:
		return
	var h = colony.get("homeostasis")
	if h == null:
		return
	# Keep the overlay honest even if we painted between sim ticks.
	if h.has_method("tick"):
		h.call("tick", colony)
	var snap: Dictionary = h.call("snapshot") if h.has_method("snapshot") else {}

	# Dim strip so text reads over the nest.
	var strip_h := size.y * (0.42 if mode == Mode.HISTOGRAM else 0.34)
	c.draw_rect(Rect2(0, 0, size.x, strip_h), Color(0.05, 0.04, 0.03, 0.72))
	c.draw_rect(Rect2(0, size.y - 36, size.x, 36), Color(0.05, 0.04, 0.03, 0.65))

	var font := ThemeDB.fallback_font
	var fs := 15
	var fs_sm := 12
	c.draw_string(font, Vector2(16, 22), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.98, 0.93, 0.82))
	if not subtitle.is_empty():
		c.draw_string(font, Vector2(16, 42), subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_sm, Color(0.85, 0.78, 0.65))
	c.draw_string(font, Vector2(size.x - 120, 22), speed_label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.95, 0.85, 0.45))

	# snapshot() is the stable API; gardeners/nurses are live fields after tick().
	var soldiers: int = int(snap.get("soldiers", 0))
	var foragers: int = int(snap.get("foragers", 0))
	var gardeners: int = int(h.gardeners)
	var nurses: int = int(h.nurses)
	var brood_n: int = int(h.brood_count)
	var sp: float = float(snap.get("soldier_pressure", 0.0))
	var fp: float = float(snap.get("forager_pressure", 0.0))
	var mp: float = float(snap.get("minor_pressure", 0.0))
	var food: float = float(snap.get("food", 0.0))
	var care: float = float(snap.get("care", 0.0))
	var defense: float = float(snap.get("defense", 0.0))
	var waste: float = float(snap.get("waste", 0.0))

	var cfg = _config()
	var t_sol := int(cfg.get("target_soldiers")) if cfg else 14
	var t_for := int(cfg.get("target_foragers")) if cfg else 32
	var t_min := int(cfg.get("target_minors")) if cfg else 28

	var th: Dictionary = h.call("caste_thresholds") if h.has_method("caste_thresholds") else {"high": 22.0, "mid": 19.0}
	var jh_scale: float = float(h.call("jh_dose_scale")) if h.has_method("jh_dose_scale") else 1.0

	# --- caste census bars ---
	var bar_y := 58.0
	var bar_x := 16.0
	var bar_w := size.x * 0.46
	_draw_caste_bar(c, font, bar_x, bar_y, bar_w, "Soldiers", soldiers, t_sol, Color(0.85, 0.28, 0.22), sp)
	_draw_caste_bar(c, font, bar_x, bar_y + 28, bar_w, "Foragers", foragers, t_for, Color(0.30, 0.72, 0.35), fp)
	_draw_caste_bar(c, font, bar_x, bar_y + 56, bar_w, "Minors", gardeners + nurses, t_min, Color(0.35, 0.55, 0.90), mp)
	c.draw_string(font, Vector2(bar_x, bar_y + 90), "  gardeners %d · nurses %d · brood %d" % [gardeners, nurses, brood_n], HORIZONTAL_ALIGNMENT_LEFT, -1, fs_sm, Color(0.75, 0.70, 0.60))

	# --- demand meters ---
	var dx := size.x * 0.52
	c.draw_string(font, Vector2(dx, bar_y), "DEMAND", HORIZONTAL_ALIGNMENT_LEFT, -1, fs_sm, Color(0.9, 0.82, 0.6))
	_draw_meter(c, font, dx, bar_y + 14, 200, "food", food, Color(0.45, 0.85, 0.40))
	_draw_meter(c, font, dx, bar_y + 36, 200, "care", care, Color(0.45, 0.65, 0.95))
	_draw_meter(c, font, dx, bar_y + 58, 200, "defense", defense, Color(0.95, 0.35, 0.30))
	_draw_meter(c, font, dx, bar_y + 80, 200, "waste", waste, Color(0.70, 0.55, 0.30))

	# --- controller readouts ---
	var rx := dx + 220
	if rx + 160 < size.x:
		c.draw_string(font, Vector2(rx, bar_y), "CONTROLLER", HORIZONTAL_ALIGNMENT_LEFT, -1, fs_sm, Color(0.9, 0.82, 0.6))
		c.draw_string(font, Vector2(rx, bar_y + 20), "JH scale  %.2f" % jh_scale, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.95, 0.88, 0.55))
		c.draw_string(font, Vector2(rx, bar_y + 40), "soldier bar  %.1f" % float(th.get("high", 22)), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.95, 0.55, 0.45))
		c.draw_string(font, Vector2(rx, bar_y + 60), "forager bar  %.1f" % float(th.get("mid", 19)), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.55, 0.85, 0.50))
		var urg_f: int = int(h.call("idle_urgency", 2)) if h.has_method("idle_urgency") else 0  # FORAGER=2
		var urg_n: int = int(h.call("idle_urgency", 4)) if h.has_method("idle_urgency") else 0  # NURSE=4
		c.draw_string(font, Vector2(rx, bar_y + 80), "idle urg  F%d N%d" % [urg_f, urg_n], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.8, 0.75, 0.65))

	# --- nutrition / JH histogram ---
	var hist := _larva_hist()
	var hy := size.y - 150.0 if mode == Mode.HISTOGRAM else size.y - 120.0
	var hh := 95.0 if mode == Mode.HISTOGRAM else 70.0
	c.draw_rect(Rect2(12, hy - 18, size.x - 24, hh + 28), Color(0.04, 0.03, 0.02, 0.55))
	c.draw_string(font, Vector2(20, hy - 2), "LARVAE — nutrition (amber) · juvenile hormone (violet)", HORIZONTAL_ALIGNMENT_LEFT, -1, fs_sm, Color(0.9, 0.82, 0.65))
	_draw_hist(c, Rect2(20, hy + 8, size.x - 40, hh), hist["nutrition"], Color(0.95, 0.72, 0.25, 0.85))
	_draw_hist(c, Rect2(20, hy + 8, size.x - 40, hh), hist["jh"], Color(0.65, 0.40, 0.95, 0.55))
	c.draw_string(font, Vector2(20, hy + hh + 4), "n=%d  mean nut %.1f  mean JH %.1f  → score = nut + 2·JH  (vs bars above)" % [
		hist["count"], hist["mean_nut"], hist["mean_jh"]
	], HORIZONTAL_ALIGNMENT_LEFT, -1, fs_sm, Color(0.78, 0.72, 0.60))

	# footer legend
	c.draw_string(font, Vector2(16, size.y - 14), "pressure +deficit / −surplus   ·   bars: live vs target   ·   loop: census → destiny + JH + urgency", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.65, 0.60, 0.50))

func _config() -> Object:
	var cfg := get_tree().root.get_node_or_null("Config")
	if cfg == null:
		return null
	return cfg.get("data")

func _draw_caste_bar(c: Control, font: Font, x: float, y: float, w: float, name: String, count: int, target: int, col: Color, pressure: float) -> void:
	var max_v := maxi(target * 2, maxi(count, 1))
	var fill_w := w * (float(count) / float(max_v))
	var tgt_x := x + w * (float(target) / float(max_v))
	c.draw_rect(Rect2(x, y + 4, w, 14), Color(0.15, 0.12, 0.10, 0.9))
	c.draw_rect(Rect2(x, y + 4, fill_w, 14), col)
	c.draw_line(Vector2(tgt_x, y + 2), Vector2(tgt_x, y + 20), Color(1, 1, 1, 0.85), 2.0)
	var pcol := Color(0.4, 0.9, 0.5) if pressure < -0.05 else (Color(0.95, 0.45, 0.35) if pressure > 0.05 else Color(0.7, 0.7, 0.65))
	var ptxt := "%+.2f" % pressure
	c.draw_string(font, Vector2(x, y), "%s  %d / %d   pressure %s" % [name, count, target, ptxt], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, pcol)

func _draw_meter(c: Control, font: Font, x: float, y: float, w: float, name: String, v: float, col: Color) -> void:
	c.draw_rect(Rect2(x + 70, y, w, 12), Color(0.15, 0.12, 0.10, 0.9))
	c.draw_rect(Rect2(x + 70, y, w * clampf(v, 0.0, 1.0), 12), col)
	c.draw_string(font, Vector2(x, y + 10), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.85, 0.8, 0.7))

func _larva_hist() -> Dictionary:
	var nuts: Array = []
	var jhs: Array = []
	var sum_n := 0.0
	var sum_j := 0.0
	if colony != null:
		for a in colony.get("ants"):
			if a == null or not a.alive:
				continue
			if int(a.caste) != 5:  # LARVA
				continue
			var n: float = float(a.nutrition)
			var j: float = float(a.jh_dose)
			nuts.append(n)
			jhs.append(j)
			sum_n += n
			sum_j += j
	var count := nuts.size()
	return {
		"nutrition": _bucket(nuts, 0.0, 30.0, 16),
		"jh": _bucket(jhs, 0.0, 12.0, 16),
		"count": count,
		"mean_nut": (sum_n / count) if count > 0 else 0.0,
		"mean_jh": (sum_j / count) if count > 0 else 0.0,
	}

func _bucket(vals: Array, lo: float, hi: float, n: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	out.fill(0.0)
	if vals.is_empty() or hi <= lo:
		return out
	for v in vals:
		var t := clampf((float(v) - lo) / (hi - lo), 0.0, 0.999)
		var i := int(t * n)
		out[i] += 1.0
	var mx := 1.0
	for x in out:
		mx = maxf(mx, x)
	for i in n:
		out[i] /= mx
	return out

func _draw_hist(c: Control, rect: Rect2, bins: PackedFloat32Array, col: Color) -> void:
	if bins.is_empty():
		return
	var n := bins.size()
	var bw := rect.size.x / float(n)
	for i in n:
		var h := rect.size.y * bins[i]
		if h < 1.0:
			continue
		c.draw_rect(Rect2(rect.position.x + i * bw + 1.0, rect.position.y + rect.size.y - h, bw - 2.0, h), col)

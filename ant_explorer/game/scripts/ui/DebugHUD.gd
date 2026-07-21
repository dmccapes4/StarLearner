extends CanvasLayer
## Debug HUD: sim, population, garden, invaders.

@onready var label: Label = $Margin/Label

func _ready() -> void:
	Events.sim_debug_updated.connect(_on_sim_debug)
	layer = 100

func _on_sim_debug(tick: int, hz: float) -> void:
	if label == null:
		return
	var world := get_tree().get_first_node_in_group("world")
	var living := "?"
	var brood_n := "?"
	var garden_h := "?"
	var inv := "—"
	var role := "none"
	if world and world.get("colony"):
		var c: Colony = world.colony
		living = str(c.living_count())
		if c.brood:
			brood_n = str(c.brood.living_brood())
		if c.garden:
			garden_h = "%.2f" % c.garden.health
		if c.invaders:
			var n := c.invaders.active_count()
			if n > 0:
				inv = "%d %s" % [n, c.invaders._phase]
		var p := c.get_player()
		if p:
			role = AntEnums.role_name(p.role)
			if role.is_empty():
				role = "none"
	# `tick` is the discrete sim step counter (Config.sim_hz steps/sec), not
	# wall-clock seconds — at 2.5Hz it advances ~2–3 per real second.
	var sim_hz: float = Config.get_sim_hz() if Config else 2.5
	var sim_sec: float = float(tick) / maxf(sim_hz, 0.001)
	label.text = "%.0fs | tick %d | %.1fHz | ants %s | brood %s | garden %s | role %s | inv %s" % [
		sim_sec, tick, hz, living, brood_n, garden_h, role, inv
	]

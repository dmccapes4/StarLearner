extends RefCounted
## Soak: one simulated hour with the closed-loop controller ON.
##
## Unit tests prove correct-sign response; this proves bounded self-regulation —
## the property the gift needs on a phone we can't easily patch mid-birthday.
##
## Kill-switch: Config.data.homeo_enabled = false (or Homeostasis.enabled).

var _tree: Node

func _init(tree: Node) -> void:
	_tree = tree

func run() -> TestAssert:
	var t := TestAssert.new("HomeostasisSoak")
	# Shipped product: real algorithm, flag on.
	t.ok(Config.data.homeo_enabled, "config ships homeo_enabled=true")
	t.gt(Config.data.homeo_caste_bias_strength, 0.0, "caste bias armed")
	t.gt(Config.data.homeo_jh_bias_strength, 0.0, "JH bias armed")

	var colony: Colony = TestHarness.make_colony_phase2(_tree)
	t.ok(colony.homeostasis.enabled, "colony boots with homeostasis enabled")
	# Keep invaders from injecting noise into a long soak.
	if colony.invaders:
		colony.invaders.cooldown = 999999

	var hz: float = maxf(Config.get_sim_hz(), 0.5)
	var hour_ticks: int = int(ceil(3600.0 * hz))  # one simulated hour
	var sample_every: int = maxi(1, hour_ticks / 120)  # ~120 samples

	var t_sol: int = Config.data.target_soldiers
	var t_for: int = Config.data.target_foragers
	var t_min: int = Config.data.target_minors

	var min_sol := 9999
	var max_sol := 0
	var min_for := 9999
	var max_for := 0
	var min_minors := 9999
	var max_minors := 0
	var min_adults := 9999
	var min_garden := 999.0
	var extinct_streak := 0
	var max_extinct_streak := 0
	var samples := 0

	for tick in hour_ticks:
		colony.on_sim_tick(tick)
		if tick % sample_every != 0 and tick != hour_ticks - 1:
			continue
		var h: Homeostasis = colony.homeostasis
		h.tick(colony)  # ensure census fresh for this sample
		samples += 1
		min_sol = mini(min_sol, h.soldiers)
		max_sol = maxi(max_sol, h.soldiers)
		min_for = mini(min_for, h.foragers)
		max_for = maxi(max_for, h.foragers)
		min_minors = mini(min_minors, h.minors)
		max_minors = maxi(max_minors, h.minors)
		var adults: int = h.soldiers + h.foragers + h.minors
		min_adults = mini(min_adults, adults)
		if colony.garden:
			min_garden = minf(min_garden, colony.garden.health)
		# Any adult caste at 0 is a soft extinction sample.
		if h.soldiers == 0 or h.foragers == 0 or h.minors == 0:
			extinct_streak += 1
			max_extinct_streak = maxi(max_extinct_streak, extinct_streak)
		else:
			extinct_streak = 0

	print("HomeostasisSoak: %d ticks (%.0fs @ %.1fHz), %d samples" % [
		hour_ticks, float(hour_ticks) / hz, hz, samples
	])
	print("  soldiers %d..%d (target %d)" % [min_sol, max_sol, t_sol])
	print("  foragers %d..%d (target %d)" % [min_for, max_for, t_for])
	print("  minors   %d..%d (target %d)" % [min_minors, max_minors, t_min])
	print("  min adults %d  min garden %.2f  max extinct streak %d" % [
		min_adults, min_garden, max_extinct_streak
	])

	# Bounded self-regulation — not “hits the target,” but “doesn’t blow up.”
	t.gt(samples, 50, "enough samples across the hour")
	t.gt(min_adults, 8, "adult population never collapses")
	t.gt(min_for, 0, "foragers never fully extinct")
	t.gt(min_minors, 0, "minors never fully extinct")
	# Soldiers can dip under pressure, but must not stay gone for the whole soak.
	t.gt(max_sol, 0, "soldiers appear during the soak")
	t.lt(max_sol, t_sol * 3 + 4, "soldiers stay under ~3× target (no runaway caste)")
	t.lt(max_for, t_for * 3 + 8, "foragers stay under ~3× target")
	t.lt(max_minors, t_min * 3 + 8, "minors stay under ~3× target")
	t.lt(max_extinct_streak, 8, "no long streak with a caste missing")
	t.gt(min_garden, 0.05, "garden health stays above collapse floor")

	# Kill-switch still reverts destiny to fixed thresholds mid-run.
	var saved := Config.data.homeo_enabled
	Config.data.homeo_enabled = false
	colony.homeostasis.tick(colony)
	t.ok(not colony.homeostasis.enabled, "kill-switch flips enabled off via config")
	var larva := AntState.new()
	larva.nutrition = 30.0
	larva.jh_dose = 8.0
	# With homeo off, extreme surplus pressure must NOT bend the bar.
	colony.homeostasis.soldier_pressure = -1.0
	var caste_off: int = colony.brood.decide_caste(larva)
	t.eq(caste_off, AntEnums.Caste.SOLDIER, "kill-switch: fixed high threshold still yields soldier")
	Config.data.homeo_enabled = saved
	colony.homeostasis.tick(colony)
	t.ok(colony.homeostasis.enabled, "kill-switch restored")

	return t

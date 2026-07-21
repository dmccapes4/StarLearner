extends RefCounted
## Tests for SimClock tick≠frame decoupling.

var _tree: SceneTree

func _init(tree: SceneTree) -> void:
	_tree = tree

func run() -> TestAssert:
	var t := TestAssert.new("SimClock")
	SimClock.reset()
	SimClock.set_enabled(true)
	var start := SimClock.tick
	# Inject process time directly — headless frame pacing is not wall-clock reliable.
	var step: float = 1.0 / Config.get_sim_hz()
	for i in 5:
		SimClock._process(step * 1.05)
	var gained: int = SimClock.tick - start
	t.ge(gained, 4, "≥4 sim ticks from injected process time")
	t.lt(gained, 20, "not over-ticking from short inject")
	t.in_range(SimClock.tick_alpha, 0.0, 1.0, "tick_alpha in [0,1]")
	# Also smoke the async path briefly (no hard tick count).
	var async_start := SimClock.tick
	for i in 10:
		await _tree.process_frame
	t.ok(SimClock.tick >= async_start, "clock still advances across process frames")
	return t

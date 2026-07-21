extends RefCounted
## IdlePolicy warn / exit thresholds for kiosk idle exit.

const Policy := preload("res://scripts/system/IdlePolicy.gd")

func run() -> TestAssert:
	var t := TestAssert.new("IdlePolicy")
	t.ok(not Policy.should_warn(0.0, false), "no warn at start")
	t.ok(not Policy.should_exit(0.0), "no exit at start")
	t.ok(not Policy.should_warn(Policy.WARN_SECONDS - 1.0, false), "no warn before threshold")
	t.ok(Policy.should_warn(Policy.WARN_SECONDS, false), "warn at 4.5 min")
	t.ok(not Policy.should_warn(Policy.WARN_SECONDS, true), "warn only once")
	t.ok(not Policy.should_exit(Policy.EXIT_SECONDS - 1.0), "no exit before 5 min")
	t.ok(Policy.should_exit(Policy.EXIT_SECONDS), "exit at 5 min")
	t.ok(Policy.EXIT_SECONDS > Policy.WARN_SECONDS, "warn before exit")
	# SimClock disable clears catch-up accum.
	SimClock.set_enabled(true)
	SimClock._accum = 0.5
	SimClock.set_enabled(false)
	t.eq(SimClock._accum, 0.0, "disable clears accum (no catch-up after sleep)")
	t.ok(not SimClock.is_enabled(), "clock disabled")
	SimClock.set_enabled(true)
	t.ok(SimClock.is_enabled(), "clock re-enabled")
	return t

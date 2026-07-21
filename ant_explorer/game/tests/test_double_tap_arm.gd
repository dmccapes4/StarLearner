extends RefCounted
## DoubleTapArm — arm + 1.0 s timeout state machine (not an OS double-click).

const Arm := preload("res://scripts/ui/DoubleTapArm.gd")

func run() -> TestAssert:
	var t := TestAssert.new("DoubleTapArm")

	var a := Arm.new(1.0)
	t.ok(not a.is_armed(), "starts unarmed")

	# First tap arms; second tap within window triggers.
	t.eq(a.press("01_queen", 0.0), Arm.RESULT_ARMED, "first tap arms")
	t.ok(a.is_armed_for("01_queen"), "armed for tapped key")
	t.eq(a.press("01_queen", 0.5), Arm.RESULT_TRIGGER, "second tap within window triggers")
	t.ok(not a.is_armed(), "trigger clears arm")

	# Boundary: exactly at window still triggers (<=).
	a.clear()
	a.press("x", 10.0)
	t.eq(a.press("x", 11.0), Arm.RESULT_TRIGGER, "tap at exactly window triggers")

	# Slow second tap past window re-arms instead of triggering.
	a.clear()
	a.press("y", 0.0)
	t.eq(a.press("y", 1.5), Arm.RESULT_ARMED, "tap past window re-arms (no trigger)")
	t.ok(a.is_armed_for("y"), "still armed after re-arm")

	# Different key cancels the previous arm (only one armed at a time).
	a.clear()
	a.press("a", 0.0)
	t.eq(a.press("b", 0.2), Arm.RESULT_ARMED, "different key arms, not trigger")
	t.ok(a.is_armed_for("b"), "now armed for the new key")
	t.ok(not a.is_armed_for("a"), "previous key no longer armed")

	# poll() clears once the window elapses.
	a.clear()
	a.press("z", 0.0)
	t.ok(not a.poll(0.9), "poll before timeout keeps arm")
	t.ok(a.is_armed(), "still armed just before timeout")
	t.ok(a.poll(1.2), "poll after timeout clears and reports expiry")
	t.ok(not a.is_armed(), "unarmed after timeout")
	t.ok(not a.poll(2.0), "poll when unarmed does nothing")

	return t

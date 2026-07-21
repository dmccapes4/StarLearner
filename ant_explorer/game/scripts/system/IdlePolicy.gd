class_name IdlePolicy
extends RefCounted
## Pure timing rules for kiosk idle exit (easy to unit-test).

## Soft prompt so a nearby child can keep playing.
const WARN_SECONDS := 270.0  ## 4.5 minutes
## Save + return to Star Learner.
const EXIT_SECONDS := 300.0  ## 5 minutes

static func should_warn(idle_seconds: float, already_warned: bool) -> bool:
	return (not already_warned) and idle_seconds >= WARN_SECONDS

static func should_exit(idle_seconds: float) -> bool:
	return idle_seconds >= EXIT_SECONDS

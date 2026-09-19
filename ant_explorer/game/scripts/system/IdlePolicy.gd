class_name IdlePolicy
extends RefCounted
## Timing for kiosk idle (kept for unit tests / legacy callers).

const WARN_SECONDS := 60.0   ## show PAUSED
const EXIT_SECONDS := 300.0  ## return to Star Learner

static func should_warn(idle_seconds: float, already_warned: bool) -> bool:
	return (not already_warned) and idle_seconds >= WARN_SECONDS

static func should_exit(idle_seconds: float) -> bool:
	return idle_seconds >= EXIT_SECONDS

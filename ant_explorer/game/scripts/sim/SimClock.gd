extends Node
## Autoload: fixed-rate sim clock (Config.sim_hz). Frames only render/interpolate.

signal sim_tick(tick: int)

var tick: int = 0
var _accum: float = 0.0
var _step: float = 0.2
var _enabled: bool = true
## When false, APPLICATION_PAUSED must not freeze the clock (MovieWriter demos).
var _gate_on_app_pause: bool = true
## 0..1 progress toward the next sim tick (for render interpolation).
var tick_alpha: float = 0.0

# Rolling window for acceptance / debug HUD (verify Config.sim_hz).
var _hz_window_ticks: int = 0
var _hz_window_time: float = 0.0
var measured_hz: float = 0.0

func _ready() -> void:
	# Keep processing while the tree is paused for VO/video, but IdleGuard
	# disables us when the app is backgrounded / screen-off.
	process_mode = Node.PROCESS_MODE_ALWAYS
	# --write-movie often runs unfocused; never freeze the colony for demos.
	if OS.has_feature("movie"):
		set_gate_on_app_pause(false)

func _process(delta: float) -> void:
	if not _enabled:
		return
	var hz: float = Config.get_sim_hz()
	if hz <= 0.0:
		return
	_step = 1.0 / hz
	_accum += delta
	_hz_window_time += delta
	# Catch up a few ticks if we hitch; never spiral.
	var safety := 0
	while _accum >= _step and safety < 8:
		_accum -= _step
		tick += 1
		_hz_window_ticks += 1
		sim_tick.emit(tick)
		safety += 1
	tick_alpha = clampf(_accum / _step, 0.0, 1.0)
	if _hz_window_time >= 1.0:
		measured_hz = float(_hz_window_ticks) / _hz_window_time
		Events.sim_debug_updated.emit(tick, measured_hz)
		_hz_window_ticks = 0
		_hz_window_time = 0.0

func set_enabled(on: bool) -> void:
	_enabled = on
	if not on:
		# Drop partial tick progress so a long sleep cannot burst-catch-up.
		_accum = 0.0
		tick_alpha = 0.0

func is_enabled() -> bool:
	return _enabled

func set_gate_on_app_pause(on: bool) -> void:
	_gate_on_app_pause = on
	if not on:
		set_enabled(true)

func is_gate_on_app_pause() -> bool:
	return _gate_on_app_pause

func reset() -> void:
	tick = 0
	_accum = 0.0
	_hz_window_ticks = 0
	_hz_window_time = 0.0
	measured_hz = 0.0
	_enabled = true
	if OS.has_feature("movie"):
		_gate_on_app_pause = false

func _notification(what: int) -> void:
	# Never tick while the OS has us backgrounded (power button / app switch).
	# IdleGuard also gates this; both paths are intentional.
	# MovieWriter / demo recording keeps the gate off so an unfocused
	# recorder window cannot freeze the colony mid-take.
	if not _gate_on_app_pause:
		return
	if what == NOTIFICATION_APPLICATION_PAUSED:
		set_enabled(false)
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		set_enabled(true)

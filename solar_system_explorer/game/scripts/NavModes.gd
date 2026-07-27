class_name NavModes
extends RefCounted
## Navigation rendering mode for MISSION flights, chosen on the title screen
## and persisted.
##   MARKERS    — 2D markers in 3D space (constant-size icons, fly-by meshes)
##   SIM_VIEW   — actual simulation rendering (true angular size + brightness)
## The free-flight playground is NOT a rendering mode any more — it has its
## own tile on the FlightChooser screen (the constant stays for its label).

const MODE_MARKERS := 0
const MODE_SIM_VIEW := 1
const MODE_PLAYGROUND := 2

const SAVE_PATH := "user://nav_mode.json"

static var _mode: int = -1

static func mode() -> int:
	if _mode < 0:
		_mode = _load()
	return _mode

static func set_mode(m: int) -> void:
	_mode = clampi(m, MODE_MARKERS, MODE_SIM_VIEW)
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"mode": _mode}))

static func cycle() -> int:
	set_mode((mode() + 1) % 2)
	return _mode

static func label(m: int = -1) -> String:
	match (m if m >= 0 else mode()):
		MODE_SIM_VIEW:
			return "Real view"
		MODE_PLAYGROUND:
			return "Free flight"
		_:
			return "Marker view"

static func _load() -> int:
	if not FileAccess.file_exists(SAVE_PATH):
		return MODE_MARKERS
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return MODE_MARKERS
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return MODE_MARKERS
	var m := int(parsed.get("mode", MODE_MARKERS))
	# A stale persisted PLAYGROUND (it used to live in this cycle) → default.
	if m < MODE_MARKERS or m > MODE_SIM_VIEW:
		return MODE_MARKERS
	return m

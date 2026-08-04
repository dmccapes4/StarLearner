class_name GardenState
extends RefCounted
## Per-bed planting: one crop fills all four plots and they mature together.
## Growth: water once per stage → wait plant interval → advance (seed→sprout→
## growing→grown). One thirst / harvest-ready signal per bed.

signal changed(bed_id: String, slot: int)
signal stage_advanced(bed_id: String, slot: int, plant_id: String, stage: String)
signal thirst_changed(bed_id: String, slot: int, thirsty: bool)
signal bed_changed(bed_id: String)

const STAGE_EMPTY := ""
const STAGE_SEED := "seed"
const STAGE_SPROUT := "sprout"
const STAGE_GROWING := "growing"
const STAGE_GROWN := "grown"

var slots_per_bed: int = 4
var beds: Dictionary = {} ## bed_id -> Array[Dictionary]

func setup(bed_ids: PackedStringArray, slots: int = 4) -> void:
	slots_per_bed = slots
	beds.clear()
	for id in bed_ids:
		var arr: Array = []
		for i in slots_per_bed:
			arr.append(_empty_slot())
		beds[str(id)] = arr

func _empty_slot() -> Dictionary:
	return {
		"plant_id": "",
		"stage": STAGE_EMPTY,
		"waters": 0,
		"stage_time": 0.0,
		"thirsty": false,
		"thirst_cd": 0.0,
		"awaiting_media": "",
		"watered_stage": false,
	}

func get_slot(bed_id: String, slot: int) -> Dictionary:
	var arr: Array = beds.get(bed_id, [])
	if slot < 0 or slot >= arr.size():
		return {}
	return arr[slot]

func is_empty(bed_id: String, slot: int = 0) -> bool:
	var s := get_slot(bed_id, slot)
	return s.is_empty() or str(s.get("plant_id", "")).is_empty()

func is_bed_empty(bed_id: String) -> bool:
	return occupied_count(bed_id) == 0

func is_thirsty(bed_id: String, slot: int = 0) -> bool:
	var s := get_slot(bed_id, slot)
	return not s.is_empty() and bool(s.get("thirsty", false))

func is_bed_thirsty(bed_id: String) -> bool:
	return is_thirsty(bed_id, 0) and not is_bed_empty(bed_id)

func is_harvestable(bed_id: String, slot: int = 0) -> bool:
	var s := get_slot(bed_id, slot)
	if s.is_empty() or str(s.get("plant_id", "")).is_empty():
		return false
	return str(s.get("stage", "")) == STAGE_GROWN

func is_bed_harvestable(bed_id: String) -> bool:
	return is_harvestable(bed_id, 0)

func bed_plant_id(bed_id: String) -> String:
	return str(get_slot(bed_id, 0).get("plant_id", ""))

func bed_stage(bed_id: String) -> String:
	return str(get_slot(bed_id, 0).get("stage", ""))

func bed_awaiting_media(bed_id: String) -> String:
	return str(get_slot(bed_id, 0).get("awaiting_media", ""))

func first_empty_slot(bed_id: String) -> int:
	## Per-bed planting: empty bed → slot 0; otherwise full.
	return 0 if is_bed_empty(bed_id) else -1

func occupied_count(bed_id: String) -> int:
	var n := 0
	var arr: Array = beds.get(bed_id, [])
	for s in arr:
		if not str(s.get("plant_id", "")).is_empty():
			n += 1
	return n

func plant(bed_id: String, slot: int, plant_id: String) -> bool:
	## Legacy single-slot API — redirects to plant_bed.
	return plant_bed(bed_id, plant_id)

func plant_bed(bed_id: String, plant_id: String) -> bool:
	if not beds.has(bed_id) or plant_id.is_empty():
		return false
	if not is_bed_empty(bed_id):
		return false
	for i in slots_per_bed:
		beds[bed_id][i] = {
			"plant_id": plant_id,
			"stage": STAGE_SEED,
			"waters": 0,
			"stage_time": 0.0,
			"thirsty": true,
			"thirst_cd": 0.0,
			"awaiting_media": "",
			"watered_stage": false,
		}
		changed.emit(bed_id, i)
		thirst_changed.emit(bed_id, i, true)
	bed_changed.emit(bed_id)
	return true

func uproot(bed_id: String, slot: int) -> String:
	return uproot_bed(bed_id)

func uproot_bed(bed_id: String) -> String:
	if is_bed_empty(bed_id):
		return ""
	var pid := bed_plant_id(bed_id)
	for i in slots_per_bed:
		beds[bed_id][i] = _empty_slot()
		changed.emit(bed_id, i)
	bed_changed.emit(bed_id)
	return pid

func tick(delta: float, seed_db: SeedDB) -> void:
	if delta <= 0.0 or seed_db == null:
		return
	for bed_id in beds.keys():
		if is_bed_empty(str(bed_id)):
			continue
		## Sync off slot 0 — all plots share the same clock.
		var s: Dictionary = beds[bed_id][0]
		var stage := str(s.get("stage", STAGE_SEED))
		if stage == STAGE_GROWN:
			continue
		## Time only counts after this stage has been watered.
		if bool(s.get("watered_stage", false)) and not bool(s.get("thirsty", false)):
			s["stage_time"] = float(s.get("stage_time", 0.0)) + delta
			beds[bed_id][0] = s
			_sync_slots_from_lead(str(bed_id))
			_try_advance_bed(str(bed_id), seed_db)

func water(bed_id: String, slot: int, seed_db: SeedDB) -> Dictionary:
	## Legacy — water whole bed.
	return water_bed(bed_id, seed_db)

func water_bed(bed_id: String, seed_db: SeedDB) -> Dictionary:
	var empty := {"ok": false, "plant_id": "", "stage": "", "advanced": false}
	if is_bed_empty(bed_id):
		return empty
	var s: Dictionary = beds[bed_id][0]
	var pid := str(s.get("plant_id", ""))
	var stage := str(s.get("stage", STAGE_SEED))
	if stage == STAGE_GROWN:
		return {"ok": true, "plant_id": pid, "stage": stage, "advanced": false, "already_grown": true}
	if not bool(s.get("thirsty", false)):
		return {"ok": false, "plant_id": pid, "stage": stage, "advanced": false, "not_thirsty": true}
	## One water per stage starts the growth timer.
	s["waters"] = 1
	s["thirsty"] = false
	s["watered_stage"] = true
	s["stage_time"] = 0.0
	s["thirst_cd"] = 0.0
	beds[bed_id][0] = s
	_sync_slots_from_lead(bed_id)
	for i in slots_per_bed:
		changed.emit(bed_id, i)
		thirst_changed.emit(bed_id, i, false)
	bed_changed.emit(bed_id)
	return {
		"ok": true,
		"plant_id": pid,
		"stage": stage,
		"advanced": false,
		"waters": 1,
	}

func harvest(bed_id: String, slot: int) -> String:
	return harvest_bed(bed_id)

func harvest_bed(bed_id: String) -> String:
	if not is_bed_harvestable(bed_id):
		return ""
	var pid := bed_plant_id(bed_id)
	for i in slots_per_bed:
		beds[bed_id][i] = _empty_slot()
		changed.emit(bed_id, i)
	bed_changed.emit(bed_id)
	return pid

func clear_awaiting_media(bed_id: String, slot: int = 0) -> void:
	if is_bed_empty(bed_id):
		return
	var s: Dictionary = beds[bed_id][0]
	s["awaiting_media"] = ""
	beds[bed_id][0] = s
	_sync_slots_from_lead(bed_id)
	for i in slots_per_bed:
		changed.emit(bed_id, i)

func _sync_slots_from_lead(bed_id: String) -> void:
	var lead: Dictionary = beds[bed_id][0].duplicate(true)
	for i in range(1, slots_per_bed):
		beds[bed_id][i] = lead.duplicate(true)

func _try_advance_bed(bed_id: String, seed_db: SeedDB) -> bool:
	var s: Dictionary = beds[bed_id][0]
	var pid := str(s.get("plant_id", ""))
	if pid.is_empty():
		return false
	var stage := str(s.get("stage", STAGE_SEED))
	if stage == STAGE_GROWN:
		return false
	if not bool(s.get("watered_stage", false)):
		return false
	var plant: Dictionary = seed_db.get_plant(pid) if seed_db else {}
	var min_t := _seconds_needed(stage, plant)
	if float(s.get("stage_time", 0.0)) < min_t:
		return false
	var nxt := _next_stage(stage)
	if nxt.is_empty():
		return false
	s["stage"] = nxt
	s["waters"] = 0
	s["stage_time"] = 0.0
	s["watered_stage"] = false
	s["thirsty"] = nxt != STAGE_GROWN
	s["thirst_cd"] = 0.0
	if nxt == STAGE_SPROUT or nxt == STAGE_GROWN:
		s["awaiting_media"] = nxt
	else:
		s["awaiting_media"] = ""
	beds[bed_id][0] = s
	_sync_slots_from_lead(bed_id)
	for i in slots_per_bed:
		changed.emit(bed_id, i)
		thirst_changed.emit(bed_id, i, bool(s["thirsty"]))
		stage_advanced.emit(bed_id, i, pid, nxt)
	bed_changed.emit(bed_id)
	return true

## Kept for tests that call advance on a single slot after forcing times.
func _try_advance(bed_id: String, slot: int, seed_db: SeedDB) -> bool:
	if slot != 0:
		_sync_slots_from_lead(bed_id)
	return _try_advance_bed(bed_id, seed_db)

func _next_stage(stage: String) -> String:
	match stage:
		STAGE_SEED:
			return STAGE_SPROUT
		STAGE_SPROUT:
			return STAGE_GROWING
		STAGE_GROWING:
			return STAGE_GROWN
		_:
			return ""

func _seconds_needed(stage: String, plant: Dictionary) -> float:
	match stage:
		STAGE_SEED:
			return maxf(0.5, float(plant.get("seconds_seed", 6.0)))
		STAGE_SPROUT:
			return maxf(0.5, float(plant.get("seconds_sprout", 8.0)))
		STAGE_GROWING:
			return maxf(0.5, float(plant.get("seconds_growing", 10.0)))
		_:
			return 999.0

func to_blob() -> Dictionary:
	var out := {}
	for bed_id in beds.keys():
		var arr: Array = []
		for s in beds[bed_id]:
			arr.append({
				"plant_id": str(s.get("plant_id", "")),
				"stage": str(s.get("stage", "")),
				"waters": int(s.get("waters", 0)),
				"stage_time": float(s.get("stage_time", 0.0)),
				"thirsty": bool(s.get("thirsty", false)),
				"thirst_cd": float(s.get("thirst_cd", 0.0)),
				"awaiting_media": str(s.get("awaiting_media", "")),
				"watered_stage": bool(s.get("watered_stage", false)),
			})
		out[str(bed_id)] = arr
	return out

func from_blob(blob: Dictionary) -> void:
	if blob.is_empty():
		return
	for bed_id in beds.keys():
		if not blob.has(bed_id):
			continue
		var src: Array = blob[bed_id]
		var dst: Array = beds[bed_id]
		for i in mini(src.size(), dst.size()):
			var s: Dictionary = src[i]
			var waters := int(s.get("waters", 0))
			if s.has("progress") and waters == 0:
				waters = int(float(s.get("progress", 0)) / 6.0)
			var stage := str(s.get("stage", ""))
			var pid := str(s.get("plant_id", ""))
			dst[i] = {
				"plant_id": pid,
				"stage": stage,
				"waters": waters,
				"stage_time": float(s.get("stage_time", 0.0)),
				"thirsty": bool(s.get("thirsty", stage != STAGE_GROWN and not pid.is_empty())),
				"thirst_cd": float(s.get("thirst_cd", 0.0)),
				"awaiting_media": str(s.get("awaiting_media", "")),
				"watered_stage": bool(s.get("watered_stage", waters > 0 and not bool(s.get("thirsty", false)))),
			}
		## Force sync: prefer first occupied / lead slot as bed crop.
		_normalize_bed(str(bed_id))
		for i in slots_per_bed:
			changed.emit(str(bed_id), i)

func _normalize_bed(bed_id: String) -> void:
	## Mixed legacy saves → take first non-empty plant and fill the bed.
	var lead_pid := ""
	var lead: Dictionary = {}
	var arr: Array = beds[bed_id]
	for s in arr:
		if not str(s.get("plant_id", "")).is_empty():
			lead_pid = str(s.get("plant_id", ""))
			lead = s.duplicate(true)
			break
	if lead_pid.is_empty():
		for i in slots_per_bed:
			beds[bed_id][i] = _empty_slot()
		return
	for i in slots_per_bed:
		beds[bed_id][i] = lead.duplicate(true)

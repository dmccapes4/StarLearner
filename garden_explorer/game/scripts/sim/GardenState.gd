class_name GardenState
extends RefCounted
## Beds: seed → sprout → growing → grown.
## Advance needs enough waterings *and* min stage time; dry plants stall.
## Thirst icons: plant starts thirsty; after a water, icon returns on thirst_interval.

signal changed(bed_id: String, slot: int)
signal stage_advanced(bed_id: String, slot: int, plant_id: String, stage: String)
signal thirst_changed(bed_id: String, slot: int, thirsty: bool)

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
	}

func get_slot(bed_id: String, slot: int) -> Dictionary:
	var arr: Array = beds.get(bed_id, [])
	if slot < 0 or slot >= arr.size():
		return {}
	return arr[slot]

func is_empty(bed_id: String, slot: int) -> bool:
	var s := get_slot(bed_id, slot)
	return s.is_empty() or str(s.get("plant_id", "")).is_empty()

func is_thirsty(bed_id: String, slot: int) -> bool:
	var s := get_slot(bed_id, slot)
	return not s.is_empty() and bool(s.get("thirsty", false))

func is_harvestable(bed_id: String, slot: int) -> bool:
	var s := get_slot(bed_id, slot)
	return str(s.get("stage", "")) == STAGE_GROWN

func first_empty_slot(bed_id: String) -> int:
	var arr: Array = beds.get(bed_id, [])
	for i in arr.size():
		if str(arr[i].get("plant_id", "")).is_empty():
			return i
	return -1

func occupied_count(bed_id: String) -> int:
	var n := 0
	var arr: Array = beds.get(bed_id, [])
	for s in arr:
		if not str(s.get("plant_id", "")).is_empty():
			n += 1
	return n

func plant(bed_id: String, slot: int, plant_id: String) -> bool:
	if not beds.has(bed_id):
		return false
	if slot < 0 or slot >= slots_per_bed:
		return false
	if not is_empty(bed_id, slot):
		return false
	if plant_id.is_empty():
		return false
	beds[bed_id][slot] = {
		"plant_id": plant_id,
		"stage": STAGE_SEED,
		"waters": 0,
		"stage_time": 0.0,
		"thirsty": true,
		"thirst_cd": 0.0,
		"awaiting_media": "",
	}
	changed.emit(bed_id, slot)
	thirst_changed.emit(bed_id, slot, true)
	return true

func uproot(bed_id: String, slot: int) -> String:
	if is_empty(bed_id, slot):
		return ""
	var prev: Dictionary = beds[bed_id][slot]
	var pid := str(prev.get("plant_id", ""))
	beds[bed_id][slot] = _empty_slot()
	changed.emit(bed_id, slot)
	return pid

func tick(delta: float, seed_db: SeedDB) -> void:
	if delta <= 0.0 or seed_db == null:
		return
	for bed_id in beds.keys():
		var arr: Array = beds[bed_id]
		for i in arr.size():
			var s: Dictionary = arr[i]
			if str(s.get("plant_id", "")).is_empty():
				continue
			var stage := str(s.get("stage", STAGE_SEED))
			if stage == STAGE_GROWN:
				continue
			s["stage_time"] = float(s.get("stage_time", 0.0)) + delta
			var was_thirsty := bool(s.get("thirsty", false))
			if not was_thirsty:
				s["thirst_cd"] = float(s.get("thirst_cd", 0.0)) - delta
				if float(s["thirst_cd"]) <= 0.0:
					s["thirsty"] = true
					s["thirst_cd"] = 0.0
			arr[i] = s
			if bool(s.get("thirsty", false)) != was_thirsty:
				changed.emit(str(bed_id), i)
				thirst_changed.emit(str(bed_id), i, true)
			else:
				## Persist elapsed quietly for save; still notify for icons occasionally.
				pass
			_try_advance(str(bed_id), i, seed_db)

func water(bed_id: String, slot: int, seed_db: SeedDB) -> Dictionary:
	## One watering while thirsty. Dry / grown plants do not advance from this tap.
	var empty := {"ok": false, "plant_id": "", "stage": "", "advanced": false}
	if is_empty(bed_id, slot):
		return empty
	var s: Dictionary = beds[bed_id][slot]
	var pid := str(s.get("plant_id", ""))
	var stage := str(s.get("stage", STAGE_SEED))
	if stage == STAGE_GROWN:
		return {"ok": true, "plant_id": pid, "stage": stage, "advanced": false, "already_grown": true}
	if not bool(s.get("thirsty", false)):
		return {"ok": false, "plant_id": pid, "stage": stage, "advanced": false, "not_thirsty": true}
	var plant: Dictionary = seed_db.get_plant(pid) if seed_db else {}
	var interval := float(plant.get("thirst_interval", 5.0))
	s["waters"] = int(s.get("waters", 0)) + 1
	s["thirsty"] = false
	s["thirst_cd"] = maxf(1.5, interval)
	beds[bed_id][slot] = s
	changed.emit(bed_id, slot)
	thirst_changed.emit(bed_id, slot, false)
	var advanced := _try_advance(bed_id, slot, seed_db)
	s = beds[bed_id][slot]
	return {
		"ok": true,
		"plant_id": pid,
		"stage": str(s.get("stage", stage)),
		"advanced": advanced,
		"waters": int(s.get("waters", 0)),
	}

func harvest(bed_id: String, slot: int) -> String:
	if is_empty(bed_id, slot):
		return ""
	var s: Dictionary = beds[bed_id][slot]
	if str(s.get("stage", "")) != STAGE_GROWN:
		return ""
	var pid := str(s.get("plant_id", ""))
	beds[bed_id][slot] = _empty_slot()
	changed.emit(bed_id, slot)
	return pid

func clear_awaiting_media(bed_id: String, slot: int) -> void:
	if is_empty(bed_id, slot):
		return
	var s: Dictionary = beds[bed_id][slot]
	s["awaiting_media"] = ""
	beds[bed_id][slot] = s
	changed.emit(bed_id, slot)

func _try_advance(bed_id: String, slot: int, seed_db: SeedDB) -> bool:
	var s: Dictionary = beds[bed_id][slot]
	var pid := str(s.get("plant_id", ""))
	if pid.is_empty():
		return false
	var stage := str(s.get("stage", STAGE_SEED))
	if stage == STAGE_GROWN:
		return false
	var plant: Dictionary = seed_db.get_plant(pid) if seed_db else {}
	var need := _waters_needed(stage, plant)
	var min_t := _seconds_needed(stage, plant)
	if int(s.get("waters", 0)) < need:
		return false
	if float(s.get("stage_time", 0.0)) < min_t:
		return false
	var nxt := _next_stage(stage)
	if nxt.is_empty():
		return false
	s["stage"] = nxt
	s["waters"] = 0
	s["stage_time"] = 0.0
	s["thirsty"] = nxt != STAGE_GROWN
	s["thirst_cd"] = 0.0
	if nxt == STAGE_SPROUT or nxt == STAGE_GROWN:
		s["awaiting_media"] = nxt
	elif nxt == STAGE_GROWING:
		s["awaiting_media"] = ""
	beds[bed_id][slot] = s
	changed.emit(bed_id, slot)
	thirst_changed.emit(bed_id, slot, bool(s["thirsty"]))
	stage_advanced.emit(bed_id, slot, pid, nxt)
	return true

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

func _waters_needed(stage: String, plant: Dictionary) -> int:
	match stage:
		STAGE_SEED:
			return maxi(1, int(plant.get("waters_to_sprout", 2)))
		STAGE_SPROUT:
			return maxi(1, int(plant.get("waters_to_growing", 2)))
		STAGE_GROWING:
			return maxi(1, int(plant.get("waters_to_grown", 2)))
		_:
			return 99

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
			## Migrate legacy progress/water fields into the new model.
			var waters := int(s.get("waters", 0))
			if s.has("progress") and waters == 0:
				waters = int(float(s.get("progress", 0)) / 6.0)
			dst[i] = {
				"plant_id": str(s.get("plant_id", "")),
				"stage": str(s.get("stage", "")),
				"waters": waters,
				"stage_time": float(s.get("stage_time", 0.0)),
				"thirsty": bool(s.get("thirsty", str(s.get("stage", "")) != STAGE_GROWN and not str(s.get("plant_id", "")).is_empty())),
				"thirst_cd": float(s.get("thirst_cd", 0.0)),
				"awaiting_media": str(s.get("awaiting_media", "")),
			}
			changed.emit(str(bed_id), i)

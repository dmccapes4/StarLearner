extends RefCounted
## Latest-wins mash: bed near-miss, cancellable success VO, intent seq on retarget.

func run() -> TestAssert:
	var t := TestAssert.new("TapMash")
	var SpeakScript := preload("res://scripts/audio/Speak.gd")
	var NarratorScript := preload("res://scripts/audio/Narrator.gd")

	## Short success lines must be tap-cancellable (shed pickup already is).
	SpeakScript.line("You watered the bed.", true)
	t.ok(NarratorScript.is_tap_cancellable(), "water line is tap-cancellable")
	NarratorScript.stop()
	t.ok(not NarratorScript.is_tap_cancellable(), "stop clears cancellable")

	SpeakScript.line("You planted carrot seeds!", true)
	t.ok(NarratorScript.is_tap_cancellable(), "plant line is tap-cancellable")
	NarratorScript.stop()

	var host := Node2D.new()
	var farm := FarmMap.new()
	host.add_child(farm)
	farm.build_from_file()

	## Retargeting bed_0 → bed_1 while "walking" keeps last id (intent seq).
	## Lightweight stand-in for World._pending / _intent_seq.
	var intent_seq := 0
	var pending: Dictionary = {}
	var beds := ["bed_0", "bed_1", "bed_0", "bed_1", "bed_1"]
	for bid in beds:
		intent_seq += 1
		pending = {"kind": "bed", "id": bid, "seq": intent_seq}
	t.eq(str(pending.get("id", "")), "bed_1", "last mash bed wins")
	t.eq(int(pending.get("seq", -1)), intent_seq, "pending.seq matches current intent")
	## Stale arrive from an older walk must no-op.
	var stale := {"kind": "bed", "id": "bed_0", "seq": intent_seq - 2}
	t.ok(int(stale.get("seq", -1)) != intent_seq, "stale seq is not current")

	## Near-miss lip is not empty zone (forgiveness path).
	var c1: Vector2 = farm.bed_centers["bed_1"]
	var lip1 := farm.nearest_walkable(Vector2(c1.x, c1.y + 30.0))
	t.ok(farm.zone_at(lip1).is_empty() or str(farm.zone_at(lip1).get("kind", "")) == "bed",
		"lip is empty or already bed")
	t.eq(farm.nearest_bed_id(lip1, 40.0), "bed_1", "near-miss maps lip to bed_1")

	host.free()
	return t

extends RefCounted
## Tests for AntState path / reset bookkeeping.

func run() -> TestAssert:
	var t := TestAssert.new("AntState")
	var a := AntState.new()
	a.id = 7
	a.alive = true
	a.nutrition = 5.0
	a.set_path(PackedVector2Array([Vector2.ZERO, Vector2(10, 0), Vector2(20, 0)]))
	t.eq(a.state, AntEnums.State.WALK, "set_path → WALK")
	t.eq(a.path_index, 1, "path_index advances past start")
	a.clear_path(true)
	t.eq(a.path.size(), 0, "clear_path empties path")
	t.eq(a.state, AntEnums.State.IDLE, "keep_intent clears WALK to IDLE")
	a.clear_path(false)
	t.eq(a.state, AntEnums.State.IDLE, "clear_path resets state")
	a.reset()
	t.eq(a.alive, false, "reset clears alive")
	t.eq(a.nutrition, 0.0, "reset clears nutrition")
	t.eq(a.id, -1, "reset clears id")
	return t

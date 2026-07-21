extends RefCounted
## Garden deposits/tend/decay + homeostasis demand.

var _tree: Node

func _init(tree: Node) -> void:
	_tree = tree

func run() -> TestAssert:
	var t := TestAssert.new("GardenEconomy")
	var colony: Colony = TestHarness.make_colony_phase2(_tree)
	t.ok(colony.garden != null, "garden attached")
	var g: Garden = colony.garden
	var before := g.health
	g.deposit_leaf(0.1)
	t.gt(g.health, before, "leaf deposit raises health")
	g.tend(0.05)
	t.ge(g.health, before + 0.1, "tend raises health")
	g.add_waste(0.5)
	var mid := g.health
	g.tick_decay()
	t.lt(g.health, mid + 0.001, "decay does not increase health")
	g.clear_waste(0.2)
	t.lt(g.waste, 0.5, "waste cleared")

	# Brood reads live garden health
	t.approx(colony.brood.garden_health(), g.health, 0.001, "brood uses garden.health")

	colony.homeostasis.tick(colony)
	t.ok(colony.homeostasis.food_demand >= 0.0, "food demand computed")

	# Forager deposit path
	var forager: AntState = null
	for a in colony.ants:
		if a != null and a.alive and a.caste == AntEnums.Caste.FORAGER:
			forager = a
			break
	t.ok(forager != null, "has forager")
	if forager:
		var h0 := g.health
		forager.intent = AntEnums.State.HAUL
		forager.carry = AntEnums.Carry.LEAF
		colony._finish_forager(forager)
		t.gt(g.health, h0, "forager deposit increases garden")
		t.eq(forager.carry, AntEnums.Carry.NONE, "leaf consumed on deposit")

	colony.queue_free()
	return t

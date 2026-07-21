extends RefCounted
## Tests for AntEnums helpers.

func run() -> TestAssert:
	var t := TestAssert.new("AntEnums")
	t.ok(AntEnums.is_brood(AntEnums.Caste.LARVA), "larva is brood")
	t.ok(AntEnums.is_brood(AntEnums.Caste.PUPA), "pupa is brood")
	t.ok(not AntEnums.is_brood(AntEnums.Caste.NURSE), "nurse is not brood")
	t.ok(AntEnums.is_adult_worker(AntEnums.Caste.QUEEN), "queen counts as adult worker")
	t.ok(AntEnums.is_adult_worker(AntEnums.Caste.PLAYER), "player counts as adult")
	t.ok(not AntEnums.is_adult_worker(AntEnums.Caste.LARVA), "larva not adult")
	t.ok(AntEnums.caste_color(AntEnums.Caste.NURSE).b > 0.5, "nurse is bluish")
	t.ok(AntEnums.caste_color(AntEnums.Caste.GARDENER).g > 0.5, "gardener is greenish")
	t.ok(not AntEnums.is_adult_worker(AntEnums.Caste.INVADER), "invader not colony adult")
	t.gt(AntEnums.caste_radius(AntEnums.Caste.QUEEN), AntEnums.caste_radius(AntEnums.Caste.NURSE), "queen larger than nurse")
	t.gt(AntEnums.caste_radius(AntEnums.Caste.SOLDIER), AntEnums.caste_radius(AntEnums.Caste.LARVA), "soldier larger than larva")
	t.eq(AntEnums.role_color(AntEnums.Role.NURSE).b > 0.5, true, "nurse role color is bluish")
	t.eq(AntEnums.role_name(AntEnums.Role.FORAGER), "forager", "role_name forager")
	t.eq(AntEnums.role_from_name("scout"), AntEnums.Role.SCOUT, "role_from_name scout")
	t.ok(AntEnums.role_color(AntEnums.Role.SCOUT).b > 0.5, "scout color is violet")
	return t

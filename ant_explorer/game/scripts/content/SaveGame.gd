class_name SaveGame
extends RefCounted
## Serialize / restore colony blob. Phase 0 uses the Save autoload stub only.

static func to_dict(tick: int, rng_seed: int, garden_health: float, ants_compact: Array, stars: PackedStringArray, player: Dictionary) -> Dictionary:
	return {
		"tick": tick,
		"rng_seed": rng_seed,
		"garden_health": garden_health,
		"ants": ants_compact,
		"stars_collected": Array(stars),
		"player": player,
	}

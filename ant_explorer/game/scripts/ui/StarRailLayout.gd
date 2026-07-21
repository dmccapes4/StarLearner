class_name StarRailLayout
extends RefCounted
## Fixed 6-left / 6-right slot assignment for the landscape star rails.
## Order is frozen for the whole product life (see STRATEGY_LANDSCAPE_STAR_RAILS §2.3).
## Ids match data/stars.json.

# Plain Array literals so they qualify as constant expressions (a PackedStringArray
# constructor call does not). Accessors hand back typed PackedStringArrays.
const LEFT := [
	"01_queen", "02_larvae", "03_pupae", "04_fungus", "05_forage", "06_pheromone",
]
const RIGHT := [
	"07_soldiers", "08_waste", "09_labor", "10_bacteria", "11_architecture", "12_invaders",
]

const SIDE_LEFT := "left"
const SIDE_RIGHT := "right"

static func left_ids() -> PackedStringArray:
	return PackedStringArray(LEFT)

static func right_ids() -> PackedStringArray:
	return PackedStringArray(RIGHT)

static func all_ids() -> PackedStringArray:
	var out := PackedStringArray(LEFT)
	out.append_array(PackedStringArray(RIGHT))
	return out

static func side_for(star_id: String) -> String:
	if LEFT.has(star_id):
		return SIDE_LEFT
	if RIGHT.has(star_id):
		return SIDE_RIGHT
	return ""

## Row index within the star's own side column (0 = top).
static func slot_index(star_id: String) -> int:
	var i := LEFT.find(star_id)
	if i >= 0:
		return i
	return RIGHT.find(star_id)

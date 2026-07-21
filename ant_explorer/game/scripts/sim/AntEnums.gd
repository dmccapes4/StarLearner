class_name AntEnums
extends Object
## Shared enums for castes, carry, roles, and FSM states.

enum Caste {
	QUEEN,
	SOLDIER,
	FORAGER,
	GARDENER,
	NURSE,
	LARVA,
	PUPA,
	PLAYER,
	INVADER,
}

enum Carry {
	NONE,
	LEAF,
	EGG,
	FOOD,
	WASTE,
	LARVA,
}

enum Role {
	NONE,
	NURSE,
	FORAGER,
	GARDENER,
	SOLDIER,
	WASTE,
	SCOUT,
}

enum State {
	IDLE,
	WALK,
	FEED_LARVA,
	DOSE_JH,
	MOVE_LARVA,
	CARRY_EGG,
	CARRY_PUPA,
	TEND_GARDEN,
	GO_TO_LEAF,
	CUT,
	HAUL,
	DEPOSIT,
	PATROL,
	RESPOND_INVADER,
	SHAKE,
	LAY_EGG,
	CARRY_WASTE,
	FETCH_FOOD,
}

static func caste_color(caste: int) -> Color:
	match caste:
		Caste.QUEEN:
			return Color(0.95, 0.75, 0.25)
		Caste.SOLDIER:
			return Color(0.85, 0.25, 0.22)
		Caste.FORAGER:
			return Color(0.30, 0.70, 0.35)
		Caste.GARDENER:
			return Color(0.40, 0.70, 0.55)
		Caste.NURSE:
			return Color(0.30, 0.50, 0.90)
		Caste.LARVA:
			return Color(0.92, 0.88, 0.78)
		Caste.PUPA:
			return Color(0.95, 0.95, 0.98)
		Caste.PLAYER:
			return Color(0.95, 0.55, 0.15)
		Caste.INVADER:
			return Color(0.55, 0.20, 0.55)
		_:
			return Color(0.7, 0.7, 0.7)

static func caste_radius(caste: int) -> float:
	match caste:
		Caste.QUEEN:
			return 14.0
		Caste.SOLDIER, Caste.INVADER:
			return 11.0
		Caste.FORAGER:
			return 9.0
		Caste.GARDENER, Caste.NURSE:
			return 7.0
		Caste.LARVA:
			return 5.0
		Caste.PUPA:
			return 6.0
		Caste.PLAYER:
			return 10.0
		_:
			return 8.0

static func role_color(role: int) -> Color:
	match role:
		Role.NURSE:
			return Color(0.35, 0.55, 0.95)
		Role.FORAGER:
			return Color(0.30, 0.80, 0.40)
		Role.GARDENER:
			return Color(0.95, 0.75, 0.25)
		Role.SOLDIER:
			return Color(0.90, 0.30, 0.25)
		Role.WASTE:
			return Color(0.65, 0.65, 0.65)
		Role.SCOUT:
			return Color(0.55, 0.35, 0.85)
		_:
			return Color(0.95, 0.55, 0.15)

static func role_name(role: int) -> String:
	match role:
		Role.NURSE:
			return "nurse"
		Role.FORAGER:
			return "forager"
		Role.GARDENER:
			return "gardener"
		Role.SOLDIER:
			return "soldier"
		Role.WASTE:
			return "waste"
		Role.SCOUT:
			return "scout"
		_:
			return ""

static func role_from_name(name: String) -> int:
	match name.to_lower():
		"nurse":
			return Role.NURSE
		"forager":
			return Role.FORAGER
		"gardener":
			return Role.GARDENER
		"soldier":
			return Role.SOLDIER
		"waste":
			return Role.WASTE
		"scout":
			return Role.SCOUT
		_:
			return Role.NONE

static func is_brood(caste: int) -> bool:
	return caste == Caste.LARVA or caste == Caste.PUPA

static func is_adult_worker(caste: int) -> bool:
	return caste == Caste.SOLDIER or caste == Caste.FORAGER \
		or caste == Caste.GARDENER or caste == Caste.NURSE \
		or caste == Caste.QUEEN or caste == Caste.PLAYER

static func enemy_color(kind: int) -> Color:
	match kind:
		0:  # ANT
			return Color(0.75, 0.15, 0.15)
		1:  # BEETLE
			return Color(0.25, 0.35, 0.55)
		2:  # SPIDER
			return Color(0.45, 0.25, 0.55)
		_:
			return Color(0.55, 0.20, 0.55)

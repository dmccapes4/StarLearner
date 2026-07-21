class_name MathData
extends RefCounted
## The content spine of Math Explorer: which tutorials exist, which interactive
## "use cases" (sprite-driven problem templates) exist, and a few fully specified
## sample word problems. Kept as data so tutorials, practice, and the tests all
## read from one place. See docs/STRATEGY_MATH_EXPLORER.md for the full design.

## Guided, narrated tutorials. `interactive` = the animated cube/coin choreography
## is implemented; otherwise it's specced and coming soon.
static func tutorials() -> Array:
	return [
		{"id": "add_basic", "op": "add", "title": "Counting on: 7 + 4",
			"example": "7 + 4 = 11", "interactive": true},
		{"id": "sub_basic", "op": "sub", "title": "Take away: 7 \u2212 4",
			"example": "7 \u2212 4 = 3", "interactive": false},
		{"id": "mul_basic", "op": "mul", "title": "Groups: 3 \u00D7 4",
			"example": "3 \u00D7 4 = 12", "interactive": false},
		{"id": "div_basic", "op": "div", "title": "Sharing: 9 \u00F7 3",
			"example": "9 \u00F7 3 = 3", "interactive": false},
		{"id": "div_remainder", "op": "div", "title": "Leftovers: 10 \u00F7 3",
			"example": "10 \u00F7 3 = 3 r 1", "interactive": false},
	]

## Interactive problem templates ("make math alive"). Each drives a sprite scene.
static func problem_types() -> Array:
	return [
		{"id": "count_cubes", "ops": ["add", "sub", "mul", "div"],
			"sprite": "cubes", "answer": "number",
			"blurb": "Count rounded cubes; the current one glows gold."},
		{"id": "coins_count", "ops": ["add"], "sprite": "coins", "answer": "number",
			"blurb": "Pennies, nickels, dimes; total value tracker updates live."},
		{"id": "make_change", "ops": ["add", "sub"], "sprite": "coins", "answer": "combos",
			"blurb": "Drag coins into buckets to make a target amount; count the ways."},
		{"id": "eggs_rate", "ops": ["mul", "add", "div"], "sprite": "chickens_eggs",
			"answer": "number", "blurb": "Chickens lay eggs per day; fill 6-egg cartons."},
		{"id": "share_resources", "ops": ["div", "add"], "sprite": "dolls",
			"answer": "number", "blurb": "Pool items, then share them fairly among kids."},
		{"id": "rate_time", "ops": ["div", "mul"], "sprite": "stones_paint",
			"answer": "number", "blurb": "Two painters at different rates finish a job."},
		{"id": "clock_time", "ops": ["add", "sub"], "sprite": "clock",
			"answer": "time", "blurb": "Elapsed time and reading a clock face."},
	]

## Fully specified sample problems (the user's examples), captured as data.
static func sample_problems() -> Array:
	return [
		{
			"id": "eggs_3_days", "type": "eggs_rate", "op": "mul",
			"prompt": "There are 4 white chickens and 4 yellow chickens. White chickens lay 2 eggs a day, yellow chickens lay 1 egg a day. How many eggs in 3 days?",
			"steps": ["(4 \u00D7 2) + (4 \u00D7 1) = 8 + 4 = 12 eggs per day",
				"12 \u00D7 3 days = 36 eggs", "36 \u00F7 6 per carton = 6 cartons"],
			"answer": 36,
		},
		{
			"id": "dolls_share", "type": "share_resources", "op": "div",
			"prompt": "A basket has 4 dolls. One kid adds 1, another adds 2. 4 kids want dolls. How many can each kid take?",
			"steps": ["4 + 1 + 2 = 7 dolls", "7 \u00F7 4 = 1 each, with 3 left over"],
			"answer": 1,
		},
		{
			"id": "make_12_cents", "type": "make_change", "op": "add",
			"prompt": "You have 2 dimes, 3 nickels, and 7 pennies. How many ways can you make 12 cents?",
			"steps": ["dime + penny + penny", "nickel + nickel + penny + penny",
				"nickel + 7 pennies (only if you had 7) ...count the combinations"],
			"answer": -1,
		},
		{
			"id": "paint_stones", "type": "rate_time", "op": "div",
			"prompt": "Bobby paints 4 stones an hour, Sally paints 6 an hour. There are 20 stones. How long, and how many does each paint?",
			"steps": ["together: 4 + 6 = 10 stones per hour", "20 \u00F7 10 = 2 hours",
				"Bobby: 4 \u00D7 2 = 8", "Sally: 6 \u00D7 2 = 12"],
			"answer": 2,
		},
	]

static func tutorial_for_op(op: String) -> Dictionary:
	for t in tutorials():
		if t["op"] == op:
			return t
	return {}

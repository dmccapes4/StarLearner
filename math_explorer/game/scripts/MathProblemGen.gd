class_name MathProblemGen
extends RefCounted
## Procedural problem generator. The whole point: a *small* set of sprites covers
## a *huge* number of questions, because every template is parameterised over its
## numbers (and often its actor names / subjects). One chicken sprite → endless
## egg problems; one coin set → endless change problems; one train → endless
## chase problems. Variety of numbers = variety of thinking, at ~zero art cost.
##
## Every generator returns a self-describing dict:
##   { id, type, op, sprite, subjects[], params{}, prompt, steps[], answer }
## `params` is included so tests (and the "explain the mistake" coach) can
## recompute the answer independently — no magic constants.

const NAMES := ["Mia", "Leo", "Ava", "Max", "Bobby", "Sally", "Zoe", "Sam",
	"Nina", "Theo", "Lily", "Ben"]
const CUBE_COLORS := ["red", "blue", "green", "purple", "orange"]
const COUNT_ITEMS := ["apples", "ducks", "stars", "leaves", "shells", "buttons"]

## All template ids this generator can produce.
static func templates() -> Array:
	return ["count_add", "take_sub", "groups_mul", "share_div",
		"eggs_rate", "coins_make", "share_dolls", "paint_rate",
		"trains_gap", "clock_elapsed"]

static func generate(template_id: String, seed: int = -1) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	if seed >= 0:
		rng.seed = seed
	else:
		rng.randomize()
	match template_id:
		"count_add": return _count_add(rng)
		"take_sub": return _take_sub(rng)
		"groups_mul": return _groups_mul(rng)
		"share_div": return _share_div(rng)
		"eggs_rate": return _eggs_rate(rng)
		"coins_make": return _coins_make(rng)
		"share_dolls": return _share_dolls(rng)
		"paint_rate": return _paint_rate(rng)
		"trains_gap": return _trains_gap(rng)
		"clock_elapsed": return _clock_elapsed(rng)
	return {}

# ---- number tutorials (procedural cubes) ------------------------------------

static func _count_add(rng: RandomNumberGenerator) -> Dictionary:
	var a := rng.randi_range(2, 9)
	var b := rng.randi_range(1, mini(9, 20 - a))
	var c1: String = CUBE_COLORS[rng.randi_range(0, CUBE_COLORS.size() - 1)]
	return {
		"id": "count_add", "type": "count_cubes", "op": "add", "sprite": "cubes",
		"subjects": ["cubes"], "params": {"a": a, "b": b},
		"prompt": "%d %s cubes and %d more. How many in all?" % [a, c1, b],
		"steps": ["Count on from %d: ...%d" % [a, a + b], "%d + %d = %d" % [a, b, a + b]],
		"answer": a + b,
	}

static func _take_sub(rng: RandomNumberGenerator) -> Dictionary:
	var a := rng.randi_range(4, 12)
	var b := rng.randi_range(1, a - 1)
	return {
		"id": "take_sub", "type": "count_cubes", "op": "sub", "sprite": "cubes",
		"subjects": ["cubes"], "params": {"a": a, "b": b},
		"prompt": "There are %d cubes. Take away %d. How many are left?" % [a, b],
		"steps": ["Slide %d away, count what's left" % b, "%d \u2212 %d = %d" % [a, b, a - b]],
		"answer": a - b,
	}

static func _groups_mul(rng: RandomNumberGenerator) -> Dictionary:
	var g := rng.randi_range(2, 5)
	var n := rng.randi_range(2, 5)
	return {
		"id": "groups_mul", "type": "count_cubes", "op": "mul", "sprite": "cubes",
		"subjects": ["cubes"], "params": {"g": g, "n": n},
		"prompt": "%d groups of %d cubes. How many altogether?" % [g, n],
		"steps": ["%s = %d" % ["+".join(_repeat_str(str(n), g)), g * n],
			"%d \u00D7 %d = %d" % [g, n, g * n]],
		"answer": g * n,
	}

static func _share_div(rng: RandomNumberGenerator) -> Dictionary:
	var buckets := rng.randi_range(2, 4)
	var per := rng.randi_range(2, 5)
	var extra := rng.randi_range(0, buckets - 1)  # sometimes a remainder
	var total := buckets * per + extra
	return {
		"id": "share_div", "type": "count_cubes", "op": "div", "sprite": "cubes",
		"subjects": ["cubes"], "params": {"total": total, "buckets": buckets},
		"prompt": "Share %d cubes fairly into %d buckets. How many in each?" % [total, buckets],
		"steps": ["Deal one at a time: red, blue, green...",
			"%d \u00F7 %d = %d%s" % [total, buckets, per,
				(" remainder %d" % extra) if extra > 0 else ""]],
		"answer": per,
	}

# ---- word problems (sprites) ------------------------------------------------

static func _eggs_rate(rng: RandomNumberGenerator) -> Dictionary:
	var white := rng.randi_range(2, 5)
	var yellow := rng.randi_range(2, 5)
	# Real hens lay one egg a day, occasionally two — never three.
	var w_eggs := rng.randi_range(1, 2)
	var y_eggs := rng.randi_range(1, 2)
	var days := rng.randi_range(2, 4)
	var carton := 6
	var per_day := white * w_eggs + yellow * y_eggs
	var total := per_day * days
	var cartons := int(ceil(float(total) / carton))
	return {
		"id": "eggs_rate", "type": "eggs_rate", "op": "mul",
		"sprite": "chickens_eggs", "subjects": ["chicken_white", "chicken_yellow", "egg", "carton"],
		"params": {"white": white, "yellow": yellow, "w_eggs": w_eggs,
			"y_eggs": y_eggs, "days": days, "carton": carton},
		"prompt": "%d white chickens lay %d egg%s a day, %d yellow chickens lay %d a day. How many eggs in %d days? How many %d-egg cartons?" % [white, w_eggs, "" if w_eggs == 1 else "s", yellow, y_eggs, days, carton],
		"steps": ["(%d\u00D7%d)+(%d\u00D7%d) = %d eggs/day" % [white, w_eggs, yellow, y_eggs, per_day],
			"%d \u00D7 %d days = %d eggs" % [per_day, days, total],
			"%d \u00F7 %d = %d cartons" % [total, carton, cartons]],
		"answer": total,
	}

static func _coins_make(rng: RandomNumberGenerator) -> Dictionary:
	var target: int = [10, 11, 12, 15, 16, 20][rng.randi_range(0, 5)]
	var dimes := rng.randi_range(1, 3)
	var nickels := rng.randi_range(2, 4)
	var pennies := rng.randi_range(5, 9)
	var ways := count_coin_ways(target, dimes, nickels, pennies)
	return {
		"id": "coins_make", "type": "make_change", "op": "add",
		"sprite": "coins", "subjects": ["penny", "nickel", "dime", "piggy_bank"],
		"params": {"target": target, "dimes": dimes, "nickels": nickels, "pennies": pennies},
		"prompt": "You have %d dime%s, %d nickels, and %d pennies. How many ways can you make %d\u00A2?" % [dimes, "" if dimes == 1 else "s", nickels, pennies, target],
		"steps": ["Try each purse: dimes, then nickels, then pennies",
			"Count the different combinations that total %d\u00A2" % target],
		"answer": ways,
	}

static func _share_dolls(rng: RandomNumberGenerator) -> Dictionary:
	var start := rng.randi_range(2, 6)
	var add1 := rng.randi_range(1, 3)
	var add2 := rng.randi_range(1, 3)
	var kids := rng.randi_range(2, 4)
	var total := start + add1 + add2
	var each := total / kids
	var left := total % kids
	return {
		"id": "share_dolls", "type": "share_resources", "op": "div",
		"sprite": "dolls", "subjects": ["doll", "basket"],
		"params": {"start": start, "add1": add1, "add2": add2, "kids": kids},
		"prompt": "A basket has %d dolls. One kid adds %d, another adds %d. %d kids share them. How many each?" % [start, add1, add2, kids],
		"steps": ["%d + %d + %d = %d dolls" % [start, add1, add2, total],
			"%d \u00F7 %d = %d each%s" % [total, kids, each,
				(", %d left over" % left) if left > 0 else ""]],
		"answer": each,
	}

static func _paint_rate(rng: RandomNumberGenerator) -> Dictionary:
	var n1: String = NAMES[rng.randi_range(0, NAMES.size() - 1)]
	var n2: String = NAMES[rng.randi_range(0, NAMES.size() - 1)]
	var r1 := rng.randi_range(2, 6)
	var r2 := rng.randi_range(2, 6)
	var hours := rng.randi_range(2, 4)
	var total := (r1 + r2) * hours   # chosen so it divides evenly
	return {
		"id": "paint_rate", "type": "rate_time", "op": "div",
		"sprite": "stones_paint", "subjects": ["stone_plain", "stone_painted", "kid"],
		"params": {"r1": r1, "r2": r2, "total": total},
		"prompt": "%s paints %d stones an hour, %s paints %d. There are %d stones. How many hours?" % [n1, r1, n2, r2, total],
		"steps": ["Together: %d + %d = %d stones/hour" % [r1, r2, r1 + r2],
			"%d \u00F7 %d = %d hours" % [total, r1 + r2, hours],
			"%s: %d\u00D7%d=%d, %s: %d\u00D7%d=%d" % [n1, r1, hours, r1 * hours, n2, r2, hours, r2 * hours]],
		"answer": hours,
	}

static func _trains_gap(rng: RandomNumberGenerator) -> Dictionary:
	# Train A leaves h hours earlier at sA mph; Train B leaves later at sB > sA.
	# T = hours after B departs. Gap = how far B is ahead of A at that moment.
	var s_a: int = [20, 30, 40][rng.randi_range(0, 2)]
	var s_b: int = s_a + [10, 20, 30][rng.randi_range(0, 2)]
	var h := rng.randi_range(1, 2)
	var t := rng.randi_range(3, 5)
	var d_a := (t + h) * s_a
	var d_b := t * s_b
	var gap := d_b - d_a
	# Keep only the ones where B is genuinely ahead (positive, understandable).
	if gap <= 0:
		s_b = s_a + 30
		t = 5
		d_a = (t + h) * s_a
		d_b = t * s_b
		gap = d_b - d_a
	var catch_num := h * s_a       # catch time = catch_num / (s_b - s_a) hours
	return {
		"id": "trains_gap", "type": "rate_distance", "op": "sub",
		"sprite": "trains", "subjects": ["train_a", "train_b", "station", "track"],
		"params": {"s_a": s_a, "s_b": s_b, "h": h, "t": t},
		"prompt": "Train A leaves %d hour%s early at %d mph. Train B leaves later at %d mph. After %d hours, how far ahead is Train B?" % [h, "s" if h > 1 else "", s_a, s_b, t],
		"steps": ["Train A traveled (%d+%d)\u00D7%d = %d miles" % [t, h, s_a, d_a],
			"Train B traveled %d\u00D7%d = %d miles" % [t, s_b, d_b],
			"B is ahead: %d \u2212 %d = %d miles" % [d_b, d_a, gap],
			"B catches A after %d \u00F7 %d = %s hours" % [catch_num, s_b - s_a,
				_frac(catch_num, s_b - s_a)]],
		"answer": gap,
	}

static func _clock_elapsed(rng: RandomNumberGenerator) -> Dictionary:
	# NOTE: no clock sprite yet — the ClockFace widget is procedural (see ASSETS.md).
	var start_h := rng.randi_range(1, 10)
	var dur_h := rng.randi_range(1, 3)
	var end_h := start_h + dur_h
	return {
		"id": "clock_elapsed", "type": "clock_time", "op": "add",
		"sprite": "clock", "subjects": ["clock_face"],
		"params": {"start_h": start_h, "dur_h": dur_h},
		"prompt": "It is %d o'clock. In %d hour%s, what time will it be?" % [start_h, dur_h, "s" if dur_h > 1 else ""],
		"steps": ["Sweep the hour hand forward %d" % dur_h,
			"%d + %d = %d o'clock" % [start_h, dur_h, end_h]],
		"answer": end_h,
	}

# ---- helpers ----------------------------------------------------------------

## Number of ways to reach `target` cents using at most the given coins.
static func count_coin_ways(target: int, dimes: int, nickels: int, pennies: int) -> int:
	var ways := 0
	for d in range(0, dimes + 1):
		for n in range(0, nickels + 1):
			var rem := target - d * 10 - n * 5
			if rem >= 0 and rem <= pennies:
				ways += 1
	return ways

static func _repeat_str(s: String, n: int) -> Array:
	var out := []
	for i in n:
		out.append(s)
	return out

static func _frac(num: int, den: int) -> String:
	if den == 0:
		return "?"
	if num % den == 0:
		return str(num / den)
	var whole := num / den
	var r := num % den
	if whole == 0:
		return "%d/%d" % [r, den]
	return "%d %d/%d" % [whole, r, den]

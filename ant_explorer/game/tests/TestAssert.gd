class_name TestAssert
extends RefCounted
## Tiny assertion helpers for headless GDScript tests.

var name: String = ""
var failed: int = 0
var passed: int = 0
var errors: PackedStringArray = PackedStringArray()

func _init(suite_name: String = "") -> void:
	name = suite_name

func ok(cond: bool, msg: String) -> void:
	if cond:
		passed += 1
	else:
		failed += 1
		var line := "[FAIL] %s: %s" % [name, msg]
		errors.append(line)
		push_error(line)

func eq(actual: Variant, expected: Variant, msg: String) -> void:
	ok(actual == expected, "%s (got %s, want %s)" % [msg, str(actual), str(expected)])

func neq(actual: Variant, unexpected: Variant, msg: String) -> void:
	ok(actual != unexpected, "%s (got unexpected %s)" % [msg, str(actual)])

func approx(actual: float, expected: float, eps: float, msg: String) -> void:
	ok(absf(actual - expected) <= eps, "%s (got %.4f, want %.4f ±%.4f)" % [msg, actual, expected, eps])

func gt(actual: float, bound: float, msg: String) -> void:
	ok(actual > bound, "%s (got %.4f, want > %.4f)" % [msg, actual, bound])

func ge(actual: float, bound: float, msg: String) -> void:
	ok(actual >= bound, "%s (got %.4f, want >= %.4f)" % [msg, actual, bound])

func lt(actual: float, bound: float, msg: String) -> void:
	ok(actual < bound, "%s (got %.4f, want < %.4f)" % [msg, actual, bound])

func in_range(actual: float, lo: float, hi: float, msg: String) -> void:
	ok(actual >= lo and actual <= hi, "%s (got %.4f, want [%.4f, %.4f])" % [msg, actual, lo, hi])

func summary() -> String:
	return "%s: %d passed, %d failed" % [name, passed, failed]

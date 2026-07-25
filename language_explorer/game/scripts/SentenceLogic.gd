class_name SentenceLogic
extends RefCounted
## Pure helpers for sentence matching (headless-testable).

static func normalize_token(token: String) -> String:
	var t := token.strip_edges().to_lower()
	# Strip common trailing punctuation.
	while t.length() > 0 and t[t.length() - 1] in [".", ",", "!", "?", ";", ":"]:
		t = t.substr(0, t.length() - 1)
	return t

static func is_matchable_token(token: String, matchable: Array) -> bool:
	var n := normalize_token(token)
	for m in matchable:
		if normalize_token(str(m)) == n:
			return true
	return false

static func sprite_matches_token(sprite_token: String, word_token: String) -> bool:
	return normalize_token(sprite_token) == normalize_token(word_token)

static func all_matched(matched: Dictionary, matchable: Array) -> bool:
	for m in matchable:
		var key := normalize_token(str(m))
		if not bool(matched.get(key, false)):
			return false
	return matchable.size() > 0

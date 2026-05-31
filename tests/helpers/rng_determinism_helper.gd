# Test helper — RNG sequence determinism comparison (Story 020).
# Plain RefCounted, no scene-tree / autoload dependency. Used by AC-12 / AC-15 replay tests.
extends RefCounted


## Compare two RNG output sequences. Returns:
##   { match: bool, first_diff_idx: int (-1 if equal), diff_count: int }
## Sequences of differing length are unequal; the extra tail counts as diffs.
static func compare_sequences(seq_a: Array, seq_b: Array) -> Dictionary:
	var n: int = mini(seq_a.size(), seq_b.size())
	var first_diff: int = -1
	var diff_count: int = 0
	for i in n:
		if not is_equal_approx(seq_a[i], seq_b[i]):
			if first_diff == -1:
				first_diff = i
			diff_count += 1
	# Length mismatch — the unmatched tail is all diffs.
	var tail: int = absi(seq_a.size() - seq_b.size())
	if tail > 0:
		if first_diff == -1:
			first_diff = n
		diff_count += tail
	return {
		"match": diff_count == 0,
		"first_diff_idx": first_diff,
		"diff_count": diff_count,
	}


## Self-check (Story 020 QA).
static func _static_check() -> bool:
	var same: Dictionary = compare_sequences([1.0, 2.0, 3.0], [1.0, 2.0, 3.0])
	assert(same["match"] == true and same["diff_count"] == 0, "rng helper: equal seqs")
	var diff: Dictionary = compare_sequences([1.0, 2.5, 3.0], [1.0, 2.0, 3.0])
	assert(diff["match"] == false and diff["first_diff_idx"] == 1 and diff["diff_count"] == 1,
		"rng helper: one diff at idx 1")
	return true

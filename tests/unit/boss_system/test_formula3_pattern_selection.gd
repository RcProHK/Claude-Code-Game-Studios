# BossFormulas Formula 3 + DeterministicHash — attack-pattern selection
# (Story 005: AC-06 / AC-20 / AC-34 + EC-10 / EC-11). Pure static, deterministic.
extends GutTest


func _pattern(id: StringName) -> AttackPatternResource:
	var p := AttackPatternResource.new()
	p.pattern_id = id
	return p


func _three_patterns() -> Array:
	return [_pattern(&"A"), _pattern(&"B"), _pattern(&"C")]


# ---------------------------------------------------------------------------
# AC-34 — FNV-1a cross-platform determinism (golden vector)
# ---------------------------------------------------------------------------

func test_ac34_deterministic_hash_golden_vector() -> void:
	# Canonical FNV-1a 32-bit hash of "abc" == 0x1A47E90B == 440920331.
	# NOTE: the GDD (boss-system.md Formula 3 + Followup #19) states the golden
	# vector as 1454761972 — that value is INCORRECT (does not match the standard
	# FNV-1a algorithm the GDD itself specifies). The implementation follows the
	# canonical FNV-1a; the GDD golden-vector number is a doc error (GDD doc-fix
	# followup — non-blocking; the algorithm + cross-platform determinism are right).
	assert_eq(DeterministicHash.deterministic_hash("abc"), 440920331,
		"AC-34: FNV-1a 32-bit golden vector deterministic_hash('abc') == 440920331 (0x1A47E90B)")


func test_ac34_hash_non_negative() -> void:
	for s in ["", "x", "txn_pattern_0", "STRIKE_FINAL_01_pattern_99"]:
		assert_true(DeterministicHash.deterministic_hash(s) >= 0,
			"AC-34: hash('%s') is non-negative (32-bit masked)" % s)


func test_ac34_same_input_same_pattern() -> void:
	var c := _three_patterns()
	var a := BossFormulas.select_attack_pattern(c, &"", "seed1", 5)
	var b := BossFormulas.select_attack_pattern(c, &"", "seed1", 5)
	assert_eq(a.pattern_id, b.pattern_id, "AC-34/AC-20a: same (seed, count) -> same pattern")


# ---------------------------------------------------------------------------
# AC-06 / AC-20 — anti-spam: zero consecutive identical (>=2 patterns)
# ---------------------------------------------------------------------------

func test_ac06_no_consecutive_same_pattern_over_100() -> void:
	var c := _three_patterns()
	var last := &""
	var consecutive := 0
	for count in range(100):
		var sel := BossFormulas.select_attack_pattern(c, last, "seed1", count)
		assert_not_null(sel, "selection is never null with 3 patterns")
		if sel.pattern_id == last:
			consecutive += 1
		last = sel.pattern_id
	assert_eq(consecutive, 0, "AC-06/AC-20b: zero consecutive same-pattern over 100 selections")


# ---------------------------------------------------------------------------
# EC-10 / EC-11 — degenerate candidate arrays
# ---------------------------------------------------------------------------

func test_ec10_empty_candidates_returns_null() -> void:
	var sel := BossFormulas.select_attack_pattern([], &"", "seed1", 0)
	assert_null(sel, "EC-10: empty attack_patterns -> null (defensive)")


func test_ec11_single_pattern_returns_it() -> void:
	var c := [_pattern(&"solo")]
	var sel := BossFormulas.select_attack_pattern(c, &"solo", "seed1", 0)
	assert_eq(sel.pattern_id, &"solo", "EC-11: single pattern returned (anti-spam waived)")


func test_all_same_id_bypasses_antispam() -> void:
	# Data error: all candidates share an id; must not infinite-filter to empty.
	var c := [_pattern(&"dup"), _pattern(&"dup")]
	var sel := BossFormulas.select_attack_pattern(c, &"dup", "seed1", 0)
	assert_eq(sel.pattern_id, &"dup", "all-same-id data error -> bypass anti-spam, still returns a pattern")

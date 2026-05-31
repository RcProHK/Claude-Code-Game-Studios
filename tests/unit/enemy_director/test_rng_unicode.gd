# EnemyDirector — Story 006 AC-16: Unicode transition_id handling.
#
# Coverage:
#   AC-16 [Logic|BLOCKING|unit] — RNGFactory.create() accepts Unicode transition_ids
#     (CJK + emoji) without error, yields a valid RNG, hashes distinctly from the
#     ASCII form, and stays deterministic across instantiations.
#
# Accessed as EnemyDirector.RNGFactory.* (autoload inner class).
extends GutTest

const UNICODE_ID: String = "TX-測試-🎲-001"
const ASCII_ID: String = "TX-test-001"


# ---------------------------------------------------------------------------
# AC-16 — Unicode id does not throw and produces a valid RNG
# ---------------------------------------------------------------------------

## create() with a CJK + emoji transition_id returns a non-null RNG whose draws
## fall within the documented [0, 1) randf() range.
func test_ac16_unicode_no_throw_non_null() -> void:
	# Arrange / Act
	var rng := EnemyDirector.RNGFactory.create(UNICODE_ID)

	# Assert
	assert_not_null(rng,
		"AC-16: create() with a Unicode transition_id must return a non-null RNG")
	var value := rng.randf()
	assert_true(value >= 0.0 and value < 1.0,
		"AC-16: randf() from a Unicode-seeded RNG must lie in [0, 1)")


# ---------------------------------------------------------------------------
# AC-16 — Unicode seed differs from ASCII seed
# ---------------------------------------------------------------------------

## The Unicode transition_id must hash to a different seed than its ASCII analogue.
func test_ac16_unicode_seed_differs_from_ascii() -> void:
	# Arrange / Act
	var unicode_hash := hash(UNICODE_ID)
	var ascii_hash := hash(ASCII_ID)

	# Assert
	assert_ne(unicode_hash, ascii_hash,
		"AC-16: Unicode transition_id must hash differently from the ASCII form")


# ---------------------------------------------------------------------------
# AC-16 — Unicode determinism preserved
# ---------------------------------------------------------------------------

## Two fresh create(UNICODE_ID) instances must produce identical first 5 draws.
func test_ac16_unicode_determinism_preserved() -> void:
	# Arrange
	var rng_a := EnemyDirector.RNGFactory.create(UNICODE_ID)
	var rng_b := EnemyDirector.RNGFactory.create(UNICODE_ID)

	# Act / Assert
	for draw_index in range(5):
		assert_eq(rng_a.randf(), rng_b.randf(),
			"AC-16: Unicode-seeded RNGs must be deterministic at draw %d" % draw_index)

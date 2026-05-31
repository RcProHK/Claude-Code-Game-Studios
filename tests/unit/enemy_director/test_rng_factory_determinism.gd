# EnemyDirector — Story 006 AC-12: RNGFactory seed determinism.
#
# Coverage:
#   AC-12 [Logic|BLOCKING|unit] — RNGFactory.create(transition_id) is deterministic:
#     identical transition_ids yield identical sequences; different transition_ids
#     diverge; create() and create_sub() with the same id produce different streams.
#
# Accessed as EnemyDirector.RNGFactory.* because EnemyDirector is an autoload and
# RNGFactory is its inner class.
extends GutTest


# ---------------------------------------------------------------------------
# AC-12 — same seed produces identical sequences
# ---------------------------------------------------------------------------

## 100 fresh RNGFactory.create("TX-001") instantiations each draw 10 randf() values;
## every sequence must match the reference sequence element-for-element.
func test_ac12_same_seed_produces_identical_sequences() -> void:
	# Arrange — build the reference sequence from one factory instance.
	var reference: Array[float] = []
	var ref_rng := EnemyDirector.RNGFactory.create("TX-001")
	for _i in range(10):
		reference.append(ref_rng.randf())

	# Act / Assert — 100 fresh instances must reproduce the reference exactly.
	for instance_index in range(100):
		var rng := EnemyDirector.RNGFactory.create("TX-001")
		for draw_index in range(10):
			var value := rng.randf()
			assert_eq(value, reference[draw_index],
				"AC-12: instance %d draw %d must equal reference (seeded determinism)"
				% [instance_index, draw_index])


# ---------------------------------------------------------------------------
# AC-12 — different seeds produce different sequences
# ---------------------------------------------------------------------------

## create("TX-001") and create("TX-002") must diverge on the very first draw.
func test_ac12_different_seeds_produce_different_sequences() -> void:
	# Arrange
	var rng_a := EnemyDirector.RNGFactory.create("TX-001")
	var rng_b := EnemyDirector.RNGFactory.create("TX-002")

	# Act
	var first_a := rng_a.randf()
	var first_b := rng_b.randf()

	# Assert
	assert_ne(first_a, first_b,
		"AC-12: different transition_ids must produce different first values")


# ---------------------------------------------------------------------------
# AC-12 — create vs create_sub differ for the same transition_id
# ---------------------------------------------------------------------------

## create("TX-001") and create_sub("TX-001", "wave_spawn_0") must seed distinct
## streams (different hash inputs), so first draws differ.
func test_ac12_create_vs_create_sub_different_for_same_id() -> void:
	# Arrange
	var primary := EnemyDirector.RNGFactory.create("TX-001")
	var sub := EnemyDirector.RNGFactory.create_sub("TX-001", "wave_spawn_0")

	# Act
	var first_primary := primary.randf()
	var first_sub := sub.randf()

	# Assert
	assert_ne(first_primary, first_sub,
		"AC-12: create() and create_sub() for the same id must produce different first values")

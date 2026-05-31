# EnemyDirector — Story 006 AC-13: sub-RNG stream independence.
#
# Coverage:
#   AC-13 [Logic|BLOCKING|unit] — sub-streams created via create_sub() are
#     independent of the primary create() stream and of each other: advancing one
#     stream never perturbs another seeded from the same transition_id.
#
# Accessed as EnemyDirector.RNGFactory.* (autoload inner class).
extends GutTest

const TOLERANCE: float = 0.000001


# ---------------------------------------------------------------------------
# AC-13 — sub-RNG state unchanged after the combat (primary) RNG advances
# ---------------------------------------------------------------------------

## Advancing the primary create("TX-001") stream by 100 draws must not affect a
## create_sub("TX-001", "wave_spawn_0") stream: its first draw equals that of a
## freshly created sub-RNG with the same key.
func test_ac13_sub_rng_state_unchanged_after_combat_rng_advances() -> void:
	# Arrange — advance the primary combat RNG by 100 draws.
	var combat_rng := EnemyDirector.RNGFactory.create("TX-001")
	for _i in range(100):
		combat_rng.randf()

	# Act — sub-RNG built after the primary advanced, vs a fresh sub-RNG.
	var sub_after := EnemyDirector.RNGFactory.create_sub("TX-001", "wave_spawn_0").randf()
	var sub_fresh := EnemyDirector.RNGFactory.create_sub("TX-001", "wave_spawn_0").randf()

	# Assert — both sub-RNGs are seeded identically, unaffected by the primary stream.
	assert_almost_eq(sub_after, sub_fresh, TOLERANCE,
		"AC-13: sub-RNG stream must be independent of primary RNG advancement")


# ---------------------------------------------------------------------------
# AC-13 — different sub keys are independent
# ---------------------------------------------------------------------------

## Two sub-RNGs with different keys must not affect each other: advancing one
## leaves the other's seeded sequence unchanged.
func test_ac13_different_sub_keys_are_independent() -> void:
	# Arrange — reference first draw of the "dodge_1234" stream.
	var reference_dodge := EnemyDirector.RNGFactory.create_sub("TX-001", "dodge_1234").randf()

	# Act — heavily advance an unrelated sub key, then sample dodge again.
	var spawn_rng := EnemyDirector.RNGFactory.create_sub("TX-001", "wave_spawn_0")
	for _i in range(100):
		spawn_rng.randf()
	var dodge_after := EnemyDirector.RNGFactory.create_sub("TX-001", "dodge_1234").randf()

	# Assert — the dodge stream is unchanged by advancing the spawn stream.
	assert_almost_eq(dodge_after, reference_dodge, TOLERANCE,
		"AC-13: advancing one sub key must not affect a different sub key's stream")

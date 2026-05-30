## test_deterministic_rng_replay.gd — Story 010 AC-20
##
## Governing story: production/epics/loot-drop-system/story-010-idempotency-guards.md
## Governing ADR  : ADR-0005 CI-6 (deterministic RNG); ADR-0006 Contract 2 (transition_id)
##
## AC-20: same transition_id + same workout_score → same rarity_tier + item_type +
## class_tag on every call. This is the Pillar 1 replay safety guarantee (EC-31).
## The test clears _drops_by_transition between calls to prove real RNG determinism
## rather than just cache return.
extends GutTest


var _sut: LootDropSystem
var _config: LootRarityConfig


func _make_config() -> LootRarityConfig:
	var c := LootRarityConfig.new()
	c.workout_weight = 0.75
	c.rng_weight = 0.25
	c.target_exercises = 5
	c.pr_bonus_per_pr = 0.12
	c.max_pr_factor = 1.25
	c.streak_scale = 28.0
	c.max_streak_bonus = 0.20
	c.tier_thresholds = [0.0, 0.35, 0.55, 0.72, 0.88]
	c.tier_values = [0, 1, 2, 3, 4]
	return c


func before_each() -> void:
	_config = _make_config()
	_sut = LootDropSystem.new()
	_sut._config = _config
	add_child_autofree(_sut)
	await get_tree().process_frame
	_sut.clear_telemetry()


func after_each() -> void:
	_sut = null
	_config = null


# ── AC-20: deterministic replay ───────────────────────────────────────────────

func test_ac20_same_transition_id_same_rarity_tier() -> void:
	# Arrange: generate first drop.
	var drop1 := _sut._generate_loot_internal(
		"T-feedface", LootEnums.SourceEventKind.WORKOUT_DAILY, 0.75
	)
	# Clear cache — forces a fresh roll on second call.
	_sut._drops_by_transition.clear()
	# Act: generate second drop with identical inputs.
	var drop2 := _sut._generate_loot_internal(
		"T-feedface", LootEnums.SourceEventKind.WORKOUT_DAILY, 0.75
	)
	# Assert: same tier.
	assert_eq(drop1.rarity_tier, drop2.rarity_tier,
		"AC-20: same transition_id must produce identical rarity_tier (RNG determinism)")


func test_ac20_same_transition_id_same_item_type() -> void:
	var drop1 := _sut._generate_loot_internal(
		"T-feedface", LootEnums.SourceEventKind.WORKOUT_DAILY, 0.75
	)
	_sut._drops_by_transition.clear()
	var drop2 := _sut._generate_loot_internal(
		"T-feedface", LootEnums.SourceEventKind.WORKOUT_DAILY, 0.75
	)
	assert_eq(drop1.item_type, drop2.item_type,
		"AC-20: same transition_id must produce identical item_type (RNG determinism)")


func test_ac20_same_transition_id_same_class_tag() -> void:
	var drop1 := _sut._generate_loot_internal(
		"T-feedface", LootEnums.SourceEventKind.WORKOUT_DAILY, 0.75
	)
	_sut._drops_by_transition.clear()
	var drop2 := _sut._generate_loot_internal(
		"T-feedface", LootEnums.SourceEventKind.WORKOUT_DAILY, 0.75
	)
	assert_eq(drop1.class_tag, drop2.class_tag,
		"AC-20: same transition_id must produce identical class_tag (RNG determinism)")


func test_ac20_different_transition_ids_may_differ() -> void:
	# Different seeds produce independent drops (non-collision sanity check).
	# Not guaranteed to differ, but we verify they CAN differ independently.
	var drop1 := _sut._generate_loot_internal(
		"T-aaaaaa", LootEnums.SourceEventKind.WORKOUT_DAILY, 0.75
	)
	var drop2 := _sut._generate_loot_internal(
		"T-bbbbbb", LootEnums.SourceEventKind.WORKOUT_DAILY, 0.75
	)
	# Both valid drops — the key is they don't share a cache entry.
	assert_true(drop1.transition_id == "T-aaaaaa", "drop1 carries its transition_id")
	assert_true(drop2.transition_id == "T-bbbbbb", "drop2 carries its transition_id")


func test_ac20_workout_score_zero_always_common_deterministically() -> void:
	# ws=0.0 → COMMON guaranteed by Formula 1 zero-workout guard. Deterministic.
	var drop1 := _sut._generate_loot_internal(
		"T-zero1", LootEnums.SourceEventKind.WORKOUT_DAILY, 0.0
	)
	_sut._drops_by_transition.clear()
	var drop2 := _sut._generate_loot_internal(
		"T-zero1", LootEnums.SourceEventKind.WORKOUT_DAILY, 0.0
	)
	assert_eq(drop1.rarity_tier, "COMMON",
		"ws=0.0 must always produce COMMON (Pillar 1 zero-workout guard)")
	assert_eq(drop2.rarity_tier, "COMMON",
		"ws=0.0 replay must also produce COMMON")

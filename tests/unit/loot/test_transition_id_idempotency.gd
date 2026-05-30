## test_transition_id_idempotency.gd — Story 010 AC-21
##
## Governing story: production/epics/loot-drop-system/story-010-idempotency-guards.md
## Governing ADRs : ADR-0006 Contract 2 (transition_id); ADR-0005 (Rule 9, INV-7)
##
## AC-21: when _drops_by_transition already contains a drop for a transition_id,
## _generate_loot_internal() must return the cached LootDrop without making any
## new RNG roll and without emitting duplicate telemetry.
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


# ── AC-21: idempotency cache ──────────────────────────────────────────────────

func test_ac21_second_call_returns_same_object_reference() -> void:
	# First call: generates and caches.
	var drop1 := _sut._generate_loot_internal(
		"T-abc123", LootEnums.SourceEventKind.WORKOUT_DAILY, 0.65
	)
	# Second call: must return the SAME cached LootDrop instance.
	var drop2 := _sut._generate_loot_internal(
		"T-abc123", LootEnums.SourceEventKind.WORKOUT_DAILY, 0.65
	)
	assert_eq(drop1, drop2,
		"AC-21: second call with same transition_id must return the cached LootDrop")


func test_ac21_cache_hit_does_not_create_new_drop_id() -> void:
	# First call → unique drop_id.
	var drop1 := _sut._generate_loot_internal(
		"T-idem001", LootEnums.SourceEventKind.MINI_BOSS, 0.5
	)
	var first_drop_id: String = drop1.drop_id
	# Second call → same drop_id (no new drop generated).
	var drop2 := _sut._generate_loot_internal(
		"T-idem001", LootEnums.SourceEventKind.MINI_BOSS, 0.5
	)
	assert_eq(drop2.drop_id, first_drop_id,
		"AC-21: cached drop must return the original drop_id — no new generation")


func test_ac21_cache_stored_in_drops_by_transition() -> void:
	# After first call, _drops_by_transition["T-xyz"] must be set.
	_sut._generate_loot_internal(
		"T-xyz", LootEnums.SourceEventKind.WORKOUT_DAILY, 0.4
	)
	assert_true(_sut._drops_by_transition.has("T-xyz"),
		"AC-21: _drops_by_transition must contain the generated drop after first call")


func test_ac21_pre_seeded_cache_returned_without_generation() -> void:
	# Pre-seed cache with a known drop.
	var pre_seeded := LootDrop.new()
	pre_seeded.drop_id = "D-preseeded"
	pre_seeded.transition_id = "T-seeded"
	pre_seeded.rarity_tier = "EPIC"
	_sut._drops_by_transition["T-seeded"] = pre_seeded

	# Call with same transition_id → must return pre-seeded drop.
	var result := _sut._generate_loot_internal(
		"T-seeded", LootEnums.SourceEventKind.WORKOUT_DAILY, 0.99
	)
	assert_eq(result.drop_id, "D-preseeded",
		"AC-21: pre-seeded cache entry must be returned as-is")
	assert_eq(result.rarity_tier, "EPIC",
		"AC-21: cached rarity_tier must be preserved unchanged")


func test_ac21_different_transition_ids_get_independent_drops() -> void:
	var drop_a := _sut._generate_loot_internal(
		"T-alpha", LootEnums.SourceEventKind.WORKOUT_DAILY, 0.6
	)
	var drop_b := _sut._generate_loot_internal(
		"T-beta", LootEnums.SourceEventKind.WORKOUT_DAILY, 0.6
	)
	# Both cached independently.
	assert_true(_sut._drops_by_transition.has("T-alpha"))
	assert_true(_sut._drops_by_transition.has("T-beta"))
	assert_ne(drop_a.drop_id, drop_b.drop_id,
		"Different transition_ids must generate independent drops with different drop_ids")

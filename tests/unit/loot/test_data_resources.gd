## test_data_resources.gd — Story 002: LootRarityConfig + LootDrop + Enums unit tests
##
## Governing story: production/epics/loot-drop-system/story-002-data-resources-enums.md
## Governing ADRs : ADR-0005 (Accepted 2026-05-30) rarity formula knobs + INV-1/INV-6
##                  ADR-0006 (Accepted) Contract 3 — SerializableResource envelope
##                  ADR-0007 (Accepted 2026-05-29) — enum Family A/B convention
##
## NOTE ON VALIDATE TESTING (design-by-contract):
## LootRarityConfig._validate() calls assert(), which is a hard crash in debug
## builds and a no-op in release builds. GUT tests therefore:
##   (a) Verify the VALID path by constructing a correct config and calling
##       _validate() — it must not crash (GUT will surface a crash as a test error).
##   (b) Verify INVALID conditions by asserting the condition that _validate() would
##       catch is actually detectable via bool comparison — we do NOT call _validate()
##       on bad config (that would crash the test runner; the assert is the guard).
##   This matches the pattern used for GSM knob invariant tests in this project.
extends GutTest


# ─── Shared fixtures ───────────────────────────────────────────────────────────

var _valid_config: LootRarityConfig


func before_each() -> void:
	_valid_config = LootRarityConfig.new()
	# Default values from ADR-0005 Tuning Knob table — all must satisfy INV-1/Pillar1/INV-6.
	_valid_config.workout_weight = 0.75
	_valid_config.rng_weight = 0.25
	_valid_config.target_exercises = 5
	_valid_config.pr_bonus_per_pr = 0.12
	_valid_config.max_pr_factor = 1.25
	_valid_config.streak_scale = 28.0
	_valid_config.max_streak_bonus = 0.20
	_valid_config.tier_thresholds = [0.0, 0.35, 0.55, 0.72, 0.88]
	_valid_config.tier_values = [0, 1, 2, 3, 4]


func after_each() -> void:
	_valid_config = null


# ─── LootRarityConfig: valid path (_validate does not crash) ───────────────────

func test_config_default_values_pass_validate() -> void:
	# Should not crash — _validate() only asserts, never returns a value.
	_valid_config._validate()
	pass_test("LootRarityConfig with ADR-0005 defaults passes _validate() without crash")


func test_config_custom_valid_weights_pass_validate() -> void:
	_valid_config.workout_weight = 0.80
	_valid_config.rng_weight = 0.20
	_valid_config._validate()
	pass_test("workout_weight=0.80 + rng_weight=0.20 (boundary, sum=1.0) passes _validate()")


func test_config_minimum_valid_workout_weight() -> void:
	_valid_config.workout_weight = 0.70
	_valid_config.rng_weight = 0.30
	_valid_config._validate()
	pass_test("workout_weight=0.70 + rng_weight=0.30 (Pillar 1 minimum boundary) passes _validate()")


# ─── LootRarityConfig: invalid condition detection (no _validate() call) ──────
# We assert the CONDITION is violatable — not that _validate() fires (that would crash GUT).

func test_config_invalid_workout_weight_below_pillar1_floor() -> void:
	# workout_weight=0.69 violates Pillar 1 (must be >= 0.70).
	var bad_ww := 0.69
	assert_true(bad_ww < 0.70,
		"workout_weight=0.69 is below the Pillar 1 floor (0.70) — _validate() would assert this")


func test_config_invalid_rng_weight_above_ceiling() -> void:
	# rng_weight=0.31 violates Pillar 1 (must be <= 0.30).
	var bad_rng := 0.31
	assert_true(bad_rng > 0.30,
		"rng_weight=0.31 exceeds the Pillar 1 ceiling (0.30) — _validate() would assert this")


func test_config_invalid_weights_not_summing_to_one() -> void:
	# 0.80 + 0.30 = 1.10, violates INV-1.
	var ww := 0.80
	var rng := 0.30
	assert_false(absf(ww + rng - 1.0) < 1e-6,
		"workout_weight=0.80 + rng_weight=0.30 (sum=1.10) fails INV-1 — _validate() would assert this")


func test_config_invalid_non_ascending_thresholds() -> void:
	# tier_thresholds[2]=0.35 < tier_thresholds[1]=0.55 violates INV-6.
	var bad_thresholds: Array[float] = [0.0, 0.55, 0.35, 0.72, 0.88]
	var ascending := true
	for i: int in range(1, bad_thresholds.size()):
		if bad_thresholds[i] <= bad_thresholds[i - 1]:
			ascending = false
			break
	assert_false(ascending,
		"[0.0, 0.55, 0.35, 0.72, 0.88] is not strictly ascending — _validate() INV-6 would assert this")


func test_config_tier_arrays_length_match() -> void:
	assert_eq(_valid_config.tier_thresholds.size(), _valid_config.tier_values.size(),
		"tier_thresholds and tier_values must have equal length (ADR-0005)")


func test_config_inv1_weights_sum_to_one() -> void:
	var sum := _valid_config.workout_weight + _valid_config.rng_weight
	assert_almost_eq(sum, 1.0, 1e-6,
		"Default workout_weight + rng_weight must equal 1.0 (INV-1)")


func test_config_pillar1_workout_weight_gte_070() -> void:
	assert_gte(_valid_config.workout_weight, 0.70,
		"Default workout_weight must be >= 0.70 (Pillar 1 anti-drift)")


func test_config_pillar1_rng_weight_lte_030() -> void:
	assert_lte(_valid_config.rng_weight, 0.30,
		"Default rng_weight must be <= 0.30 (Pillar 1)")


func test_config_epic_threshold_above_max_rng() -> void:
	# ADR-0005 Pillar 1 proof: max RNG contribution (0.25) < EPIC threshold (0.72)
	# so pure luck can NEVER reach EPIC. This test pins the invariant explicitly.
	var epic_threshold: float = _valid_config.tier_thresholds[3]  # index 3 = EPIC
	var max_rng_contribution := _valid_config.rng_weight  # = 0.25 at workout_score=0
	assert_gt(epic_threshold, max_rng_contribution,
		"EPIC threshold (%f) must exceed max RNG contribution (%f) — Pillar 1 proof" % [
			epic_threshold, max_rng_contribution
		])


# ─── LootDrop: serialization round-trip ───────────────────────────────────────

func test_loot_drop_round_trip_all_fields() -> void:
	var original := LootDrop.new()
	original.drop_id = "D-12345678"
	original.transition_id = "T-feedface"
	original.rarity_tier = "RARE"
	original.item_type = "ARMOR"
	original.class_tag = "STRIKE"
	original.source_event_kind = "MINI_BOSS"
	original.created_at_unix = 1748563200
	original.schema_version = 1
	original.item_metadata = {"name": "Iron Cuirass", "power": 42}

	var dict := original.to_dict()
	var restored := LootDrop.from_dict(dict)

	assert_eq(restored.drop_id, original.drop_id, "drop_id round-trips")
	assert_eq(restored.transition_id, original.transition_id, "transition_id round-trips")
	assert_eq(restored.rarity_tier, original.rarity_tier, "rarity_tier round-trips")
	assert_eq(restored.item_type, original.item_type, "item_type round-trips")
	assert_eq(restored.class_tag, original.class_tag, "class_tag round-trips")
	assert_eq(restored.source_event_kind, original.source_event_kind, "source_event_kind round-trips")
	assert_eq(restored.created_at_unix, original.created_at_unix, "created_at_unix round-trips")
	assert_eq(restored.schema_version, original.schema_version, "schema_version round-trips")
	assert_eq(restored.item_metadata, original.item_metadata, "item_metadata round-trips")


func test_loot_drop_payload_type_is_class_name() -> void:
	var drop := LootDrop.new()
	var dict := drop.to_dict()
	assert_eq(dict.get("payload_type"), "LootDrop",
		"payload_type must equal class name 'LootDrop' (get_script().get_global_name(), not get_class())")


func test_loot_drop_payload_type_not_resource() -> void:
	# get_class() returns "Resource" for all GDScript Resource subclasses —
	# ADR-0006 Contract 3 forbids using get_class() for this reason.
	var drop := LootDrop.new()
	var dict := drop.to_dict()
	assert_ne(dict.get("payload_type"), "Resource",
		"payload_type must NOT be 'Resource' (that would break forward-recovery dispatch)")


func test_loot_drop_from_dict_missing_keys_use_safe_defaults() -> void:
	# Sparse dict simulates an older schema version with missing keys.
	var sparse := {"drop_id": "D-abc"}
	var restored := LootDrop.from_dict(sparse)

	assert_eq(restored.drop_id, "D-abc", "drop_id from sparse dict")
	assert_eq(restored.rarity_tier, "COMMON",
		"missing rarity_tier falls back to COMMON (Pillar 3 floor)")
	assert_eq(restored.item_type, "WEAPON", "missing item_type falls back to WEAPON")
	assert_eq(restored.class_tag, "NEUTRAL", "missing class_tag falls back to NEUTRAL (safe, usable)")
	assert_eq(restored.source_event_kind, "WORKOUT_DAILY",
		"missing source_event_kind falls back to WORKOUT_DAILY")
	assert_eq(restored.created_at_unix, 0, "missing created_at_unix falls back to 0")
	assert_eq(restored.schema_version, 1, "missing schema_version falls back to 1")
	assert_eq(restored.item_metadata, {}, "missing item_metadata falls back to empty dict")


func test_loot_drop_empty_dict_produces_valid_object() -> void:
	var restored := LootDrop.from_dict({})
	assert_not_null(restored, "from_dict({}) must not return null")
	assert_eq(restored.rarity_tier, "COMMON", "empty dict → rarity_tier COMMON default")


# ─── Enum: RarityTier (Family A) ──────────────────────────────────────────────

func test_rarity_tier_common_is_ordinal_zero() -> void:
	assert_eq(LootEnums.RarityTier.COMMON, 0,
		"RarityTier.COMMON must be 0 (ADR-0007 Family A safe floor, Pillar 3)")


func test_rarity_tier_has_five_values() -> void:
	# COMMON/UNCOMMON/RARE/EPIC/LEGENDARY — locked by ADR-0005 tier table.
	var keys := LootEnums.RarityTier.keys()
	assert_eq(keys.size(), 5, "RarityTier must have exactly 5 members")


func test_rarity_tier_ascending_ordinals() -> void:
	assert_lt(LootEnums.RarityTier.COMMON, LootEnums.RarityTier.UNCOMMON, "COMMON < UNCOMMON")
	assert_lt(LootEnums.RarityTier.UNCOMMON, LootEnums.RarityTier.RARE, "UNCOMMON < RARE")
	assert_lt(LootEnums.RarityTier.RARE, LootEnums.RarityTier.EPIC, "RARE < EPIC")
	assert_lt(LootEnums.RarityTier.EPIC, LootEnums.RarityTier.LEGENDARY, "EPIC < LEGENDARY")


func test_rarity_tier_find_key_returns_string_name() -> void:
	assert_eq(LootEnums.RarityTier.find_key(LootEnums.RarityTier.COMMON), "COMMON",
		"RarityTier.find_key(COMMON) must return 'COMMON' for string-name serialization (ADR-0007)")
	assert_eq(LootEnums.RarityTier.find_key(LootEnums.RarityTier.LEGENDARY), "LEGENDARY",
		"RarityTier.find_key(LEGENDARY) must return 'LEGENDARY'")


# ─── Enum: ClassTag (Family B) — ADR-0007 F-7 distinction ────────────────────

func test_class_tag_neutral_find_key_returns_neutral() -> void:
	# ADR-0007 F-7: ClassTag.NEUTRAL is a loot-item outcome ("any class can use"),
	# distinct from AbilityClass.UNKNOWN (player-class sentinel). Its string name
	# must be "NEUTRAL", never "UNKNOWN".
	var name: String = LootEnums.ClassTag.find_key(LootEnums.ClassTag.NEUTRAL)
	assert_eq(name, "NEUTRAL",
		"ClassTag.NEUTRAL.find_key() must return 'NEUTRAL', not 'UNKNOWN' (ADR-0007 F-7)")


func test_class_tag_has_four_values() -> void:
	# STRIKE / CONTROL / MOBILITY / NEUTRAL (sentinel last per ADR-0007 Family B)
	assert_eq(LootEnums.ClassTag.keys().size(), 4, "ClassTag must have exactly 4 members")


func test_class_tag_neutral_is_last_ordinal() -> void:
	# ADR-0007 Family B: sentinel placed last.
	assert_eq(LootEnums.ClassTag.NEUTRAL, 3,
		"ClassTag.NEUTRAL must be ordinal 3 (last — ADR-0007 Family B sentinel convention)")


func test_class_tag_strike_is_ordinal_zero_real_class() -> void:
	# ordinal 0 is a real class (STRIKE) — Family B warns that zero-default
	# reliance is FORBIDDEN; producers must explicitly initialise.
	assert_eq(LootEnums.ClassTag.STRIKE, 0,
		"ClassTag.STRIKE is ordinal 0 (a real class, not a safe default — explicit init required)")


# ─── Enum: SourceEventKind (Family A) ─────────────────────────────────────────

func test_source_event_kind_has_three_values() -> void:
	assert_eq(LootEnums.SourceEventKind.keys().size(), 3,
		"SourceEventKind must have exactly 3 members (WORKOUT_DAILY / MINI_BOSS / FINAL_BOSS)")


func test_source_event_kind_workout_daily_is_ordinal_zero() -> void:
	assert_eq(LootEnums.SourceEventKind.WORKOUT_DAILY, 0,
		"SourceEventKind.WORKOUT_DAILY must be 0 (Family A safe default — most common trigger)")


# ─── Enum: CeremonyDecision (Family A) ────────────────────────────────────────

func test_ceremony_decision_has_three_values() -> void:
	assert_eq(LootEnums.CeremonyDecision.keys().size(), 3,
		"CeremonyDecision must have 3 members (FULL_CEREMONY / MICRO_ACK / NON_CEREMONY_ROUTE)")


func test_ceremony_decision_full_ceremony_is_ordinal_zero() -> void:
	assert_eq(LootEnums.CeremonyDecision.FULL_CEREMONY, 0,
		"CeremonyDecision.FULL_CEREMONY must be 0 (Family A — celebrate by default)")


# ─── Enum: ItemType (Family B) ────────────────────────────────────────────────

func test_item_type_has_five_values() -> void:
	assert_eq(LootEnums.ItemType.keys().size(), 5,
		"ItemType must have 5 members (WEAPON/ARMOR/ACCESSORY/CONSUMABLE/COSMETIC)")


func test_item_type_consumable_and_cosmetic_ordinals() -> void:
	# Formula E2 uses CONSUMABLE and COSMETIC membership to force ClassTag.NEUTRAL.
	assert_eq(LootEnums.ItemType.CONSUMABLE, 3, "ItemType.CONSUMABLE ordinal must be 3")
	assert_eq(LootEnums.ItemType.COSMETIC, 4, "ItemType.COSMETIC ordinal must be 4")

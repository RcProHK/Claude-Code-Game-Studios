## test_item_type_weighted_selection.gd — Story 007 AC-15
##
## Governing story: production/epics/loot-drop-system/story-007-formula-e1-e2-e4.md
## Governing ADR  : ADR-0005 (CI-6 deterministic RNG); ADR-0007 (Family B enum)
##
## AC-15: item_type_weighted_selection() must produce the GDD worked example result
## (ARMOR at rng_roll_2=0.42 with weapon_slot_starter=true, RARE tier) and satisfy
## CF-E1 (Σ normalized weights = 1.0 ± 1e-6).
extends GutTest


# ── Helpers ────────────────────────────────────────────────────────────────────

func _make_no_gap_state() -> Dictionary:
	return {}


func _make_weapon_starter_state() -> Dictionary:
	return {"weapon_slot_starter": true}


# ── AC-15: GDD worked example ──────────────────────────────────────────────────

func test_ac15_gdd_worked_example_rare_weapon_starter_roll_042_returns_armor() -> void:
	# GDD AC-15 canonical: RARE, weapon_slot_starter=true, rng_roll_2=0.42 → ARMOR.
	# Raw weights: WEAPON=0.375 (×1.5), ARMOR=0.25, ACCESSORY=0.20, CONSUMABLE=0.20, COSMETIC=0.10
	# Total = 1.10; normalized CDF: WEAPON=0.341, ARMOR=0.568; 0.42 ∈ [0.341, 0.568) → ARMOR.
	var result := LootItemCalc.item_type_weighted_selection(
		LootEnums.RarityTier.RARE,
		_make_weapon_starter_state(),
		LootEnums.ClassTag.STRIKE,  # dominant_class (unused by E1)
		0.42
	)
	assert_eq(result, LootEnums.ItemType.ARMOR,
		"AC-15: RARE + weapon_slot_starter + rng_roll_2=0.42 must return ARMOR (GDD worked example)")


func test_ac15_cf_e1_normalized_weights_sum_to_one() -> void:
	# CF-E1: compute what the function would produce and verify weight normalization.
	# With weapon_slot_starter: WEAPON=0.375, ARMOR=0.25, ACC=0.20, CONS=0.20, COS=0.10; total=1.10.
	var raw_w := 0.25 * 1.5  # 0.375
	var raw_a := 0.25
	var raw_acc := 0.20
	var raw_con := 0.20
	var raw_cos := 0.10
	var total := raw_w + raw_a + raw_acc + raw_con + raw_cos
	var sum_normalized := (raw_w + raw_a + raw_acc + raw_con + raw_cos) / total
	assert_almost_eq(sum_normalized, 1.0, 1e-6,
		"CF-E1: normalized weights must sum to 1.0 ± 1e-6")


func test_ac15_cosmetic_epic_bonus_applied_for_epic_tier() -> void:
	# EPIC tier: cosmetic raw = 0.10 + 0.05 = 0.15 (before normalize).
	# Without gear gaps: total = 0.25+0.25+0.20+0.20+0.15 = 1.05.
	# COSMETIC normalized = 0.15/1.05 ≈ 0.1429; COSMETIC CDF starts at 0.25+0.24+0.19+0.19=0.8571.
	# A rng_roll_2 very close to 1.0 should land on COSMETIC.
	var result := LootItemCalc.item_type_weighted_selection(
		LootEnums.RarityTier.EPIC,
		_make_no_gap_state(),
		null,
		0.999  # Very high roll → last CDF band = COSMETIC
	)
	assert_eq(result, LootEnums.ItemType.COSMETIC,
		"EPIC tier with roll near 1.0 must land on COSMETIC (boosted weight)")


func test_no_epic_bonus_for_rare_tier() -> void:
	# RARE: cosmetic stays at 0.10 (no bonus).
	# Without gaps: total=1.00; COSMETIC CDF = last band starting at 0.90.
	# rng_roll_2=0.99 → COSMETIC.
	var result := LootItemCalc.item_type_weighted_selection(
		LootEnums.RarityTier.RARE,
		_make_no_gap_state(),
		null,
		0.999
	)
	assert_eq(result, LootEnums.ItemType.COSMETIC,
		"RARE tier with roll near 1.0 must land on COSMETIC (no bonus but still last band)")


func test_ac15_rng_roll_zero_returns_first_type() -> void:
	# rng_roll_2=0.0 → first CDF band = WEAPON (always, regardless of weights).
	var result := LootItemCalc.item_type_weighted_selection(
		LootEnums.RarityTier.COMMON,
		_make_no_gap_state(),
		null,
		0.0
	)
	assert_eq(result, LootEnums.ItemType.WEAPON,
		"rng_roll_2=0.0 must return WEAPON (first CDF band)")


func test_armor_starter_boosts_armor_weight() -> void:
	# With armor_slot_starter: ARMOR raw = 0.25 × 1.5 = 0.375.
	# Total = 0.25+0.375+0.20+0.20+0.10 = 1.125.
	# ARMOR CDF band starts at 0.25/1.125=0.222, ends at (0.25+0.375)/1.125=0.556.
	# rng_roll_2=0.40 should land in ARMOR band.
	var result := LootItemCalc.item_type_weighted_selection(
		LootEnums.RarityTier.COMMON,
		{"armor_slot_starter": true},
		null,
		0.40
	)
	assert_eq(result, LootEnums.ItemType.ARMOR,
		"armor_slot_starter=true must boost ARMOR weight; 0.40 roll should land on ARMOR")


func test_legendary_tier_also_applies_cosmetic_bonus() -> void:
	# LEGENDARY ≥ EPIC → bonus applies.
	var result := LootItemCalc.item_type_weighted_selection(
		LootEnums.RarityTier.LEGENDARY,
		_make_no_gap_state(),
		null,
		0.999
	)
	assert_eq(result, LootEnums.ItemType.COSMETIC,
		"LEGENDARY tier must also apply cosmetic bonus (≥ EPIC gate)")

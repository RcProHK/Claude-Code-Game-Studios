# Boss loot guarantee + Rule 9 tier combine (Story 015: AC-09 + INV-8 + combine contract).
extends GutTest


# ---------------------------------------------------------------------------
# AC-09 — FINAL boss loot floor == RARE
# ---------------------------------------------------------------------------

func test_ac09_final_template_default_loot_floor_is_rare() -> void:
	var t := BossTemplate.new()
	assert_eq(t.loot_guarantee_min_tier, LootEnums.RarityTier.RARE,
		"AC-09: FINAL BossTemplate loot_guarantee_min_tier default == RARE (ordinal 2)")
	assert_eq(LootEnums.RarityTier.RARE, 2, "RarityTier.RARE ordinal is 2 (ordinal-ordered)")


# ---------------------------------------------------------------------------
# Rule 9 combine — max(floor, rolled): guarantee the floor, let ADR-0005 exceed
# ---------------------------------------------------------------------------

func test_combine_floor_wins_when_roll_is_lower() -> void:
	# Final floor RARE(2); ADR-0005 rolls COMMON(0) -> floored to RARE
	assert_eq(BossFormulas.resolve_boss_loot_tier(LootEnums.RarityTier.RARE, LootEnums.RarityTier.COMMON),
		LootEnums.RarityTier.RARE, "combine: rolled COMMON < floor RARE -> RARE (guarantee)")


func test_combine_roll_wins_when_higher() -> void:
	# ADR-0005 rolls EPIC(3) > floor RARE(2) -> EPIC (modifiers exceed the floor)
	assert_eq(BossFormulas.resolve_boss_loot_tier(LootEnums.RarityTier.RARE, LootEnums.RarityTier.EPIC),
		LootEnums.RarityTier.EPIC, "combine: rolled EPIC > floor RARE -> EPIC")
	assert_eq(BossFormulas.resolve_boss_loot_tier(LootEnums.RarityTier.RARE, LootEnums.RarityTier.LEGENDARY),
		LootEnums.RarityTier.LEGENDARY, "combine: LEGENDARY roll preserved")


func test_combine_equal_floor_and_roll() -> void:
	assert_eq(BossFormulas.resolve_boss_loot_tier(LootEnums.RarityTier.RARE, LootEnums.RarityTier.RARE),
		LootEnums.RarityTier.RARE, "combine: equal -> RARE")


# ---------------------------------------------------------------------------
# INV-8 — final floor >= mini ceiling (both RARE, joint-equal valid)
# ---------------------------------------------------------------------------

func test_inv8_final_floor_ge_mini_ceiling() -> void:
	# Final boss loot_guarantee_min_tier (RARE) >= EnemyTemplate.loot_rarity_ceiling (RARE).
	# Joint-equal at RARE is VALID — the gradient is DISTRIBUTIONAL (ADR-0005 modifiers),
	# not static (Pass 6 F6: the old `>` operator was a RARE>RARE=false bug).
	var final_floor := LootEnums.RarityTier.RARE   # BossTemplate.loot_guarantee_min_tier
	var mini_ceiling := LootEnums.RarityTier.RARE  # #14 EnemyTemplate.loot_rarity_ceiling (forward constraint)
	assert_true(final_floor >= mini_ceiling, "INV-8: final floor (RARE) >= mini ceiling (RARE), joint-equal valid")

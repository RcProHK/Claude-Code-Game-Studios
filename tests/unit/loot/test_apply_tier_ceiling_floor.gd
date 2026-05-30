## test_apply_tier_ceiling_floor.gd — Story 003 AC-03 / AC-04 / AC-05 + edge cases
##
## Governing story: production/epics/loot-drop-system/story-003-formula-1-pillar1-proofs.md
## Governing ADR  : ADR-0005 (Accepted 2026-05-30) Loot Rarity Formula
##
## Covers Formula 1 source-event ceiling/floor (apply_tier_ceiling_floor) and the
## data-driven tier mapping (tier_from_score):
##   AC-03 — MINI_BOSS dual-gate: hard RARE ceiling + workout-score ceiling floor(ws×5).
##   AC-04 — FINAL_BOSS floor: lift to at least UNCOMMON, no upper ceiling.
##   AC-05 — Zero-workout guard: ws=0.0 forces COMMON, outranking every other rule.
extends GutTest


# ─── Shared fixture ────────────────────────────────────────────────────────────

func _make_default_config() -> LootRarityConfig:
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


# ─── AC-03: MINI_BOSS hard RARE ceiling ────────────────────────────────────────

func test_ac03_mini_boss_epic_clamped_to_rare() -> void:
	# Arrange: EPIC raw, mini-boss, ws=0.78 (ws_ceiling=floor(0.78×5)=3=EPIC),
	# but the hard cap is RARE (ordinal 2).
	# Act
	var result := LootRarityCalc.apply_tier_ceiling_floor(
		LootEnums.RarityTier.EPIC, LootEnums.SourceEventKind.MINI_BOSS, 0.78)
	# Assert: hard RARE ceiling wins.
	assert_eq(result, LootEnums.RarityTier.RARE,
		"MINI_BOSS EPIC raw must clamp to the hard RARE ceiling (INV-10)")


func test_ac03_mini_boss_rare_unchanged() -> void:
	# Arrange: RARE raw, mini-boss, ws=0.60 (ws_ceiling=floor(3.0)=3), within ceilings.
	# Act
	var result := LootRarityCalc.apply_tier_ceiling_floor(
		LootEnums.RarityTier.RARE, LootEnums.SourceEventKind.MINI_BOSS, 0.60)
	# Assert: RARE is at the hard cap and below the ws_ceiling → unchanged.
	assert_eq(result, LootEnums.RarityTier.RARE,
		"MINI_BOSS RARE raw within both ceilings must remain RARE")


func test_ac03_mini_boss_epic_clamped_by_workout_score() -> void:
	# Arrange: RARE raw, mini-boss, ws=0.19 → ws_ceiling=floor(0.19×5)=floor(0.95)=0.
	# The workout-score ceiling (0 = COMMON) is stricter than the hard RARE cap.
	# Act
	var result := LootRarityCalc.apply_tier_ceiling_floor(
		LootEnums.RarityTier.RARE, LootEnums.SourceEventKind.MINI_BOSS, 0.19)
	# Assert: clamped down to COMMON by the workout-score ceiling.
	assert_eq(result, LootEnums.RarityTier.COMMON,
		"MINI_BOSS ws=0.19 (ws_ceiling=0) must clamp RARE down to COMMON")


func test_ac03_mini_boss_pillar3_floor() -> void:
	# Arrange: COMMON raw, mini-boss, ws=0.6. Already at the floor.
	# Act
	var result := LootRarityCalc.apply_tier_ceiling_floor(
		LootEnums.RarityTier.COMMON, LootEnums.SourceEventKind.MINI_BOSS, 0.6)
	# Assert: Pillar 3 floor holds COMMON.
	assert_eq(result, LootEnums.RarityTier.COMMON,
		"MINI_BOSS COMMON raw must stay COMMON (Pillar 3 floor)")


# ─── AC-04: FINAL_BOSS floor ───────────────────────────────────────────────────

func test_ac04_final_boss_common_lifted_to_uncommon() -> void:
	# Arrange: COMMON raw, final-boss, ws=0.4.
	# Act
	var result := LootRarityCalc.apply_tier_ceiling_floor(
		LootEnums.RarityTier.COMMON, LootEnums.SourceEventKind.FINAL_BOSS, 0.4)
	# Assert: final-boss floor lifts COMMON to UNCOMMON (INV-10).
	assert_eq(result, LootEnums.RarityTier.UNCOMMON,
		"FINAL_BOSS COMMON raw must lift to UNCOMMON (final-boss floor)")


func test_ac04_final_boss_legendary_unchanged() -> void:
	# Arrange: LEGENDARY raw, final-boss, ws=0.9. No upper ceiling for final boss.
	# Act
	var result := LootRarityCalc.apply_tier_ceiling_floor(
		LootEnums.RarityTier.LEGENDARY, LootEnums.SourceEventKind.FINAL_BOSS, 0.9)
	# Assert: LEGENDARY passes through untouched.
	assert_eq(result, LootEnums.RarityTier.LEGENDARY,
		"FINAL_BOSS LEGENDARY raw must remain LEGENDARY (no ceiling on final boss)")


func test_ac04_final_boss_rare_unchanged() -> void:
	# Arrange: RARE raw, final-boss, ws=0.5. RARE is already above the UNCOMMON floor.
	# Act
	var result := LootRarityCalc.apply_tier_ceiling_floor(
		LootEnums.RarityTier.RARE, LootEnums.SourceEventKind.FINAL_BOSS, 0.5)
	# Assert: no change (already ≥ UNCOMMON floor).
	assert_eq(result, LootEnums.RarityTier.RARE,
		"FINAL_BOSS RARE raw must remain RARE (already above the UNCOMMON floor)")


# ─── AC-05: zero-workout guard overrides ALL ───────────────────────────────────

func test_ac05_zero_workout_overrides_workout_daily() -> void:
	# Arrange: LEGENDARY raw, workout-daily, ws=0.0.
	# Act
	var result := LootRarityCalc.apply_tier_ceiling_floor(
		LootEnums.RarityTier.LEGENDARY, LootEnums.SourceEventKind.WORKOUT_DAILY, 0.0)
	# Assert: zero-workout guard forces COMMON.
	assert_eq(result, LootEnums.RarityTier.COMMON,
		"ws=0.0 must force COMMON on WORKOUT_DAILY (zero-workout guard)")


func test_ac05_zero_workout_overrides_final_boss_floor() -> void:
	# Arrange: LEGENDARY raw, final-boss, ws=0.0. The guard must outrank the floor.
	# Act
	var result := LootRarityCalc.apply_tier_ceiling_floor(
		LootEnums.RarityTier.LEGENDARY, LootEnums.SourceEventKind.FINAL_BOSS, 0.0)
	# Assert: COMMON — zero-workout guard is highest priority.
	assert_eq(result, LootEnums.RarityTier.COMMON,
		"ws=0.0 must override the FINAL_BOSS floor (zero-workout guard highest priority)")


func test_ac05_zero_workout_overrides_mini_boss() -> void:
	# Arrange: RARE raw, mini-boss, ws=0.0.
	# Act
	var result := LootRarityCalc.apply_tier_ceiling_floor(
		LootEnums.RarityTier.RARE, LootEnums.SourceEventKind.MINI_BOSS, 0.0)
	# Assert: COMMON — guard short-circuits before the dual-gate.
	assert_eq(result, LootEnums.RarityTier.COMMON,
		"ws=0.0 must force COMMON on MINI_BOSS (zero-workout guard)")


# ─── WORKOUT_DAILY Pillar 3 floor (raw below COMMON) ───────────────────────────

func test_workout_daily_pillar3_floor() -> void:
	# Arrange: a raw tier below COMMON (-1, a degenerate input), workout-daily, ws=0.3.
	# Act
	var result := LootRarityCalc.apply_tier_ceiling_floor(
		-1, LootEnums.SourceEventKind.WORKOUT_DAILY, 0.3)
	# Assert: Pillar 3 floor lifts it to COMMON.
	assert_eq(result, LootEnums.RarityTier.COMMON,
		"WORKOUT_DAILY raw below COMMON must be floored to COMMON (Pillar 3)")


# ─── tier_from_score boundary behaviour ────────────────────────────────────────

func test_tier_from_score_epic_boundary() -> void:
	# Arrange: score exactly at the EPIC threshold (0.72), inclusive.
	var config := _make_default_config()
	# Act
	var result := LootRarityCalc.tier_from_score(0.72, config)
	# Assert: 0.72 >= 0.72 → EPIC.
	assert_eq(result, LootEnums.RarityTier.EPIC,
		"score=0.72 is the inclusive EPIC threshold → EPIC")


func test_tier_from_score_legendary_boundary() -> void:
	# Arrange: score exactly at the LEGENDARY threshold (0.88), inclusive.
	var config := _make_default_config()
	# Act
	var result := LootRarityCalc.tier_from_score(0.88, config)
	# Assert
	assert_eq(result, LootEnums.RarityTier.LEGENDARY,
		"score=0.88 is the inclusive LEGENDARY threshold → LEGENDARY")


func test_tier_from_score_below_common() -> void:
	# Arrange: score=0.10, below the UNCOMMON threshold (0.35) but above 0.0.
	var config := _make_default_config()
	# Act
	var result := LootRarityCalc.tier_from_score(0.10, config)
	# Assert: only the 0.0 threshold (index 0 = COMMON) is met → COMMON.
	assert_eq(result, LootEnums.RarityTier.COMMON,
		"score=0.10 meets only the 0.0 threshold → COMMON (Pillar 3 floor via tier table)")


func test_tier_from_score_zero() -> void:
	# Arrange: score=0.0, the lowest possible clamped score.
	var config := _make_default_config()
	# Act
	var result := LootRarityCalc.tier_from_score(0.0, config)
	# Assert: 0.0 >= tier_thresholds[0]=0.0 → COMMON.
	assert_eq(result, LootEnums.RarityTier.COMMON,
		"score=0.0 → COMMON (meets the 0.0 baseline threshold)")

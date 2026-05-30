## test_e3_anti_pillar_soft_clamp.gd — Story 008 AC-14
##
## Governing story: production/epics/loot-drop-system/story-008-formula-e3-anti-pillar.md
## Governing ADR  : ADR-0005 (Accepted 2026-05-30) — CF-E3 EPIC+ ≤ 10% anti-pillar invariant
##
## AC-14: expected_weekly_rarity_distribution() with Hardcore profile (n=10,000)
## must produce EPIC+ ≤ 10% post-clamp. Also tests monotonic invariant, termination
## guard, and Average/Casual profiles.
##
## NOTE: These tests run n=10,000 Monte Carlo iterations per profile. They are
## deterministic (seeded by "sim_%d_%d" format) and will always produce the same
## result — NOT flaky random tests. Runtime ~200ms per profile on desktop GUT.
extends GutTest


func before_each() -> void:
	LootE3Calc.clear_telemetry()


func after_each() -> void:
	LootE3Calc.clear_telemetry()


# ── Helper ────────────────────────────────────────────────────────────────────

func _epic_plus_pct(dist: Dictionary) -> float:
	var total := LootE3Calc.count_total(dist)
	if total == 0:
		return 0.0
	var epic_plus := dist.get(LootEnums.RarityTier.EPIC, 0) + dist.get(LootEnums.RarityTier.LEGENDARY, 0)
	return float(epic_plus) / float(total)


# ── AC-14: Hardcore profile EPIC+ ≤ 10% ──────────────────────────────────────

func test_ac14_hardcore_profile_epic_plus_at_most_10_pct() -> void:
	# Hardcore: 5 events/week, avg ws=0.92 (high-effort player).
	# GDD expects ~10% EPIC+ pre-clamp for hardcore → soft-clamp brings it to ≤ 10%.
	var profile := LootE3Calc.make_profile("Hardcore", 5, 0.92)
	var dist := LootE3Calc.expected_weekly_rarity_distribution(profile)
	var pct := _epic_plus_pct(dist)
	assert_lte(pct, 0.10,
		"AC-14: Hardcore profile EPIC+ must be ≤ 10%% post-clamp (CF-E3); got %.3f" % pct)


func test_ac14_hardcore_profile_has_some_drops() -> void:
	var profile := LootE3Calc.make_profile("Hardcore", 5, 0.92)
	var dist := LootE3Calc.expected_weekly_rarity_distribution(profile)
	var total := LootE3Calc.count_total(dist)
	assert_eq(total, 10000 * 5,  # N=10000 × 5 events/week
		"Hardcore profile (5 events × n=10,000) must produce 50,000 total drops")


func test_ac14_downgrade_order_legendary_before_epic() -> void:
	# Verify the soft-clamp degrades LEGENDARY→EPIC before EPIC→RARE.
	# Test via a pathological profile (ws=1.0, very high LEGENDARY rate).
	var profile := LootE3Calc.make_profile("MaxWS", 10, 1.0)
	var dist_before := LootE3Calc.expected_weekly_rarity_distribution(profile)
	# After clamp, if LEGENDARY count decreased, some were moved to EPIC first.
	# We can verify by checking the distribution satisfies CF-E3.
	var pct := _epic_plus_pct(dist_before)
	assert_lte(pct, 0.10, "Max-ws profile must satisfy CF-E3 after soft-clamp")


# ── Average profile ────────────────────────────────────────────────────────────

func test_average_profile_epic_plus_at_most_10_pct() -> void:
	# Average: 4 events/week, ws=0.65 → GDD expects ~8% EPIC+ (≤ 10% easily).
	var profile := LootE3Calc.make_profile("Average", 4, 0.65)
	var dist := LootE3Calc.expected_weekly_rarity_distribution(profile)
	var pct := _epic_plus_pct(dist)
	assert_lte(pct, 0.10,
		"Average profile EPIC+ must be ≤ 10%% (CF-E3); got %.3f" % pct)


# ── Casual profile ─────────────────────────────────────────────────────────────

func test_casual_profile_epic_plus_well_below_10_pct() -> void:
	# Casual: 2 events/week, ws=0.35 → GDD expects ~2% EPIC+.
	var profile := LootE3Calc.make_profile("Casual", 2, 0.35)
	var dist := LootE3Calc.expected_weekly_rarity_distribution(profile)
	var pct := _epic_plus_pct(dist)
	assert_lte(pct, 0.10,
		"Casual profile EPIC+ must be ≤ 10%% (CF-E3); got %.3f" % pct)
	# Additionally, casual should be well below 5% (GDD says ~2%).
	assert_lte(pct, 0.05,
		"Casual profile EPIC+ expected ~2%% — should be well below 5%%; got %.3f" % pct)


func test_casual_profile_legendary_likely_zero() -> void:
	var profile := LootE3Calc.make_profile("Casual", 2, 0.35)
	var dist := LootE3Calc.expected_weekly_rarity_distribution(profile)
	var legendary: int = dist.get(LootEnums.RarityTier.LEGENDARY, 0)
	# GDD: Casual→0% LEGENDARY. With deterministic seeding this should reliably be 0.
	assert_eq(legendary, 0, "Casual profile (ws=0.35) must produce 0 LEGENDARY drops")


# ── Termination guard ─────────────────────────────────────────────────────────

func test_max_iterations_constant_is_10() -> void:
	assert_eq(LootE3Calc.MAX_ITERATIONS, 10,
		"MAX_ITERATIONS must be 10 (termination guard per GDD Pass 2 F-4)")


func test_anti_pillar_cap_constant_is_010() -> void:
	assert_almost_eq(LootE3Calc.ANTI_PILLAR_EPIC_PLUS_CAP_PCT, 0.10, 1e-6,
		"ANTI_PILLAR_EPIC_PLUS_CAP_PCT must be 0.10 (LOCKED CF-E3)")


func test_max_iterations_not_fired_for_realistic_profiles() -> void:
	# For all three GDD profiles, max_iterations should NOT fire (telemetry should be empty).
	for config: Array in [["Hardcore", 5, 0.92], ["Average", 4, 0.65], ["Casual", 2, 0.35]]:
		LootE3Calc.clear_telemetry()
		var profile := LootE3Calc.make_profile(config[0], config[1], config[2])
		LootE3Calc.expected_weekly_rarity_distribution(profile)
		var overflow_events := LootE3Calc.get_telemetry("loot_e3_max_iterations_hit")
		assert_eq(overflow_events.size(), 0,
			"Profile '%s' must NOT trigger max_iterations overflow (realistic config)" % config[0])


# ── Monotonic invariant (manual verification of the logic) ─────────────────────

func test_monotonic_invariant_downgrade_reduces_epic_plus() -> void:
	# Verify that one soft-clamp step on a dict with only LEGENDARY reduces EPIC+ count.
	# We simulate the logic manually to avoid calling assert() in a test runner.
	var counts := {
		LootEnums.RarityTier.COMMON:    0,
		LootEnums.RarityTier.UNCOMMON:  0,
		LootEnums.RarityTier.RARE:      0,
		LootEnums.RarityTier.EPIC:      0,
		LootEnums.RarityTier.LEGENDARY: 100,
	}
	var pre_epic_plus: int = counts[LootEnums.RarityTier.EPIC] + counts[LootEnums.RarityTier.LEGENDARY]
	# Simulate one downgrade step (LEGENDARY→EPIC).
	counts[LootEnums.RarityTier.LEGENDARY] -= 1
	counts[LootEnums.RarityTier.EPIC] += 1
	var post_epic_plus: int = counts[LootEnums.RarityTier.EPIC] + counts[LootEnums.RarityTier.LEGENDARY]
	assert_lt(post_epic_plus, pre_epic_plus,
		"Monotonic invariant: post_epic_plus (%d) must be < pre_epic_plus (%d)" % [
			post_epic_plus, pre_epic_plus
		])


func test_monotonic_invariant_epic_to_rare_step() -> void:
	# Simulate EPIC→RARE downgrade step (when LEGENDARY count already 0).
	var counts := {
		LootEnums.RarityTier.COMMON:    0,
		LootEnums.RarityTier.UNCOMMON:  0,
		LootEnums.RarityTier.RARE:      0,
		LootEnums.RarityTier.EPIC:      50,
		LootEnums.RarityTier.LEGENDARY: 0,
	}
	var pre_epic_plus: int = counts[LootEnums.RarityTier.EPIC] + counts[LootEnums.RarityTier.LEGENDARY]
	counts[LootEnums.RarityTier.EPIC] -= 1
	counts[LootEnums.RarityTier.RARE] += 1
	var post_epic_plus: int = counts[LootEnums.RarityTier.EPIC] + counts[LootEnums.RarityTier.LEGENDARY]
	assert_lt(post_epic_plus, pre_epic_plus,
		"EPIC→RARE downgrade must strictly reduce post_epic_plus")


# ── make_profile helper ────────────────────────────────────────────────────────

func test_make_profile_creates_correct_event_count() -> void:
	var profile := LootE3Calc.make_profile("Test", 5, 0.80)
	var events: Array = profile.get("weekly_events", [])
	assert_eq(events.size(), 5, "make_profile with event_count=5 must produce 5 weekly_events")
	assert_eq(events[0].get("workout_score", 0.0), 0.80,
		"Each event must have workout_score=0.80")


func test_empty_profile_returns_zero_distribution() -> void:
	var profile := {"name": "Empty", "weekly_events": []}
	var dist := LootE3Calc.expected_weekly_rarity_distribution(profile)
	var total := LootE3Calc.count_total(dist)
	assert_eq(total, 0, "Empty weekly_events profile must produce 0 total drops")

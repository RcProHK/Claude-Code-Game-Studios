## test_pending_ttl_hard_cap.gd — Story 005 AC-11
##
## Governing story: production/epics/loot-drop-system/story-005-formula-3-4-ttl-bfcache.md
## Governing ADR  : ADR-0003 (Accepted 2026-05-30) — HARD_CAP_DAYS = 37
##                  ADR-0006 Contract 15 — raw age governs hard-cap (no drift forgiveness)
##
## AC-11: HARD boundary uses RAW age — a clock running slow cannot delay eviction
## indefinitely. Drop at 38 days old → HARD_EXPIRED regardless of clock skew.
extends GutTest


const _NOW: int = 1_748_563_200


func test_ac11_38_day_old_drop_with_slow_clock_is_hard_expired() -> void:
	# Arrange: age = 38 * 86400 = 3,283,200s. Even with a -10min slow clock
	# (subtracting 600s from effective age), raw age 3,283,200 > HARD_CAP
	# (37 * 86400 = 3,196,800) → HARD_EXPIRED.
	var created_at: int = _NOW - (38 * 86400)
	# Act
	var result := LootTtlCalc.pending_ttl_expired(created_at, _NOW)
	# Assert
	assert_eq(result, LootEnums.ExpiryState.HARD_EXPIRED,
		"38d old drop must be HARD_EXPIRED regardless of clock skew (raw age at HARD boundary)")


func test_ac11_exactly_37_day_hard_cap_is_hard_expired() -> void:
	# Boundary: age = 37 * 86400 = 3,196,800s exactly.
	# HARD check: age < HARD_CAP_DAYS * 86400 → false (3,196,800 < 3,196,800 is false) → HARD_EXPIRED.
	var created_at: int = _NOW - (37 * 86400)
	var result := LootTtlCalc.pending_ttl_expired(created_at, _NOW)
	assert_eq(result, LootEnums.ExpiryState.HARD_EXPIRED,
		"Drop at exactly 37 days (HARD_CAP boundary) must be HARD_EXPIRED (inclusive)")


func test_one_second_before_hard_cap_is_soft_expired() -> void:
	# age = 37 * 86400 - 1 = 3,196,799s: raw < HARD_CAP → NOT hard expired.
	# adjusted_age = 3,196,799 - 300 = 3,196,499 > SOFT_TTL → SOFT_EXPIRED.
	var created_at: int = _NOW - (37 * 86400 - 1)
	var result := LootTtlCalc.pending_ttl_expired(created_at, _NOW)
	assert_eq(result, LootEnums.ExpiryState.SOFT_EXPIRED,
		"Drop 1s before HARD_CAP must be SOFT_EXPIRED (not yet hard-evicted)")


func test_hard_cap_days_constant() -> void:
	assert_eq(LootTtlCalc.HARD_CAP_DAYS, 37,
		"HARD_CAP_DAYS must be 37 (SOFT_TTL + 7 grace per ADR-0003)")


func test_hard_cap_greater_than_soft_ttl() -> void:
	# INV-3 invariant: HARD_CAP > SOFT_TTL.
	assert_gt(LootTtlCalc.HARD_CAP_DAYS, LootTtlCalc.SOFT_TTL_DAYS,
		"INV-3: HARD_CAP_DAYS must be > SOFT_TTL_DAYS")


func test_very_old_drop_60_days_is_hard_expired() -> void:
	var created_at: int = _NOW - (60 * 86400)
	var result := LootTtlCalc.pending_ttl_expired(created_at, _NOW)
	assert_eq(result, LootEnums.ExpiryState.HARD_EXPIRED,
		"60-day-old drop must be HARD_EXPIRED")

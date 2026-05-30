## test_pending_ttl_drift_tolerance.gd — Story 005 AC-10
##
## Governing story: production/epics/loot-drop-system/story-005-formula-3-4-ttl-bfcache.md
## Governing ADR  : ADR-0003 (Accepted 2026-05-30) — TTL constants; CI-3 DRIFT_TOLERANCE_S
##
## AC-10: DRIFT_TOLERANCE_S = 300 prevents a client clock running ≤5 min fast
## from prematurely expiring a drop at the SOFT boundary. Adjusted_age is used
## only for the SOFT check; raw age governs the HARD check.
extends GutTest


# Reference timestamps — deterministic, no real clock calls in tests.
const _NOW: int = 1_748_563_200  # arbitrary fixed "now"


func test_ac10_drop_30d_4m_old_with_clock_fast_5m_is_fresh() -> void:
	# Arrange: age = 30d + 4min = 2,592,240s.  Clock-fast +5min means NOW is
	# effectively 5min ahead, so adjusted_age = 2,592,240 - 300 = 2,591,940.
	# SOFT_TTL = 30 * 86400 = 2,592,000 → adjusted_age < SOFT_TTL → FRESH.
	var created_at: int = _NOW - 2_592_240
	# Act
	var result := LootTtlCalc.pending_ttl_expired(created_at, _NOW)
	# Assert
	assert_eq(result, LootEnums.ExpiryState.FRESH,
		"30d+4m age with clock-fast +5m must be FRESH (drift tolerance saves edge case)")


func test_ac10_drop_exactly_at_soft_boundary_no_drift_is_fresh() -> void:
	# Arrange: age = 30 * 86400 = 2,592,000s exactly, no drift.
	# adjusted_age = 2,592,000 - 300 = 2,591,700 < 2,592,000 → FRESH.
	var created_at: int = _NOW - (30 * 86400)
	var result := LootTtlCalc.pending_ttl_expired(created_at, _NOW)
	assert_eq(result, LootEnums.ExpiryState.FRESH,
		"Drop exactly at SOFT boundary (no drift) must be FRESH (adjusted_age still < TTL)")


func test_ac10_drop_past_soft_boundary_by_300s_is_soft_expired() -> void:
	# Arrange: age = 30 * 86400 + 300 + 1 = 2,592,301s.
	# adjusted_age = 2,592,001 > 2,592,000 → not FRESH.
	# raw_age = 2,592,301 < HARD_CAP (37 * 86400 = 3,196,800) → SOFT_EXPIRED.
	var created_at: int = _NOW - (30 * 86400 + 300 + 1)
	var result := LootTtlCalc.pending_ttl_expired(created_at, _NOW)
	assert_eq(result, LootEnums.ExpiryState.SOFT_EXPIRED,
		"Drop just past SOFT boundary + drift must be SOFT_EXPIRED")


func test_fresh_brand_new_drop_age_zero() -> void:
	# Arrange: just created.
	var result := LootTtlCalc.pending_ttl_expired(_NOW, _NOW)
	assert_eq(result, LootEnums.ExpiryState.FRESH,
		"Brand new drop (age=0) must be FRESH")


func test_fresh_drop_one_day_old() -> void:
	var created_at: int = _NOW - 86400  # 1 day
	var result := LootTtlCalc.pending_ttl_expired(created_at, _NOW)
	assert_eq(result, LootEnums.ExpiryState.FRESH,
		"1-day-old drop must be FRESH")


func test_soft_expired_31_days_old() -> void:
	# 31 days old: adjusted_age = 31*86400 - 300 = 2,677,500 > 2,592,000 → past soft.
	# raw_age = 31*86400 = 2,678,400 < 3,196,800 → SOFT_EXPIRED.
	var created_at: int = _NOW - (31 * 86400)
	var result := LootTtlCalc.pending_ttl_expired(created_at, _NOW)
	assert_eq(result, LootEnums.ExpiryState.SOFT_EXPIRED,
		"31-day-old drop must be SOFT_EXPIRED")


func test_drift_tolerance_constant_matches_adr_0003() -> void:
	# CI-3 invariant: DRIFT_TOLERANCE_S must equal 300 (ADR-0003 wall-clock drift budget).
	assert_eq(LootTtlCalc.DRIFT_TOLERANCE_S, 300,
		"DRIFT_TOLERANCE_S must be 300s (ADR-0003 CI-3 binding)")


func test_soft_ttl_days_matches_registry() -> void:
	# CI-2 invariant: SOFT_TTL_DAYS must equal lootdrop_pending_ttl_days = 30.
	assert_eq(LootTtlCalc.SOFT_TTL_DAYS, 30,
		"SOFT_TTL_DAYS must be 30 (registry lootdrop_pending_ttl_days CI-2)")

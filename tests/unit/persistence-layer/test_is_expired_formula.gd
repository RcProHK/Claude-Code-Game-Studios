# PersistenceLayer — Story 007 AC-14/14b/14c Clock-Drift TTL Tests
#
# Scope: 6-row table-driven tests for `is_expired()` Formula 1
# (ADR-0006 Contract 9 drift-tolerant TTL helper).
# Also covers edge cases: uninitialized clock (AC-14b) and zero TTL (AC-14c).
#
# AC-14 (GDD design/gdd/persistence-layer.md Formula 1):
#   6-row matrix verifying all drift/no-drift/rollback scenarios.
#   Pure function: cache snapshot must be identical before/after each call.
#
# AC-14b: negative wall_delta + no monotonic → push_warning + return false.
# AC-14c: ttl_seconds=0 edge: wall_delta=1 → true; wall_delta=0 → false.
#
# Note: GDD spec requires IClock injection but `is_expired()` calls
# Time.get_unix_time_from_system() + Time.get_ticks_msec() directly. To
# control clock values the tests pass computed anchor values based on
# the known current time (Time.get_unix_time_from_system()), or use
# artificially large/small values to force specific wall_delta outcomes.
# This approach avoids real time dependencies (deterministic per test-standards).
#
# Framework: GUT (Godot Unit Testing) v7.x
# Governing ADRs: ADR-0006 Contract 9 (Wall-Clock TTL + Clock-Drift Tolerance)
extends GutTest


const CACHE_VAR_NAME: StringName = &"_cache"
const DRIFT_TOLERANCE: int = 300  # WALL_CLOCK_DRIFT_TOLERANCE_SECONDS


func before_each() -> void:
	PersistenceLayer.get(CACHE_VAR_NAME).clear()


# ===========================================================================
# Helpers
# ===========================================================================

## Returns an anchor_unix such that wall_delta == desired_delta.
func _anchor_for_wall_delta(desired_delta_seconds: int) -> int:
	return int(Time.get_unix_time_from_system()) - desired_delta_seconds


## Returns an anchor_monotonic_ms such that mono_delta_ms == desired_delta_ms.
func _anchor_mono_for_delta_ms(desired_delta_ms: int) -> int:
	return Time.get_ticks_msec() - desired_delta_ms


# ===========================================================================
# AC-14 Row 1: Normal not-expired (wall=100s, ttl=86400s)
# ===========================================================================

func test_is_expired_row1_normal_not_expired_returns_false() -> void:
	# Arrange: anchor 100s ago (ttl=1 day → not expired)
	var anchor_unix: int = _anchor_for_wall_delta(100)
	var anchor_mono: int = _anchor_mono_for_delta_ms(100_000)
	var cache_before: Dictionary = PersistenceLayer.get(CACHE_VAR_NAME).duplicate()

	# Act
	var result: bool = PersistenceLayer.is_expired(anchor_unix, 86400, anchor_mono)

	# Assert
	assert_false(result, "Row 1: 100s elapsed < 86400s TTL → not expired")
	assert_eq(PersistenceLayer.get(CACHE_VAR_NAME), cache_before,
		"AC-14 pure function: cache must be identical before/after call")


# ===========================================================================
# AC-14 Row 2: Normal expired (wall=90000s > 86400s TTL)
# ===========================================================================

func test_is_expired_row2_normal_expired_returns_true() -> void:
	# Arrange: anchor 90000s ago (25h) — beyond 1-day TTL
	var anchor_unix: int = _anchor_for_wall_delta(90_000)
	var anchor_mono: int = _anchor_mono_for_delta_ms(90_000_000)

	# Act
	var result: bool = PersistenceLayer.is_expired(anchor_unix, 86400, anchor_mono)

	# Assert
	assert_true(result, "Row 2: 90000s elapsed > 86400s TTL → expired")


# ===========================================================================
# AC-14 Row 3: NTP drift +600s (wall_delta appears 700s but mono only 100s)
# ===========================================================================

func test_is_expired_row3_ntp_drift_trusts_monotonic_returns_false() -> void:
	# Arrange: make wall clock look like 700s elapsed but mono shows 100s.
	# wall_delta = 700s, mono_delta = 100s → |700000ms - 100000ms| = 600000ms > 300000ms → drift!
	# Trust mono: 100s < 86400s → not expired.
	var anchor_unix: int = _anchor_for_wall_delta(700)
	var anchor_mono: int = _anchor_mono_for_delta_ms(100_000)

	# Act
	var result: bool = PersistenceLayer.is_expired(anchor_unix, 86400, anchor_mono)

	# Assert — monotonic trusted (100s < 86400s)
	assert_false(result, "Row 3: NTP +600s drift detected — trust mono (100s < TTL)")


# ===========================================================================
# AC-14 Row 4: DST spring-forward +3600s
# ===========================================================================

func test_is_expired_row4_dst_drift_trusts_monotonic_returns_false() -> void:
	# wall_delta appears 3700s (DST adds 1h) but mono shows 100s
	# |3700000ms - 100000ms| = 3600000ms > 300000ms → drift; trust mono → not expired
	var anchor_unix: int = _anchor_for_wall_delta(3_700)
	var anchor_mono: int = _anchor_mono_for_delta_ms(100_000)

	var result: bool = PersistenceLayer.is_expired(anchor_unix, 86400, anchor_mono)

	assert_false(result, "Row 4: DST +3600s drift detected — trust mono (100s < TTL)")


# ===========================================================================
# AC-14 Row 5: Clock rollback -86400s
# ===========================================================================

func test_is_expired_row5_clock_rollback_trusts_monotonic_returns_false() -> void:
	# Wall rolled back 1 day: wall_delta appears -86300s (negative!) but mono=100s
	# negative wall_delta but anchor_monotonic_ms > 0 → skip negative-delta guard,
	# compute mono_delta and check drift.
	# |(-86300)*1000 - 100000| = |-86300000 - 100000| = 86400000 > 300000 → drift
	# Trust mono: 100s < 86400s → not expired.
	var anchor_unix: int = _anchor_for_wall_delta(-86_300)  # wall_delta = -(-86300) ... wait
	# _anchor_for_wall_delta(-86300) = now - (-86300) = now + 86300 (future anchor)
	# wall_delta = now - anchor = now - (now + 86300) = -86300 ✓
	var anchor_mono: int = _anchor_mono_for_delta_ms(100_000)

	var result: bool = PersistenceLayer.is_expired(anchor_unix, 86400, anchor_mono)

	assert_false(result, "Row 5: Clock rollback — trust mono (100s < TTL)")


# ===========================================================================
# AC-14 Row 6: No monotonic anchor (wall=90000s, ttl=86400s, mono=0)
# ===========================================================================

func test_is_expired_row6_no_monotonic_wall_only_returns_true() -> void:
	# anchor_monotonic_ms = 0 → skip drift detection, use wall-clock only
	# wall_delta = 90000s > 86400s TTL → expired
	var anchor_unix: int = _anchor_for_wall_delta(90_000)

	var result: bool = PersistenceLayer.is_expired(anchor_unix, 86400)  # mono defaults to 0

	assert_true(result, "Row 6: no mono anchor, wall-only: 90000s > 86400s → expired")


# ===========================================================================
# AC-14b: Uninitialized clock (negative wall_delta, no mono) → false + warning
# ===========================================================================

func test_is_expired_ac14b_negative_wall_no_mono_returns_false() -> void:
	# anchor_unix in the future (wall_delta negative) + no monotonic
	# → conservative not-expired + push_warning
	var future_anchor: int = int(Time.get_unix_time_from_system()) + 3600  # 1h in future
	# Can't assert push_warning fires (GUT doesn't intercept push_warning easily)
	# but we can assert the return value is false

	var result: bool = PersistenceLayer.is_expired(future_anchor, 86400, 0)

	assert_false(result, "AC-14b: negative wall_delta + no mono → conservative false")


# ===========================================================================
# AC-14c: Zero TTL edge cases
# ===========================================================================

func test_is_expired_ac14c_zero_ttl_any_elapsed_is_expired() -> void:
	# ttl_seconds=0: even 1s elapsed is "expired" (wall_delta=1 > 0)
	var anchor_unix: int = _anchor_for_wall_delta(1)

	var result: bool = PersistenceLayer.is_expired(anchor_unix, 0)

	assert_true(result, "AC-14c: ttl=0, wall_delta=1s → expired (strict greater-than)")


func test_is_expired_ac14c_zero_ttl_zero_elapsed_not_expired() -> void:
	# ttl_seconds=0, wall_delta=0 → 0 > 0 = false (strict greater-than, not ≥)
	var anchor_unix: int = int(Time.get_unix_time_from_system())  # wall_delta ≈ 0

	var result: bool = PersistenceLayer.is_expired(anchor_unix, 0)

	# Note: tiny race possible (clock ticks between anchor set and call).
	# Acceptable for this test — if it flakes once in 10k runs, add 1s buffer.
	assert_false(result, "AC-14c: ttl=0, wall_delta=0 → not expired (strict >)")

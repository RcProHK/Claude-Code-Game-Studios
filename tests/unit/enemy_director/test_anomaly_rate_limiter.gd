# EnemyDirector — Story 007 AC-09a/b/c: Anomaly Rate-Limiter (Formula 4)
#
# Coverage:
#   AC-09a — Main path: 100 same-reason calls at same ms → 10 pass, 90 drop;
#            walk_anomaly_rate_windows(1001) → aggregate combat_metric_anomaly emitted.
#   AC-09b — Per-reason isolation: 6 reasons × 100 calls → each independently caps at 10.
#   AC-09c — Sliding-window eviction boundary: half-open window ts <= now - RATE_WINDOW_MS.
#
# Time is injected via the now_ms parameter — no Time.get_ticks_msec() inside
# rate_limit_check (ADR-0006 deterministic-time requirement).
extends GutTest


func before_each() -> void:
	await get_tree().process_frame
	# Reset anomaly rate tracker to clean state between tests.
	EnemyDirector.get(&"_anomaly_rate_tracker").clear()


func after_each() -> void:
	await get_tree().process_frame
	EnemyDirector.get(&"_anomaly_rate_tracker").clear()


# ---------------------------------------------------------------------------
# AC-09a — main path: cap + drop + aggregate emit
# ---------------------------------------------------------------------------

## First 10 calls must return true; calls 11-100 must return false.
func test_ac09a_first_10_pass_next_90_drop() -> void:
	# Arrange + Act
	var pass_count: int = 0
	var drop_count: int = 0
	for i in 100:
		var result: bool = EnemyDirector.rate_limit_check(&"GSM_SUSPENDED", 0)
		if result:
			pass_count += 1
		else:
			drop_count += 1
	# Assert
	assert_eq(pass_count, 10,
		"AC-09a: first 10 calls must return true (within RATE_CAP_PER_REASON=10)")
	assert_eq(drop_count, 90,
		"AC-09a: next 90 calls must return false (rate limited)")


## dropped counter must accumulate to 90 after 100 calls.
func test_ac09a_dropped_count_is_90() -> void:
	for i in 100:
		EnemyDirector.rate_limit_check(&"GSM_SUSPENDED", 0)
	var tracker: Dictionary = EnemyDirector.get(&"_anomaly_rate_tracker")
	assert_true(tracker.has(&"GSM_SUSPENDED"),
		"AC-09a: tracker must have GSM_SUSPENDED entry after calls")
	var window = tracker[&"GSM_SUSPENDED"]
	assert_eq(window.dropped, 90,
		"AC-09a: dropped count must be 90 after 100 calls (10 accepted, 90 dropped)")


## walk(1001) must emit exactly one aggregate combat_metric_anomaly.
func test_ac09a_walk_emits_aggregate_with_correct_payload() -> void:
	# Arrange — 100 calls at now_ms=0.
	for i in 100:
		EnemyDirector.rate_limit_check(&"GSM_SUSPENDED", 0)
	watch_signals(EnemyDirector)
	# Act — advance time past RATE_WINDOW_MS=1000 so all ts=0 entries expire.
	EnemyDirector.walk_anomaly_rate_windows(1001)
	# Assert — exactly one emit.
	assert_signal_emitted(EnemyDirector, "combat_metric_anomaly",
		"AC-09a: walk must emit combat_metric_anomaly after window expires with drops")
	var params: Array = get_signal_parameters(EnemyDirector, "combat_metric_anomaly")
	assert_eq(params.size(), 1, "AC-09a: signal must carry one payload argument")
	var payload = params[0]
	assert_not_null(payload, "AC-09a: payload must not be null")
	assert_eq(payload.reason, &"GSM_SUSPENDED", "AC-09a: payload.reason must match")
	assert_eq(payload.aggregate, true, "AC-09a: payload.aggregate must be true")
	assert_eq(payload.dropped_count, 90, "AC-09a: payload.dropped_count must be 90")


## After aggregate emit, dropped counter must be reset to 0.
func test_ac09a_dropped_reset_after_aggregate_emit() -> void:
	for i in 100:
		EnemyDirector.rate_limit_check(&"GSM_SUSPENDED", 0)
	EnemyDirector.walk_anomaly_rate_windows(1001)
	var window = EnemyDirector.get(&"_anomaly_rate_tracker")[&"GSM_SUSPENDED"]
	assert_eq(window.dropped, 0,
		"AC-09a: dropped_count must be reset to 0 after aggregate emit")


# ---------------------------------------------------------------------------
# AC-09b — per-reason isolation: 6 independent caps
# ---------------------------------------------------------------------------

## 6 different reasons must each allow exactly 10 passes independently.
func test_ac09b_six_reasons_each_cap_independently() -> void:
	# Arrange — 6 reasons from the locked set (GDD Rule 6).
	var reasons: Array[StringName] = [
		&"GSM_SUSPENDED", &"INVALID_ABILITY_ID", &"NEGATIVE_DAMAGE",
		&"CLAMP_TRIGGERED", &"DEAD_TARGET_RESOLVE", &"RNG_INJECTION_MISSING",
	]
	# Act — 100 calls per reason.
	var pass_counts: Array[int] = []
	for reason: StringName in reasons:
		var passes: int = 0
		for i in 100:
			if EnemyDirector.rate_limit_check(reason, 0):
				passes += 1
		pass_counts.append(passes)
	# Assert — each reason allows exactly 10.
	for i in reasons.size():
		assert_eq(pass_counts[i], 10,
			"AC-09b: reason '%s' must allow exactly 10 passes (independent cap)" % reasons[i])


## Passes for reason A must not reduce the cap for reason B.
func test_ac09b_caps_are_not_shared_globally() -> void:
	# Fill reason A to cap.
	for i in 10:
		EnemyDirector.rate_limit_check(&"GSM_SUSPENDED", 0)
	# Reason B's first call must still pass (cap not shared).
	var result: bool = EnemyDirector.rate_limit_check(&"INVALID_ABILITY_ID", 0)
	assert_true(result,
		"AC-09b: reason B must still accept calls after reason A reached its cap")


# ---------------------------------------------------------------------------
# AC-09c — sliding-window boundary (half-open eviction)
# ---------------------------------------------------------------------------

## ts=0 at walk(999): NOT evicted (999-1000 = -1; ts=0 > -1 → still in window).
func test_ac09c_walk_999_does_not_evict_ts0() -> void:
	# Fill cap at ts=0.
	for i in 10:
		EnemyDirector.rate_limit_check(&"GSM_SUSPENDED", 0)
	# Try 10 more calls at ts=999 — should all drop (cap still full).
	var passes_at_999: int = 0
	for i in 10:
		if EnemyDirector.rate_limit_check(&"GSM_SUSPENDED", 999):
			passes_at_999 += 1
	assert_eq(passes_at_999, 0,
		"AC-09c: calls at ts=999 must be dropped (ts=0 not evicted; cap still full)")


## ts=0 at walk(1000): IS evicted (ts <= 1000-1000 = 0 → boundary is expired).
func test_ac09c_walk_1000_evicts_ts0() -> void:
	# Fill cap at ts=0.
	for i in 10:
		EnemyDirector.rate_limit_check(&"GSM_SUSPENDED", 0)
	watch_signals(EnemyDirector)
	# Walk at exactly 1000ms — ts=0 entries are at boundary, must be evicted.
	EnemyDirector.walk_anomaly_rate_windows(1000)
	# Window empty after eviction → no drops in this test → no aggregate yet.
	# Key check: window.timestamps is empty after walk(1000).
	var window = EnemyDirector.get(&"_anomaly_rate_tracker")[&"GSM_SUSPENDED"]
	assert_true(window.timestamps.is_empty(),
		"AC-09c: walk(1000) must evict ts=0 entries (half-open boundary: ts<=0 is expired)")


## After walk(1000) evicts ts=0, new calls at ts=1000 should pass (fresh window).
func test_ac09c_new_calls_pass_after_eviction() -> void:
	# Arrange — fill cap at ts=0.
	for i in 10:
		EnemyDirector.rate_limit_check(&"GSM_SUSPENDED", 0)
	# Evict ts=0 entries.
	EnemyDirector.walk_anomaly_rate_windows(1000)
	# Act — 10 new calls at ts=1000 should pass.
	var passes: int = 0
	for i in 10:
		if EnemyDirector.rate_limit_check(&"GSM_SUSPENDED", 1000):
			passes += 1
	# Assert — up to 10 new passes (window is fresh after eviction).
	assert_eq(passes, 10,
		"AC-09c: 10 new calls at ts=1000 must pass after ts=0 entries evicted")


## Aggregate emit for drops accumulated before window rolled.
func test_ac09c_drops_at_999_trigger_aggregate_on_next_eviction() -> void:
	# 10 calls at ts=0 (cap full).
	for i in 10:
		EnemyDirector.rate_limit_check(&"GSM_SUSPENDED", 0)
	# 10 more at ts=999 (all drop — cap still full, ts=0 not evicted yet).
	for i in 10:
		EnemyDirector.rate_limit_check(&"GSM_SUSPENDED", 999)
	# walk(1000): evicts ts=0 entries, window empty, dropped=10 → aggregate.
	watch_signals(EnemyDirector)
	EnemyDirector.walk_anomaly_rate_windows(1000)
	var params: Array = get_signal_parameters(EnemyDirector, "combat_metric_anomaly")
	assert_eq(params.size(), 1, "AC-09c: aggregate must be emitted after eviction with drops")
	var payload = params[0]
	assert_eq(payload.aggregate, true, "AC-09c: payload must be aggregate")
	assert_eq(payload.dropped_count, 10,
		"AC-09c: dropped_count must be 10 (drops at ts=999 before eviction)")

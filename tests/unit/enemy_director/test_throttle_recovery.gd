# EnemyDirector — Story 015 AC-24: particle throttle RELEASE + hysteresis (EC-30, INV-4).
extends GutTest


func before_each() -> void:
	await get_tree().process_frame
	EnemyDirector.set_physics_process(false)
	EnemyDirector.get(&"_frame_time_window").clear()
	EnemyDirector.get(&"_recovery_window").clear()
	EnemyDirector.get(&"_anomaly_rate_tracker").clear()
	EnemyDirector.set(&"_throttle_active", false)
	EnemyDirector.set(&"_caller_mult", EnemyDirector.CALLER_MULT_NORMAL)


func after_each() -> void:
	await get_tree().process_frame
	EnemyDirector.get(&"_frame_time_window").clear()
	EnemyDirector.get(&"_recovery_window").clear()
	EnemyDirector.set(&"_throttle_active", false)
	EnemyDirector.set(&"_caller_mult", EnemyDirector.CALLER_MULT_NORMAL)
	EnemyDirector.set_physics_process(true)


func _record(value: float, times: int) -> void:
	for _i in times:
		EnemyDirector.call("_record_frame_time", value)


func _engage() -> void:
	_record(35.0, 3)  # 3 over-budget → throttle engaged
	assert_true(EnemyDirector.call("_is_throttle_active"), "precondition: throttle engaged")


# ---------------------------------------------------------------------------
# AC-24 — release after sustained recovery
# ---------------------------------------------------------------------------

func test_ac24_sixty_under_recovery_releases_throttle() -> void:
	_engage()
	watch_signals(EnemyDirector)
	_record(18.0, EnemyDirector.RECOVERY_SAMPLE_SIZE)  # 60 frames < 20ms
	assert_false(EnemyDirector.call("_is_throttle_active"), "AC-24: 60 frames <20ms → released")
	assert_almost_eq(EnemyDirector.call("get_caller_mult"), 1.5, 0.001, "AC-24: caller_mult restored to 1.5")
	assert_signal_emitted(EnemyDirector, "combat_metric_anomaly", "AC-24: anomaly emitted")
	var payload = get_signal_parameters(EnemyDirector, "combat_metric_anomaly")[0]
	assert_eq(payload.reason, &"PARTICLE_THROTTLE_RELEASED", "AC-24: reason PARTICLE_THROTTLE_RELEASED")


## Fewer than the full recovery window does not release.
func test_ac24_partial_recovery_does_not_release() -> void:
	_engage()
	_record(18.0, EnemyDirector.RECOVERY_SAMPLE_SIZE - 1)  # 59 frames
	assert_true(EnemyDirector.call("_is_throttle_active"),
		"AC-24: 59 frames (< full window) → still throttled")


# ---------------------------------------------------------------------------
# Hysteresis (INV-4) — one spike resets the release requirement
# ---------------------------------------------------------------------------

func test_inv4_one_spike_prevents_release_then_clean_window_releases() -> void:
	_engage()
	# 59 good frames + 1 spike at 21ms (≥ recovery threshold) → window not all-below.
	_record(18.0, 59)
	_record(21.0, 1)
	assert_true(EnemyDirector.call("_is_throttle_active"),
		"INV-4: a single ≥20ms spike keeps the throttle engaged")
	# 60 more clean frames evict the spike → release.
	_record(18.0, EnemyDirector.RECOVERY_SAMPLE_SIZE)
	assert_false(EnemyDirector.call("_is_throttle_active"),
		"INV-4: 60 clean frames after the spike → released")


## INV-4 static: engage threshold exceeds recovery threshold by > the min hysteresis gap.
func test_inv4_hysteresis_gap_constant() -> void:
	var gap: float = EnemyDirector.FRAME_TIME_BUDGET_MS - EnemyDirector.FRAME_TIME_RECOVERY_MS
	assert_gt(gap, EnemyDirector.THROTTLE_HYSTERESIS_MIN_MS,
		"INV-4: hysteresis gap (13.0) > min (5.0) — anti-thrash")

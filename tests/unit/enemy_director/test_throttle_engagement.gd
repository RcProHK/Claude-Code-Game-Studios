# EnemyDirector — Story 015 AC-23: particle throttle ENGAGE (EC-29).
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


func _record(values: Array) -> void:
	for v in values:
		EnemyDirector.call("_record_frame_time", float(v))


# ---------------------------------------------------------------------------
# AC-23 — engage
# ---------------------------------------------------------------------------

func test_ac23_three_over_budget_engages_throttle() -> void:
	watch_signals(EnemyDirector)
	_record([35.0, 36.0, 34.0])  # all > 33
	assert_true(EnemyDirector.call("_is_throttle_active"), "AC-23: 3 consecutive >33ms → throttle active")
	assert_almost_eq(EnemyDirector.call("get_caller_mult"), 1.0, 0.001, "AC-23: caller_mult drops to 1.0")
	assert_signal_emitted(EnemyDirector, "combat_metric_anomaly", "AC-23: anomaly emitted")
	var payload = get_signal_parameters(EnemyDirector, "combat_metric_anomaly")[0]
	assert_eq(payload.reason, &"PARTICLE_THROTTLE_ENGAGED", "AC-23: reason PARTICLE_THROTTLE_ENGAGED")


func test_ac23_fewer_than_three_does_not_engage() -> void:
	_record([35.0, 36.0])  # only 2 samples
	assert_false(EnemyDirector.call("_is_throttle_active"), "AC-23: window not full → no engage")
	assert_almost_eq(EnemyDirector.call("get_caller_mult"), 1.5, 0.001, "AC-23: caller_mult stays normal")


func test_ac23_one_under_budget_breaks_engage() -> void:
	_record([35.0, 20.0, 36.0])  # middle sample below budget
	assert_false(EnemyDirector.call("_is_throttle_active"),
		"AC-23: not ALL 3 above budget → no engage")


func test_ac23_rolling_window_engages_once_filled() -> void:
	_record([10.0, 35.0, 36.0])  # first below, not yet all-above
	assert_false(EnemyDirector.call("_is_throttle_active"), "not engaged with a low sample in window")
	_record([34.0])  # window now [35,36,34] — all above
	assert_true(EnemyDirector.call("_is_throttle_active"), "AC-23: engages once the rolling window is all-above")


## Already engaged → no duplicate engage anomaly on further over-budget frames.
func test_ac23_no_duplicate_engage_anomaly() -> void:
	_record([35.0, 36.0, 34.0])  # engage (1 anomaly)
	watch_signals(EnemyDirector)
	_record([40.0, 41.0, 42.0])  # still over budget, already throttled
	assert_eq(get_signal_emit_count(EnemyDirector, "combat_metric_anomaly"), 0,
		"AC-23: no duplicate ENGAGED anomaly while already throttled")

# GameStateMachine — Story 012 Rule 5.5 Weekly Tick Replay
extends GutTest


func before_each() -> void:
	PersistenceLayer.get(&"_cache").erase("gsm._last_weekly_tick_unix")


## AC-gsm-weekly-1: 3 weeks since last tick → missed=3
func test_weekly_tick_3_weeks_returns_3() -> void:
	# Arrange — 3 weeks ago
	var three_weeks_ago: int = int(Time.get_unix_time_from_system()) - (3 * 7 * 86400 + 100)
	PersistenceLayer.write("gsm._last_weekly_tick_unix", three_weeks_ago)

	# Act
	var missed: int = GameStateMachine._run_rule5_5_weekly_tick_replay()

	# Assert
	assert_eq(missed, 3, "AC-weekly-1: 3 weeks elapsed → 3 missed ticks")


## AC-gsm-weekly-2: 20 weeks → clamped to MAX_WEEKLY_TICK_CATCHUP=8 + signal.
func test_weekly_tick_20_weeks_clamped_with_signal() -> void:
	# Arrange — 20 weeks ago
	var twenty_weeks_ago: int = int(Time.get_unix_time_from_system()) - (20 * 7 * 86400)
	PersistenceLayer.write("gsm._last_weekly_tick_unix", twenty_weeks_ago)
	watch_signals(GameStateMachine)

	# Act
	var missed: int = GameStateMachine._run_rule5_5_weekly_tick_replay()

	# Assert
	assert_eq(missed, GameStateMachine.MAX_WEEKLY_TICK_CATCHUP,
		"AC-weekly-2: 20 weeks must be clamped to MAX=8")
	assert_signal_emit_count(GameStateMachine, "weekly_tick_catchup_capped", 1,
		"AC-weekly-2: clamp event must emit weekly_tick_catchup_capped signal")


## AC-gsm-weekly-3: <1 week → missed=0, no signal.
func test_weekly_tick_yesterday_returns_zero() -> void:
	# Arrange — yesterday
	var yesterday: int = int(Time.get_unix_time_from_system()) - 86400
	PersistenceLayer.write("gsm._last_weekly_tick_unix", yesterday)

	# Act
	var missed: int = GameStateMachine._run_rule5_5_weekly_tick_replay()

	# Assert
	assert_eq(missed, 0, "AC-weekly-3: <1 week elapsed → 0 missed ticks")

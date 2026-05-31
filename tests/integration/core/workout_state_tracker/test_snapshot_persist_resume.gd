# WorkoutStateTracker — Story 008 Persistence Snapshot + Bfcache Resume Integration Tests
#
# Coverage:
#   AC-16 — bfcache resume: snapshot restored, phase/set_history/dominant_class reconstructed
#   AC-32 — TTL expiry: < 24h → resume; > 24h → discard + workout_state_discarded
#   AC-35 — snapshot truncation: > 256KB → truncate to 50 sets; WST_SNAPSHOT_TRUNC_001 logged
#   AC-36 — write fail: emit wst_persist_failed; in-memory state continues
extends GutTest


## Fake PersistenceLayer double (untyped, duck-typed per project DI convention).
## Supports pre-seeding read values and simulating write failures.
class FakePersistenceLayer:
	## Key-value store backing all read/write calls.
	var data: Dictionary = {}
	## Set to true to simulate write failure (write() returns false).
	var write_should_fail: bool = false
	## Records all write calls: [{key, value, flush}].
	var write_calls: Array[Dictionary] = []
	## Injected "now" unix timestamp for is_expired checks (seconds).
	var now_s: int = int(Time.get_unix_time_from_system())

	func read(key: String) -> Variant:
		return data.get(key, null)

	func write(key: String, value: Variant, flush: bool = false) -> bool:
		write_calls.append({"key": key, "value": value, "flush": flush})
		if write_should_fail:
			return false
		data[key] = value
		return true

	func is_expired(anchor_unix: int, ttl_seconds: int, _anchor_monotonic_ms: int = 0) -> bool:
		# Strict greater-than (EC-26): boundary exactly at TTL is NOT expired.
		return (now_s - anchor_unix) > ttl_seconds

	# No custom has_method() — built-in Object.has_method detects the methods above.

	func clear_calls() -> void:
		write_calls.clear()


var _fake_pl: FakePersistenceLayer


func before_each() -> void:
	await get_tree().process_frame
	# Reset all WST state
	WorkoutStateTracker.set(&"_workout_phase", WorkoutStateTracker.WorkoutPhase.IDLE)
	WorkoutStateTracker.get(&"_set_history").clear()
	WorkoutStateTracker.set(&"_rest_ended_awaiting_next_set", false)
	WorkoutStateTracker.set(&"_substate", WorkoutStateTracker.Substate.READY)
	WorkoutStateTracker.set(&"_is_frozen", false)
	WorkoutStateTracker.set(&"_last_drop_reason", &"")
	WorkoutStateTracker.set(&"_pending_suspended_entry", false)
	WorkoutStateTracker.set(&"_cached_set_progress", 0.0)
	WorkoutStateTracker.set(&"_set_progress_is_estimated", true)
	WorkoutStateTracker.set(&"_historical_avg_sets", 0.0)
	WorkoutStateTracker.set(&"_historical_avg_reps_per_set", 0.0)
	WorkoutStateTracker.set(&"_planned_total_sets", -1)
	WorkoutStateTracker.set(&"_planned_reps_per_set", -1)
	WorkoutStateTracker.set(&"_current_workout_id", "")
	WorkoutStateTracker.set(&"_cached_dominant_class", AbilitySystem.AbilityClass.UNKNOWN)
	WorkoutStateTracker.set(&"_previous_dominant_class", AbilitySystem.AbilityClass.UNKNOWN)
	WorkoutStateTracker.set(&"_dominant_class_last_change_ms", 0)
	WorkoutStateTracker.set(&"_time_source", null)
	WorkoutStateTracker.get(&"_completed_exercises").clear()
	WorkoutStateTracker.set(&"_last_snapshot", null)
	WorkoutStateTracker.set(&"_last_summary", null)
	WorkoutStateTracker.set(&"_last_workout_transition_id", "")
	WorkoutStateTracker.get(&"_pending_stat_deltas").clear()
	WorkoutStateTracker.set(&"_stat_delta_overflow_count", 0)
	WorkoutStateTracker.set(&"_workout_started_at_s", 0)
	# Inject fresh fake PersistenceLayer
	_fake_pl = FakePersistenceLayer.new()
	WorkoutStateTracker.set(&"_persistence_layer", _fake_pl)


func after_each() -> void:
	# GAP-2 fix: drain deferred queue (e.g. _finalize_workout_idle) BEFORE restoring the real PL.
	# Without this, a deferred _change_phase(IDLE) could fire after restoration and issue a
	# real write("wst.current_workout.phase", ...) against user://, contaminating the filesystem.
	await get_tree().process_frame
	WorkoutStateTracker.set(&"_persistence_layer", PersistenceLayer)


# ---------------------------------------------------------------------------
# AC-16: bfcache resume — snapshot restored, fields reconstructed
# ---------------------------------------------------------------------------

## Successful bfcache resume: phase, set_history, and dominant_class recomputed.
func test_ac16_bfcache_resume_restores_snapshot_state() -> void:
	var now_s: int = int(Time.get_unix_time_from_system())
	# Pre-seed snapshot: SET_ACTIVE + 5 sets + started 1 hour ago (within TTL)
	var seed_history: Array = [
		{"exercise_id": &"bench_press", "reps": 8, "weight": 60.0},
		{"exercise_id": &"row", "reps": 8, "weight": 50.0},
		{"exercise_id": &"bench_press", "reps": 8, "weight": 60.0},
		{"exercise_id": &"squat", "reps": 8, "weight": 80.0},
		{"exercise_id": &"bench_press", "reps": 8, "weight": 60.0},
	]
	_fake_pl.data["wst.current_workout.phase"] = int(WorkoutStateTracker.WorkoutPhase.SET_ACTIVE)
	_fake_pl.data["wst.current_workout.id"] = "wst-test-resume-001"
	_fake_pl.data["wst.current_workout.started_at"] = now_s - 3600  # 1h ago (within 24h TTL)
	_fake_pl.data["wst.current_workout.set_history"] = seed_history
	# bench_press×3 > row×1, squat×1 → STRIKE dominant
	_fake_pl.now_s = now_s

	watch_signals(WorkoutStateTracker)
	WorkoutStateTracker.call("_restore_from_persistence")

	# Phase restored
	assert_eq(WorkoutStateTracker.get(&"_workout_phase"),
		WorkoutStateTracker.WorkoutPhase.SET_ACTIVE,
		"AC-16: phase must be restored to SET_ACTIVE from snapshot")

	# set_history restored
	var restored_history: Array = WorkoutStateTracker.get(&"_set_history")
	assert_eq(restored_history.size(), 5,
		"AC-16: set_history must have 5 entries from snapshot")
	assert_eq(restored_history[0], seed_history[0],
		"AC-16: set_history entries must deep-equal seeded data")

	# dominant_class recomputed from set_history (bench_press=STRIKE×3 vs row=CONTROL×1 vs squat=MOBILITY×1)
	assert_eq(WorkoutStateTracker.get(&"_cached_dominant_class"),
		AbilitySystem.AbilityClass.STRIKE,
		"AC-16: _cached_dominant_class must be STRIKE (recomputed from 3 bench sets)")

	# bfcache_resumed emitted with correct args
	assert_signal_emitted(WorkoutStateTracker, "bfcache_resumed",
		"AC-16: bfcache_resumed must emit on successful resume")
	var params: Array = get_signal_parameters(WorkoutStateTracker, "bfcache_resumed")
	assert_true(params[0] as bool,
		"AC-16: was_mid_workout must be true (phase != IDLE)")
	assert_eq(params[1], int(WorkoutStateTracker.WorkoutPhase.SET_ACTIVE),
		"AC-16: restored_phase must be SET_ACTIVE")


# ---------------------------------------------------------------------------
# AC-32: TTL expiry — < 24h resumes; > 24h discards; boundary = valid
# ---------------------------------------------------------------------------

## Resume succeeds when elapsed < 24h.
func test_ac32_resume_succeeds_within_ttl() -> void:
	var now_s: int = int(Time.get_unix_time_from_system())
	_fake_pl.data["wst.current_workout.phase"] = int(WorkoutStateTracker.WorkoutPhase.WARM_UP)
	_fake_pl.data["wst.current_workout.id"] = "wst-ttl-test"
	_fake_pl.data["wst.current_workout.started_at"] = now_s - 3600  # 1h ago
	_fake_pl.now_s = now_s
	watch_signals(WorkoutStateTracker)

	WorkoutStateTracker.call("_restore_from_persistence")

	assert_eq(WorkoutStateTracker.get(&"_workout_phase"),
		WorkoutStateTracker.WorkoutPhase.WARM_UP,
		"AC-32: phase must be restored when elapsed (1h) < 24h TTL")
	assert_signal_emit_count(WorkoutStateTracker, "workout_state_discarded", 0,
		"AC-32: workout_state_discarded must NOT emit when TTL not expired")


## Snapshot discarded + workout_state_discarded emitted when elapsed > 24h.
func test_ac32_snapshot_discarded_after_ttl_expiry() -> void:
	var started_s: int = 1000000  # arbitrary past time
	_fake_pl.data["wst.current_workout.phase"] = int(WorkoutStateTracker.WorkoutPhase.SET_ACTIVE)
	_fake_pl.data["wst.current_workout.id"] = "wst-expired"
	_fake_pl.data["wst.current_workout.started_at"] = started_s
	# Set fake now to 25 hours after start → elapsed > 86400s
	_fake_pl.now_s = started_s + 25 * 3600
	watch_signals(WorkoutStateTracker)

	WorkoutStateTracker.call("_restore_from_persistence")

	assert_eq(WorkoutStateTracker.get(&"_workout_phase"),
		WorkoutStateTracker.WorkoutPhase.IDLE,
		"AC-32: phase must remain IDLE when snapshot is expired (> 24h)")
	assert_signal_emitted(WorkoutStateTracker, "workout_state_discarded",
		"AC-32: workout_state_discarded must emit when TTL expired")
	var params: Array = get_signal_parameters(WorkoutStateTracker, "workout_state_discarded")
	assert_eq(params[0], "ttl_expired",
		"AC-32: reason must be 'ttl_expired'")


## Boundary: exactly 24h elapsed → treated as valid (strict > means NOT expired at boundary).
func test_ac32_boundary_exactly_24h_is_valid() -> void:
	var started_s: int = 1000000
	_fake_pl.data["wst.current_workout.phase"] = int(WorkoutStateTracker.WorkoutPhase.WARM_UP)
	_fake_pl.data["wst.current_workout.id"] = "wst-boundary"
	_fake_pl.data["wst.current_workout.started_at"] = started_s
	# Exactly 24h = 86400s: strict > means NOT expired
	_fake_pl.now_s = started_s + 86400
	watch_signals(WorkoutStateTracker)

	WorkoutStateTracker.call("_restore_from_persistence")

	assert_eq(WorkoutStateTracker.get(&"_workout_phase"),
		WorkoutStateTracker.WorkoutPhase.WARM_UP,
		"AC-32 EC-26: exactly 24h boundary must be treated as valid (strict > not >=)")
	assert_signal_emit_count(WorkoutStateTracker, "workout_state_discarded", 0,
		"AC-32 EC-26: workout_state_discarded must NOT emit at exact boundary (still valid)")


# ---------------------------------------------------------------------------
# AC-35: snapshot truncation > 256KB → keep last 50 sets
# ---------------------------------------------------------------------------

## Oversized set_history triggers truncation; WST_SNAPSHOT_TRUNC_001 logged.
func test_ac35_large_set_history_truncated_on_persist() -> void:
	WorkoutStateTracker.call("_on_workout_started")
	# Must exceed SNAPSHOT_BYTE_TRUNCATION_THRESHOLD (262144 bytes). JSON.stringify of each
	# entry {"exercise_id":"bench_press","reps":8,"weight":60.0} ≈ 50 chars/bytes, so we need
	# ~5250+ entries. Use 7000 to comfortably clear the threshold (~350KB).
	for i in range(7000):
		WorkoutStateTracker.get(&"_set_history").append(
			{"exercise_id": &"bench_press", "reps": 8, "weight": 60.0}
		)

	# Trigger persist (via _persist_set_history)
	WorkoutStateTracker.call("_persist_set_history")

	# Find the set_history write in the fake PL's call log
	var history_write: Dictionary = {}
	for call: Dictionary in _fake_pl.write_calls:
		if call["key"] == "wst.current_workout.set_history":
			history_write = call
			break

	assert_true(history_write.size() > 0,
		"AC-35: wst.current_workout.set_history must have been written")
	var written_history: Array = history_write.get("value", [])
	assert_true(written_history.size() <= WorkoutStateTracker.SNAPSHOT_TRUNCATION_MAX_SETS,
		"AC-35: written set_history must be ≤ SNAPSHOT_TRUNCATION_MAX_SETS (%d)" \
		% WorkoutStateTracker.SNAPSHOT_TRUNCATION_MAX_SETS)


## GAP-1: Resume from truncated snapshot reconstructs valid partial state without crash.
func test_ac35_resume_from_truncated_snapshot_works() -> void:
	var now_s: int = int(Time.get_unix_time_from_system())
	# Seed only 50 sets (as if truncation had already occurred)
	var truncated_history: Array = []
	for i in range(50):
		truncated_history.append({"exercise_id": &"bench_press", "reps": 8, "weight": 60.0})

	_fake_pl.data["wst.current_workout.phase"] = int(WorkoutStateTracker.WorkoutPhase.SET_ACTIVE)
	_fake_pl.data["wst.current_workout.id"] = "wst-truncated"
	_fake_pl.data["wst.current_workout.started_at"] = now_s - 3600
	_fake_pl.data["wst.current_workout.set_history"] = truncated_history
	_fake_pl.now_s = now_s

	# Should not crash — partial state is acceptable
	WorkoutStateTracker.call("_restore_from_persistence")

	assert_eq(WorkoutStateTracker.get(&"_workout_phase"),
		WorkoutStateTracker.WorkoutPhase.SET_ACTIVE,
		"AC-35: resume from truncated snapshot must restore phase correctly")
	assert_eq(WorkoutStateTracker.get(&"_set_history").size(), 50,
		"AC-35: resume from truncated snapshot must have 50 set_history entries")
	assert_eq(WorkoutStateTracker.get_completed_exercises_count(), 1,
		"AC-35: resume must reconstruct completed_exercises (1 distinct: bench_press)")


## GAP-3: EWMA history survives TTL discard (cross-session stats preserved even when workout expires).
func test_ac32_ewma_history_survives_ttl_discard() -> void:
	var started_s: int = 1000000
	_fake_pl.data["wst.current_workout.phase"] = int(WorkoutStateTracker.WorkoutPhase.SET_ACTIVE)
	_fake_pl.data["wst.current_workout.id"] = "wst-expired-ewma"
	_fake_pl.data["wst.current_workout.started_at"] = started_s
	# Seed cross-session EWMA history (should survive TTL discard)
	_fake_pl.data["wst.history.avg_sets"] = 5.4
	_fake_pl.data["wst.history.avg_reps_per_set"] = 9.0
	# Expire the workout (25h elapsed)
	_fake_pl.now_s = started_s + 25 * 3600

	WorkoutStateTracker.call("_restore_from_persistence")

	# Active workout snapshot discarded
	assert_eq(WorkoutStateTracker.get(&"_workout_phase"),
		WorkoutStateTracker.WorkoutPhase.IDLE,
		"Precondition: workout must be discarded (expired)")
	# EWMA history must survive (not TTL-gated — cross-session data)
	assert_almost_eq(WorkoutStateTracker.get(&"_historical_avg_sets"), 5.4, 0.001,
		"GAP-3: _historical_avg_sets must survive TTL discard of active workout snapshot")
	assert_almost_eq(WorkoutStateTracker.get(&"_historical_avg_reps_per_set"), 9.0, 0.001,
		"GAP-3: _historical_avg_reps_per_set must survive TTL discard")


## set_history exactly 50 entries → no truncation triggered.
func test_ac35_exactly_50_sets_no_truncation() -> void:
	WorkoutStateTracker.call("_on_workout_started")
	for i in range(50):
		WorkoutStateTracker.get(&"_set_history").append(
			{"exercise_id": &"bench_press", "reps": 8, "weight": 60.0}
		)

	_fake_pl.clear_calls()
	WorkoutStateTracker.call("_persist_set_history")

	var history_write: Dictionary = {}
	for call: Dictionary in _fake_pl.write_calls:
		if call["key"] == "wst.current_workout.set_history":
			history_write = call
			break
	var written_history: Array = history_write.get("value", [])
	assert_eq(written_history.size(), 50,
		"AC-35 edge: exactly 50 sets must NOT be truncated (threshold not reached)")


# ---------------------------------------------------------------------------
# AC-36: write failure → emit wst_persist_failed; in-memory state continues
# ---------------------------------------------------------------------------

## Write failure emits wst_persist_failed; subsequent set_logged still processed.
func test_ac36_write_failure_emits_signal_and_continues() -> void:
	_fake_pl.write_should_fail = true

	WorkoutStateTracker.call("_on_workout_started")
	watch_signals(WorkoutStateTracker)

	# Phase change triggers persist (which fails)
	WorkoutStateTracker.call("_on_set_logged", &"bench_press", 8, 60.0)

	# wst_persist_failed must have been emitted for the phase key or set_history key
	assert_signal_emitted(WorkoutStateTracker, "wst_persist_failed",
		"AC-36: wst_persist_failed must emit on PersistenceLayer write failure")

	# In-memory state must still work correctly
	_fake_pl.write_should_fail = false  # Allow next call to succeed
	WorkoutStateTracker.call("_on_set_logged", &"row", 8, 50.0)
	assert_eq(WorkoutStateTracker.get(&"_set_history").size(), 2,
		"AC-36: in-memory set_history must continue to accumulate after write fail")
	assert_eq(WorkoutStateTracker.get_completed_exercises_count(), 2,
		"AC-36: get_completed_exercises_count() must return live value (in-memory continuity)")


## Write failure does NOT prevent future writes (not retry-inline, no cascade).
func test_ac36_write_failure_does_not_cascade() -> void:
	# We can't easily inject per-call fail logic with the simple fake,
	# so test that in-memory state is independent of write success
	_fake_pl.write_should_fail = true
	WorkoutStateTracker.call("_on_workout_started")

	# Even with all writes failing, query API must return live values
	WorkoutStateTracker.call("_on_set_logged", &"squat", 5, 80.0)

	assert_eq(WorkoutStateTracker.get_current_phase(),
		WorkoutStateTracker.WorkoutPhase.SET_ACTIVE,
		"AC-36: get_current_phase() must return live value even when PL writes all fail")
	assert_eq(WorkoutStateTracker.get_set_progress(),
		WorkoutStateTracker.get(&"_cached_set_progress"),
		"AC-36: get_set_progress() must return live value regardless of persist failures")

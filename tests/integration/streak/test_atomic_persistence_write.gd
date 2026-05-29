## Integration tests for StreakSystemScript Story 005 — Atomic Persistence Write (streak.* namespace).
##
## Covers:
##   AC-ss-persist-1: write order — count first (flush=false), date second (flush=true)
##   AC-ss-persist-2: second (date) flush fails → FAILED substate + streak_persistence_failed
##   AC-ss-persist-3: same-day record is idempotent — no duplicate write
##
## Story: production/epics/streak-system/story-005-atomic-persistence-write.md
## Test evidence path: tests/integration/streak/test_atomic_persistence_write.gd
extends GutTest
const StreakSystemScript := preload("res://src/autoload/streak_system.gd")


## Mock PersistenceLayer — records every write; can fail a chosen key's write.
class MockPersistenceLayer extends RefCounted:
	signal critical_save_failed(error_code: String, key: String)
	## Each entry: { "key": String, "value": Variant, "flush": bool }
	var write_log: Array = []
	## When non-empty, write() returns false for this key (simulates flush failure).
	var fail_on_key: String = ""

	func write(key: String, value: Variant, flush: bool = false) -> bool:
		write_log.append({"key": key, "value": value, "flush": flush})
		return key != fail_on_key


func _make_streak(mock_p: MockPersistenceLayer) -> StreakSystemScript:
	var s := StreakSystemScript.new()
	autofree(s)  # not in tree → _ready() does not run
	s._persistence = mock_p
	return s


# ---------------------------------------------------------------------------
# AC-ss-persist-1: 2-write order (count first non-critical, date second critical)
# ---------------------------------------------------------------------------

func test_persist_streak_writes_count_before_date() -> void:
	var p := MockPersistenceLayer.new()
	var s := _make_streak(p)

	s._persist_streak(3, 20240101)

	assert_eq(p.write_log.size(), 2, "exactly two writes")
	assert_eq(p.write_log[0]["key"], "streak.streak_count", "count key written first")
	assert_false(p.write_log[0]["flush"], "count write is non-critical (flush=false)")
	assert_eq(p.write_log[1]["key"], "streak.last_workout_date_local", "date key written second")
	assert_true(p.write_log[1]["flush"], "date write is critical (flush=true)")
	assert_eq(s._streak_count, 3, "streak_count updated on success")
	assert_eq(s._last_workout_date_local, 20240101, "date updated on success")


# ---------------------------------------------------------------------------
# AC-ss-persist-2: second flush fails → FAILED + signal, state not committed
# ---------------------------------------------------------------------------

func test_persist_streak_flush_failure_enters_failed_and_emits() -> void:
	var p := MockPersistenceLayer.new()
	p.fail_on_key = "streak.last_workout_date_local"  # the critical (second) write fails
	var s := _make_streak(p)
	watch_signals(s)

	s._persist_streak(3, 20240101)

	assert_eq(s._substate, StreakSystemScript.Substate.FAILED, "flush failure → FAILED substate")
	assert_signal_emitted_with_parameters(
		s, "streak_persistence_failed",
		["FLUSH_FAILED", "streak.last_workout_date_local"], 0
	)
	assert_eq(s._streak_count, 0, "streak_count NOT committed on flush failure")
	assert_eq(s._last_workout_date_local, 0, "date NOT committed on flush failure")


# ---------------------------------------------------------------------------
# AC-ss-persist-2 (count-write variant): first (count) write fails → FAILED,
# date write never attempted
# ---------------------------------------------------------------------------

func test_persist_streak_count_write_failure_aborts_before_date() -> void:
	var p := MockPersistenceLayer.new()
	p.fail_on_key = "streak.streak_count"  # the FIRST (count) write fails
	var s := _make_streak(p)
	watch_signals(s)

	s._persist_streak(3, 20240101)

	assert_eq(s._substate, StreakSystemScript.Substate.FAILED, "count-write failure → FAILED substate")
	assert_signal_emitted_with_parameters(
		s, "streak_persistence_failed",
		["FLUSH_FAILED", "streak.streak_count"], 0
	)
	assert_eq(p.write_log.size(), 1, "date write must NOT be attempted after count-write failure")


# ---------------------------------------------------------------------------
# AC-ss-persist-3: idempotency — same local day → no duplicate write
# ---------------------------------------------------------------------------

func test_record_today_workout_idempotent_same_day() -> void:
	var p := MockPersistenceLayer.new()
	var s := _make_streak(p)
	s._substate = StreakSystemScript.Substate.READY  # _ready() not run; force READY
	s._tz_offset_seconds = 0
	var utc := 1700000000
	var local_date := s.local_calendar_date_from_utc(utc, 0)
	# Pre-set the last workout to today's local date so the incoming call is a duplicate.
	s._last_workout_date_local = local_date
	s._streak_count = 5

	s.record_today_workout(utc)

	assert_eq(p.write_log.size(), 0, "same local day → no duplicate write")
	assert_eq(s._streak_count, 5, "streak_count unchanged on idempotent call")

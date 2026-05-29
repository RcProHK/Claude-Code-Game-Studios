## Unit tests for StreakSystem Story 002 — Core API (_on_workout_completed) + Drift Gate.
##
## Covers:
##   AC-ss-api-1: completed_at_utc within ±WALL_CLOCK_DRIFT_TOLERANCE_SECONDS passes the
##                drift gate; no streak_persistence_failed; streak logic proceeds.
##   AC-ss-api-2: completed_at_utc far in the future is rejected; streak_persistence_failed
##                emitted with ("DRIFT_GATE_REJECTED", ""); no streak mutation.
##   AC-ss-api-3: in BOOTING substate the event is deferred to _deferred_events (queue +1).
##
## Time is pinned via the _now_utc_override injection seam so the drift gate is fully
## deterministic and never reads the real system clock.
##
## Story: production/epics/streak-system/story-002-core-api-drift-gate.md
## Test evidence path: tests/unit/streak/test_core_api_drift_gate.gd
extends GutTest


## Fixed "now" injected into the system under test (Unix UTC seconds).
const FIXED_NOW: int = 1_000_000


## Mock GameStateMachine — satisfies the connect_for_initial_state subscription seam.
## Same pattern as Story 001 (tests/integration/streak/test_state_machine_boot.gd).
##
## ADR-0006 Contract 6 protection note: this mock has no `state_changed` signal, so any
## direct `state_changed.connect(...)` in production would runtime-error and fail the test.
class MockGSM extends RefCounted:
	func connect_for_initial_state(_callable: Callable) -> void:
		pass


## Minimal mock PersistenceLayer — satisfies the _ready() critical_save_failed
## connect + keeps boot tests hermetic (no real autoload coupling).
class MockPersistenceLayer extends RefCounted:
	signal critical_save_failed(error_code: String, key: String)
	func write(_key: String, _value: Variant, _flush: bool = false) -> bool:
		return true


## Helper: build a StreakSystem with mock GSM + mock PersistenceLayer + pinned time.
## Caller decides whether to add_child_autofree (which runs _ready → boots to READY).
func _make_streak() -> StreakSystem:
	var streak := StreakSystem.new()
	streak._gsm = MockGSM.new()
	streak._persistence = MockPersistenceLayer.new()
	streak._now_utc_override = FIXED_NOW
	return streak


# ---------------------------------------------------------------------------
# AC-ss-api-1: timestamp within tolerance passes the drift gate
# ---------------------------------------------------------------------------

func test_drift_gate_passes_for_recent_timestamp() -> void:
	# Arrange — boot to READY, delta = 150s (<= 300s tolerance)
	var streak := _make_streak()
	add_child_autofree(streak)  # _ready() → BOOTING→READY
	watch_signals(streak)
	var completed_at_utc := FIXED_NOW - 150

	# Act
	streak._on_workout_completed(completed_at_utc)

	# Assert — drift gate passed, no persistence-failure signal
	assert_signal_not_emitted(
		streak,
		"streak_persistence_failed",
		"A timestamp within tolerance must pass the drift gate (no failure signal)"
	)
	assert_true(
		streak._passes_drift_gate(completed_at_utc),
		"delta=150 must be <= WALL_CLOCK_DRIFT_TOLERANCE_SECONDS"
	)


# ---------------------------------------------------------------------------
# AC-ss-api-2: suspicious future timestamp is rejected
# ---------------------------------------------------------------------------

func test_drift_gate_rejects_future_timestamp() -> void:
	# Arrange — boot to READY, delta = 600s (> 300s tolerance)
	var streak := _make_streak()
	add_child_autofree(streak)  # _ready() → BOOTING→READY
	watch_signals(streak)
	var completed_at_utc := FIXED_NOW + 600

	# Act
	streak._on_workout_completed(completed_at_utc)

	# Assert — rejected with the documented error_code and empty key
	assert_signal_emitted_with_parameters(
		streak,
		"streak_persistence_failed",
		["DRIFT_GATE_REJECTED", ""],
		0
	)
	assert_false(
		streak._passes_drift_gate(completed_at_utc),
		"delta=600 must exceed WALL_CLOCK_DRIFT_TOLERANCE_SECONDS"
	)


# ---------------------------------------------------------------------------
# AC-ss-api-1/2 boundary: <= semantics + abs() both directions (off-by-one guard)
# ---------------------------------------------------------------------------

func test_drift_gate_boundary_and_past_direction() -> void:
	# Arrange
	var streak := _make_streak()
	add_child_autofree(streak)  # _ready() → BOOTING→READY

	# delta == tolerance (300) MUST pass (<= semantics; GDD AC-03: 600 passes, 601 rejects)
	assert_true(
		streak._passes_drift_gate(FIXED_NOW - 300),
		"past delta == 300 (== tolerance) must PASS"
	)
	assert_true(
		streak._passes_drift_gate(FIXED_NOW + 300),
		"future delta == 300 (== tolerance) must PASS"
	)
	# delta == 301 MUST reject (just over boundary) — both directions (abs is symmetric)
	assert_false(
		streak._passes_drift_gate(FIXED_NOW + 301),
		"future delta == 301 must REJECT (just over boundary)"
	)
	assert_false(
		streak._passes_drift_gate(FIXED_NOW - 600),
		"past delta == 600 must REJECT (abs() rejects stale timestamps too)"
	)


# ---------------------------------------------------------------------------
# AC-ss-api-3: BOOTING substate defers the event
# ---------------------------------------------------------------------------

func test_booting_substate_defers_event() -> void:
	# Arrange — construct WITHOUT add_child so _ready() never runs; _substate stays BOOTING
	var streak := _make_streak()
	autofree(streak)  # not in tree; free at teardown
	assert_eq(
		streak._substate,
		StreakSystem.Substate.BOOTING,
		"_substate must be BOOTING when _ready() has not run"
	)
	var queue_size_before := streak._deferred_events.size()

	# Act
	streak._on_workout_completed(0)

	# Assert — event queued, not processed
	assert_eq(
		streak._deferred_events.size(),
		queue_size_before + 1,
		"Workout event during BOOTING must be deferred (queue size +1)"
	)

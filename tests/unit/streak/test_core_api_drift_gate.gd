## Unit tests for StreakSystemScript Story 002 — Core API (_on_workout_completed) + Drift Gate.
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
const StreakSystemScript := preload("res://src/autoload/streak_system.gd")


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
class StubPersistence extends RefCounted:
	signal critical_save_failed(error_code: String, key: String)
	func write(_key: String, _value: Variant, _flush: bool = false) -> bool:
		return true


## Helper: build a StreakSystemScript with mock GSM + mock PersistenceLayer + pinned time.
## Caller decides whether to add_child_autofree (which runs _ready → boots to READY).
func _make_streak() -> StreakSystemScript:
	var streak := StreakSystemScript.new()
	streak._gsm = MockGSM.new()
	streak._persistence = StubPersistence.new()
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
# AC-ss-api-1/2 boundary: DIRECTIONAL gate (GDD Rule 4) — future-skew only.
# REVISED Story 010 (2026-06-01): the gate was symmetric (abs ≤ tolerance), which
# rejected stale PAST timestamps and broke Phone-Lost retro-credit (AC-37 / FR-1 /
# Falsifiable Test #3). Per GDD Rule 4 it now rejects only FUTURE skew > tolerance;
# PAST timestamps in monotonic order always pass (see test_*_monotonicity below).
# ---------------------------------------------------------------------------

func test_drift_gate_boundary_and_past_direction() -> void:
	# Arrange
	var streak := _make_streak()
	add_child_autofree(streak)  # _ready() → BOOTING→READY

	# Future skew == tolerance (300) MUST pass (<= semantics).
	assert_true(
		streak._passes_drift_gate(FIXED_NOW + 300),
		"future skew == 300 (== tolerance) must PASS"
	)
	# Future skew == 301 MUST reject (just over the forward boundary).
	assert_false(
		streak._passes_drift_gate(FIXED_NOW + 301),
		"future skew == 301 must REJECT (just over boundary)"
	)
	# PAST timestamps ALWAYS pass (no backward bound) — Phone-Lost retro-credit (GDD Rule 4).
	assert_true(
		streak._passes_drift_gate(FIXED_NOW - 300),
		"past delta == 300 must PASS (no backward bound — directional gate)"
	)
	assert_true(
		streak._passes_drift_gate(FIXED_NOW - 600),
		"past delta == 600 must PASS (was the symmetric-gate bug — retro events are real workouts)"
	)
	assert_true(
		streak._passes_drift_gate(FIXED_NOW - 5 * 86400),
		"past delta == 5 days must PASS (Phone-Lost: GymSys delivers a real offline workout late)"
	)


func test_drift_gate_rejects_non_monotonic_replay() -> void:
	# GDD Rule 4 monotonicity / replay defense: once an event is accepted, a strictly
	# OLDER event is rejected. The anchor advances only after a passing _on_workout_completed.
	var streak := _make_streak()
	add_child_autofree(streak)  # boots to READY

	# Accept a recent event → anchor advances to FIXED_NOW - 100.
	streak._on_workout_completed(FIXED_NOW - 100)
	assert_eq(streak._last_accepted_completed_at_utc, FIXED_NOW - 100,
		"monotonicity anchor advances after a passing gate")

	# An older event (predates the anchor) is now rejected by the replay guard.
	assert_false(
		streak._passes_drift_gate(FIXED_NOW - 200),
		"event older than the last accepted must REJECT (replay defense)"
	)
	# An equal-or-newer past event still passes (monotonic non-decreasing).
	assert_true(
		streak._passes_drift_gate(FIXED_NOW - 50),
		"event newer than the anchor (still in the past) must PASS"
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
		StreakSystemScript.Substate.BOOTING,
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

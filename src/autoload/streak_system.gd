## StreakSystem — Autoload position 8
##
## Manages workout streak tracking state machine with 5 substates.
## Subscribes to GameStateMachine via connect_for_initial_state (ADR-0006 Contract 6).
##
## Driving GDD: design/gdd/streak-system.md
## ADR: docs/architecture/adr-0006-state-machine-contract.md (Contract 6)
## Story: production/epics/streak-system/story-001-state-machine-boot.md
##
## NOTE: no `class_name` — this script is registered as the `StreakSystem` autoload
## (project.godot). A class_name matching the autoload name is a hard parse error
## ("hides an autoload singleton"). Tests that need the type preload the script
## directly (see tests/unit/streak/*, const StreakSystemScript).
extends Node

## Five internal substates governing streak operation lifecycle.
## Legal arcs: BOOTING→READY, READY→UPDATING, UPDATING→READY,
##             UPDATING→FAILED, FAILED→BACKOFF, BACKOFF→READY
enum Substate { BOOTING, READY, UPDATING, FAILED, BACKOFF }

## Legal substate transitions. Key = from substate (int), value = Array of legal 'to' substates.
## Untyped Dictionary required — GDScript const Dictionary cannot hold typed-enum Array values.
const LEGAL_ARCS: Dictionary = {
	Substate.BOOTING:  [Substate.READY],
	Substate.READY:    [Substate.UPDATING],
	Substate.UPDATING: [Substate.READY, Substate.FAILED],
	Substate.FAILED:   [Substate.BACKOFF],
	Substate.BACKOFF:  [Substate.READY],
}

## Wall-clock drift tolerance for the workout-completion drift gate (ADR-0006 Contract 9).
## Literal const: PersistenceLayer is an autoload singleton (no class_name), unavailable
## at parse time — so it cannot initialize a const. MUST stay in sync with
## PersistenceLayer.WALL_CLOCK_DRIFT_TOLERANCE_SECONDS (300s); enforced by the runtime
## assert in _ready() below (mirrors GameStateMachine Invariant 7 cross-system pattern).
const WALL_CLOCK_DRIFT_TOLERANCE_SECONDS: int = 300

## Buff step boundaries (ascending, strictly increasing — asserted at boot). (Story 004)
## EG-4 rename (was MILESTONE_THRESHOLDS): this is the Formula 1 step table INCLUDING the
## s=1 baseline boundary — NOT the milestone gate set ([7,14,30,60,90], GDD Rule 7).
## Future milestone-emit machinery (AC-38) must NOT iterate this table (the leading 1
## would emit a phantom day-1 milestone). See production/escalations/EG-4-streak-reachability.md.
const BUFF_STEP_THRESHOLDS: Array[int] = [1, 7, 14, 30, 60, 90]
## Buff multiplier per step boundary (non-decreasing — asserted at boot). (Story 004)
const BUFF_STEP_MULTIPLIERS: Array[float] = [1.1, 1.25, 1.4, 1.6, 1.8, 2.0]
## Hard cap on the streak buff multiplier. (Story 004)
const MAX_BUFF_MULTIPLIER: float = 2.0

## EG-4 rest-day grace: the chain continues when the calendar-day gap between the prior
## workout day and the new workout day is within this knob (3 = up to 2 full rest days).
## Reachability fix: zero grace made milestones 7+ mathematically unreachable for the
## default 3x/week cadence and incentivised daily junk workouts (anti-Pillar 1).
## Safe range [1, 4]; 1 reproduces the pre-EG-4 exact-next-day semantics. (GDD Rule 6)
const STREAK_GRACE_GAP_DAYS: int = 3

## Persistence keys — streak.* namespace per GDD Rule 12 (Story 005). Closed API:
## these are the ONLY keys StreakSystem writes; CI bans external streak.* writes.
const KEY_STREAK_COUNT: String = "streak.streak_count"
const KEY_LAST_WORKOUT_DATE: String = "streak.last_workout_date_local"

## Emitted after a successful substate transition.
signal substate_changed(from_state: Substate, to_state: Substate)

## Emitted when an illegal arc transition is attempted; _substate is unchanged.
signal invalid_transition_attempted(from_state: Substate, to_state: Substate)

## Emitted when a streak operation cannot be persisted or is rejected before persistence.
## error_code: machine-readable reason (e.g. "DRIFT_GATE_REJECTED").
## key: affected persistence key, "" when not applicable.
signal streak_persistence_failed(error_code: String, key: String)

## Current internal substate. Starts at BOOTING; transitions to READY after boot.
var _substate: Substate = Substate.BOOTING

## Queue of deferred callables accumulated during BOOTING.
## Drained once on the BOOTING→READY transition in _ready().
var _deferred_events: Array[Callable] = []

## GameStateMachine reference — overrideable for testing (dependency injection seam).
## Production: points to GameStateMachine autoload singleton.
## Tests: replaced with a mock before add_child / _ready() runs.
## Untyped intentionally: connect_for_initial_state is not a Node member, so a typed
## (Node) annotation would fail GDScript's compile-time member check. Duck-typed seam.
var _gsm = null

## Time provider override — overrideable for testing (dependency injection seam).
## Production: -1 means use Time.get_unix_time_from_system() live.
## Tests: set to a fixed non-negative int before invoking _on_workout_completed.
var _now_utc_override: int = -1

## Current consecutive-day streak count. Mutated only internally (Pillar 1 closed API). (Story 004)
var _streak_count: int = 0

## Local calendar date (YYYYMMDD) of the last recorded workout. 0 = none yet. (Story 005)
var _last_workout_date_local: int = 0

## Configured local timezone offset in seconds (data-driven; default UTC). (Story 005)
var _tz_offset_seconds: int = 0

## PersistenceLayer reference — overrideable for testing (dependency injection seam). (Story 005/006)
## Production: points to PersistenceLayer autoload singleton. Tests: inject a mock.
## Untyped intentionally: write()/critical_save_failed are not Node members, so a typed
## (Node) annotation would fail GDScript's compile-time member check. Duck-typed seam.
var _persistence = null

## Sticky single-emit guard: streak_persistence_failed emits at most once total. (Story 006)
var _persistence_failed_emitted: bool = false

## Last accepted workout timestamp (Unix UTC). Monotonicity anchor for the drift/replay
## gate (GDD Rule 4 directional semantics). A later event must not predate it; 0 = none
## accepted yet. Advanced in _on_workout_completed after a passing gate (NOT inside the
## pure predicate). Enables Phone-Lost retro-credit (Story 010 / FR-1 / Falsifiable #3).
var _last_accepted_completed_at_utc: int = 0


func _ready() -> void:
	# Default to singletons if not injected by test
	if _gsm == null:
		_gsm = GameStateMachine
	if _persistence == null:
		_persistence = PersistenceLayer
	# Boot-time knob invariant guard (Story 008 + 004), before persistence load.
	_assert_knob_invariants()
	# ADR-006 Contract 4: connect_for_initial_state (ADR-0006 Contract 6 helper).
	# FORBIDDEN: _gsm.state_changed.connect(_on_gsm_state_changed)
	# CI check: tools/ci/check_connect_for_initial_state_bind.gd enforces no .bind()
	_gsm.connect_for_initial_state(_on_gsm_state_changed)
	# Story 006: listen for PersistenceLayer critical save failures (streak.* filtered).
	_persistence.critical_save_failed.connect(_on_persistence_failed)
	_load_from_persistence()
	_drain_deferred_if_any()
	_transition_to(Substate.READY)


## Handles GSM state delivery — both initial-state sentinel and real transitions.
## Signature must match 3-arg state_changed signal: (from, to, payload).
## Must NOT be created with .bind() — callv positional delivery (ADR-0006 Contract 6).
func _on_gsm_state_changed(
	from_state: GameStateMachine.GameState,
	to_state: GameStateMachine.GameState,
	payload: StateTransitionPayload,
) -> void:
	if payload != null \
			and payload.source_event == GameStateMachine.INITIAL_STATE_PAYLOAD_SOURCE_EVENT:
		# Initial-state sentinel delivery — no action required at Story 001 scope.
		# Workout event handling deferred to Story 002.
		return
	# Real transition handling — deferred to Story 002+ (out of scope here).


## Drains deferred callables accumulated during BOOTING substate.
## Called once during _ready(), before transitioning to READY.
func _drain_deferred_if_any() -> void:
	var events := _deferred_events.duplicate()
	_deferred_events.clear()
	for ev: Callable in events:
		ev.call()


## Transitions to the given substate, enforcing legal arcs.
## Emits invalid_transition_attempted and leaves _substate unchanged on illegal arc.
##
## Re-entrancy note (ADR-0006 Contract 1): this sub-FSM intentionally has NO
## generational lock. All transitions are triggered synchronously by a single
## owner (StreakSystem itself), never re-entered from a substate_changed
## subscriber. Story 002 MUST re-evaluate this when it adds the first external
## subscriber that could trigger a re-entrant _transition_to.
func _transition_to(next: Substate) -> void:
	var legal: Array = LEGAL_ARCS.get(_substate, [])
	if next not in legal:
		invalid_transition_attempted.emit(_substate, next)
		return
	var prev: Substate = _substate
	_substate = next
	substate_changed.emit(prev, next)


## Handles a completed-workout event from the workout source (e.g. GymSys integration).
## During BOOTING the event is deferred and replayed on boot drain (ADR-0006 Contract 6).
## Applies the wall-clock drift gate (ADR-0006 Contract 9) before any streak mutation:
## a timestamp drifting more than WALL_CLOCK_DRIFT_TOLERANCE_SECONDS from local time is
## rejected (emits streak_persistence_failed) and produces no streak change.
##
## completed_at_utc: Unix UTC seconds when the workout completed (from the workout source).
func _on_workout_completed(completed_at_utc: int) -> void:
	# Sticky FAILED: once failed, ignore further workouts (no re-emit spam).
	if _substate == Substate.FAILED:
		return
	if _substate == Substate.BOOTING:
		_deferred_events.append(func() -> void: _on_workout_completed(completed_at_utc))
		return
	if not _passes_drift_gate(completed_at_utc):
		streak_persistence_failed.emit("DRIFT_GATE_REJECTED", "")
		return
	# Advance the monotonicity anchor only after a passing gate (Story 010). Done here,
	# not inside the pure predicate, so direct _passes_drift_gate() test calls never mutate.
	_last_accepted_completed_at_utc = completed_at_utc
	record_today_workout(completed_at_utc)


## Directional drift / replay gate (ADR-0006 Contract 9 + GDD Rule 4). Pure predicate
## (no mutation — safe to call directly in tests). Rejects:
##   * non-positive timestamps (invalid input),
##   * timestamps drifting MORE than WALL_CLOCK_DRIFT_TOLERANCE_SECONDS into the FUTURE
##     (device clock tampered backward, or backend returned a future timestamp),
##   * timestamps OLDER than the last accepted one (monotonicity / replay defense).
## PAST timestamps in monotonic order ALWAYS pass — this is the Phone-Lost retro-credit
## path (GDD Falsifiable Test #3 / FR-1): GymSys may deliver a real workout event hours or
## days after it occurred when the phone was offline; rejecting it would violate Pillar 1
## (real body, real power). The monotonicity anchor (_last_accepted_completed_at_utc) is
## advanced by _on_workout_completed after this gate passes.
func _passes_drift_gate(completed_at_utc: int) -> bool:
	if completed_at_utc <= 0:
		return false
	var future_skew: int = completed_at_utc - _get_now_utc()
	if future_skew > WALL_CLOCK_DRIFT_TOLERANCE_SECONDS:
		return false
	if _last_accepted_completed_at_utc > 0 and completed_at_utc < _last_accepted_completed_at_utc:
		return false
	return true


## Returns current Unix UTC seconds, honouring the _now_utc_override test seam.
## Production path (override < 0) reads Time.get_unix_time_from_system().
func _get_now_utc() -> int:
	if _now_utc_override >= 0:
		return _now_utc_override
	return int(Time.get_unix_time_from_system())


# ============================================================================
# Story 003 — Calendar formulas (DST-robust, noon-anchored)
# ============================================================================

## Formula 3 (ADR-0006 Contract 9): converts a UTC timestamp to a stable YYYYMMDD
## integer for the local calendar date. Noon-anchored (midnight is DST-ambiguous).
## utc: Unix UTC seconds. tz_offset_seconds: local offset (e.g. 28800 for UTC+8).
func local_calendar_date_from_utc(utc: int, tz_offset_seconds: int) -> int:
	var local: int = utc + tz_offset_seconds
	# posmod floor-to-day: correct for negative local (pre-epoch) where integer `/`
	# truncates toward zero instead of flooring (would be off-by-one a day).
	var day_start: int = local - posmod(local, 86400)
	var noon: int = day_start + 43200
	var dt: Dictionary = Time.get_datetime_dict_from_unix_time(noon)
	return dt["year"] * 10000 + dt["month"] * 100 + dt["day"]


## Calendar primitive: true iff date_a and date_b (YYYYMMDD integers) are exactly one
## calendar day apart. Same day → false. Month/year boundaries handled via noon-anchored
## unix conversion (raw integer subtraction is unsafe across boundaries, e.g. 20240131→20240201).
## NOTE (EG-4): no longer the production chain predicate — kept as the exact-1-day
## calendar formula. Production uses chain_continuation_classification below.
func consecutive_day_classification(date_a: int, date_b: int) -> bool:
	return _days_between(date_a, date_b) == 1


## Formula 2 (EG-4 amendment): true iff the calendar-day gap between date_a and date_b
## (YYYYMMDD integers) is within the rest-day grace window — `1 ≤ gap ≤
## STREAK_GRACE_GAP_DAYS`. Same day → false (the same-day idempotent branch
## short-circuits earlier in record_today_workout). GDD Rule 6 / EC-23 / AC-40.
func chain_continuation_classification(date_a: int, date_b: int) -> bool:
	var gap: int = _days_between(date_a, date_b)
	return gap >= 1 and gap <= STREAK_GRACE_GAP_DAYS


## Returns the absolute number of calendar days between two YYYYMMDD integers,
## via noon-anchored unix conversion (DST-safe).
func _days_between(date_a: int, date_b: int) -> int:
	var unix_a: int = _yyyymmdd_to_noon_unix(date_a)
	var unix_b: int = _yyyymmdd_to_noon_unix(date_b)
	return int(abs(unix_b - unix_a)) / 86400


## Converts a YYYYMMDD integer to its noon-anchored Unix UTC seconds.
func _yyyymmdd_to_noon_unix(yyyymmdd: int) -> int:
	var dt := {
		"year": yyyymmdd / 10000,
		"month": (yyyymmdd / 100) % 100,
		"day": yyyymmdd % 100,
		"hour": 12, "minute": 0, "second": 0,
	}
	return int(Time.get_unix_time_from_datetime_dict(dt))


# ============================================================================
# Story 004 — Buff multiplier (step function over milestones)
# ============================================================================

## Returns the streak buff multiplier as a step function over BUFF_STEP_THRESHOLDS.
## Baseline 1.0 below the first step boundary; capped at MAX_BUFF_MULTIPLIER.
func get_streak_buff_multiplier() -> float:
	var result: float = 1.0
	for i in range(BUFF_STEP_THRESHOLDS.size()):
		if _streak_count >= BUFF_STEP_THRESHOLDS[i]:
			result = BUFF_STEP_MULTIPLIERS[i]
		else:
			break
	return min(result, MAX_BUFF_MULTIPLIER)


## Boot-time invariant guard (ADR-0006 Contract 8 pattern): buff step boundaries
## strictly ascending + multipliers non-decreasing. Trips in debug builds.
func _assert_buff_step_invariants() -> void:
	assert(BUFF_STEP_THRESHOLDS.size() == BUFF_STEP_MULTIPLIERS.size(),
		"Buff step thresholds and multipliers must be the same length")
	for i in range(BUFF_STEP_THRESHOLDS.size() - 1):
		assert(BUFF_STEP_THRESHOLDS[i] < BUFF_STEP_THRESHOLDS[i + 1],
			"Buff step thresholds must be strictly ascending")
		assert(BUFF_STEP_MULTIPLIERS[i] <= BUFF_STEP_MULTIPLIERS[i + 1],
			"Buff step multipliers must be non-decreasing")


# ============================================================================
# Story 008 — Boot-time knob invariants
# ============================================================================

## Boot-time knob invariant guard (ADR-0006 Contract 8/9). Called from _ready()
## before persistence load. Trips in debug builds on any violation.
func _assert_knob_invariants() -> void:
	# Story 008 (ADR-0006 Contract 9): cross-system drift tolerance must match
	# PersistenceLayer's owned knob (both 300s).
	assert(
		WALL_CLOCK_DRIFT_TOLERANCE_SECONDS == PersistenceLayer.WALL_CLOCK_DRIFT_TOLERANCE_SECONDS,
		"Streak drift tolerance must match PersistenceLayer (%d vs %d)" %
			[WALL_CLOCK_DRIFT_TOLERANCE_SECONDS, PersistenceLayer.WALL_CLOCK_DRIFT_TOLERANCE_SECONDS]
	)
	# Story 004: buff step invariants (EG-4 rename)
	_assert_buff_step_invariants()
	# EG-4: grace knob bounds — [1, 4]; 1 = pre-EG-4 zero-grace degenerate floor.
	assert(STREAK_GRACE_GAP_DAYS >= 1 and STREAK_GRACE_GAP_DAYS <= 4,
		"STREAK_GRACE_GAP_DAYS must be within [1, 4] (EG-4 invariant #5)")


# ============================================================================
# Story 005 — Atomic persistence write (streak.* namespace)
# ============================================================================

## Records a completed workout for its local calendar day, then persists.
## Idempotent: a second call on the same local day is a no-op (no duplicate write).
## A workout day within the grace window (gap ≤ STREAK_GRACE_GAP_DAYS) extends the
## chain; a longer gap resets it to 1 (EG-4 — GDD Rule 6).
## No-op while in FAILED substate (sticky — Story 006).
func record_today_workout(completed_at_utc: int) -> void:
	if _substate == Substate.FAILED:
		return
	var local_date: int = local_calendar_date_from_utc(completed_at_utc, _tz_offset_seconds)
	# Idempotency: same local day already recorded → skip (no duplicate write).
	if local_date == _last_workout_date_local:
		return
	var new_count: int = 1
	if _last_workout_date_local != 0 \
			and chain_continuation_classification(_last_workout_date_local, local_date):
		new_count = _streak_count + 1
	_persist_streak(new_count, local_date)


## Atomic 2-write order (TR-streak-008): count first (non-critical, flush=false),
## then date second (critical, flush=true — the date is the recovery anchor).
## On flush failure: enter FAILED + emit streak_persistence_failed (sticky via _enter_failed).
func _persist_streak(new_count: int, local_date: int) -> void:
	# Count write is non-critical (flush=false) but can still fail (NOT_READY /
	# MIGRATION_IN_PROGRESS) — check it before attempting the critical date write.
	var count_ok: bool = _persistence.write(KEY_STREAK_COUNT, new_count, false)
	if not count_ok:
		_enter_failed("FLUSH_FAILED", KEY_STREAK_COUNT)
		return
	var ok: bool = _persistence.write(KEY_LAST_WORKOUT_DATE, local_date, true)
	if not ok:
		_enter_failed("FLUSH_FAILED", KEY_LAST_WORKOUT_DATE)
		return
	_streak_count = new_count
	_last_workout_date_local = local_date


# ============================================================================
# Story 006 — Failed state + error handling (sticky single-emit)
# ============================================================================

## Handles PersistenceLayer.critical_save_failed (TR-streak-010 namespace filter):
## only streak.* keys concern this system; others are ignored.
func _on_persistence_failed(error_code: String, key: String) -> void:
	if not key.begins_with("streak."):
		return
	_enter_failed(error_code, key)


## Enters the sticky FAILED substate and emits streak_persistence_failed exactly
## once total (TR-streak-009). Subsequent failures are silent. No auto-recovery
## without a session restart (Foundation-layer rule).
##
## Out-of-band transition (by design): persistence failures can arrive in ANY
## substate (e.g. an external PersistenceLayer.critical_save_failed in READY), so
## this deliberately bypasses _transition_to()'s LEGAL_ARCS validation. It still
## emits substate_changed so observers see the entry. LEGAL_ARCS remains the
## contract for normal-flow transitions via _transition_to() (Story 001).
func _enter_failed(error_code: String, key: String) -> void:
	if _substate != Substate.FAILED:
		var prev: Substate = _substate
		_substate = Substate.FAILED
		substate_changed.emit(prev, Substate.FAILED)
	if not _persistence_failed_emitted:
		_persistence_failed_emitted = true
		streak_persistence_failed.emit(error_code, key)


## Stub: load streak data from PersistenceLayer.
## Full implementation deferred to a later story (out of scope here).
func _load_from_persistence() -> void:
	pass

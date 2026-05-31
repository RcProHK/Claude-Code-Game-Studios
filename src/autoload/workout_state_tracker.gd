# WorkoutStateTracker — Autoload position 8 (#9)
#
# Status: Story 001 — WorkoutPhase FSM + Transition Guards
# Driving GDD: design/gdd/workout-state-tracker.md (Approved 2026-05-27)
# Governing ADR: ADR-0006 (State Machine Contract — Contract 12 NO await,
#                Contract 5 process_frame.connect CONNECT_ONE_SHOT for follow-up transitions)
#
# Story scope notes:
#   Story 001 — IMPLEMENTED: WorkoutPhase enum, _change_phase helper,
#               _set_history append-only, _rest_ended_awaiting_next_set flag,
#               signal handlers for all 5 workout event types + EC guards.
#   Story 002 — IMPLEMENTED: Substate enum (INITIALISING/READY/SUSPENDED) +
#               _is_frozen flag (orthogonal) + connect_for_initial_state GSM
#               subscription + SUSPENDED drop guards on all workout handlers +
#               EC-08 deferred SUSPENDED + EC-11 drop + poll_failed/recovered.
#   Story 003 — IMPLEMENTED: set_progress Formula 1 (estimated + full-data paths) +
#               monotonic clamp + EWMA Formula 2 (CF-3 ordering) +
#               _current_workout_id generation + _finalize_workout_idle reset.
#   Story 004 — IMPLEMENTED: dominant_class Formula 3 (set-count weighted + last-solo-leader
#               tiebreak) + 30s hysteresis cooldown + injectable time-source DI seam +
#               VS-tier 3-exercise stub + _classify_exercise helper.
#   Story 005 — IMPLEMENTED: 5 public read-only queries (get_current_phase / get_dominant_ability_class /
#               get_set_progress / get_completed_exercises_count / get_workout_snapshot) +
#               get_active_workout_id() + WorkoutSnapshotRO factory + _completed_exercises distinct tracking +
#               workout_id lifecycle isolation (_set_history + _completed_exercises reset on workout_started).
#   Story 006 — IMPLEMENTED: workout_started_forwarded signal + workout_completed_forwarded
#               full payload (completed_at, transition_id) + workout_summary_available(summary) +
#               WorkoutSummaryRO factory (_build_summary) + strict Rule 10 emission order +
#               total_volume Formula 4 + AC-37 tombstone dedup (best-effort, ADR-RATIFICATION-GATED).
#   Story 007 — IMPLEMENTED: class→stat routing table (Rule 13) + _stat_system DI seam +
#               _pending_stat_deltas buffer (cap 100, FIFO overflow) + wst_queue_overflow signal +
#               frozen window gate + Stat.ready drain. source_key stored in pending dict;
#               not yet passed to StatSystem (StatSystem.apply_stat_delta(stat,source,delta) = 3-param).
#   Story 008 — IMPLEMENTED: wst.* namespace PersistenceLayer writes (phase/id/started_at/
#               set_history/avg_sets/last_class) + bfcache resume sequence (_restore_from_persistence) +
#               TTL expiry (ADR-0006 Contract 9 drift-tolerant) + snapshot truncation (>256KB→50 sets) +
#               write-fail signal (wst_persist_failed) + bfcache_resumed/workout_state_discarded signals.
extends Node


## WorkoutPhase — ADR-0007 Family A (Outcome/State enum). Ordinal 0 = IDLE is
## the safe pre-_ready() default. Declaration order is LOCKED: ordinals carry
## persisted-migration meaning per ADR-0006 Contract 10.
enum WorkoutPhase {
	IDLE,              ## 0 — no active workout (boot default + post-complete terminal)
	WARM_UP,           ## 1 — workout_started received, no set_logged yet
	SET_ACTIVE,        ## 2 — mid-set window (last event was set_logged)
	REST_PERIOD,       ## 3 — rest_started received, awaiting rest_ended or next set
	WORKOUT_COMPLETE,  ## 4 — terminal; auto-returns to IDLE next tick via call_deferred
}

## Substate — boot lifecycle (ADR-0007 Family A: 0=INITIALISING is safe pre-_ready() default).
## Orthogonal to WorkoutPhase and to _is_frozen.
enum Substate {
	INITIALISING,  ## 0 — autoload _ready() in progress; queries return enum defaults
	READY,         ## 1 — normal operation
	SUSPENDED,     ## 2 — GSM Suspended state; all workout signals dropped (Rule 8)
}

## Emitted on every valid WorkoutPhase transition. Per GDD Rule 10 strict order,
## this fires BEFORE workout_summary_available and workout_completed_forwarded.
signal phase_changed(from_phase: WorkoutPhase, to_phase: WorkoutPhase)

## Forwarded when #2 GymSysClient emits workout_started. Story 001 re-emit.
signal workout_started_forwarded()

## Emitted in strict Rule 10 order: AFTER workout_summary_available, BEFORE IDLE auto-transition.
## Payload: completed_at (unix ms) + transition_id (acquired from GSM — ADR-0006 Contract 2).
signal workout_completed_forwarded(completed_at: int, transition_id: String)

## Emitted IMMEDIATELY BEFORE workout_completed_forwarded (Rule 16 NEVER #12).
## Consumers (#14 EnemyDirector, #15 LootDrop) cache the summary here.
signal workout_summary_available(summary: WorkoutSummaryRO)

## Emitted when set_progress changes (non-decreasing only — monotonic guarantee).
## Debounce (500ms) deferred to Story 008. Current implementation emits immediately.
signal set_progress_changed(new_progress: float)

## Emitted after _ready() completes a successful bfcache resume from wst.* snapshot.
signal bfcache_resumed(was_mid_workout: bool, restored_phase: int)

## Emitted when snapshot is discarded (TTL expired or device_handoff). Phase reset to IDLE.
signal workout_state_discarded(reason: String)

## Emitted when PersistenceLayer.write() returns false for a wst.* key (EC-24).
## WST continues in-memory — does NOT retry inline.
signal wst_persist_failed(key: String, reason: String)

# ---- Story 008 tuning knob constants ----

## Workout snapshot TTL: 24 hours = 86400 seconds. Boundary (exactly 24h) = valid per EC-26.
const WORKOUT_SNAPSHOT_TTL_HOURS: int = 24

## Snapshot byte threshold: if serialized set_history > this, truncate to SNAPSHOT_TRUNCATION_MAX_SETS.
## Must be ≤ PersistenceLayer MAX_STATE_FILE_BYTES (1 MB) per INV-7.
const SNAPSHOT_BYTE_TRUNCATION_THRESHOLD: int = 262144  # 256 KB

## Maximum sets to retain when snapshot is truncated. Must be ≥ typical max-sets for most workouts.
const SNAPSHOT_TRUNCATION_MAX_SETS: int = 50

## Emitted only when dominant_class genuinely flips AND cooldown has expired.
## Carries AbilityClass int value (AbilitySystem.AbilityClass.STRIKE/CONTROL/MOBILITY/UNKNOWN).
## NOT emitted on every set_logged — only on real class changes.
signal dominant_class_changed(new_class: int)

# ---- Story 004 tuning knob constant ----

## Hysteresis cooldown for dominant_class flips — prevents enemy wave thrash (EC-21).
## 30s ≥ #14 perception_tick_interval × min_visible_frames (INV-4).
const DOMINANT_CLASS_CHANGE_COOLDOWN_MS: int = 30_000

# ---- Story 003 tuning knob constants (data-driven, GDD Rule 4 / Formula 1/2) ----

## EWMA smoothing factor for historical_avg_sets / historical_avg_reps_per_set.
## α=0.3: half-life ≈ 2 workouts — responsive to style change, resilient to outliers.
## Safe range [0.1, 0.5]. See GDD Formula 2 Notes.
const HISTORICAL_EWMA_ALPHA: float = 0.3

## Cap applied when current_set_index > planned total — preserves buffer for
## true workout_completed event (must be < 1.0 per INV-2).
const SET_PROGRESS_BONUS_SET_CLAMP: float = 0.95

## Neutral fallback when BOTH planned_total_sets AND historical_avg are unavailable
## (cold start). Must be < pre_spawn_threshold(0.8) per INV-3 (does not trigger boss).
const SET_PROGRESS_NEUTRAL_FALLBACK: float = 0.5

var _workout_phase: WorkoutPhase = WorkoutPhase.IDLE
## Append-only within a workout. CF-4: entries are NEVER in-place mutated or popped.
var _set_history: Array[Dictionary] = []
## Set by _on_rest_ended; cleared by next _on_set_logged. Never triggers phase change.
var _rest_ended_awaiting_next_set: bool = false

## Boot substate — INITIALISING until _ready() finishes subscribing all signals.
var _substate: Substate = Substate.INITIALISING
## Frozen flag — set by poll_failed, cleared by poll_recovered. Orthogonal to substate.
## When true, phase machine rejects transitions (Rule 9). Can be true in any substate.
var _is_frozen: bool = false
## Last drop-reason code — written whenever a signal is dropped due to SUSPENDED or
## other non-critical conditions. Diagnostic field; cleared in _ready() each boot.
var _last_drop_reason: StringName = &""
## EC-08 race guard: set true when a deferred SUSPENDED entry is queued
## (WORKOUT_COMPLETE phase). Cleared when SUSPENDED entry fires or GSM exits Suspended.
## Prevents stuck-SUSPENDED if GSM leaves Suspended before the deferred lambda executes.
var _pending_suspended_entry: bool = false

# ---- Story 003: set_progress + EWMA state ----

## Last forwarded set_progress value. Monotonically non-decreasing within a workout.
## Reset to 0.0 on workout completion. Exposed via get_set_progress() (Story 005).
var _cached_set_progress: float = 0.0

## True when using the estimated fallback path (GymSys has not exposed planned_total_sets).
## Exposed via WorkoutSnapshotRO.set_progress_is_estimated (CI-2 binding for #14).
var _set_progress_is_estimated: bool = true

## Cross-workout EWMA of sets per session (Formula 2). 0.0 = uninitialized (first workout).
## Persisted to wst.history.avg_sets by Story 008.
var _historical_avg_sets: float = 0.0

## Parallel EWMA of reps per set (Formula 2). 0.0 = uninitialized.
var _historical_avg_reps_per_set: float = 0.0

## Full-data path inputs — set when GymSys exposes planned values (ADR-002-EXTENSION-GATED).
## -1 = unknown → falls back to estimated path.
var _planned_total_sets: int = -1
var _planned_reps_per_set: int = -1

## Client-derived workout identifier (GDD Rule 11.1). Non-empty during an active workout;
## empty string between workouts. Used for per-set stat idempotency keys (Story 007)
## and CF-3 ordering guard (AC-23: must be non-empty when EWMA computes).
var _current_workout_id: String = ""

# ---- Story 005: distinct exercise tracking + last cached snapshot ----

## Distinct exercise_id set for this workout (key = exercise_id, value = true).
## Used for get_completed_exercises_count() (CI-5). Reset on new workout.
## NOT filtered by AbilityClass mapping — any exercise_id contributes to count.
var _completed_exercises: Dictionary = {}

## Cached sealed WorkoutSnapshotRO for the current workout. Rebuilt on demand.
## Invalidated whenever any tracked field changes (for Story 005, always rebuilt on call).
## Story 008 may add a debounced cache here.
var _last_snapshot: WorkoutSnapshotRO = null

# ---- Story 006: WorkoutSummaryRO + transition_id + tombstone dedup ----

## Sealed WorkoutSummaryRO from the most recently completed workout.
## Populated in _on_workout_completed; consumed by #14/#15 via workout_summary_available.
var _last_summary: WorkoutSummaryRO = null

## Last acquired transition_id for the current (or most recent) workout_completed.
## Used for AC-37 tombstone dedup: if the same ID is seen twice, the second is dropped.
var _last_workout_transition_id: String = ""

# ---- Story 004: dominant_class state ----

## Cached dominant AbilityClass int value (AbilitySystem.AbilityClass.STRIKE/CONTROL/MOBILITY/UNKNOWN).
## Initialised to UNKNOWN in _ready(). Updated synchronously in _on_set_logged (NOT call_deferred)
## so #14's 4Hz tick always reads a fresh value without 1-frame lag.
var _cached_dominant_class: int = 3  # 3 = UNKNOWN ordinal (AbilitySystem.AbilityClass.UNKNOWN)

## Last solo-leader class seen during tiebreak walk. Preserved across workouts (EC-22 sticky).
## -1 = never set (first workout before any unambiguous leader).
var _previous_dominant_class: int = -1

## Timestamp (ms) of last _cached_dominant_class flip. Used for DOMINANT_CLASS_CHANGE_COOLDOWN_MS.
var _dominant_class_last_change_ms: int = 0

## Injectable time-source for cooldown testing (DI seam, untyped Node per project convention).
## null → uses Time.get_ticks_msec(). Tests inject a mock object via set(&"_time_source", mock).
var _time_source: Node = null

# ---- Story 007: Stat caller routing ----

## Max buffered stat delta calls when #11 StatSystem is not READY (EC-29, INV-5).
const PENDING_STAT_DELTAS_MAX: int = 100

## Emitted when _pending_stat_deltas overflows cap (EC-29 FIFO drop).
## Payload: dropped_count (int) — how many entries were dropped this overflow event.
signal wst_queue_overflow(dropped_count: int)

## Injectable #11 StatSystem reference (untyped Node — project DI convention per memory).
## null = use StatSystem autoload directly. Tests inject a spy double via set(&"_stat_system", spy).
var _stat_system: Node = null

## Pending apply_stat_delta calls buffered while #11 is not READY (substate != READY).
## Each entry: { "stat_id": StringName, "source": int, "delta": float, "source_key": String }
var _pending_stat_deltas: Array[Dictionary] = []

## Cumulative overflow drop count for queue_overflow telemetry (EC-29).
var _stat_delta_overflow_count: int = 0

# ---- Story 008: PersistenceLayer DI seam + snapshot state ----

## Injectable PersistenceLayer reference (untyped Node — project DI convention).
## null → resolved to PersistenceLayer autoload in _ready(). Tests inject a mock.
var _persistence_layer: Node = null

## Unix timestamp (seconds) when the current workout was started. Stored in
## wst.current_workout.started_at for TTL check on bfcache resume.
var _workout_started_at_s: int = 0


func _ready() -> void:
	# _substate starts INITIALISING (enum ordinal 0 = safe default, set at declaration).
	print_verbose("[WorkoutStateTracker] initialized — autoload pos 8 (#9)")
	_last_drop_reason = &""
	# Story 004: initialise dominant class vars using AbilitySystem enum (loaded before pos 8)
	_cached_dominant_class = AbilitySystem.AbilityClass.UNKNOWN
	_previous_dominant_class = AbilitySystem.AbilityClass.UNKNOWN
	# Subscribe to #1 GameStateMachine.state_changed for Suspended detection.
	# ADR-0006 Contract 6: use connect_for_initial_state (NOT direct .connect) to avoid
	# missing the signal if GSM already emitted before this autoload's _ready() ran.
	GameStateMachine.connect_for_initial_state(_on_gsm_state_changed)
	# Story 008: resolve PersistenceLayer reference + restore bfcache snapshot.
	if _persistence_layer == null:
		_persistence_layer = PersistenceLayer
	_restore_from_persistence()
	# TODO Story 012: connect to #2 GymSysBackendClient workout signals here.
	# Story 007: resolve StatSystem reference (untyped DI seam; injected by tests).
	# ADR-0008: StatSystem (pos 5) boots before WST (pos 8) — by the time _ready() runs,
	# StatSystem is guaranteed READY, so the queue is never used in normal operation.
	# The boot_completed connection is a safety net for edge cases (e.g. test injection
	# with delayed READY state). Do NOT use Node.ready — it has already fired at pos 5.
	if _stat_system == null:
		_stat_system = StatSystem
	# Connect to StatSystem.boot_completed (business-level "substate → READY" signal).
	if _stat_system.has_signal("boot_completed"):
		_stat_system.boot_completed.connect(_on_stat_system_ready, CONNECT_ONE_SHOT)
	# Eager drain: if StatSystem already READY (normal production path), drain immediately.
	if _stat_system.has_method("get_substate") \
			and _stat_system.get_substate() == StatSystem.Substate.READY:
		_on_stat_system_ready()
	_substate = Substate.READY


# ---------------------------------------------------------------------------
# GymSys signal handlers — connected by Story 012 (live #2 wiring).
# Callable directly in unit tests via WorkoutStateTracker.call("_on_workout_started") etc.
# ---------------------------------------------------------------------------

## Called by #2 GymSysBackendClient.workout_started.
func _on_workout_started() -> void:
	if _substate == Substate.SUSPENDED:
		_last_drop_reason = &"WST_SUSPENDED_DROP_WORKOUT_STARTED"
		push_warning("[WST_SUSPENDED_DROP] workout_started dropped — substate SUSPENDED (Rule 8)")
		return
	match _workout_phase:
		WorkoutPhase.IDLE:
			# Generate client-derived workout_id (GDD Rule 11.1 — defensive monotonicity).
			_current_workout_id = "wst-%d-%d" % [
				int(Time.get_unix_time_from_system() * 1000),
				randi() % 10000
			]
			# Story 004: reset dominant class for new workout (EC-22: previous_dominant_class preserved)
			_cached_dominant_class = AbilitySystem.AbilityClass.UNKNOWN
			_dominant_class_last_change_ms = 0
			# Story 005: clear set_history + distinct exercise set for clean workout isolation
			_set_history.clear()
			_completed_exercises.clear()
			_last_snapshot = null
			# Story 006: reset transition_id dedup for new workout
			_last_workout_transition_id = ""
			_last_summary = null
			# Story 008: record and persist workout start time for TTL tracking
			_workout_started_at_s = int(Time.get_unix_time_from_system())
			_persist_key("wst.current_workout.id", _current_workout_id)
			_persist_key("wst.current_workout.started_at", _workout_started_at_s)
			_change_phase(WorkoutPhase.WARM_UP)
			workout_started_forwarded.emit()  # Story 006: forwarded signal (AC-07)
		WorkoutPhase.SET_ACTIVE, WorkoutPhase.REST_PERIOD:
			# EC-06: prior workout ended without workout_completed — force-flush.
			# Per ADR-0006 Contract 5: follow-up phase transitions use process_frame.connect
			# (CONNECT_ONE_SHOT) instead of call_deferred to make ordering explicit and
			# prevent deferred-queue leaks across test boundaries.
			push_warning("[WST_FORCED_FLUSH_001] workout_started in %s — force-flushing prior workout" \
					% WorkoutPhase.find_key(_workout_phase))
			_change_phase(WorkoutPhase.WORKOUT_COMPLETE)
			get_tree().process_frame.connect(
				func() -> void:
					_transition_to_idle()
					_start_new_workout(),
				CONNECT_ONE_SHOT
			)
		WorkoutPhase.WARM_UP, WorkoutPhase.WORKOUT_COMPLETE:
			# EC-33 pattern: silent return (rapid retry / harmless dupe).
			# WARM_UP: workout already started, duplicate signal.
			# WORKOUT_COMPLETE: terminal state, new workout starts after IDLE auto-transition.
			pass


## Called by #2 GymSysBackendClient.set_logged.
func _on_set_logged(exercise_id: StringName, reps: int, weight: float) -> void:
	if _substate == Substate.SUSPENDED:
		_last_drop_reason = &"WST_SUSPENDED_DROP_SET_LOGGED"
		push_warning("[WST_SUSPENDED_DROP] set_logged dropped — substate SUSPENDED (Rule 8)")
		return
	match _workout_phase:
		WorkoutPhase.WORKOUT_COMPLETE:
			# EC-32: late backfill after workout sealed — drop, anti-fabrication.
			push_warning("[WST_LATE_SET_001] Late set_logged dropped in WORKOUT_COMPLETE (exercise=%s)" \
					% exercise_id)
			return
		WorkoutPhase.IDLE:
			# EC-02: set_logged with no preceding workout_started — fabrication guard.
			push_error("[WST_INV_VIOL_002] set_logged received in IDLE — dropping (no preceding workout_started)")
			return
	# Valid phases: WARM_UP / SET_ACTIVE / REST_PERIOD
	if _workout_phase != WorkoutPhase.SET_ACTIVE:
		_change_phase(WorkoutPhase.SET_ACTIVE)
	# CF-4: append-only. Never pop, never in-place mutate.
	_set_history.append({
		"exercise_id": exercise_id,
		"reps": reps,
		"weight": weight,
	})
	# Story 005: track distinct exercise_ids (CI-5). Idempotent — same id ≠ extra count.
	_completed_exercises[exercise_id] = true
	_last_snapshot = null  # Invalidate cached snapshot
	_rest_ended_awaiting_next_set = false
	# Compute and (if changed) emit set_progress (Formula 1, Story 003).
	_compute_and_emit_set_progress(reps)
	# Compute and (if changed + cooldown expired) emit dominant_class (Formula 3, Story 004).
	_update_dominant_class()
	# Story 007: route stat delta to #11 StatSystem (one-way, never read back).
	if not _is_frozen:
		_route_stat_delta(exercise_id, reps, weight)
	# Story 008: persist set_history (with truncation guard per EC-23/INV-7).
	_persist_set_history()


## Called by #2 GymSysBackendClient.rest_started.
func _on_rest_started() -> void:
	if _substate == Substate.SUSPENDED:
		_last_drop_reason = &"WST_SUSPENDED_DROP_REST_STARTED"
		push_warning("[WST_SUSPENDED_DROP] rest_started dropped — substate SUSPENDED (Rule 8)")
		return
	if _workout_phase == WorkoutPhase.SET_ACTIVE:
		_change_phase(WorkoutPhase.REST_PERIOD)
	else:
		# EC-03: rest_started before any set_logged, or other invalid phase.
		push_warning("[WST_INV_VIOL_003] rest_started in %s — dropping (EC-03)" \
				% WorkoutPhase.find_key(_workout_phase))


## Called by #2 GymSysBackendClient.rest_ended.
## Per GDD Rule 2: rest_ended does NOT change phase — sets internal flag only.
## EC-04: wrong phase → drop + warn.
func _on_rest_ended() -> void:
	if _substate == Substate.SUSPENDED:
		_last_drop_reason = &"WST_SUSPENDED_DROP_REST_ENDED"
		push_warning("[WST_SUSPENDED_DROP] rest_ended dropped — substate SUSPENDED (Rule 8)")
		return
	if _workout_phase == WorkoutPhase.REST_PERIOD:
		_rest_ended_awaiting_next_set = true
	else:
		push_warning("[WST_INV_VIOL_004] rest_ended in %s — dropping (EC-04)" \
				% WorkoutPhase.find_key(_workout_phase))


## Called by #2 GymSysBackendClient.workout_completed.
func _on_workout_completed(completed_at: int) -> void:
	if _substate == Substate.SUSPENDED:
		# EC-11: drop + log. #2 GymSysClient will backfill via idempotent polling on resume.
		_last_drop_reason = &"WST_SUSPENDED_DROP_COMPLETE_001"
		push_warning("[WST_SUSPENDED_DROP_COMPLETE_001] workout_completed dropped — substate SUSPENDED (EC-11)")
		return
	if _workout_phase == WorkoutPhase.IDLE:
		# EC-01: workout_completed with no active workout — Pillar 1 anti-fabrication gate.
		push_error("[WST_INV_VIOL_001] workout_completed received in IDLE — dropping (EC-01)")
		return
	_change_phase(WorkoutPhase.WORKOUT_COMPLETE)
	# Step 1: EC-19 diagnostic — log if entire workout had only unmapped exercises.
	if _set_history.size() > 0 and _compute_dominant_class() == AbilitySystem.AbilityClass.UNKNOWN:
		push_warning("[WST_ALL_UNKNOWN_001] workout completed with all UNKNOWN exercises — %d sets, workout_id=%s" \
				% [_set_history.size(), _current_workout_id])
	# Step 2: Acquire transition_id from GameStateMachine (ADR-0006 Contract 2 — NEVER self-generate).
	var txn_id: String = GameStateMachine.acquire_transition_id(
		GameStateMachine.GameState.WORKOUT_ACTIVE,
		GameStateMachine.GameState.LOOT_DROP
	)
	# AC-37 best-effort tombstone dedup (ADR-RATIFICATION-GATED — pending ADR-0006 Contract 2 finalization).
	# NOTE: _change_phase(WORKOUT_COMPLETE) already fired above. If dedup triggers here,
	# we still schedule _finalize_workout_idle to prevent the FSM from getting stuck.
	# The duplicate is dropped (no summary/forwarded signals), but IDLE auto-transition proceeds.
	if txn_id != "" and txn_id == _last_workout_transition_id:
		push_error("[WST_TXN_COLLIDE_001] Duplicate transition_id '%s' detected — dropping workout_completed (EC-30)" \
				% txn_id)
		call_deferred("_finalize_workout_idle")  # WST-006-01: prevent stuck WORKOUT_COMPLETE state
		return
	_last_workout_transition_id = txn_id
	# Step 3: Build sealed WorkoutSummaryRO (seal immediately — no mutation after this point).
	var summary: WorkoutSummaryRO = _build_summary(completed_at, txn_id)
	_last_summary = summary
	# Step 4 (Rule 10 strict order): emit workout_summary_available BEFORE workout_completed_forwarded.
	workout_summary_available.emit(summary)
	# Step 5: emit workout_completed_forwarded with full payload (Rule 16 NEVER #12).
	workout_completed_forwarded.emit(completed_at, txn_id)
	# Step 6: CF-3 — compute EWMA NOW, after summary sealed (set_history still intact),
	# BEFORE workout state reset (_current_workout_id still non-empty, AC-23).
	_compute_ewma(_set_history.size())
	# Story 008: persist EWMA + last_completed_class to wst.history namespace.
	# I3 fix: also persist avg_reps_per_set (restore path reads it for set_progress estimation).
	_persist_key("wst.history.avg_sets", _historical_avg_sets)
	_persist_key("wst.history.avg_reps_per_set", _historical_avg_reps_per_set)
	_persist_key("wst.history.last_completed_class", _cached_dominant_class)
	# Deferred: reset workout tracking vars + transition phase to IDLE.
	call_deferred("_finalize_workout_idle")


# ---------------------------------------------------------------------------
# GSM + poll signal handlers (Story 002)
# ---------------------------------------------------------------------------

## Connected to #1 GameStateMachine.state_changed via connect_for_initial_state
## (ADR-0006 Contract 6). Manages READY ↔ SUSPENDED substate transitions.
## Signal shape: (from_state: GameState, to_state: GameState, payload: StateTransitionPayload)
func _on_gsm_state_changed(
		_from: GameStateMachine.GameState,
		to: GameStateMachine.GameState,
		_payload: StateTransitionPayload) -> void:
	if to == GameStateMachine.GameState.SUSPENDED:
		if _workout_phase == WorkoutPhase.WORKOUT_COMPLETE:
			# EC-08: pending deferred callables (stat-apply, loot chain) must complete
			# before SUSPENDED blocks signals. Defer SUSPENDED entry by one frame so the
			# call_deferred queue drains first (ADR-0006 Contract 5 process_frame idiom).
			# _pending_suspended_entry guards against the stuck-SUSPENDED race: if GSM
			# sends non-SUSPENDED before this frame fires, the flag is cleared and
			# _enter_suspended() is skipped.
			_pending_suspended_entry = true
			get_tree().process_frame.connect(
				func() -> void:
					if _pending_suspended_entry:
						_enter_suspended()
						_pending_suspended_entry = false,
				CONNECT_ONE_SHOT
			)
		else:
			_enter_suspended()
	elif _substate == Substate.SUSPENDED:
		# GSM has left Suspended state — return to READY.
		_pending_suspended_entry = false
		_substate = Substate.READY
	else:
		# GSM transitioned to a non-Suspended state while WST was not yet SUSPENDED
		# (e.g. rapid SUSPENDED→ACTIVE in same frame as EC-08 defer). Cancel pending entry.
		_pending_suspended_entry = false


## Called by #2 GymSysBackendClient.poll_failed (Story 012 wires connection).
## Sets _is_frozen regardless of substate — frozen is orthogonal to substate (Rule 9).
## _category: e.g. &"network", &"auth", &"timeout" — currently unused; stored for
## future Rule 9 refinement (e.g. differentiating auth failures from transient polls).
## TODO Story 009 or later: route _category to telemetry WST_POLL_FAILED event.
func _on_poll_failed(_category: StringName = &"") -> void:
	_is_frozen = true


## Called by #2 GymSysBackendClient.poll_recovered (Story 012 wires connection).
func _on_poll_recovered() -> void:
	_is_frozen = false


# ---------------------------------------------------------------------------
# Private phase machine helpers
# ---------------------------------------------------------------------------

## Enter SUSPENDED substate. Called directly or via process_frame.connect (EC-08).
func _enter_suspended() -> void:
	_substate = Substate.SUSPENDED


func _transition_to_idle() -> void:
	_change_phase(WorkoutPhase.IDLE)


## Used by EC-06 force-flush deferred chain: _transition_to_idle → _start_new_workout.
## Generates a fresh workout_id + resets workout tracking for the new session.
func _start_new_workout() -> void:
	_current_workout_id = "wst-%d-%d" % [
		int(Time.get_unix_time_from_system() * 1000),
		randi() % 10000
	]
	# Story 005: reset workout tracking (EC-06 force-flush path)
	_set_history.clear()
	_completed_exercises.clear()
	_cached_set_progress = 0.0
	_cached_dominant_class = AbilitySystem.AbilityClass.UNKNOWN
	_dominant_class_last_change_ms = 0
	_last_snapshot = null
	_change_phase(WorkoutPhase.WARM_UP)


# ---------------------------------------------------------------------------
# Story 003: set_progress Formula 1 + EWMA Formula 2
# ---------------------------------------------------------------------------

## Compute set_progress from the just-appended set (after _set_history.append).
## Applies monotonic clamp and emits set_progress_changed if value increased.
## reps_in_set: from the set_logged payload (0 if no per-rep tracking available).
func _compute_and_emit_set_progress(reps_in_set: int) -> void:
	var current_set_index: int = _set_history.size()  # 1-based count after append

	# EC-15: cold start — both planned and historical unavailable
	if _planned_total_sets < 1 and _historical_avg_sets <= 0.0:
		_set_progress_is_estimated = true
		# set_progress stays neutral; don't reduce from prior value
		var clamped: float = max(SET_PROGRESS_NEUTRAL_FALLBACK, _cached_set_progress)
		if clamped > _cached_set_progress:
			_cached_set_progress = clamped
			set_progress_changed.emit(clamped)
		return

	var raw: float

	if _planned_total_sets >= 1:
		# Full-data path — only active when GymSys exposes planned_total_sets (ADR-002-EXTENSION-GATED)
		var planned_reps: int = _planned_reps_per_set
		if planned_reps <= 0:
			push_warning("[WST_PLANNED_ZERO_001] planned_reps_per_set <= 0 — falling to estimated path")
			_set_progress_is_estimated = true
			# fall through to estimated path below
		else:
			_set_progress_is_estimated = false
			raw = clamp(
				float(current_set_index - 1 + float(reps_in_set) / float(planned_reps)) \
				/ float(_planned_total_sets),
				0.0, 1.0
			)
			# Bonus-set cap (current > planned)
			if current_set_index > _planned_total_sets:
				raw = min(raw, SET_PROGRESS_BONUS_SET_CLAMP)
			_apply_monotonic_clamp(raw)
			return

	# Estimated path (current default — _planned_total_sets < 1 OR planned_reps invalid)
	_set_progress_is_estimated = true
	# EC-15: historical also unavailable here (0.0 = uninitialized) → neutral fallback.
	# Covers: planned_total_sets known but planned_reps invalid AND no historical data.
	if _historical_avg_sets <= 0.0:
		var clamped: float = max(SET_PROGRESS_NEUTRAL_FALLBACK, _cached_set_progress)
		if clamped > _cached_set_progress:
			_cached_set_progress = clamped
			set_progress_changed.emit(clamped)
		return
	var effective_total: int = max(current_set_index + 1, int(ceil(_historical_avg_sets)))
	var effective_reps: int = max(1, int(round(_historical_avg_reps_per_set)))
	raw = clamp(
		float(current_set_index - 1 + float(reps_in_set) / float(effective_reps)) \
		/ float(effective_total),
		0.0, 1.0
	)
	# Bonus-set cap
	if current_set_index > effective_total:
		raw = min(raw, SET_PROGRESS_BONUS_SET_CLAMP)
	_apply_monotonic_clamp(raw)


## Apply CF-1 monotonic clamp and emit set_progress_changed if value increased.
func _apply_monotonic_clamp(raw: float) -> void:
	var new_progress: float = max(raw, _cached_set_progress)
	if new_progress > _cached_set_progress:
		_cached_set_progress = new_progress
		set_progress_changed.emit(new_progress)
	elif raw < _cached_set_progress:
		# Downward revision suppressed — log at INFO level (GDScript: push_warning)
		push_warning("[WST_PROGRESS_MONOTONIC_BLOCKED] downward revision suppressed (raw=%.4f, current=%.4f)" \
				% [raw, _cached_set_progress])
	# raw == _cached: silent (non-decreasing, no change)


## Compute Formula 2 EWMA for historical_avg_sets and historical_avg_reps_per_set.
## Called synchronously in _on_workout_completed — AFTER summary sealed, BEFORE reset (CF-3).
func _compute_ewma(sets_count: int) -> void:
	var total_reps: int = 0
	for entry: Dictionary in _set_history:
		total_reps += entry.get("reps", 0)
	var avg_reps_this_workout: float = float(total_reps) / max(1.0, float(sets_count))

	if _historical_avg_sets <= 0.0:
		# Cold start (first workout) — store raw value, skip EWMA blend
		_historical_avg_sets = float(sets_count)
		_historical_avg_reps_per_set = avg_reps_this_workout
	else:
		_historical_avg_sets = HISTORICAL_EWMA_ALPHA * float(sets_count) \
				+ (1.0 - HISTORICAL_EWMA_ALPHA) * _historical_avg_sets
		_historical_avg_reps_per_set = HISTORICAL_EWMA_ALPHA * avg_reps_this_workout \
				+ (1.0 - HISTORICAL_EWMA_ALPHA) * _historical_avg_reps_per_set


## Called via call_deferred from _on_workout_completed.
## Resets per-workout tracking vars and transitions phase to IDLE.
## Runs AFTER _compute_ewma (CF-3: EWMA must precede reset, AC-23).
func _finalize_workout_idle() -> void:
	_current_workout_id = ""
	_cached_set_progress = 0.0
	_set_progress_is_estimated = true
	# Story 004: reset per-workout dominant class tracking.
	# _previous_dominant_class is intentionally NOT cleared (EC-22 cross-workout sticky).
	_cached_dominant_class = AbilitySystem.AbilityClass.UNKNOWN
	_dominant_class_last_change_ms = 0
	# Story 005: clear completed exercises and snapshot cache for next workout.
	# _completed_exercises is reset here (post-completion) so it's clean for next workout_started.
	_completed_exercises.clear()
	_last_snapshot = null
	# Story 007: reset per-workout overflow counter (telemetry only).
	_stat_delta_overflow_count = 0
	# Story 008: reset workout timing
	_workout_started_at_s = 0
	# Persist cleared phase to wst.current_workout.phase (after IDLE transition in _change_phase)
	# Note: _set_history and _historical_avg_* are not cleared here.
	_change_phase(WorkoutPhase.IDLE)


# ---------------------------------------------------------------------------
# Story 005: public read-only query API
# ---------------------------------------------------------------------------

## Returns current workout phase. O(1) cached read.
func get_current_phase() -> WorkoutPhase:
	return _workout_phase


## Returns dominant AbilityClass int value (AbilitySystem.AbilityClass enum).
## Returns AbilityClass.UNKNOWN (3) when no mapped exercises have been logged.
## Pillar 4 day-flavor signal source for #14 EnemyDirector. O(1) cached read.
func get_dominant_ability_class() -> int:
	return _cached_dominant_class


## Returns set_progress in [0.0, 1.0]. Monotonically non-decreasing within a workout.
## Pillar 2 boss anchor pre-spawn trigger for #14 EnemyDirector Rule 13. O(1) cached read.
func get_set_progress() -> float:
	return _cached_set_progress


## Returns DISTINCT exercise_id count for this workout (CI-5, not set count).
## ADR-005 loot volume_factor = min(1.0, completed / EXERCISE_TARGET_COUNT=5). O(1) read.
func get_completed_exercises_count() -> int:
	return _completed_exercises.size()


## Returns a sealed immutable snapshot of current WST state. O(1) construction.
## Snapshot fields reflect values at time of call. Consumers may cache this reference;
## it will not change after construction (sealed).
func get_workout_snapshot() -> WorkoutSnapshotRO:
	return _build_snapshot()


## Returns the current client-derived workout_id (may be "" between workouts).
## ADR-0009 §2: callers needing workout_id as ambient context call this, NOT reading from
## signal payload. Callers MUST handle "" (no active workout) explicitly.
func get_active_workout_id() -> String:
	return _current_workout_id


## Build a sealed WorkoutSummaryRO from current WST state at workout_completed time.
## Called BEFORE _compute_ewma() and _finalize_workout_idle() to capture intact state.
## total_volume = Σ (reps × weight) per Formula 4 (bodyweight sets with weight=0 contribute 0).
func _build_summary(completed_at_ms: int, txn_id: String) -> WorkoutSummaryRO:
	var summary := WorkoutSummaryRO.new()
	summary.completed_at = completed_at_ms
	summary.transition_id = txn_id
	summary.dominant_class = _cached_dominant_class
	summary.completed_exercises_count = _completed_exercises.size()
	summary.final_set_progress = _cached_set_progress
	summary.total_sets_logged = _set_history.size()
	# Formula 4: Σ (reps × weight) — bodyweight (weight=0.0) contributes 0 by design.
	var total_vol: float = 0.0
	for entry: Dictionary in _set_history:
		total_vol += float(entry.get("reps", 0)) * float(entry.get("weight", 0.0))
	summary.total_volume = total_vol
	summary.seal()
	return summary


## Build and seal a fresh WorkoutSnapshotRO from current WST state.
## Called by get_workout_snapshot(). Returns a new sealed resource each call.
func _build_snapshot() -> WorkoutSnapshotRO:
	var snap := WorkoutSnapshotRO.new()
	snap.current_phase = _workout_phase
	snap.set_progress = _cached_set_progress
	snap.set_progress_is_estimated = _set_progress_is_estimated
	snap.dominant_class = _cached_dominant_class
	snap.completed_exercises_count = _completed_exercises.size()
	snap.workout_id = _current_workout_id
	snap.is_suspended = (_substate == Substate.SUSPENDED)
	snap.is_stale_due_to_poll_failure = _is_frozen
	snap.seal()  # Immutable after this point
	return snap


# ---------------------------------------------------------------------------
# Story 007: Stat caller routing (Rule 6 + Rule 13 — one-way, no read-back)
# ---------------------------------------------------------------------------

## Route a set_logged event to #11 StatSystem via apply_stat_delta.
## Called from _on_set_logged when NOT frozen. Never called during SUSPENDED (Rule 8 guard upstream).
## ADR-0006: strictly one-way — NEVER call Stat.get_*() here.
func _route_stat_delta(exercise_id: StringName, reps: int, weight: float) -> void:
	var class_val: int = _classify_exercise(exercise_id)
	if class_val == AbilitySystem.AbilityClass.UNKNOWN:
		return  # Rule 6 + Rule 5: skip unmapped exercises (do NOT default to STR)

	var stat_id: StringName = _derive_stat_id_from_class(class_val)
	var delta: float = float(reps) * float(weight)  # raw volume (reps × kg)
	var set_index: int = _set_history.size()  # after append: 1-based set index
	var source_key: String = "%s_set_%d" % [_current_workout_id, set_index]

	# Check if #11 StatSystem is READY (untyped DI seam — duck-typed get_substate())
	var stat_ready: bool = true
	if _stat_system != null and _stat_system.has_method("get_substate"):
		stat_ready = (_stat_system.get_substate() == StatSystem.Substate.READY)
	elif _stat_system == null:
		stat_ready = false

	if not stat_ready:
		# EC-29: buffer the invocation (cap PENDING_STAT_DELTAS_MAX)
		if _pending_stat_deltas.size() >= PENDING_STAT_DELTAS_MAX:
			# FIFO overflow: drop oldest entry
			_pending_stat_deltas.pop_front()
			_stat_delta_overflow_count += 1
			push_error("[WST_QUEUE_OVERFLOW_001] _pending_stat_deltas overflow — dropped oldest (count=%d)" \
					% _stat_delta_overflow_count)
			wst_queue_overflow.emit(_stat_delta_overflow_count)
		_pending_stat_deltas.append({
			"stat_id": stat_id,
			"source": StatSystem.StatSource.VOLUME_TICK,
			"delta": delta,
			"source_key": source_key,
		})
		return

	# #11 is READY — call directly (one-way, never read back per Rule 16 NEVER #6)
	if _stat_system != null:
		_stat_system.apply_stat_delta(stat_id, StatSystem.StatSource.VOLUME_TICK, delta)


## Derive the #11 StatId StringName from an AbilityClass int value (Rule 13 routing table).
## STRIKE → STR (push muscles, attack_power)
## CONTROL → DEX (pull muscles, minor attack + move_speed)
## MOBILITY → VIT (leg muscles, max_hp)
## UNKNOWN → returns &"" (caller must skip)
func _derive_stat_id_from_class(class_val: int) -> StringName:
	match class_val:
		AbilitySystem.AbilityClass.STRIKE:
			return StatSystem.StatId.STR
		AbilitySystem.AbilityClass.CONTROL:
			return StatSystem.StatId.DEX
		AbilitySystem.AbilityClass.MOBILITY:
			return StatSystem.StatId.VIT
		_:
			return &""


## Drain _pending_stat_deltas when #11 StatSystem transitions to READY.
## Connected in _ready() via Stat.ready signal (CONNECT_ONE_SHOT).
func _on_stat_system_ready() -> void:
	if _pending_stat_deltas.is_empty():
		return
	for entry: Dictionary in _pending_stat_deltas:
		if _stat_system != null:
			# entry["source"] is already the correct StatSource int — no cast needed.
			# Using `as StatSource` on an int produces null in GDScript (as is Object cast only).
			_stat_system.apply_stat_delta(
				entry["stat_id"],
				entry["source"],
				entry["delta"]
			)
	_pending_stat_deltas.clear()


# ---------------------------------------------------------------------------
# Story 004: dominant_class Formula 3 + hysteresis + VS-tier stub
# ---------------------------------------------------------------------------

## VS-tier exercise → AbilityClass int mapping (3-exercise stub per GDD Rule 5 FR-2).
## Returns AbilitySystem.AbilityClass.UNKNOWN for any unmapped exercise_id.
## TODO Story #10: replace with IExerciseClassMapper.classify(exercise_id) interface.
func _classify_exercise(exercise_id: StringName) -> int:
	match exercise_id:
		&"bench_press":
			return AbilitySystem.AbilityClass.STRIKE
		&"row":
			return AbilitySystem.AbilityClass.CONTROL
		&"squat":
			return AbilitySystem.AbilityClass.MOBILITY
		_:
			return AbilitySystem.AbilityClass.UNKNOWN


## Compute dominant_class from current set_history via Formula 3 (set-count weighted
## with last-solo-leader tiebreak). Does NOT mutate state — pure derivation.
func _compute_dominant_class() -> int:
	# Build per-class set counts (UNKNOWN exercises excluded from tally)
	var set_counts: Dictionary = {
		AbilitySystem.AbilityClass.STRIKE: 0,
		AbilitySystem.AbilityClass.CONTROL: 0,
		AbilitySystem.AbilityClass.MOBILITY: 0,
	}
	for entry: Dictionary in _set_history:
		var class_val: int = _classify_exercise(entry.get("exercise_id", &""))
		if class_val != AbilitySystem.AbilityClass.UNKNOWN:
			set_counts[class_val] += 1

	# Find max count
	var max_count: int = 0
	for count: int in set_counts.values():
		if count > max_count:
			max_count = count

	# No mapped sets at all
	if max_count == 0:
		return AbilitySystem.AbilityClass.UNKNOWN

	# Collect leaders (classes tied for max)
	var leaders: Array = []
	for class_val: int in set_counts.keys():
		if set_counts[class_val] == max_count:
			leaders.append(class_val)

	# Unambiguous winner
	if leaders.size() == 1:
		return leaders[0]

	# Tie: reverse-chronological tiebreak walk (Formula 3 step 5-6)
	return _resolve_tiebreak(leaders)


## Reverse-chronological tiebreak walk: finds the last index where exactly one
## leader class had a strict solo max among leaders. Returns that class, or
## _previous_dominant_class (sticky) if no such index found, or UNKNOWN if no prior.
func _resolve_tiebreak(leaders: Array) -> int:
	# Walk from end to start, evaluating prefix set_history[0..i] at each i
	for i in range(_set_history.size() - 1, -1, -1):
		# Count only leader-class entries in the prefix [0..i]
		var prefix_leader_counts: Dictionary = {}
		for j in range(i + 1):
			var class_val: int = _classify_exercise(_set_history[j].get("exercise_id", &""))
			if class_val in leaders:
				prefix_leader_counts[class_val] = prefix_leader_counts.get(class_val, 0) + 1

		# Find max among leaders in this prefix
		var prefix_max: int = 0
		for count: int in prefix_leader_counts.values():
			if count > prefix_max:
				prefix_max = count

		# Check for solo leader (skip prefix if no leader class appeared at all)
		if prefix_max == 0:
			continue
		var solo: int = -1
		var solo_count: int = 0
		for class_val: int in leaders:
			if prefix_leader_counts.get(class_val, 0) == prefix_max:
				solo_count += 1
				solo = class_val

		if solo_count == 1:
			return solo

	# No solo leader found in any prefix — return sticky previous class or UNKNOWN
	if _previous_dominant_class != AbilitySystem.AbilityClass.UNKNOWN:
		return _previous_dominant_class
	return AbilitySystem.AbilityClass.UNKNOWN


## Update dominant_class cache and emit dominant_class_changed if value flips and cooldown passed.
## Called synchronously from _on_set_logged (after append) for #14 4Hz tick freshness.
func _update_dominant_class() -> void:
	var new_class: int = _compute_dominant_class()

	if new_class == _cached_dominant_class:
		return  # No change — no emit

	# Cooldown guard (only when already has a non-UNKNOWN dominant class — first assignment is immediate)
	if _cached_dominant_class != AbilitySystem.AbilityClass.UNKNOWN:
		var now_ms: int = _get_now_ms()
		var elapsed_ms: int = now_ms - _dominant_class_last_change_ms
		if elapsed_ms < DOMINANT_CLASS_CHANGE_COOLDOWN_MS:
			return  # EC-21: suppressed within cooldown window

	# Accept the new class
	_cached_dominant_class = new_class
	if new_class != AbilitySystem.AbilityClass.UNKNOWN:
		_previous_dominant_class = new_class
	_dominant_class_last_change_ms = _get_now_ms()

	dominant_class_changed.emit(new_class)
	# Note: EC-19 (all-UNKNOWN workout) is logged in _on_workout_completed, not here.
	# Logging here would require class != cached, which never holds for UNKNOWN→UNKNOWN transitions.


## Monotonic time accessor with injectable DI seam (untyped Node per project convention).
## Tests inject a mock via WorkoutStateTracker.set(&"_time_source", mock).
func _get_now_ms() -> int:
	if _time_source != null:
		return _time_source.get_now_ms()
	return Time.get_ticks_msec()


# ---------------------------------------------------------------------------
# Story 008: PersistenceLayer snapshot writes + bfcache resume
# ---------------------------------------------------------------------------

## Write a wst.* key to PersistenceLayer. On write failure, emits wst_persist_failed
## and continues in-memory (EC-24 — do NOT retry inline).
func _persist_key(key: String, value: Variant, flush: bool = false) -> void:
	if _persistence_layer == null:
		return
	var success: bool = _persistence_layer.write(key, value, flush)
	if not success:
		push_warning("[WST] persist failed: %s" % key)
		wst_persist_failed.emit(key, "write_returned_false")


## Persist set_history with truncation guard (EC-23 / INV-7).
## Truncates to last SNAPSHOT_TRUNCATION_MAX_SETS entries if serialized size > threshold.
func _persist_set_history() -> void:
	if _persistence_layer == null:
		return
	var history_to_persist: Array = _set_history
	# EC-23 truncation: check serialized size against 256KB threshold
	var json_str: String = JSON.stringify(_set_history)
	if json_str.length() > SNAPSHOT_BYTE_TRUNCATION_THRESHOLD:
		var original_count: int = _set_history.size()
		var kept_count: int = min(SNAPSHOT_TRUNCATION_MAX_SETS, original_count)
		history_to_persist = _set_history.slice(_set_history.size() - kept_count)
		push_warning("[WST_SNAPSHOT_TRUNC_001] set_history truncated: original=%d kept=%d" \
				% [original_count, kept_count])
	_persist_key("wst.current_workout.set_history", history_to_persist)


## Restore WST state from PersistenceLayer on boot/bfcache-resume.
## Called from _ready() after _persistence_layer is resolved.
## If snapshot is expired or missing, boots to IDLE with no resume signal.
func _restore_from_persistence() -> void:
	if _persistence_layer == null:
		return
	# Read snapshot keys
	var stored_phase: Variant = _persistence_layer.read("wst.current_workout.phase")
	var stored_id: Variant = _persistence_layer.read("wst.current_workout.id")
	var stored_started_at: Variant = _persistence_layer.read("wst.current_workout.started_at")
	var stored_set_history: Variant = _persistence_layer.read("wst.current_workout.set_history")
	var stored_avg_sets: Variant = _persistence_layer.read("wst.history.avg_sets")
	var stored_avg_reps: Variant = _persistence_layer.read("wst.history.avg_reps_per_set")
	var stored_last_class: Variant = _persistence_layer.read("wst.history.last_completed_class")

	# Restore cross-workout EWMA history (not TTL-gated)
	if stored_avg_sets != null:
		_historical_avg_sets = float(stored_avg_sets)
	if stored_avg_reps != null:
		_historical_avg_reps_per_set = float(stored_avg_reps)

	# No active workout snapshot → boot to IDLE (fresh start)
	if stored_phase == null or stored_started_at == null:
		return

	# TTL check (ADR-0006 Contract 9 drift-tolerant is_expired)
	var started_at_s: int = int(stored_started_at)
	var ttl_seconds: int = WORKOUT_SNAPSHOT_TTL_HOURS * 3600
	if _persistence_layer.is_expired(started_at_s, ttl_seconds):
		# EC-10 / EC-26: discard expired snapshot
		push_warning("[WST_TTL_DISCARD_001] workout snapshot expired — discarding and booting IDLE")
		workout_state_discarded.emit("ttl_expired")
		return

	# Snapshot is valid — restore workout state
	# C1 fix: plain int assignment; `as WorkoutPhase` on an int produces null in GDScript 4 (same as Story 007 C2)
	_workout_phase = int(stored_phase)
	_workout_started_at_s = started_at_s
	if stored_id != null:
		_current_workout_id = str(stored_id)
	# Restore set_history (CF-4 append-only — read into typed Array via explicit element copy).
	# W3 fix: direct untyped-Array → Array[Dictionary] assignment may throw at runtime.
	# JSON round-trip always produces untyped Array, so explicit copy is required.
	if stored_set_history != null and stored_set_history is Array:
		_set_history.clear()
		_completed_exercises.clear()
		for e in stored_set_history:
			var entry: Dictionary = e if e is Dictionary else {}
			_set_history.append(entry)
			_completed_exercises[entry.get("exercise_id", &"")] = true

	# Re-derive _cached_dominant_class from set_history (Rule 5 replay, Rule 7 "NOT persisted").
	# W1 fix: use SILENT recompute — do NOT call _update_dominant_class() which emits
	# dominant_class_changed. Resume is state reconstruction, not a real class-flip event.
	_cached_dominant_class = _compute_dominant_class()
	if _cached_dominant_class != AbilitySystem.AbilityClass.UNKNOWN:
		_previous_dominant_class = _cached_dominant_class

	# Emit resume signal
	var was_mid_workout: bool = (_workout_phase != WorkoutPhase.IDLE)
	bfcache_resumed.emit(was_mid_workout, int(_workout_phase))


## Central phase transition helper. ALL phase changes must go through here.
## Guarantees: state updated before signal emit; no duplicate emits for same phase.
func _change_phase(to: WorkoutPhase) -> void:
	var from: WorkoutPhase = _workout_phase
	_workout_phase = to
	phase_changed.emit(from, to)
	# Story 008: persist phase on every transition. flush=false — use PL's normal flush timer
	# (W2 fix: flush=true on every transition caused N flush cycles in EC-06 force-flush chain).
	_persist_key("wst.current_workout.phase", int(to))

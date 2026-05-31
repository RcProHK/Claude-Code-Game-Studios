## GameStateMachine — Autoload position 2 (LOCKED per ADR-0006 Contract 4)
##
## Status: Implemented (2026-05-29) — game-state-machine epic stories 001-016
## Complete. Wired: Contract 1 generational-lock transition primitive
## (_request_transition + _force_clear_lock), Contract 2 transition_id
## generation, Contract 3 tombstone write/remove + forward-recovery, Contract 4
## boot discipline, Contract 6/7 sentinel-delivery + race guard, Contract 8 knob
## asserts, Contract 14 spy hooks, event-intake priority queue (1-per-frame
## drain), Rule 5 boot reconciliation (priorities 1/2/5), Rule 5.5 weekly-tick
## replay, Rule 7 workout_completed force-transition, Rule 13 loot-reveal gating.
## Deferred post-VS: full Rule 5 priority cascade (0/0.5/1.5/3/4), Contract 10
## migration-chain guard, Story 017 bfcache resume spike.
##
## Driving GDD: design/gdd/game-state-machine.md (Approved 2026-05-26; 51 ACs)
## Governing ADRs: ADR-0006 State Machine Contract (Accepted 2026-05-28) — 15 contracts
##
## CRITICAL boot rule (ADR-0006 Contract 4, lines 272-307): MUST NOT emit
## state_changed from _ready(). Downstream subscribers (autoload positions 3+)
## have NOT yet connected — emit would be silently lost. Subscribers obtain
## initial state via connect_for_initial_state(callable) sentinel-delivery
## helper (Contract 6 lines 334-397 + Contract 7 lines 399-410).
##
## Autoload position 2 LOCK reminder (Contract 4 line 287-291):
##   1. PersistenceLayer
##   2. GameStateMachine  <-- THIS FILE
##   3. EnemyDirector / LootDropSystem / AttentionBudget / GymSysClient / ...
## Per-autoload sequential ordering (NOT batched) verified against Godot 4.6
## SceneTree behavior in Contract 4. Position 1 PersistenceLayer.read() is safe
## to call synchronously from _ready() here. Positions 3+ have not yet entered
## the tree — that is why state_changed emit from _ready() is forbidden.
##
## ============================================================================
## FOLLOW-UP FLAGS (must be resolved before Gate A graduation to VS implementation)
## ============================================================================
##
## F-STEP4-1 (DIVERGENCE — ADR-0006 vs GDD signal typing):
##   ADR-0006 Contract 6 code (line 374) and GDD line 627 both show
##   `callable.callv(["", captured_state, _initial_state_payload])` — first arg
##   is empty String `""`. But the canonical signal contract (GDD line 576) is
##   typed `signal state_changed(from_state: GameState, to_state: GameState, ...)`
##   — `GameState` is the enum, not String. Passing `""` violates the typed
##   signature: Godot 4.6 callv with mismatched typed-callable args either fails
##   silently (release) or asserts (debug) depending on the callable's typed-bind
##   state. RESOLUTION ADOPTED IN THIS FILE (per user Q3 decision 2026-05-28):
##   sentinel uses self-loop pattern callv([_current_state, _current_state,
##   _initial_state_payload]). Subscribers MUST detect via
##   `payload.source_event == "initial_state"` (Contract 6 sentinel pattern,
##   line 397). Future ADR-0006 prose addendum required to either (a) ratify
##   self-loop pattern as the canonical implementation, or (b) introduce a
##   dedicated `GameState.INITIAL` enum value — option (b) would expand the
##   9-state enum to 10 and ripple through all 51 ACs, so (a) preferred.
##
## F-RAT-1 (CROSS-KNOB WARNING — Gate A follow-up, surfaces when Contract 8
##   knob constants land in this file):
##   ADR-0006 line 20 Gate A signoff notes Invariant 1 boundary gap at
##   FALLBACK=1499 + MIN_REVEAL=11 (1499 > 1100=11×100). Production defaults
##   (FALLBACK=1000, MIN_REVEAL=15) are safely in invariant center, but Contract
##   8 _assert_knob_invariants() runtime check (ADR line 422) will trip if a
##   designer simultaneously moves both knobs to their corrected-range corners.
##   Resolution options recorded: (a) tighten STATE_TRANSITION_FALLBACK_MS upper
##   to 1100ms, OR (b) add cross-knob warning in GDD Tuning Knobs section.
##   Tracked as Gate A follow-up; do NOT silently paper over when Contract 8
##   constants are introduced in next step.
##
## Q-OQ8 (WRONG-SIGNATURE WARNING — avatar-renderer.md):
##   GDD avatar-renderer.md cites a 4-argument signature for the connect_for_
##   initial_state callable; canonical is the 1-argument Callable accepting the
##   3-arg `(from, to, payload)` callback shape (per Contract 6 line 355 +
##   line 381 ".bind() forbidden" rule). Reviewers seeing avatar-renderer.md
##   wiring MUST normalise to the 1-arg Callable form before that GDD lands
##   in implementation. Track for /architecture-review next pass.
## ============================================================================
extends Node


## GameState enum — 9 states locked by GDD line 585 + ADR-0006 §Decision.
## Order matches GDD; do NOT renumber (persisted state.json may carry int values
## in future migrations, though current Contract 3 serialization writes string
## names via SerializableResource envelope).
enum GameState {
	BOOTING,
	DISCONNECTED,
	IDLE,
	WORKOUT_ACTIVE,
	REST_PERIOD,
	COMBAT_ACTIVE,
	BOSS_ENCOUNTER,
	LOOT_DROP,
	SUSPENDED,
}


## Contract 6 sentinel marker (ADR-0006 line 343). Subscribers handling
## state_changed inspect `payload.source_event == INITIAL_STATE_PAYLOAD_SOURCE_EVENT`
## to distinguish the one-shot initial-state delivery from a real transition.
const INITIAL_STATE_PAYLOAD_SOURCE_EVENT: String = "initial_state"


# ============================================================================
# Tuning knob constants (ADR-0006 Contract 8 — Story 005)
# Each knob has a safe range documented inline. `_assert_knob_invariants()`
# runs at boot and trips in debug builds if a designer-tweaked value violates
# the cross-knob invariants documented in ADR-0006 lines 452-503.
# ============================================================================

## Per-transition fallback timer ceiling. If a transition gets stuck (e.g. a
## subscriber throws), this timer fires and clears `_transitioning` to prevent
## indefinite lock-hold. Safe range: 100..1499ms (Contract 8 Invariant 1).
const STATE_TRANSITION_FALLBACK_MS: int = 1000

## Minimum window the LootDrop reveal ritual must remain on-screen before any
## state transition can interrupt it. Safe range: 11..30s (Contract 8 corrected
## per Gate A 2026-05-28 — original 5..30 lower bound failed Invariant 1).
const MIN_REVEAL_WINDOW_SECONDS: int = 15

## TTL after which a stale `pending_transition` tombstone is considered abandoned
## and the corrupt path runs. Safe range: 3600..(SUSPENSION_TTL-1) (Invariant 2).
const TOMBSTONE_TTL_SECONDS: int = 7200

## TTL for the Suspended substate before forced fall-through to Idle.
## Strict greater-than TOMBSTONE_TTL_SECONDS (Invariant 2 — prevents inverted
## tombstone TTL > suspension TTL scenario).
const SUSPENSION_TTL_SECONDS: int = 86400

## Soft TTL for `loot_reveal_pending` — Safari ITP 7-day mitigation target.
## Safe range: 1..LOOTDROP_PENDING_HARD_CAP_DAYS-1 (Invariant 3).
const LOOTDROP_PENDING_TTL_DAYS: int = 6

## Hard cap on `loot_reveal_pending` age. Beyond this, force-reveal regardless
## of state. Strict greater than soft TTL (Invariant 3).
const LOOTDROP_PENDING_HARD_CAP_DAYS: int = 30

## Base retry delay for backoff (Formula 1: BASE_DELAY * 2^(n-1) clamped to
## RETRY_CAP). Must be > 0 (Invariant 4a).
const BASE_DELAY: float = 1.0

## Maximum retry delay (clamp ceiling). Must be ≥ BASE_DELAY (Invariant 4b).
const RETRY_CAP: float = 16.0

## Maximum retry attempts before giving up. FIXED at 30 to prevent IEEE 754
## overflow in `BASE_DELAY * 2^(n-1)` when n approaches 64. Changing this
## value MUST go through ADR revision (Invariant 5 — FIXED constant).
const ATTEMPT_CAP: int = 30

## Maximum weekly-tick catchup events at boot. Clamps `missed_count` in Rule 5.5
## replay to prevent multi-month-absence flood. Safe range: 1..52 (Invariant 6).
const MAX_WEEKLY_TICK_CATCHUP: int = 8


## Emitted by every real state transition AND by connect_for_initial_state via
## direct callv to a newly-connecting subscriber (ADR-0006 Contract 6 line 379
## binding: callv NOT emit — emit would broadcast to ALL subscribers including
## already-up-to-date ones).
##
## Typed parameters per GDD line 576 (canonical signature). See F-STEP4-1
## divergence flag in file header for the ADR/GDD string-vs-enum gap and the
## self-loop sentinel resolution adopted here.
signal state_changed(from_state: GameState, to_state: GameState, payload: StateTransitionPayload)


## ADR-0006 Contract 1 line 100 — emitted whenever a transition request is
## rejected because the lock is held by an in-flight transition. Subscribers
## MUST NOT call `_request_transition()` synchronously from their state_changed
## handler; dropped_event surfaces that footgun via reason="lock_held".
signal dropped_event(event: Variant, reason: String)


## In-memory current state. Defaults to BOOTING — Contract 4 boot model: this
## file's _ready() completes before downstream autoloads enter tree; first real
## transition (BOOTING -> IDLE / DISCONNECTED / restored state) happens later
## once PersistenceLayer reconciliation + GymSys first poll lands (future step).
var _current_state: GameState = GameState.BOOTING


## ADR-0006 Contract 1 — generational lock state (Story 002).
##
## `_transitioning` flips true while Rule 2 steps 1-8 execute. Re-entrant
## `_request_transition()` calls during that window emit `dropped_event` and
## return immediately. `_lock_gen` is the per-transition identifier that the
## fallback timer captures; on fire, the timer compares against the current
## `_lock_gen` and only clears the lock if its generation still matches —
## prevents a stale timer from a prior transition unlocking the new one.
var _transitioning: bool = false
var _lock_gen: int = 0


## Contract 7 race guard (ADR-0006 line 359 + 368). Updated to
## `Time.get_ticks_usec()` right before every real `state_changed.emit`. Used by
## `_deliver_initial_state` to skip stale initial-state delivery when a real
## transition fired between `connect_for_initial_state` call and the deferred
## lambda fire.
##
## Default -1 is load-bearing: first connect_for_initial_state call captures
## tick = -1; in _deliver_initial_state the guard reads `_last_emit_tick >
## captured_tick` which evaluates `-1 > -1` => false => initial state IS
## delivered. Once any real transition emits, this advances to a positive usec
## and any in-flight initial-state lambda from before that point correctly skips.
var _last_emit_tick: int = -1


## Sentinel payload constructed once at boot (ADR-0006 Contract 6 line 347).
## Single shared instance across all subscribers — they treat it read-only.
## Carrying a real (non-null) payload here avoids the null-deref footgun that
## Pass-3 godot-specialist B3 caught (ADR-0006 line 337).
var _initial_state_payload: StateTransitionPayload


func _ready() -> void:
	# Contract 4 (line 297): synchronous, no await. Safe to read PersistenceLayer
	# here (autoload position 1, already past its own _ready). But we MUST NOT
	# emit state_changed — positions 3+ have not yet connected.

	# Contract 8: validate knob invariants BEFORE any reconciliation (Story 005).
	# Debug builds crash on violation; release builds no-op (acceptable — VS/MVP
	# run debug per project policy).
	_assert_knob_invariants()

	_initial_state_payload = StateTransitionPayload.new()
	_initial_state_payload.source_event = INITIAL_STATE_PAYLOAD_SOURCE_EVENT
	_initial_state_payload.transition_id = ""
	_initial_state_payload.data = {}
	# Rule 5 boot reconciliation (Story 011 — simplified priority cascade).
	_run_rule5_reconciliation()
	# Rule 5 reconciliation here covers priorities 1/2/5 (tombstone forward-
	# recovery, explicit stored state, default IDLE). The remaining priority
	# cascade rungs (0/0.5/1.5/3/4 — 401 invalidation, LootDrop TTL) and the
	# Contract 10 migration-chain guard are deferred post-VS. Downstream
	# foundation autoloads (#5 Particle System Wrapper, #6 Screen Effects — both
	# cited at GDD line 370-371 as using connect_for_initial_state) can register
	# safely against the wired Contract 4 + Contract 6/7 boot model.
	print("[GameStateMachine] ready — pos 2; state=%s" % GameState.find_key(_current_state))


## Read-only accessor for the current game state.
##
## Consumers (e.g. #33 AttentionBudget per GDD line 364) MUST treat this as a
## point-in-time snapshot. To track ongoing state changes, subscribe via
## `connect_for_initial_state(callable)` instead — polling this getter races
## against the transition primitive (Contract 1) and may observe a value the
## subscriber-side state_changed signal has not yet broadcast.
func get_current_state() -> GameState:
	return _current_state


## Subscribe to state_changed AND receive the current state as a deferred
## one-shot delivery on the next frame.
##
## Cited by ADR-0006 Contract 6 (lines 334-397) + Contract 7 (lines 399-410).
##
## WHY a helper instead of plain state_changed.connect(callable):
## Contract 4 (line 296-297) — at _ready() time, downstream autoload subscribers
## have not yet connected; if GameStateMachine emitted an "initial" state_changed
## from _ready(), the emit would be lost. This helper closes the gap by
## delivering the captured current_state to the new subscriber on the next
## process_frame, AFTER the subscriber's own _ready() has wired its other
## signals.
##
## BINDING SIGNATURE: the Callable passed in MUST accept the canonical 3-arg
## shape `(from_state: GameState, to_state: GameState, payload: StateTransitionPayload)`
## per Contract 6 line 381. Using `.bind()` to prepend extra args is FORBIDDEN
## because the internal `callv(...)` path in `_deliver_initial_state` writes
## positional args — `.bind()` shifts the layout and silently mis-delivers
## (Contract 6 line 391, CI rule line 395).
##
## Subscribers detect the initial-state delivery via
## `payload.source_event == INITIAL_STATE_PAYLOAD_SOURCE_EVENT` (Contract 6
## sentinel pattern, line 397).
##
## See F-STEP4-1 in file header for the from_state arg sentinel choice
## (self-loop instead of String "") — ADR/GDD divergence pending addendum.
func connect_for_initial_state(callable: Callable) -> void:
	state_changed.connect(callable)
	# Capture at connect-time so the deferred lambda compares against the value
	# that was current WHEN the subscriber connected, not the value at lambda
	# fire-time (which a real transition between now and next frame would have
	# already advanced past).
	var captured_state: GameState = _current_state
	var captured_tick: int = _last_emit_tick
	get_tree().process_frame.connect(
		func() -> void: _deliver_initial_state(callable, captured_state, captured_tick),
		CONNECT_ONE_SHOT
	)


## Deferred delivery of the captured initial state to the newly-connected
## subscriber. Internal — not part of the public API; called only by the
## CONNECT_ONE_SHOT lambda in connect_for_initial_state.
##
## Cited by ADR-0006 Contract 7 (lines 399-410) race guard mechanism.
##
## RACE GUARD (Contract 7): if `_last_emit_tick` has advanced beyond
## `captured_tick`, a real state_changed emit fired between the subscriber's
## connect call and this lambda firing — the subscriber already received the
## up-to-date state via that real emit, so delivering the (now stale) initial
## state would cause: new -> old -> desync (the Pass-3 godot-specialist B4 bug,
## ADR line 401). Skip in that case.
##
## CALLV NOT EMIT (Contract 6 line 379 binding): we deliberately bypass
## state_changed.emit() because emit() would broadcast to every subscriber
## including those already up-to-date. callv targets ONLY the newly-connecting
## subscriber's Callable. Trade-off: this means initial delivery uses positional
## arg layout (which is why `.bind()` on the callable is forbidden — see
## connect_for_initial_state doc).
func _deliver_initial_state(callable: Callable, captured_state: GameState, captured_tick: int) -> void:
	if _last_emit_tick > captured_tick:
		return
	# Self-loop sentinel (from == to == captured_state) chosen per F-STEP4-1
	# resolution: the canonical signal is GameState-enum-typed, so we cannot
	# pass String "" as the ADR/GDD code samples currently show. Sentinel
	# semantics carried by payload.source_event == "initial_state" instead.
	callable.callv([captured_state, captured_state, _initial_state_payload])


# ============================================================================
# Test spy interface (ADR-0006 Contract 14 — Story 007)
# ============================================================================

## In-memory state mutation spies. Production methods are no-op below — tests
## inject Callables via `attach_in_memory_spy()` to record `_current_state`
## mutations. Story 002 (Rule 2 transition) will call `_notify_in_memory_spies()`
## on every state change.
var _in_memory_spies: Array[Callable] = []


## Attach a Callable invoked (old_state, new_state) on every `_current_state`
## mutation. Production records — tests inject recorders. ADR-0006 Contract 14.
func attach_in_memory_spy(spy: Callable) -> void:
	_in_memory_spies.append(spy)


## Clear all attached in-memory spies. Call in test tearDown() to prevent
## cross-test leakage.
func clear_spies() -> void:
	_in_memory_spies.clear()


## Internal helper invoked by transition primitive (Story 002) on every
## `_current_state` mutation. No-op if no spies attached.
func _notify_in_memory_spies(old_state: GameState, new_state: GameState) -> void:
	for spy in _in_memory_spies:
		spy.call(old_state, new_state)


# ============================================================================
# transition_id generation (ADR-0006 Contract 2 — Story 003)
# ============================================================================

## PersistenceLayer key for the monotonic transition counter. Persisted so
## the counter survives WASM reload (collision-safety across reload — see
## ADR-0006 Contract 2 lines 161-164).
const TRANSITION_ID_COUNTER_KEY: String = "gsm._transition_id_counter"


## Public entry point for external systems that need a coordinated transition_id
## (e.g. WorkoutStateTracker #9 acquiring an ID for WorkoutSummaryRO before
## forwarding workout_completed_forwarded — ADR-0006 Contract 2 + GDD Rule 11).
## Delegates to _generate_transition_id; increments the shared monotonic counter.
##
## Callers MUST NOT call this more than once per logical transition event.
## The caller owns the returned ID and uses it in both the signal payload AND
## any downstream resource that requires the same ID (e.g. LootDrop idempotency key).
func acquire_transition_id(from_state: GameState, to_state: GameState) -> String:
	return _generate_transition_id(from_state, to_state)


## Generate a collision-safe opaque transition_id.
## Format: `"%d_%d_%s_%s" % [wall_clock_ms, counter, from_name, to_name]`
##
## ADR-0006 Contract 2 binding rules:
##   * Counter is incremented BEFORE writing to PersistenceLayer (atomic
##     increment-then-persist).
##   * Counter survives WASM reload — IDs are globally monotonic across reload.
##   * String is OPAQUE — no code may parse it back (state names contain
##     underscores like `WORKOUT_ACTIVE` making split ambiguous). Recovery
##     context is read from tombstone Dictionary fields instead.
func _generate_transition_id(from_state: GameState, to_state: GameState) -> String:
	var wall_clock_ms: int = int(Time.get_unix_time_from_system() * 1000.0)
	var counter_value: Variant = PersistenceLayer.read(TRANSITION_ID_COUNTER_KEY)
	var counter: int = int(counter_value) if counter_value != null else 0
	counter += 1
	# Increment-then-persist BEFORE returning the ID (Contract 2 line 148).
	PersistenceLayer.write(TRANSITION_ID_COUNTER_KEY, counter)
	return "%d_%d_%s_%s" % [
		wall_clock_ms,
		counter,
		GameState.find_key(from_state),
		GameState.find_key(to_state),
	]


# ============================================================================
# Rule 5.5 Weekly Tick Replay (Story 012 — TR-gsm-012)
# ============================================================================

const WEEKLY_TICK_INTERVAL_SECONDS: int = 7 * 86400
const KEY_LAST_WEEKLY_TICK: String = "gsm._last_weekly_tick_unix"

signal weekly_tick_catchup_capped(missed_count: int, capped_at: int)


## Replay missed weekly ticks at boot, clamped to MAX_WEEKLY_TICK_CATCHUP=8.
## Returns the number of ticks fired (clamped value).
func _run_rule5_5_weekly_tick_replay() -> int:
	var last_tick_value: Variant = PersistenceLayer.read(KEY_LAST_WEEKLY_TICK)
	if last_tick_value == null:
		return 0
	var last_tick: int = int(last_tick_value)
	var now: int = int(Time.get_unix_time_from_system())
	@warning_ignore("integer_division")
	var missed: int = (now - last_tick) / WEEKLY_TICK_INTERVAL_SECONDS
	if missed <= 0:
		return 0
	if missed > MAX_WEEKLY_TICK_CATCHUP:
		weekly_tick_catchup_capped.emit(missed, MAX_WEEKLY_TICK_CATCHUP)
		missed = MAX_WEEKLY_TICK_CATCHUP
	return missed


# ============================================================================
# Rule 7: workout_completed force transition (Story 013 — TR-gsm-015)
# ============================================================================

## Force-transition to LOOT_DROP on workout_completed (priority 1).
## From BOSS_ENCOUNTER, attaches BossOutcome.INTERRUPTED_WITH_CREDIT.
func on_workout_completed(workout_id: String) -> void:
	var payload := StateTransitionPayload.new()
	payload.source_event = "workout_completed"
	payload.data = {"workout_id": workout_id}
	if _current_state == GameState.BOSS_ENCOUNTER:
		var boss := BossPayload.new()
		boss.outcome = BossPayload.BossOutcome.INTERRUPTED_WITH_CREDIT
		payload.data["boss"] = boss.to_dict()
	enqueue_event(payload, GameState.LOOT_DROP, 1)


# ============================================================================
# Rule 13: LootDrop reveal gating (Story 014 — TR-gsm-013)
# ============================================================================

const KEY_LOOT_REVEAL_PENDING: String = "gsm.loot_reveal_pending"
const LOOT_REVEAL_SAFE_STATES: Array[int] = [
	GameState.IDLE, GameState.REST_PERIOD, GameState.DISCONNECTED
]

## Returns true if pending loot reveal should fire in current state.
func _check_pending_loot_reveal() -> bool:
	var pending: Variant = PersistenceLayer.read(KEY_LOOT_REVEAL_PENDING)
	if pending != true:
		return false
	return _current_state in LOOT_REVEAL_SAFE_STATES


# ============================================================================
# Boot reconciliation Rule 5 (ADR-0006 — Story 011 simplified)
# ============================================================================

## Storage keys for Rule 5 reconciliation.
const KEY_CURRENT_STATE: String = "gsm.current_state"


## Simplified Rule 5 boot reconciliation (Story 011 scope — VS tier).
## Priority cascade (full version per GDD line 245-280):
##   * Priority 1: pending tombstone → forward-recovery
##   * Priority 2: explicit stored `gsm.current_state` → resume
##   * Priority 5: default IDLE
##
## Priorities 0/0.5/1.5/3/4 (401 invalidation, LootDrop TTL, etc.) deferred
## post-VS — Story 011 covers the core happy path.
func _run_rule5_reconciliation() -> void:
	# Priority 1: pending tombstone → forward-recovery
	var tombstone: Variant = PersistenceLayer.read(PENDING_TRANSITION_KEY)
	if tombstone != null and tombstone is Dictionary:
		_forward_recover_from_tombstone(tombstone)
		return

	# Priority 2: explicit stored state
	var stored: Variant = PersistenceLayer.read(KEY_CURRENT_STATE)
	if stored != null and stored is String:
		var resolved: int = GameState.get(stored, -1)
		if resolved >= 0:
			_current_state = resolved
			return

	# Priority 5: default IDLE
	_current_state = GameState.IDLE


# ============================================================================
# Event Intake Queue (ADR-0006 Contract 1 — Story 009)
# ============================================================================

## Priority FIFO. Lower priority = drained first (0=highest precedence).
## Each entry: {event, target_state, priority}
var _event_queue: Array[Dictionary] = []


## Enqueue a transition request. Lower priority drained first.
func enqueue_event(event: Variant, target_state: GameState, priority: int = 2) -> void:
	_event_queue.append({
		"event": event,
		"target_state": target_state,
		"priority": priority,
	})
	_event_queue.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return a["priority"] < b["priority"]
	)


## Drain 1 event per frame (Story 009 — TR-gsm-014).
func _process(_delta: float) -> void:
	if _event_queue.is_empty():
		return
	var entry: Dictionary = _event_queue.pop_front()
	# Validity re-check: skip if already in target state.
	if entry["target_state"] == _current_state:
		return
	_request_transition(entry["event"], entry["target_state"])


# ============================================================================
# Tombstone serialization (ADR-0006 Contract 3 — Story 004)
# ============================================================================

const PENDING_TRANSITION_KEY: String = "gsm.pending_transition"


## Write a tombstone for an in-flight transition (Rule 2 step 2).
## payload_type uses `get_script().get_global_name()` — NEVER `get_class()`.
func _write_tombstone(tid: String, from_state: GameState, to_state: GameState, payload: StateTransitionPayload) -> void:
	var payload_type: String = ""
	if payload != null and payload.get_script() != null:
		payload_type = payload.get_script().get_global_name()
	var tombstone: Dictionary = {
		"transition_id": tid,
		"from": GameState.find_key(from_state),
		"to": GameState.find_key(to_state),
		"wall_clock_anchor": Time.get_unix_time_from_system(),
		"monotonic_anchor": Time.get_ticks_usec(),
		"payload": payload.to_dict() if payload is SerializableResource else {},
		"payload_type": payload_type,
	}
	PersistenceLayer.write(PENDING_TRANSITION_KEY, tombstone, true)


## Remove the tombstone after a successful transition (Rule 2 step 5).
func _remove_tombstone() -> void:
	PersistenceLayer.delete(PENDING_TRANSITION_KEY)


## Forward-recovery from a persisted tombstone (Rule 5 priority 3).
## MUST reuse `tombstone["transition_id"]` verbatim — never regenerate
## (Contract 2 binding rule, CI-enforced by check_forward_recover_no_generate.sh).
func _forward_recover_from_tombstone(tombstone: Dictionary) -> void:
	var existing_id: String = tombstone.get("transition_id", "")
	if existing_id.is_empty():
		push_error("[GSM] Forward-recovery: tombstone missing transition_id — skipping")
		return

	var from_name: String = tombstone.get("from", "BOOTING")
	var to_name: String = tombstone.get("to", "IDLE")
	var from_state: GameState = GameState.get(from_name, GameState.BOOTING)
	var to_state: GameState = GameState.get(to_name, GameState.IDLE)

	var payload_type: String = tombstone.get("payload_type", "")
	var payload_data: Dictionary = tombstone.get("payload", {})
	var payload: StateTransitionPayload = _initial_state_payload
	if payload_type == "StateTransitionPayload":
		var restored: SerializableResource = StateTransitionPayload.from_dict(payload_data)
		if restored is StateTransitionPayload:
			payload = restored

	_current_state = to_state
	_notify_in_memory_spies(from_state, to_state)
	_last_emit_tick = Time.get_ticks_usec()
	state_changed.emit(from_state, to_state, payload)
	_remove_tombstone()


# ============================================================================
# Rule 2 atomic transition primitive (ADR-0006 Contract 1 — Story 002)
# ============================================================================

## Request a state transition. Single-thread WASM safe via generational lock.
##
## Re-entry policy (ADR-0006 Contract 1 lines 117-130):
##   * Synchronous re-entry from within a `state_changed` handler → emit
##     `dropped_event(event, "lock_held")` and return. Subscribers MUST defer
##     via `get_tree().process_frame.connect(func(): _request_transition(...),
##     CONNECT_ONE_SHOT)`.
##   * HTTPRequest.request_completed handlers MUST also `call_deferred` /
##     `process_frame` — they fire on the main thread but may land DURING an
##     in-flight transition's emit phase.
##
## Lock release sequence (Rule 2 step 8): `_transitioning = false` runs AFTER
## `state_changed.emit` completes. This means any subscriber that synchronously
## re-enters during `emit` sees `_transitioning = true` and gets the
## dropped_event signal as intended.
##
## For Story 002 scope, this method captures the lock acquire/release shell
## and the dropped_event guard. Steps 2-5 (tombstone write/read/cleanup) +
## the actual `_current_state` mutation land in Stories 003 + 004. The
## `to_state` and `payload` parameters are accepted now so the public API
## is locked at this story; full body wiring follows.
func _request_transition(event: Variant, to_state: GameState = GameState.IDLE, payload: StateTransitionPayload = null) -> void:
	if _transitioning:
		# Re-entry blocked — lock is held by an in-flight transition.
		dropped_event.emit(event, "lock_held")
		return

	_transitioning = true
	_lock_gen += 1
	var my_gen: int = _lock_gen

	# Per-transition fallback timer (NOT a process-global). On fire, the
	# captured generation gates the unlock so a stale timer from a previous
	# transition cannot clear a newer lock.
	var t: SceneTreeTimer = get_tree().create_timer(STATE_TRANSITION_FALLBACK_MS / 1000.0)
	t.timeout.connect(_force_clear_lock.bind(my_gen), CONNECT_ONE_SHOT)

	# Rule 2 steps 2-5 (tombstone write, in-memory mutation, tombstone delete,
	# backend write) land in Stories 003 + 004. For Story 002 scope, perform
	# the in-memory mutation + emit sequence so the lock semantics can be
	# end-to-end tested. Story 003 wraps this with tombstone+transition_id.
	var from_state: GameState = _current_state
	_current_state = to_state
	_notify_in_memory_spies(from_state, to_state)

	# Story 002 step 7: update race-guard tick BEFORE emit (Contract 7 line 446).
	_last_emit_tick = Time.get_ticks_usec()
	var effective_payload: StateTransitionPayload = payload if payload != null else _initial_state_payload
	state_changed.emit(from_state, to_state, effective_payload)

	# Rule 2 step 8: release lock AFTER emit so re-entrant subscribers
	# observe `_transitioning = true` and route through dropped_event.
	_transitioning = false


## ADR-0006 Contract 1 lines 116-121 — generational stale-timer guard.
##
## The fallback timer is created with `_force_clear_lock.bind(my_gen)` so the
## generation seen at creation is preserved in the bind. When the timer fires:
##   * If `_lock_gen` no longer matches `captured_gen`, a NEWER transition has
##     started since the timer was scheduled. The lock it sees belongs to that
##     newer transition — we MUST NOT clear it. Return.
##   * If generations match AND `_transitioning == true`, the original transition
##     never released the lock (a bug somewhere). The timer was the safety net;
##     clear the flag so the system can continue accepting transitions.
func _force_clear_lock(captured_gen: int) -> void:
	if captured_gen == _lock_gen and _transitioning:
		_transitioning = false


## ADR-0006 Contract 8 — runtime knob invariant assertions.
##
## Called from `_ready()` BEFORE Rule 5 reconciliation (Story 005).
## In debug builds (VS / MVP per project policy) each `assert()` traps with the
## given message. In release builds, `assert()` is a no-op — designer should
## have verified during VS playtest that production defaults are safely in the
## invariant centre.
##
## F-RAT-1 cross-knob warning (ADR-006 line 20): defaults FALLBACK=1000 +
## MIN_REVEAL=15 are safely in the invariant centre. Designer-corner combos
## like FALLBACK=1499 + MIN_REVEAL=11 will pass each individual range check
## but trip Invariant 1 at runtime. See GDD Tuning Knobs section for the
## pair-invariant warning that designers must read before tuning.
func _assert_knob_invariants() -> void:
	# Invariant 1: per-transition fallback ≤ minimum reveal window
	# (cross-knob invariant — see F-RAT-1)
	assert(
		STATE_TRANSITION_FALLBACK_MS <= MIN_REVEAL_WINDOW_SECONDS * 100,
		"Invariant 1 violated: STATE_TRANSITION_FALLBACK_MS (%d) > MIN_REVEAL_WINDOW_SECONDS (%d) × 100" %
			[STATE_TRANSITION_FALLBACK_MS, MIN_REVEAL_WINDOW_SECONDS]
	)
	# Invariant 2: tombstone TTL strictly less than suspension TTL
	assert(
		TOMBSTONE_TTL_SECONDS < SUSPENSION_TTL_SECONDS,
		"Invariant 2 violated: TOMBSTONE_TTL (%d) must be STRICTLY less than SUSPENSION_TTL (%d)" %
			[TOMBSTONE_TTL_SECONDS, SUSPENSION_TTL_SECONDS]
	)
	# Invariant 3: loot reveal soft TTL strictly less than hard cap
	assert(
		LOOTDROP_PENDING_TTL_DAYS < LOOTDROP_PENDING_HARD_CAP_DAYS,
		"Invariant 3 violated: SOFT_TTL (%d) must be < HARD_CAP (%d)" %
			[LOOTDROP_PENDING_TTL_DAYS, LOOTDROP_PENDING_HARD_CAP_DAYS]
	)
	# Invariant 4: backoff base + cap preconditions
	assert(BASE_DELAY > 0.0, "Invariant 4a violated: BASE_DELAY must be > 0")
	assert(RETRY_CAP >= BASE_DELAY, "Invariant 4b violated: RETRY_CAP must be ≥ BASE_DELAY")
	# Invariant 5: attempt cap fixed at 30 (IEEE 754 overflow guard for 2^n)
	assert(ATTEMPT_CAP == 30, "Invariant 5 violated: ATTEMPT_CAP must remain 30 (overflow guard)")
	# Invariant 6: weekly tick catchup sanity cap
	assert(MAX_WEEKLY_TICK_CATCHUP <= 52,
		"Invariant 6 violated: MAX_WEEKLY_TICK_CATCHUP must be ≤ 52")
	# Invariant 7: PersistenceLayer drift tolerance must be positive
	# (cross-system invariant — PersistenceLayer owns this knob; we re-assert here
	# because is_expired() callers in GSM rely on its non-zero value).
	assert(
		PersistenceLayer.WALL_CLOCK_DRIFT_TOLERANCE_SECONDS > 0,
		"Invariant 7 violated: PersistenceLayer.WALL_CLOCK_DRIFT_TOLERANCE_SECONDS must be > 0"
	)

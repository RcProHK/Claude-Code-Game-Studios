# Story 001: State Machine + Boot Subscription

> **Epic**: StreakSystem
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: M (2-3 hours)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-29

## Context

**GDD**: `design/gdd/streak-system.md`
**Requirement**: `TR-streak-003`, `TR-streak-004`
*(TR-003: "State machine (Booting/Ready/Updating/Failed/Backoff) + _drain_deferred_if_any()"; TR-004: "Subscribe via GameStateMachine.connect_for_initial_state ONLY")*

**ADR Governing Implementation**: ADR-0006 Contract 6 (connect_for_initial_state subscription)
**ADR Decision Summary**: StreakSystem MUST subscribe to GSM state changes via `connect_for_initial_state` (NOT direct `.connect`) — CI scan enforces this. State machine has 5 substates; `_drain_deferred_if_any()` fires on Booting→Ready transition.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Autoload pos 8 — subscriptions to pos 2 (GSM) are safe in `_ready()` via `connect_for_initial_state`.

**Control Manifest Rules (Foundation layer)**:
- Required: Use `connect_for_initial_state` for GSM subscription (NOT direct `.connect`)
- Forbidden: Direct `state_changed.connect()` call (CI enforced)

---

## Acceptance Criteria

- [x] **AC-ss-sm-1**: GIVEN fresh autoload boot, WHEN `_ready()` completes, THEN `_substate == Substate.BOOTING`; `_drain_deferred_if_any()` called after PersistenceLayer load triggers Booting→Ready transition.
- [x] **AC-ss-sm-2**: GIVEN StreakSystem in Booting substate, WHEN GSM delivers initial state via `connect_for_initial_state`, THEN subscription registered correctly; no state_changed.connect() used.
- [x] **AC-ss-sm-3**: GIVEN state machine transitions, WHEN `_substate` changes, THEN follows legal arcs: Booting→Ready, Ready→Updating, Updating→Ready, Updating→Failed, Failed→Backoff, Backoff→Ready.

---

## Implementation Notes

```gdscript
enum Substate { BOOTING, READY, UPDATING, FAILED, BACKOFF }
var _substate: Substate = Substate.BOOTING
var _deferred_events: Array[Callable] = []

func _ready() -> void:
    GameStateMachine.connect_for_initial_state(_on_gsm_state_changed)
    _load_from_persistence()
    _drain_deferred_if_any()
    _substate = Substate.READY

func _drain_deferred_if_any() -> void:
    var events := _deferred_events.duplicate()
    _deferred_events.clear()
    for ev in events: ev.call()
```

---

## Out of Scope

- Story 002: `_on_workout_completed` API implementation
- Story 005: actual PersistenceLayer write

---

## QA Test Cases

**AC-ss-sm-1** — Integration
- Given: fresh StreakSystem (mock GSM + mock PersistenceLayer)
- When: `_ready()` runs
- Then: substate == READY; deferred queue processed

**AC-ss-sm-2** — Integration
- Given: StreakSystem + MockGSM tracking connections
- When: `_ready()` completes
- Then: subscription via `connect_for_initial_state` (not direct state_changed.connect)

**AC-ss-sm-3** — Unit
- Given: each substate
- When: valid transition attempted
- Then: succeeds; invalid transition emits error + stays in current substate

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/streak/test_state_machine_boot.gd` — must pass

**Status**: [x] Created — 8 test functions covering all 3 ACs
- `test_substate_is_booting_before_ready_and_ready_after`
- `test_deferred_events_are_drained_during_boot`
- `test_subscription_uses_connect_for_initial_state`
- `test_initial_state_sentinel_delivery_does_not_change_substate` *(AC-ss-sm-2 callv signature)*
- `test_boot_emits_substate_changed_booting_to_ready`
- `test_legal_transition_emits_substate_changed_with_correct_params`
- `test_legal_arcs_transition_successfully`
- `test_illegal_arcs_emit_signal_and_leave_state_unchanged`

---

## Dependencies

- Depends on: GameStateMachine epic (Story 010 Complete ✅), PersistenceLayer epic (Stories 002+003 Complete ✅)
- Unlocks: Story 002 (core API uses state machine)

---

## Completion Notes

**Completed**: 2026-05-29
**Criteria**: 3/3 passing (0 deferred)
**Deviations**: None
**Test Evidence**: Integration test at `tests/integration/streak/test_state_machine_boot.gd` (8 tests, all ACs covered including sentinel callv signature validation)
**Code Review**: Complete — APPROVED (2 testability gaps found + fixed: MockGSM sentinel delivery + substate_changed signal assertions)

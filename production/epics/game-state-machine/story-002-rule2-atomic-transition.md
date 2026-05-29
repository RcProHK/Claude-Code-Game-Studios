# Story 002: Rule 2 Atomic Transition Primitive — Generational Lock

> **Epic**: GameStateMachine
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: L (4+ hours)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-29

## Context

**GDD**: `design/gdd/game-state-machine.md`
**Requirement**: `TR-gsm-002`, `TR-gsm-003`
*(TR-002: "Rule 2: 8-step atomic transition"; TR-003: "Generational lock + _force_clear_timer per-transition fallback")*

**ADR Governing Implementation**: ADR-0006 Contract 1 (Atomic Transition Primitive: Generational Lock ID)
**ADR Decision Summary**: `_request_transition(event)` acquires generational lock (`_lock_gen++`), runs 8 steps atomically, releases lock after `state_changed.emit`. Per-transition `_force_clear_timer` (NOT global) fallback clears stuck locks. Re-entrant calls from `state_changed` handlers emit `dropped_event("lock_held")` and must use `process_frame.connect(CONNECT_ONE_SHOT)` for follow-up.

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: GDScript single-thread WASM. Timer created via `get_tree().create_timer(STATE_TRANSITION_FALLBACK_MS/1000.0)` — NOT `add_child(Timer)` here. `CONNECT_ONE_SHOT` flag available. No `await` anywhere.

**Control Manifest Rules (Foundation layer)**:
- Required: Generational lock (not Mutex) — future-proof for both threading modes
- Forbidden: Pure `call_deferred` frame-boundary atomicity (adds 16.6ms delay, Pillar 3 violation)
- Forbidden: `await` anywhere in transition code

---

## Acceptance Criteria

- [ ] **AC-04a**: GIVEN `_request_transition(event)` called while lock held (synchronous re-entry from `state_changed` handler), THEN `dropped_event("lock_held")` signal emits; original transition completes normally.
- [ ] **AC-04b**: GIVEN `_request_transition(event)` called, WHEN transition completes, THEN `_lock_gen` has incremented by 1 AND `_transitioning = false`.
- [ ] **AC-04c**: GIVEN `_force_clear_timer` fires for a captured generation that NO LONGER matches `_lock_gen` (stale timer), THEN lock is NOT cleared (generational check prevents spurious unlock).
- [ ] **AC-32a**: GIVEN `state_changed` subscriber immediately calls `_request_transition`, THEN the follow-up transition MUST use `process_frame.connect(CONNECT_ONE_SHOT)` deferred path — direct call emits `dropped_event`.

---

## Implementation Notes

*From ADR-0006 Contract 1 (lines 84-133):*

```gdscript
var _transitioning: bool = false
var _lock_gen: int = 0
signal dropped_event(event, reason: String)

func _request_transition(event) -> void:
    if _transitioning:
        dropped_event.emit(event, "lock_held")
        return
    _transitioning = true
    _lock_gen += 1
    var my_gen: int = _lock_gen
    # Per-transition fallback timer
    var t = get_tree().create_timer(STATE_TRANSITION_FALLBACK_MS / 1000.0)
    t.timeout.connect(_force_clear_lock.bind(my_gen), CONNECT_ONE_SHOT)
    # ... Rule 2 steps 1-8 (Story 003/004 implement steps 2-5) ...
    _last_emit_tick = Time.get_ticks_usec()
    state_changed.emit(from, to, payload)
    _transitioning = false

func _force_clear_lock(captured_gen: int) -> void:
    if captured_gen == _lock_gen and _transitioning:
        _transitioning = false
```

For VS tier: steps 2-5 (tombstone write, final state, in-mem update, remove tombstone) implemented in Stories 003+004. Steps 6-8 (backend write, signal emit, lock release) here.

---

## Out of Scope

- Story 003: transition_id generation (Contract 2)
- Story 004: Tombstone write/read/forward-recovery (Contract 3)

---

## QA Test Cases

**AC-04a** — Unit
- Given: `_transitioning=true` (lock held)
- When: `_request_transition(event)` called
- Then: `dropped_event("lock_held")` emitted; lock state unchanged

**AC-04b** — Unit
- Given: fresh transition executes
- When: transition completes
- Then: `_lock_gen` incremented; `_transitioning == false`

**AC-04c** — Unit
- Given: stale timer fires (captured_gen < _lock_gen)
- When: `_force_clear_lock(old_gen)` called
- Then: `_transitioning` NOT cleared (generational check)

**AC-32a** — Unit
- Given: subscriber directly calls `_request_transition` from `state_changed` handler
- When: transition fires
- Then: `dropped_event` emits; direct re-call does not complete

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/state_machine/test_rule2_atomic_transition.gd` — must pass

**Status**: [x] Created — `test_rule2_atomic_transition.gd` (7 tests)

---

## Completion Notes
**Completed**: 2026-05-29
**Criteria**: 4/4 passing (AC-04a ✅ AC-04b ✅ AC-04c ✅ AC-32a ✅)
**Deviations**: Story 002 implements lock primitive + minimal in-memory state mutation. Tombstone write/read (steps 2-5) deferred to Stories 003+004 — production behavior is currently "in-memory only" between transitions. Tests cover lock semantics end-to-end.
**Test Evidence**: Logic — `test_rule2_atomic_transition.gd` (7 tests)
**Code Review**: APPROVED (inline)

---

## Dependencies

- Depends on: Story 001 (GameState enum verified)
- Unlocks: Story 003, Story 005 (lock tests rely on this primitive)

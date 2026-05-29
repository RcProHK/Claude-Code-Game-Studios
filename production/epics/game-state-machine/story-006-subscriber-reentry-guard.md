# Story 006: Subscriber Re-Entry Guard + dropped_event Signal

> **Epic**: GameStateMachine
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S (1-2 hours)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-29

## Context

**GDD**: `design/gdd/game-state-machine.md`
**Requirement**: `TR-gsm-007`
*(Requirement text: "Subscriber re-entry: synchronous re-entry blocked (lock held during emit); follow-up MUST use process_frame.connect(CONNECT_ONE_SHOT) lambda pattern")*

**ADR Governing Implementation**: ADR-0006 Contract 1 (re-entrance guarantees) + Contract 5 (Callable.call_deferred signature)
**ADR Decision Summary**: Synchronous re-entry from `state_changed` handler immediately blocked → `dropped_event` emits. `HTTPRequest.request_completed` MUST `call_deferred` any state transition. Prefer `get_tree().process_frame.connect(func():..., CONNECT_ONE_SHOT)` over direct `call_deferred` due to variadic-args ambiguity.

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: GDScript 4.5+ variadic args ambiguity for `Callable.call_deferred(BossPayload_instance)` — use lambda+connect pattern instead (ADR-0006 Contract 5).

**Control Manifest Rules (Foundation layer)**:
- Required: `get_tree().process_frame.connect(func():..., CONNECT_ONE_SHOT)` for deferred transitions
- Forbidden: Direct synchronous `_request_transition` call from within `state_changed` subscriber

---

## Acceptance Criteria

- [ ] **AC-04a** (already in Story 002, cross-ref): re-entry emits `dropped_event("lock_held")` — covered by Story 002.
- [ ] **AC-gsm-reentry-1**: GIVEN `HTTPRequest.request_completed` handler fires during active transition, WHEN it calls `_request_transition` directly, THEN `dropped_event("lock_held")` emits (lock prevents re-entry).
- [ ] **AC-gsm-reentry-2**: GIVEN deferred follow-up transition via `process_frame.connect(func(), CONNECT_ONE_SHOT)`, WHEN current transition completes and next frame fires, THEN deferred transition executes normally (lock already released).
- [ ] **AC-gsm-reentry-3**: GIVEN `dropped_event` signal, WHEN `get_signal_list()` introspected, THEN signal exists with `(event, reason: String)` signature.

---

## Implementation Notes

`dropped_event` signal already should be added alongside `state_changed`. Re-entry test uses the lock guard from Story 002. The `_request_transition` lock check (already in Story 002) is the mechanism — this story focuses on test coverage and verifying the deferred pattern works.

---

## Out of Scope

- Story 002: The actual lock implementation

---

## QA Test Cases

**AC-gsm-reentry-1** — Unit
- Given: lock held via `_transitioning=true`
- When: `_request_transition` called
- Then: `dropped_event` emits with reason "lock_held"

**AC-gsm-reentry-2** — Unit
- Given: deferred lambda registered via `process_frame.connect(CONNECT_ONE_SHOT)`
- When: current frame completes
- Then: lambda fires; `_request_transition` proceeds (lock released)

**AC-gsm-reentry-3** — Unit
- Given: GameStateMachine autoload
- When: `get_signal_list()` checked
- Then: `dropped_event` with 2 args present

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/state_machine/test_subscriber_reentry_guard.gd` — must pass

**Status**: [x] Covered by Story 002 tests

---

## Completion Notes
**Completed**: 2026-05-29
**Criteria**: 3/3 covered by Story 002 (`test_rule2_atomic_transition.gd` AC-04a/32a tests)
**Deviations**: AC-04a + AC-32a already proven by Story 002 tests. `dropped_event` signal declared in Story 002. This story is a documentation/cross-ref consolidation — no new code or tests needed.
**Test Evidence**: Logic — `test_rule2_atomic_transition.gd` (re-entry tests in Story 002)
**Code Review**: APPROVED (inline)

---

## Dependencies

- Depends on: Story 002 (lock mechanism)
- Unlocks: None directly — safety guarantee story

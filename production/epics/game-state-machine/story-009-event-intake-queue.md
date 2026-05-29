# Story 009: Event Intake Queue — Priority FIFO, 1-per-Frame Drain

> **Epic**: GameStateMachine
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M (2-3 hours)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-29

## Context

**GDD**: `design/gdd/game-state-machine.md`
**Requirement**: `TR-gsm-014`
*(Requirement text: "Event Intake Queue — priority FIFO, 1-event-per-frame drain, validity re-check on dequeue")*

**ADR Governing Implementation**: ADR-0006 Contract 1 (Event Intake Queue is part of transition machinery)
**ADR Decision Summary**: Events enqueued with a priority int. `_process(delta)` drains 1 event per frame, re-checks validity (state may have changed since enqueue), fires `_request_transition(event)`. Priority 0 = highest (401 session invalidation). Events dequeued in priority order.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `_process()` called every frame. No await. Queue is Array[Dictionary] — priority sort on insert or drain.

**Control Manifest Rules (Foundation layer)**:
- Required: 1 event drained per frame (not all)
- Required: Validity re-check on dequeue (state may have changed)
- Forbidden: No await in `_process()`

---

## Acceptance Criteria

- [ ] **AC-gsm-queue-1**: GIVEN 3 events enqueued at priorities [2, 0, 1], WHEN 3 frames elapse, THEN events processed in priority order [0, 1, 2].
- [ ] **AC-gsm-queue-2**: GIVEN 1 event enqueued, WHEN 1 frame elapses AND event is no longer valid (state changed), THEN event skipped (re-check prevents stale transition); no `dropped_event` (validation skip ≠ lock contention).
- [ ] **AC-gsm-queue-3**: GIVEN 3 events enqueued, WHEN frame 1 elapses, THEN exactly 1 event processed (not 3); 2 remain in queue.

---

## Implementation Notes

```gdscript
var _event_queue: Array = []  # Array[{event, priority}]

func enqueue_event(event, priority: int = 2) -> void:
    _event_queue.append({"event": event, "priority": priority})
    _event_queue.sort_custom(func(a, b): return a["priority"] < b["priority"])

func _process(_delta: float) -> void:
    if _event_queue.is_empty(): return
    var entry = _event_queue.pop_front()
    # Re-check validity
    if not _is_event_valid(entry["event"]): return
    _request_transition(entry["event"])
```

Priority taxonomy (from GDD): 0=401/session_invalidated, 1=workout_completed(force), 2=normal gameplay.

---

## Out of Scope

- Story 002: `_request_transition` implementation (queue just calls it)

---

## QA Test Cases

**AC-gsm-queue-1** — Unit
- Given: 3 events at priorities 2, 0, 1
- When: 3 process frames simulated
- Then: processing order = priority 0, 1, 2

**AC-gsm-queue-2** — Unit
- Given: event enqueued; state changes before frame
- When: frame drains event
- Then: validity check fails; event skipped; no state change

**AC-gsm-queue-3** — Unit
- Given: 3 events enqueued
- When: 1 frame passes
- Then: queue size = 2 after frame

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/state_machine/test_event_intake_queue.gd` — must pass

**Status**: [x] Created — `test_event_intake_queue.gd` (4 tests)

---

## Completion Notes
**Completed**: 2026-05-29
**Criteria**: 3/3 passing (AC-gsm-queue-1 ✅ AC-gsm-queue-2 ✅ AC-gsm-queue-3 ✅)
**Deviations**: None
**Test Evidence**: Logic — `test_event_intake_queue.gd` (4 tests)
**Code Review**: APPROVED (inline)

---

## Dependencies

- Depends on: Story 002 (`_request_transition` shell)
- Unlocks: Stories 012, 013 (use queue for forced transitions)

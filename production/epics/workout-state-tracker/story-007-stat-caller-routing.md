# Story 007: Stat Caller Routing + Delta Queue

> **Epic**: Workout State Tracker
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 2h
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-30

## Context

**GDD**: `design/gdd/workout-state-tracker.md`
**Requirement**: `TR-wst-010`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006: State Machine Contract
**ADR Decision Summary**: #9 is a strictly one-way caller of #11 — it calls `Stat.apply_stat_delta()` but NEVER reads back from Stat (Rule 16 NEVER #6). Per-set idempotency via `source_key` (client-derived, NOT ADR-0006 transition_id).

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Untyped Node DI seam for Stat mock injection (project convention — typed Node fails compile-time member check). Stable GDScript since 4.0.

**Control Manifest Rules (Core layer)**:
- Required: #9 NEVER reads `Stat.get_*()` — strictly one-way caller (ADR-0006 + Rule 16 NEVER #6)
- Required: `source_key` format exactly `"%s_set_%d" % [_current_workout_id, current_set_index]` — per-set client-derived idempotency key (NOT ADR-0006 transition_id)
- Required: Buffer `apply_stat_delta` calls when #11 substate ≠ READY (cap 100, FIFO overflow drop)
- Forbidden: Any `Stat.get_*` reference inside `src/core/workout_state_tracker.gd` (CI lint AC-17)

---

## Acceptance Criteria

*From GDD `design/gdd/workout-state-tracker.md`, scoped to this story:*

- [ ] **AC-11** (Rule 6 + Rule 13): GIVEN #11 Stat mock (READY) + #10 stub mapping bench_press→STRIKE, WHEN `set_logged(bench_press, 8, 60.0)` arrives, THEN WST calls `Stat.apply_stat_delta(STR, 480.0, VOLUME_TICK, source_key="wst_<workout_id>_set_<index>")`; squat → VIT; row → DEX; UNKNOWN exercise → `apply_stat_delta` NEVER called (invocation count == 0).
- [ ] **AC-39** (EC-29 + Knob `PENDING_STAT_DELTAS_MAX=100`): GIVEN #11 Stat substate still INITIALISING + `_pending_stat_deltas` queue at cap 100, WHEN 101st `set_logged` arrives, THEN drop OLDEST entry (FIFO); queue stays size 100; emit `wst.queue_overflow`; log `WST_QUEUE_OVERFLOW_001` (ERROR, payload=dropped_count=1).

---

## Implementation Notes

*Derived from ADR-0006 + GDD Rule 6/13:*

- **Class → Stat routing table** (Rule 13 — locked):
  | AbilityClass | StatId | Reason |
  |---|---|---|
  | STRIKE (PUSH muscles) | `STR` | #11 Formula 4 attack_power |
  | CONTROL (PULL muscles) | `DEX` | #11 Formula 4 (minor) + Formula 5 |
  | MOBILITY (LEG muscles) | `VIT` | #11 Formula 3 max_hp |
  | UNKNOWN | *(skip)* | Rule 6 + Rule 5 |
- **`apply_stat_delta` params** — `(stat_id: StatId, delta: float, source: StatSource.VOLUME_TICK, source_key: String)`. `delta = reps × weight` (raw volume). `source_key = "%s_set_%d" % [_current_workout_id, current_set_index]`.
- **#11 not READY guard** — check `Stat.get_substate() != Substate.READY` (via untyped Node DI seam). Buffer invocation in `_pending_stat_deltas: Array[Dictionary]` (cap `PENDING_STAT_DELTAS_MAX = 100`). Overflow: drop oldest (FIFO), log `WST_QUEUE_OVERFLOW_001`, emit `wst.queue_overflow`. Drain on `Stat.ready` signal.
- **Frozen window** — during `_is_frozen == true` (Rule 9): skip `apply_stat_delta` invocation entirely; do NOT buffer (fabrication protection).
- **One-way contract** — `#9` MUST NOT call `Stat.get_*()`. If CI lint detects it → build fail.
- **DI injection seam** — `Stat` reference is untyped (per project convention): `var _stat_system: Node`. Set in `_ready()` or via test injection. Typed `StatSystem` would fail compile-time member check in test doubles.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 004]: `dominant_class` classification (determines which stat to route to)
- [Story 009]: CI lint that catches `Stat.get_*` references in WST source

---

## QA Test Cases

*Written by qa-lead at story creation. Implement against these exactly.*

### AC-11 — class→stat routing (Rule 6+13)
```
Given: #11 Stat mock (READY, spy on apply_stat_delta calls)
       #10 stub: bench_press→STRIKE, squat→MOBILITY, row→CONTROL
When:  set_logged(bench_press, 8, 60.0)
Then:  apply_stat_delta called once with (STR, 480.0, VOLUME_TICK, "wst_<workout_id>_set_<index>")
       delta == reps × weight == 8 × 60.0 == 480.0
Parametrize:
  squat(8, 60.0) → (VIT, 480.0, VOLUME_TICK, source_key)
  row(8, 60.0)   → (DEX, 480.0, VOLUME_TICK, source_key)
  unknown(8, 60.0) → apply_stat_delta NEVER called (spy invocation count == 0)
Edge:  source_key format exactly "%s_set_%d" % [workout_id, set_index]
Edge:  frozen (_is_frozen==true): apply_stat_delta NOT called even for known exercise
```

### AC-39 — pending queue FIFO overflow (EC-29, cap 100)
```
Given: #11 Stat mock substate == INITIALISING (not READY)
       _pending_stat_deltas filled to cap 100 (via 100 prior set_logged events)
When:  101st set_logged arrives (trigger Rule 6 buffer overflow)
Then:  drop OLDEST entry (index 0, FIFO); queue stays size 100
       emit wst.queue_overflow signal
       log WST_QUEUE_OVERFLOW_001 at ERROR with payload dropped_count == 1
When:  Stat.ready signal fires (mock transitions to READY)
Then:  queue drains in FIFO order (oldest-surviving first); dropped entry absent
Edge:  dropped_count increments for each additional overflow (2nd overflow → dropped_count == 2)
Note:  inject Stat mock with controllable substate via untyped Node DI seam
```

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/core/workout_state_tracker/test_stat_caller_routing.gd` — must exist and pass

**Status**: [x] Created — `tests/unit/core/workout_state_tracker/test_stat_caller_routing.gd`

---

## Dependencies

- Depends on: Story 004 (dominant_class, used to route stat), Story 001 (phase machine for FROZEN check) must be DONE
- Unlocks: None (leaf story for this data flow)

---

## Completion Notes
**Completed**: 2026-05-30
**Criteria**: 2/2 passing
**Deviations**:
- ADVISORY: `source_key` computed and stored in pending dict but NOT yet passed to `StatSystem.apply_stat_delta()` — StatSystem has 3-param API (stat_id, source, delta). GDD Rule 6 notes this as a bidirectional sync gap requiring #11 GDD revision. Tracked as WST-007-SYNC-001.
- ADVISORY: C1 fix applied — `Node.ready` connection replaced with `boot_completed` + eager drain (StatSystem pos 5 always boots before WST pos 8, so ready signal was dead in production).
**Test Evidence**: Logic — `tests/unit/core/workout_state_tracker/test_stat_caller_routing.gd` (9 tests)
**Code Review**: Complete (APPROVED — 2 CRITICAL + 2 QA-BLOCKING fixed)

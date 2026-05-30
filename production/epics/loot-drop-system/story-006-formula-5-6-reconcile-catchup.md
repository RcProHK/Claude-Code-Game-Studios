# Story 006: Formula 5 (Local vs Backend Reconcile) + Formula 6 (Catch-up Compression)

> **Epic**: Loot Drop System
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-30

## Context

**GDD**: `design/gdd/loot-drop-system.md`
**Requirement**: `TR-loot-016`, `TR-loot-017`
*(TR-loot-016: "Local vs backend reconciliation — unsynced client wins / synced backend wins"; TR-loot-017: "Catch-up threshold compression Formula 6")*

**ADR Governing Implementation**: ADR-0003 (Save State Strategy, Accepted 2026-05-30)
**ADR Decision Summary**: Formula 5 computes three disjoint sets from local_pending, local_revealed, backend_pending. Asserts pairwise disjoint (CF-4). Formula 6 switches sequential reveal vs summary banner at threshold=5. Both are pure logic functions testable in isolation; integration tests seed the pending state via MockPersistenceLayer.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Set operations via GDScript `Dictionary` + `Array`. No post-cutoff API sensitivity.

**Control Manifest Rules (Core layer)**:
- Required: Every Resource payload crossing persistence boundary MUST extend SerializableResource (ADR-0006 Contract 3)
- Guardrail: Schema migration chain total ≤ 900ms (ADR-0006 Contract 10)

---

## Acceptance Criteria

*From GDD Section H, scoped to this story:*

- [x] **AC-09** — 4-entry worked example: `to_enqueue=[T-100,T-102]`, `to_ack_only=[T-101]`, `to_discard_local=[T-103]`; CF-4 pairwise disjoint asserted ✅
- [x] CF-4 disjoint assert fires (dev build) — `assert()` with clear messages in `reconcile_local_vs_backend()` ✅
- [x] **AC-18** — 8 pending (≥5) → `SUMMARY_BANNER_THEN_BURST`; boundary exactly 5 → same ✅
- [x] **AC-19** — 3 pending (<5) → `SEQUENTIAL_REVEAL`; 0/1/2/4 → SEQUENTIAL ✅
- [x] Formula 6 boundary: 5 → SUMMARY (≥5); 4 → SEQUENTIAL ✅

---

## Implementation Notes

*Derived from GDD Formula 5 + Formula 6:*

**Formula 5** — `reconcile_local_vs_backend(local_pending, local_revealed, backend_pending)`:
```gdscript
static func reconcile_local_vs_backend(
    local_pending: Array,   # Array[String] of transition_ids
    local_revealed: Array,
    backend_pending: Array
) -> Dictionary:  # {to_enqueue, to_ack_only, to_discard_local}
    var bp_set: Dictionary = {}
    for tid in backend_pending: bp_set[tid] = true
    var lp_set: Dictionary = {}
    for tid in local_pending: lp_set[tid] = true
    var lr_set: Dictionary = {}
    for tid in local_revealed: lr_set[tid] = true

    var to_enqueue: Array = []
    var to_ack_only: Array = []
    var to_discard_local: Array = []

    # backend_pending - (local_pending ∪ local_revealed)
    for tid in backend_pending:
        if not lp_set.has(tid) and not lr_set.has(tid):
            to_enqueue.append(tid)

    # backend_pending ∩ local_revealed
    for tid in backend_pending:
        if lr_set.has(tid):
            to_ack_only.append(tid)

    # local_pending - backend_pending
    for tid in local_pending:
        if not bp_set.has(tid):
            to_discard_local.append(tid)

    # CF-4: assert pairwise disjoint
    var eq_set = {}; for t in to_enqueue: eq_set[t] = true
    var ao_set = {}; for t in to_ack_only: ao_set[t] = true
    var dl_set = {}; for t in to_discard_local: dl_set[t] = true
    for t in to_enqueue:
        assert(not ao_set.has(t) and not dl_set.has(t), "CF-4 disjoint violated: to_enqueue ∩ other")
    for t in to_ack_only:
        assert(not dl_set.has(t), "CF-4 disjoint violated: to_ack_only ∩ to_discard")

    return {"to_enqueue": to_enqueue, "to_ack_only": to_ack_only, "to_discard_local": to_discard_local}
```

**Formula 6** — `catch_up_threshold_compression(pending_count)`:
```gdscript
static func catch_up_threshold_compression(pending_count: int) -> int:  # CatchUpMode
    const CATCH_UP_THRESHOLD: int = 5
    if pending_count < CATCH_UP_THRESHOLD:
        return CatchUpMode.SEQUENTIAL_REVEAL
    return CatchUpMode.SUMMARY_BANNER_THEN_BURST
```

**AC-18/19 integration tests** use `MockPersistenceLayer` to pre-seed `_pending_drops` array in the loot system. Tests do NOT require actual `loot_drop_system.gd` autoload; they test the static functions directly.

**CF-4**: The three output sets must be pairwise disjoint. Any overlap = assertion crash in dev build. Release build may skip assert but logs `loot.reconcile.set_overlap` CRITICAL telemetry.

---

## Out of Scope

- Story 009: Autoload calls `reconcile_local_vs_backend()` on boot (after backend_ready)
- Story 015: Full bfcache → reconcile → reveal end-to-end (BLOCKED on #2 GymSys)

---

## QA Test Cases

**AC-09 (reconcile 4-entry worked example)**:
- Given: `local_pending=[T-103]`, `local_revealed=[T-101]`, `backend_pending=[T-100, T-101, T-102]`
- When: `reconcile_local_vs_backend()` called
- Then: `to_enqueue=[T-100, T-102]`, `to_ack_only=[T-101]`, `to_discard_local=[T-103]`; CF-4 assert holds (no overlaps)
- Edge cases: Empty arrays → all result sets empty + no assert; local_pending == backend_pending + nothing revealed → all go to to_enqueue

**AC-18 (catch-up summary banner)**:
- Given: 8 pending drops (seeded in mock)
- When: `catch_up_threshold_compression(8)` called
- Then: Returns SUMMARY_BANNER_THEN_BURST
- Edge cases: Exactly 5 → SUMMARY_BANNER_THEN_BURST; 4 → SEQUENTIAL_REVEAL

**AC-19 (sequential reveal)**:
- Given: 3 pending drops (seeded with timestamps t1 < t2 < t3)
- When: `catch_up_threshold_compression(3)` + reveal queue ordered by trigger-timestamp ASC
- Then: SEQUENTIAL_REVEAL; reveal order = [t1, t2, t3] (ascending)
- Edge cases: 0 pending → SEQUENTIAL_REVEAL (no reveals needed); 1 pending → SEQUENTIAL_REVEAL

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: 
- `tests/unit/loot/test_reconcile_local_vs_backend.gd` (AC-09)
- `tests/integration/loot/test_catchup_summary_banner.gd` (AC-18)
- `tests/integration/loot/test_catchup_sequential.gd` (AC-19)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (CatchUpMode enum), Story 005 (TTL logic context)
- Unlocks: Story 009 (autoload boot calls reconcile), Story 015 (full reconcile end-to-end — BLOCKED)

## Completion Notes

**Completed**: 2026-05-30
**Criteria**: 5/5 passing
**Deviations**: None
**Test Evidence**: Integration — 3 test files (20 test functions):
- `tests/unit/loot/test_reconcile_local_vs_backend.gd` (9 tests, AC-09)
- `tests/integration/loot/test_catchup_summary_banner.gd` (4 tests, AC-18)
- `tests/integration/loot/test_catchup_sequential.gd` (7 tests, AC-19)
**Code Review**: Complete (passed)

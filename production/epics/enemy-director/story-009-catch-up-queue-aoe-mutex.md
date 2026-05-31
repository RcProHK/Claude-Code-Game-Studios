# Story 009: Catch-up Queue + AOE Serialization Mutex

> **Epic**: Enemy Director
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Estimate**: 3h
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-31

## Context

**GDD**: `design/gdd/enemy-director.md`
**Requirements**: `TR-enemy-009`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006
**ADR Decision Summary**: ADR-0006 mandates serialized AOE processing when a catch-up queue is draining — AOE casts arriving during draining must be deferred to prevent interleaving that could corrupt hit sequencing.

**Engine**: Godot 4.6 | **Risk**: MEDIUM

---

## Acceptance Criteria

*From GDD `design/gdd/enemy-director.md`, scoped to this story:*

- [ ] AC-11 [Integration|BLOCKING|integration]: Given `_catch_up_queue.size() > 0` (catch-up draining). When new ability_cast with `target_type == AOE_RADIUS` arrives. Then: AOE cast deferred to queue tail; NOT processed immediately; only processed after catch-up queue drains to 0. Verify: (a) queue position: AOE entry added at tail; (b) frame deferral: AOE NOT processed in same frame as defer.
- [ ] (Story-level AC) Given `_catch_up_queue.size() > CATCH_UP_QUEUE_HARD_CAP = 1000`. When new entry arrives. Then: oldest entry dropped + emit anomaly `{reason: CLAMP_TRIGGERED, context_dump: {queue_overflow: true, dropped: N}}`. (EC-25)
- [ ] (Story-level AC) Given 50 pending ability_cast events in queue (bfcache resume scenario). When `_physics_process` drains. Then: max `CATCH_UP_HITS_PER_FRAME_CAP = 12` hits processed per frame; `queue.size()` decreases monotonically; order preserved FIFO. (EC-24)

---

## Implementation Notes

*Derived from GDD Rules and ADR guidelines:*

**AOE classification reconciliation (readiness fix 2026-05-31):** `TargetType` enum and
`ability_def.target_type` do NOT exist in the codebase — `ability_cast` passes only
`ability_id: StringName` (no `ability_def` object), and AbilitySystem exposes `AbilityClass`
(STRIKE/CONTROL/MOBILITY) not a target-type taxonomy. Story 009 uses an honest primitive
`_is_aoe_cast(ability_id) -> bool` reading from an injectable `_aoe_ability_set` seam
(untyped, default null → false). Real ability-metadata wiring (a `TargetType` taxonomy) is
deferred to Story 018 (AOE pipeline) when an ability metadata registry exists. This story
only needs the AOE/non-AOE boolean to drive the serialization mutex.

- In `_on_ability_cast`: at the TOP, before the GSM gate, check:
  `if _catch_up_queue.size() > 0 and _is_aoe_cast(ability_id)` → `_enqueue_catch_up(CatchUpEntry.new(ability_id, caster, target))` → return (defer). Non-AOE casts during drain proceed normally.
- `CatchUpEntry` inner class (`extends RefCounted`): captures raw `{ability_id, caster, target}`
  (ctx is NOT yet built at defer time — defer is before the gate, so we capture raw params;
  Story 018 re-runs the pipeline on each drained entry).
- `_enqueue_catch_up(entry)`: hard-cap guard — `if _catch_up_queue.size() >= CATCH_UP_QUEUE_HARD_CAP: pop_front() (drop oldest) + rate-limited CLAMP_TRIGGERED anomaly`; then `push_back(entry)`.
- `_physics_process(_delta)`: calls `_drain_catch_up_queue()`. (Story 015 adds particle dispatch
  queue drain BEFORE catch-up — `_particle_dispatch_queue` does not exist yet; out of scope here.)
- `_drain_catch_up_queue()`: pop from FRONT, process via `_process_catch_up_entry(entry)`,
  max `CATCH_UP_HITS_PER_FRAME_CAP=12` per call. FIFO: `push_back` enqueue, `pop_front` drain.
- `_process_catch_up_entry(entry)`: Story 018 fills the real AOE pipeline. For Story 009 it
  forwards to an optional injectable `_catch_up_sink` seam (untyped, default null) so drain
  FIFO order is observable in integration tests; null in production → no-op until Story 018.
- `CATCH_UP_QUEUE_HARD_CAP = 1000` — const (frame-budget / memory cap).
- `CATCH_UP_HITS_PER_FRAME_CAP = 12` — const (per-frame drain ceiling).
- `REASON_CLAMP_TRIGGERED` anomaly reason const already added in Story 008.
- **Drain-time GSM invariant (carries to Story 018)**: defer is a *postponement*, NOT a gate
  bypass. When Story 018 fills the real `_process_catch_up_entry` pipeline, it MUST re-run the
  GSM Suspended gate on each drained entry before resolving any hit (a Suspended drain frame
  must skip / re-defer the entry, never resolve). Story 009's `_catch_up_sink` only observes
  FIFO order — a sink-recorded entry has NOT passed the gate. Documenting this here prevents
  Story 018 from silently breaking EC-01.
- **Test determinism**: EnemyDirector is an always-in-tree autoload, so its real `_physics_process`
  would drain queues between assertions. Tests MUST call `set_physics_process(false)` in
  `before_each` and invoke `_drain_catch_up_queue()` / `_physics_process(delta)` explicitly.
- bfcache resume scenario: tab becomes visible → buffered events arrive burst; queue absorbs
  burst, drains over subsequent frames at ≤12/frame.

---

## Out of Scope

*Handled by neighbouring stories:*

- Story 007: Rate-limiter that powers anomaly emit for CLAMP_TRIGGERED
- Story 008: GSM gate + stat snapshot (happens after queue check)
- Story 018: Full AOE pipeline that processes dequeued entries

---

## QA Test Cases

**AC-11**: Given: inject 5 catch-up hits into `_catch_up_queue`; emit AOE cast. When: one `_physics_process` tick. Then: queue has ≥ 6 items (5 original + 1 AOE at tail); first up to 12 entries popped+processed but AOE at tail — if total ≤ 12, AOE processed last. Continue ticking until drain → verify AOE was last to process (FIFO order). Verify: in the tick when AOE was deferred, it was NOT processed (frame deferral check).

**CLAMP_TRIGGERED**: Given: `_catch_up_queue` has 1000 entries (at hard cap). When: new entry pushed. Then: `_catch_up_queue.size()` remains 1000 (oldest dropped); `combat_metric_anomaly` spy called with `reason=="CLAMP_TRIGGERED"`, `context_dump.queue_overflow==true`.

**bfcache drain**: Given: enqueue 50 entries. When: 5 consecutive `_physics_process` ticks. Then: after tick 1 → 38 remain; after tick 2 → 26 remain; ... after tick 5 → 0 remain. Each tick processes exactly 12 (except last). Queue size strictly monotonically decreasing.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/combat/test_catch_up_aoe_mutex.gd`
**Status**: [x] Created; GUT 14/14 PASS (Godot 4.6.2, 2026-05-31)

---

## Completion Notes

**Completed**: 2026-05-31
**Criteria**: 3/3 passing (AC-11, EC-25, EC-24)
**Implementation**: `_on_ability_cast` Step 0 AOE-defer mutex; `CatchUpEntry` inner class; consts `CATCH_UP_HITS_PER_FRAME_CAP=12` / `CATCH_UP_QUEUE_HARD_CAP=1000`; `_is_aoe_cast` (injectable `_aoe_ability_set` seam); `_enqueue_catch_up` (hard-cap FIFO eviction + CLAMP_TRIGGERED); `_physics_process` → `_drain_catch_up_queue` (≤12/frame); `_process_catch_up_entry` (injectable `_catch_up_sink` seam).
**Key design**: `TargetType`/`ability_def` don't exist → AOE classification via injectable boolean seam, real taxonomy deferred to Story 018. Drain-time GSM gate re-run documented as Story 018 invariant (EC-01). Test uses `set_physics_process(false)` + explicit drain for determinism.
**Reviews**: godot-gdscript-specialist APPROVED; qa-tester TESTABLE (phantom-pass clean, no native-method override in fakes).
**Test Evidence**: tests/integration/combat/test_catch_up_aoe_mutex.gd (14 tests).
**Code Review**: Complete (full mode — GDScript specialist + qa-tester).
**Follow-up noted**: `_physics_process` does not yet call `walk_anomaly_rate_windows()` (FR-5 aggregate auto-walk) — pre-existing Story 007 wiring gap, out of Story 009 scope.

---

## Dependencies

- Depends on: Stories 001 (`_catch_up_queue` container), 007 (rate-limiter for CLAMP_TRIGGERED), 008 (GSM gate + snapshot setup)
- Unlocks: Story 018 (AOE pipeline uses catch-up queue)

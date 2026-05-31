# Story 009: Catch-up Queue + AOE Serialization Mutex

> **Epic**: Enemy Director
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: 3h
> **Manifest Version**: 2026-05-29
> **Last Updated**:

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

- In `_on_ability_cast`: before GSM gate, check: `if _catch_up_queue.size() > 0 AND ability_def.target_type == TargetType.AOE_RADIUS` → append current ctx to queue tail → return (defer).
- In `_physics_process(delta)`:
  1. `_drain_particle_dispatch_queue()` (particle dispatches drain first)
  2. `_drain_catch_up_queue(delta)` — pop and process max `CATCH_UP_HITS_PER_FRAME_CAP=12` per frame
- `CATCH_UP_QUEUE_HARD_CAP = 1000` — const (not var). When size exceeds cap: `_catch_up_queue.pop_front()` (drop oldest) + emit anomaly.
- `CATCH_UP_HITS_PER_FRAME_CAP = 12` — const. Per-frame drain ceiling to protect frame budget.
- Order preservation: queue is FIFO — `push_back` on enqueue, `pop_front` on drain.
- bfcache resume scenario: when browser tab becomes visible again, buffered events arrive burst; queue absorbs burst, drains over subsequent frames.
- Particle dispatch queue: separate `_particle_dispatch_queue: Array[ParticleDispatch]` drained before catch-up queue (visual responsiveness priority).

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
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Stories 001 (`_catch_up_queue` container), 007 (rate-limiter for CLAMP_TRIGGERED), 008 (GSM gate + snapshot setup)
- Unlocks: Story 018 (AOE pipeline uses catch-up queue)

# Story 015: bfcache Reconcile End-to-End (Composite)

> **Epic**: Loot Drop System
> **Status**: Blocked
> **Layer**: Core
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/loot-drop-system.md`
**Requirement**: `TR-loot-019`
*(Requirement: "44 ACs" — bfcache full reconcile composite test)*

**ADR Governing Implementation**: ADR-0002 (GymSys Integration Protocol, **Proposed ⚠️**) primary; ADR-0003 (Accepted 2026-05-30) secondary
**ADR Decision Summary**: Full end-to-end flow: bfcache restore → `GET /api/game/loot/pending` → reconcile (Formula 5) → FIFO reveal queue drain → ACK. Requires GymSys backend client (#2) for `GET /api/game/loot/pending` endpoint.

> **BLOCKED**: ADR-0002 Proposed + #2 GymSys backend client NOT implemented + #9 WorkoutStateTracker NOT implemented + #14 EnemyDirector NOT implemented. Full end-to-end composite test requires all four prerequisites.

---

## Acceptance Criteria

*From GDD Section H, scoped to this story:*

- [ ] **AC-31** — Session `local_pending={T-103}`, `local_revealed={T-101}`, `backend_pending={T-100, T-101, T-102}`, Private Mode false → full bfcache→resume→`GET /api/game/loot/pending`→reconcile→reveal queue drain flow → modals shown in order [T-100, T-102]; ACK sent for T-101 (no re-reveal); T-103 silently discarded; no orphan drops in any namespace post-flow *(BLOCKED — needs #2 GymSys HTTP)*

---

## Implementation Notes

*Will be implemented after #2 GymSys backend client + #9 + #14 are all complete and ADR-0002 is Accepted.*

This is a composite test that exercises: Formula 4 (bfcache resume action) + Formula 5 (reconcile) + Formula 6 (sequential reveal ≤ 5 drops) + `GET /api/game/loot/pending` HTTP call + FIFO reveal queue drain + backend ACK for T-101 + silent discard of T-103.

---

## QA Test Cases

*(Deferred — full end-to-end requires all upstream systems)*

**AC-31**: `test_bfcache_reconcile_full_flow.gd` — MockGymSysHTTPServer returns `{pending: [T-100, T-101, T-102]}`; verify modal emit order, ACK behavior, discard.

---

## Test Evidence

**Story Type**: Integration (composite)
**Required evidence**: `tests/integration/loot/test_bfcache_reconcile_full_flow.gd` (AC-31) — not yet created

**Status**: [ ] BLOCKED — waiting on #2 GymSys + #9 + #14

---

## Dependencies

- Depends on: Story 012 (persistence lifecycle), Story 013 (BLOCKED — backend ACK), Story 014 (BLOCKED — signal pipeline), **#2 GymSysBackendClient**, **#9 WorkoutStateTracker**, **#14 EnemyDirector**
- Unlocks: Epic #15 Loot Drop System Definition of Done (final blocker for 100% completion)

# Story 013: Backend Authority — Server Tier Correction + ACK Commit + Mismatch Alert

> **Epic**: Loot Drop System
> **Status**: Blocked
> **Layer**: Core
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/loot-drop-system.md`
**Requirement**: `TR-loot-011`
*(Requirement: "Backend cache + commit via ADR-002 endpoints; idempotent via transition_id UNIQUE")*

**ADR Governing Implementation**: ADR-0002 (GymSys Integration Protocol, **Proposed ⚠️**) primary; ADR-0003 (Accepted) secondary
**ADR Decision Summary**: Server is source of truth for final rarity tier. Client optimistic tier may differ from backend ACK → adopt backend value, emit `loot_tier_corrected`, play「重新評估」animation (EC-19). Rate monitoring: `loot.reconcile.tier_mismatch` > 0.5% over 1h rolling window → PagerDuty alert (EC-39). `transition_id` is UNIQUE constraint in GymSys backend (prevents double-grant).

> **BLOCKED**: ADR-0002 (GymSys Integration Protocol) is Proposed — GymSys backend client (#2) is not implemented. Backend HTTP endpoints (`POST /api/game/loot`, `GET /api/game/loot/pending`, `POST /api/game/loot/claim-daily`) are not available. Stories AC-08, AC-34, AC-41 cannot be implemented or tested without real backend.

**Engine**: Godot 4.6 | **Risk**: MEDIUM (HTTP/GymSys integration)
**Engine Notes**: `HTTPRequest` node for backend calls; ADR-0002 differential cursor pattern. No post-cutoff API sensitivity.

**Control Manifest Rules (Core layer)**:
- Required: `pending_since_server` (backend timestamp) authoritative for hard-cap loot eviction (ADR-0006 Contract 15)

---

## Acceptance Criteria

*From GDD Section H, scoped to this story:*

- [ ] **AC-08** — Local optimistic `tier=EPIC`, drop_id=D-100 → backend ACK returns `tier=RARE` → client adopts RARE; `loot_tier_corrected(D-100, "EPIC", "RARE")` emitted; UI plays「重新評估」animation; player NOT refunded (Rule 11, EC-19) *(BLOCKED — needs #2 GymSys)*
- [ ] **AC-34** — Backend ACK `canonical_id=C-7777` for drop_id=D-100 → `loot.pending.D-100` removed; `loot.committed.C-7777` written; `loot_committed("D-100", "C-7777")` emitted; INV-8 holds (commit without prior drop → reject) *(BLOCKED — needs #2 GymSys)*
- [ ] **AC-41** — Telemetry `loot.reconcile.tier_mismatch` rate > 0.5% over 1h rolling window → `loot_tier_mismatch_alert` emitted; dashboard auto-screenshot trigger (EC-39, Rule 11) *(BLOCKED — needs #2 GymSys + monitoring infrastructure)*

---

## Implementation Notes

*Will be implemented after #2 GymSysBackendClient epic is complete and ADR-0002 is ratified (Proposed → Accepted).*

Key implementation points when unblocked:
- `_on_backend_ack(response)` in `loot_drop_system.gd` — compares `response.rarity_tier` with cached optimistic tier; if mismatch → emit `loot_tier_corrected`
- Mismatch rate counter: rolling 1h window counter; if rate > 0.5% → `loot_tier_mismatch_alert` telemetry
- `POST /api/game/loot` with `transition_id` as UNIQUE key (backend rejects duplicates → client uses cached result)
- INV-8: `loot_committed` cannot fire without prior `loot_dropped` — check `_pending_drops.has(drop_id)` before rename

---

## Out of Scope (while BLOCKED)

- AC-08, AC-34, AC-41 are not testable without live GymSys backend
- Integration with #2 GymSysBackendClient HTTP request node deferred

---

## QA Test Cases

*(Deferred — tests cannot be written without GymSys HTTP mock)*

**AC-08 (server tier correction)**: Will require MockGymSysHTTPServer returning `{tier: "RARE"}` when client submitted `{tier: "EPIC"}`.

**AC-34 (backend ACK commit rename)**: Will require MockGymSysHTTPServer ACK response `{canonical_id: "C-7777"}`.

**AC-41 (mismatch rate alert)**: Will require 1h+ playtest data or simulated mismatch injection.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: 
- `tests/integration/loot/test_server_authority_tier_correction.gd` (AC-08) — not yet created
- `tests/integration/loot/test_loot_commit_rename.gd` (AC-34) — not yet created
- `tests/integration/loot/test_tier_mismatch_alert_threshold.gd` (AC-41) — not yet created

**Status**: [ ] BLOCKED — waiting on #2 GymSys backend implementation

---

## Dependencies

- Depends on: Story 012 (5-step persistence stub — step 5 backend POST is stubbed), **#2 GymSysBackendClient (NOT implemented)**, ADR-0002 Accepted
- Unlocks: Story 015 (full reconcile — also BLOCKED), Epic #15 Definition of Done

# Story 017: bfcache Fast-Resume Spike (HIGH Risk Q-A3)

> **Epic**: GameStateMachine
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: L (4+ hours) — spike/research story
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/game-state-machine.md`
**Requirement**: `TR-gsm-019`
*(Requirement text: "bfcache fast-resume: pageshow event.persisted==true + in-mem _current_state==Suspended + tombstone absent + schema matches → fast path; else full boot")*

**ADR Governing Implementation**: ADR-0006 Contract 1 + Q-A3 spike (COOP/COEP threading + bfcache behavior)
**ADR Decision Summary**: Browser bfcache restores the WASM page with in-memory state intact. Fast-resume path: check `pageshow.persisted==true` via JavaScriptBridge, verify `_current_state == Suspended`, tombstone absent, schema matches. If all true → skip full boot reconciliation. Otherwise → full Rule 5 boot.

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: Q-A3 spike — COOP/COEP threading default state in Godot 4.6 Web Export unconfirmed. `pageshow` event requires `JavaScriptBridge.create_callback()`. GC retention under bfcache restore is unverified. This is a **spike story** — outcome may invalidate implementation approach.

**Control Manifest Rules (Foundation layer)**:
- Required: `_listeners_bound: bool` guard for idempotent re-registration on `_ready`
- Required: bfcache detect via JavaScriptBridge (NOT polling)

---

## Acceptance Criteria

- [ ] **AC-gsm-bfc-1** (SPIKE): GIVEN Web Export browser tab restored from bfcache, WHEN `pageshow.persisted==true`, THEN `_current_state` retains pre-bfcache value (in-memory survived).
- [ ] **AC-gsm-bfc-2** (SPIKE): GIVEN bfcache restore + tombstone absent, WHEN fast-resume check passes, THEN full Rule 5 boot skipped; startup latency < 100ms (no IDB reads).
- [ ] **AC-gsm-bfc-3** (SPIKE): GIVEN bfcache restore + tombstone present, WHEN fast-resume check fails, THEN falls through to full Rule 5 boot (forward-recovery).

---

## Implementation Notes

**This is a VS-tier spike story.** Implementation requires:
1. `JavaScriptBridge.create_callback()` for `pageshow` listener
2. `_is_bfcache_restore(): bool` method
3. `_listeners_bound: bool` guard

Q-A3 verification before implementing: confirm Godot 4.6 Web Export COOP/COEP default. If threading enabled by default, atomicity assumptions need Mutex upgrade (ADR-0006 Contract 1 path B).

Spike deliverable: document actual bfcache behavior + timing measurement + confirm or deny fast-resume viability. Implementation follows spike findings.

---

## Out of Scope

- COOP/COEP threading upgrade (deferred until Q-A3 spike result)

---

## QA Test Cases

**AC-gsm-bfc-1** — Integration (manual/playtest — headless can't test bfcache)
- Setup: Web Export running in Chrome; open DevTools Network tab; navigate away then back
- Verify: `pageshow.persisted == true` logged; `_current_state` unchanged
- Pass: state survived bfcache restore

**AC-gsm-bfc-2** — Integration (manual)
- Setup: bfcache restore with clean state (no tombstone)
- Verify: startup takes < 100ms (no IDB reads logged)
- Pass: fast path confirmed

**AC-gsm-bfc-3** — Integration (manual)
- Setup: force tombstone in IDB; trigger bfcache restore
- Verify: full boot runs; forward-recovery executes
- Pass: fallback correct

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `production/qa/evidence/bfcache-resume-spike-evidence.md` — manual spike doc + sign-off

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 011 (boot reconciliation), Q-A3 spike timing (VS playtest)
- Unlocks: Final VS playtest readiness

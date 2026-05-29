# Story 009: GSM Suspended Gate + Reconciling Re-read

> **Epic**: Stat System
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: M (2-3 hours)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-29

## Context

**GDD**: `design/gdd/stat-system.md`
**Requirements**: `TR-stat-010`
*(TR-stat-010: GSM Suspended gate — mutation API rejects when substate == Suspended)*

**ADR Governing Implementation**: ADR-0006 State Machine Contract — Contract 6 (`connect_for_initial_state` for GSM subscription), Contract 13 (IInputPolicy Suspended gate pattern)
**ADR Decision Summary**: Stat System subscribes to GSM `state_changed` via `connect_for_initial_state`. GSM Suspended → Stat System enters Suspended substate → all mutation API calls reject. GSM exit from Suspended → Stat System enters Reconciling substate (1-frame re-read from PersistenceLayer) → emits delta `stat_changed` for any values changed by backend during suspension → returns to Ready.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: GSM `state_changed` signal delivers `(from, to, payload: StateTransitionPayload)` — Stat System reads `to` field for the new state string name. GSM uses string-name states per ADR-0006 Contract 3. Reconciling substate is a single-frame sync operation — no `await`.

**Control Manifest Rules (Core layer)**:
- Required: Subscribe GSM via `connect_for_initial_state` in `_ready()` (ADR-0006 Contract 6 binding)
- Required: Mutation API (including `apply_equipment_modifier`) rejects during Suspended AND Reconciling substates — emit `stat_mutation_rejected(reason="suspended_substate")` for both
- Required: On GSM resume (exit Suspended), re-read all 3 base keys from PersistenceLayer synchronously + emit `stat_changed` for any delta vs pre-Suspended snapshot (Pillar 1 anti-stale guarantee)

---

## Acceptance Criteria

- [ ] **AC-20** — GIVEN GSM delivers `state_changed(from, "suspended", payload)` and Stat System substate transitions to Suspended, WHEN `apply_stat_delta(StatId.STR, StatSource.PR_BREAKTHROUGH, 1.0)` is called, THEN returns `false`, `stat_mutation_rejected(STR, PR_BREAKTHROUGH, 1.0, "suspended_substate")` emits, push_warning fires, AND STR remains unchanged.
- [ ] **AC-new-reconciling** — GIVEN Stat System is in Suspended substate AND PersistenceLayer holds `stat.str = 15.0` (backend updated during suspension, from pre-Suspension value of 12.0), WHEN GSM delivers `state_changed(from, "ready", payload)` (exit from Suspended → Reconciling → Ready), THEN Stat System re-reads PersistenceLayer → `_base[STR]` updates to 15.0 → `stat_changed(STR, 12.0, 15.0, PR_BREAKTHROUGH, false)` emits (source reflects what backend recorded, or a dedicated `RECONCILED` sub-source if designed) → substate returns to Ready. *(QA-lead identified gap: Reconciling re-read is Pillar 1 anti-stale critical path with no prior test evidence — Rule 14 + EC-23)*

---

## Implementation Notes

*From GDD Rule 14 + EC-23 / EC-24 + States table:*

1. **GSM subscription** in `_ready()` (Story 004 sets this up):
   ```gdscript
   GameStateMachine.connect_for_initial_state(_on_gsm_state_changed)
   ```
2. **`_on_gsm_state_changed(from: String, to: String, payload)`**:
   - `to == "suspended"` → `_substate = Substate.SUSPENDED`; capture pre-Suspension `_base` snapshot (`_pre_suspended_snapshot = _base.duplicate()`)
   - `to != "suspended"` AND `_substate == Substate.SUSPENDED` → enter Reconciling
3. **Reconciling sequence** (single-frame, no `await`):
   ```gdscript
   _substate = Substate.RECONCILING
   # Re-read all 3 base keys
   for key_pair in [["stat.str", StatId.STR], ["stat.dex", StatId.DEX], ["stat.vit", StatId.VIT]]:
       var fresh := PersistenceLayer.read(key_pair[0])
       if typeof(fresh) == TYPE_FLOAT and fresh != _pre_suspended_snapshot[key_pair[1]]:
           var old := _base[key_pair[1]]
           _base[key_pair[1]] = fresh
           emit_signal("stat_changed", key_pair[1], old, fresh, StatSource.PR_BREAKTHROUGH, false)
   _substate = Substate.READY
   ```
4. **Mutation rejection during Suspended + Reconciling**: Both substates use reason `"suspended_substate"` (shared per GDD EC-21 simplicity note). `_emit_depth` guard (Story 006) applies normally.
5. **EC-24** (GSM already Suspended at boot): `connect_for_initial_state` delivers initial GSM state — if initial state is "suspended", Stat System immediately enters Suspended after boot. Subscriber receives `boot_completed` then sees mutation rejected.
6. **`get_stat()` remains functional during Suspended + Reconciling** — read-only; does not reject.

---

## Out of Scope

- Story 004: Boot — GSM subscription connection (`connect_for_initial_state` call is there; this story handles the handler body)
- Story 005: `connect_for_initial_state` helper implementation

---

## QA Test Cases

**Story Type**: Integration (GSM state injection required)

- **AC-20**: Suspended gate rejects mutation
  - Given: MockGSM delivers `state_changed(_, "suspended", _)`; Stat System enters Suspended
  - When: `apply_stat_delta(STR, PR_BREAKTHROUGH, 1.0)`
  - Then: Returns false; `stat_mutation_rejected(STR, PR_BREAKTHROUGH, 1.0, "suspended_substate")` emits; push_warning fires; STR unchanged
  - Edge cases: `get_stat(STR)` during Suspended → succeeds (read-only); `apply_equipment_modifier` during Suspended → same rejection; multiple consecutive calls during Suspended → each independently rejected

- **AC-new-reconciling**: Reconciling re-read + delta emit
  - Given: Stat System Suspended with `_base[STR]=12.0` pre-Suspension; MockPersistenceLayer updated to return `15.0` for `"stat.str"` during Suspension
  - When: MockGSM delivers `state_changed("suspended", "ready", _)` (exit Suspended)
  - Then: Stat System re-reads; `_base[STR]` updates to 15.0; `stat_changed(STR, 12.0, 15.0, ...)` emits; substate = Ready; subsequent `apply_stat_delta` succeeds
  - Edge cases: Backend value unchanged during Suspension → no `stat_changed` emit for that stat (delta==0 path or skip entirely); rapid Suspended→Ready→Suspended (EC-23) → each cycle re-reads independently

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/stat_system/test_suspended_gate.gd`, `test_reconciling_reread.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 005 (observer + `connect_for_initial_state`), Story 006 (atomic write — Reconciling re-read follows same persistence path), Story 004 (boot sets up GSM subscription in `_ready()`)
- Unlocks: Story 013 (BLOCKED ADR-RATIFICATION-GATED — after all Ready stories pass, this is the only blocker)

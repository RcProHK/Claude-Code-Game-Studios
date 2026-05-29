# Story 011: Boot Reconciliation — Rule 5 Priority Cascade

> **Epic**: GameStateMachine
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: L (4+ hours)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-29

## Context

**GDD**: `design/gdd/game-state-machine.md`
**Requirement**: `TR-gsm-011`
*(Requirement text: "Rule 5 reconciliation precedence (priority 0/0.5/1/1.5/2/3/4/5) including 401 active-state-deferred + 30-day LootDrop force-transition")*

**ADR Governing Implementation**: ADR-0006 Contract 3 (tombstone recovery = priority 3) + PersistenceLayer integration
**ADR Decision Summary**: `_ready()` runs Rule 5 after `_assert_knob_invariants()`. Priority cascade: 0=401-session-invalidated → DISCONNECTED, 0.5=LootDrop-hard-cap expired → force reveal, 1=pending tombstone → forward-recovery, 1.5=LootDrop-soft-TTL, 2=explicit stored state, 3=tombstone replay, 4=implicit state reconstruction, 5=default IDLE.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: All reads from PersistenceLayer in `_ready()` are sync (Contract 4). No await.

**Control Manifest Rules (Foundation layer)**:
- Required: Rule 5 runs AFTER `_assert_knob_invariants()`
- Required: Tombstone forward-recovery (priority 3) uses original `transition_id` verbatim
- Forbidden: `await` anywhere in Rule 5 code path

---

## Acceptance Criteria

- [ ] **AC-gsm-r5-1**: GIVEN no stored state (fresh install), WHEN `_ready()` runs Rule 5, THEN `_current_state == GameState.IDLE` (priority 5 default).
- [ ] **AC-gsm-r5-2**: GIVEN stored `gsm.current_state = "DISCONNECTED"`, WHEN `_ready()` runs Rule 5, THEN `_current_state == GameState.DISCONNECTED` (priority 2 explicit state).
- [ ] **AC-gsm-r5-3**: GIVEN tombstone present (`gsm.pending_transition` in PersistenceLayer), WHEN `_ready()` runs Rule 5, THEN forward-recovery executes (priority 1); original transition_id reused.
- [ ] **AC-26**: GIVEN PersistenceLayer with `schema_version` matching, WHEN `_ready()` reads state, THEN reads are synchronous (no await); GSM enters correct state within same `_ready()` call.

---

## Implementation Notes

Simplified Rule 5 structure for VS tier:
```gdscript
func _run_rule5_reconciliation() -> void:
    # Priority 1: pending tombstone → forward-recovery
    var tombstone = PersistenceLayer.read("gsm.pending_transition")
    if tombstone != null and tombstone is Dictionary:
        _forward_recover_from_tombstone(tombstone)
        return
    # Priority 2: explicit stored state
    var stored = PersistenceLayer.read("gsm.current_state")
    if stored != null and stored is String:
        var state = GameState.get(stored, -1)
        if state >= 0: _current_state = state; return
    # Priority 5: default IDLE
    _current_state = GameState.IDLE
```

Full priority cascade (including 401/LootDrop-TTL) deferred to post-VS iteration.

---

## Out of Scope

- Story 004: tombstone forward-recovery implementation
- Story 012: weekly tick replay (Rule 5.5)
- LootDrop hard-cap (Story 013)

---

## QA Test Cases

**AC-gsm-r5-1** — Integration
- Given: MockPersistenceLayer with no stored state
- When: Rule 5 runs
- Then: `_current_state == IDLE`

**AC-gsm-r5-2** — Integration
- Given: MockPersistenceLayer with `gsm.current_state = "DISCONNECTED"`
- When: Rule 5 runs
- Then: `_current_state == DISCONNECTED`

**AC-gsm-r5-3** — Integration
- Given: MockPersistenceLayer with tombstone present
- When: Rule 5 runs
- Then: forward-recovery fires; original transition_id preserved

**AC-26** — Integration
- Given: matching schema version
- When: `_ready()` completes
- Then: `_current_state` is set (not BOOTING); no await used

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/state_machine/test_boot_reconciliation_rule5.gd` — must pass

**Status**: [x] Created — `test_boot_reconciliation_rule5.gd` (4 tests)

---

## Completion Notes
**Completed**: 2026-05-29
**Criteria**: 4/4 passing (AC-gsm-r5-1 ✅ AC-gsm-r5-2 ✅ AC-gsm-r5-3 ✅ AC-26 ✅)
**Deviations**: Simplified priority cascade — priorities 1, 2, 5 only. Priorities 0, 0.5, 1.5, 3, 4 deferred post-VS.
**Test Evidence**: Integration — `test_boot_reconciliation_rule5.gd` (4 tests)
**Code Review**: APPROVED (inline)

---

## Dependencies

- Depends on: Story 004 (tombstone recovery), PersistenceLayer epic Complete
- Unlocks: Story 012 (weekly tick runs after basic boot)

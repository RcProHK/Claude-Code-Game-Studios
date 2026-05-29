# Story 016: BossOutcome Enum + Storage JSON Keys

> **Epic**: GameStateMachine
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S (1 hour)
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/game-state-machine.md`
**Requirement**: `TR-gsm-016`, `TR-gsm-018`
*(TR-016: "BossOutcome enum (DEFEATED/INTERRUPTED_WITH_CREDIT/ABANDONED) replaces boss_defeated:bool"; TR-018: "Storage backend: IndexedDB via user://; 9 JSON top-level keys; current_state uses stable string")*

**ADR Governing Implementation**: ADR-0006 Contract 3 (serialization) + ADR-0003 (Proposed ⚠️ — storage topology)
**ADR Decision Summary**: BossOutcome enum already implemented in BossPayload (PersistenceLayer Story 004). GSM writes `gsm.current_state` as string name (not int) for readability. 9 JSON keys defined for `user://state.json`.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `GameState.find_key(value)` for int→string. `GameState[string]` for string→int.

> ⚠️ TR-gsm-018 storage topology partially depends on ADR-0003 (Proposed) for backend-primary semantics. The `gsm.*` namespace writes work with current PersistenceLayer but ADR-0003 ratification needed for full backend-sync.

---

## Acceptance Criteria

- [ ] **AC-gsm-boss-1**: GIVEN `BossOutcome` enum (already in `BossPayload`), WHEN verified in GSM context, THEN 3 values exist: DEFEATED/INTERRUPTED_WITH_CREDIT/ABANDONED.
- [ ] **AC-gsm-keys-1**: GIVEN GSM state transition to IDLE, WHEN `gsm.current_state` written to PersistenceLayer, THEN stored as String `"IDLE"` (not int).
- [ ] **AC-gsm-keys-2**: GIVEN `user://state.json` schema, WHEN 9 top-level keys verified, THEN: `current_state, schema_version, pending_transition, loot_reveal_pending, loot_reveal_payload, _last_weekly_tick_unix, _transition_id_counter, pending_since, loot_reveal_hard_cap_unix`.

---

## Implementation Notes

BossOutcome is in `src/core/boss_payload.gd` (already implemented). GSM just needs to:
1. Write `current_state` as `GameState.find_key(_current_state)` (string)
2. Define the 9 storage keys as constants

```gdscript
# GSM storage key constants
const KEY_CURRENT_STATE: String = "gsm.current_state"
const KEY_PENDING_TRANSITION: String = "gsm.pending_transition"
const KEY_LOOT_REVEAL_PENDING: String = "gsm.loot_reveal_pending"
const KEY_LOOT_REVEAL_PAYLOAD: String = "gsm.loot_reveal_payload"
const KEY_LAST_WEEKLY_TICK: String = "gsm._last_weekly_tick_unix"
const KEY_TRANSITION_ID_COUNTER: String = "gsm._transition_id_counter"
const KEY_PENDING_SINCE: String = "gsm.loot_pending_since"
const KEY_LOOT_HARD_CAP: String = "gsm.loot_reveal_hard_cap_unix"
```

---

## Out of Scope

- Backend-primary sync (ADR-0003 scope)

---

## QA Test Cases

**AC-gsm-boss-1** — Unit
- Given: BossPayload.BossOutcome enum
- When: keys() called
- Then: size==3; contains DEFEATED, INTERRUPTED_WITH_CREDIT, ABANDONED

**AC-gsm-keys-1** — Unit
- Given: transition to IDLE
- When: `gsm.current_state` written to MockPersistenceLayer
- Then: stored value = String "IDLE" (not 2)

**AC-gsm-keys-2** — Unit
- Given: GSM key constants
- When: each constant verified against expected string
- Then: all 9 match expected `gsm.*` namespace keys

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/state_machine/test_bossoutcome_storage_keys.gd` — must pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 003 (transition_id key), BossPayload (PersistenceLayer Story 004)
- Unlocks: Story 011 (reads storage keys at boot)

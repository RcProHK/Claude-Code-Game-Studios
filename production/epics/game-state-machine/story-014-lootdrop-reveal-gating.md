# Story 014: LootDrop Reveal Gating — Natural-Pause States

> **Epic**: GameStateMachine
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S (1-2 hours)
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/game-state-machine.md`
**Requirement**: `TR-gsm-013`
*(Requirement text: "Natural-pause gated LootDrop reveal — safe={Idle, RestPeriod, Disconnected}, suppressed={WorkoutActive, CombatActive, BossEncounter}")*

**ADR Governing Implementation**: ADR-0006 Contract 1 (state validation)
**ADR Decision Summary**: `loot_reveal_pending` flag set when LootDrop ritual available. Reveal suppressed during active gameplay states. Triggered automatically when entering a safe state (Idle/RestPeriod/Disconnected).

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: State check is synchronous. `_check_pending_loot_reveal()` called after every successful state transition.

**Control Manifest Rules (Foundation layer)**:
- Required: Safe states for reveal = {IDLE, REST_PERIOD, DISCONNECTED}
- Required: Suppressed states = {WORKOUT_ACTIVE, COMBAT_ACTIVE, BOSS_ENCOUNTER}

---

## Acceptance Criteria

- [ ] **AC-13-1**: GIVEN `loot_reveal_pending=true`, WHEN entering IDLE from WORKOUT_ACTIVE, THEN loot reveal triggered.
- [ ] **AC-13-2**: GIVEN `loot_reveal_pending=true` AND state = WORKOUT_ACTIVE, WHEN `_check_pending_loot_reveal()` called, THEN reveal NOT triggered (suppressed state).
- [ ] **AC-13-3**: GIVEN `loot_reveal_pending=true`, WHEN entering DISCONNECTED, THEN loot reveal triggered (Disconnected is safe).

---

## Implementation Notes

```gdscript
const LOOT_REVEAL_SAFE_STATES: Array[GameState] = [
    GameState.IDLE, GameState.REST_PERIOD, GameState.DISCONNECTED
]
const LOOT_REVEAL_SUPPRESS_STATES: Array[GameState] = [
    GameState.WORKOUT_ACTIVE, GameState.COMBAT_ACTIVE, GameState.BOSS_ENCOUNTER
]

func _check_pending_loot_reveal() -> void:
    if not PersistenceLayer.read("gsm.loot_reveal_pending"): return
    if _current_state in LOOT_REVEAL_SAFE_STATES:
        _trigger_loot_reveal()
```

Called from `_request_transition` after successful state commit.

---

## Out of Scope

- LootDrop System actual reveal ceremony (LootDrop epic)

---

## QA Test Cases

**AC-13-1** — Unit
- Given: `loot_reveal_pending=true`; transition to IDLE
- When: post-transition hook runs
- Then: reveal triggered

**AC-13-2** — Unit
- Given: `loot_reveal_pending=true`; state = WORKOUT_ACTIVE
- When: check runs
- Then: reveal NOT triggered

**AC-13-3** — Unit
- Given: `loot_reveal_pending=true`; entering DISCONNECTED
- When: post-transition hook
- Then: reveal triggered

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/state_machine/test_lootdrop_reveal_gating.gd` — must pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (transition framework)
- Unlocks: LootDrop System epic (receives reveal trigger)

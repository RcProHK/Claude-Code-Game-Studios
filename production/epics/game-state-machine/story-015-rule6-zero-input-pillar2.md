# Story 015: Rule 6 — Zero-Input Active States (Pillar 2)

> **Epic**: GameStateMachine
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S (1-2 hours)
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/game-state-machine.md`
**Requirement**: `TR-gsm-017`
*(Requirement text: "Rule 6 (Pillar 2): WorkoutActive/CombatActive/BossEncounter must require zero player input; defer to RestPeriod/LootDrop")*

**ADR Governing Implementation**: ADR-0006 Contract 13 (IInputPolicy interface)
**ADR Decision Summary**: `AttentionBudgetPolicy.is_input_permitted()` returns false during WORKOUT_ACTIVE, COMBAT_ACTIVE, BOSS_ENCOUNTER. Input handlers use `IInputPolicy` via DI, not direct state checks.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `is_input_permitted()` is synchronous. No GSM state check inside input handler — only via IInputPolicy.

**Control Manifest Rules (Foundation layer)**:
- Required: Input permission via IInputPolicy (not direct `_current_state` check in handlers)

---

## Acceptance Criteria

- [ ] **AC-15b** (from Story 008 cross-ref): `MockInputPolicy._permitted=false` injected → input dropped during WORKOUT_ACTIVE.
- [ ] **AC-gsm-r6-1**: GIVEN `AttentionBudgetPolicy` + GSM in WORKOUT_ACTIVE, WHEN `is_input_permitted()` called, THEN returns `false`.
- [ ] **AC-gsm-r6-2**: GIVEN GSM in IDLE, WHEN `is_input_permitted()` called, THEN returns `true` (idle = input allowed).
- [ ] **AC-gsm-r6-3**: GIVEN `AttentionBudgetPolicy` receiving `current_state`, WHEN state transitions from WORKOUT_ACTIVE → REST_PERIOD, THEN `is_input_permitted()` changes from false → true.

---

## Implementation Notes

```gdscript
# src/systems/attention_budget_policy.gd (placeholder — Story #33 epic implements full logic)
class_name AttentionBudgetPolicy extends IInputPolicy

const INPUT_BLOCKED_STATES: Array[GameStateMachine.GameState] = [
    GameStateMachine.GameState.WORKOUT_ACTIVE,
    GameStateMachine.GameState.COMBAT_ACTIVE,
    GameStateMachine.GameState.BOSS_ENCOUNTER,
]

func is_input_permitted() -> bool:
    return not (GameStateMachine.get_current_state() in INPUT_BLOCKED_STATES)
```

This is the placeholder stub. Story #33 (AttentionBudget epic) implements the full contract.

---

## Out of Scope

- Full AttentionBudget GDD implementation (Story #33 epic)
- Story 008: IInputPolicy interface definition

---

## QA Test Cases

**AC-gsm-r6-1** — Unit
- Given: AttentionBudgetPolicy + GSM in WORKOUT_ACTIVE
- When: `is_input_permitted()` called
- Then: false

**AC-gsm-r6-2** — Unit
- Given: GSM in IDLE
- When: `is_input_permitted()` called
- Then: true

**AC-gsm-r6-3** — Unit
- Given: transition WORKOUT_ACTIVE → REST_PERIOD
- When: `is_input_permitted()` checked before + after
- Then: false → true

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/state_machine/test_rule6_zero_input.gd` — must pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 008 (IInputPolicy interface)
- Unlocks: AttentionBudget epic (Story #33)

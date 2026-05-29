# Story 008: IInputPolicy Interface — Pillar 2 Enforcement Contract

> **Epic**: GameStateMachine
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S (1-2 hours)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-29

## Context

**GDD**: `design/gdd/game-state-machine.md`
**Requirement**: `TR-gsm-023`
*(Requirement text: "IInputPolicy interface (Contract 13) — AttentionBudgetPolicy extends IInputPolicy; MockInputPolicy for tests")*

**ADR Governing Implementation**: ADR-0006 Contract 13 (AC-15b Pillar 2 derivation enforcement)
**ADR Decision Summary**: `IInputPolicy extends RefCounted` — `is_input_permitted() -> bool`. `AttentionBudgetPolicy` implements real logic from `GameStateMachine.current_state`. Input handlers accept `IInputPolicy` via constructor injection. `MockInputPolicy` for tests with `_permitted: bool` member.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: RefCounted — no autoload needed. Pure interface pattern.

**Control Manifest Rules (Foundation layer)**:
- Required: `AttentionBudgetPolicy extends IInputPolicy`
- Required: Input handlers use constructor injection — NOT direct reference to AttentionBudgetPolicy

---

## Acceptance Criteria

- [ ] **AC-15a**: GIVEN `MockInputPolicy(_permitted=false)` injected into input handler, WHEN input event triggered during WORKOUT_ACTIVE, THEN `MockInputPolicy.is_input_permitted` called exactly once AND input event dropped.
- [ ] **AC-15b**: GIVEN `IInputPolicy` interface, WHEN `is_input_permitted()` method signature introspected, THEN returns `bool` with no parameters.
- [ ] **AC-gsm-input-1**: GIVEN `src/core/i_input_policy.gd` file, WHEN `class_name IInputPolicy extends RefCounted` verified, THEN file exists at correct path.

---

## Implementation Notes

*From ADR-0006 Contract 13 (lines 608-638):*

```gdscript
# src/core/i_input_policy.gd
class_name IInputPolicy extends RefCounted
func is_input_permitted() -> bool:
    push_error("IInputPolicy.is_input_permitted() must be overridden")
    return false
```

```gdscript
# tests/mocks/mock_input_policy.gd
class_name MockInputPolicy extends IInputPolicy
var _permitted: bool = true
func is_input_permitted() -> bool: return _permitted
```

`AttentionBudgetPolicy` (Story #33 AttentionBudget epic — not implemented here) will eventually provide the real derivation from `GameStateMachine.current_state`.

---

## Out of Scope

- AttentionBudgetPolicy real implementation (Story #33 epic)
- Actual input handler wiring (Story 015)

---

## QA Test Cases

**AC-15a** — Unit
- Given: `MockInputPolicy(_permitted=false)` + input event simulation
- When: input fires in WORKOUT_ACTIVE
- Then: `is_input_permitted` called; event dropped

**AC-15b** — Unit
- Given: IInputPolicy instance
- When: method called
- Then: returns bool; no crash

**AC-gsm-input-1** — Static
- Given: file system
- When: `src/core/i_input_policy.gd` checked
- Then: file exists

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/state_machine/test_iinputpolicy_interface.gd` — must pass

**Status**: [x] Created — IInputPolicy + MockInputPolicy + 6 tests

---

## Dependencies

- Depends on: None
- Unlocks: Story 015 (Rule 6 zero-input uses IInputPolicy)

---

## Completion Notes
**Completed**: 2026-05-29
**Criteria**: 3/3 passing (AC-15a ✅ AC-15b ✅ AC-gsm-input-1 ✅)
**Deviations**: None
**Test Evidence**: Logic — `test_iinputpolicy_interface.gd` (6 tests)
**Code Review**: APPROVED (inline)

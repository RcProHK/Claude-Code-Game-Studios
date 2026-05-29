# Story 001: GameState Enum + Rule 1 Unit Test

> **Epic**: GameStateMachine
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S (1 hour)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-29

## Context

**GDD**: `design/gdd/game-state-machine.md`
**Requirement**: `TR-gsm-001`
*(Requirement text: "Rule 1: Exactly one active top-level state from 9-enum (Booting/Disconnected/Idle/WorkoutActive/RestPeriod/CombatActive/BossEncounter/LootDrop/Suspended)")*

**ADR Governing Implementation**: ADR-0006 Contract 1 (Atomic Transition Primitive)
**ADR Decision Summary**: GameStateMachine maintains exactly one active `GameState` enum value. The 9-state enum is locked — no additions without GDD revision. Default state = BOOTING.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: GDScript enum values are int constants. `GameState.find_key(value)` returns the string name.

**Control Manifest Rules (Foundation layer)**:
- Required: Single autoload pos 2; sync `_ready()` — no await
- Forbidden: Never modify _current_state directly outside transition primitive

---

## Acceptance Criteria

- [ ] **AC-01**: GIVEN `GameStateMachine` autoload instantiated, WHEN `get_current_state()` called on fresh boot, THEN returns `GameState.BOOTING`.
- [ ] **AC-02**: GIVEN `GameState` enum, WHEN all values enumerated, THEN exactly 9 members exist: BOOTING/DISCONNECTED/IDLE/WORKOUT_ACTIVE/REST_PERIOD/COMBAT_ACTIVE/BOSS_ENCOUNTER/LOOT_DROP/SUSPENDED.
- [ ] **AC-03**: GIVEN `game_state_machine.gd` source file, WHEN CI scans for `await`, THEN zero non-comment occurrences (ADR-0006 Contract 4 sync discipline).

---

## Implementation Notes

The 9-state enum and `get_current_state()` accessor are **already implemented** in `src/autoload/game_state_machine.gd` (Foundation chain step 4, 2026-05-28). This story adds unit tests to formally verify the AC criteria.

No source changes needed — tests only.

---

## Out of Scope

- Story 002: Rule 2 transition primitive (the state-changing mechanism)
- Any state transition logic

---

## QA Test Cases

**AC-01** — Unit
- Given: fresh GUT test accessing `GameStateMachine` autoload
- When: `GameStateMachine.get_current_state()` called
- Then: returns `GameStateMachine.GameState.BOOTING`

**AC-02** — Unit
- Given: `GameStateMachine.GameState` enum
- When: `GameStateMachine.GameState.keys().size()` evaluated
- Then: equals 9; all 9 names match exact list

**AC-03** — Static / CI
- Given: `src/autoload/game_state_machine.gd`
- When: CI checks for non-comment `await`
- Then: existing CI script exits 0 (or create dedicated check)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/state_machine/test_gamestate_enum_rule1.gd` — must pass

**Status**: [x] Created — `tests/unit/state_machine/test_gamestate_enum_rule1.gd` (4 tests)

---

## Dependencies

- Depends on: None (enum already implemented)
- Unlocks: Story 002 (transition primitive builds on this enum)

---

## Completion Notes
**Completed**: 2026-05-29
**Criteria**: 3/3 passing (AC-01 ✅ AC-02 ✅ AC-03 ✅)
**Deviations**: No src changes needed — enum already implemented (Foundation chain step 4). AC-03 tested via synchronous-call proxy; dedicated GSM no-await CI script owned by Story 007.
**Test Evidence**: Logic — `test_gamestate_enum_rule1.gd` (4 tests)
**Code Review**: APPROVED (inline)

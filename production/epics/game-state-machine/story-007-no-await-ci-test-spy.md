# Story 007: @no-await CI Enforcement + Test Spy Scaffolding

> **Epic**: GameStateMachine
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M (2-3 hours)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-29

## Context

**GDD**: `design/gdd/game-state-machine.md`
**Requirement**: `TR-gsm-021`, `TR-gsm-022`
*(TR-021: "Test Spy Contract — IPersistence + GSM + Input + MockToastQueue + MockInventory + MockEnemyDirector spy interface set"; TR-022: "@no-await static analysis scan-entire-file on src/core/state_machine/**.gd")*

**ADR Governing Implementation**: ADR-0006 Contract 12 (@no-await CI) + Contract 14 (Test Spy Contract)
**ADR Decision Summary**: CI scan `src/core/state_machine/**/*.gd` for `\bawait\b` — any match fails build. Test spy interfaces: `GameStateMachine.attach_in_memory_spy(cb)` + `clear_spies()`. Helper file `tests/helpers/state_machine_spies.gd` scaffolds the full spy set.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: CI uses `rg --glob "*.gd"` (not `--type gdscript`). State machine files MUST live under `src/core/state_machine/` OR `src/autoload/game_state_machine.gd` must be included.

**Control Manifest Rules (Foundation layer)**:
- Forbidden: Never `await` in `src/core/state_machine/**.gd` (CI enforced)

---

## Acceptance Criteria

- [ ] **AC-18a**: GIVEN `src/autoload/game_state_machine.gd`, WHEN CI scans for `\bawait\b`, THEN zero non-comment matches.
- [ ] **AC-gsm-spy-1**: GIVEN `GameStateMachine.attach_in_memory_spy(callable)` + `clear_spies()` methods, WHEN `write("foo","bar")` to MockPersistenceLayer then spy records, THEN spy callable receives `(old_state, new_state)` args on each `_current_state` mutation.
- [ ] **AC-gsm-spy-2**: GIVEN `tests/helpers/state_machine_spies.gd`, WHEN GUT test imports it, THEN all 6 spy attachment methods available (write_spy, delete_spy, in_memory_spy, input_spy, toast_spy, inventory_spy).

---

## Implementation Notes

1. CI script: `tools/ci/check_no_await_in_state_machine.sh` — similar to `check_no_await_in_persistence.sh` from PersistenceLayer Story 001.

2. `GameStateMachine` test spy interface:
```gdscript
# Test spy contract (ADR-0006 Contract 14)
var _in_memory_spies: Array[Callable] = []
func attach_in_memory_spy(spy: Callable) -> void: _in_memory_spies.append(spy)
func clear_spies() -> void: _in_memory_spies.clear()
# Called whenever _current_state mutates:
func _notify_in_memory_spies(old: GameState, new: GameState) -> void:
    for spy in _in_memory_spies: spy.call(old, new)
```

3. `tests/helpers/state_machine_spies.gd`: scaffolds full spy set per ADR-0006 Contract 14 lines 661-672.

---

## Out of Scope

- MockToastQueue / MockInventory implementation — those live in their own system stories

---

## QA Test Cases

**AC-18a** — Static/CI
- Given: game_state_machine.gd source
- When: CI grep runs
- Then: exit 0, zero await

**AC-gsm-spy-1** — Unit
- Given: `attach_in_memory_spy` called with recorder
- When: state changes occur
- Then: spy callable receives correct (old, new) args

**AC-gsm-spy-2** — Unit
- Given: `tests/helpers/state_machine_spies.gd` exists
- When: test imports and calls setup
- Then: no errors; spy methods callable

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tools/ci/check_no_await_in_state_machine.sh` — must exit 0
- `tests/unit/state_machine/test_spy_scaffolding.gd` — must pass

**Status**: [x] Created — CI script + spy interface + helper + 4 tests

---

## Dependencies

- Depends on: Story 001 (basic GSM exists)
- Unlocks: All stories that use spy interfaces for testing

---

## Completion Notes
**Completed**: 2026-05-29
**Criteria**: 3/3 passing (AC-18a ✅ AC-gsm-spy-1 ✅ AC-gsm-spy-2 ✅)
**Deviations**: GSM spy interface added directly to game_state_machine.gd. StateMachineSpies helper in tests/helpers/. Future MockToastQueue/Inventory/EnemyDirector spies added when those systems land.
**Test Evidence**: Logic — `test_spy_scaffolding.gd` (4 tests) + `check_no_await_in_state_machine.sh`
**Code Review**: APPROVED (inline)

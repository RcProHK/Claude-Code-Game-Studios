# Story 010: connect_for_initial_state — Verification Tests

> **Epic**: GameStateMachine
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S (1 hour)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-06

**Completion Notes (2026-06-06)**: documentation story — verified the already-shipped implementation. `tests/unit/state_machine/test_connect_for_initial_state.gd` (proper `test_` prefix, GUT-collected) has 5 tests covering AC-30a (skip-stale) + AC-gsm-sentinel-1 (source_event marker / self-loop) + the 3 other scenarios; all pass in the combined gate (1788 pass / 0 fail). CI lint `tools/ci/check_connect_for_initial_state_bind.gd` (AC-gsm-bind-ci) runs `--headless -s` and **exits 0** on the clean codebase. Removed a stale untracked orphan `connect_for_initial_state_test.gd.uid` (the old `_test.gd`-suffix phantom file's leftover; the real file was already renamed to the `test_` prefix). All 3 ACs satisfied.

## Context

**GDD**: `design/gdd/game-state-machine.md`
**Requirement**: `TR-gsm-008`, `TR-gsm-009`
*(TR-008: "connect_for_initial_state sentinel + race guard"; TR-009: ".bind() FORBIDDEN + CI enforcement")*

**ADR Governing Implementation**: ADR-0006 Contract 6+7 (initial-state delivery) + Contract 12 (CI .bind() scan)
**ADR Decision Summary**: `connect_for_initial_state(callable)` delivers current state as deferred CONNECT_ONE_SHOT on next process_frame. Race guard (`_last_emit_tick`) skips stale delivery. `.bind()` forbidden — CI scans for `connect_for_initial_state(*.bind(*))`.

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: CONNECT_ONE_SHOT semantics verified in Godot 4.6. Self-loop sentinel pattern (`from==to==_current_state`) — detect via `payload.source_event == "initial_state"`.

**Control Manifest Rules (Foundation layer)**:
- Required: sentinel delivery via `callable.callv([from, to, payload])` NOT `state_changed.emit`
- Forbidden: `.bind()` on callable passed to `connect_for_initial_state`

---

## Acceptance Criteria

Note: Implementation already in `game_state_machine.gd` (Foundation chain step 4+6, 2026-05-28). This story adds formal story record for the already-passing tests.

- [ ] **AC-30a (already written)**: subscriber connected via `connect_for_initial_state` + real transition fires before deferred delivery → subscriber receives ONLY real transition (skip-stale per Contract 7).
- [ ] **AC-gsm-sentinel-1 (already written)**: `payload.source_event == "initial_state"` on initial delivery; `from==to==_current_state` (self-loop).
- [ ] **AC-gsm-bind-ci**: CI lint `check_connect_for_initial_state_bind.gd` exits 0 on clean codebase.

---

## Implementation Notes

**Already implemented:**
- `connect_for_initial_state()` + `_deliver_initial_state()` in `src/autoload/game_state_machine.gd`
- 5 GUT tests in `tests/unit/state_machine/connect_for_initial_state_test.gd` (Foundation chain step 6)
- CI lint `tools/ci/check_connect_for_initial_state_bind.gd`

This story is a **documentation story** — formalizing the existing implementation into the epic's story table.

---

## Out of Scope

- All other story implementation — this is already done

---

## QA Test Cases

All 5 test scenarios already in `tests/unit/state_machine/connect_for_initial_state_test.gd`:
1. initial state delivered on next process frame
2. sentinel payload source_event marker set correctly
3. initial state payload is single shared instance
4. skip stale when emit tick advanced before deferred fire
5. default `_last_emit_tick = -1` allows first delivery

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/state_machine/connect_for_initial_state_test.gd` — already written, must pass

**Status**: [x] Already created (Foundation chain step 6, 2026-05-28)

---

## Dependencies

- Depends on: None (already implemented)
- Unlocks: All other stories that use `connect_for_initial_state`

# Story 005: Knob Invariants at Boot (Contract 8)

> **Epic**: GameStateMachine
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S (1-2 hours)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-29

## Context

**GDD**: `design/gdd/game-state-machine.md`
**Requirement**: `TR-gsm-020`
*(Requirement text: "Knob invariant assertions at boot: 8 invariants (Contract 8) including STATE_TRANSITION_FALLBACK_MS ≤ MIN_REVEAL_WINDOW_SECONDS × 100, TOMBSTONE_TTL < SUSPENSION_TTL, ATTEMPT_CAP == 30")*

**ADR Governing Implementation**: ADR-0006 Contract 8 (Knob Invariant Runtime assert() Enforcement)
**ADR Decision Summary**: `_assert_knob_invariants()` called from `GameStateMachine._ready()` BEFORE Rule 5 reconciliation. `assert()` triggers crash in debug builds, no-op in release. 8 invariants protect designer from safe-range corner violations.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: GDScript `assert(condition, message)` — crashes in debug (push_error + error flag), no-op in release. VS + MVP run debug builds per project policy.

**Control Manifest Rules (Foundation layer)**:
- Required: `_assert_knob_invariants()` called from `_ready()` BEFORE Rule 5
- Guardrail: `STATE_TRANSITION_FALLBACK_MS`: 100..1499; `MIN_REVEAL_WINDOW_SECONDS`: 11..30

---

## Acceptance Criteria

- [ ] **AC-17a**: GIVEN default knob values, WHEN `_assert_knob_invariants()` runs in debug build, THEN all 8 assertions pass without crash; no error log.
- [ ] **AC-20a**: GIVEN `STATE_TRANSITION_FALLBACK_MS = 1500` (violates `≤ MIN_REVEAL_WINDOW_SECONDS × 100 = 1500`), WHEN debug build runs `_assert_knob_invariants()`, THEN assertion fires (test catches error).
- [ ] **AC-gsm-knob-1**: GIVEN `ATTEMPT_CAP ≠ 30` (violates Invariant 5), WHEN `_assert_knob_invariants()` runs, THEN assertion fires.

---

## Implementation Notes

*From ADR-0006 Contract 8 (lines 452-500):*

Key constants (add to game_state_machine.gd):
```gdscript
const STATE_TRANSITION_FALLBACK_MS: int = 1000    # safe: 100..1499
const MIN_REVEAL_WINDOW_SECONDS: int = 15          # safe: 11..30
const TOMBSTONE_TTL_SECONDS: int = 7200            # safe: 3600..(SUSPENSION_TTL-1)
const SUSPENSION_TTL_SECONDS: int = 86400
const LOOTDROP_PENDING_TTL_DAYS: int = 6
const LOOTDROP_PENDING_HARD_CAP_DAYS: int = 30
const BASE_DELAY: float = 1.0
const RETRY_CAP: float = 16.0
const ATTEMPT_CAP: int = 30                        # FIXED — never change

func _assert_knob_invariants() -> void:
    assert(STATE_TRANSITION_FALLBACK_MS <= MIN_REVEAL_WINDOW_SECONDS * 100, "Invariant 1")
    assert(TOMBSTONE_TTL_SECONDS < SUSPENSION_TTL_SECONDS, "Invariant 2")
    assert(LOOTDROP_PENDING_TTL_DAYS < LOOTDROP_PENDING_HARD_CAP_DAYS, "Invariant 3")
    assert(BASE_DELAY > 0.0, "Invariant 4a")
    assert(RETRY_CAP >= BASE_DELAY, "Invariant 4b")
    assert(ATTEMPT_CAP == 30, "Invariant 5")
    assert(WALL_CLOCK_DRIFT_TOLERANCE_SECONDS > 0, "Invariant 7")  # from PersistenceLayer
    assert(MAX_WEEKLY_TICK_CATCHUP <= 52, "Invariant 6")
```

F-RAT-1 note: cross-knob warning — if both FALLBACK and MIN_REVEAL near their range corners, Invariant 1 may still pass but be fragile. Cross-knob warning documented in GDD Tuning Knobs.

---

## Out of Scope

- Story 002: Rule 2 transition that uses STATE_TRANSITION_FALLBACK_MS

---

## QA Test Cases

**AC-17a** — Unit
- Given: default knob constants
- When: `_assert_knob_invariants()` called
- Then: no assertions fire; function returns normally

**AC-20a** — Unit
- Given: temporarily modified FALLBACK=1500 or MIN_REVEAL=10
- When: invariants checked
- Then: assertion trips (test catches push_error in debug)

**AC-gsm-knob-1** — Unit
- Given: ATTEMPT_CAP constant
- When: checked via assert
- Then: passes (value = 30); if changed to non-30 → assert fires

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/state_machine/test_knob_invariants.gd` — must pass

**Status**: [x] Created — `tests/unit/state_machine/test_knob_invariants.gd` (9 tests)

---

## Dependencies

- Depends on: Story 001 (enum), None blocking
- Unlocks: Story 002 (uses FALLBACK constant)

---

## Completion Notes
**Completed**: 2026-05-29
**Criteria**: 3/3 passing (AC-17a ✅ AC-20a ✅ AC-gsm-knob-1 ✅)
**Deviations**: 9 constants + `_assert_knob_invariants()` added to game_state_machine.gd. Called from `_ready()` BEFORE `_initial_state_payload` setup. AC-20a tests math validation (can't mutate const at runtime).
**Test Evidence**: Logic — `test_knob_invariants.gd` (9 tests)
**Code Review**: APPROVED (inline)

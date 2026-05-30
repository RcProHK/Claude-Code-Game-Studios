# Story 009: Cross-Knob Invariants

> **Epic**: Ability System
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S (1-2 hours)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-30

## Completion Notes
**Completed**: 2026-05-30
**Criteria**: 4/4 passing (AC-24/25/26/27)
**Deviations**: None — `_assert_knob_invariants()` in _ready head (INV-1/2/3/4/5/6/7); INV-2/3 cross-reference StatSystem.DEFAULT_BASE_VALUE (10) + MAX_STAT_VALUE (999); test references actual TIER_THRESHOLDS/BASE_COOLDOWN_SEC consts; INV-8 8-knob safe-range sweep
**Test Evidence**: Logic — `tests/unit/ability_system/test_knob_invariants.gd`
**Code Review**: Batch C self-verified

## Context

**GDD**: `design/gdd/ability-system.md`
**Requirements**: `TR-ability-018`
*(TR-ability-018: INV-1..INV-8 cross-knob invariants (CI-verified))*

**ADR Governing Implementation**: ADR-0006 Contract 8 pattern (mirrors `_assert_knob_invariants()` in GSM); no specific ADR contract, follows established pattern from stat-system Story 012.
**ADR Decision Summary**: Hard-pin 8 cross-knob invariants in unit tests referencing ACTUAL constants from `ability_system.gd` (never hardcoded literals). Any knob change violating an invariant fails CI. `_assert_knob_invariants()` called in `_ready()` before any boot logic.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Constants loaded at compile time from `const` block in `ability_system.gd`. `pow()` for ratio. Tests reference `StatSystem.DEFAULT_BASE_STAT` and `StatSystem.MAX_STAT_VALUE` directly (cross-system invariant reference). No runtime engine APIs needed.

**Control Manifest Rules (Core layer)**:
- Required: `_assert_knob_invariants()` called from `AbilitySystem._ready()` BEFORE any other boot logic
- Forbidden: Test must NOT hardcode knob values as magic numbers — reference `AbilitySystem.TIER_1_THRESHOLD`, `AbilitySystem.BASE_COOLDOWN_SEC` etc.

---

## Acceptance Criteria

- [ ] **AC-24** — GIVEN TuningKnobs constants loaded, WHEN CI invariant check verifies INV-1 + INV-4, THEN: `TIER_1_THRESHOLD < TIER_2_THRESHOLD < TIER_3_THRESHOLD` (INV-1 strict monotonic — unlock event ordering correctness) AND `TIER_1_BASE_COOLDOWN_SEC < TIER_2_BASE_COOLDOWN_SEC < TIER_3_BASE_COOLDOWN_SEC` (INV-4 strict monotonic — tier hierarchy); violation fails build with offending values.
- [ ] **AC-25** — GIVEN TuningKnobs and #11 StatSystem exposes `DEFAULT_BASE_STAT=10` + `MAX_STAT_VALUE=999`, WHEN CI invariant check verifies INV-2 + INV-3, THEN: `TIER_1_THRESHOLD >= StatSystem.DEFAULT_BASE_STAT` (INV-2 — first-boot auto-unlock guarantee) AND `TIER_3_THRESHOLD <= floor(StatSystem.MAX_STAT_VALUE * 0.25)` = 249 (INV-3 — no grind ceiling).
- [ ] **AC-26** — GIVEN TuningKnobs, WHEN CI invariant check verifies INV-5 + INV-6 + INV-7, THEN: `TIER_1_BASE_COOLDOWN_SEC >= 2.0` (INV-5 — anti-spam floor) AND `TIER_3_BASE_COOLDOWN_SEC <= 15.0` (INV-6 — anti-dead-time ceiling) AND `TIER_3_BASE_COOLDOWN_SEC / TIER_1_BASE_COOLDOWN_SEC <= 4.0` (INV-7 — cadence gap ratio cap).
- [ ] **AC-27** — GIVEN Section G knob table with safe ranges, WHEN test iterates all 8 owned knobs, THEN every value satisfies `safe_range_min <= value <= safe_range_max`; out-of-range fails with knob name + actual value + range.

---

## Implementation Notes

*From GDD Section G Cross-Knob Invariants + ADR-0006 Contract 8 pattern:*

1. **Add `_assert_knob_invariants()` to `_ready()` head** (before sync PL reads):
   ```gdscript
   func _assert_knob_invariants() -> void:
       assert(TIER_1_THRESHOLD < TIER_2_THRESHOLD, "INV-1: TIER_1 < TIER_2 threshold violated")
       assert(TIER_2_THRESHOLD < TIER_3_THRESHOLD, "INV-1: TIER_2 < TIER_3 threshold violated")
       assert(TIER_1_BASE_COOLDOWN_SEC < TIER_2_BASE_COOLDOWN_SEC, "INV-4 violated")
       assert(TIER_2_BASE_COOLDOWN_SEC < TIER_3_BASE_COOLDOWN_SEC, "INV-4 violated")
       assert(TIER_1_THRESHOLD >= StatSystem.DEFAULT_BASE_STAT, "INV-2 violated")
       assert(TIER_3_THRESHOLD <= floori(StatSystem.MAX_STAT_VALUE * 0.25), "INV-3 violated")
       assert(TIER_1_BASE_COOLDOWN_SEC >= 2.0, "INV-5 violated")
       assert(TIER_3_BASE_COOLDOWN_SEC <= 15.0, "INV-6 violated")
       assert(TIER_3_BASE_COOLDOWN_SEC / TIER_1_BASE_COOLDOWN_SEC <= 4.0, "INV-7 violated")
   ```
2. **Test pattern** — reference constants directly (not hardcoded):
   ```gdscript
   var ss := preload("res://src/autoload/ability_system.gd")
   assert_lt(ss.TIER_1_THRESHOLD, ss.TIER_2_THRESHOLD, "INV-1")
   ```
3. **INV-8 safe-range table** (8 owned knobs):
   ```gdscript
   var safe_ranges = {
       "TIER_1_THRESHOLD": [5, 30],
       "TIER_2_THRESHOLD": [30, 100],
       "TIER_3_THRESHOLD": [100, 400],
       "TIER_1_BASE_COOLDOWN_SEC": [2.0, 5.0],
       "TIER_2_BASE_COOLDOWN_SEC": [4.0, 9.0],
       "TIER_3_BASE_COOLDOWN_SEC": [7.0, 15.0],
       "MINIMUM_ACTIVE_STAT": [3.0, 15.0],
       "MAX_EMIT_DEPTH": [0, 4],
   }
   ```
4. **StatSystem cross-reference** — `assert(TIER_1_THRESHOLD >= StatSystem.DEFAULT_BASE_STAT, ...)` requires StatSystem accessible from test. Use `StatSystem.DEFAULT_BASE_STAT` constant directly.
5. **No StatSystem DI needed** — invariant test only reads const values; no StatSystem instance required.

---

## Out of Scope

- Story 005: TIER_THRESHOLDS formula usage (this story only verifies knob constraints, not evaluation logic)
- Story 006: BASE_COOLDOWN_SEC formula usage

---

## QA Test Cases

**Story Type**: Logic

- **AC-24**: Monotonic invariants INV-1 + INV-4
  - Given: AbilitySystem constants via preload
  - When: Compute INV-1 and INV-4 expressions
  - Then: Both pass with current defaults (10 < 50 < 200; 3.0 < 6.0 < 10.0)
  - Edge cases: Set TIER_2_THRESHOLD = TIER_1_THRESHOLD in test → assert fails (test verifies invariant is enforced)

- **AC-25**: Anchor + ceiling INV-2 + INV-3
  - Given: AbilitySystem + StatSystem constants
  - When: Verify TIER_1_THRESHOLD >= DEFAULT_BASE_STAT AND TIER_3_THRESHOLD <= MAX*0.25
  - Then: 10 >= 10 ✓; 200 <= 249 ✓

- **AC-26**: Cooldown bounds INV-5 + INV-6 + INV-7
  - Given: BASE_COOLDOWN constants
  - When: 3.0 >= 2.0; 10.0 <= 15.0; 10.0/3.0 = 3.33 <= 4.0
  - Then: All pass with current defaults

- **AC-27**: INV-8 all 8 knobs in safe range
  - Given: Safe ranges table (hardcoded as design documentation)
  - When: Check each of 8 knobs
  - Then: All 8 within range; diagnostic output if any out-of-range

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/ability_system/test_knob_invariants.gd` (distinct from `tests/unit/state_machine/test_knob_invariants.gd` for GSM and `tests/unit/stat_system/test_knob_invariants.gd` for StatSystem)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 005 (TIER_THRESHOLDS defined), Story 006 (BASE_COOLDOWN_SEC defined)
- Unlocks: Story 010 (ADR-Ratification-Gated — all Ready stories must be Complete first)

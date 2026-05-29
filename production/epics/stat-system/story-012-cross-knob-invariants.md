# Story 012: Cross-Knob Invariants

> **Epic**: Stat System
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S (1-2 hours)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-29

## Context

**GDD**: `design/gdd/stat-system.md`
**Requirements**: `TR-stat-013`
*(TR-stat-013: 15 owned tuning knobs + 9 cross-knob invariants (CI-verified))*

**ADR Governing Implementation**: ADR-0006 State Machine Contract — (no specific contract; pattern mirrors ADR-0006 Contract 8 `_assert_knob_invariants` in GSM)
**ADR Decision Summary**: All 9 cross-knob invariants are hard-pinned in unit tests. Any knob change that violates an invariant fails CI. INV-9 iterates all 15 knobs against their safe ranges. CF-1 default baseline (STR=DEX=VIT=10, no eq, default knobs → MAX_HP=160, ATK=28, MOVE=184, CRIT=1.5%) is hard-coded as a regression anchor.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Constants loaded at compile time from the `const` block in `stat_system.gd`. `pow()` used in INV-2 test. Tests must reference the actual constants from the script, not hardcoded literals — so any knob change breaks only the tests that should break.

**Control Manifest Rules (Core layer)**:
- Required: `_assert_knob_invariants()` called from `StatSystem._ready()` BEFORE any other boot logic — catches violated invariants before first use
- Forbidden: Test must NOT hardcode knob values as magic numbers — use `StatSystem.PR_BASE`, `StatSystem.HP_PER_VIT` etc. so tests break when knobs change

---

## Acceptance Criteria

- [ ] **AC-30** — GIVEN default knob const values loaded from `stat_system.gd`, WHEN test computes all 4 invariant expressions, THEN: `PR_BASE × 2.0 < 50.0` ✓ (INV-1); `HP_BASE + 10 × HP_PER_VIT ≥ 150` ✓ (INV-3); `ATK_PER_DEX × 2.0 < ATK_PER_STR` ✓ (INV-4); `ATK_BASE + 10 × ATK_PER_STR + 10 × ATK_PER_DEX ≥ 25` ✓ (INV-5); AND if any knob is changed to violate any invariant → test fails with diagnostic message identifying which invariant broke and what the actual + expected values were.
- [ ] **AC-31** — GIVEN default knob values, WHEN test computes stat-only cap expressions, THEN: `MOVE_BASE + 999 × MOVE_PER_DEX > MOVE_CAP` ✓ (INV-6 — cap reachable by stat alone); `(DEX_FOR_MAX_CRIT = MAX_CRIT_CHANCE / CRIT_PER_DEX) ∈ [100.0, MAX_STAT_VALUE]` ✓ (INV-8); confirming CF-3 (stat-only progression can reach derived caps without equipment).
- [ ] **AC-32** — GIVEN all 15 tuning knobs and their safe ranges from GDD Section G, WHEN test iterates each knob and checks `value within [safe_min, safe_max]`, THEN all 15 pass; AND if any knob is out of range (e.g., `MAX_CRIT_CHANCE = 5.0`), test fails with knob name + actual value + safe range. (ADVISORY — does not block Done)

---

## Implementation Notes

*From GDD Section G Cross-Knob Invariants + INV-1 through INV-9:*

1. **`_assert_knob_invariants()` in `_ready()`** (mirrors GSM pattern from ADR-0006 Contract 8):
   ```gdscript
   func _assert_knob_invariants() -> void:
       assert(PR_BASE * 2.0 < 50.0, "INV-1 violated: PR_BASE*2=%f" % (PR_BASE*2))
       assert(HP_BASE + 10.0 * HP_PER_VIT >= 150.0, "INV-3 violated")
       assert(ATK_PER_DEX * 2.0 < ATK_PER_STR, "INV-4 violated: DEX must not dominate ATK")
       assert(ATK_BASE + 10.0 * ATK_PER_STR + 10.0 * ATK_PER_DEX >= 25.0, "INV-5 violated")
       assert(MOVE_BASE + 999.0 * MOVE_PER_DEX > MOVE_CAP, "INV-6 violated: MOVE_CAP unreachable by stat-only")
       var dex_for_crit := MAX_CRIT_CHANCE / CRIT_PER_DEX
       assert(dex_for_crit >= 100.0 and dex_for_crit <= MAX_STAT_VALUE, "INV-8 violated: DEX_FOR_MAX_CRIT out of range")
   ```
   (INV-2 and INV-7 are mathematical guarantees verified in formulas, not `assert` checks)

2. **Test pattern** — reference constants directly:
   ```gdscript
   var ss := preload("res://src/autoload/stat_system.gd").new()
   assert_eq(ss.PR_BASE * 2.0 < 50.0, true, "INV-1")
   assert_ge(ss.HP_BASE + 10.0 * ss.HP_PER_VIT, 150.0, "INV-3")
   ```

3. **INV-9 safe-range table** — hard-coded in test (safe ranges are design documentation, not runtime-variable):
   ```gdscript
   var safe_ranges := {
       "MAX_STAT_VALUE": [100.0, 9999.0],
       "DEFAULT_BASE_STAT": [1.0, 50.0],
       "VOLUME_TICK_BASE": [0.02, 0.20],
       "PR_BASE": [3.0, 12.0],
       # ... all 15 knobs
   }
   ```

4. **AC-32 is ADVISORY** — INV-9 safe-range check does not block Done; it documents intent and protects against typos. Mark test as advisory in story tracking.

---

## Out of Scope

- Story 011: Formula 1+2 computation (uses knob values; invariants verify the knobs are valid)
- Story 010: Derived formulas F3-F6 (also uses knobs; same relationship)

---

## QA Test Cases

**Story Type**: Logic (unit tests, const-based)

- **AC-30**: INV-1/3/4/5 baseline invariants
  - Given: Load stat_system.gd const block
  - When: Compute all 4 invariant expressions
  - Then: All 4 pass; diagnostic output on failure names the violated invariant with actual vs expected
  - Edge cases: Deliberately change `PR_BASE=25.0` in test (via monkey-patch or fork) → INV-1 fails immediately (PR_BASE×2=50.0 ≮ 50.0); `ATK_PER_DEX=1.0` → INV-4 fails (1.0×2=2.0 ≮ ATK_PER_STR=1.5... wait, 2.0 > 1.5 → violates rule "DEX<STR/2")

- **AC-31**: INV-6/8 stat-only cap reachable
  - Given: Default knobs
  - When: Compute `MOVE_BASE + 999 × MOVE_PER_DEX` and `MAX_CRIT_CHANCE / CRIT_PER_DEX`
  - Then: 579.6 > 420 ✓; 333.3 ∈ [100, 999] ✓
  - Edge cases: `MOVE_CAP=600` (could make INV-6 fail if `MOVE_BASE+999×MOVE_PER_DEX < 600`); `CRIT_PER_DEX=0.001` → DEX_FOR_MAX_CRIT=500 (still in range)

- **AC-32**: INV-9 all knobs in safe range (ADVISORY)
  - Given: 15 knobs and safe ranges table
  - When: Check each knob
  - Then: All in range; diagnostic on failure: "MAX_CRIT_CHANCE = 5.0 is outside safe range [0.30, 0.75]"

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/stat_system/test_knob_invariants.gd` (AC-30 BLOCKING, AC-31 BLOCKING, AC-32 ADVISORY)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 010 (derived formulas use these knobs — invariant tests verify formula knobs in their safe range), Story 011 (mutation formula knobs — PR_BASE, VOLUME_TICK_BASE included in INV-9)
- Unlocks: Story 013 (BLOCKED — all 12 Ready stories must be Complete first)

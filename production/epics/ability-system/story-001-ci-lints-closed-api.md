# Story 001: CI Lints — Closed API Enforcement

> **Epic**: Ability System
> **Status**: Complete
> **Layer**: Core
> **Type**: Static
> **Estimate**: M (2-3 hours)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-30

## Completion Notes
**Completed**: 2026-05-30
**Criteria**: 6/6 passing (AC-02/04/08/09/signal/relock — 6 CI lints created)
**Deviations**: None — follows stat-system lint pattern (extends SceneTree, exit 0/1/2, non-vacuous)
**Test Evidence**: Static — `tools/ci/check_ability_id_magic_string.gd`, `check_ability_internal_field_access.gd`, `check_ability_unlock_callers.gd`, `check_ability_cast_callers.gd`, `check_ability_signal_connect.gd`, `check_ability_relock.gd`
**Code Review**: Batch A self-verified (same proven pattern as stat-system 4 lints which passed CI)

## Context

**GDD**: `design/gdd/ability-system.md`
**Requirements**: `TR-ability-003`, `TR-ability-007`
*(TR-ability-003: Closed mutation API — direct private field access rejected (CI). TR-ability-007: Caller whitelist CI lints for `unlock_ability` + `cast_ability`)*

**ADR Governing Implementation**: ADR-0006 State Machine Contract — Contract 12 (CI-enforced chokepoints). No await in chokepoint functions; violation catches at build time.
**ADR Decision Summary**: All mutation paths funnelled through single chokepoints; CI lints enforce statically so violations cannot reach main.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: CI lints use `--glob "*.gd"` pattern (NOT `--type gdscript` — invalid in ripgrep). Same extends SceneTree + DirAccess/RegEx pattern established by `tools/ci/check_connect_for_initial_state_bind.gd` and stat-system CI lints. Exit 0=PASS, 1=violation, 2=internal error.

**Control Manifest Rules (Core layer)**:
- Required: CI caller whitelist for `unlock_ability` (whitelist: `src/autoload/ability_system.gd` only) and `cast_ability` (whitelist: `src/core/combat_resolver.gd` only)
- Forbidden: Never `_unlocked_abilities[` or `_unlocked_abilities.` access outside `src/autoload/ability_system.gd`
- Forbidden: Never `.erase(` or `.clear(` on `_unlocked_abilities` outside schema migration paths (permanent unlock contract)

---

## Acceptance Criteria

- [ ] **AC-02** — GIVEN any `src/` file (excluding `src/autoload/ability_system.gd`) contains a string literal matching pattern `(strike|control|mobility)_tier_[1-3]_[a-z_]+`, WHEN CI lint `tools/ci/check_ability_id_magic_string.gd` runs, THEN build fails, exit code ≠ 0, offending file + line reported.
- [ ] **AC-04** — GIVEN any `src/` file (excluding `src/autoload/ability_system.gd` and `tests/`) contains `AbilitySystem._unlocked_abilities[` OR `AbilitySystem._unlocked_abilities.`, WHEN CI lint `tools/ci/check_ability_internal_field_access.gd` runs, THEN build fails.
- [ ] **AC-08** — GIVEN any `src/` file (excluding `src/autoload/ability_system.gd`) contains `AbilitySystem.unlock_ability(` OR `AbilitySystem.unlock_ability (`, WHEN CI lint `tools/ci/check_ability_unlock_callers.gd` runs, THEN build fails identifying unauthorized caller (only ability_system.gd internal calls are permitted — PR Detection emits signal, not direct call).
- [ ] **AC-09** — GIVEN any `src/` file (excluding `src/core/combat_resolver.gd` and `tests/`) contains `AbilitySystem.cast_ability(`, WHEN CI lint `tools/ci/check_ability_cast_callers.gd` runs, THEN build fails.
- [ ] **AC-signal** — GIVEN any `src/` file (excluding `src/autoload/ability_system.gd` and `tests/`) contains `.connect(` with `"ability_unlocked"` OR `"ability_cast"` OR `"ability_cooldown_` (plain connect bypassing Contract 6 helper), WHEN CI lint `tools/ci/check_ability_signal_connect.gd` runs, THEN build fails with message "Use connect_for_initial_state — see ADR-006 Contract 6".
- [ ] **AC-relock** — GIVEN any `src/` file (excluding `src/autoload/ability_system.gd` and schema migration paths) contains `_unlocked_abilities.erase(` OR `_unlocked_abilities.clear(`, WHEN CI lint `tools/ci/check_ability_relock.gd` runs, THEN build fails (permanent unlock contract enforcement — Rule 12).

---

## Implementation Notes

*From GDD Rules 1, 3, 6, 12 + ADR-0006 Contract 12:*

1. **`check_ability_id_magic_string.gd`** — regex scan `(strike|control|mobility)_tier_[1-3]_[a-z_]+` in string literals (not comments). Exclude `src/autoload/ability_system.gd`.
2. **`check_ability_internal_field_access.gd`** — grep `AbilitySystem\._unlocked_abilities[\[.]` across `src/`. Exclude self.
3. **`check_ability_unlock_callers.gd`** — grep `AbilitySystem\.unlock_ability\s*\(` across `src/`. Only `src/autoload/ability_system.gd` permitted.
4. **`check_ability_cast_callers.gd`** — grep `AbilitySystem\.cast_ability\s*\(` across `src/`. Only `src/core/combat_resolver.gd` permitted.
5. **`check_ability_signal_connect.gd`** — grep `\.connect\(.*"ability_(unlocked|cast|cooldown_)"` across `src/`. Exclude `src/autoload/ability_system.gd`.
6. **`check_ability_relock.gd`** — grep `_unlocked_abilities\.(erase|clear)\s*\(` across `src/`. Exclude `src/autoload/ability_system.gd`.
7. **All follow stat-system lint pattern** — `extends SceneTree`, DirAccess/FileAccess/RegEx, exit 0/1/2, src/ absent → exit 2.
8. **All auto-picked up** by `tests.yml` "Run CI lints (tools/ci/*.gd)" step — no workflow modification needed.
9. **Performance**: CI-only, no runtime impact. Non-vacuous guard: exit 2 if src/ absent.

---

## Out of Scope

- Story 002: Runtime enum + signal implementation (what the lints guard)
- Story 003: Source/class allow-list runtime guard in `unlock_ability` body

---

## QA Test Cases

**Story Type**: Static
**Required evidence**: 6 CI lint scripts must exist, be non-vacuous (exit 2 if src/ absent, not 0), exit 0 on clean code, exit 1 on violation.

- **AC-02**: Given `src/game.gd` contains `"strike_tier_1_jab"` as a string literal → exit 1; `AbilityId.STRIKE_TIER_1_JAB` (no magic string) → exit 0
- **AC-04**: Given `src/hud.gd` contains `AbilitySystem._unlocked_abilities["x"]` → exit 1; ability_system.gd accessing own field → exit 0
- **AC-08**: Given `src/pr_detection.gd` calls `AbilitySystem.unlock_ability(...)` directly → exit 1 (must use signal instead); only ability_system.gd internal → exit 0
- **AC-09**: Given `src/hud.gd` calls `AbilitySystem.cast_ability(...)` → exit 1; `src/core/combat_resolver.gd` → exit 0
- **AC-signal**: Given `src/hud.gd` has `ability_system.ability_unlocked.connect(my_cb)` → exit 1; `connect_for_initial_state(my_cb)` → exit 0
- **AC-relock**: Given `src/migration.gd` calls `_unlocked_abilities.clear()` → exit 1; ability_system.gd itself → exit 0

---

## Test Evidence

**Story Type**: Static
**Required evidence**: `tools/ci/check_ability_id_magic_string.gd`, `check_ability_internal_field_access.gd`, `check_ability_unlock_callers.gd`, `check_ability_cast_callers.gd`, `check_ability_signal_connect.gd`, `check_ability_relock.gd` — all must exist and pass in CI

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None (CI infrastructure — first story, no runtime code required)
- Unlocks: Story 002 (runtime implementation — lints must exist before code is written)

# Story 001: CI Lints — 5-Layer Purity Defense

> **Epic**: Combat Resolver
> **Status**: Complete
> **Layer**: Core
> **Type**: Static
> **Estimate**: M (2-3 hours)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-30

## Completion Notes
**Completed**: 2026-05-30
**Criteria**: 6/6 passing (5 lints + AC-05 single-entry)
**Deviations**: None — purity lint uses indentation block-tracking state machine (distinguishes inner-POD-class var [OK] + static-func-body var [OK] from class-scope var [violation]); @onready/@export/_ready/_process unconditionally banned. CombatResolver is NOT autoload (project.godot never registered it).
**Test Evidence**: Static — `tools/ci/check_combat_resolver_purity.gd` + autoload/engine_singletons/randf/stat_calls
**Code Review**: Batch A self-verified (agent traced own source against purity lint)

## Context

**GDD**: `design/gdd/combat-resolver.md`
**Requirements**: `TR-combat-001`, `TR-combat-004`
*(TR-combat-001: Stateless pure-function — static func only, no var/signal/autoload. TR-combat-004: Single entry resolve_hit(ctx: CombatContext) → HitResult.)*

**ADR Governing Implementation**: ADR-0006 Contract 12 (CI-enforced chokepoints — no mutable state, no RNG, no singleton reads)
**ADR Decision Summary**: 4-layer CI lint defense ensures CombatResolver remains a true pure function: purity (no instance vars), autoload (not registered), engine-singletons (no global reads), randf-ban (RNG caller-injected). Fifth lint guards against StatSystem direct reads (must go via snapshot).

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: All 5 lints use `extends SceneTree` + RegEx/DirAccess (established pattern from stat + ability CI lints). Exit 0/1/2. Non-vacuous: exit 2 if `src/` absent.

**Control Manifest Rules (Core layer)**:
- Required: CombatResolver MUST be `class_name CombatResolver extends RefCounted` with `static func` only — no autoload
- Forbidden: Any `var`, `@onready`, `@export`, `signal`, `_ready`, `_process` in the CombatResolver class body
- Forbidden: Any `randf(` / `randi(` / `RandomNumberGenerator.new()` in `src/core/combat_resolver.gd`
- Forbidden: Direct `StatSystem.` / `AbilitySystem.` / `GameStateMachine.` reference in `src/core/combat_resolver.gd` (must use snapshot inputs)

---

## Acceptance Criteria

- [ ] **AC-01-lint** — GIVEN `tools/ci/check_combat_resolver_purity.gd` runs against `src/core/combat_resolver.gd`, WHEN the class body contains any `var` (instance), `@onready`, `@export`, `signal`, `_ready()`, `_process()`, or `_physics_process()`, THEN exit code ≠ 0, offending line reported. `const` and `static func` body vars are permitted.
- [ ] **AC-autoload-lint** — GIVEN `tools/ci/check_combat_resolver_autoload.gd` runs, WHEN `project.godot` `[autoload]` section contains any reference to `CombatResolver`, THEN exit code ≠ 0. CombatResolver is NOT an autoload.
- [ ] **AC-singletons-lint** — GIVEN `tools/ci/check_combat_resolver_engine_singletons.gd` runs against `src/core/combat_resolver.gd`, WHEN any of `StatSystem.`, `AbilitySystem.`, `GameStateMachine.`, `ScreenEffects.`, `ParticleSystemWrapper.` appear, THEN exit code ≠ 0 (pure function — no global reads; must use snapshot inputs from CombatContext).
- [ ] **AC-randf-lint** — GIVEN `tools/ci/check_combat_resolver_randf.gd` runs against `src/core/combat_resolver.gd`, WHEN any of `randf(`, `randi(`, `randf_range(`, `RandomNumberGenerator.new()` appear, THEN exit code ≠ 0 (RNG must be caller-injected via ctx.rng — FR-1 binding).
- [ ] **AC-stat-calls-lint** — GIVEN `tools/ci/check_combat_resolver_stat_calls.gd` runs, WHEN any `StatSystem.` reference appears inside `src/core/combat_resolver.gd`, THEN exit code ≠ 0 (stats arrive pre-snapshotted in CombatContext.caster_stats — Rule 6).
- [ ] **AC-05** — GIVEN `CombatResolver.gd` source, WHEN static type inspection, THEN entry point is `static func resolve_hit(ctx: CombatContext) -> HitResult` — typed params, no `Variant` return. Single-entry-point invariant (Rule 2).

---

## Implementation Notes

*From GDD Rule 1, Rule 2, Rule 6 + ADR-0006 Contract 12:*

1. **`check_combat_resolver_purity.gd`** — RegEx scan class body (after `class_name CombatResolver`) for: `^\s*var\s`, `@onready`, `@export`, `^\s*signal\s`, `func _ready`, `func _process`, `func _physics_process`. Allowlist: `\s*const\s` + `\s*static func\s` + inner `class\s`. Exit 1 on any class-scope match.
2. **`check_combat_resolver_autoload.gd`** — Read `project.godot`; grep `[autoload]` section for `CombatResolver`. Exit 1 if found.
3. **`check_combat_resolver_engine_singletons.gd`** — Scan `src/core/combat_resolver.gd` for `StatSystem\.|AbilitySystem\.|GameStateMachine\.|ScreenEffects\.|ParticleSystemWrapper\.`. Exit 1 on match.
4. **`check_combat_resolver_randf.gd`** — Scan `src/core/combat_resolver.gd` for `randf\(|randi\(|randf_range\(|RandomNumberGenerator\.new\(`. Exit 1 on match.
5. **`check_combat_resolver_stat_calls.gd`** — Scan `src/core/combat_resolver.gd` for `StatSystem\.`. Exit 1 on match (note: also covered by check 3, but separate lint for clearer CI output).
6. All 5 lints follow `extends SceneTree` + DirAccess/RegEx + exit 0/1/2 pattern. Auto-picked up by `tests.yml` "Run CI lints (tools/ci/*.gd)" step.

---

## Out of Scope

- Story 002: CombatResolver runtime implementation (what the lints guard)
- Story 003-008: Formula implementations

---

## QA Test Cases

**Story Type**: Static
**Required evidence**: 5 CI lint scripts must exist, be non-vacuous (exit 2 if src/ absent), exit 0 on clean code, exit 1 on violation.

- `check_combat_resolver_purity.gd`: Given class body has `var _state: int`, exit 1; `static func resolve_hit()` → exit 0
- `check_combat_resolver_autoload.gd`: Given `project.godot` has `CombatResolver=...`, exit 1; not in autoload → exit 0
- `check_combat_resolver_engine_singletons.gd`: Given `StatSystem.get_stat()` in resolver → exit 1; removed → exit 0
- `check_combat_resolver_randf.gd`: Given `randf()` call → exit 1; `ctx.rng.randf()` → exit 0
- `check_combat_resolver_stat_calls.gd`: Given `StatSystem.` ref → exit 1; via snapshot only → exit 0

---

## Test Evidence

**Story Type**: Static
**Required evidence**: `tools/ci/check_combat_resolver_purity.gd`, `check_combat_resolver_autoload.gd`, `check_combat_resolver_engine_singletons.gd`, `check_combat_resolver_randf.gd`, `check_combat_resolver_stat_calls.gd`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None (CI infrastructure — first story)
- Unlocks: Story 002 (runtime implementation — lints active before code written)

# Story 002: CI Lint Suite A — RNG / Chokepoint / Stat

> **Epic**: Enemy Director
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 3h
> **Manifest Version**: 2026-05-29
> **Last Updated**:

## Context

**GDD**: `design/gdd/enemy-director.md`
**Requirements**: `TR-enemy-002, TR-enemy-011`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: N/A (CI tooling)
**ADR Decision Summary**: CI lint scripts enforce forbidden patterns at commit time; each script must include positive (violation → exit 1) and negative (clean → exit 0) fixture tests.

**Engine**: Godot 4.6 | **Risk**: LOW

---

## Acceptance Criteria

*From GDD `design/gdd/enemy-director.md`, scoped to this story:*

- [ ] AC-03 [Logic|BLOCKING|static]: `tools/ci/check_enemy_director_chokepoint.gd` — AST scan `src/autoload/enemy_director.gd`; reject inline arithmetic resembling damage math (`caster.attack_power * 1.5`, `target.hp -= ...`); all damage MUST go via `CombatResolver.resolve_hit()`. Script must have fixture test: positive fixture (violation present → exit 1) + negative fixture (clean → exit 0).
- [ ] AC-14 [Logic|BLOCKING|static]: `tools/ci/check_enemy_director_randf.gd` — reject `randf(` / `randi(` / `randf_range(` / `Time.get_ticks_msec(` / direct `RandomNumberGenerator.new()` in `enemy_director.gd` outside RNGFactory class body. Fixture: positive (violation) + negative (clean).
- [ ] (Story-level AC) `tools/ci/check_enemy_director_stat_calls.gd` — verify all `StatSystem.get_stat()` calls in `enemy_director.gd` exist ONLY inside `_build_stat_snapshot()` method body (Rule 8). Fixture: positive (stat call outside snapshot method → exit 1) + negative (clean → exit 0).

---

## Implementation Notes

*Derived from GDD Rules and ADR guidelines:*

- Each CI script is a GDScript `extends SceneTree` that parses the source file as text (regex scan).
- Each script returns exit code 0 (clean) or 1 (violation). Use `OS.exit(1)` on violation.
- Write positive fixture file (`tests/ci_fixtures/enemy_director_violation_a.gd.txt`) containing an intentional violation; verify the script detects it.
- Write negative fixture file (`tests/ci_fixtures/enemy_director_clean_a.gd.txt`) with clean code; verify the script passes.
- `check_enemy_director_chokepoint.gd`: regex patterns to reject — `attack_power\s*\*`, `\.hp\s*-=`, `\.hp\s*\+=` (raw HP mutation), `\.defense\s*-=`.
- `check_enemy_director_randf.gd`: patterns to reject — `randf\(`, `randi\(`, `randf_range\(`, `Time\.get_ticks_msec\(`, `RandomNumberGenerator\.new\(` — but ONLY outside `class RNGFactory` body scope. Use line-range tracking.
- `check_enemy_director_stat_calls.gd`: verify `StatSystem\.get_stat\(` appears ONLY inside `func _build_stat_snapshot` method body.

---

## Out of Scope

*Handled by neighbouring stories:*

- Story 003: CI Lint Suite B (boot order, signal lifecycle, state locality scripts)
- Story 004: CI Lint Suite C (forbidden patterns, move cap, dodge invariant scripts)
- Story 008: Actual `_build_stat_snapshot()` implementation that these lints protect

---

## QA Test Cases

**AC-03**: Given: `check_enemy_director_chokepoint.gd` run against `enemy_director_violation_a.gd.txt` (contains `target.hp -= damage`). When: script executes. Then: exit code 1. Given: run against `enemy_director_clean_a.gd.txt`. Then: exit code 0.

**AC-14**: Given: `check_enemy_director_randf.gd` run against fixture containing `var x = randf()` outside RNGFactory. When: script executes. Then: exit code 1. Given: run against clean fixture (all randf calls inside RNGFactory class body). Then: exit code 0.

**Story-level AC**: Given: `check_enemy_director_stat_calls.gd` run against fixture containing `StatSystem.get_stat(...)` outside `_build_stat_snapshot`. When: script executes. Then: exit code 1. Given: clean fixture (all stat calls inside snapshot method). Then: exit code 0.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tools/ci/check_enemy_director_chokepoint.gd` + `tools/ci/check_enemy_director_randf.gd` + `tools/ci/check_enemy_director_stat_calls.gd` — all with fixture tests in `tests/ci_fixtures/`
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (source file `src/autoload/enemy_director.gd` must exist to lint)
- Unlocks: Story 016 (AOE pipeline verifiable), Story 008 (stat snapshot protected by lint)

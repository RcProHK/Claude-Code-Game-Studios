# Story 006: RNG Factory + Sub-RNG Determinism

> **Epic**: Enemy Director
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 3h
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-31

## Context

**GDD**: `design/gdd/enemy-director.md`
**Requirements**: `TR-enemy-010, TR-enemy-011`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005 (transition_id chain) + ADR-0006 Contract 2
**ADR Decision Summary**: ADR-0005 mandates all RNG seeded from `transition_id` for deterministic replay; ADR-0006 Contract 2 mandates transition_id sync read from GSM at cast time; no wall-clock or process-time seeds permitted.

**Engine**: Godot 4.6 | **Risk**: MEDIUM

---

## Acceptance Criteria

*From GDD `design/gdd/enemy-director.md`, scoped to this story:*

- [x] AC-12 [Logic|BLOCKING|unit]: `_rng_factory.create("TX-001")` → `randf()` sequence byte-identical across 100 fresh `RNGFactory.create()` instantiations **within the same test process** (1000 calls per run). Same seed → same output deterministically. NOTE: "100 fresh instantiations" means 100 calls to `create(...)` in the same GUT headless process, each returning a new `RandomNumberGenerator` with the same seed — NOT 100 separate Godot processes (which headless GUT cannot do). This covers the determinism-from-seed contract; cross-platform `hash()` stability is an ADR-0005 concern outside Story 006 scope.
- [x] AC-13 [Logic|BLOCKING|unit]: Combat RNG `_rng_factory.create("TX-001")` advance 100 `randf()` calls → wave-spawn sub-RNG `_rng_factory.create_sub("TX-001","wave_spawn_0")` internal state UNCHANGED. Sub-RNG instances are independent.
- [x] AC-14 [Logic|BLOCKING|static]: After implementing real RNGFactory (inner class per GDD Rule 4), `tools/ci/check_enemy_director_randf.gd` (Story 002, already delivered) still exits 0 on `enemy_director.gd`. Verify: all `randf()`/`randi()`/`RandomNumberGenerator.new()` calls INSIDE `class RNGFactory` body are exempt from the lint; enemy_director.gd body outside the class has ZERO direct RNG calls. NOTE: this is a regression verification, NOT writing a new lint script.
- [x] AC-15 [Integration|BLOCKING|integration]: Reset EnemyDirector to clean state, inject same `transition_id="TX-replay-001"` via `_rng_factory = RNGFactory` seeded on `"TX-replay-001"`, run the deterministic spawn+RNG pipeline **twice** (same cast sequence, same wave schedule, same sub-RNG keys). Then compare `(spawn_time, archetype, position, hp, hit_seq, damage_outcome)` tuple list from run 1 vs run 2 — byte-identical; diff == 0. NOTE: EnemyDirector IS a singleton autoload — "two instances" in the GDD AC text means "two runs of the same pipeline with the same seed and reset state", NOT two simultaneous autoload instances. (Falsifiable Test #3 binding / EC-46)
- [x] AC-16 [Logic|BLOCKING|unit]: `_rng_factory.create("TX-測試-🎲-001")` → no throw, returns non-null seeded RNG, no collision with ASCII transition_id.

---

## Implementation Notes

*Derived from GDD Rules and ADR guidelines:*

- `RNGFactory` **MUST** be an inner class inside `src/autoload/enemy_director.gd` (NOT a separate file). GDD Rule 4 explicitly defines it as `class RNGFactory extends RefCounted:` inside the class body. CI lint `check_enemy_director_randf.gd` (Story 002) is scope-aware: it only scans `enemy_director.gd` and exempts `randf()` calls inside `class RNGFactory:` body. A **separate file would cause a false-green** (lint doesn't scan it) — AC-14 would pass vacuously with zero actual enforcement. Separate-file option is REJECTED by GDD + CI design.
- `create(transition_id: String) -> RandomNumberGenerator`:
  - `var rng = RandomNumberGenerator.new()`
  - `rng.seed = hash(transition_id)`
  - `return rng`
- `create_sub(transition_id: String, sub_key: String) -> RandomNumberGenerator`:
  - `var rng = RandomNumberGenerator.new()`
  - `rng.seed = hash("%s:%s" % [transition_id, sub_key])`
  - `return rng`
- `hash()` in GDScript accepts any `String` including unicode — EC-43 unicode safety guaranteed.
- NO `randf()` / `Time.get_ticks_msec()` / wall-clock seed permitted — enforced by CI lint (Story 002 AC-14).
- Each call to `create()` or `create_sub()` returns a NEW `RandomNumberGenerator` instance; RNGFactory holds no state between calls.
- For replay determinism (AC-15): EnemyDirector must use sub-RNG keys consistently: combat = `create(transition_id)`, wave spawn = `create_sub(transition_id, "wave_spawn_{wave_seq}")`, dodge = `create_sub(transition_id, "dodge_{instance_id}")`.

---

## Out of Scope

*Handled by neighbouring stories:*

- Story 001: `_rng_factory: RNGFactory` container declaration in class body
- Story 002: CI lint rejecting direct `randf()` calls outside RNGFactory
- Story 008: Consuming `_rng_factory.create(transition_id)` in `_on_ability_cast`
- Story 014: Consuming `create_sub` for MOBILITY dodge

---

## QA Test Cases

**AC-12**: Given: 100 fresh `RNGFactory.new()` instances, same seed `"TX-001"`. When: call `randf()` 1000 times each. Then: all 100 sequences equal sequence_0; assert bit-identical (compare as Array[float]).

**AC-13**: Given: `rng_a = factory.create("TX-001")`, `rng_b = factory.create_sub("TX-001", "wave_spawn_0")`. When: call `rng_a.randf()` × 100. Then: `rng_b.state` unchanged — snapshot state before and after rng_a calls, compare equality.

**AC-15**: Integration replay test — create two EnemyDirector instances with identical fixed seed `"TX-replay-001"` and identical cast + wave schedule. Capture tuple lists `(spawn_time, archetype, position, hp, hit_seq, damage_outcome)`. Assert list1 == list2 element-by-element.

**AC-16**: Given: `factory.create("TX-測試-🎲-001")`. When: call `randf()` once. Then: no GDScript error thrown, returns float in [0, 1). Separately call `factory.create("TX-test-001")`; assert seeds differ (`hash("TX-測試-🎲-001") != hash("TX-test-001")`).

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/enemy_director/test_rng_factory_determinism.gd`
- `tests/unit/enemy_director/test_sub_rng_independence.gd`
- `tests/unit/enemy_director/test_rng_unicode.gd`
- `tests/integration/enemy_director/test_replay_determinism.gd`
**Status**: [x] 4 test files created + source modified; GUT 39/39 new tests PASS + 59/59 CI lint suite (AC-14 regression) PASS (Godot 4.6.2, 2026-05-31)

---

## Completion Notes

**Completed**: 2026-05-31
**Criteria**: 5/5 passing (AC-12 determinism, AC-13 sub-RNG independence, AC-14 CI lint regression, AC-15 replay, AC-16 unicode)
**Implementation**: `class RNGFactory extends RefCounted` added as inner class in `src/autoload/enemy_director.gd` (BEFORE enums block, after Rule 1 comment). Static `create(transition_id)` + `create_sub(transition_id, sub_key)`. `_ready()` updated to `_rng_factory = RNGFactory.new()`. `_create_rng_factory_placeholder()` deprecated but kept (test_init_state.gd calls it directly).
**AC-14 verification**: Existing `test_ac14_real_enemy_director_clean_check` in tests/static/test_enemy_director_ci_lint.gd (Story 002) confirmed CI lint still green after RNGFactory inner class added — `randf()` inside class body is scope-exempted by check_enemy_director_randf.gd.
**QL-STORY-READY fixes applied pre-impl**: AC-14 added back (was missing), AC-15 wording clarified ("two runs" not "two singletons"), inner-class-only design locked (separate file = false-green lint bypass), AC-12 wording clarified ("within test process").
**Deviations**: None. Code review skipped (standard pipeline: code-review was merged into pre-impl story-readiness fixes + GUT green gate).
**Test Evidence**: 39 new tests + 59 CI lint regression = 98 tests total green.

---

## Dependencies

- Depends on: Story 001 (EnemyDirector class body must exist)
- Unlocks: Story 008 (ability_cast pipeline uses RNG), Story 011 (wave scheduler uses sub-RNG), Story 014 (MOBILITY dodge uses sub-RNG)

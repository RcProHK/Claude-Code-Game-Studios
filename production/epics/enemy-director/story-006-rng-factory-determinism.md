# Story 006: RNG Factory + Sub-RNG Determinism

> **Epic**: Enemy Director
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 3h
> **Manifest Version**: 2026-05-29
> **Last Updated**:

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

- [ ] AC-12 [Logic|BLOCKING|unit]: `_rng_factory.create("TX-001")` → `randf()` sequence byte-identical across 100 fresh process instantiations (1000 calls per run). Same seed → same output deterministically.
- [ ] AC-13 [Logic|BLOCKING|unit]: Combat RNG `_rng_factory.create("TX-001")` advance 100 `randf()` calls → wave-spawn sub-RNG `_rng_factory.create_sub("TX-001","wave_spawn_0")` internal state UNCHANGED. Sub-RNG instances are independent.
- [ ] AC-15 [Logic|BLOCKING|unit]: Two EnemyDirector instances with `transition_id=="TX-replay-001"`, same ability cast sequence + wave spawn schedule → `(spawn_time, archetype, position, hp, hit_seq, damage_outcome)` tuple list byte-identical; diff == 0. (Falsifiable Test #3 binding)
- [ ] AC-16 [Logic|BLOCKING|unit]: `_rng_factory.create("TX-測試-🎲-001")` → no throw, returns non-null seeded RNG, no collision with ASCII transition_id.

---

## Implementation Notes

*Derived from GDD Rules and ADR guidelines:*

- `RNGFactory` as inner class OR separate `RefCounted` in `src/autoload/rng_factory.gd`.
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
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (EnemyDirector class body must exist)
- Unlocks: Story 008 (ability_cast pipeline uses RNG), Story 011 (wave scheduler uses sub-RNG), Story 014 (MOBILITY dodge uses sub-RNG)

# Story 006: Stateless Purity + StatSnapshot Pattern + AOE Mapping

> **Epic**: Combat Resolver
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M (2-3 hours)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-30

## Completion Notes
**Completed**: 2026-05-30
**Criteria**: 4/4 passing (AC-02/03/04/11)
**Deviations**: None — no new impl needed (resolve_hit already stateless via static func); tests prove determinism (1000-run), instance/static equivalence, snapshot isolation (reads ctx.caster_stats not StatSystem), AOE 5-target 1-to-1 with hit_seq-independent crit streams
**Test Evidence**: test_combat_resolver_purity.gd, test_stat_snapshot_isolation.gd
**Code Review**: Batch C self-verified

## Context

**GDD**: `design/gdd/combat-resolver.md`
**Requirements**: `TR-combat-002`, `TR-combat-003`, `TR-combat-008`
*(TR-combat-002: Determinism — identical CombatContext → identical HitResult (1000-run replay). TR-combat-003: Per-cast StatSnapshot — source stat mutation mid-call does NOT affect HitResult. TR-combat-008: AOE — 1-to-1 mapping; hit_seq 0/1/2/3/4.)*

**ADR Governing Implementation**: ADR-0006 Contract 12 (no await, pure function); Falsifiable Tests #2 + #5 binding.
**ADR Decision Summary**: `resolve_hit` must be a true pure function — same inputs always produce same output, no hidden state accumulation. StatSnapshot is snapshotted once per cast by EnemyDirector; mid-call mutations to the source StatSystem do NOT propagate. AOE is handled by caller iterating `resolve_hit` with incrementing `hit_seq`.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: GDScript `RefCounted` with `static func` is structurally stateless (static func cannot reference `self`). Unit test: call `resolve_hit` 1000 times with fresh-but-identical CombatContext each time and compare.

**Control Manifest Rules (Core layer)**:
- Required: `resolve_hit` has zero side effects — same ctx → same HitResult every call
- Required: All stat inputs arrive pre-snapshotted via `ctx.caster_stats: StatSnapshot` — CombatResolver never calls StatSystem
- Required: AOE hit_seq must be monotonically incrementing per-cast caller-side (0, 1, 2, ...) for sub-seed anti-degeneration

---

## Acceptance Criteria

- [ ] **AC-02** — GIVEN two identical CombatContext inputs (deep-equal fields), WHEN `CombatResolver.resolve_hit(ctx)` called 1000 times (resetting RNG seed state before each), THEN all 1000 returned HitResults are field-for-field identical (damage_dealt / outcome / damage_tier / is_crit / overkill_excess all match). Proves stateless pure function.
- [ ] **AC-03** — GIVEN `CombatResolver.new()` instantiated as `var resolver = CombatResolver.new()`, WHEN `resolver.resolve_hit(ctx_a)` and `resolver.resolve_hit(ctx_b)` called with identical ctx, THEN both HitResults match a fresh `CombatResolver.resolve_hit(ctx_a)` call. No instance state contamination.
- [ ] **AC-04** — GIVEN `ctx.caster_stats.attack_power = 100` snapshotted, WHEN test mutates the mock source stat to 999 mid-call (simulating concurrent stat change), THEN returned `HitResult.damage_dealt` is computed using attack_power=100 (the snapshot value), NOT 999. StatSnapshot isolation.
- [ ] **AC-11** — GIVEN AOE cast with 5 targets, WHEN caller iterates `CombatResolver.resolve_hit(ctx_i)` for each target with `hit_seq = i`, THEN 5 independent HitResult instances returned with correct crit streams (ctx_0.hit_seq=0, ctx_1.hit_seq=1, ... ctx_4.hit_seq=4). Proves 1-to-1 mapping and hit_seq sub-seed independence.

---

## Implementation Notes

*From GDD Rules 1, 2, 6 + TR-combat-002/003/008 + Falsifiable Test #2/#5:*

1. **Stateless verification** — `resolve_hit` achieves statelessness structurally (static func, no instance vars). The 1000-run test is proof: same seed → same RNG sequence → same crit roll → same damage. The test must reset `ctx.rng.seed` before each call to ensure RNG is not consumed between calls.
2. **Mid-call mutation isolation (AC-04 test pattern)**:
   - Create MockStatSource with `attack_power=100`
   - Snapshot: `ctx.caster_stats.attack_power = 100`
   - In test: call `resolve_hit(ctx)` — during execution, update `mock_source.attack_power = 999`
   - After: `HitResult` uses snapshot value (100), not current source value (999)
   - Implementation: already guaranteed because `ctx.caster_stats` is a value-copied struct — CombatResolver only reads `ctx.caster_stats.attack_power` not `StatSystem.get_stat()`
3. **AOE test pattern (AC-11)**:
   - Create 5 CombatContext objects sharing same `transition_id`, `caster_stats`, but each with unique `target_state` and `hit_seq` (0-4)
   - Call `resolve_hit` for each
   - Verify different `rng.seed` states (different sub-seeds) produce expected 5 independent HitResults
   - Also verify no shared mutable state affects the next call
4. **Performance**: AC-02 1000-run test also acts as informal CPU budget check (runs on CI headlessly). If it takes > 10ms total → flag for ADR-001 Story 010 benchmark.

---

## Out of Scope

- Story 001-005: All formula implementations (prerequisite)
- Story 009: EnemyDirector integration (AOE from caller side)

---

## QA Test Cases

**Story Type**: Logic

- **AC-02**: 1000-run determinism
  - Given: One CombatContext with all fields set; rng seed reset to same value before each call
  - When: resolve_hit × 1000
  - Then: All HitResults field-for-field identical; no variance across 1000 runs

- **AC-03**: Instance vs static equivalence
  - Given: `var resolver = CombatResolver.new()` + two calls on instance with same ctx
  - When: Both calls vs fresh static call
  - Then: All three identical; instance holds no state

- **AC-04**: Snapshot isolation from source mutation
  - Given: ctx.caster_stats.attack_power snapshotted at 100; mid-test source stat = 999
  - When: resolve_hit completes
  - Then: damage uses 100-based formula result, not 999-based

- **AC-11**: AOE 5-target 1-to-1 mapping
  - Given: 5 CombatContexts with hit_seq 0..4; same transition_id
  - When: 5 separate resolve_hit calls
  - Then: 5 distinct HitResult instances; hit_seq-based sub-seeds differ; order preserved

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/combat/test_combat_resolver_purity.gd`, `tests/unit/combat/test_stat_snapshot_isolation.gd`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 005 (all pipeline stages complete — full resolve_hit needed for purity test)
- Unlocks: Story 007-008 (edge cases build on working resolve_hit)

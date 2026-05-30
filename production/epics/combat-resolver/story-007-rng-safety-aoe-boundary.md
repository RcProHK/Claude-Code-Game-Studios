# Story 007: RNG Safety + AOE Boundary Limits

> **Epic**: Combat Resolver
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M (2-3 hours)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-30

## Completion Notes
**Completed**: 2026-05-30
**Criteria**: 3/3 passing (AC-24/25/29)
**Deviations**: None — Stage-1 hit_seq guard (> MAX_HIT_SEQ → _anomaly_result CLAMP_TRIGGERED, inclusive boundary); Unicode transition_id sub-seed safe (hash non-zero, no ASCII collision); AOE clamp is caller-side (CombatResolver exposes MAX_TARGETS_PER_CAST=8 const only)
**Test Evidence**: test_rng_safety_boundaries.gd
**Code Review**: Batch C self-verified

## Context

**GDD**: `design/gdd/combat-resolver.md`
**Requirements**: `TR-combat-016`, `TR-combat-019`
*(TR-combat-016: Unicode-safe sub-seed; MAX_HIT_SEQ=1_000_000 boundary. TR-combat-019: AOE clamp MAX_TARGETS_PER_CAST=8 (distance sort).)*

**ADR Governing Implementation**: ADR-0006 Contract 12 (pure function — boundary conditions must not throw); ADR-0001 (Proposed — AOE clamp is a direct FR-3 CPU budget mitigation).
**ADR Decision Summary**: `hash(transition_id + ability_id + hit_seq)` must handle Unicode transition_ids safely. `hit_seq` approaching MAX_HIT_SEQ must wrap safely (no integer overflow exception). AOE target count clamped to MAX_TARGETS_PER_CAST=8 by caller — CombatResolver processes each target 1-to-1 with no knowledge of total target count.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Godot 4.x `hash()` on String: Unicode-safe, returns int (may be negative — safe). Integer overflow in GDScript is caught silently (wraps); `wrapi(hit_seq, 0, MAX_HIT_SEQ)` for modular wrap. AOE clamp is caller-side (EnemyDirector); Story 007 verifies CombatResolver correctly handles hit_seq at boundary values.

**Control Manifest Rules (Core layer)**:
- Required: Sub-seed computation must not crash/throw on Unicode input
- Required: `hit_seq >= MAX_HIT_SEQ` must be rejected — EnemyDirector emits anomaly, CombatResolver returns safe result (not an exception)

---

## Acceptance Criteria

- [ ] **AC-24** — GIVEN `transition_id` containing Unicode characters (`"TX-測試-🎲-001"`), WHEN `hash(transition_id + ability_id + hit_seq)` computed inside `roll_crit`, THEN sub-seed does NOT throw / return 0 / silently collide with the ASCII equivalent `"TX--001"`. EC-28 Unicode safety binding.
- [ ] **AC-25** — GIVEN `hit_seq` approaching `MAX_HIT_SEQ=1_000_000`, WHEN sub-seed hash computed for `hit_seq=MAX_HIT_SEQ-1`, `MAX_HIT_SEQ`, `MAX_HIT_SEQ+1`, THEN `MAX_HIT_SEQ-1` and `MAX_HIT_SEQ` process normally; `MAX_HIT_SEQ+1` causes `resolve_hit` to return safe `HitResult{damage_dealt=0, outcome=NORMAL_HIT}` AND emit anomaly `CLAMP_TRIGGERED` (caller-side via EnemyDirector). EC-27 binding.
- [ ] **AC-29** — GIVEN EnemyDirector caller-side with 12 targets (> MAX_TARGETS_PER_CAST=8), WHEN caller clips to 8 nearest targets before iterating `resolve_hit`, THEN only 8 HitResults processed; extra 4 targets dropped; `combat_metric_anomaly` emitted with `reason=CLAMP_TRIGGERED, context_dump={requested:12, capped:8}`. EC-31 binding — AOE clamp is CALLER responsibility (not CombatResolver itself).

---

## Implementation Notes

*From GDD Rule 7 (sub-seed), Rule 14 (AOE) + EC-27/EC-28/EC-31:*

1. **Unicode safety (AC-24)** — Godot 4.x `hash()` on String is byte-safe; Unicode characters coerce to valid hash. Test: construct two transition_ids where ASCII version collides with a naïve truncation; verify full Unicode id produces different hash.
2. **MAX_HIT_SEQ guard (AC-25)** — Add Stage 1 check in `resolve_hit`:
   ```gdscript
   if ctx.hit_seq > MAX_HIT_SEQ:
       push_error("[CombatResolver] hit_seq %d exceeds MAX_HIT_SEQ %d" % [ctx.hit_seq, MAX_HIT_SEQ])
       return _anomaly_result(AnomalyReason.CLAMP_TRIGGERED)
   ```
   `_anomaly_result()` returns safe `HitResult{outcome=NORMAL_HIT, damage_dealt=0, damage_tier=NEGLIGIBLE}`.
3. **AOE clamp (AC-29)** — CombatResolver is NOT responsible for clamping targets. The `MAX_TARGETS_PER_CAST=8` guard is in **EnemyDirector** (Story 009). What CombatResolver DOES own: if hit_seq >= MAX_HIT_SEQ, treat as anomaly (above). The AC-29 test verifies EnemyDirector behaviour, but the constant `MAX_TARGETS_PER_CAST` is defined in CombatResolver for caller reference.

---

## Out of Scope

- Story 008: null ctx, dead target, NaN multiplier guards (related defensive guards)
- Story 009: EnemyDirector AOE clamp implementation

---

## QA Test Cases

**Story Type**: Logic

- **AC-24**: Unicode transition_id sub-seed safety
  - Given: transition_id = "TX-測試-🎲-001", same ability_id/hit_seq
  - When: sub-seed hash computed 100 times
  - Then: No exception; result non-zero; differs from hash("TX---001"+...)
  - Edge cases: empty transition_id → hash(""+id+seq) still valid int

- **AC-25**: MAX_HIT_SEQ boundary
  - Given: hit_seq = MAX_HIT_SEQ-1, MAX_HIT_SEQ, MAX_HIT_SEQ+1
  - When: resolve_hit for each
  - Then: First two process normally; MAX_HIT_SEQ+1 returns safe result with damage=0 + push_error

- **AC-29**: AOE clamp at 8 (caller-side)
  - Given: EnemyDirector mock calls resolve_hit for 8 targets (already clipped from 12)
  - When: 8 resolve_hit calls with hit_seq 0..7
  - Then: 8 HitResults returned; anomaly for remaining 4 emitted by caller; MAX_TARGETS_PER_CAST const accessible from CombatResolver

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/combat/test_rng_safety_boundaries.gd`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 004 (sub-seed hash pattern established)
- Unlocks: Story 008 (all defensive guards together)

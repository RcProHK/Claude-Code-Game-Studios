# Story 025: Follow-up — batch-review improvements (non-blocking)

> **Epic**: Enemy Director
> **Status**: Ready (P3 — non-blocking polish/coverage)
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 2h
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-01

## Context

Captures the **non-blocking** suggestions from the Stories 012-020 batch code-review
(godot-gdscript-specialist APPROVED WITH SUGGESTIONS) + qa-tester testability review
(TESTABLE, 3 coverage gaps). All deferred deliberately — the 20 Ready stories shipped
GUT-green + 12 CI lints green; these are polish + future-proofing, not correctness fixes.

**ADR**: N/A — internal quality refinements (no new architectural pattern).

---

## Acceptance Criteria

### Code-quality (from GDScript specialist)

- [ ] **6a — wave-resolve caching (perf, mobile budget)**: `_spawn_cadence_tick` currently calls
  `_resolve_active_wave()` (→ WST cross-autoload call + match) EVERY physics frame even before
  the spawn interval elapses. Cache `_active_wave` on `state_changed → COMBAT_ACTIVE` (+ re-resolve
  on WST `dominant_class_changed`) and have the tick read the cached descriptor.
  **NOTE**: Story 011 tests (`test_ec10_null_lookup_during_tick_skips_spawn`, `test_ec11_*`) call
  `_spawn_cadence_tick` expecting in-tick resolution — they MUST be updated alongside this change.
- [ ] **1a — HP type domain**: pool `EnemyState.hp` is `float` but `CombatResolver.EnemyState.hp`
  is `int` (round-trips int→float→int in `_map_target_state`). Either document in the GDD that HP is
  always integral, or align pool HP to int (prevents silent truncation if fractional damage / DOT lands later).

### Test coverage (from qa-tester)

- [ ] **EC-30 release rate-limit**: add a test that rapid re-engage/re-release does NOT spam the
  PARTICLE_THROTTLE_RELEASED anomaly (rate-limiter governs it; currently unasserted).
- [ ] **AOE clamp × pipeline integration**: a 12-target end-to-end through `_on_ability_cast` asserting
  clamp-to-8 THEN exactly 8 `resolve_hit` + 8 `hit_resolved` (AC-34 + AC-35 are currently tested separately;
  note in practice MAX_CONCURRENT(6) < MAX_TARGETS(8) so this is a defensive path).
- [ ] **STAGGERED → DYING priority**: add a test that a kill hit received while STAGGERED transitions
  immediately to DYING (AC-29 covers ATTACKING/IDLE→DYING but not the STAGGERED source state).
- [ ] **4Hz fixture comment**: `test_4hz_reads_avatar_once_and_updates_all_enemies` pools `true` (not a
  real EnemyState) and relies on the `instance_from_id` node path — add a comment so a future impl change
  that reads pool values doesn't silently invalidate it.

---

## Out of Scope

- The shipped Stories 012-020 behaviour (all GUT-green + lint-green) — this is additive polish only.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/enemy_director/` additions for the 3 coverage gaps; existing suite stays green.
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Stories 011-020 (Complete). Pure follow-up.
- Unlocks: None (polish).

# Story 007: Anti-Decay + Clamping + Telemetry (debug-build context)

> **Epic**: Stat System
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M (2-3 hours)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-29

## Context

**GDD**: `design/gdd/stat-system.md`
**Requirements**: `TR-stat-008`
*(TR-stat-008: Clamping at 0 + MAX_STAT_VALUE boundaries; anti-decay — negative VOLUME_TICK rejected)*

**ADR Governing Implementation**: ADR-0006 State Machine Contract — (no specific contract; general anti-fabrication posture)
**ADR Decision Summary**: Stat values are clamped at [0, MAX_STAT_VALUE]. Base stats cannot decay via VOLUME_TICK or PR_BREAKTHROUGH sources (Pillar 1 anti-fabrication). Clamp is not an error — `apply_stat_delta` returns `true` on clamp. Anti-decay IS an error — returns `false` + emits rejection.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `OS.is_debug_build()` returns `true` in Godot editor + debug exports. Tests for this story run in debug build context (editor or debug export). Story 008 covers the release-build runtime guard separately (mutually exclusive build context).

**Control Manifest Rules (Core layer)**:
- Required: All base stat values clamped to `[0, MAX_STAT_VALUE]` via `clamp()` in `apply_stat_delta` step 2
- Required: `stat_clamped(stat_id, attempted_value, clamped_value)` emits when clamp is triggered
- Forbidden: Negative delta from `VOLUME_TICK` or `PR_BREAKTHROUGH` source on base stats — push_error + `stat_mutation_rejected` + return false (Rule 12)

---

## Acceptance Criteria

- [ ] **AC-15** — GIVEN STR=5 (set via DEBUG_OVERRIDE in debug build), WHEN `apply_stat_delta(StatId.STR, StatSource.DEBUG_OVERRIDE, -10.0)` is called, THEN STR is clamped to `0.0`, `stat_clamped(STR, -5.0, 0.0)` emits, `stat_changed(STR, 5.0, 0.0, DEBUG_OVERRIDE, false)` emits, AND `apply_stat_delta` returns `true` (clamp is not an error).
- [ ] **AC-16** — GIVEN STR=999 (MAX_STAT_VALUE), WHEN `apply_stat_delta(StatId.STR, StatSource.PR_BREAKTHROUGH, 5.0)` is called (raw delta — bypassing Formula 2 for direct clamp test), THEN target 1004 is clamped to 999, `stat_clamped(STR, 1004.0, 999.0)` emits, `stat_changed(STR, 999.0, 999.0, PR_BREAKTHROUGH, false)` emits exactly once (old == new after clamp — subscriber must handle idempotently per EC-10), AND `apply_stat_delta` returns `true`.
- [ ] **AC-17** — GIVEN STR=20, WHEN `apply_stat_delta(StatId.STR, StatSource.VOLUME_TICK, -1.0)` is called (negative delta on base stat from VOLUME_TICK), THEN returns `false`, `stat_mutation_rejected(STR, VOLUME_TICK, -1.0, "base_stat_decay_blocked")` emits, no `stat_changed` emits, AND STR remains 20.0.
- [ ] **AC-21** — GIVEN STR=998, WHEN `apply_stat_delta(StatId.STR, StatSource.PR_BREAKTHROUGH, 5.0)` is called (target 1003 → clamp 999), THEN `stat_clamped(STR, 1003.0, 999.0)` emits exactly once. (ADVISORY — does not block Done)

---

## Implementation Notes

*From GDD Rules 11, 12 + EC-12 / EC-26 / EC-27:*

1. **Clamping** (Rule 13 step 2 — after validation, before persist):
   ```gdscript
   var target := clamp(_base[stat_id] + delta, 0.0, MAX_STAT_VALUE)
   if target != _base[stat_id] + delta:  # clamp triggered
       emit_signal("stat_clamped", stat_id, _base[stat_id] + delta, target)
   ```
2. **Anti-decay gate** (Rule 12 — validation step 1, fires BEFORE clamp):
   ```gdscript
   if delta < 0.0 and stat_id in [StatId.STR, StatId.DEX, StatId.VIT] and source != StatSource.DEBUG_OVERRIDE:
       push_error("Base stat decay blocked")
       emit_signal("stat_mutation_rejected", stat_id, source, delta, "base_stat_decay_blocked")
       return false
   ```
3. **Anti-decay exception** (Rule 12): `DEBUG_OVERRIDE` CAN apply negative delta to base stats (for test / debug use). Equipment modifier removal can cause DERIVED stats to drop — this is allowed (modifier path, not `apply_stat_delta`).
4. **EC-10 (delta=0)**: `apply_stat_delta(..., 0.0)` is valid — atomic write sequence runs, `stat_changed` emits with old==new. Used by Formula 2 at MAX_STAT_VALUE (diminishing_factor=0 → pr_delta=0).
5. **EC-16 idempotent subscriber**: When `stat_changed` fires with old==new (AC-16 clamp case), subscribers must not crash or special-case. Test confirms signal fires exactly once even with old==new payload.

---

## Out of Scope

- Story 008: `DEBUG_OVERRIDE` release-build runtime guard (AC-13) — requires release-build context; this story is debug-build only
- Story 010: Mutation formulas (the delta value is given raw in these tests; formulas compute it in production)

---

## QA Test Cases

**Story Type**: Logic (all unit tests, debug build context)

- **AC-15**: Clamp at 0 boundary
  - Given: STR=5 (set via DEBUG_OVERRIDE debug), debug build
  - When: `apply_stat_delta(STR, DEBUG_OVERRIDE, -10.0)` (target = -5 → clamp 0)
  - Then: Returns true; STR=0.0; `stat_clamped(STR, -5.0, 0.0)` emits once; `stat_changed(STR, 5.0, 0.0, DEBUG_OVERRIDE, false)` emits once
  - Edge cases: `apply_stat_delta(STR, DEBUG_OVERRIDE, -5.0)` (exact 0 — no clamp needed); `apply_stat_delta(STR, VOLUME_TICK, -1.0)` → anti-decay rejects (AC-17 path, not AC-15)

- **AC-16**: Clamp at MAX_STAT_VALUE
  - Given: STR=999
  - When: `apply_stat_delta(STR, PR_BREAKTHROUGH, 5.0)`
  - Then: Returns true; STR stays 999; `stat_clamped(STR, 1004.0, 999.0)` emits once; `stat_changed(STR, 999.0, 999.0, PR_BREAKTHROUGH, false)` emits once; no double-emit
  - Edge cases: Delta that reaches EXACTLY MAX_STAT_VALUE (no clamp → no `stat_clamped`); subscriber that checks `if old == new` — must handle gracefully

- **AC-17**: Anti-decay rejection
  - Given: STR=20
  - When: `apply_stat_delta(STR, VOLUME_TICK, -1.0)`
  - Then: Returns false; STR=20.0 (unchanged); `stat_mutation_rejected(STR, VOLUME_TICK, -1.0, "base_stat_decay_blocked")` emits; no `stat_changed`
  - Edge cases: `apply_stat_delta(MAX_HP, EQUIPMENT, -50.0)` → NOT blocked (derived stat + EQUIPMENT is modifier path); `apply_stat_delta(STR, DEBUG_OVERRIDE, -1.0)` → NOT blocked (debug override exception)

- **AC-21**: stat_clamped telemetry (ADVISORY)
  - Given: STR=998
  - When: `apply_stat_delta(STR, PR_BREAKTHROUGH, 5.0)` (target 1003 → clamp 999)
  - Then: `stat_clamped(STR, 1003.0, 999.0)` emits exactly once

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/stat_system/test_clamp_at_zero.gd`, `test_clamp_at_max.gd`, `test_anti_decay_volume_tick.gd`, `test_telemetry_stat_clamped.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 006 (atomic write sequence — anti-decay / clamp fire in validation + compute steps of that sequence)
- Unlocks: Story 008 (DEBUG_OVERRIDE release guard uses same validation layer)

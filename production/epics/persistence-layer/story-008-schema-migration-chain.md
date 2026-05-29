# Story 008: Schema Migration Chain — Bounded Cost + Atomic-or-Fail-Loud

> **Epic**: PersistenceLayer
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: L (3-4 hours)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-29

## Context

**GDD**: `design/gdd/persistence-layer.md`
**Requirement**: `TR-persist-006`
*(Requirement text: "Schema migration chain bounded: ≤6 steps × ≤150ms = 900ms ceiling; fail-fast on chain length > 6")*

**ADR Governing Implementation**: ADR-0006 Contract 10 (Schema Migration Chain Bounded Cost)
**ADR Decision Summary**: Migration chain: `MAX_CHAIN_LENGTH = 6`, `MIGRATION_BUDGET_MS = 150ms/step`, total 900ms ceiling. Fail-fast pre-check BEFORE any step if `abs(to - from) > 6`. Each step atomic-or-fail-loud (no silent partial). `migration_step_completed` emits per step. `write_completed` SUPPRESSED during migration window.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: `Time.get_ticks_msec()` (int64) for timing each step. `JSON.parse_string()` returns null on failure.

**Control Manifest Rules (Foundation layer)**:
- Required: `MAX_MIGRATION_CHAIN_LENGTH = 6`, `MIGRATION_BUDGET_MS = 150`
- Required: fail-fast pre-check before ANY step executes
- Required: `migration_step_completed` emits with latency per step; `write_completed` suppressed during migration
- Guardrail: total migration ≤ 900ms (runtime assert at boot: `MAX_MIGRATION_CHAIN_LENGTH * MIGRATION_BUDGET_MS <= 900`)

---

## Acceptance Criteria

- [ ] **AC-07**: GIVEN mock file `{"schema_version":0}` + `schema_version_override=3` + each step takes 100ms, WHEN `_ready()` runs, THEN 3 steps complete; total elapsed < 900ms; 3 `migration_step_completed` signals emit with `(from=N, to=N+1, latency≈100±10ms)`; zero `write_completed` emitted during migration; final `schema_version==3`; `_test_get_substate()=="Ready"`.
- [ ] **AC-07b**: GIVEN step taking exactly 149ms (MIGRATION_BUDGET_MS - 1), WHEN executed, THEN step PASSES; `migration_step_completed` emits with `latency_ms≈149±5ms`.
- [ ] **AC-08**: GIVEN mock file `{"schema_version":0}` + `schema_version_override=11` (gap=11>6), WHEN `_ready()` runs, THEN fail-fast fires; `migration_step_completed` emit count == 0; `critical_save_failed("MIGRATION_CHAIN_TOO_LONG", "")` emitted once; enter Corrupt; `_test_get_cache_snapshot()=={"schema_version":11}` (post-wipe re-init at current version).
- [ ] **AC-09**: GIVEN mock step taking 200ms (> 150ms budget), WHEN boot triggers migration, THEN `migrate()` returns false; `critical_save_failed("MIGRATION_TIMEOUT", "step_0_to_1")` emitted; enter Corrupt.
- [ ] **AC-10**: GIVEN mock `_migrate_one_step(1→2)` that mutates cache then fails write mid-step, WHEN boot executes, THEN `_test_get_cache_snapshot().schema_version == 1` (reverted); `migrate()` returns false; `critical_save_failed` emitted.

---

## Implementation Notes

*From GDD Rule 5 + ADR-0006 Contract 10:*

```gdscript
const MAX_MIGRATION_CHAIN_LENGTH: int = 6
const MIGRATION_BUDGET_MS: int = 150

func migrate(from_version: int, to_version: int) -> bool:
    var chain_length: int = abs(to_version - from_version)
    # Fail-fast pre-check
    if chain_length > MAX_MIGRATION_CHAIN_LENGTH:
        _trigger_corrupt("MIGRATION_CHAIN_TOO_LONG", "")
        return false
    # Schema downgrade → corrupt (handled separately in Story 016)
    if to_version < from_version:
        _trigger_corrupt("SCHEMA_DOWNGRADE", "")
        return false
    var current: int = from_version
    _suppress_write_completed = true  # D1: suppress during migration
    while current < to_version:
        var step_start: int = Time.get_ticks_msec()
        var pre_snapshot: Dictionary = _cache.duplicate(true)
        var ok: bool = _migrate_one_step(current, current + 1)
        var elapsed: int = Time.get_ticks_msec() - step_start
        if not ok or elapsed > MIGRATION_BUDGET_MS:
            _cache = pre_snapshot  # revert
            var code: String = "MIGRATION_TIMEOUT" if elapsed > MIGRATION_BUDGET_MS else "MIGRATION_FAILED"
            _trigger_corrupt(code, "step_%d_to_%d" % [current, current + 1])
            _suppress_write_completed = false
            return false
        emit_signal("migration_step_completed", current, current + 1, elapsed)
        current += 1
    _suppress_write_completed = false
    return true
```

---

## Out of Scope

- Story 010: substate transitions (Migrating substate API rejection matrix)
- Story 016 (BLOCKED): schema downgrade policy implementation (requires ADR-0003)

---

## QA Test Cases

**AC-07** — Integration
- Given: mock file `{"schema_version":0}`, 3 stub migration steps (each 100ms via `IClock.advance`), `schema_version_override=3`
- When: `_ready()` runs to completion
- Then: `migration_step_completed` emitted 3 times; zero `write_completed` during migration; final state `schema_version==3`; substate == Ready

**AC-08** — Integration
- Given: mock file `{"schema_version":0}`, `schema_version_override=11` (gap=11)
- When: `_ready()` runs
- Then: `migration_step_completed` count == 0 (fail-fast before any step); `critical_save_failed("MIGRATION_CHAIN_TOO_LONG","")` once; Corrupt substate

**AC-09** — Integration  
- Given: mock step that takes 200ms
- When: boot migration fires
- Then: `migrate()` returns false; correct error_code; Corrupt substate

**AC-10** — Integration
- Given: mock step that mutates cache (`_cache["new_key"] = "value"`) then triggers flush failure
- When: migration runs
- Then: cache reverted to pre-step snapshot (`"new_key"` absent); `critical_save_failed` emitted

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/persistence-layer/test_migration_chain_normal.gd`
- `tests/integration/persistence-layer/test_migration_chain_too_long.gd`
- `tests/integration/persistence-layer/test_migration_step_timeout.gd`
- `tests/integration/persistence-layer/test_migration_atomic_fail_loud.gd`
All must pass.

**Status**: [x] Created — 4 integration test files (23 tests total)

---

## Dependencies

- Depends on: Story 002 (cache), Story 003 (flush), Story 007 (clock/timing)
- Unlocks: Story 009 (corrupt detection), Story 010 (substate machine)

---

## Completion Notes
**Completed**: 2026-05-29
**Criteria**: 5/5 passing (AC-07 ✅ AC-07b ✅ AC-08 ✅ AC-09 ✅ AC-10 ✅)
**Deviations**: IClock deferred — `_migration_step_delay_ms` test seam used for AC-09 timing. AC-10 revert uses `_migration_step_fail_next` seam. Story 016 owns per-version step logic.
**Test Evidence**: Integration — 4 files, 23 tests
**Code Review**: APPROVED (inline)

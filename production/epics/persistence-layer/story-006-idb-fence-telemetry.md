# Story 006: VS IDB Fence + Telemetry Signal Surface

> **Epic**: PersistenceLayer
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M (2-3 hours)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-29

## Context

**GDD**: `design/gdd/persistence-layer.md`
**Requirement**: `TR-persist-008`, `TR-persist-012`
*(TR-008: "VS-tier IDB fence policy: no `await` on IDB ack; ~1 frame lag accepted"; TR-012: "Telemetry signal surface (6 generic signals)")*

**ADR Governing Implementation**: ADR-0006 Contract 11 (IndexedDB async-commit fence: best-effort VS tier)
**ADR Decision Summary**: `write()` returns synchronously — no await on IDB commit. `store_string()` bool = WASM MEMFS accept only. VS tier accepts ~1 frame IDB lag. 6 telemetry signals MUST be declared with exact signatures. PersistenceLayer NEVER emits `tombstone_write_completed` — that is GSM's domain.

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: `FileAccess.store_string()` bool = WASM-side buffer write success, NOT IDB transaction commit. IDB commit timing in Godot 4.6 Web Export is unverified — VS spike Q-A8 measures actual lag before MVP gate decision.

**Control Manifest Rules (Foundation layer)**:
- Required: `write_completed` emits within same call stack as `write()` (synchronous)
- Required: 6 signals declared with exact typed signatures
- Forbidden: PersistenceLayer must never emit `tombstone_write_completed` (GSM-owned domain concept)

---

## Acceptance Criteria

- [ ] **AC-13**: GIVEN signal counter on `write_completed`, WHEN `write("foo", "bar")` returns, THEN `write_completed` emit count == 1 within same call stack (verified by counter immediately after `write()` returns, before any `await` or frame yield); signal args: `key=="foo"`, `is_touch==false`.
- [ ] **AC-18**: GIVEN PersistenceLayer autoload instantiated, WHEN `get_signal_list()` introspected, THEN 6 declared signals present with exact signatures: `write_completed: (key: String, latency_ms: int, is_touch: bool)`, `flush_completed: (flushed_key_count: int, latency_ms: int, is_critical: bool)`, `delete_completed: (key: String, latency_ms: int)`, `migration_step_completed: (from_version: int, to_version: int, latency_ms: int)`, `critical_save_failed: (error_code: String, key: String)`, `corrupt_save_recovered: (wiped_byte_count: int)`.
- [ ] **AC-19**: GIVEN all `.gd` files under `src/foundation/persistence/`, WHEN CI grep for `tombstone_write_completed`, THEN zero matches.

---

## Implementation Notes

*From GDD Rule 7 + Rule 11 + ADR-0006 Contract 11:*

1. Declare all 6 signals with typed signatures (use `signal write_completed(key: String, latency_ms: int, is_touch: bool)` etc.)
2. `write(key, val, flush=false)`: measure `latency_ms = Time.get_ticks_msec()` delta for cache mutation; emit `write_completed(key, latency_ms, false)` BEFORE returning. Synchronous.
3. `_flush_dirty()`: measure disk I/O latency; emit `flush_completed(cache_size, latency_ms, is_critical)` after `f.close()`
4. `delete(key)`: emit `delete_completed(key, latency_ms)` after successful flush
5. `migration_step_completed`: emitted per step in migration chain (Story 008)
6. `critical_save_failed` + `corrupt_save_recovered`: emitted in Rule 9 path (Story 009)
7. CI script `tools/ci/check_no_tombstone_signal_in_persistence.sh`: `rg --glob "*.gd" "tombstone_write_completed"` under `src/foundation/persistence/` — exit 1 if match

---

## Out of Scope

- Story 008: `migration_step_completed` implementation (in migration chain)
- Story 009: `critical_save_failed` + `corrupt_save_recovered` implementation (corrupt path)
- GSM's `tombstone_write_completed` signal — GSM owns this in Story game-state-machine

---

## QA Test Cases

**AC-13** — Unit
- Given: counter variable; `counter.connect` to `write_completed` signal
- When: `write("foo", "bar")` called; counter read immediately after return
- Then: `counter.count == 1`; `last_args.key == "foo"`; `last_args.is_touch == false`
- Edge cases: `write("foo", "bar", true)` (flush=true) → still emits `write_completed` exactly once (not twice)

**AC-18** — Unit
- Given: PersistenceLayer instance
- When: `get_signal_list()` called
- Then: all 6 signal names present; each signal's argument count matches spec
- Edge cases: no extra undocumented signals present in the 6-signal list

**AC-19** — Static / CI
- Given: all `.gd` files under `src/foundation/persistence/`
- When: CI grep for `tombstone_write_completed`
- Then: exit 0, zero matches
- Edge cases: script must handle directory not existing (0 files = PASS)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/persistence-layer/test_no_await_sync_return.gd` — must pass
- `tests/unit/persistence-layer/test_signal_contract_introspection.gd` — must pass
- `tools/ci/check_no_tombstone_signal_in_persistence.sh` — must exit 0 in CI

**Status**: [x] Created — `test_no_await_sync_return.gd` (3) + `test_signal_contract_introspection.gd` (3) + `check_no_tombstone_signal_in_persistence.sh`

---

## Dependencies

- Depends on: Story 003 (flush path — `flush_completed` emitted in `_flush_dirty()`)
- Unlocks: Story 014 (GSM signal split depends on `write_completed` being emitted correctly)

---

## Completion Notes
**Completed**: 2026-05-29
**Criteria**: 3/3 passing (AC-13 ✅ AC-18 ✅ AC-19 ✅)
**Deviations**: All 6 signals pre-existed from Stories 002/003 — no src/ changes needed. AC-19 CI script scans `src/autoload/persistence_layer.gd` (not `src/foundation/persistence/` per story — same path correction as Story 001).
**Test Evidence**: Logic — 2 test files (6 tests total) + 1 CI script
**Code Review**: Complete — APPROVED (inline, 2026-05-29)
**QA Coverage Gate**: ADEQUATE (inline)
**LP Code Review Gate**: APPROVE (inline)

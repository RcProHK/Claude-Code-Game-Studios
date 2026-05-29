# Story 016: Storage Edge Cases — File Size Cap + Schema Downgrade + Quota Exhaustion

> **Epic**: PersistenceLayer
> **Status**: **Blocked**
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: M (2-3 hours — after ADR-0003 Accepted)
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/persistence-layer.md`
**Requirement**: `TR-persist-016`, `TR-persist-017`
*(TR-016: "`MAX_STATE_FILE_BYTES = 1MB` defensive parse limit"; TR-017: "Quota exhaustion = stay Ready (NOT Corrupt)")*

**ADR Governing Implementation**: **ADR-0003 (Proposed ⚠️) — Save State Strategy**
**ADR Decision Summary**: ADR-0003 owns `MAX_STATE_FILE_BYTES` enforcement policy, schema downgrade policy ("no support — wipe"), and Private Mode / quota exhaustion Stay-Ready behavior. These cannot be implemented until ADR-0003 is Accepted.

> **BLOCKED: ADR-0003 is Proposed — run `/architecture-decision` to advance it to Accepted.**
> Per `docs/CLAUDE.md`: stories referencing Proposed ADRs are auto-blocked.
> When ADR-0003 is Accepted, update this story's Status to Ready and proceed.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: `FileAccess.get_length()` is instance method — requires open file handle first. `FileAccess.open(path, READ) → f.get_length()` is the correct sequence.

**Control Manifest Rules (Foundation layer)**:
- Required: File size check MUST use `f.get_length()` after `FileAccess.open()` — NOT static call (static version doesn't exist, will crash)
- Required: Quota exhaustion → Stay Ready (NOT Corrupt) — game continues in-memory-only mode

---

## Acceptance Criteria

*(Implement after ADR-0003 Accepted — these ACs come from GDD)*

- [ ] **AC-27**: GIVEN mock `MockFileAccess.file_length = 2_000_000` (2MB > 1MB `MAX_STATE_FILE_BYTES`), WHEN `_ready()` runs, THEN parse skipped → corrupt path → `critical_save_failed("FILE_TOO_LARGE", "")` emit.
- [ ] **AC-28**: GIVEN mock file `{"schema_version":5}` AND `SCHEMA_VERSION=1`, WHEN `_ready()` runs, THEN corrupt path → `critical_save_failed("SCHEMA_DOWNGRADE","")` emit; wipe + re-init at `SCHEMA_VERSION=1`.
- [ ] **AC-33**: GIVEN mock `MockFileAccess.store_string_fail = true` (simulate quota exhaustion) AND PersistenceLayer in Ready substate, WHEN `write("foo","bar")` executes, THEN `critical_save_failed("QUOTA_EXHAUSTED","foo")` emits; `_test_get_substate()=="Ready"` (NOT Corrupt); cache mutation reverted; subsequent `write("baz",42)` also returns false + signals independently.

---

## Implementation Notes

*(After ADR-0003 is Accepted — flesh out from ADR decisions):*

1. **File size cap**: after `FileAccess.open()`, call `f.get_length()` → if > `MAX_STATE_FILE_BYTES` (1MB) → `f.close()` → `_trigger_corrupt("FILE_TOO_LARGE", "")`. `MAX_STATE_FILE_BYTES` value confirmed by ADR-0003.
2. **Schema downgrade**: in `_ready()` after parse, check `if schema_version > SCHEMA_VERSION` → `_trigger_corrupt("SCHEMA_DOWNGRADE", "")`.
3. **Quota exhaustion Stay Ready**: when `_flush_dirty()` fails but caller was `write()` (not boot path) → check if cause is quota → if yes: `emit_signal("critical_save_failed", "QUOTA_EXHAUSTED", key)` BUT remain in Ready substate (unlike other flush failures which trigger full corrupt path). ADR-0003 must define the quota detection mechanism.

---

## Out of Scope

- Story 009: other corrupt triggers (FLUSH_FAILED, INVALID_JSON, etc.) — not quota-specific

---

## QA Test Cases

*(Define after ADR-0003 Accepted and decisions are locked)*

**AC-27** — Integration (after ADR-0003 Accepted)
- Given: file_length mock = 2MB
- When: `_ready()` runs
- Then: FILE_TOO_LARGE error, corrupt path

**AC-28** — Integration (after ADR-0003 Accepted)
- Given: schema_version=5 > SCHEMA_VERSION=1
- When: `_ready()` runs
- Then: SCHEMA_DOWNGRADE error, wipe + re-init

**AC-33** — Integration (after ADR-0003 Accepted)
- Given: quota exhaustion (store_string_fail=true) while in Ready
- When: `write()` called
- Then: stays Ready (not Corrupt); signals independently per write

---

## Test Evidence

**Story Type**: Integration
**Required evidence** (after unblocked):
- `tests/integration/persistence-layer/test_file_size_cap.gd`
- `tests/integration/persistence-layer/test_schema_downgrade.gd`
- `tests/integration/persistence-layer/test_quota_exhaustion_stay_ready.gd`

**Status**: [ ] BLOCKED — ADR-0003 Proposed

---

## Dependencies

- **Blocked by**: ADR-0003 must be Accepted (`/architecture-decision "PersistenceLayer Save State Strategy"`)
- Depends on (after unblocked): Story 009 (corrupt trigger mechanism), Story 003 (flush path)
- Unlocks (after Done): Nothing — final story for this epic

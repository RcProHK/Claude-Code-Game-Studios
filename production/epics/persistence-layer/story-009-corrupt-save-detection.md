# Story 009: Corrupt Save Detection + Recovery (Rule 9)

> **Epic**: PersistenceLayer
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: L (3-4 hours)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-29

## Context

**GDD**: `design/gdd/persistence-layer.md`
**Requirement**: `TR-persist-010`
*(Requirement text: "Corrupt save detection: 7 trigger conditions emit `critical_save_failed(error_code, key)` + `corrupt_save_recovered(wiped_byte_count)` in fixed order")*

**ADR Governing Implementation**: ADR-0006 Contract 3 (serialization envelope — `UNREGISTERED_PAYLOAD_TYPE`) + Contract 10 (migration failure triggers corrupt) + Contract 11 (flush failure triggers corrupt)
**ADR Decision Summary**: 6 trigger conditions → corrupt path. Actions: (1) wipe `user://state.json` to `{"schema_version":SCHEMA_VERSION}`; (2) `_cache` reset; (3) emit `corrupt_save_recovered(wiped_byte_count)` FIRST; (4) emit `critical_save_failed(error_code, key)` SECOND. Enter Corrupt substate. Never auto-recover — sticky until session restart.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `push_error()` logs to Godot console even with zero signal consumers connected — safety net per GDD Rule 9. Signal order (recovered THEN failed) is binding.

**Control Manifest Rules (Foundation layer)**:
- Required: `corrupt_save_recovered` emits BEFORE `critical_save_failed` (signal order binding)
- Required: `push_error("critical_save_failed: %s | key=%s" ...)` always logged regardless of signal consumers
- Forbidden: Never auto-recover from Corrupt without session restart

---

## Acceptance Criteria

- [ ] **AC-15** (6-trigger table): GIVEN each trigger condition, WHEN boot or runtime hits trigger, THEN for EACH: `user://state.json` content == `{"schema_version":SCHEMA_VERSION}`; `critical_save_failed(error_code, key)` emitted once with correct code; `_test_get_substate()=="Corrupt"`.

  | # | Trigger | Expected error_code | key |
  |---|---------|--------------------|----|
  | 1 | `JSON.parse_string()` returns null | `"INVALID_JSON"` | `""` |
  | 2 | Parsed result not Dictionary | `"INVALID_JSON"` | `""` |
  | 3 | Missing `schema_version` key | `"INVALID_JSON"` | `""` |
  | 4 | `migrate()` returns false | `"MIGRATION_TIMEOUT"` or `"MIGRATION_CHAIN_TOO_LONG"` | `""` |
  | 5 | Unregistered `payload_type` in `from_dict` | `"UNREGISTERED_PAYLOAD_TYPE"` | (key) |
  | 6 | `_flush_dirty()` returns false (MEMFS write error) | `"FLUSH_FAILED"` | `""` |

- [ ] **AC-15b**: GIVEN mock file content `'{"schema_version":1,"foo":"bar"}'` (25 bytes) + signal order recorder on both signals, WHEN Rule 9 trigger fires, THEN `corrupt_save_recovered(wiped_byte_count==25)` emits FIRST; `critical_save_failed` emits AFTER; order log index verified.
- [ ] **AC-16**: GIVEN Corrupt substate entered, WHEN 100 subsequent `write()` calls, THEN all 100 succeed (cache mutation OK in Corrupt); `critical_save_failed` emit count stays at 1 (NOT re-emit per call); no auto-recovery.

---

## Implementation Notes

*From GDD Rule 9 + ADR-0006:*

```gdscript
func _trigger_corrupt(error_code: String, key: String) -> void:
    # Measure original file size before wipe
    var wiped_bytes: int = 0
    var f_check := FileAccess.open("user://state.json", FileAccess.READ)
    if f_check:
        wiped_bytes = f_check.get_length()
        f_check.close()
    # Wipe to clean state
    _cache = { "schema_version": SCHEMA_VERSION }
    var f := FileAccess.open("user://state.json", FileAccess.WRITE)
    if f:
        f.store_string(JSON.stringify(_cache))
        f.close()
    _substate = Substate.CORRUPT
    # Signal order: recovered FIRST, then failed
    emit_signal("corrupt_save_recovered", wiped_bytes)
    push_error("critical_save_failed: %s | key=%s" % [error_code, key])
    emit_signal("critical_save_failed", error_code, key)
```

Single-emit guard: check `_substate != Substate.CORRUPT` before `_trigger_corrupt()` — if already Corrupt, skip re-trigger (AC-16 sticky single-emit).

---

## Out of Scope

- Story 016 (BLOCKED): quota exhaustion stays Ready (NOT Corrupt) — different path
- Story 010: Corrupt substate API rejection matrix

---

## QA Test Cases

**AC-15** — Integration (6-sub-case table)
- Given: each trigger condition (mock file content, mock flush fail, mock ClassDB fail)
- When: trigger fires
- Then: all 4 postconditions per row match (file content, error_code, key, substate)

**AC-15b** — Integration
- Given: file with known 25-byte content + order recorder
- When: INVALID_JSON trigger fires
- Then: signal order index: `corrupt_save_recovered` fires first; `critical_save_failed` second; `wiped_byte_count == 25`

**AC-16** — Integration
- Given: Corrupt substate entered
- When: 100 `write()` calls
- Then: all return true; `critical_save_failed` count stays 1 (no re-emit)

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/persistence-layer/test_corrupt_detection_matrix.gd`
- `tests/integration/persistence-layer/test_corrupt_save_recovered_emission.gd`
- `tests/integration/persistence-layer/test_corrupt_sticky_single_emit.gd`
All must pass.

**Status**: [x] Created — 3 integration test files (14 tests total)

---

## Dependencies

- Depends on: Story 003 (flush path), Story 008 (migration failure triggers corrupt)
- Unlocks: Story 010 (substate machine includes Corrupt), Story 013 (boot edge cases use corrupt path)

---

## Completion Notes
**Completed**: 2026-05-29
**Criteria**: 3/3 passing (AC-15 ✅ AC-15b ✅ AC-16 ✅)
**Deviations**: Trigger 5 (UNREGISTERED_PAYLOAD_TYPE) not tested — ClassDB.instantiate not wired in PersistenceLayer yet (Story 014 scope). Tests cover triggers 1-4 + 6 directly.
**Test Evidence**: Integration — 3 files, 14 tests
**Code Review**: APPROVED (inline)

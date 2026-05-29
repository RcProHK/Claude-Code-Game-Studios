# Story 005: Test Spy Contract — Production No-Op + MockPersistenceLayer

> **Epic**: PersistenceLayer
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S (1-2 hours)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-29

## Context

**GDD**: `design/gdd/persistence-layer.md`
**Requirement**: `TR-persist-007`
*(Requirement text: "Test spy contract: production no-op + MockPersistenceLayer records (`attach_write_spy/attach_delete_spy/clear_spies`)")*

**ADR Governing Implementation**: ADR-0006 Contract 14 (Test Spy Contract — formal interface set)
**ADR Decision Summary**: Production `PersistenceLayer` exposes `attach_write_spy / attach_delete_spy / clear_spies` but all are no-op. `MockPersistenceLayer` (in `tests/mocks/`) extends `IPersistence` and records all calls. Interface shape MUST be identical in production and test builds — no conditional compilation.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: GDScript 4.6 Callable — spy methods use `Callable` parameter type. `cb.call(key, val)` syntax for invoking spies.

**Control Manifest Rules (Foundation layer)**:
- Required: `IPersistence.attach_write_spy / attach_delete_spy / clear_spies` present in both production and mock
- Forbidden: No `OS.has_feature("debug")` conditional compilation to distinguish production/test interface shape

---

## Acceptance Criteria

- [ ] **AC-11**: GIVEN production `PersistenceLayer` (NOT mock) AND `attach_write_spy(my_cb)` called, WHEN `write("foo", "bar")` executes, THEN `my_cb` NEVER invoked; no error/warning emitted.
- [ ] **AC-12**: GIVEN `MockPersistenceLayer` instance with `attach_write_spy(write_log.append)` + `attach_delete_spy(delete_log.append)`, WHEN `write("foo", "bar") + write("baz", 42) + delete("foo")` called, THEN `write_log == [{"key": "foo", "value": "bar"}, {"key": "baz", "value": 42}]`; `delete_log == ["foo"]`.
- [ ] **AC-12b**: GIVEN `MockPersistenceLayer` with spy attached, WHEN `clear_spies()` called THEN `write("after_clear", 99)` called, THEN spy NOT fired for the post-clear write (verifies `clear_spies()` actually clears).

---

## Implementation Notes

*From ADR-0006 Contract 14 + GDD Rule 6:*

1. Add to `IPersistence` base interface:
   ```gdscript
   func attach_write_spy(spy: Callable) -> void: pass  # no-op in production
   func attach_delete_spy(spy: Callable) -> void: pass
   func clear_spies() -> void: pass
   ```
2. `MockPersistenceLayer` at `tests/mocks/mock_persistence_layer.gd`:
   - `var _write_spies: Array[Callable] = []`
   - `var _delete_spies: Array[Callable] = []`
   - Override `attach_write_spy(spy)`: `_write_spies.append(spy)`
   - Override `write(key, val)`: call each spy `spy.call({"key": key, "value": val})` then record
   - Override `clear_spies()`: `_write_spies.clear(); _delete_spies.clear()`
3. `tests/helpers/persistence_test_setup.gd`: `setUp()` / `tearDown()` hooks that auto-call `clear_spies()` to prevent cross-test leakage (AC-note from GDD Edge Cases).

---

## Out of Scope

- Story 014: cross-system contracts that use `MockPersistenceLayer` to verify GSM signal split

---

## QA Test Cases

**AC-11** — Unit
- Given: real `PersistenceLayer` (not mock); spy callable `my_cb` that appends to `call_log`
- When: `attach_write_spy(my_cb)` then `write("foo", "bar")`
- Then: `call_log.size() == 0` (spy never called); write succeeds normally
- Edge cases: spy attached after 3 writes → spy still never called retroactively

**AC-12** — Unit
- Given: `MockPersistenceLayer` with both spies attached
- When: `write("foo","bar")`, `write("baz", 42)`, `delete("foo")` in sequence
- Then: `write_log` contains 2 entries matching exact key+value; `delete_log == ["foo"]`

**AC-12b** — Unit
- Given: `MockPersistenceLayer` with spy attached; `clear_spies()` called
- When: `write("after_clear", 99)` called after clear
- Then: spy NOT fired for the post-clear write; `write_log.size() == 0` (or whatever was recorded before clear is gone)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/persistence-layer/test_production_spy_noop.gd` — must pass
- `tests/unit/persistence-layer/test_mock_spy_records.gd` — must pass

**Status**: [x] Created — `test_production_spy_noop.gd` (3 tests) + `test_mock_spy_records.gd` (3 tests)

---

## Dependencies

- Depends on: Story 002 (write/delete methods exist)
- Unlocks: Story 014 (cross-system contracts need MockPersistenceLayer)

---

## Completion Notes
**Completed**: 2026-05-29
**Criteria**: 3/3 passing (AC-11 ✅ AC-12 ✅ AC-12b ✅)
**Deviations**: None — production spy stubs already existed from Story 001; only MockPersistenceLayer + tests needed
**Test Evidence**: Logic — `test_production_spy_noop.gd` (3) + `test_mock_spy_records.gd` (3) — total 6 tests
**Code Review**: Complete — APPROVED (2026-05-29, inline)
**QA Coverage Gate**: ADEQUATE (inline)
**LP Code Review Gate**: APPROVE (inline)

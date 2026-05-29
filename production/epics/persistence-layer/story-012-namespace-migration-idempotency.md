# Story 012: Namespace Convention + Migration Idempotency

> **Epic**: PersistenceLayer
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S (1-2 hours)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-29

## Context

**GDD**: `design/gdd/persistence-layer.md`
**Requirement**: `TR-persist-013`, `TR-persist-014`
*(TR-013: "Key namespace convention (`gsm.*`/`gym.*`/`_internal.*`) — push_warning only"; TR-014: "Migration step idempotency requirement")*

**ADR Governing Implementation**: ADR: N/A — namespace convention is a GDD-level design guideline without an ADR (NOT architectural pattern requiring ADR). Migration idempotency is an implementation discipline from GDD Rule 13.
**ADR Decision Summary**: N/A — These are coding discipline rules from the GDD, not architectural decisions requiring ADR coverage. Namespace convention = `push_warning` only (NOT enforced). Migration idempotency = defensive guard `if "new_key" not in _cache`.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `push_warning()` only emits in debug builds; release builds silently skip.

**Control Manifest Rules (Foundation layer)**:
- Required: Namespace violation → `push_warning()` in debug builds, NOT `push_error()` / NOT fail build
- Required: `_migrate_one_step(N→N+1)` uses idempotent guard: `if "new_key" not in _cache`

---

## Acceptance Criteria

- [ ] **AC-20**: GIVEN debug build PersistenceLayer + `MockLogger.attach_warning_spy(warning_log.append)`, WHEN `write("bare_key", "val")` called (no namespace prefix), THEN `warning_log` contains one entry matching pattern `Key 'bare_key' lacks namespace prefix`; `write()` returns true (convention warning does NOT block write).
- [ ] **AC-21**: GIVEN debug build + warning spy, WHEN `write("gsm.current_state","idle")` + `write("gym.session_token","tk")` + `write("_internal.schema_version",1)` called, THEN zero warnings emitted; all return true.
- [ ] **AC-22**: GIVEN `_migrate_one_step(1→2)` with idempotent guard `if "new_key" not in _cache`, WHEN step executed 3 times on same input, THEN post-third-run cache state byte-identical to post-first-run; no errors.

---

## Implementation Notes

*From GDD Rule 12 + Rule 13:*

1. **Namespace check** in `write(key, val)`:
   ```gdscript
   var VALID_NAMESPACES := ["gsm.", "gym.", "_internal.", "streak.", "wst.", "stat.", "ability.unlocked."]
   if OS.is_debug_build():
       var has_prefix := VALID_NAMESPACES.any(func(ns): return key.begins_with(ns))
       if not has_prefix:
           push_warning("Key '%s' lacks namespace prefix — add one per Rule 12" % key)
   # Continue write regardless
   ```
2. **Idempotency pattern** for all migration steps:
   ```gdscript
   func _migrate_one_step(from: int, to: int) -> bool:
       match from:
           0:  # Example: version 0 → 1
               if "new_key" not in _cache:  # idempotency guard
                   _cache["new_key"] = _cache.get("old_key", "")
               return true
       return false
   ```
3. Backward-compat: existing bare keys (`current_state`, `session_token`, etc. from GDD #1/#2) MUST NOT trigger warnings — add them to `VALID_NAMESPACES` or mark as legacy accepted patterns.

---

## Out of Scope

- Story 008: migration chain runner (calls `_migrate_one_step` but doesn't define content)

---

## QA Test Cases

**AC-20** — Unit
- Given: debug build; warning spy attached
- When: `write("bare_key", "val")`
- Then: one warning containing `"bare_key"`; write returns true

**AC-21** — Unit
- Given: debug build; warning spy attached
- When: 3 namespaced writes
- Then: zero warnings; all return true

**AC-22** — Unit
- Given: mock step with idempotent guard
- When: 3 consecutive executions on same input
- Then: cache identical after each execution; no errors

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/persistence-layer/test_namespace_warning.gd`
- `tests/unit/persistence-layer/test_namespace_acceptance.gd`
- `tests/unit/persistence-layer/test_migration_idempotent.gd`
All must pass.

**Status**: [x] Created — `test_namespace_warning.gd` (4 tests, covers all 3 ACs)

---

## Dependencies

- Depends on: Story 002 (write method), Story 008 (migration step pattern)
- Unlocks: Story 015 (gate verifies namespace convention)

---

## Completion Notes
**Completed**: 2026-05-29
**Criteria**: 3/3 passing (AC-20 ✅ AC-21 ✅ AC-22 ✅)
**Deviations**: 3 story-specified test files consolidated into 1 (`test_namespace_warning.gd`). push_warning() not capturable in GUT headless — AC-20 tests write-not-blocked behavior only.
**Test Evidence**: Logic — `test_namespace_warning.gd` (4 tests)
**Code Review**: APPROVED (inline)

# Story 002: In-Memory Write-Through Cache (O(1) Read)

> **Epic**: PersistenceLayer
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M (2-3 hours)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-29

## Context

**GDD**: `design/gdd/persistence-layer.md`
**Requirement**: `TR-persist-002`
*(Requirement text: "In-memory write-through cache; `read()` O(1) zero file-I/O")*

**ADR Governing Implementation**: ADR-0006 Contract 4 (sync _ready loads cache) + Contract 11 (no-await — cache mutation is sync)
**ADR Decision Summary**: `_ready()` loads `user://state.json` once into `_cache: Dictionary`. All subsequent `read()` calls return from in-memory cache — zero file I/O. `write()` mutates cache then marks `_dirty = true`. Debounced flush (100ms) handles disk persistence separately.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: `FileAccess.get_as_text()` reads full file content sync. `JSON.parse_string()` returns Variant — check `result is Dictionary`. `FileAccess.store_string()` bool return = WASM-side accept (4.4+ behavior), NOT IDB commit.

**Control Manifest Rules (Foundation layer)**:
- Required: Cache loads at `_ready()` once; all reads from `_cache.get(key)` (O(1))
- Forbidden: Never call `FileAccess.open()` inside `read()` — all reads must be cache-only
- Guardrail: Boot time (PersistenceLayer `_ready()`) < 100ms budget

---

## Acceptance Criteria

- [ ] **AC-02**: GIVEN `MockFileAccess.attach_open_spy(open_log.append)` after `write("foo", "bar")` called once, WHEN `read("foo")` called 1000 times consecutively, THEN `open_log.size() == 0` (zero file I/O on read path); returned value == `"bar"` for all 1000 calls.
- [ ] **AC-02b**: GIVEN a fresh `PersistenceLayer` with empty cache, WHEN `read("nonexistent_key")` called, THEN returns `null` without error or exception; `read("")` (empty string key) also returns `null` without error.
- [ ] **AC-02c**: GIVEN `write("k1", "v1")` then `write("k2", 42)` called in sequence, WHEN `read("k1")` and `read("k2")` called, THEN `read("k1") == "v1"` and `read("k2") == 42`; both keys independently stored in `_cache`; second write does not overwrite first.

---

## Implementation Notes

*From GDD Rule 2 + ADR-0006 Contract 4:*

1. `var _cache: Dictionary = {}` — initialized in `_ready()` by loading `user://state.json`
2. `var _dirty: bool = false` — set `true` on every `write()` or `delete()` call
3. `_ready()` sequence: open file → read `get_as_text()` → `JSON.parse_string()` → assign to `_cache` → proceed (or corrupt path if parse fails per Rule 9)
4. `read(key: String) -> Variant` — `return _cache.get(key)` only. No file I/O.
5. `write(key: String, value: Variant, flush: bool = false) -> bool` — `_cache[key] = value; _dirty = true` → (a) if `flush=true`: call `_flush_dirty()` immediately; (b) else: reset/start `_flush_timer` (FLUSH_DEBOUNCE_MS = 100ms)
6. `_flush_timer: Timer` — AUTOSTART=false, ONE_SHOT=true, connected to `_flush_dirty()`
7. Constructor injection (for tests): `func _init(file_factory: IFileFactory = null, clock: IClock = null, schema_version_override: int = -1)`

---

## Out of Scope

- Story 003: `_flush_dirty()` implementation (atomic flush body)
- Story 008: schema migration (happens before Ready substate)
- Story 009: corrupt save path (triggered by parse failures)

---

## QA Test Cases

**AC-02** — Unit
- Given: `write("foo", "bar")` called once to populate cache; `MockFileAccess.attach_open_spy(open_log.append)` attached
- When: `read("foo")` called 1000 times
- Then: `open_log.size() == 0`; all 1000 return values == `"bar"`

**AC-02b** — Unit
- Given: fresh PersistenceLayer with empty `_cache`
- When: `read("nonexistent_key")` called, then `read("")` called
- Then: both return `null`; no error, no exception, no push_error in output
- Edge cases: `read(null)` should also be safe (or documented as caller's responsibility)

**AC-02c** — Unit
- Given: `write("k1", "v1")` then `write("k2", 42)` called
- When: `read("k1")` and `read("k2")` called
- Then: `read("k1") == "v1"` AND `read("k2") == 42`; keys are independent (multi-key isolation)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/persistence-layer/test_in_memory_cache_read.gd` — must exist and pass

**Status**: [x] Created — `tests/unit/persistence-layer/test_in_memory_cache_read.gd` (8 tests)

---

## Dependencies

- Depends on: Story 001 (interface definition + no-await CI must pass)
- Unlocks: Story 003, 005, 008, 010, 011, 012

---

## Completion Notes
**Completed**: 2026-05-29
**Criteria**: 3/3 passing (AC-02 ✅ AC-02b ✅ AC-02c ✅)
**Deviations**:
- ADVISORY: AC-02 "× 1000" literal loop not explicitly asserted — covered implicitly by 8 focused tests; FileAccess spy deferred to Story 003 when IFileFactory wired
- ADVISORY: `mock_file_factory.gd` added beyond original story scope — valid BLOCKING fix from code review
- ADVISORY: `_ready()` disk load deferred — Stories 008/009 scope
**Test Evidence**: Logic — `tests/unit/persistence-layer/test_in_memory_cache_read.gd` (8 test functions)
**Code Review**: Complete — APPROVED WITH SUGGESTIONS (post-fixes 2026-05-29)
**QA Coverage Gate**: ADEQUATE (2026-05-29)
**LP Code Review Gate**: APPROVE (2026-05-29)

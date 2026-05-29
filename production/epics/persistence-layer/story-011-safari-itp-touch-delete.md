# Story 011: Safari ITP Touch Refresh + Delete Method Semantics

> **Epic**: PersistenceLayer
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S (1-2 hours)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-29

## Context

**GDD**: `design/gdd/persistence-layer.md`
**Requirement**: `TR-persist-011`
*(Requirement text: "Safari ITP `touch(key)` rewrite (refresh 7-day eviction timer)")*

**ADR Governing Implementation**: ADR-0006 Contract 9 (wall-clock TTL — touch refreshes anchor), secondary: Contract 11 (touch is critical flush)
**ADR Decision Summary**: `touch(key)` rewrites same content to refresh Safari ITP 7-day timer. Functionally equivalent to `write(key, read(key), flush=true)` but explicitly signals intent via `is_touch: true` in `write_completed` signal. `delete()` is always critical flush (flush=true). Both are fail-loud on flush failure.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Safari ITP eviction window = 7 days inactivity. `touch()` must flush=true (immediate, not debounced) to ensure disk persistence before tab close.

**Control Manifest Rules (Foundation layer)**:
- Required: `touch()` always uses `flush=true` (critical path — same as tombstone writes)
- Required: `delete()` always uses `flush=true` (destructive operation — no debounce delay)
- Required: `write_completed` emits with `is_touch: true` for touch calls

---

## Acceptance Criteria

- [ ] **AC-17**: GIVEN `write("foo", "bar")` called once, WHEN `touch("foo")` called, THEN `write_completed` emitted second time with `is_touch: true`; cache value unchanged; file content unchanged (same JSON bytes round-trip).
- [ ] **AC-17b**: GIVEN cache without key "nonexistent", WHEN `touch("nonexistent")` called, THEN returns `false`; zero `write_completed` emitted for the touch call.
- [ ] **AC-17c**: GIVEN `write("key", "val")` to populate cache, WHEN `delete("key")` called, THEN returns `true`; key removed from `_cache`; `delete_completed("key", latency_ms)` emitted once.

---

## Implementation Notes

*From GDD Rule 10 + Rule 7.1:*

```gdscript
func touch(key: String) -> bool:
    if key not in _cache: return false
    var val = _cache[key]
    var start: int = Time.get_ticks_msec()
    _cache[key] = val  # no-op mutation (same value)
    _dirty = true
    var ok: bool = _flush_dirty(is_critical=true)
    if ok:
        emit_signal("write_completed", key, Time.get_ticks_msec() - start, true)  # is_touch=true
    return ok

func delete(key: String) -> bool:
    if key not in _cache: return false
    _cache.erase(key)
    _dirty = true
    var start: int = Time.get_ticks_msec()
    var ok: bool = _flush_dirty(is_critical=true)  # always critical
    if ok:
        emit_signal("delete_completed", key, Time.get_ticks_msec() - start)
    else:
        _trigger_corrupt("FLUSH_FAILED", key)  # Rule 9: don't re-insert key
    return ok
```

---

## Out of Scope

- Cross-system: GSM calling `touch()` for ITP refresh → Story 014
- `delete()` failure path details → covered by Story 009 (corrupt detection)

---

## QA Test Cases

**AC-17** — Unit
- Given: `write("foo", "bar")` to populate cache
- When: `touch("foo")` called
- Then: second `write_completed` signal with `is_touch==true`; `_cache["foo"] == "bar"` (unchanged); file JSON unchanged
- Edge cases: `touch("nonexistent")` returns false; `touch()` on key with null value still touches (not absent check)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/persistence-layer/test_touch_refresh.gd` — must pass

**Status**: [x] Created — `test_touch_refresh.gd` (4 tests)

---

## Dependencies

- Depends on: Story 003 (flush path — touch uses critical flush)
- Unlocks: Story 014 (GSM uses touch for ITP; cross-system contract)

---

## Completion Notes
**Completed**: 2026-05-29
**Criteria**: 3/3 passing (AC-17 ✅ AC-17b ✅ AC-17c ✅)
**Deviations**: None
**Test Evidence**: Logic — `test_touch_refresh.gd` (4 tests)
**Code Review**: APPROVED (inline)

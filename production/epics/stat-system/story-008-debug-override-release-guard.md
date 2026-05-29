# Story 008: DEBUG_OVERRIDE Release-Build Runtime Guard

> **Epic**: Stat System
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S (1-2 hours)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-29

## Context

**GDD**: `design/gdd/stat-system.md`
**Requirements**: `TR-stat-016`
*(TR-stat-016: DEBUG_OVERRIDE — debug build runtime guard + CI lint catches `src/` usage)*

**ADR Governing Implementation**: ADR-0006 State Machine Contract — Contract 12 (chokepoint enforcement); GDD FR-3 (Pillar 1 hard guarantee — triple defense)
**ADR Decision Summary**: `DEBUG_OVERRIDE` is blocked in release builds via three independent defense layers: (1) runtime `OS.is_debug_build()` guard, (2) CI lint (Story 001 AC-14), (3) export-template strip. This story covers the runtime guard layer. The CI lint is covered by Story 001.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: `OS.is_debug_build()` returns `false` in release exports and Godot's "Export Release" mode. To simulate release-build context in GUT tests, inject a boolean seam (`_is_debug_build_override`) that the test can set to `false`. Without a seam, the test would need a real release export — impractical in CI GUT gate.

**Control Manifest Rules (Core layer)**:
- Required: `apply_stat_delta` body must check `if source == StatSource.DEBUG_OVERRIDE and not _get_is_debug()` → push_error + `stat_mutation_rejected(reason="debug_override_release_blocked")` + return false
- Required: The debug/release check must use a testable seam (boolean property or callable override) — not raw `OS.is_debug_build()` directly, which is untestable in GUT without export
- Forbidden: `DEBUG_OVERRIDE` must never silently succeed in release build — FR-3 Pillar 1 hard guarantee

---

## Acceptance Criteria

- [ ] **AC-13** — GIVEN a release-build context (`OS.is_debug_build() == false`, simulated via injection seam), STR=10, WHEN `apply_stat_delta(StatId.STR, StatSource.DEBUG_OVERRIDE, 100.0)` is called, THEN returns `false`, `push_error("DEBUG_OVERRIDE blocked in release build")` fires, `stat_mutation_rejected(STR, DEBUG_OVERRIDE, 100.0, "debug_override_release_blocked")` emits, AND STR remains 10.0 (unchanged).

---

## Implementation Notes

*From GDD Rule 10 + FR-3:*

1. **Testable injection seam**:
   ```gdscript
   var _debug_build_override: Variant = null  # null = use OS.is_debug_build()
   func _get_is_debug() -> bool:
       if _debug_build_override != null:
           return _debug_build_override
       return OS.is_debug_build()
   ```
2. **Runtime guard** in `apply_stat_delta` validation (Rule 13 step 1, fires before any other logic):
   ```gdscript
   if source == StatSource.DEBUG_OVERRIDE and not _get_is_debug():
       push_error("DEBUG_OVERRIDE blocked in release build")
       emit_signal("stat_mutation_rejected", stat_id, source, delta, "debug_override_release_blocked")
       return false
   ```
3. **Test pattern**: Set `stat_system._debug_build_override = false` before calling `apply_stat_delta` to simulate release build. Reset to `null` in `after_each`.
4. **Order of guards**: DEBUG_OVERRIDE release check fires BEFORE anti-decay (Rule 12) and BEFORE allow-list (Rule 4). This ensures release builds never process DEBUG_OVERRIDE regardless of other validation state.
5. **CI lint (Story 001 AC-14)** is the second defense — independently catches `StatSource.DEBUG_OVERRIDE` references in `src/` on release branches. Both defenses must be independent.
6. **Export strip (third defense)** — confirmed via AC-37 in Story 013 (ADR-RATIFICATION-GATED); out of scope for this story.

---

## Out of Scope

- Story 001: CI lint `check_debug_override_calls.gd` (AC-14) — that's the second defense layer
- Story 013: Export-template binary strip verification (AC-37) — third defense, ADR-RATIFICATION-GATED
- Story 007: Anti-decay + clamping (fires after this guard)

---

## QA Test Cases

**Story Type**: Logic
**Required evidence**: `tests/unit/stat_system/test_debug_override_release_runtime_guard.gd`

- **AC-13**: Release-build runtime guard
  - Given: `stat_system._debug_build_override = false` (simulates release build); STR=10
  - When: `apply_stat_delta(STR, DEBUG_OVERRIDE, 100.0)`
  - Then: Returns false; push_error fires with "blocked in release build" message; `stat_mutation_rejected(STR, DEBUG_OVERRIDE, 100.0, "debug_override_release_blocked")` emits; STR=10.0 (unchanged)
  - Edge cases: `_debug_build_override = true` (debug build) + `apply_stat_delta(STR, DEBUG_OVERRIDE, 1.0)` → should succeed (guard passes); `_debug_build_override = null` (use real `OS.is_debug_build()`) in editor → typically returns true → guard passes

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/stat_system/test_debug_override_release_runtime_guard.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 007 (validation ordering context), Story 002 (StatSource enum)
- Unlocks: Story 009 (GSM Suspended gate — all validation guards are in place before integration stories)

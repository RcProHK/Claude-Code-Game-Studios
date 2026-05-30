# Story 006: Persistence + Atomic Write Sequence + Re-entrance Guard

> **Epic**: Stat System
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Estimate**: M (2-4 hours)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-30

## Completion Notes
**Completed**: 2026-05-30
**Criteria**: 4/4 passing (AC-09 ✓ AC-18 ✓ AC-19 ✓ AC-33 ✓)
**Deviations**: ADVISORY — clamping deferred to Story 007 (target computed raw in atomic sequence); ADR-0003 referenced for `stat.*` namespace is Proposed but informational-only (governing ADR is ADR-0006 C11, Accepted)
**Test Evidence**: Integration — `test_persistence_flush_policy.gd`, `test_atomic_write_persist_first.gd`; Unit — `test_atomic_write_emit_after.gd`, `test_reentrance_guard.gd`
**Code Review**: Complete (Batch A) — CLEAN; persist-first → mutate → guarded-emit sequence verified

## Context

**GDD**: `design/gdd/stat-system.md`
**Requirements**: `TR-stat-006`, `TR-stat-007`, `TR-stat-014`, `TR-stat-015`
*(TR-stat-006: Flush policy — PR flush=true / VOLUME_TICK flush=false. TR-stat-007: Atomic ordering — persist BEFORE mutate BEFORE emit. TR-stat-014: stat.* namespace. TR-stat-015: Re-entrance guard)*

**ADR Governing Implementation**: ADR-0006 State Machine Contract — Contract 11 (best-effort IDB fence, sync API, no `await`), Contract 3 (namespace ownership); ADR-0003 (Proposed ⚠️ — `stat.*` namespace; stories proceed on ADR-0006 Contract 11 which is Accepted)
**ADR Decision Summary**: `apply_stat_delta` persists BEFORE mutating in-memory cache, and emits `stat_changed` AFTER in-memory mutation. This prevents phantom-state (disk says old, cache says new). Re-entrance guard (`_emit_depth` counter) prevents unbounded recursion if a subscriber handler calls back into `apply_stat_delta`.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: `FileAccess.store_string()` returns `bool` (WASM-side accept only, NOT IndexedDB commit ack — Contract 11). `PersistenceLayer.write()` returning `true` means the write was accepted, not that IDB has committed. GDScript signal emit is synchronous — subscriber handlers run to completion before emit returns.

**Control Manifest Rules (Core layer)**:
- Required: Persist BEFORE in-memory mutate — if `PersistenceLayer.write()` returns false, abort and leave `_base` unchanged (Rule 13 step 4-5)
- Required: Emit `stat_changed` AFTER `_base[stat_id] = target` (Rule 13 step 6) so subscribers see new value via `get_stat()`
- Required: `_emit_depth` counter — increment before signal emit, decrement after; nested `apply_stat_delta` with `_emit_depth > 0` → push_error + return false (EC-22)
- Forbidden: Never `await` in `apply_stat_delta` or any helper it calls (ADR-0006 Contract 12)

---

## Acceptance Criteria

- [ ] **AC-09** — GIVEN Stat System Ready, PersistenceLayer spy records each `write(key, value, flush)` call, WHEN `apply_stat_delta(STR, PR_BREAKTHROUGH, 1.0)` is called then `apply_stat_delta(STR, VOLUME_TICK, 0.05)` is called, THEN the PR_BREAKTHROUGH write spy sees `flush == true` AND the VOLUME_TICK write spy sees `flush == false`.
- [ ] **AC-18** — GIVEN PersistenceLayer spy is configured to force `write()` to return `false`, STR=12, WHEN `apply_stat_delta(STR, PR_BREAKTHROUGH, 1.0)` is called, THEN returns `false`, `_base[STR]` is still `12.0` (in-memory unchanged), `stat_critical_save_failed(StatId.STR)` emits, AND no `stat_changed` signal fires.
- [ ] **AC-19** — GIVEN STR=10, a subscriber callable connected via `connect_for_initial_state`, where the callable captures and stores the value of `get_stat(StatId.STR)` at handle time, WHEN `apply_stat_delta(STR, PR_BREAKTHROUGH, 1.0)`, THEN the captured value inside the subscriber handler is `11.0` (new value), NOT `10.0` (old value) — confirming emit fires AFTER in-memory mutation.
- [ ] **AC-33** — GIVEN a subscriber handler connected to `stat_changed` which internally calls `apply_stat_delta(STR, PR_BREAKTHROUGH, 1.0)` (nested re-entrance on same stat), WHEN the outer `apply_stat_delta(STR, PR_BREAKTHROUGH, 1.0)` fires and triggers the subscriber, THEN the nested call detects `_emit_depth > 0`, returns `false`, push_error fires with a re-entrance message, AND no unbounded recursion occurs.

---

## Implementation Notes

*From GDD Rule 7, 9, 13 + EC-22:*

1. **Flush decision** (`flush_for_source(source: StatSource) -> bool`):
   - `PR_BREAKTHROUGH` → `true` (critical — must reach disk before next interaction)
   - `VOLUME_TICK` → `false` (debounced 100ms by PersistenceLayer's dirty-flag timer)
   - `DEBUG_OVERRIDE` → `true`
   - `EQUIPMENT` → N/A (no persistence call for modifier path)
2. **Atomic write sequence** (Rule 13 — `apply_stat_delta` body after validation):
   ```gdscript
   # Step 2-3: compute target + snapshot old
   var target := clamp(_base[stat_id] + delta, 0.0, MAX_STAT_VALUE)
   var old_value := _base[stat_id]
   # Step 4: persist FIRST
   var persist_ok := PersistenceLayer.write("stat." + stat_id.to_lower(), target, flush_for_source(source))
   if not persist_ok:
       emit_signal("stat_critical_save_failed", stat_id)
       push_error("...")
       return false
   # Step 5: mutate in-memory
   _base[stat_id] = target
   # Step 6: emit (AFTER mutate — subscriber reads new value via get_stat)
   _emit_depth += 1
   emit_signal("stat_changed", stat_id, old_value, target, source, false)
   _emit_depth -= 1
   ```
3. **Re-entrance guard** (EC-22):
   - `var _emit_depth: int = 0` — instance variable
   - At top of `apply_stat_delta`: `if _emit_depth > 0: push_error("Stat System re-entrance"); return false`
   - Increment before emit, decrement in `finally`-style pattern
4. **`stat.*` namespace** (TR-stat-014): key format = `"stat." + stat_id.to_lower()` → `"stat.str"`, `"stat.dex"`, `"stat.vit"`. Only base stats persisted; derived are computed.

---

## Out of Scope

- Story 007: Anti-decay + clamping gates (validation before atomic write sequence)
- Story 008: DEBUG_OVERRIDE runtime guard (also fires before atomic write)
- Story 010: Mutation formula computation (delta value passed in is caller-computed)

---

## QA Test Cases

**Story Type**: Integration (PersistenceLayer spy required for AC-09 and AC-18)

- **AC-09**: Flush policy
  - Given: PersistenceLayer spy active; STR=10
  - When: `apply_stat_delta(STR, PR_BREAKTHROUGH, 1.0)` then `apply_stat_delta(STR, VOLUME_TICK, 0.05)`
  - Then: Spy log shows call 1: `write("stat.str", 11.0, true)`; call 2: `write("stat.str", 11.05, false)`
  - Edge cases: `DEBUG_OVERRIDE` source → `flush=true`; `EQUIPMENT` source → no persistence call at all

- **AC-18**: Persist-first rollback on write failure
  - Given: MockPersistenceLayer `write()` returns `false`; STR=12
  - When: `apply_stat_delta(STR, PR_BREAKTHROUGH, 1.0)`
  - Then: Returns `false`; `_base[STR] == 12.0`; `stat_critical_save_failed(STR)` emits; no `stat_changed` emits
  - Edge cases: Persist fails on second consecutive call (same behaviour); recover when spy returns `true` again

- **AC-19**: Emit after in-memory mutate
  - Given: STR=10; subscriber captures `get_stat(STR)` inside handler
  - When: `apply_stat_delta(STR, PR_BREAKTHROUGH, 1.0)`
  - Then: Subscriber reads `get_stat(STR) == 11.0` (not 10.0)
  - Edge cases: Derived stat `get_stat(ATTACK_POWER)` inside handler also reads updated derived value (recompute happens before emit chain for derived)

- **AC-33**: Re-entrance guard
  - Given: Subscriber handler calls `apply_stat_delta(STR, PR_BREAKTHROUGH, 1.0)` when it receives `stat_changed(STR, ...)`
  - When: Outer `apply_stat_delta(STR, PR_BREAKTHROUGH, 1.0)` fires
  - Then: Nested call immediately returns `false`; push_error fires once; no stack overflow; outer call completes normally
  - Edge cases: Re-entrance on DIFFERENT stat_id — same guard (`_emit_depth` is global not per-stat); nested re-entrance 3+ deep — all rejected

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/stat_system/test_persistence_flush_policy.gd` (AC-09)
- Integration: `tests/integration/stat_system/test_atomic_write_persist_first.gd` (AC-18)
- Unit: `tests/unit/stat_system/test_atomic_write_emit_after.gd` (AC-19)
- Unit: `tests/unit/stat_system/test_reentrance_guard.gd` (AC-33)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 005 (observer pattern — AC-19 requires subscriber that calls `get_stat` in handler), Story 002 (StatSource enum + allow-list), Story 004 (boot — `_base` must be populated)
- Unlocks: Story 010 (mutation formulas compute the delta before calling this sequence), Story 011 (knob invariants build on correct mutation infrastructure)

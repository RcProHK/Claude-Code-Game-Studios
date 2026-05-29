# Story 004: Boot Reconciliation

> **Epic**: Stat System
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M (2-3 hours)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-29

## Context

**GDD**: `design/gdd/stat-system.md`
**Requirements**: `TR-stat-011`, `TR-stat-017`
*(TR-stat-011: Boot reconciliation — first-boot defaults / partial keys / corrupt fallback. TR-stat-017: Autoload position 5)*

**ADR Governing Implementation**: ADR-0006 State Machine Contract — Contract 4 (autoload sequential boot — Stat System = position 5, after PersistenceLayer pos 1 + GSM pos 2 + PlatformDetect pos 3 + GymSys pos 4)
**ADR Decision Summary**: `_ready()` must complete synchronously; no `await`. Each autoload boot completes fully before the next begins. PersistenceLayer (pos 1) is guaranteed ready when Stat System (pos 5) `_ready()` runs.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Autoload `_ready()` order is per-instance sequential in Godot 4.6 (NOT batched). `is_nan(value)` and `is_inf(value)` are available as global functions. `PersistenceLayer.read()` returns `Variant` — test `typeof(result) == TYPE_FLOAT` to distinguish valid float from `{}` empty Dictionary.

**Control Manifest Rules (Foundation/Core layer)**:
- Required: No `await` anywhere in `_ready()` (ADR-0006 Contract 4 + Contract 12)
- Required: Read-only during `_ready()` — no `stat_changed` emit during boot (subscribers not yet connected)
- Required: `boot_completed()` signal emits after `_ready()` finishes (Rule 16)
- Required: Autoload position 5 — verified in `project.godot` (F-SETUP-1 synced 2026-05-28)

---

## Acceptance Criteria

- [ ] **AC-10** — GIVEN `PersistenceLayer.read("stat.str")`, `read("stat.dex")`, `read("stat.vit")` all return `{}` (key absent / first boot), WHEN Stat System `_ready()` runs, THEN `_base = {STR: 10.0, DEX: 10.0, VIT: 10.0}`, substate = Ready, `boot_completed()` emits exactly once, AND no `stat_changed` signal fires during boot.
- [ ] **AC-11** — GIVEN `read("stat.str")` returns `25.0` but `read("stat.dex")` returns `{}` (partial keys), WHEN `_ready()` runs, THEN `_base = {STR: 25.0, DEX: 10.0, VIT: 10.0}`, AND `push_warning` fires for each absent key (`"stat.dex absent — defaulting to 10.0"`).
- [ ] **AC-12** — GIVEN `read("stat.str")` returns `NAN`, WHEN `_ready()` runs, THEN `_base[STR] = 10.0` (default fallback), `stat_critical_save_failed(StatId.STR)` emits, push_error fires, substate = Ready (degraded mode), AND game launch is NOT blocked.
- [ ] **AC-12b** — GIVEN `read("stat.dex")` returns `-5.0` (negative — invalid) AND `read("stat.vit")` returns `1500.0` (exceeds MAX_STAT_VALUE=999), WHEN `_ready()` runs, THEN `_base[DEX]` is clamped to `0.0` + push_warning fires; AND `_base[VIT]` is clamped to `999.0` + push_warning fires; AND boot continues to Ready substate normally. *(QA-lead proposed coverage for EC-04 negative + >MAX branches — GDD sync pending)*
- [ ] **AC-22** — GIVEN Stat System autoload begins initialising, WHEN `_ready()` completes all sync reads + GSM subscription, THEN `boot_completed()` emits exactly once (ADVISORY — does not block Done).

---

## Implementation Notes

*From GDD Rule 8 + EC-01 / EC-03 / EC-04:*

1. **`_ready()` sync sequence** (no `await`):
   - Read `PersistenceLayer.read("stat.str")`, `"stat.dex"`, `"stat.vit"` — all sync returns
   - For each key: `if typeof(result) != TYPE_FLOAT` → absent/corrupt → apply fallback
   - `is_nan(v) or is_inf(v)` → clamp to default 10.0 + `push_error` + emit `stat_critical_save_failed(stat_id)` (EC-04 NaN/Inf branch)
   - `v < 0` → clamp to 0.0 + `push_warning` (EC-04 negative branch)
   - `v > MAX_STAT_VALUE` → clamp to MAX_STAT_VALUE + `push_warning` (EC-04 >MAX branch)
   - `typeof(result) == TYPE_DICTIONARY and result.is_empty()` → absent → default 10.0 + `push_warning` (EC-01/03)
   - `typeof(result) == TYPE_FLOAT` → valid → use as-is
2. **Populate `_base`** — after all 3 keys resolved
3. **Subscribe GSM** — `GameStateMachine.connect_for_initial_state(_on_gsm_state_changed)` for Rule 14 Suspended gate (Story 009)
4. **`boot_completed()` emit** — after GSM subscription completes, before `_ready()` returns
5. **No `stat_changed` emit during `_ready()`** — subscribers not yet connected; they receive initial values through `connect_for_initial_state` helper (Story 005)
6. **Substate = Ready** after `_ready()` completes (even in degraded NaN-fallback case — boot continues)

---

## Out of Scope

- Story 005: `connect_for_initial_state` subscriber delivery (observer pattern)
- Story 008: GSM Suspended gate (`_on_gsm_state_changed` handler body)
- Story 009: GSM Reconciling re-read + resume delta emit (triggered after Suspended exit)

---

## QA Test Cases

**Story Type**: Logic
**Required evidence**: `tests/unit/stat_system/test_boot_first_time.gd`, `test_boot_partial_keys.gd`, `test_boot_corrupt_fallback.gd`

- **AC-10**: First-boot all-absent
  - Given: MockPersistenceLayer returns `{}` for all 3 `stat.*` reads
  - When: `_ready()` runs
  - Then: `_base == {STR:10.0, DEX:10.0, VIT:10.0}`; `boot_completed` emits once; no `stat_changed` emits during boot; substate = Ready
  - Edge cases: Confirm `boot_completed` fires AFTER GSM subscription (order check)

- **AC-11**: Partial keys
  - Given: Mock returns `25.0` for `stat.str`, `{}` for `stat.dex`, `15.0` for `stat.vit`
  - When: `_ready()` runs
  - Then: `_base == {STR:25.0, DEX:10.0, VIT:15.0}`; push_warning fires for `stat.dex`; no push_warning for str/vit

- **AC-12**: NaN corrupt fallback
  - Given: Mock returns `NAN` for `stat.str`
  - When: `_ready()` runs
  - Then: `_base[STR] == 10.0`; `stat_critical_save_failed(STR)` emits; push_error fires; substate = Ready (not blocked); game continues

- **AC-12b**: Negative + >MAX boot clamp (QA-lead proposed, GDD EC-04 coverage)
  - Given: Mock returns `-5.0` for `stat.dex`; `1500.0` for `stat.vit`
  - When: `_ready()` runs
  - Then: `_base[DEX] == 0.0` (clamped), push_warning fires; `_base[VIT] == 999.0` (clamped), push_warning fires; substate = Ready

- **AC-22**: boot_completed telemetry (ADVISORY)
  - Given: Stat System autoload starting
  - When: `_ready()` completes
  - Then: `boot_completed` signal emits exactly once

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/stat_system/test_boot_first_time.gd`, `test_boot_partial_keys.gd`, `test_boot_corrupt_fallback.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (StatId constants + StatSource enum must exist), Story 001 (CI lints active)
- Unlocks: Story 005 (observer pattern delivers boot-loaded values), Story 009 (GSM Suspended gate subscribes GSM in `_ready()`)

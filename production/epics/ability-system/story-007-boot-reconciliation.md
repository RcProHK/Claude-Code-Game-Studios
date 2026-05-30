# Story 007: Boot Reconciliation

> **Epic**: Ability System
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Estimate**: M (2-3 hours)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-30

## Completion Notes
**Completed**: 2026-05-30
**Criteria**: 3/3 passing (AC-14/14b/14c)
**Deviations**: None — `_load_unlock_from_key` defensive read (EC-02/03/04); boot-burst suppression via `_on_stat_changed` early-return while `_substate == INITIALISING` (prevents ability_unlocked during _ready per AC-14c — required forcing `_substate = READY` in 2 Batch B Path-B tests); `_assert_knob_invariants()` at _ready head (Story 009)
**Test Evidence**: Integration — `tests/integration/ability_system/test_boot_reconciliation.gd`
**Code Review**: Batch C self-verified

## Context

**GDD**: `design/gdd/ability-system.md`
**Requirements**: `TR-ability-011`, `TR-ability-020`
*(TR-ability-011: Boot reconciliation rebuilds state from PersistenceLayer. TR-ability-020: Autoload position 6.)*

**ADR Governing Implementation**: ADR-0006 Contract 4 (autoload sequential boot — pos 6, after PersistenceLayer/GSM/PlatformDetect/GymSys/Stat); Contract 6 (`connect_for_initial_state` subscriptions in `_ready()`).
**ADR Decision Summary**: `_ready()` is synchronous (no `await`); reads all `ability.unlocked.*` keys from PersistenceLayer; subscribes to GSM + Stat via `connect_for_initial_state`; emits `boot_completed` at end. No `ability_unlocked` emits during `_ready()` — subscribers not yet connected.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `PersistenceLayer.list_keys_matching(prefix)` — sync return. `await _sut.ready` hangs after `add_child_autofree` (ready already fired); use `await get_tree().process_frame` instead (learned from stat-system Story 004 CI hang). Untyped `_persistence = null` DI seam.

**Control Manifest Rules (Foundation layer)**:
- Required: No `await` in `_ready()` (ADR-0006 Contract 4 + Contract 12)
- Required: `boot_completed()` signal emits AFTER all subscriptions wired (Rule 16 + Rule 10 step 6)
- Required: Autoload position 6 — after PersistenceLayer (1) + GSM (2) + PlatformDetect (3) + GymSys (4) + Stat (5)

---

## Acceptance Criteria

- [ ] **AC-14** — GIVEN PersistenceLayer preloaded with keys `{"ability.unlocked.strike_tier_1_jab": record_dict, "ability.unlocked.control_tier_1_parry": record_dict}` AND AbilitySystem at autoload position 6, WHEN `_ready()` completes, THEN `get_unlocked_abilities()` returns exactly `{STRIKE_TIER_1_JAB: record, CONTROL_TIER_1_PARRY: record}`, `_cooldown_remaining` is empty (cooldowns transient — reset on reload), `_unlocked_abilities` populated before `boot_completed` fires.
- [ ] **AC-14b** — GIVEN boot with defensive edge cases: (EC-02) empty PL = boot fallback to empty set + push_warning; (EC-03) partial keys = STRIKE_TIER_2 present without TIER_1 = each loaded independently + push_warning for non-causal chain; (EC-04) corrupt UnlockRecord: NaN timestamp → use current time + push_warning; invalid source → coerce to INITIAL_STATE + push_warning; from_dict fail → skip key + `ability_unlock_save_failed` emit, WHEN `_ready()` runs, THEN boot completes to Ready substate in ALL cases (game launch NOT blocked).
- [ ] **AC-14c** — GIVEN AbilitySystem boot with watch_signals, WHEN `_ready()` completes, THEN `boot_completed` emits exactly once; NO `ability_unlocked` signals fire during `_ready()` (subscribers connect AFTER boot via `connect_for_initial_state`); GSM + Stat subscriptions wired (connect_for_initial_state called once each).

---

## Implementation Notes

*From GDD Rule 10 + EC-01/02/03/04 + ADR-0006 C4:*

1. **`_ready()` sequence** (NO `await`):
   ```
   if _persistence == null: _persistence = PersistenceLayer
   if _gsm == null: _gsm = GameStateMachine
   if _stat_system == null: _stat_system = StatSystem
   _substate = Substate.INITIALISING
   # Step 1-3: sync read + populate
   var keys := _persistence.list_keys_matching("ability.unlocked.")  # or iterate known keys
   for key in keys:
       _load_unlock_from_key(key)  # EC-03/04 defensive
   # Step 4: empty cooldowns (transient)
   _cooldown_remaining.clear()
   # Step 5: subscribe
   _stat_system.connect_for_initial_state(_on_stat_changed)
   _gsm.connect_for_initial_state(_on_gsm_state_changed)
   _substate = Substate.READY
   boot_completed.emit()
   ```
2. **`_load_unlock_from_key(key: String)`** — defensive read:
   - `var record_dict = _persistence.read(key)` → if not dict → skip + push_warning (EC-02)
   - `var record = UnlockRecord.from_dict(record_dict)` → if null/fail → skip key + `ability_unlock_save_failed.emit(key)`
   - Validate `record.source in UnlockSource.values()` → else coerce + push_warning (EC-04)
   - Validate `is_nan(record.first_unlocked_at_unix)` → use Time.get_unix_time_from_system() (EC-04)
   - Extract ability_id from key: `key.replace("ability.unlocked.", "")`
   - If ability_id not in AbilityId constants → push_warning + skip (EC-03 partial key + Rule 1 locked surface)
   - `_unlocked_abilities[ability_id] = record`
3. **`Substate` enum** (add to story-002 declarations if needed):
   ```gdscript
   enum Substate { INITIALISING, READY, SUSPENDED, RECONCILING }
   var _substate: Substate = Substate.INITIALISING
   ```
4. **MockGSM / MockStatSystem** for tests — simple RefCounted with `connect_for_initial_state(callable)` no-op method.
5. **Test pattern** — use `await get_tree().process_frame` (NOT `await _sut.ready` which hangs — ready signal already fired by add_child_autofree in Godot 4.6).
6. **`list_keys_matching`** — MockPersistenceLayer must support this; add to existing mock or use inline mock with `_data.keys().filter(...)`.

---

## Out of Scope

- Story 008: GSM Suspended gate after boot
- Story 004-005: How abilities get unlocked during gameplay (this story only reads pre-existing keys)

---

## QA Test Cases

**Story Type**: Integration

- **AC-14**: Normal boot with pre-existing keys
  - Given: MockPL with 2 ability keys, MockGSM, MockStatSystem
  - When: `add_child(sut)` → `await get_tree().process_frame` (NOT await _sut.ready)
  - Then: `get_unlocked_abilities()` has 2 entries; `_cooldown_remaining` empty; both entries correct
  - Edge cases: 0 keys → empty `_unlocked_abilities`; 9 keys (all unlocked) → all loaded

- **AC-14b**: Defensive boot edge cases
  - Given: PL with various corrupt data: empty, partial chain, NaN timestamp, bad source
  - When: Boot runs for each scenario
  - Then: Boot ALWAYS completes to Ready (no crash); appropriate push_warning/push_error; ability_unlock_save_failed fires for unrecoverable record; recovered data loaded

- **AC-14c**: No signals during boot + boot_completed fires once
  - Given: watch_signals before boot; capturing MockGSM + MockStatSystem recording connect_for_initial_state calls
  - When: Boot completes
  - Then: `ability_unlocked` emit count = 0; `boot_completed` emit count = 1; both connect_for_initial_state calls recorded

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/ability_system/test_boot_reconciliation.gd`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 004 (UnlockRecord class must exist; `_unlocked_abilities` dict established), Story 002 (enums), Story 001 (CI lints active)
- Unlocks: Story 008 (Suspended gate builds on substate + _ready subscriptions)

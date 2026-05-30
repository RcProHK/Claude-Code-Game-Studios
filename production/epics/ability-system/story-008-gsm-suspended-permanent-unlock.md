# Story 008: GSM Suspended Gate + Reconciling Re-read + Permanent Unlock

> **Epic**: Ability System
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Estimate**: M (2-3 hours)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-30

## Completion Notes
**Completed**: 2026-05-30
**Criteria**: 3/3 passing (AC-15/15b/16)
**Deviations**: None — `_is_mutation_gated()` (SUSPENDED|RECONCILING) gates unlock_ability + cast_ability; `_enter_suspended`/`_reconcile_after_resume` mirror StatSystem; permanent unlock verified (no relock_ability method, no ability_relocked signal, no PL.delete on stat drop)
**Test Evidence**: Integration — `test_suspended_gate.gd`; Unit — `test_no_relock_on_stat_drop.gd`
**Code Review**: Batch C self-verified

## Context

**GDD**: `design/gdd/ability-system.md`
**Requirements**: `TR-ability-012`, `TR-ability-013`
*(TR-ability-012: GSM Suspended gate rejects mutation. TR-ability-013: Permanent unlock contract — no relock under stat drop.)*

**ADR Governing Implementation**: ADR-0006 Contract 6 (`connect_for_initial_state` GSM subscription); Contract 13 (IInputPolicy Suspended gate pattern).
**ADR Decision Summary**: Ability System subscribes to GSM `state_changed` via `connect_for_initial_state` in `_ready()`. GSM Suspended → enter Suspended substate (mutation API rejects). GSM exit Suspended → Reconciling (single-frame re-read + emit delta unlocks). Anti-Pillar: once unlocked, always unlocked (no relock under stat drop).

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: GSM state_changed handler signature `(from: GameState, to: GameState, payload: StateTransitionPayload)` per callv 3-arg layout. `is_queued_for_deletion()` for target validation. `GameStateMachine.GameState.SUSPENDED` enum compare (not string-name — established pattern from streak_system).

**Control Manifest Rules (Core layer)**:
- Required: Subscribe GSM via `connect_for_initial_state` in `_ready()` — direct `.connect("state_changed", cb)` FORBIDDEN
- Required: Mutation API (incl. `cast_ability` + `apply_equipment_modifier`-equivalent) uniform gate during Suspended AND Reconciling
- Forbidden: Never implement `relock_ability` or `_unlocked_abilities.erase()` outside schema migration (Rule 12 permanent unlock)

---

## Acceptance Criteria

- [ ] **AC-15** — GIVEN AbilitySystem `Ready`, GSM delivers `state_changed(_, SUSPENDED, payload)` via MockGSM, WHEN `unlock_ability(AbilityId.STRIKE_TIER_1_JAB, PR_BREAKTHROUGH)` invoked during Suspended, THEN returns `false`, `_unlocked_abilities` unchanged, `ability_mutation_rejected(..., "suspended_substate")` emits, no `PersistenceLayer.write` call. ALSO: `cast_ability` during Suspended returns `CastResult.GSM_REJECT` AND read-only `get_unlocked_abilities()` succeeds normally during Suspended.
- [ ] **AC-15b** — GIVEN AbilitySystem Suspended, PersistenceLayer updated to have a new key `"ability.unlocked.control_tier_2_hook_pull"` (backend unlocked during suspension), WHEN MockGSM delivers `state_changed(SUSPENDED, IDLE, null)` (exit Suspended → Reconciling → Ready), THEN Reconciling re-reads all `ability.unlocked.*` keys; `_unlocked_abilities` contains `CONTROL_TIER_2_HOOK_PULL`; `ability_unlocked(CONTROL_TIER_2_HOOK_PULL, PR_BREAKTHROUGH, false)` emits; substate returns to `Ready`; subsequent `unlock_ability` succeeds (gate released).
- [ ] **AC-16** — GIVEN `STRIKE_TIER_2_HOOK` unlocked (STR=50), WHEN `stat_changed(STR, 50, 5, EQUIPMENT)` delivered (stat drops — EC-15 EQUIPMENT path also excluded), THEN `get_unlocked_abilities()` STILL contains `STRIKE_TIER_2_HOOK` (permanent unlock — Anti-Pillar constraint), no `ability_relocked` signal exists in codebase, no `PersistenceLayer.delete` called for `ability.unlocked.*` keys.

---

## Implementation Notes

*From GDD Rules 11, 12 + EC-30 + ADR-0006 C6/C13:*

1. **`_on_gsm_state_changed(from, to, payload)` body** (registered via `connect_for_initial_state` in `_ready()`):
   - Initial-state sentinel: if `payload != null and payload.source_event == GameStateMachine.INITIAL_STATE_PAYLOAD_SOURCE_EVENT`: handle EC-30 (if to == SUSPENDED → enter_suspended immediately)
   - `to == GameStateMachine.GameState.SUSPENDED` → `_enter_suspended()`
   - `_substate == Substate.SUSPENDED` AND `to != SUSPENDED` → `_reconcile_after_resume()`
2. **`_enter_suspended()`**:
   ```gdscript
   _substate = Substate.SUSPENDED
   _pre_suspended_snapshot = _unlocked_abilities.duplicate()
   set_process(false)  # freeze cooldowns during suspension
   ```
3. **`_reconcile_after_resume()`** (single-frame, NO await):
   ```gdscript
   _substate = Substate.RECONCILING
   var current_keys := _persistence.list_keys_matching("ability.unlocked.")
   for key in current_keys:
       var ability_id := key.replace("ability.unlocked.", "")
       if not _unlocked_abilities.has(ability_id):
           _load_unlock_from_key(key)  # adds to _unlocked_abilities
           if _unlocked_abilities.has(ability_id):
               ability_unlocked.emit(ability_id, UnlockSource.PR_BREAKTHROUGH, false)
   _pre_suspended_snapshot.clear()
   _substate = Substate.READY
   if not _cooldown_remaining.is_empty():
       set_process(true)
   ```
4. **`_is_mutation_gated() -> bool`**:
   ```gdscript
   return _substate == Substate.SUSPENDED or _substate == Substate.RECONCILING
   ```
   Add this guard at top of `unlock_ability` + `cast_ability` body.
5. **Permanent unlock** (Rule 12): No `relock_ability` method. No `_unlocked_abilities.erase` or `.clear` in production paths. CI lint `check_ability_relock.gd` (Story 001) enforces at build time.
6. **`_pre_suspended_snapshot: Dictionary = {}`** — instance variable.

---

## Out of Scope

- Story 007: Boot reconciliation (reads pre-existing keys; this story handles mid-session Reconciling)
- Story 006: Cast cooldown tick (only cast-time GSM state check; this story adds substate lifecycle)

---

## QA Test Cases

**Story Type**: Integration

- **AC-15**: Suspended gate rejects mutations, passes reads
  - Given: MockGSM capturing callable, MockPL, boot to Ready
  - When: Deliver SUSPENDED transition; then attempt unlock + cast + get_unlocked_abilities
  - Then: unlock returns false + ability_mutation_rejected; cast returns GSM_REJECT; get_unlocked_abilities returns normally
  - Edge cases: Rapid SUSPENDED→READY cycles; multiple mutations during Suspended each independently rejected

- **AC-15b**: Reconciling re-read emits delta unlocks
  - Given: MockPL updated with new key during Suspended; MockGSM
  - When: Resume (exit Suspended) delivered
  - Then: New ability in _unlocked_abilities; ability_unlocked fires; substate = READY; subsequent unlock succeeds

- **AC-16**: Permanent unlock contract
  - Given: STRIKE_TIER_2 already unlocked
  - When: stat_changed delivers STR drop to 5 (EQUIPMENT source)
  - Then: _unlocked_abilities still contains STRIKE_TIER_2; no erase/delete calls; cast_ability returns STAT_INSUFFICIENT (stat below minimum) but unlock state unchanged

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/ability_system/test_suspended_gate.gd`, `tests/unit/ability_system/test_no_relock_on_stat_drop.gd`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 007 (boot wires GSM subscription + substate enum declared), Story 004 (unlock_ability infrastructure)
- Unlocks: Story 013 (ADR-Ratification-Gated — all 12 Ready stories must be Complete first)

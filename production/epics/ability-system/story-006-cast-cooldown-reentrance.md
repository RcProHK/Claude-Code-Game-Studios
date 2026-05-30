# Story 006: Cast Evaluation + Cooldown Tick + Re-entrance Guard

> **Epic**: Ability System
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M (2-4 hours)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-30

## Completion Notes
**Completed**: 2026-05-30
**Criteria**: 4/4 passing (AC-12/22/18/28)
**Deviations**: None — cast_ability 8-gate sequence (re-entrance _cast_depth → registry → unlocked → cooldown → GSM state COMBAT_ACTIVE/BOSS_ENCOUNTER → stat → target → emit); _process set_process toggle + MAX_FRAME_DELTA=0.1 clamp; ability_cast 3-arg no-damage (#13 owns combat math)
**Test Evidence**: test_cast_atomic_sequence.gd, test_formula_base_cooldown.gd, test_cooldown_tick.gd, test_reentrance_depth_limit.gd
**Code Review**: Batch B self-verified

## Context

**GDD**: `design/gdd/ability-system.md`
**Requirements**: `TR-ability-009`, `TR-ability-015`, `TR-ability-019`
*(TR-ability-009: Cast evaluation atomic sequence. TR-ability-015: Cooldown tick + set_process toggle + MAX_FRAME_DELTA. TR-ability-019: Re-entrance depth limit)*

**ADR Governing Implementation**: ADR-0006 Contract 12 (no `await`, chokepoint); ADR-0006 Contract 6 (`connect_for_initial_state` for GSM subscription for Rule 8 step 3 state check).
**ADR Decision Summary**: `cast_ability` is a sync atomic sequence — validate → cooldown check → GSM check → stat check → target check → emit + start cooldown → return CastResult. No `await` anywhere in the call chain. `_process(delta)` cooldown tick toggles via `set_process()`.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `Node.set_process(bool)` toggles `_process(delta)` per-frame calls. `Node.is_processing()` to check current state. `Node.is_queued_for_deletion()` for EC-22 target validation. `MAX_FRAME_DELTA` clamp via `minf(delta, 0.1)`.

**Control Manifest Rules (Core layer)**:
- Required: No `await` in `cast_ability` or any helper it calls (ADR-0006 Contract 12)
- Required: `set_process(false)` when `_cooldown_remaining.is_empty()` — 0 CPU when no cooldowns active
- Forbidden: Never `await` in `_process(delta)` body

---

## Acceptance Criteria

- [ ] **AC-12** — GIVEN STRIKE_TIER_1_JAB unlocked, `_cooldown_remaining` empty, STR=100 (mock stat), GSM `CombatActive` state (mock), valid live target Node2D, WHEN `cast_ability(AbilityId.STRIKE_TIER_1_JAB, caster, target)` invoked, THEN returns `CastResult.SUCCESS`, `_cooldown_remaining[STRIKE_TIER_1_JAB] == BASE_COOLDOWN_SEC[TIER_1] == 3.0`, `ability_cast` emits once with `(STRIKE_TIER_1_JAB, caster, target)` (no damage — #13 owns combat math), `ability_cooldown_started` emits with duration `3.0`.
- [ ] **AC-22** — GIVEN `const BASE_COOLDOWN_SEC = {TIER_1: 3.0, TIER_2: 6.0, TIER_3: 10.0}`, WHEN ability cast succeeds for each tier (separate fixtures), THEN `_cooldown_remaining[STRIKE_TIER_1_JAB] == 3.0`, `STRIKE_TIER_2_HOOK == 6.0`, `STRIKE_TIER_3_OVERHAND == 10.0` (exact float match, no fuzziness > 1e-6).
- [ ] **AC-18** — GIVEN AbilitySystem with no abilities on cooldown (`is_processing() == false`), WHEN cast succeeds (sets cooldown=3.0), THEN `is_processing() == true`; after `_process(0.5)` cooldown = 2.5; after `_process(0.3)` decrement produces cooldown ≤ 0 → entry erased + `ability_cooldown_ended` emits → `is_processing() == false`; AND `_process(30.0)` with MAX_FRAME_DELTA=0.1 clamp only decrements 0.1 (bfcache safety).
- [ ] **AC-28** — GIVEN AbilitySystem `MAX_EMIT_DEPTH=2`, subscriber connected to `ability_cooldown_started` that calls `cast_ability` → which fires `ability_cooldown_started` again → chain depth 3, WHEN initial `cast_ability` fires and triggers subscriber chain, THEN 3rd-level re-entrant call returns `CastResult.GSM_REJECT` (or `ability_cast_rejected` with reason `"reentrance_depth_exceeded"`) AND test completes within 1 second (no stack overflow / infinite recursion).

---

## Implementation Notes

*From GDD Rules 5, 8, 14 + EC-22/28:*

1. **`const BASE_COOLDOWN_SEC: Dictionary`**:
   ```gdscript
   const BASE_COOLDOWN_SEC: Dictionary = {
       AbilityTier.TIER_1: 3.0,
       AbilityTier.TIER_2: 6.0,
       AbilityTier.TIER_3: 10.0,
   }
   const MAX_FRAME_DELTA: float = 0.1  # bfcache resume safety (shared with #6/#7)
   const MAX_EMIT_DEPTH: int = 2
   ```
2. **`cast_ability` body** (6 validation steps, sync, no await):
   - Step 1: `_cast_depth += 1`; if `_cast_depth > MAX_EMIT_DEPTH` → `_cast_depth -= 1; return GSM_REJECT`
   - Step 2: ability_id in AbilityRegistry → else NOT_UNLOCKED
   - Step 3: ability_id in `_unlocked_abilities` → else NOT_UNLOCKED
   - Step 4: `_cooldown_remaining.has(ability_id)` → return ON_COOLDOWN
   - Step 5: GSM current state ∈ {COMBAT_ACTIVE, BOSS_ENCOUNTER} → else GSM_REJECT (use `_gsm` DI seam)
   - Step 6: `StatSystem.get_stat(class_stat_id) >= ability.minimum_active_stat` → else STAT_INSUFFICIENT
   - Step 7: target_type compatibility + target null/deleted check → else INVALID_TARGET
   - Step 8: emit `ability_cast(ability_id, caster, target)`; `_start_cooldown(ability_id)` → SUCCESS
   - `_cast_depth -= 1`; return SUCCESS
3. **`_start_cooldown(ability_id: StringName)`**:
   ```gdscript
   _cooldown_remaining[ability_id] = BASE_COOLDOWN_SEC[_get_ability_tier(ability_id)]
   set_process(true)
   ability_cooldown_started.emit(ability_id, _cooldown_remaining[ability_id])
   ```
4. **`_process(delta: float)`**:
   ```gdscript
   var clamped := minf(delta, MAX_FRAME_DELTA)
   for id in _cooldown_remaining.keys():  # copy keys for safe iteration
       _cooldown_remaining[id] -= clamped
       if _cooldown_remaining[id] <= 0.0:
           _cooldown_remaining.erase(id)
           ability_cooldown_ended.emit(id)
   if _cooldown_remaining.is_empty():
       set_process(false)
   ```
5. **`_gsm` DI seam** (untyped, duck-typed — see boot story 007 for boot wiring):
   - GSM state check: `_gsm.get_current_state() == GameStateMachine.GameState.COMBAT_ACTIVE or ...BOSS_ENCOUNTER`
6. **AbilityRegistry stub**: For VS tier, derive tier from ability_id (contains "tier_1"/"tier_2"/"tier_3"); `minimum_active_stat = 5.0` for all abilities; target_type = ENEMY for STRIKE/CONTROL, SELF for MOBILITY.

---

## Out of Scope

- Story 008: GSM Suspended gate (this story only covers cast-time GSM state check, not substate lifecycle)
- Story 007: Boot reconciliation
- Story 009: Knob invariants for BASE_COOLDOWN_SEC

---

## QA Test Cases

**Story Type**: Logic

- **AC-12**: Cast atomic sequence SUCCESS path
  - Given: MockGSM(CombatActive), MockStatSystem(STR=100), MockPL(write=true), STRIKE_TIER_1_JAB pre-unlocked, cooldown empty
  - When: `cast_ability(STRIKE_TIER_1_JAB, mock_caster, mock_target)`
  - Then: CastResult.SUCCESS; cooldown set to 3.0; ability_cast fires (no damage param); cooldown_started fires with 3.0

- **AC-22**: BASE_COOLDOWN_SEC per tier
  - Given: Same setup with each tier pre-unlocked
  - When: Cast each tier separately
  - Then: Exact cooldown values 3.0/6.0/10.0 with no float error > 1e-6

- **AC-18**: Cooldown tick + set_process toggle + bfcache clamp
  - Given: Fresh instance (add_child, boot to Ready), ability cast succeeds
  - When: Sequence of _process calls including 30.0 (bfcache spike)
  - Then: Process=true after cast; correct decrements; process=false after last cooldown; 30.0 delta → only 0.1 decremented

- **AC-28**: Re-entrance depth limit
  - Given: Subscriber on ability_cooldown_started that calls cast_ability; MAX_EMIT_DEPTH=2
  - When: Initial cast triggers chain
  - Then: 3rd-level returns GSM_REJECT; no stack overflow; test completes < 1s

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/ability_system/test_cast_atomic_sequence.gd`, `tests/unit/ability_system/test_formula_base_cooldown.gd`, `tests/unit/ability_system/test_cooldown_tick.gd`, `tests/unit/ability_system/test_reentrance_depth_limit.gd`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (enums, especially CastResult), Story 005 (abilities must be unlockable to be cast)
- Unlocks: Story 009 (cooldown knob invariants reference BASE_COOLDOWN_SEC)

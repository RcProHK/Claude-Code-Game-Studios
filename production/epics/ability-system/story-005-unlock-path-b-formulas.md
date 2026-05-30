# Story 005: Unlock Path B (STAT_THRESHOLD) + Formulas 1+3

> **Epic**: Ability System
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M (2-3 hours)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-30

## Completion Notes
**Completed**: 2026-05-30
**Criteria**: 3/3 passing (AC-11/21/23)
**Deviations**: None — `_evaluate_unlock_tiers` (Path B iterate) added alongside Batch A's 4-arg `_evaluate_unlock` (preserved for AC-07 test compat); Formula 3 sort_custom key = tier_ord*4 + class_ord; EQUIPMENT-source stat_changed excluded (EC-15)
**Test Evidence**: test_unlock_path_b_multi_tier.gd, test_formula_tier_thresholds.gd, test_formula_unlock_event_priority.gd
**Code Review**: Batch B self-verified

## Context

**GDD**: `design/gdd/ability-system.md`
**Requirements**: `TR-ability-008`, `TR-ability-017`
*(TR-ability-008: Unlock evaluation Path A (PR_BREAKTHROUGH) + Path B (STAT_THRESHOLD multi-tier ascent). TR-ability-017: TIER_THRESHOLDS / BASE_COOLDOWN_SEC / UNLOCK_EVENT_PRIORITY deterministic sort)*

**ADR Governing Implementation**: ADR-0006 Contract 6 (`connect_for_initial_state` subscription to #11 `stat_changed`); ADR-0007 (class ordinals load-bearing for Formula 3 sort).
**ADR Decision Summary**: Path B subscribes to Stat System `stat_changed` via `connect_for_initial_state`; evaluates threshold on VOLUME_TICK and PR_BREAKTHROUGH sources only (EQUIPMENT excluded — Pillar 1); Formula 3 sorts pending unlocks by (tier_ordinal, class_ordinal) for deterministic emit.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `connect_for_initial_state` callv delivers 5-arg positional layout `[stat_id, old, new, source, is_initial]`. No `.bind()` (breaks callv). `Array.sort_custom()` for Formula 3 deterministic sort.

**Control Manifest Rules (Core layer)**:
- Required: Subscribers MUST use `connect_for_initial_state` — plain `.connect("stat_changed", cb)` is FORBIDDEN (CI lint check_ability_signal_connect.gd)
- Required: EQUIPMENT-source `stat_changed` must be ignored (EC-14/EC-15 Pillar 1 anti-fabrication)

---

## Acceptance Criteria

- [ ] **AC-11** — GIVEN AbilitySystem initialized, no abilities unlocked, STR=9, WHEN `stat_changed(STR, 9, 52, STAT_THRESHOLD)` delivered from #11 (via connect_for_initial_state handler), THEN Path B iterates TIER_1→TIER_2→TIER_3: `STRIKE_TIER_1_JAB` + `STRIKE_TIER_2_HOOK` unlocked (52 ≥ 10 and 52 ≥ 50), `STRIKE_TIER_3_OVERHAND` NOT unlocked (52 < 200), signals emit in tier-ascending order (TIER_1 before TIER_2) per Formula 3.
- [ ] **AC-21** — GIVEN `const TIER_THRESHOLDS = {TIER_1: 10, TIER_2: 50, TIER_3: 200}`, WHEN `_evaluate_unlock(STR, value, STAT_THRESHOLD)` invoked with values 9, 10, 49, 50, 199, 200, THEN: 9→0 unlocks; 10→TIER_1 only; 49→TIER_1 only; 50→TIER_1+TIER_2; 199→TIER_1+TIER_2; 200→all 3 tiers (inclusive `≥` boundary).
- [ ] **AC-23** — GIVEN AbilitySystem first boot with DEFAULT_BASE_STAT=10 across STR=DEX=VIT=10 delivered same frame (all 3 TIER_1 thresholds met simultaneously), WHEN all 3 TIER_1 abilities unlock, THEN `ability_unlocked` signals arrive in sorted order: TIER_1_JAB(STRIKE) → TIER_1_PARRY(CONTROL) → TIER_1_DASH(MOBILITY) AND repeating test 100 times produces identical order every run (Formula 3 determinism).

---

## Implementation Notes

*From GDD Rule 7, Formulas 1/3 + ADR-0006 Contract 6:*

1. **`const TIER_THRESHOLDS: Dictionary`** (data-driven, all 3 classes share same thresholds):
   ```gdscript
   const TIER_THRESHOLDS: Dictionary = {
       AbilityTier.TIER_1: 10,
       AbilityTier.TIER_2: 50,
       AbilityTier.TIER_3: 200,
   }
   ```
2. **`_on_stat_changed(stat_id, old, new, source, _is_initial)` handler** (subscribed via `connect_for_initial_state` in `_ready()`):
   - If `source == StatSource.EQUIPMENT`: return early (EC-14/EC-15 — equipment stats don't unlock abilities)
   - If `stat_id not in StatId`: return early
   - If `source not in [StatSource.VOLUME_TICK, StatSource.PR_BREAKTHROUGH]`: return early
   - Call `_evaluate_unlock(stat_id, new, UnlockSource.STAT_THRESHOLD)`
3. **`_evaluate_unlock(stat_id, current_value, source)`**:
   - Map `stat_id → ability_class` via `_STAT_TO_CLASS`
   - Build `pending_unlocks: Array[StringName]`
   - For each tier in TIER_1/TIER_2/TIER_3:
     - `ability_id_for(class, tier)` lookup
     - If `current_value >= TIER_THRESHOLDS[tier]` AND NOT in `_unlocked_abilities` → append to pending_unlocks
   - Sort `pending_unlocks` by Formula 3 key: `(tier_ordinal, class_ordinal)`
   - Set `_unlock_call_permitted = true`
   - For each in sorted order: call `unlock_ability(id, source)`
   - Reset `_unlock_call_permitted = false`
4. **Formula 3 sort key** — use `Array.sort_custom` with lambda comparing `(tier_ordinal << 2) | class_ordinal` as integer sort key (deterministic, no allocation).
5. **`_stat_system` DI seam** (untyped, for test injection):
   ```gdscript
   var _stat_system = null
   # in _ready(): if _stat_system == null: _stat_system = StatSystem
   ```
   Subscribe: `_stat_system.connect_for_initial_state(_on_stat_changed)` in `_ready()`.
6. **Performance (Q-X1 context)**: `_evaluate_unlock` iterates 3 tiers O(3). Per stat_changed: worst case 3 ability lookups. Trivial vs 0.01ms budget. No caching needed for VS tier.

---

## Out of Scope

- Story 004: Path A (PR_BREAKTHROUGH direct unlock via #18 signal)
- Story 006: Cast + cooldown (unrelated)
- Story 007: Boot reconciliation (loads pre-existing unlocks, doesn't re-evaluate thresholds at boot)

---

## QA Test Cases

**Story Type**: Logic

- **AC-11**: Path B multi-tier ascent
  - Given: No abilities unlocked, `_stat_system` mock, `_persistence` mock (write=true)
  - When: Deliver `stat_changed(STR, 9, 52, STAT_THRESHOLD)` via direct handler call or connect_for_initial_state
  - Then: TIER_1_JAB and TIER_2_HOOK unlocked; TIER_3 not; TIER_1 emits before TIER_2 (Formula 3 order)
  - Edge cases: EQUIPMENT source → no evaluation; STR=9 → 0 unlocks; STR=200 → all 3 tiers

- **AC-21**: Threshold boundary values
  - Given: Mock persistence, evaluate 6 boundary values
  - When: `_evaluate_unlock(STR, value, STAT_THRESHOLD)` for value ∈ {9,10,49,50,199,200}
  - Then: Correct tier count for each value per inclusive ≥ rule
  - Edge cases: Exactly at threshold = unlocks; one below = does not

- **AC-23**: Formula 3 determinism
  - Given: STR=DEX=VIT=10, no abilities unlocked; deliver stat_changed for all 3 simultaneously
  - When: Same scenario run 100 times
  - Then: TIER_1_JAB → TIER_1_PARRY → TIER_1_DASH every single run (no randomness)
  - Edge cases: Hash order of pending_unlocks array irrelevant — sort produces consistent result

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/ability_system/test_unlock_path_b_multi_tier.gd`, `tests/unit/ability_system/test_formula_tier_thresholds.gd`, `tests/unit/ability_system/test_formula_unlock_event_priority.gd`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 004 (unlock_ability + _evaluate_unlock infrastructure), Story 002 (enums)
- Unlocks: Story 006 (cast builds on unlocked ability state), Story 009 (knob invariants reference TIER_THRESHOLDS)
